// AnalyticsService.swift
// Métricas de producto (#40 §4): onboarding, gastos por usuario, uso de voz y
// retención D1/D7/D30.
//
// La métrica norte es "usuarios que registran gastos 3+ días por semana", así
// que además de emitir eventos se llevan contadores locales — se pueden leer sin
// depender de ninguna consola externa.

import Foundation
import OSLog
import UIKit

/// Eventos que la app emite. Nombres en snake_case (convención de Firebase).
enum AnalyticsEvent: Sendable {
    case onboardingStarted
    case onboardingCompleted
    case expenseAdded(method: ExpenseInputMethod, category: String)
    /// Un dictado que no acabó en gasto. El motivo es un vocabulario cerrado:
    /// nunca lleva lo dictado.
    case voiceExpenseFailed(reason: FalloVoz)
    case paywallShown(reason: String)
    case purchaseCompleted(productId: String)
    case reviewPrompted
    case debtSettled
    case sessionStarted(deviceModel: String, systemVersion: String)
    case sessionEnded(seconds: Int)
    case screenViewed(name: String)
    case aiCategoryCorrected(from: String, to: String)
    case budgetConfigured(source: String)
    case budgetLimitReached(percent: Int)
    case extraIncomeLogged
    case supportContacted(reason: String)
    /// Se ha visto la pantalla de "aún no hay gastos". Sin esto no se puede
    /// saber cuánta gente la ve y cuánta sale de ahí apuntando algo, que es el
    /// escalón donde hoy se pierden 7 de cada 21 (#40).
    case emptyStateShown
    case emptyStateAction(method: String)
    /// Permiso de micrófono: sin esto no se sabe si la voz no se usa porque no
    /// gusta o porque el permiso se deniega en el primer intento (#57).
    case microphonePermission(granted: Bool)
    /// Primer gasto registrado durante el onboarding, con el método usado.
    case onboardingFirstExpense(method: String)
    /// Cada vez que se enseña una página del onboarding: su posición y un
    /// nombre que no cambia aunque cambie el orden. El 33 % abandonaba entre
    /// empezar y terminar, y sin esto no se sabe en qué página (#57).
    case onboardingStep(index: Int, name: String)
    /// La app se ha abierto desde fuera para apuntar algo: widget, control de
    /// «Dictar gasto», Siri o el Atajo de Apple Pay. El gasto que salga de ahí
    /// se cuenta con el método de dentro (el formulario es `manual`), así que
    /// sin esto el widget y los controles no aparecían nunca.
    case entradaExterna(EntradaExterna)
    /// Un cargo que la app ha creado sola a partir de una regla recurrente. Va
    /// aparte de `expense_added`: ese es un evento clave y cuenta lo que apunta
    /// el usuario, y además marcaría como activo un día en que no hizo nada.
    case recurringExpenseCreated
    /// Una importación de CSV terminada, una vez por importación y no por fila.
    case csvImported

    /// El sink de Firebase traduce este evento a su evento canónico de pantalla;
    /// los demás destinos lo mandan tal cual. Los nombres viven aquí para que el
    /// sink no tenga que repetirlos a mano.
    static let screenViewedName = "screen_viewed"
    static let screenParameter = "screen"

