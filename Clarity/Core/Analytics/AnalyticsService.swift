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
    case voiceExpenseFailed(reason: String)
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
        case .screenViewed: return "screen_viewed"
        case .aiCategoryCorrected: return "categoria_ia_corregida"
        case .budgetConfigured: return "presupuesto_configurado"
        case .budgetLimitReached: return "limite_alcanzado"
        case .extraIncomeLogged: return "ingreso_extra_registrado"
        case .supportContacted: return "contacto_soporte"
        case .emptyStateShown: return "sin_gastos_visto"
        case .emptyStateAction: return "sin_gastos_accion"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .expenseAdded(let method, let category):
            return ["method": method.rawValue, "category": category]
        case .voiceExpenseFailed(let reason):
            return ["reason": reason]
        case .paywallShown(let reason):
            return ["reason": reason]
        case .purchaseCompleted(let productId):
            return ["product_id": productId]
        case .sessionStarted(let deviceModel, let systemVersion):
            return ["device": deviceModel, "os_version": systemVersion]
        case .sessionEnded(let seconds):
            return ["duration_seconds": String(seconds)]
        case .screenViewed(let name):
            return ["screen": name]
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
        default:
            return [:]
        }
    }
}

enum ExpenseInputMethod: String, Sendable {
    case manual
    case voice
    case recurring
    case widget
    case importCSV = "import"
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

    /// Marca el primer arranque. Idempotente.
    func registerFirstOpenIfNeeded() {
        guard defaults.object(forKey: Key.firstOpen) == nil else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: Key.firstOpen)
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
