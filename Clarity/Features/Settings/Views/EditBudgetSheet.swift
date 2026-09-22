// EditBudgetSheet.swift
// Hoja para corregir la nómina de un mes. La abre `SalarySettingsStandaloneView`.
// Vivía en MonthlyBudgetsView.swift, que se eliminó por no tener usos.

import SwiftUI

// MARK: - Edit Budget Sheet

struct EditBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let budget: MonthlyBudget
    var viewModel: MonthlyBudgetsViewModel

    @State private var income: String = ""
    @FocusState private var incomeFocused: Bool

    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()

    private var monthDate: Date {
        Calendar.current.date(from: DateComponents(year: budget.year, month: budget.month))
            ?? Date()
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text(monthFormatter.string(from: monthDate).capitalized)
                            .font(.headline)
                    }
                }

                Section(String(localized: "budgets.edit.income", defaultValue: "Ingresos")) {
                    HStack {
                        Text("€")
                            .foregroundColor(.secondary)
                        TextField("1600", text: $income)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.medium))
                            .focused($incomeFocused)
                    }
                }

                Section {
                    Button {
                        saveAndDismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "common.saveChanges", defaultValue: "Guardar Cambios"))
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "budgets.edit.title", defaultValue: "Editar Nómina"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancelar")) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { incomeFocused = false }.fontWeight(.semibold)
                }
            }
            .onAppear {
                income = "\(Int(budget.income))"
            }
        }
    }

    private func saveAndDismiss() {
        guard let newIncome = Double(income), newIncome > 0 else { return }

        var updatedBudget = budget
        updatedBudget.income = newIncome
        updatedBudget.updatedAt = Date()

        Task {
            await viewModel.saveBudget(updatedBudget)
            dismiss()
        }
    }
}
