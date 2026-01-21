// NotificationsView.swift
// Notifications settings with actual scheduling

import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @AppStorage("notifications.pushEnabled") private var pushEnabled = false
    @AppStorage("notifications.dailyReminder") private var dailyReminder = false
    @AppStorage("notifications.budgetAlerts") private var budgetAlerts = true
    @AppStorage("notifications.recurringReminders") private var recurringReminders = true
    
    @AppStorage("notifications.dailyHour") private var dailyHour = 20
    @AppStorage("notifications.dailyMinute") private var dailyMinute = 0
    
    // Hardcoded reminder message
    private let reminderMessage = "💰 ¡Registra tus gastos del día!"
    
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showTimePicker = false
    @State private var selectedTime = Date()
    
    var body: some View {
        List {
            // Push Notifications Toggle
            Section {
                Toggle("Notificaciones Push", isOn: $pushEnabled)
                    .onChange(of: pushEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        } else {
                            cancelAllNotifications()
                        }
                        HapticManager.shared.selection()
                    }
                
                if notificationStatus == .denied {
                    Button("Abrir Ajustes del Sistema") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.blue)
                }
            } footer: {
                if notificationStatus == .denied {
                    Text("Las notificaciones están desactivadas. Actívalas en Ajustes.")
                        .foregroundStyle(.red)
                } else {
                    Text("Permite que Clarity te envíe recordatorios")
                }
            }
            
            // Daily Reminder
            Section {
                Toggle("Recordatorio Diario", isOn: $dailyReminder)
                    .onChange(of: dailyReminder) { _, newValue in
                        HapticManager.shared.selection()
                        if newValue && pushEnabled {
                            scheduleDailyReminder()
                        } else {
                            cancelDailyReminder()
                        }
                    }
                
                if dailyReminder {
                    // Time Picker Button
                    Button {
                        // Initialize selectedTime with stored values
                        var components = DateComponents()
                        components.hour = dailyHour
                        components.minute = dailyMinute
                        selectedTime = Calendar.current.date(from: components) ?? Date()
                        showTimePicker = true
                    } label: {
                        HStack {
                            Text("Hora del recordatorio")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(String(format: "%02d:%02d", dailyHour, dailyMinute))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    // Show the hardcoded message (read-only)
                    HStack {
                        Text("Mensaje")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(reminderMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } header: {
                Text("Recordatorio Diario")
            } footer: {
                if dailyReminder {
                    Text("Recibirás un recordatorio todos los días a las \(String(format: "%02d:%02d", dailyHour, dailyMinute))")
                }
            }
            
            // Other Alerts
            Section {
                Toggle("Alertas de Presupuesto", isOn: $budgetAlerts)
                    .onChange(of: budgetAlerts) { _, _ in HapticManager.shared.selection() }
                Toggle("Gastos Recurrentes", isOn: $recurringReminders)
                    .onChange(of: recurringReminders) { _, _ in HapticManager.shared.selection() }
            } header: {
                Text("Alertas")
            } footer: {
                Text("Te avisaremos cuando superes el 80% de tu presupuesto")
            }
            
            // Debug Section (for testing)
            #if DEBUG
            Section {
                Button("🔔 Enviar Notificación de Prueba") {
                    sendTestNotification()
                }
                
                Button("📋 Ver Notificaciones Pendientes") {
                    listPendingNotifications()
                }
            } header: {
                Text("Debug")
            }
            #endif
        }
        .navigationTitle("Notificaciones")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTimePicker) {
            NavigationStack {
                DatePicker(
                    "Hora del recordatorio",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle("Seleccionar Hora")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") {
                            showTimePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") {
                            let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                            dailyHour = components.hour ?? 20
                            dailyMinute = components.minute ?? 0
                            showTimePicker = false
                            
                            // Reschedule notification with new time
                            if dailyReminder && pushEnabled {
                                scheduleDailyReminder()
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
        }
    }
    
    // MARK: - Notification Functions
    
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationStatus = .authorized
                    // Schedule daily reminder if enabled
                    if dailyReminder {
                        scheduleDailyReminder()
                    }
                } else {
                    pushEnabled = false
                    notificationStatus = .denied
                }
            }
        }
    }
    
    private func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        
        // Remove existing daily reminders first
        center.removePendingNotificationRequests(withIdentifiers: ["clarity.daily.reminder"])
        
        // Create content
        let content = UNMutableNotificationContent()
        content.title = "Clarity"
        content.body = reminderMessage
        content.sound = .default
        content.badge = 1
        
        // Create trigger for daily at specified time
        var dateComponents = DateComponents()
        dateComponents.hour = dailyHour
        dateComponents.minute = dailyMinute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "clarity.daily.reminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                print("✅ Daily reminder scheduled for \(dailyHour):\(String(format: "%02d", dailyMinute))")
            }
        }
    }
    
    private func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["clarity.daily.reminder"])
        print("🗑️ Daily reminder cancelled")
    }
    
    private func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ All notifications cancelled")
    }
    
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Clarity - Test"
        content.body = reminderMessage
        content.sound = .default
        
        // Trigger in 3 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "clarity.test", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                print("✅ Test notification scheduled (3 seconds)")
                DispatchQueue.main.async {
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }
    
    private func listPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📋 Pending notifications: \(requests.count)")
            for request in requests {
                print("  - \(request.identifier): \(request.trigger.debugDescription)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
