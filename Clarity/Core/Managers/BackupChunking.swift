// BackupChunking.swift
// Lógica PURA de la copia en la nube (sin Firestore): partir los gastos para
// que ningún documento pase del límite, y recomponerlos al restaurar.
//
// Firestore rechaza cualquier documento de más de 1 MiB. La copia guardaba
// todo serializado en UN documento: con unos 3.000 gastos dejaba de caber y la
// copia automática fallaba cada semana sin que nadie lo viera.
//
// Formato:
//  - Si todo cabe, un solo documento, idéntico al de siempre: lo restaura
//    también una versión antigua de la app.
//  - Si no cabe, el documento principal lleva la copia SIN gastos y `partCount`;
//    los gastos van en documentos hermanos `<id>_p<n>` de la misma colección
//    `backups`, marcados con `isBackupPart` y `parentBackupId`.
//
// Hermanos y no una subcolección bajo la copia: `users/{uid}/backups/{doc}` es
// la ruta que ya escriben las copias de hoy, así que funciona con las reglas
// que haya desplegadas sin tener que confirmarlas (la regla de rutas anidadas
// está en `firestore.rules`, pero desde aquí no se puede comprobar que sea la
// desplegada). Además, borrar la cuenta vacía `backups` documento a documento
// y no baja a subcolecciones: anidadas se quedarían huérfanas para siempre.
//
// Las partes NO llevan el campo `timestamp`: las consultas que listan copias
// ordenan por él, y Firestore deja fuera los documentos que no lo tienen. Así
// tampoco las ven —ni les ocupan hueco en el `limit`— las versiones antiguas.

import Foundation

/// Una parte de la copia: un tramo de los gastos, en su orden.
///
/// Envuelto en un objeto y no un array a pelo para poder añadir campos sin
/// romper las partes ya guardadas.
nonisolated struct BackupPart: Codable, Sendable {
    let expenses: [Expense]
}

