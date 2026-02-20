//
//  MonthlyBudgetsView.swift
//  Clarity
//
//  Monthly income history - view and edit paycheck records
//

import SwiftUI

struct MonthlyBudgetsView: View {
    @StateObject private var viewModel = MonthlyBudgetsViewModel()
    @State private var showingCreateSheet = false
    @State private var editingBudget: MonthlyBudget?

    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Cargando historial...")
            } else if viewModel.budgets.isEmpty {
                emptyState
            } else {
                budgetsList
            }
        }
        .navigationTitle("Historial de Nóminas")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateBudgetSheet(viewModel: viewModel)
        }
        .sheet(item: $editingBudget) { budget in
            EditBudgetSheet(budget: budget, viewModel: viewModel)
        }
        .task {
            await viewModel.loadBudgets()
        }
        .refreshable {
            await viewModel.loadBudgets()
        }
    }

    // MARK: - Subviews

    private var budgetsList: some View {
        List {
            ForEach(viewModel.budgets) { budget in
                BudgetMonthRow(budget: budget)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingBudget = budget
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No hay nóminas registradas")
                .font(.title3.bold())

            Text("Registra tus ingresos mensuales para\nun seguimiento preciso de ahorros")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateSheet = true
            } label: {
                Label("Crear Primera Nómina", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
}

// MARK: - Budget Month Row

struct BudgetMonthRow: View {
    let budget: MonthlyBudget

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
        HStack(spacing: 16) {
            // Month indicator
            VStack(spacing: 4) {
                Text(monthFormatter.shortMonthSymbols[budget.month - 1].uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                Text("\(budget.year)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text(monthFormatter.string(from: monthDate).capitalized)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "eurosign.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("€\(Int(budget.income))")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Create Budget Sheet

struct CreateBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MonthlyBudgetsViewModel

    @State private var selectedDate = Date()
    @State private var income: String = ""

    private var year: Int {
        Calendar.current.component(.year, from: selectedDate)
    }

    private var month: Int {
        Calendar.current.component(.month, from: selectedDate)
    }

    private var canSave: Bool {
        guard let income = Double(income), income > 0 else { return false }
        return !viewModel.budgetExists(for: year, month: month)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Mes") {
                    DatePicker(
                        "Seleccionar mes",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)

                    if viewModel.budgetExists(for: year, month: month) {
                        Label(
                            "Ya existe nómina para este mes",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundColor(.orange)
                        .font(.caption)
                    }
                }

                Section("Ingresos Estimados") {
                    HStack {
                        Text("€")
                            .foregroundColor(.secondary)
                        TextField("1600", text: $income)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.medium))
                    }
                }

                Section {
                    Button {
                        saveAndDismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Crear Nómina")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Nueva Nómina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveAndDismiss() {
        guard let income = Double(income) else { return }

        Task {
            await viewModel.createBudgetForMonth(year: year, month: month, income: income)
            dismiss()
        }
    }
}

// MARK: - Edit Budget Sheet

struct EditBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let budget: MonthlyBudget
    @ObservedObject var viewModel: MonthlyBudgetsViewModel

    @State private var income: String = ""

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

                Section("Ingresos") {
                    HStack {
                        Text("€")
                            .foregroundColor(.secondary)
                        TextField("1600", text: $income)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.medium))
                    }
                }

                Section {
                    Button {
                        saveAndDismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Guardar Cambios")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Editar Nómina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
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

#Preview {
    NavigationView {
        MonthlyBudgetsView()
    }
}
