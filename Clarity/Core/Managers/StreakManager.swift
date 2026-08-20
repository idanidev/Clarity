// StreakManager.swift
// Racha de días registrando gastos: el refuerzo positivo que sostiene el
// hábito diario (#40 §1).

import Foundation
import Observation

@MainActor
@Observable
final class StreakManager {
    static let shared = StreakManager()

    private enum Key {
        static let current = "streak.current"
        static let best = "streak.best"
        static let lastDay = "streak.lastDay"   // "yyyy-MM-dd"
    }

    private let defaults = UserDefaults.standard

    private(set) var current: Int
    private(set) var best: Int

    /// Se pone a true cuando la racha acaba de crecer, para que la UI celebre
    /// una sola vez. La vista lo baja al consumirlo.
    var justExtended = false

    private init() {
        self.current = defaults.integer(forKey: Key.current)
        self.best = defaults.integer(forKey: Key.best)
    }

    /// ¿Se ha registrado algún gasto hoy?
    var loggedToday: Bool {
        defaults.string(forKey: Key.lastDay) == Self.dayString(Date())
    }

    /// Llamar al guardar un gasto. Idempotente dentro del mismo día.
    func registerExpenseLogged(on date: Date = Date()) {
        let today = Self.dayString(date)
        let lastDay = defaults.string(forKey: Key.lastDay)

        guard lastDay != today else { return }

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)
        let wasYesterday = lastDay == yesterday.map(Self.dayString)

        current = wasYesterday ? current + 1 : 1
        best = max(best, current)
        justExtended = true

        defaults.set(current, forKey: Key.current)
        defaults.set(best, forKey: Key.best)
        defaults.set(today, forKey: Key.lastDay)
    }

    /// Recalcula la racha al abrir la app: si se saltó un día, vuelve a cero.
    func refreshOnLaunch(now: Date = Date()) {
        guard let lastDay = defaults.string(forKey: Key.lastDay) else { return }

        let calendar = Calendar.current
        let today = Self.dayString(now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now).map(Self.dayString)

        if lastDay != today && lastDay != yesterday {
            current = 0
            defaults.set(0, forKey: Key.current)
        }
    }

    /// Mensaje corto para la UI. nil = no hay racha que enseñar.
    var badgeText: String? {
        guard current >= 2 else { return nil }
        return "🔥 \(current) días seguidos"
    }

    private nonisolated static func dayString(_ date: Date) -> String {
        Formatters.localDayString(from: date)
    }
}
