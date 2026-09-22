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

    // Recordatorio diario (#57): el hábito es lo que sostiene una app de gastos.
    // Apagado por defecto y con claves nuevas (ver `RecordatoriosService.Clave`).
    @AppStorage(RecordatoriosService.Clave.diario) private var dailyCheckIn = false
    @AppStorage(RecordatoriosService.Clave.horaDiario) private var dailyCheckInHour = RecordatorioDiario.horaPorDefecto
    @AppStorage(RecordatoriosService.Clave.minutoDiario) private var dailyCheckInMinute = 0

    private let weekdayNames = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]

    private enum NotificationID {
        static let endOfMonth = "clarity.endofmonth.reminder"
        static let daily = "clarity.daily.reminder"
    }

    /// Qué hora se está cambiando en la hoja del selector: la misma hoja sirve
    /// para el resumen semanal y para el diario.
    private enum HoraEditable: String, Identifiable {
        case semanal, diaria
        var id: String { rawValue }
    }

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var horaEditando: HoraEditable?
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
                    .foregroundStyle(Color.clarityPrimary)
                }
            } footer: {
                if notificationStatus == .denied {
                    Text(String(localized: "notifications.push.denied", defaultValue: "Las notificaciones están desactivadas. Actívalas en Ajustes."))
                        .foregroundStyle(Color.error)
                } else {
                    Text(String(localized: "notifications.push.footer", defaultValue: "Permite que Clarity te envíe recordatorios"))
                }
            }

            // Resumen semanal (#57): antes solo recordaba; ahora cuenta lo que
            // llevas. El texto lo rehace `RecordatoriosService` con los datos al día.
            Section {
                Toggle(String(localized: "notifications.weekly.toggle", defaultValue: "Resumen semanal"), isOn: $weeklyReminder)
                    .onChange(of: weeklyReminder) { _, _ in
                        HapticManager.shared.selection()
                        // Programa o quita según el interruptor (y las push).
                        RecordatoriosService.shared.reprogramarAhora()
                    }

                if weeklyReminder {
                    Picker(String(localized: "notifications.weekly.dayPicker", defaultValue: "Día de la semana"), selection: $weeklyDay) {
                        ForEach(1...7, id: \.self) { day in
                            Text(weekdayNames[day - 1]).tag(day)
                        }
                    }
                    .onChange(of: weeklyDay) { _, _ in
                        RecordatoriosService.shared.reprogramarAhora()
                    }

                    filaHora(.semanal, hora: dailyHour, minuto: dailyMinute)
                }
            } header: {
                Text(String(localized: "notifications.weekly.header", defaultValue: "Resumen semanal"))
            } footer: {
                if weeklyReminder {
                    Text(String(
                        localized: "notifications.weekly.footer",
                        defaultValue: "Cada \(weekdayNames[weeklyDay - 1].lowercased()) a las \(String(format: "%02d:%02d", dailyHour, dailyMinute)) te contamos cuánto llevas gastado en la semana y cómo va frente a la anterior."
                    ))
                }
            }

            // Recordatorio diario (#57)
            Section {
                Toggle(String(localized: "notifications.daily.toggle", defaultValue: "Recordatorio diario"), isOn: $dailyCheckIn)
                    .onChange(of: dailyCheckIn) { _, activo in
                        HapticManager.shared.selection()
                        if activo && !pushEnabled {
                            // Encender las push pide el permiso (ver su
                            // `onChange`) y, si se concede, se programa todo.
                            pushEnabled = true
                        } else if activo {
                            RecordatoriosService.shared.reprogramarAhora()
                        } else {
                            // Quita los diarios y devuelve el de inactividad.
                            RecordatoriosService.shared.diarioApagado()
                        }
                    }

                if dailyCheckIn {
                    filaHora(.diaria, hora: dailyCheckInHour, minuto: dailyCheckInMinute)
                }
            } header: {
                Text(String(localized: "notifications.daily.header", defaultValue: "Recordatorio diario"))
            } footer: {
                if dailyCheckIn {
                    Text(String(
                        localized: "notifications.daily.footerOn",
                        defaultValue: "Cada día a las \(String(format: "%02d:%02d", dailyCheckInHour, dailyCheckInMinute)) te preguntamos si has tenido algún gasto. Si ese día ya has apuntado alguno, no te avisamos."
                    ))
                } else {
                    Text(String(
                        localized: "notifications.daily.footerOff",
                        defaultValue: "Un toque al día para que no se te acumulen los gastos sin apuntar."
                    ))
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
                    .foregroundStyle(Color.textSecondary)
                }
            } header: {
                Text(String(localized: "notifications.alerts.header", defaultValue: "Alertas"))
            } footer: {
                Text(String(localized: "notifications.alerts.footer", defaultValue: "Te avisaremos cuando superes el 80% de tu presupuesto"))
            }

        }
        .fondoClarity()
        .navigationTitle(String(localized: "notifications.navigationTitle", defaultValue: "Notificaciones"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $horaEditando) { cual in
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
                            horaEditando = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.save", defaultValue: "Guardar")) {
                            let components = Calendar.current.dateComponents(
                                [.hour, .minute], from: selectedTime)
                            switch cual {
                            case .semanal:
                                dailyHour = components.hour ?? 20
                                dailyMinute = components.minute ?? 0
                            case .diaria:
                                dailyCheckInHour = components.hour ?? RecordatorioDiario.horaPorDefecto
                                dailyCheckInMinute = components.minute ?? 0
                            }
                            horaEditando = nil

                            RecordatoriosService.shared.reprogramarAhora()
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

    // MARK: - Hora

    /// Fila con la hora de un recordatorio; al tocarla abre el selector.
    private func filaHora(_ cual: HoraEditable, hora: Int, minuto: Int) -> some View {
        Button {
            var components = DateComponents()
            components.hour = hora
            components.minute = minuto
            selectedTime = Calendar.current.date(from: components) ?? Date()
            horaEditando = cual
        } label: {
            HStack {
                Text(String(localized: "notifications.weekly.reminderTime", defaultValue: "Hora del recordatorio"))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%02d:%02d", hora, minuto))
                    .monospacedDigit()
                    .foregroundStyle(Color.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: - Notification Functions

    /// Migra notificaciones antiguas: elimina IDs obsoletos.
    ///
    /// Antes corregía también un semanal registrado sin día de la semana (el
    /// antiguo diario). Ya no hace falta, y además los semanales de ahora son
    /// sueltos, con fecha completa y sin `weekday`: esa comprobación los daría
    /// por viejos cada vez. `RecordatoriosService` rehace el semanal al
    /// arrancar y al abrir esta pantalla, así que cualquier formato antiguo
    /// queda sustituido.
    private func migrateOldNotifications() {
        let center = UNUserNotificationCenter.current()
        let knownIDs = RecordatoriosService.Identificador.todos

        center.getPendingNotificationRequests { requests in
            let staleIDs = requests.map(\.identifier).filter { !knownIDs.contains($0) }
            if !staleIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: staleIDs)
            }
        }
    }

    /// Re-programa notificaciones activas para asegurar que el contenido esté al día.
    /// Resuelve el bug de notificación vacía: el contenido se fijó al programarla,
    /// y cambios en el código no actualizan notificaciones ya registradas en el sistema.
    private func refreshActiveNotifications() {
        guard pushEnabled else { return }
        // Resumen semanal y diario, con los datos de ahora.
        RecordatoriosService.shared.reprogramarAhora()
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
                    // El semanal y el diario, si están encendidos.
                    RecordatoriosService.shared.reprogramarAhora()
                } else {
                    pushEnabled = false
                    notificationStatus = .denied
                }
            }
        }
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
        let center = UNUserNotificationCenter.current()

        // El recordatorio diario se retiró. Quien lo tuviera activo conserva la
        // notificación repetitiva ya registrada en el sistema, que sobrevive a
        // la actualización: hay que cancelarla explícitamente o seguiría sonando
        // cada día sin nada en Ajustes que la apague. Va antes del guard porque
        // también hay que limpiarla si entretanto desactivó las push.
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.daily])

        guard defaults.bool(forKey: "notifications.pushEnabled") else { return }

        // El resumen semanal (y el diario) ya no se programan aquí: los rehace
        // `RecordatoriosService.arrancar()` con las cifras de la caché.

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

    private static let inactivityThresholdDays = 7
    private static let inactivityRenotifyDays = 7  // re-notifica cada 7 días si sigue inactivo

    /// Programa recordatorio de inactividad basado en el ÚLTIMO gasto registrado.
    /// Reglas:
    /// - Si han pasado >= 7 días desde último gasto → notifica mañana 10:00.
    /// - Si han pasado < 7 días → programa para el día exacto en que cumpla 7 días, 10:00.
    /// - Si no hay ningún gasto registrado → 7 días desde la fecha actual.
    /// - Después del primer fire, programa re-notif cada `inactivityRenotifyDays`.
    /// Llamar en cada app launch tras cargar gastos.
    static func scheduleInactivityReminderIfNeeded(lastExpenseDate: Date?) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notifications.pushEnabled") else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [inactivityID, inactivityRecurringID])

        // Con el recordatorio diario encendido este sobra: el diario ya pregunta
        // cada día, y juntos llegarían a sonar los dos el mismo día. Al apagar
        // el diario, `RecordatoriosService.diarioApagado()` vuelve a llamar aquí.
        guard !defaults.bool(forKey: RecordatoriosService.Clave.diario) else { return }

        let cal = Calendar.current
        let now = Date()
        // Anchor: si nunca registró gastos, usamos "hoy" (notif en 7 días).
        let anchor = lastExpenseDate ?? now

        // Día objetivo del primer aviso = anchor + threshold
        guard let targetDay = cal.date(byAdding: .day, value: inactivityThresholdDays, to: anchor) else { return }

        // Si el targetDay ya pasó, fire mañana 10:00; si no, ese día 10:00.
        let fireDay = targetDay < now ? (cal.date(byAdding: .day, value: 1, to: now) ?? now) : targetDay

        var dc = cal.dateComponents([.year, .month, .day], from: fireDay)
        dc.hour = 10
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)

        // Días reales que llevará sin gastos en el momento del fire (más preciso que el +1).
        let daysAtFire = max(
            inactivityThresholdDays,
            cal.dateComponents([.day], from: anchor, to: fireDay).day ?? inactivityThresholdDays
        )

        let content = UNMutableNotificationContent()
        content.title = "Te echamos de menos"
        if lastExpenseDate == nil {
            content.body = "Aún no has registrado ningún gasto. Empieza hoy con uno por voz: \"Clarity, añade un gasto\"."
        } else {
            content.body = "Llevas \(daysAtFire) días sin registrar gastos. Mantén tus finanzas al día."
        }
        content.sound = .default
        center.add(UNNotificationRequest(identifier: inactivityID, content: content, trigger: trigger))

        // Re-notif recurrente cada N días tras el primer aviso (mientras siga sin abrir/registrar).
        scheduleRecurringInactivity(after: fireDay)
    }

    private static let inactivityRecurringID = "clarity.inactivity.recurring"

    private static func scheduleRecurringInactivity(after firstFire: Date) {
        let cal = Calendar.current
        guard let secondFire = cal.date(byAdding: .day, value: inactivityRenotifyDays, to: firstFire) else { return }
        var dc = cal.dateComponents([.year, .month, .day], from: secondFire)
        dc.hour = 10
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Sigues sin registrar gastos"
        content.body = "Han pasado más de 2 semanas. Un toque al + y vuelves a ordenar tu mes."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: inactivityRecurringID, content: content, trigger: trigger)
        )
    }

    /// Cancel inactivity reminder (call after adding an expense).
    static func cancelInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [inactivityID, inactivityRecurringID]
        )
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