    var name: String {
        switch self {
        case .onboardingStarted: return "onboarding_started"
        case .onboardingCompleted: return "onboarding_completed"
        case .expenseAdded: return "expense_added"
        case .voiceExpenseFailed: return "voice_expense_failed"
        case .paywallShown: return "paywall_shown"
        case .purchaseCompleted: return "purchase_completed"
        case .reviewPrompted: return "review_prompted"
        case .debtSettled: return "debt_settled"
        case .sessionStarted: return "session_started"
        case .sessionEnded: return "session_ended"
        case .screenViewed: return Self.screenViewedName
        case .aiCategoryCorrected: return "categoria_ia_corregida"
        case .budgetConfigured: return "presupuesto_configurado"
        case .budgetLimitReached: return "limite_alcanzado"
        case .extraIncomeLogged: return "ingreso_extra_registrado"
        case .supportContacted: return "contacto_soporte"
        case .emptyStateShown: return "sin_gastos_visto"
        case .emptyStateAction: return "sin_gastos_accion"
        case .microphonePermission: return "permiso_microfono"
        case .onboardingFirstExpense: return "onboarding_primer_gasto"
        case .onboardingStep: return "onboarding_step"
        case .entradaExterna: return "entrada_externa"
        case .recurringExpenseCreated: return "gasto_recurrente_creado"
        case .csvImported: return "importacion_csv"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .expenseAdded(let method, let category):
            return ["method": method.rawValue, "category": category]
        case .voiceExpenseFailed(let reason):
            return ["reason": reason.rawValue]
        case .paywallShown(let reason):
            return ["reason": reason]
        case .purchaseCompleted(let productId):
            return ["product_id": productId]
        case .sessionStarted(let deviceModel, let systemVersion):
            return ["device": deviceModel, "os_version": systemVersion]
        case .sessionEnded(let seconds):
            return ["duration_seconds": String(seconds)]
        case .screenViewed(let name):
            return [Self.screenParameter: name]
        case .aiCategoryCorrected(let from, let to):
            // Solo nombres de categoría: nunca el concepto ni el importe.
            return ["from": from, "to": to]
        case .budgetConfigured(let source):
            return ["source": source]
        case .budgetLimitReached(let percent):
            return ["percent": String(percent)]
        case .supportContacted(let reason):
            return ["reason": reason]
        case .emptyStateAction(let method):
            return ["method": method]
        case .microphonePermission(let granted):
            return ["granted": granted ? "true" : "false"]
        case .onboardingFirstExpense(let method):
            return ["method": method]
        case .onboardingStep(let index, let name):
            // Solo la página: nada del usuario.
            return ["index": String(index), "step": name]
        case .entradaExterna(let via):
            // `method` y no un nombre propio: es una dimensión que GA ya trae
            // y se puede consultar sin darla de alta.
            return ["method": via.rawValue]
        default:
            return [:]
        }
    }
}

enum ExpenseInputMethod: String, Sendable {
    case manual
    case voice
    /// Dictado a Siri desde fuera de la app. Acaba en el mismo parser que la
    /// voz de dentro, pero cuenta aparte: es la única forma de saber si los
    /// atajos sirven de algo o nadie los usa.
    case siri
    case recurring
    case widget
    case importCSV = "import"
    /// El Atajo de Apple Pay: comercio e importe llegan hechos. Antes se
    /// contaba como voz porque pasa por la misma confirmación.
    case applePay = "apple_pay"
}

/// Por qué un dictado no acabó en gasto.
enum FalloVoz: String, Sendable {
    /// El reconocimiento de voz no llegó a arrancar.
    case noArranca = "no_arranca"
    /// Se paró sin haber oído nada.
    case sinAudio = "sin_audio"
    /// Se entendió la frase pero no el importe: se lleva al formulario.
    case sinImporte = "sin_importe"
    /// El parser no sacó nada, o se le acabó el tiempo.
    case noProcesado = "no_procesado"
    /// Salió un importe, pero cero o por encima del tope de la voz.
    case importeNoValido = "importe_no_valido"
    case formato
    case categoriaAmbigua = "categoria_ambigua"
    /// El gasto estaba listo y falló al guardarse.
    case errorAlGuardar = "error_guardar"

    init(_ error: ParserError) {
        switch error {
        case .noAmountFound: self = .sinImporte
        case .emptyInput: self = .sinAudio
        case .ambiguousCategory: self = .categoriaAmbigua
        case .invalidFormat: self = .formato
        }
    }
}

/// Desde dónde se abrió la app para apuntar algo.
enum EntradaExterna: String, Sendable {
    /// El widget, o su botón de añadir.
    case widget
    /// El control «Dictar gasto»: Centro de Control, pantalla bloqueada o
    /// Botón de Acción.
    case controlDictar = "control_dictar"
    /// Una frase dictada a Siri o escrita en un Atajo.
    case siri
    case applePay = "apple_pay"
}

// MARK: - Traducción a Firebase