// `nonisolated`: lógica pura sin estado. Se ejecuta en una tarea aparte para
// no serializar el historial entero en el hilo principal.
nonisolated enum BackupChunking {

    // MARK: - Límites

    /// Tope de JSON por documento. El límite de Firestore es 1.048.576 bytes
    /// contando nombres de campo y metadatos; el margen los cubre de sobra.
    static let limitePorDocumento = 900_000

    /// Operaciones por `WriteBatch`. El máximo de Firestore es 500; el mismo
    /// margen que ya usa `UserDataService`.
    static let operacionesPorLote = 450

    /// Una parte sin copia madre no se borra hasta pasado este tiempo: puede
    /// ser de una copia que otro dispositivo está escribiendo ahora mismo (las
    /// partes se suben antes que el documento principal).
    static let graciaDeHuerfanas: TimeInterval = 24 * 60 * 60

    // MARK: - Tipos

    /// Lo que hay que escribir en Firestore para una copia.
    struct Documentos: Sendable, Equatable {
        /// JSON del documento principal (`UserBackup`).
        let principal: String
        /// JSON de cada parte (`BackupPart`), en orden. Vacío si todo cupo.
        let partes: [String]

        /// Bytes de la copia entera, para enseñarlos en la lista.
        var bytes: Int {
            principal.utf8.count + partes.reduce(0) { $0 + $1.utf8.count }
        }
    }

    enum Fallo: LocalizedError, Equatable {
        /// Ni quitándole los gastos cabe el documento principal.
        case principalDemasiadoGrande(bytes: Int)
        /// Falta alguna parte: restaurar a medias sería peor que no restaurar.
        case copiaIncompleta(esperadas: Int, encontradas: Int)

        var errorDescription: String? {
            switch self {
            case .principalDemasiadoGrande:
                return "La copia es demasiado grande para guardarla"
            case .copiaIncompleta(let esperadas, let encontradas):
                return "La copia está incompleta (\(encontradas) de \(esperadas) partes)"
            }
        }
    }

    // MARK: - Codificación

    // Las fechas, en segundos: es como se han guardado siempre las copias en
    // la nube, y las antiguas tienen que seguir leyéndose.

    static func codificador() -> JSONEncoder {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .secondsSince1970
        return codificador
    }

    static func decodificador() -> JSONDecoder {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .secondsSince1970
        return decodificador
    }

    // MARK: - Partir

    /// Serializa la copia y, si no cabe en un documento, saca los gastos a
    /// partes.
    ///
    /// Por tamaño y no por número de gastos: el límite es de bytes, y un gasto
    /// con notas o deudores ocupa varias veces lo que uno escueto. Un tope por
    /// número tendría que ser muy bajo para ser seguro, o dejaría de serlo.
    static func trocear(_ backup: UserBackup, limite: Int = limitePorDocumento) throws -> Documentos {
        let codificador = codificador()
        let entera = try codificador.encode(backup)
        if entera.count <= limite {
            return Documentos(principal: String(decoding: entera, as: UTF8.self), partes: [])
        }

        let sinGastos = try codificador.encode(backup.conGastos([]))
        guard sinGastos.count <= limite else {
            throw Fallo.principalDemasiadoGrande(bytes: sinGastos.count)
        }
        return Documentos(
            principal: String(decoding: sinGastos, as: UTF8.self),
            partes: try repartir(backup.expenses, limite: limite, codificador: codificador)
        )
    }

    /// Parte los gastos por la mitad hasta que cada tramo, ya serializado,
    /// cabe. Se mide el JSON real de cada parte, no una estimación, así que lo
    /// que devuelve cabe seguro. Un único gasto que no quepa se devuelve tal
    /// cual: no se puede partir más, y Firestore dará el error al escribirlo.
    private static func repartir(_ gastos: [Expense], limite: Int, codificador: JSONEncoder) throws -> [String] {
        let datos = try codificador.encode(BackupPart(expenses: gastos))
        if datos.count <= limite || gastos.count <= 1 {
            return [String(decoding: datos, as: UTF8.self)]
        }
        let mitad = gastos.count / 2
        return try repartir(Array(gastos[..<mitad]), limite: limite, codificador: codificador)
            + repartir(Array(gastos[mitad...]), limite: limite, codificador: codificador)
    }

    // MARK: - Recomponer

    /// Reconstruye la copia. Con `partesEsperadas == 0` es el formato de un
    /// solo documento —el antiguo, o el nuevo cuando todo cabe— y `principal`
    /// ya lo trae todo.
    ///
    /// - Parameter partes: JSON de cada parte por su índice.
    /// - Throws: `Fallo.copiaIncompleta` si falta alguna. Restaurar solo los
    ///   gastos que hayan llegado pasaría por una restauración buena.
    static func recomponer(
        principal: String,
        partes: [Int: String] = [:],
        partesEsperadas: Int = 0
    ) throws -> UserBackup {
        let decodificador = decodificador()
        let base = try decodificador.decode(UserBackup.self, from: Data(principal.utf8))
        guard partesEsperadas > 0 else { return base }

        var gastos = base.expenses
        for indice in 0..<partesEsperadas {
            guard let texto = partes[indice] else {
                throw Fallo.copiaIncompleta(esperadas: partesEsperadas, encontradas: partes.count)
            }
            gastos += try decodificador.decode(BackupPart.self, from: Data(texto.utf8)).expenses
        }
        return base.conGastos(gastos)
    }

    // MARK: - Documentos hermanos

    static func idDeParte(copia: String, indice: Int) -> String {
        "\(copia)_p\(indice)"
    }

    /// Una parte tal como está en Firestore, para decidir si sobra.
    struct ParteGuardada: Sendable, Equatable {
        let id: String
        let copia: String
        let creada: Date?
    }

    /// Ids de las partes que hay que borrar: las de una copia que ya no existe.
    ///
    /// Quedan huérfanas cuando falla una copia a medias o cuando una versión
    /// antigua de la app rota las copias (borra el documento principal y no
    /// sabe que hay partes). Cada una puede pesar casi 1 MB.
    static func partesHuerfanas(
        _ partes: [ParteGuardada],
        copiasVivas: Set<String>,
        ahora: Date = Date()
    ) -> [String] {
        partes.compactMap { parte in
            guard !copiasVivas.contains(parte.copia) else { return nil }
            // Sin fecha no se sabe si es reciente: se deja para la próxima.
            guard let creada = parte.creada,
                  ahora.timeIntervalSince(creada) > graciaDeHuerfanas else { return nil }
            return parte.id
        }
    }

    // MARK: - Lotes de restauración

    /// Los gastos que se pueden restaurar —sin id no hay documento al que
    /// escribir—, en lotes que caben en un `WriteBatch`.
    static func lotes(de gastos: [Expense], tamaño: Int = operacionesPorLote) -> [[Expense]] {
        gastos.filter { $0.id?.isEmpty == false }.chunked(into: tamaño)
    }
}
