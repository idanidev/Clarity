// NotificationsView.swift
// Notifications settings

import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @AppStorage("notifications.pushEnabled") private var pushEnabled = false
    @AppStorage("notifications.weeklyReminder") private var weeklyReminder = true
    @AppStorage("notifications.budgetAlerts") private var budgetAlerts = true
    @AppStorage("notifications.recurringReminders") private var recurringReminders = true
    @AppStorage("notifications.customReminders") private var customReminders = true
    
    @AppStorage("notifications.weeklyDay") private var weeklyDay = 5 // Friday
    @AppStorage("notifications.weeklyHour") private var weeklyHour = 20
    @AppStorage("notifications.weeklyMinute") private var weeklyMinute = 0
    
    @AppStorage("notifications.customHour") private var customHour = 20
    @AppStorage("notifications.customMinute") private var customMinute = 0
    @AppStorage("notifications.customMessage") private var customMessage = "No olvides registrar tus gastos"
    
    private let weekDays = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    
    var body: some View {
        List {
            Section {
                Toggle("Notificaciones Push", isOn: $pushEnabled)
                    .onChange(of: pushEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                        HapticManager.selection()
                    }
            } footer: {
                Text("Permite que Clarity te envíe notificaciones para recordatorios y alertas")
            }
            
            Section {
                Toggle("Recordatorio Semanal", isOn: $weeklyReminder)
                    .onChange(of: weeklyReminder) { _, _ in HapticManager.selection() }
                
                if weeklyReminder {
                    Picker("Día de la semana", selection: $weeklyDay) {
                        ForEach(0..<weekDays.count, id: \.self) { index in
                            Text(weekDays[index]).tag(index)
                        }
                    }
                    .onChange(of: weeklyDay) { _, _ in HapticManager.selection() }
                    
                    HStack {
                        Text("Hora")
                        Spacer()
                        Text("\(weeklyHour):\(String(format: "%02d", weeklyMinute))")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle("Recordatorios Personalizados", isOn: $customReminders)
                    .onChange(of: customReminders) { _, _ in HapticManager.selection() }
                
                if customReminders {
                    TextField("Mensaje", text: $customMessage)
                    
                    HStack {
                        Text("Hora")
                        Spacer()
                        Text("\(customHour):\(String(format: "%02d", customMinute))")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Recordatorios")
            }
            
            Section {
                Toggle("Alertas de Presupuesto", isOn: $budgetAlerts)
                    .onChange(of: budgetAlerts) { _, _ in HapticManager.selection() }
                Toggle("Gastos Recurrentes", isOn: $recurringReminders)
                    .onChange(of: recurringReminders) { _, _ in HapticManager.selection() }
            } header: {
                Text("Alertas")
            } footer: {
                Text("Los ajustes se guardan automáticamente")
            }
        }
        .navigationTitle("Notificaciones")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    pushEnabled = false
                }
            }
        }
    }
}

