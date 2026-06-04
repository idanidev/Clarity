// SalaryDashboardSheet.swift
// Unified salary settings + monthly income history

import SwiftUI

struct SalaryDashboardSheet: View {
    @Binding var income: Double
    @Binding var isRecurring: Bool
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var historyVM = MonthlyBudgetsViewModel()

    @State private var editingIncome: String = ""
    @State private var internalIsRecurring: Bool = false
    @State private var editingBudget: MonthlyBudget? = nil
    @State private var showingAddMonth = false
    @State private var hasChanges = false

    private var maxIncome: Double {
        historyVM.budgets.map(\.income).max() ?? max(income, 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    salaryCard
                    if !historyVM.budgets.isEmpty {
                        historySection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nóminas")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.bold)
                        .disabled(!hasChanges)
                }
            }
        }
        .presentationDetents([.large])
        .task { await historyVM.loadBudgets() }
        .onAppear {
            editingIncome = formatIncome(income)
            internalIsRecurring = isRecurring
        }
        .sheet(isPresented: $showingAddMonth) {
            CreateBudgetSheet(viewModel: historyVM)
        }
        .sheet(item: $editingBudget) { budget in
            EditBudgetSheet(budget: budget, viewModel: historyVM)
        }
    }

    // MARK: - Salary Card

    private var salaryCard: some View {
        VStack(spacing: 0) {
            // Amount input
            VStack(spacing: 6) {
                Text("Sueldo base mensual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("€")
                        .scaledFont(size: 28, weight: .semibold, design: .rounded)
                        .foregroundStyle(.secondary)

                    TextField("0", text: $editingIncome)
                        .scaledFont(size: 52, weight: .bold, design: .rounded)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .onChange(of: editingIncome) { _, _ in hasChanges = true }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            Divider()
                .padding(.horizontal, -20)

            // Recurring toggle
            Toggle(isOn: $internalIsRecurring) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nómina fija")
                        .font(.body)
                    Text(
                        internalIsRecurring
                            ? "El presupuesto se crea automáticamente cada mes"
                            : "Te preguntaremos tus ingresos al inicio de cada mes"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Color.clarityPrimary)
            .padding(.vertical, 14)
            .onChange(of: internalIsRecurring) { _, _ in hasChanges = true }
        }
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historial de nóminas")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddMonth = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.clarityPrimary)
                }
            }

            VStack(spacing: 8) {
                ForEach(historyVM.budgets.prefix(12)) { budget in
                    MonthIncomeRowView(
                        budget: budget,
                        maxIncome: maxIncome,
                        onTap: { editingBudget = budget }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        let cleaned = editingIncome.replacingOccurrences(of: ",", with: ".")
        if let value = Double(cleaned) {
            income = value
            isRecurring = internalIsRecurring
            onSave()
            dismiss()
        }
    }

    private func formatIncome(_ value: Double) -> String {
        value == 0 ? "" : String(format: "%.0f", value)
    }
}

// MARK: - Month Income Row

private struct MonthIncomeRowView: View {
    let budget: MonthlyBudget
    let maxIncome: Double
    let onTap: () -> Void

    private var isCurrentMonth: Bool {
        let now = Date()
        let y = Calendar.current.component(.year, from: now)
        let m = Calendar.current.component(.month, from: now)
        return budget.year == y && budget.month == m
    }

    private var monthAbbr: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        return f.shortMonthSymbols[budget.month - 1].uppercased()
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Month badge
                VStack(spacing: 1) {
                    Text(monthAbbr)
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundStyle(isCurrentMonth ? .white : .secondary)
                    Text(String(budget.year).suffix(2))
                        .scaledFont(size: 9, weight: .medium)
                        .foregroundStyle(isCurrentMonth ? Color.white.opacity(0.75) : Color.secondary.opacity(0.6))
                }
                .frame(width: 40, height: 40)
                .background(isCurrentMonth ? Color.clarityPrimary : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        Capsule()
                            .fill(
                                isCurrentMonth
                                    ? Color.clarityPrimary
                                    : Color(.systemGray3)
                            )
                            .frame(
                                width: max(6, geo.size.width * CGFloat(budget.income / maxIncome)),
                                height: 6
                            )
                            .animation(.spring(response: 0.5), value: budget.income)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 40)

                // Amount
                Text(Formatters.currency(budget.income))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCurrentMonth ? Color.clarityPrimary : .primary)
                    .frame(width: 72, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
