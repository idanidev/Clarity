// NotificationsView.swift
// Notifications settings with actual scheduling

import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @AppStorage("notifications.pushEnabled") private var pushEnabled = false
    @AppStorage("notifications.weeklyReminder") private var weeklyReminder = false
    @AppStorage("notifications.budgetAlerts") private var budgetAlerts = true
    @AppStorage("notifications.recurringReminders") private var recurringReminders = true
    @AppStorage("notifications.endOfMonthReminder") private var endOfMonthReminder = false

    // Keys kept as "daily*" for backward-compat; now shared with weekly reminder
    @AppStorage("notifications.dailyHour") private var dailyHour = 20
    @AppStorage("notifications.dailyMinute") private var dailyMinute = 0
    // weekday: 1=domingo, 2=lunes, ..., 7=sábado (Calendar convention)
    @AppStorage("notifications.weeklyDay") private var weeklyDay = 1

    private let weekdayNames = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]

    private enum NotificationID {
        static let weekly = "clarity.weekly.reminder"
        static let endOfMonth = "clarity.endofmonth.reminder"
    }

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showTimePicker = false
    @State private var selectedTime = Date()

    var body: some View {
        List {
            // Push Notifications Toggle
            Section {
                Toggle(String(localized: "notifications.push.toggle", defaultValue: "Notificaciones Push"), isOn: $pushEnabled)
                    .onChange(of: pushEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        } else {
                            cancelAllNotifications()
                        }
                        HapticManager.shared.selection()
                    }

                if notificationStatus == .denied {
                    Button(String(localized: "notifications.openSystemSettings", defaultValue: "Abrir Ajustes del Sistema")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.blue)
                }
            } footer: {
                if notificationStatus == .denied {
                    Text(String(localized: "notifications.push.denied", defaultValue: "Las notificaciones están desactivadas. Actívalas en Ajustes."))
                        .foregroundStyle(.red)
                } else {
                    Text(String(localized: "notifications.push.footer", defaultValue: "Permite que Clarity te envíe recordatorios"))
                }
            }

            // Weekly Reminder
            Section {
                Toggle(String(localized: "notifications.weekly.toggle", defaultValue: "Recordatorio Semanal"), isOn: $weeklyReminder)
                    .onChange(of: weeklyReminder) { _, newValue in
                        HapticManager.shared.selection()
                        if newValue && pushEnabled {
                            scheduleWeeklyReminder()
                        } else {
                            cancelWeeklyReminder()
                        }
                    }

                if weeklyReminder {
                    Picker(String(localized: "notifications.weekly.dayPicker", defaultValue: "Día de la semana"), selection: $weeklyDay) {
                        ForEach(1...7, id: \.self) { day in
                            Text(weekdayNames[day - 1]).tag(day)
                        }
                    }
                    .onChange(of: weeklyDay) { _, _ in
                        if pushEnabled { scheduleWeeklyReminder() }
                    }

                    // Time Picker Button
                    Button {
                        var components = DateComponents()
                        components.hour = dailyHour
                        components.minute = dailyMinute
                        selectedTime = Calendar.current.date(from: components) ?? Date()
                        showTimePicker = true
                    } label: {
                        HStack {
                            Text(String(localized: "notifications.weekly.reminderTime", defaultValue: "Hora del recordatorio"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(String(format: "%02d:%02d", dailyHour, dailyMinute))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "notifications.weekly.header", defaultValue: "Recordatorio Semanal"))
            } footer: {
                if weeklyReminder {
                    Text(
                        "Recibirás un recordatorio cada \(weekdayNames[(weeklyDay - 1)]) a las \(String(format: "%02d:%02d", dailyHour, dailyMinute))"
                    )
                }
            }

            // Other Alerts
            Section {
                Toggle(String(localized: "notifications.alerts.budget", defaultValue: "Alertas de Presupuesto"), isOn: $budgetAlerts)
                    .onChange(of: budgetAlerts) { _, _ in HapticManager.shared.selection() }
                Toggle(String(localized: "notifications.alerts.recurring", defaultValue: "Gastos Recurrentes"), isOn: $recurringReminders)
                    .onChange(of: recurringReminders) { _, _ in HapticManager.shared.selection() }

                let isSalaryFixed =
                    UserDataManager.shared.userDocument?.settings?.isSalaryRecurring == true
                Toggle(String(localized: "notifications.alerts.endOfMonth", defaultValue: "Recordatorio Fin de Mes"), isOn: $endOfMonthReminder)
                    .onChange(of: endOfMonthReminder) { _, newValue in
                        HapticManager.shared.selection()
                        if newValue && pushEnabled && !isSalaryFixed {
                            scheduleEndOfMonthReminder()
                        } else {
                            cancelEndOfMonthReminder()
                        }
                    }
                    .disabled(isSalaryFixed)

                if isSalaryFixed {
                    NavigationLink(destination: SalarySettingsStandaloneView()) {
                        Label(
                            String(localized: "notifications.alerts.fixedSalaryHint", defaultValue: "Nómina Fija activada — toca para cambiarla"),
                            systemImage: "arrow.right.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(Color.clarityPrimary)
                    }
                } else if endOfMonthReminder {
                    Text(
                        "Recibirás un recordatorio el día 28 de cada mes para configurar tus ingresos del mes siguiente."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "notifications.alerts.header", defaultValue: "Alertas"))
            } footer: {
                Text(String(localized: "notifications.alerts.footer", defaultValue: "Te avisaremos cuando superes el 80% de tu presupuesto"))
            }

        }
        .navigationTitle(String(localized: "notifications.navigationTitle", defaultValue: "Notificaciones"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTimePicker) {
            NavigationStack {
                DatePicker(
                    String(localized: "notifications.timePicker.label", defaultValue: "Hora del recordatorio"),
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle(String(localized: "notifications.timePicker.title", defaultValue: "Seleccionar Hora"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel", defaultValue: "Cancelar")) {
                            showTimePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.save", defaultValue: "Guardar")) {
                            let components = Calendar.current.dateComponents(
                                [.hour, .minute], from: selectedTime)
                            dailyHour = components.hour ?? 20
                            dailyMinute = components.minute ?? 0
                            showTimePicker = false

                            if weeklyReminder && pushEnabled {
                                scheduleWeeklyReminder()
                            }
                            HapticManager.shared.notification(.success)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            checkNotificationStatus()
            migrateOldNotifications()
            refreshActiveNotifications()
        }
    }

    // MARK: - Notification Functions

    /// Migra notificaciones antiguas: elimina IDs obsoletos y corrige el trigger diario→semanal
    private func migrateOldNotifications() {
        let center = UNUserNotificationCenter.current()
        let knownIDs: Set<String> = [NotificationID.weekly, NotificationID.endOfMonth]

        center.getPendingNotificationRequests { requests in
            // 1. Eliminar IDs desconocidos (daily reminders antiguos, etc.)
            let staleIDs = requests.map(\.identifier).filter { !knownIDs.contains($0) }
            if !staleIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: staleIDs)
            }

            // 2. Si el reminder semanal existe pero el trigger NO tiene weekday → era diario, reprogramar
            if let weeklyRequest = requests.first(where: { $0.identifier == NotificationID.weekly }),
               let calTrigger = weeklyRequest.trigger as? UNCalendarNotificationTrigger,
               calTrigger.dateComponents.weekday == nil
            {
                DispatchQueue.main.async {
                    if pushEnabled && weeklyReminder {
                        scheduleWeeklyReminder()
                    } else {
                        cancelWeeklyReminder()
                    }
                }
            }
        }
    }

    /// Re-programa notificaciones activas para asegurar que el contenido esté al día.
    /// Resuelve el bug de notificación vacía: el contenido se fijó al programarla,
    /// y cambios en el código no actualizan notificaciones ya registradas en el sistema.
    private func refreshActiveNotifications() {
        guard pushEnabled else { return }
        if weeklyReminder { scheduleWeeklyReminder() }
        if endOfMonthReminder { scheduleEndOfMonthReminder() }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
                if settings.authorizationStatus == .denied {
                    pushEnabled = false
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
            granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationStatus = .authorized
                    if weeklyReminder {
                        scheduleWeeklyReminder()
                    }
                } else {
                    pushEnabled = false
                    notificationStatus = .denied
                }
            }
        }
    }

    private func scheduleWeeklyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.weekly])

        let content = UNMutableNotificationContent()
        content.title = "Recordatorio semanal"
        content.body = "Recuerda revisar tus gastos de esta semana 📊"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = weeklyDay > 0 ? weeklyDay : 1
        dateComponents.hour = dailyHour
        dateComponents.minute = dailyMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationID.weekly,
            content: content,
            trigger: trigger
        )

        center.add(request) { _ in }
    }

    private func cancelWeeklyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [NotificationID.weekly])
    }

    private func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func scheduleEndOfMonthReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.endOfMonth])

        let content = UNMutableNotificationContent()
        content.title = "📅 Prepara el próximo mes"
        // Genérico: el trigger es repeats=true así que el nombre del mes hardcoded quedaría obsoleto.
        content.body = "Configura tus ingresos del próximo mes para que Clarity esté listo desde el día 1."
        content.sound = .default

        // Fire on day 28 of each month at 9:00am
        var dateComponents = DateComponents()
        dateComponents.day = 28
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationID.endOfMonth,
            content: content,
            trigger: trigger
        )

        center.add(request) { _ in }
    }

    private func cancelEndOfMonthReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [NotificationID.endOfMonth])
    }

    /// Returns the name of the next calendar month in Spanish
    private func nextMonthName() -> String {
        Self.nextMonthNameStatic()
    }

    private static func nextMonthNameStatic() -> String {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        return Formatters.fullMonthName(from: nextMonth)
    }

    // MARK: - App Launch Refresh

    /// Call from app launch to keep notification content up to date.
    /// Recreates active notifications so the body reflects the current month.
    static func refreshOnLaunch() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notifications.pushEnabled") else { return }

        let center = UNUserNotificationCenter.current()

        if defaults.bool(forKey: "notifications.weeklyReminder") {
            let weeklyDay = defaults.integer(forKey: "notifications.weeklyDay")
            let hour = defaults.integer(forKey: "notifications.dailyHour")
            let minute = defaults.integer(forKey: "notifications.dailyMinute")

            center.removePendingNotificationRequests(withIdentifiers: ["clarity.weekly.reminder"])
            let content = UNMutableNotificationContent()
            content.title = "Recordatorio semanal"
            content.body = "Recuerda revisar tus gastos de esta semana"
            content.sound = .default
            var dc = DateComponents()
            dc.weekday = weeklyDay == 0 ? 1 : weeklyDay
            dc.hour = hour == 0 ? 20 : hour
            dc.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            center.add(UNNotificationRequest(identifier: "clarity.weekly.reminder", content: content, trigger: trigger))
        }

        if defaults.bool(forKey: "notifications.endOfMonthReminder") {
            center.removePendingNotificationRequests(withIdentifiers: ["clarity.endofmonth.reminder"])
            let content = UNMutableNotificationContent()
            content.title = "Prepara el próximo mes"
            content.body = "Configura tus ingresos de \(nextMonthNameStatic()) para que Clarity esté listo desde el día 1."
            content.sound = .default
            var dc = DateComponents()
            dc.day = 28
            dc.hour = 9
            dc.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            center.add(UNNotificationRequest(identifier: "clarity.endofmonth.reminder", content: content, trigger: trigger))
        }
    }

    // MARK: - Inactivity Reminder

    private static let inactivityID = "clarity.inactivity.reminder"

    /// Schedules a local notification if the user hasn't added an expense in 7+ days.
    /// Call from app launch after expenses are loaded.
    static func scheduleInactivityReminderIfNeeded(lastExpenseDate: Date?) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notifications.pushEnabled") else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [inactivityID])

        guard let lastDate = lastExpenseDate else { return }
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        guard daysSince >= 7 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Te echamos de menos"
        content.body = "Llevas \(daysSince) días sin registrar gastos. Mantén tus finanzas al día."
        content.sound = .default

        // Fire tomorrow at 10:00 AM (sin .day el trigger podía disparar en minutos)
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) else { return }
        var dc = cal.dateComponents([.year, .month, .day], from: tomorrow)
        dc.hour = 10
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
        center.add(UNNotificationRequest(identifier: inactivityID, content: content, trigger: trigger))
    }

    /// Cancel inactivity reminder (call after adding an expense).
    static func cancelInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [inactivityID])
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
