//
//  MonthlyBudgetsView.swift
//  Clarity
//
//  Monthly income history - view and edit paycheck records
//

import SwiftUI

struct MonthlyBudgetsView: View {
    @State private var viewModel = MonthlyBudgetsViewModel()
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
                ProgressView(String(localized: "budgets.loading", defaultValue: "Cargando historial..."))
            } else if viewModel.budgets.isEmpty {
                emptyState
            } else {
                budgetsList
            }
        }
        .navigationTitle(String(localized: "budgets.history.title", defaultValue: "Historial de Nóminas"))
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
            ForEach(viewModel.groupedByYear) { group in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { viewModel.expandedYears.contains(group.year) },
                            set: { isExpanded in
                                withAnimation(.easeInOut(duration: AnimationDuration.normal)) {
                                    if isExpanded {
                                        viewModel.expandedYears.insert(group.year)
                                    } else {
                                        viewModel.expandedYears.remove(group.year)
                                    }
                                }
                            }
                        )
                    ) {
                        ForEach(group.budgets) { budget in
                            BudgetMonthRow(budget: budget)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingBudget = budget
                                }
                        }
                    } label: {
                        YearHeaderView(group: group)
                    }
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

            Text(String(localized: "budgets.empty.title", defaultValue: "No hay nóminas registradas"))
                .font(.title3.bold())

            Text(String(localized: "budgets.empty.subtitle", defaultValue: "Registra tus ingresos mensuales para\nun seguimiento preciso de ahorros"))
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateSheet = true
            } label: {
                Label(String(localized: "budgets.empty.createFirst", defaultValue: "Crear Primera Nómina"), systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
}

// MARK: - Year Header

struct YearHeaderView: View {
    let group: YearBudgetGroup

    private var formattedTotal: String {
        let value = Int(group.totalIncome)
        return "\(value.formatted(.number.grouping(.automatic)))€"
    }

    private var formattedAverage: String {
        let value = Int(group.averageIncome)
        return "\(value.formatted(.number.grouping(.automatic)))€"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(group.year))
                .font(.title3.weight(.bold))

            HStack(spacing: CornerRadius.small) {
                Label(formattedTotal, systemImage: "eurosign.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                Text("·")
                    .foregroundColor(.secondary)

                Text("Media: \(formattedAverage)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary)

                Text("\(group.budgets.count) meses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
    var viewModel: MonthlyBudgetsViewModel

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var income: String = ""

    private let monthNames: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.monthSymbols.map { $0.capitalized }
    }()

    private let availableYears: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 3)...currentYear).reversed()
    }()

    private var canSave: Bool {
        guard let income = Double(income), income > 0 else { return false }
        return !viewModel.budgetExists(for: selectedYear, month: selectedMonth)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(String(localized: "budgets.create.month", defaultValue: "Mes")) {
                    Picker(String(localized: "budgets.create.month", defaultValue: "Mes"), selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthNames[month - 1]).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()

                    Picker(String(localized: "budgets.create.year", defaultValue: "Año"), selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.budgetExists(for: selectedYear, month: selectedMonth) {
                        Label(
                            String(localized: "budgets.create.alreadyExists", defaultValue: "Ya existe nómina para este mes"),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundColor(.orange)
                        .font(.caption)
                    }
                }

                Section(String(localized: "budgets.create.estimatedIncome", defaultValue: "Ingresos Estimados")) {
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
                            Text(String(localized: "budgets.create.button", defaultValue: "Crear Nómina"))
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(String(localized: "budgets.create.title", defaultValue: "Nueva Nómina"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancelar")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveAndDismiss() {
        guard let income = Double(income) else { return }

        Task {
            await viewModel.createBudgetForMonth(
                year: selectedYear, month: selectedMonth, income: income)
            dismiss()
        }
    }
}

// MARK: - Edit Budget Sheet

struct EditBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let budget: MonthlyBudget
    var viewModel: MonthlyBudgetsViewModel

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

                Section(String(localized: "budgets.edit.income", defaultValue: "Ingresos")) {
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
