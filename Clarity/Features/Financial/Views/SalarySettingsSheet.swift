// SalarySettingsSheet.swift
// Manage monthly salary and recurring settings

import SwiftUI

struct SalarySettingsSheet: View {
    @Binding var income: Double
    @Binding var isRecurring: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    // Internal state for editing
    @State private var editingIncome: String = ""
    @State private var internalIsRecurring: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sueldo Base Mensual")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("€")
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            TextField("0.00", text: $editingIncome)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Toggle("Nómina Fija", isOn: $internalIsRecurring)
                        .tint(Color.clarityPrimary)

                    if internalIsRecurring {
                        Text(
                            "Clarity creará el presupuesto mensual automáticamente con este importe. No tendrás que introducirlo cada mes."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(
                            "Si tu sueldo varía cada mes, mantén esto desactivado. Te preguntaremos tus ingresos al inicio de cada mes."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Automatización")
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Configurar Recordatorios")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "bell.badge")
                                .foregroundStyle(Color.clarityPrimary)
                        }
                    }
                } header: {
                    Text("Notificaciones")
                } footer: {
                    Text(
                        "Activa las notificaciones para que Clarity te avise cuándo revisar tus finanzas."
                    )
                }
            }
            .navigationTitle("Ajustes de Sueldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                editingIncome = String(format: "%.2f", income)
                internalIsRecurring = isRecurring
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        if let value = Double(editingIncome.replacingOccurrences(of: ",", with: ".")) {
            income = value
            isRecurring = internalIsRecurring
            onSave()
            dismiss()
        }
    }
}
