// InformeDeCuelgue.swift
// Lo que queda en disco de un cuelgue: el informe, dónde se guarda y cómo se
// resume para el pie del correo de soporte.
//
// Nada de esto toca el hilo principal salvo la lectura del pie, que ocurre al
// pulsar "Algo no funciona" y lee un archivo de unos pocos KB.

import Foundation
import OSLog

// MARK: - Informe

/// Un cuelgue del hilo principal, tal como lo vio el vigilante.
nonisolated struct InformeDeCuelgue: Codable, Equatable, Sendable {
    /// Cuándo se detectó. Empezó `segundosBloqueado` antes.
    var fecha: Date
    /// Lo que llevaba bloqueado la última vez que se pudo escribir.
    var segundosBloqueado: Double
    /// `false` mientras dura. Si se queda así, la app murió colgada: quien la
    /// usaba la cerró a mano (o el sistema por ella) y esa duración es un mínimo.
    var recuperado: Bool
    var versionApp: String
    var build: String
    var versionIOS: String
    /// Identificador de hardware ("iPhone14,5"). No identifica a la persona.
    var modelo: String
    /// Lo último que hizo la app antes de bloquearse. Solo nombres de pantalla
    /// y de acción: ver `Migas`.
    var migas: [Miga]

    /// Qué informe se queda en disco cuando el hilo principal se recupera.
    ///
    /// Gana siempre el más reciente salvo en un caso: un cuelgue del que la app
    /// salió sola no pisa a uno más largo del que NO salió. El que interesa es el
    /// que obligó a cerrar la app, y sin esta regla lo borraría el primer tirón de
    /// tres segundos que hubiera días después, antes de que nadie escribiera.
    static func queConservar(anterior: InformeDeCuelgue?, recuperado nuevo: InformeDeCuelgue) -> InformeDeCuelgue {
        guard let anterior, !anterior.recuperado,
              anterior.segundosBloqueado > nuevo.segundosBloqueado
        else { return nuevo }
        return anterior
    }
}

// MARK: - Datos del aparato

/// Versión, iOS y modelo, leídos sin pasar por el hilo principal: cuando hacen
/// falta, está colgado. Por eso `ProcessInfo` y `uname` en vez de `UIDevice`.
nonisolated enum DatosDelAparato {
    static var versionApp: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    static var versionIOS: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let base = "\(v.majorVersion).\(v.minorVersion)"
        return v.patchVersion == 0 ? base : "\(base).\(v.patchVersion)"
    }

    static var modelo: String {
        var info = utsname()
        uname(&info)
        let largo = MemoryLayout.size(ofValue: info.machine)
        let identificador = withUnsafePointer(to: &info.machine) { puntero in
            puntero.withMemoryRebound(to: CChar.self, capacity: largo) { String(cString: $0) }
        }
        return identificador.isEmpty ? "iPhone" : identificador
    }
}

// MARK: - Almacén

