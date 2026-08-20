// AnalyticsService.swift
// Métricas de producto (#40 §4): onboarding, gastos por usuario, uso de voz y
// retención D1/D7/D30.
//
// La métrica norte es "usuarios que registran gastos 3+ días por semana", así
// que además de emitir eventos se llevan contadores locales — se pueden leer sin
// depender de ninguna consola externa.

import Foundation
import OSLog

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
    private let defaults = UserDefaults.standard

    private enum Key {
        static let firstOpen = "analytics.firstOpenDate"
        static let activeDays = "analytics.activeDays"       // ["yyyy-MM-dd"]
        static let expenseCount = "analytics.expenseCount"
    }

    private init() {}

    /// Añade un destino adicional (p. ej. Firebase Analytics) en el arranque.
    func register(sink: any AnalyticsSink) {
        sinks.append(sink)
    }

    func track(_ event: AnalyticsEvent) {
        for sink in sinks {
            sink.send(name: event.name, parameters: event.parameters)
        }

        if case .expenseAdded = event {
            recordActiveDay()
            defaults.set(defaults.integer(forKey: Key.expenseCount) + 1, forKey: Key.expenseCount)
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
