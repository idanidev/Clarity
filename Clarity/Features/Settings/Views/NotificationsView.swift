// NotificationsView.swift
// Notifications settings

import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @State private var pushEnabled = false
    @State private var weeklyReminder = true
    @State private var budgetAlerts = true
    @State private var recurringReminders = true
    @State private var customReminders = true
    
    @State private var weeklyDay = 5 // Friday
    @State private var weeklyHour = 20
    @State private var weeklyMinute = 0
    
    @State private var customHour = 20
    @State private var customMinute = 0
    @State private var customMessage = "No olvides registrar tus gastos"
    
    private let weekDays = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    
    var body: some View {
        List {
            Section {
                Toggle("Notificaciones Push", isOn: $pushEnabled)
                    .onChange(of: pushEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                    }
            } footer: {
                Text("Permite que Clarity te envíe notificaciones para recordatorios y alertas")
            }
            
            Section {
                Toggle("Recordatorio Semanal", isOn: $weeklyReminder)
                
                if weeklyReminder {
                    Picker("Día de la semana", selection: $weeklyDay) {
                        ForEach(0..<weekDays.count, id: \.self) { index in
                            Text(weekDays[index]).tag(index)
                        }
                    }
                    
                    HStack {
                        Text("Hora")
                        Spacer()
                        Text("\(weeklyHour):\(String(format: "%02d", weeklyMinute))")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle("Recordatorios Personalizados", isOn: $customReminders)
                
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
                Toggle("Gastos Recurrentes", isOn: $recurringReminders)
            } header: {
                Text("Alertas")
            } footer: {
                Text("Recibe alertas cuando te acerques o superes tus presupuestos, y recordatorios de gastos recurrentes próximos")
            }
            
            Section {
                Button("Guardar Configuración") {
                    saveSettings()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.clarityPrimary)
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
    
    private func saveSettings() {
        // TODO: Save to Firebase
        print("Saving notification settings...")
        HapticManager.notification(.success)
    }
}