/// La carpeta `Application Support/Diagnostics/`. Todas las operaciones son
/// síncronas a propósito: el informe se escribe desde el hilo del vigilante con
/// el principal colgado y no hay a quién esperar.
nonisolated struct AlmacenDeDiagnosticos: Sendable {
    static let nombreUltimoCuelgue = "ultimo_cuelgue.json"
    static let prefijoMetricKit = "metrickit_"
    /// Informes de MetricKit que se conservan. Pesan (traen pilas de llamadas) y
    /// solo interesan los recientes.
    static let topeMetricKit = 5

    static let registroDelSistema = Logger(subsystem: "com.idanidev.clarity", category: "Diagnosticos")

    let carpeta: URL

    static let porDefecto: AlmacenDeDiagnosticos = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return AlmacenDeDiagnosticos(carpeta: base.appendingPathComponent("Diagnostics", isDirectory: true))
    }()

    var urlUltimoCuelgue: URL {
        carpeta.appendingPathComponent(Self.nombreUltimoCuelgue)
    }

    // MARK: Cuelgues

    /// Escritura atómica: si matan la app a media escritura, queda el informe
    /// anterior entero y no medio archivo.
    func guarda(_ informe: InformeDeCuelgue) {
        do {
            try preparaCarpeta()
            try Self.codifica(informe).write(to: urlUltimoCuelgue, options: .atomic)
        } catch {
            Self.registroDelSistema.error("No se pudo guardar el informe de cuelgue: \(error.localizedDescription)")
        }
    }

    func ultimoCuelgue() -> InformeDeCuelgue? {
        guard let datos = try? Data(contentsOf: urlUltimoCuelgue) else { return nil }
        return try? Self.decodifica(datos)
    }

    // MARK: MetricKit

    /// Guarda un payload de MetricKit tal cual llega y deja solo los más recientes.
    func guardaMetricKit(_ datos: Data, fecha: Date, indice: Int = 0) {
        do {
            try preparaCarpeta()
            let nombre = Self.nombreMetricKit(fecha: fecha, indice: indice)
            try datos.write(to: carpeta.appendingPathComponent(nombre), options: .atomic)

            let nombres = try FileManager.default.contentsOfDirectory(atPath: carpeta.path)
            for sobrante in Self.sobrantesDeMetricKit(entre: nombres) {
                try? FileManager.default.removeItem(at: carpeta.appendingPathComponent(sobrante))
            }
        } catch {
            Self.registroDelSistema.error("No se pudo guardar el payload de MetricKit: \(error.localizedDescription)")
        }
    }

    /// `metrickit_20260919-184207.json`. En UTC y de mayor a menor unidad para
    /// que el orden alfabético sea el cronológico, cambie o no la zona horaria.
    static func nombreMetricKit(fecha: Date, indice: Int = 0) -> String {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.timeZone = TimeZone(identifier: "UTC")
        formato.dateFormat = "yyyyMMdd-HHmmss"
        let sufijo = indice == 0 ? "" : "_\(indice)"
        return "\(prefijoMetricKit)\(formato.string(from: fecha))\(sufijo).json"
    }

    /// Qué archivos de MetricKit sobran. Pura, para poder probarla sin disco.
    static func sobrantesDeMetricKit(entre nombres: [String], conservando tope: Int = topeMetricKit) -> [String] {
        let propios = nombres
            .filter { $0.hasPrefix(prefijoMetricKit) && $0.hasSuffix(".json") }
            .sorted(by: >)
        return Array(propios.dropFirst(max(0, tope)))
    }

    // MARK: JSON

    /// ISO 8601 con milisegundos: entre dos avisos del teclado puede haber menos
    /// de un segundo, y el orden fino es justo lo que se quiere ver.
    private static let estiloDeFecha = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func codifica<Valor: Encodable>(_ valor: Valor) throws -> Data {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        codificador.dateEncodingStrategy = .custom { fecha, encoder in
            var contenedor = encoder.singleValueContainer()
            try contenedor.encode(fecha.formatted(estiloDeFecha))
        }
        return try codificador.encode(valor)
    }

    static func decodifica(_ datos: Data) throws -> InformeDeCuelgue {
        try decodifica(InformeDeCuelgue.self, de: datos)
    }

    static func decodifica<Valor: Decodable>(_ tipo: Valor.Type, de datos: Data) throws -> Valor {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .custom { decoder in
            let contenedor = try decoder.singleValueContainer()
            let texto = try contenedor.decode(String.self)
            guard let fecha = try? Date(texto, strategy: estiloDeFecha) else {
                throw DecodingError.dataCorruptedError(in: contenedor, debugDescription: "Fecha no válida: \(texto)")
            }
            return fecha
        }
        return try decodificador.decode(tipo, from: datos)
    }

    // MARK: Carpeta

    func preparaCarpeta() throws {
        guard !FileManager.default.fileExists(atPath: carpeta.path) else { return }
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        // Son datos de diagnóstico del aparato: no pintan nada en la copia de iCloud.
        var url = carpeta
        var valores = URLResourceValues()
        valores.isExcludedFromBackup = true
        try? url.setResourceValues(valores)
    }
}

// MARK: - Resumen para el correo

