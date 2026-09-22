// ExpenseSyncPolicy.swift
// Las reglas de la sincronización de gastos con Firestore, sin red ni almacén:
// qué tramo se baja, cuándo toca el historial entero, cuándo es seguro purgar
// y cuándo "Todos" puede salir de la caché.

import Foundation

/// Cada documento que devuelve Firestore es una lectura facturada, y la
/// sincronización de fondo bajaba el historial entero cada cinco minutos de
/// uso: con 1.000 gastos y diez aperturas al día eran 10.000 lecturas por
/// usuario, con 50.000 diarias para todo el proyecto.
///
/// Ahora lo normal es bajar solo una ventana reciente —donde ocurre casi todo
/// lo que cambia— y dejar el historial entero para una vez por semana.
///
/// `nonisolated` y sin estado: son funciones puras para poder probarlas sin
/// Firestore ni SwiftData.
nonisolated enum ExpenseSyncPolicy {

    /// Tramo de fechas "yyyy-MM-dd", inclusive por los dos lados. Se compara
    /// como texto: con ese formato el orden lexicográfico es el cronológico.
    nonisolated struct Ventana: Equatable, Sendable {
        let desde: String
        let hasta: String

        func contiene(_ fecha: String) -> Bool {
            fecha >= desde && fecha <= hasta
        }
    }

    // MARK: - Marcas en UserDefaults

    /// Cuándo terminó la última sincronización de fondo, del tipo que fuera.
    static let lastSyncKey = "lastSyncTimestamp"
    /// Cuándo terminó la última que bajó el historial entero. A cero, la caché
    /// no se da por completa: ni se sirve "Todos" desde ella ni se espera una
    /// semana para bajarlo todo.
    static let lastFullSyncKey = "lastFullSyncTimestamp"

    /// Las marcas son del usuario y de la caché que había. Al cerrar sesión,
    /// cambiar de cuenta o quedarse la caché vacía dejan de valer: si
    /// sobrevivieran, la caché recién estrenada pasaría por completa y el
    /// historial antiguo tardaría hasta una semana en volver.
    static func olvidarMarcas(en defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: lastSyncKey)
        defaults.removeObject(forKey: lastFullSyncKey)
    }

    // MARK: - Ventana

    /// Meses enteros hacia atrás, además del que corre.
    static let mesesAtras = 2
    /// Sin tope por arriba: los gastos con fecha futura también entran.
    static let finAbierto = "9999-12-31"

    /// Del día 1 de hace dos meses en adelante. En enero empieza en noviembre
    /// del año anterior.
    ///
    /// Calendario gregoriano a propósito: las fechas guardadas lo son siempre
    /// (`en_US_POSIX`), aunque el dispositivo use otro.
    static func ventana(para fecha: Date, zona: TimeZone = .current) -> Ventana {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zona
        let partes = calendario.dateComponents([.year, .month], from: fecha)
        var año = partes.year ?? 1970
        var mes = (partes.month ?? 1) - mesesAtras
        while mes < 1 {
            mes += 12
            año -= 1
        }
        return Ventana(desde: String(format: "%04d-%02d-01", año, mes), hasta: finAbierto)
    }

    // MARK: - Purga

    /// Los locales que ya no están en remoto se borran solo si la respuesta
    /// trae un número razonable de gastos: una respuesta a medias no debe
    /// vaciar la caché. `locales` son los del mismo tramo que se pidió.
    static func debePurgar(remotos: Int, locales: Int) -> Bool {
        remotos > 0 && remotos >= locales / 2
    }

    // MARK: - Historial entero

    /// Cada cuánto se baja todo. Es lo que tardan en llegar, como mucho, las
    /// ediciones hechas desde otro dispositivo en gastos anteriores a la ventana.
    static let intervaloCompleta: TimeInterval = 7 * 24 * 60 * 60

    /// Nunca se ha hecho, ha pasado una semana, o el reloj ha ido hacia atrás
    /// (una marca en el futuro aplazaría la completa sin fecha).
    static func tocaCompleta(ultimaCompleta: TimeInterval, ahora: TimeInterval) -> Bool {
        guard ultimaCompleta > 0, ultimaCompleta <= ahora else { return true }
        return ahora - ultimaCompleta >= intervaloCompleta
    }

    // MARK: - "Todos" desde la caché

    /// Sin filtro o con "Todos", el remoto devuelve el historial entero. Eso
    /// mismo está en la caché, siempre que alguna vez se haya bajado entera:
    /// con solo el mes que guarda la Home al arrancar, "Todos" enseñaría un mes.
    static func respondeDesdeCache(
        filter: ExpenseFilter?,
        cacheVacia: Bool,
        ultimaCompleta: TimeInterval
    ) -> Bool {
        guard !cacheVacia, ultimaCompleta > 0 else { return false }
        guard let filter else { return true }
        return filter.dateRange == .allTime
    }

    /// El orden en que Firestore devuelve `order(by: "date", descending: true)`:
    /// por fecha y, a igualdad, por id de documento en el mismo sentido.
    static func enOrdenRemoto(_ expenses: [Expense]) -> [Expense] {
        expenses.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return ($0.id ?? "") > ($1.id ?? "")
        }
    }
}