extension AnalyticsEvent {
    /// Parámetros que Firebase tiene que recibir como número. Todo lo demás
    /// viaja como texto; un número en texto no sirve para una métrica de GA,
    /// que suma y promedia (la duración de sesión llegaba así y no se podía
    /// usar).
    static let parametrosNumericos: Set<String> = ["duration_seconds"]

    /// Lo que se entrega a `Analytics.logEvent` para un evento con este nombre
    /// y estos parámetros. Función pura para poder probarla sin Firebase.
    ///
    /// Las pantallas se traducen al evento canónico `screen_view`: el informe
    /// de Pantallas solo se llena con él. Llevan además la clase y el nombre
    /// repetido en `pantalla`, un parámetro propio. En iOS 27 el SDK pierde
    /// el nombre de pantalla del `screen_view` manual —llega `(not set)` con
    /// el mismo binario que en iOS 26 llega bien— y `pantalla` no lo toca.
    static func paraFirebase(nombre: String, parametros: [String: String]) -> (nombre: String, parametros: [String: Any]) {
        if nombre == screenViewedName, let pantalla = parametros[screenParameter] {
            return ("screen_view", [
                "screen_name": pantalla,
                "screen_class": pantalla,
                "pantalla": pantalla,
            ])
        }
        var salida: [String: Any] = [:]
        for (clave, valor) in parametros {
            if parametrosNumericos.contains(clave), let numero = Int(valor) {
                salida[clave] = numero
            } else {
                salida[clave] = valor
            }
        }
        return (nombre, salida)
    }
}

/// Destino de los eventos. Permite enchufar Firebase Analytics (o cualquier otro)
/// sin tocar los puntos de llamada.
protocol AnalyticsSink: Sendable {
    func send(name: String, parameters: [String: String])
    func setUserProperty(_ value: String?, for name: String)
    /// Corta de raíz la recogida del destino, no solo el envío de eventos
    /// propios (sesiones, pantallas y demás automatismos del SDK incluidos).
    func setCollectionEnabled(_ enabled: Bool)
}

extension AnalyticsSink {
    func setCollectionEnabled(_ enabled: Bool) {}
}

/// Sink por defecto: deja rastro en la consola unificada de Apple. No sale nada
/// del dispositivo, así que no cambia el perfil de privacidad de la app.
struct OSLogAnalyticsSink: AnalyticsSink {
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "Analytics")

    func send(name: String, parameters: [String: String]) {
        logger.info("📊 \(name, privacy: .public) \(parameters.description, privacy: .public)")
    }

    func setUserProperty(_ value: String?, for name: String) {
        logger.info("📊 prop \(name, privacy: .public) = \(value ?? "nil", privacy: .public)")
    }
}

