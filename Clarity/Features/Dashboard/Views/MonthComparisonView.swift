// MonthComparisonView.swift
// Vista premium de comparación de meses para el tab VS

import SwiftUI
import Charts

struct MonthComparisonView: View {
    let expenses: [Expense]

    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var pickerYear: Int
    @State private var animateChart = false
    @State private var selectedChartCategory: String?
    /// Expenses loaded directly from Firebase (user-scoped) for accurate comparisons.
    @State private var fetchedExpenses: [Expense] = []
    @State private var isLoadingExpenses = false

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "MMMM"
        return f
    }()

    private static let shortMonthSymbols: [String] = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        return f.shortStandaloneMonthSymbols ?? ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]
    }()

    /// Uses Firebase-sourced data if loaded, otherwise falls back to the passed-in list.
    private var displayExpenses: [Expense] {
        fetchedExpenses.isEmpty ? expenses : fetchedExpenses
    }

    init(expenses: [Expense]) {
        self.expenses = expenses
        let cal = Calendar.current
        let now = Date()
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        let prev = cal.date(byAdding: .month, value: -1, to: now) ?? now
        _selectedYear = State(initialValue: cal.component(.year, from: prev))
        _selectedMonth = State(initialValue: cal.component(.month, from: prev))
        _pickerYear = State(initialValue: y)
        _ = m
    }

    // Legacy init for compatibility
    init(viewModel: HomeViewModel) {
        self.init(expenses: viewModel.allHistoricalExpenses)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header con gradiente
                headerSection

                // Month Selector Pills
                monthSelector
                    .padding(.horizontal)

                // Big comparison card
                mainComparisonCard
                    .padding(.horizontal)

                // Trend indicator
                trendCard
                    .padding(.horizontal)

                // Category breakdown
                categoryBreakdown
                    .padding(.horizontal)

                // Top differences
                topDifferencesCard
                    .padding(.horizontal)

                Spacer(minLength: 100)
            }
        }
        .background(Color.bgPrimary)
        .overlay {
            if isLoadingExpenses && fetchedExpenses.isEmpty {
                ProgressView("Cargando datos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgPrimary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateChart = true
            }
        }
        .onChange(of: selectedYear) { _, _ in
            animateChart = false
            withAnimation(.easeOut(duration: 0.6)) { animateChart = true }
        }
        .onChange(of: selectedMonth) { _, _ in
            animateChart = false
            withAnimation(.easeOut(duration: 0.6)) { animateChart = true }
        }
        .task {
            await loadAllExpenses()
        }
    }

    // MARK: - Load ALL expenses (network → cache fallback)
    @MainActor
    private func loadAllExpenses() async {
        guard !isLoadingExpenses else { return }
        isLoadingExpenses = true
        defer { isLoadingExpenses = false }
        let rules = (try? await DependencyContainer.shared.recurringExpenseRepository.fetchAll()) ?? []
        do {
            let useCase = DependencyContainer.shared.makeGetExpensesUseCase()
            let all = try await useCase.execute(policy: .cacheFirst())
            var seen = Set<String>()
            let deduped = all.filter { seen.insert($0.stableId).inserted }
            fetchedExpenses = ExpenseSanitizer.sanitize(expenses: deduped, rules: rules)
        } catch {
            if let cached = try? await DependencyContainer.shared.makeGetExpensesUseCase()
                .execute(policy: .cacheOnly) {
                var seen = Set<String>()
                let deduped = cached.filter { seen.insert($0.stableId).inserted }
                fetchedExpenses = ExpenseSanitizer.sanitize(expenses: deduped, rules: rules)
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Comparativa")
                .scaledFont(size: 28, weight: .bold)
                .foregroundStyle(.primary)
            
            Text("Analiza tus gastos entre meses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .padding(.top, 8)
    }
    
    // MARK: - Month Selector (Year Grid)
    private var monthSelector: some View {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let currentMonth = cal.component(.month, from: Date())
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

        return VStack(spacing: 12) {
            // Year header
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) { pickerYear -= 1 }
                    HapticManager.shared.selection()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout.bold())
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(String(pickerYear))
                    .scaledFont(size: 18, weight: .bold, design: .rounded)
                    .contentTransition(.numericText(value: Double(pickerYear)))

                Spacer()

                Button {
                    guard pickerYear < currentYear else { return }
                    withAnimation(.spring(response: 0.3)) { pickerYear += 1 }
                    HapticManager.shared.selection()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.callout.bold())
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                        .opacity(pickerYear < currentYear ? 1 : 0.3)
                }
                .buttonStyle(.plain)
                .disabled(pickerYear >= currentYear)
            }

            // Months grid
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    let isFuture = pickerYear > currentYear || (pickerYear == currentYear && month > currentMonth)
                    let isCurrent = pickerYear == currentYear && month == currentMonth
                    let isSelected = pickerYear == selectedYear && month == selectedMonth
                    let hasData = monthHasData(year: pickerYear, month: month)
                    let enabled = !isFuture && !isCurrent && hasData

                    Button {
                        guard enabled else { return }
                        withAnimation(.spring(response: 0.3)) {
                            selectedYear = pickerYear
                            selectedMonth = month
                        }
                        HapticManager.shared.selection()
                    } label: {
                        Text(Self.shortMonthSymbols[month - 1].capitalized)
                            .scaledFont(size: 13, weight: .semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(
                                isSelected ? Color.white
                                : (isCurrent ? Color.clarityAccent : (enabled ? .primary : .secondary))
                            )
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.clarityPrimary.gradient)
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(isCurrent ? Color.clarityAccent : Color.clear, lineWidth: 1.5)
                                        )
                                }
                            }
                            .opacity(enabled ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func monthHasData(year: Int, month: Int) -> Bool {
        let cal = Calendar.current
        for e in displayExpenses {
            guard let d = Formatters.date(from: e.date) else { continue }
            if cal.component(.year, from: d) == year && cal.component(.month, from: d) == month {
                return true
            }
        }
        return false
    }
    
    // MARK: - Main Comparison Card
    private var mainComparisonCard: some View {
        let current = totalForCurrentMonth
        let compared = totalForComparedMonth
        let difference = current - compared
        let percentChange = compared > 0 ? ((difference / compared) * 100) : 0
        
        return VStack(spacing: 0) {
            // Top section - This month
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTE MES")
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    Text(current.formattedCurrency)
                        .scaledFont(size: 36, weight: .bold, design: .rounded)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Circle progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: animateChart ? min(current / max(compared, 1), 1.0) : 0)
                        .stroke(
                            current > compared ? Color.red.gradient : Color.green.gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: difference > 0 ? "arrow.up" : "arrow.down")
                        .scaledFont(size: 20, weight: .bold)
                        .foregroundStyle(difference > 0 ? .red : .green)
                }
                .frame(width: 56, height: 56)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            
            // Divider with VS
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("VS")
                    .scaledFont(size: 12, weight: .black)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal)
            .background(Color(.secondarySystemGroupedBackground))
            
            // Bottom section - Compared month
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedMonthDisplayName().uppercased())
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    Text(compared.formattedCurrency)
                        .scaledFont(size: 28, weight: .semibold, design: .rounded)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Difference badge
                HStack(spacing: 4) {
                    Image(systemName: difference > 0 ? "arrow.up.right" : "arrow.down.right")
                        .scaledFont(size: 12, weight: .bold)

                    Text("\(String(format: "%.0f", abs(percentChange)))%")
                        .scaledFont(size: 14, weight: .bold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(difference > 0 ? Color.red.gradient : Color.green.gradient)
                )
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
    
    // MARK: - Trend Card
    private var trendCard: some View {
        let current = totalForCurrentMonth
        let compared = totalForComparedMonth
        let difference = current - compared
        
        let message: String
        let icon: String
        let color: Color
        
        if difference > 0 {
            message = "Estás gastando \(difference.formattedCurrency) más que en \(selectedMonthDisplayName())"
            icon = "exclamationmark.triangle.fill"
            color = .red
        } else if difference < 0 {
            message = "¡Genial! Has ahorrado \(abs(difference).formattedCurrency) comparado con \(selectedMonthDisplayName())"
            icon = "checkmark.seal.fill"
            color = .green
        } else {
            message = "Tus gastos son iguales a los de \(selectedMonthDisplayName())"
            icon = "equal.circle.fill"
            color = .blue
        }
        
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .scaledFont(size: 24)
                .foregroundStyle(color)

            Text(message)
                .scaledFont(size: 14, weight: .medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Category Breakdown
    private var categoryBreakdown: some View {
        let data = comparisonByCategory.prefix(6) // Top 6 categories
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Por categoría")
                    .font(.headline)
                
                Spacer()
                
                // Legend
                HStack(spacing: 12) {
                    legendItem(color: Color.clarityPrimary, label: "Actual")
                    legendItem(color: .gray.opacity(0.4), label: "Anterior")
                }
                .font(.caption)
            }
            
            if data.isEmpty {
                ContentUnavailableView("Sin datos", systemImage: "chart.bar", description: Text("No hay gastos para comparar"))
                    .frame(height: 200)
            } else {
                Chart(Array(data)) { item in
                    BarMark(
                        x: .value("Categoría", item.category),
                        y: .value("Actual", animateChart ? item.currentAmount : 0)
                    )
                    .foregroundStyle(Color.clarityPrimary.gradient)
                    .cornerRadius(6)
                    .position(by: .value("Tipo", "Actual"))
                    
                    BarMark(
                        x: .value("Categoría", item.category),
                        y: .value("Comparado", animateChart ? item.comparedAmount : 0)
                    )
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .cornerRadius(6)
                    .position(by: .value("Tipo", "Anterior"))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("\(Int(amount))€")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let cat = value.as(String.self) {
                                Text(cat)
                                    .scaledFont(size: 10)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedChartCategory)
                .frame(height: 220)

                // Detail popover for selected category
                if let cat = selectedChartCategory,
                   let item = comparisonByCategory.first(where: { $0.category == cat }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.category).font(.subheadline.bold())
                            HStack(spacing: 12) {
                                Label("\(Formatters.currency(item.currentAmount))", systemImage: "circle.fill")
                                    .font(.caption).foregroundStyle(Color.clarityPrimary)
                                Label("\(Formatters.currency(item.comparedAmount))", systemImage: "circle.fill")
                                    .font(.caption).foregroundStyle(.gray)
                            }
                        }
                        Spacer()
                        let diff = item.currentAmount - item.comparedAmount
                        Text("\(diff >= 0 ? "+" : "")\(Formatters.currency(diff))")
                            .font(.subheadline.bold())
                            .foregroundStyle(diff > 0 ? .red : .green)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.opacity)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Top Differences
    private var topDifferencesCard: some View {
        let differences = comparisonByCategory
            .map { (cat: $0.category, diff: $0.currentAmount - $0.comparedAmount) }
            .sorted { abs($0.diff) > abs($1.diff) }
            .prefix(5)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Mayores cambios")
                .font(.headline)
            
            if differences.isEmpty {
                Text("No hay diferencias significativas")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(differences), id: \.cat) { item in
                    HStack {
                        Text(item.cat)
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: item.diff > 0 ? "arrow.up" : "arrow.down")
                                .scaledFont(size: 10, weight: .bold)

                            Text(item.diff > 0 ? "+\(item.diff.formattedCurrency)" : item.diff.formattedCurrency)
                                .scaledFont(size: 13, weight: .semibold, design: .rounded)
                        }
                        .foregroundStyle(item.diff > 0 ? .red : .green)
                    }
                    .padding(.vertical, 8)
                    
                    if item.cat != differences.last?.cat {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Views
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Data Calculations

    /// Pre-computed split of expenses into current and compared month — filters once for both.
    /// Uses explicit year/month components to avoid timezone edge-case issues.
    private var monthlyData: (current: [Expense], compared: [Expense]) {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        let targetYear = selectedYear
        let targetMonth = selectedMonth

        var current: [Expense] = []
        var compared: [Expense] = []
        for expense in displayExpenses {
            guard let date = Formatters.date(from: expense.date) else { continue }
            let y = calendar.component(.year, from: date)
            let m = calendar.component(.month, from: date)
            if y == currentYear && m == currentMonth {
                current.append(expense)
            } else if y == targetYear && m == targetMonth {
                compared.append(expense)
            }
        }
        return (current, compared)
    }

    private var totalForCurrentMonth: Double {
        monthlyData.current.reduce(0) { $0 + $1.amount }
    }

    private var totalForComparedMonth: Double {
        monthlyData.compared.reduce(0) { $0 + $1.amount }
    }

    private var comparisonByCategory: [CategoryComparison] {
        let data = monthlyData
        var categories = Set<String>()
        (data.current + data.compared).forEach { categories.insert(displayCategory($0.category)) }

        return categories.compactMap { cat in
            let current = data.current
                .filter { displayCategory($0.category) == cat }
                .reduce(0) { $0 + $1.amount }
            let compared = data.compared
                .filter { displayCategory($0.category) == cat }
                .reduce(0) { $0 + $1.amount }
            if current == 0 && compared == 0 { return nil }
            return CategoryComparison(category: cat, currentAmount: current, comparedAmount: compared)
        }.sorted { $0.currentAmount > $1.currentAmount }
    }

    // MARK: - Helpers
    
    private func selectedMonthDisplayName() -> String {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = selectedMonth
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let cal = Calendar.current
        let nowY = cal.component(.year, from: Date())
        if selectedYear != nowY {
            let f = DateFormatter()
            f.locale = Locale(identifier: "es_ES")
            f.dateFormat = "MMMM yyyy"
            return f.string(from: date).capitalized
        }
        return Self.monthFormatter.string(from: date).capitalized
    }

    private func shortMonthLabel(offset: Int) -> String {
        switch offset {
        case 1: return "1 mes"
        case 2: return "2 meses"
        case 3: return "3 meses"
        case 6: return "6 meses"
        case 12: return "1 año"
        default: return "\(offset)m"
        }
    }
    
    private func displayCategory(_ category: String) -> String {
        return category
    }
}

// MARK: - Category Comparison Model
struct CategoryComparison: Identifiable {
    var id: String { category }
    let category: String
    let currentAmount: Double
    let comparedAmount: Double
}

#Preview {
    MonthComparisonView(expenses: [])
}
