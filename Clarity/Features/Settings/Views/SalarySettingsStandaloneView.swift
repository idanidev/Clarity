// SalarySettingsStandaloneView.swift
// Hub unificado de nóminas: ajustes + grid de 12 meses por año (escala infinito).

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

struct SalarySettingsStandaloneView: View {
    @State private var historyVM = MonthlyBudgetsViewModel()

    @State private var editingIncome: String = ""
    @State private var isRecurring: Bool = false
    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var saveSuccess = false

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var editingBudget: MonthlyBudget? = nil

    private let currentYear = Calendar.current.component(.year, from: Date())
    private let currentMonth = Calendar.current.component(.month, from: Date())

    private var budgetsByMonth: [Int: MonthlyBudget] {
        Dictionary(uniqueKeysWithValues: historyVM.budgets
            .filter { $0.year == selectedYear }
            .map { ($0.month, $0) })
    }

    private var yearStats: (total: Double, average: Double, months: Int) {
        let yearBudgets = historyVM.budgets.filter { $0.year == selectedYear }
        let total = yearBudgets.reduce(0) { $0 + $1.income }
        let avg = yearBudgets.isEmpty ? 0 : total / Double(yearBudgets.count)
        return (total, avg, yearBudgets.count)
    }

    /// Años con datos + año actual.
    private var availableYears: [Int] {
        let years = Set(historyVM.budgets.map(\.year)).union([currentYear])
        return years.sorted(by: >)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                salaryCard
                historySection
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Nóminas")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView().scaleEffect(0.8)
                } else if saveSuccess {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Button("Guardar") { save() }
                        .fontWeight(.bold)
                        .disabled(!hasChanges)
                }
            }
        }
        .task { await historyVM.loadBudgets() }
        .onAppear { loadCurrentValues() }
        .onChange(of: selectedYear) { _, newYear in
            Task { await historyVM.loadYear(newYear) }
        }
        .sheet(item: $editingBudget) { budget in
            EditBudgetSheet(budget: budget, viewModel: historyVM)
        }
    }

    // MARK: - Salary Card

    private var salaryCard: some View {
        VStack(spacing: 0) {
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

            Divider().padding(.horizontal, -20)

            Toggle(isOn: $isRecurring) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nómina fija").font(.body)
                    Text(isRecurring
                        ? "El presupuesto se crea automáticamente cada mes"
                        : "Te preguntaremos tus ingresos al inicio de cada mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Color.clarityPrimary)
            .padding(.vertical, 14)
            .onChange(of: isRecurring) { _, _ in
                hasChanges = true
                HapticManager.shared.selection()
            }
        }
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - History (year navigator + grid + stats)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historial").font(.headline)
                Spacer()
                yearNavigator
            }

            monthsGrid

            yearStatsFooter
        }
    }

    private var yearNavigator: some View {
        let canGoOlder = true   // historial puede ser arbitrariamente profundo
        let canGoNewer = selectedYear < currentYear

        return HStack(spacing: 14) {
            Button {
                selectedYear -= 1
                HapticManager.shared.selection()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(.tertiarySystemGroupedBackground)))
            }
            .disabled(!canGoOlder)
            .opacity(canGoOlder ? 1 : 0.3)

            Text(String(selectedYear))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 56)

            Button {
                selectedYear += 1
                HapticManager.shared.selection()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(.tertiarySystemGroupedBackground)))
            }
            .disabled(!canGoNewer)
            .opacity(canGoNewer ? 1 : 0.3)
        }
        .foregroundStyle(Color.clarityPrimary)
    }

    private var monthsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(1...12, id: \.self) { month in
                MonthBudgetCell(
                    month: month,
                    budget: budgetsByMonth[month],
                    isCurrent: selectedYear == currentYear && month == currentMonth,
                    isFuture: selectedYear > currentYear || (selectedYear == currentYear && month > currentMonth)
                )
                .onTapGesture { handleTap(month: month) }
            }
        }
    }

    private var yearStatsFooter: some View {
        let stats = yearStats
        return HStack(spacing: 0) {
            statItem(label: "Total", value: Formatters.currency(stats.total))
            Divider().frame(height: 32)
            statItem(label: "Media", value: Formatters.currency(stats.average))
            Divider().frame(height: 32)
            statItem(label: "Meses", value: "\(stats.months)/12")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tap handling

    private func handleTap(month: Int) {
        let isFuture = selectedYear > currentYear || (selectedYear == currentYear && month > currentMonth)
        if isFuture {
            HapticManager.shared.notification(.warning)
            return
        }
        if let existing = budgetsByMonth[month] {
            editingBudget = existing
        } else {
            // Crear con sueldo base actual o 0
            let baseIncome = Double(editingIncome.replacingOccurrences(of: ",", with: ".")) ?? 0
            HapticManager.shared.impact(.light)
            Task {
                await historyVM.createBudgetForMonth(year: selectedYear, month: month, income: baseIncome)
            }
        }
    }

    // MARK: - Data

    private func loadCurrentValues() {
        guard let doc = UserDataManager.shared.userDocument else { return }
        let income = doc.income ?? 0
        editingIncome = income > 0 ? String(format: "%.0f", income) : ""
        isRecurring = doc.settings?.isSalaryRecurring ?? false
    }

    private func save() {
        let cleaned = editingIncome.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), let userId = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        hasChanges = false
        Task {
            do {
                try await Firestore.firestore().collection("users").document(userId).updateData([
                    "income": value,
                    "settings.isSalaryRecurring": isRecurring,
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
                await MainActor.run {
                    isSaving = false
                    saveSuccess = true
                    HapticManager.shared.playSuccess()
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { saveSuccess = false }
            } catch {
                await MainActor.run {
                    isSaving = false
                    hasChanges = true
                }
            }
        }
    }
}

// MARK: - Month Budget Cell

private struct MonthBudgetCell: View {
    let month: Int
    let budget: MonthlyBudget?
    let isCurrent: Bool
    let isFuture: Bool

    private var monthAbbr: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        return f.shortMonthSymbols[month - 1].capitalized
    }

    private var bgColor: Color {
        if isCurrent { return Color.clarityPrimary }
        if budget != nil { return Color(.secondarySystemGroupedBackground) }
        return Color(.tertiarySystemGroupedBackground)
    }

    private var primaryFg: Color {
        if isCurrent { return .white }
        if isFuture { return Color(.tertiaryLabel) }
        return budget != nil ? .primary : .secondary
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(monthAbbr)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isCurrent ? Color.white.opacity(0.9) : .secondary)

            if let budget {
                Text("\(Int(budget.income))€")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(primaryFg)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Image(systemName: isFuture ? "lock" : "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isFuture ? Color(.tertiaryLabel) : Color.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    budget == nil && !isFuture && !isCurrent ? Color(.systemGray4).opacity(0.6) : Color.clear,
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
        )
        .opacity(isFuture ? 0.55 : 1.0)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SalarySettingsStandaloneView()
    }
}