@MainActor
@Observable
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var sinks: [any AnalyticsSink] = [OSLogAnalyticsSink()]
    /// Destinos que envían datos fuera del dispositivo. Se separan del resto
    /// para poder callarlos sin perder el rastro en la consola local.
    private var remoteSinks: [any AnalyticsSink] = []
    private let defaults = UserDefaults.standard

    private enum Key {
        static let firstOpen = "analytics.firstOpenDate"
        static let activeDays = "analytics.activeDays"       // ["yyyy-MM-dd"]
        static let expenseCount = "analytics.expenseCount"
        static let sessionDays = "analytics.sessionDays"     // ["yyyy-MM-dd"] → DAU/MAU
        static let sessionCount = "analytics.sessionCount"
        static let excludeDevice = "analytics.excludeDevice"
        static let installVersion = "analytics.installVersion"
    }

    /// Inicio de la sesión en curso, para poder medir su duración.
    @ObservationIgnored private var sessionStart: Date?

    private init() {}

    /// Añade un destino adicional (p. ej. Firebase Analytics) en el arranque.
    func register(sink: any AnalyticsSink) {
        sinks.append(sink)
        remoteSinks.append(sink)
    }

    // MARK: - Exclusión de dispositivos propios

    /// Este dispositivo no cuenta para las métricas.
    ///
    /// Con ~16 descargas al mes, el uso diario del propio desarrollador domina
    /// cualquier agregado: sin esto, los datos confirman las hipótesis de quien
    /// las escribió. En DEBUG está excluido siempre; en la build de la App Store
    /// se activa a mano desde Ajustes, que es lo que permite excluir también el
    /// móvil de uso diario y el de cualquier tester.
    var isDeviceExcluded: Bool {
        #if DEBUG
        return true
        #else
        return defaults.bool(forKey: Key.excludeDevice)
        #endif
    }

    func setDeviceExcluded(_ excluded: Bool) {
        defaults.set(excluded, forKey: Key.excludeDevice)
        applyExclusionToRemoteSinks()
    }

    /// Corta la recogida en los destinos remotos. Llamar al arrancar y al
    /// cambiar el ajuste.
    func applyExclusionToRemoteSinks() {
        for sink in remoteSinks {
            sink.setCollectionEnabled(!isDeviceExcluded)
        }
    }

    func track(_ event: AnalyticsEvent) {
        // El sink local sigue registrando siempre: sirve para depurar sin
        // ensuciar las métricas de producto.
        guard !isDeviceExcluded else {
            for sink in sinks where !(sink is FirebaseAnalyticsSink) {
                sink.send(name: event.name, parameters: event.parameters)
            }
            recordLocalCounters(for: event)
            return
        }

        for sink in sinks {
            sink.send(name: event.name, parameters: event.parameters)
        }

        recordLocalCounters(for: event)
    }

    /// Contadores locales (racha de días activos, total de gastos). Se llevan
    /// aunque el dispositivo esté excluido: son para la propia app, no salen fuera.
    private func recordLocalCounters(for event: AnalyticsEvent) {
        if case .expenseAdded = event {
            recordActiveDay()
            defaults.set(defaults.integer(forKey: Key.expenseCount) + 1, forKey: Key.expenseCount)
        }
    }

    // MARK: - Sesiones

    /// Arranca la sesión: emite el evento con dispositivo y versión de iOS (lo
    /// que hace falta para decidir qué soportar) y anota el día como activo.
    func startSession() {
        sessionStart = Date()
        defaults.set(defaults.integer(forKey: Key.sessionCount) + 1, forKey: Key.sessionCount)
        recordSessionDay()

        let device = UIDevice.current
        track(.sessionStarted(
            deviceModel: Self.hardwareIdentifier,
            systemVersion: device.systemVersion
        ))
    }

    /// Cierra la sesión al pasar a background.
    func endSession() {
        guard let sessionStart else { return }
        let seconds = Int(Date().timeIntervalSince(sessionStart))
        self.sessionStart = nil
        guard seconds > 0 else { return }
        track(.sessionEnded(seconds: seconds))
    }

    /// Vuelta desde background: si la sesión se cerró, empieza otra. La primera
    /// activación tras el lanzamiento no cuenta doble porque `startSession` ya
    /// dejó `sessionStart` puesto.
    func resumeSessionIfNeeded() {
        guard sessionStart == nil else { return }
        startSession()
    }

    var totalSessions: Int {
        defaults.integer(forKey: Key.sessionCount)
    }

    /// Días distintos con al menos una apertura. Base local de DAU/MAU: el
    /// agregado real lo da Firebase, esto sirve para verlo sin salir de la app.
    var sessionDays: [String] {
        defaults.stringArray(forKey: Key.sessionDays) ?? []
    }

    var monthlyActiveDays: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return sessionDays.filter { day in
            guard let date = Formatters.date(from: day) else { return false }
            return date >= cutoff
        }.count
    }

    /// Identificador de hardware ("iPhone16,1"). No identifica a la persona.
    private nonisolated static var hardwareIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            partial.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "unknown" : identifier
    }

    private func recordSessionDay() {
        let today = Formatters.localDayString(from: Date())
        var days = sessionDays
        guard !days.contains(today) else { return }
        days.append(today)
        defaults.set(Array(days.suffix(90)), forKey: Key.sessionDays)
    }

    // MARK: - Umbrales de presupuesto

    /// Emite `limite_alcanzado` la primera vez que el gasto del mes cruza el 80 %
    /// y el 100 % del presupuesto. Una vez por umbral y mes: si no, saltaría en
    /// cada refresco de la Home.
    func trackBudgetThresholdIfCrossed(spent: Double, budget: Double?) {
        guard let budget, budget > 0 else { return }
        let percent = spent / budget
        let month = Formatters.currentMonthString()

        for threshold in [100, 80] where percent >= Double(threshold) / 100 {
            let key = "analytics.budgetThreshold.\(month).\(threshold)"
            guard !defaults.bool(forKey: key) else { continue }
            defaults.set(true, forKey: key)
            track(.budgetLimitReached(percent: threshold))
            return  // solo el umbral más alto alcanzado
        }
    }

    // MARK: - Retención (calculada en local)

    /// Marca el primer arranque y la versión con la que fue. Idempotente.
    func registerFirstOpenIfNeeded() {
        if defaults.string(forKey: Key.installVersion) == nil {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            defaults.set(
                Self.versionDeInstalacion(yaHabiaArrancado: defaults.object(forKey: Key.firstOpen) != nil, actual: version),
                forKey: Key.installVersion
            )
        }
        guard defaults.object(forKey: Key.firstOpen) == nil else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: Key.firstOpen)
    }

    /// La versión con la que este dispositivo empezó a usar la app, para medir
    /// la retención según con cuál se estrenó cada uno. Quien ya la usaba antes
    /// de que existiera este dato no tiene forma de saber con cuál empezó.
    static func versionDeInstalacion(yaHabiaArrancado: Bool, actual: String) -> String {
        yaHabiaArrancado ? "anterior_a_2.4.0" : actual
    }

    /// De dónde viene la instalación (App Store, TestFlight y App Review, o
    /// Xcode), para poder quitar de las cifras a App Review, que cuenta como
    /// usuario: el 8 % de las altas.
    func registrarEntorno() async {
        let entorno = await EntornoApp.actual()
        for sink in sinks {
            sink.setUserProperty(entorno, for: "entorno")
        }
    }

    var daysSinceFirstOpen: Int? {
        guard let stamp = defaults.object(forKey: Key.firstOpen) as? Double else { return nil }
        let first = Date(timeIntervalSince1970: stamp)
        return Calendar.current.dateComponents([.day], from: first, to: Date()).day
    }

    /// Días distintos con al menos un gasto registrado.
    var activeDays: [String] {
        defaults.stringArray(forKey: Key.activeDays) ?? []
    }

    var totalExpensesLogged: Int {
        defaults.integer(forKey: Key.expenseCount)
    }

    /// Métrica norte: días con gasto en los últimos 7.
    var activeDaysThisWeek: Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return activeDays.filter { day in
            guard let date = Formatters.date(from: day) else { return false }
            return date >= cutoff
        }.count
    }

    /// true si el usuario cumple la métrica norte (3+ días por semana).
    var isHabitualUser: Bool {
        activeDaysThisWeek >= 3
    }

    /// Retención simple: ¿seguía activo en D1 / D7 / D30?
    func isRetained(dayOffset: Int) -> Bool {
        guard let stamp = defaults.object(forKey: Key.firstOpen) as? Double else { return false }
        let first = Date(timeIntervalSince1970: stamp)
        guard let target = Calendar.current.date(byAdding: .day, value: dayOffset, to: first) else {
            return false
        }
        let targetDay = Formatters.localDayString(from: target)
        return activeDays.contains(targetDay)
    }

    /// Sube las propiedades derivadas al sink (segmentación sin datos personales).
    func syncUserProperties() {
        for sink in sinks {
            sink.setUserProperty(isHabitualUser ? "habitual" : "casual", for: "usage_tier")
            sink.setUserProperty(String(totalExpensesLogged), for: "expenses_logged")
            sink.setUserProperty(String(monthlyActiveDays), for: "active_days_30")
            sink.setUserProperty(defaults.string(forKey: Key.installVersion), for: "version_instalacion")
        }
    }

    private func recordActiveDay() {
        let today = Formatters.localDayString(from: Date())
        var days = activeDays
        guard !days.contains(today) else { return }
        days.append(today)
        // 90 días es de sobra para D30 y para la métrica semanal.
        defaults.set(Array(days.suffix(90)), forKey: Key.activeDays)
    }
}