/// El informe en unas pocas líneas legibles, para el pie del `mailto:` de soporte.
nonisolated enum ResumenDeCuelgue {
    /// Migas que caben en el pie. El informe en disco guarda todas.
    static let migasEnElPie = 12
    /// Un `mailto:` es una URL: pasado cierto largo, hay clientes de correo que
    /// la recortan o no la abren.
    static let topeDeCaracteres = 1200

    /// Qué va al pie. Un solo bloque de migas, que el tope es para todo el añadido:
    ///
    /// - Cuelgue de la sesión anterior o posterior (o sin sesión anterior con la
    ///   que comparar): el bloque del cuelgue, entero.
    /// - Cuelgue MÁS VIEJO que la sesión anterior: manda la sesión anterior (ver
    ///   `VolcadoDeMigas`) y el cuelgue se queda en una línea al final. El informe
    ///   no caduca en disco, y sin esta regla uno de hace un mes taparía para
    ///   siempre lo último que pasó, que es de lo que suele ir el correo.
    /// - Sin cuelgue: la sesión anterior, si dejó migas. Sin nada: nada.
    static func paraElPie(
        cuelgue: InformeDeCuelgue?,
        sesionAnterior: SesionDeMigas?,
        zona: TimeZone = .current,
        tope: Int = topeDeCaracteres
    ) -> String {
        // Una sesión sin migas no tiene ni bloque ni principio con el que comparar.
        let sesion = sesionAnterior.flatMap { $0.migas.isEmpty ? nil : $0 }

        guard let cuelgue else {
            return sesion.map { paraElPie($0, zona: zona, tope: tope) } ?? ""
        }
        guard let sesion, let principio = sesion.migas.first?.fecha, cuelgue.fecha < principio else {
            return paraElPie(cuelgue, zona: zona, tope: tope)
        }
        return paraElPie(sesion, cuelguePrevio: cuelgue, zona: zona, tope: tope)
    }

    /// Texto que se añade al pie, saltos de línea iniciales incluidos. Nunca pasa
    /// de `tope`: si no cabe, se caen las migas más viejas.
    static func paraElPie(
        _ informe: InformeDeCuelgue,
        zona: TimeZone = .current,
        tope: Int = topeDeCaracteres
    ) -> String {
        let dia = formateador("yyyy-MM-dd HH:mm:ss Z", zona: zona)
        let desenlace = informe.recuperado ? "se recuperó" : "la app no se recuperó"
        let segundos = String(format: "%.1f", informe.segundosBloqueado)
        let cabecera = """


        Último cuelgue: \(dia.string(from: informe.fecha)) · \(segundos) s · \(desenlace)
        Clarity \(informe.versionApp) (\(informe.build)) · \(informe.modelo) · iOS \(informe.versionIOS)
        """
        return conMigas(informe.migas, tras: cabecera, zona: zona, tope: tope)
    }

    /// La cabecera de un bloque y, debajo, sus últimas migas: una por línea, con
    /// su hora. De la más reciente hacia atrás mientras quepan; luego, en orden.
    ///
    /// - Parameter cierre: lo que va detrás de las migas. Su sitio se reserva
    ///   antes de repartir: si no cabe todo, se caen migas, no el cierre.
    static func conMigas(
        _ migas: [Miga],
        tras cabecera: String,
        cierre: String = "",
        zona: TimeZone,
        tope: Int
    ) -> String {
        let hora = formateador("HH:mm:ss.SSS", zona: zona)
        var lineas: [String] = []
        var largo = cabecera.count + cierre.count
        for miga in migas.suffix(migasEnElPie).reversed() {
            let repeticiones = miga.veces > 1 ? " ×\(miga.veces)" : ""
            let linea = "\n\(hora.string(from: miga.fecha)) \(miga.texto)\(repeticiones)"
            guard largo + linea.count <= tope else { break }
            lineas.append(linea)
            largo += linea.count
        }
        return String((cabecera + lineas.reversed().joined() + cierre).prefix(tope))
    }

    /// Formato fijo y no el de `Formatters`: esto no es interfaz, es un dato
    /// técnico con milisegundos que tiene que leerse igual venga de donde venga.
    /// En la hora local de quien escribe, que es la que contará en el correo.
    static func formateador(_ formato: String, zona: TimeZone) -> DateFormatter {
        let formateador = DateFormatter()
        formateador.locale = Locale(identifier: "en_US_POSIX")
        formateador.timeZone = zona
        formateador.dateFormat = formato
        return formateador
    }
}
