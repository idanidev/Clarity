// NotificationPermissionCoordinator.swift
// Pide el permiso de notificaciones DESPUÉS de que el usuario haya visto valor
// (su primer gasto registrado), no al abrir la app (#40 §2).

import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationPermissionCoordinator {
    static let shared = NotificationPermissionCoordinator()

    private enum Key {
        static let asked = "notifications.contextualPromptShown"
    }

    /// Gastos que hace falta registrar antes de proponer los recordatorios.
    private static let expensesBeforeAsking = 2

    /// La vista observa esto para presentar la propuesta.
    var shouldShowPrompt = false

    private let defaults = UserDefaults.standard

    private init() {}

    private var alreadyAsked: Bool {
        defaults.bool(forKey: Key.asked)
    }

    /// Llamar cuando la Home aparece. Decide en silencio si toca proponerlo.
    func evaluate() async {
        guard !alreadyAsked else { return }
        guard AnalyticsService.shared.totalExpensesLogged >= Self.expensesBeforeAsking else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            // Ya decidió por su cuenta en Ajustes: no volver a preguntar.
            defaults.set(true, forKey: Key.asked)
            return
        }

        shouldShowPrompt = true
    }

    /// El usuario acepta: pide el permiso del sistema y deja programado el
    /// recordatorio diario a la hora por defecto.
    func acceptAndRequest() async {
        defaults.set(true, forKey: Key.asked)
        shouldShowPrompt = false

        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false

        guard granted else { return }

        defaults.set(true, forKey: "notifications.pushEnabled")
        defaults.set(true, forKey: "notifications.dailyReminder")
        let hour = defaults.object(forKey: "notifications.dailyReminderHour") as? Int ?? 21
        let minute = defaults.integer(forKey: "notifications.dailyReminderMinute")
        NotificationsView.scheduleDailyReminderStatic(hour: hour, minute: minute)
    }

    func decline() {
        defaults.set(true, forKey: Key.asked)
        shouldShowPrompt = false
    }
}
