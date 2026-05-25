// HomeView.swift
// Main screen implementing Clean Architecture + MVVM
// Restored full functionality: Tabs (List/Graph/Calendar), 3-Card Summary, No Title

import Charts
import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private var userDataManager = UserDataManager.shared

    // UI State
    @State private var selectedView = 0  // 0 = Tabla, 1 = Gráfico, 2 = Calendario, 3 = VS
    @State private var evolutionMonths = 6
    @State private var expenseToEdit: Expense?
    @State private var showFilterSheet = false

    // Voice & FAB
    // showVoiceSheet removed
    @State private var showAddExpense = false  // New state for manual entry
    @State private var voiceCoordinator = VoiceExpenseCoordinator()
    @State private var speechManager = SpeechRecognitionManager.shared

    @MainActor
    init(viewModel: HomeViewModel? = nil) {
        let vm = viewModel ?? DependencyContainer.shared.makeHomeViewModel()
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        mainContent
            .background(DesignTokens.Colors.background)
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadIfNeeded() }
            .sheet(item: $expenseToEdit) { expense in
                EditExpenseSheet(expense: expense) {
                    Task { await viewModel.refresh() }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseSheet {
                    Task { await viewModel.refresh() }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showFilterSheet) {
                ExpenseFilterSheet(
                    filter: $viewModel.selectedFilter,
                    availableCategories: UserDataManager.shared.categoryNames,
                    onApply: {
                        // Trigger reload to fetch data if date range changed
                        Task { await viewModel.loadExpenses() }
                    }
                )
            }
            // VoiceRecordingSheet removed - migrated to inline VoiceExpenseButton
            // VoiceConfirmationSheet is now handled by VoiceExpenseButton directly
            .onChange(of: voiceCoordinator.errorMessage) { _, newValue in
                if let error = newValue {
                    FeedbackManager.shared.show(.error, title: "Error de Voz", message: error)
                    voiceCoordinator.clearError()
                }
            }
        // onChange for silence removed - logic moved to VoiceExpenseCoordinator inside Button
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Views (List, Chart, etc.)
            Group {
                switch selectedView {
                case 0:
                    listView
                case 1:
                    chartView
                case 2:
                    calendarView
                // case 3: comparisonView  // Temporalmente deshabilitado
                default:
                    listView
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedView)
            .padding(.bottom, 60)  // Space for floating bar

            // Floating Bottom Bar
            segmentedPicker
        }
    }

    // MARK: - Bottom Picker
    private var segmentedPicker: some View {
        ZStack(alignment: .bottom) {
            // Centered Pills (Floating Island)
            HStack(spacing: 0) {
                viewModeButton(icon: "list.bullet", index: 0)
                    .accessibilityLabel("Vista lista")
                viewModeButton(icon: "chart.pie.fill", index: 1)
                    .accessibilityLabel("Vista gráficos")
                viewModeButton(icon: "calendar", index: 2)
                    .accessibilityLabel("Vista calendario")
                // viewModeButton(icon: "arrow.left.arrow.right", index: 3)
                //     .accessibilityLabel("Comparar meses")
            }
            .padding(4)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .frame(maxWidth: .infinity, alignment: .center)  // Force center

            // Voice Button Aligned Right
            HStack {
                Spacer()
                SimpleVoiceButton(
                    viewModel: viewModel,
                    categories: UserDataManager.shared.categories
                )
                .offset(y: 4)  // "mas abajo" slightly to align nicely vs capsule
            }
            .padding(.trailing, DesignTokens.Spacing.md)
        }
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    // MARK: - Tab 1: List View
    private var listView: some View {
        VStack(spacing: 0) {
            // Header Content (Cards + Search) - Fixed at top
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Summary Cards Modernas
                SummaryCardsView(
                    totalExpenses: filteredTotal,
                    expenseCount: viewModel.filteredExpenses.count,
                    savings: savings,
                    savingsPercentage: savings > 0
                        ? Int((savings / (monthlyIncome > 0 ? monthlyIncome : 1)) * 100)
                        : 0,
                    available: savings
                )
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.top, 12)  // Espacio limpio desde navigation bar

                // Month Selector — hidden while searching (search spans all months)
                if viewModel.searchText.isEmpty {
                    MonthSelectorView(currentMonth: $viewModel.selectedMonth) {
                        Task { await viewModel.onMonthChanged() }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Search Bar Moderna + Filter Button
                HStack(spacing: DesignTokens.Spacing.xs) {
                    SearchBarView(
                        searchText: $viewModel.searchText,
                        filter: $viewModel.selectedFilter,
                        onFilterChange: {
                            // Handled automatically by ViewModel bindings
                        }
                    )

                    // Clear Filter Button (only if active)
                    if viewModel.selectedFilter.hasActiveFilters {
                        Button {
                            viewModel.selectedFilter = ExpenseFilter()  // Reset
                            HapticManager.shared.notification(.success)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(DesignTokens.Colors.surface)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Limpiar filtros")
                    }

                    Button {
                        showFilterSheet = true
                        HapticManager.shared.selection()
                    } label: {
                        // Purple icon if active filters
                        Image(
                            systemName: viewModel.selectedFilter.hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                        .font(.system(size: 22))
                        .foregroundColor(
                            viewModel.selectedFilter.hasActiveFilters
                                ? DesignTokens.Colors.accent : DesignTokens.Colors.textPrimary
                        )
                        .frame(width: 44, height: 44)
                        .background(DesignTokens.Colors.surface)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("Filtros")
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                // ActiveFilterPillsView removed as requested
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.searchText.isEmpty)
            .background(DesignTokens.Colors.background)
            // Sombra inferior que crea profundidad entre header y lista
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.background,
                        DesignTokens.Colors.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 16)
                .offset(y: 16)
                .allowsHitTesting(false)
            }

            // List Content - Scrollable
            if viewModel.state == .loading && viewModel.allExpenses.isEmpty {
                loadingView
            } else if case .error(let error) = viewModel.state {
                errorView(error.localizedDescription)
            } else if viewModel.filteredExpenses.isEmpty {
                emptyStateView
            } else {
                ExpandableExpenseList(
                    categories: viewModel.categoryGroups,
                    onExpenseDelete: { expense in
                        Task { await viewModel.deleteExpense(expense) }
                    },
                    onExpenseEdit: { expense in
                        expenseToEdit = expense
                    },
                    onLoadMore: {
                        Task { await viewModel.loadMore() }
                    }
                )
            }
        }
    }

    // MARK: - Tab 2: Chart View
    private var chartView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.filteredExpenses.isEmpty {
                    ContentUnavailableView("Sin datos para gráficos", systemImage: "chart.pie")
                } else {
                    // Donut Chart - Comparativa ahora en tab VS de ExpensesView
                    DonutChartView(
                        categoryData: buildChartData(),
                        total: filteredTotal
                    )
                }
            }
            .padding(.bottom, 80)
        }
        // Swipe horizontal cambia de mes (← anterior / → siguiente, sin futuro)
        .highPriorityGesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    let cal = Calendar.current
                    if value.translation.width < -50 {
                        if let next = cal.date(byAdding: .month, value: 1, to: viewModel.selectedMonth),
                           next <= Date() {
                            withAnimation(.snappy) { viewModel.selectedMonth = next }
                            HapticManager.shared.selection()
                        }
                    } else if value.translation.width > 50 {
                        if let prev = cal.date(byAdding: .month, value: -1, to: viewModel.selectedMonth) {
                            withAnimation(.snappy) { viewModel.selectedMonth = prev }
                            HapticManager.shared.selection()
                        }
                    }
                }
        )
    }

    // MARK: - Tab 3: Calendar View
    private var calendarView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.allHistoricalExpenses.isEmpty {
                    ContentUnavailableView("Sin datos para calendario", systemImage: "calendar")
                } else {
                    // Historial completo: el calendario navega meses internamente
                    // (con filteredExpenses solo veía el mes seleccionado).
                    ExpenseCalendarView(expenses: viewModel.allHistoricalExpenses)

                    // Evolución mensual (movida aquí desde la gráfica)
                    let evo = monthlyEvolution(months: evolutionMonths)
                    if evo.count >= 2 {
                        MonthlyEvolutionChart(
                            data: evo,
                            selectedMonthKey: String(
                                Formatters.localDayString(from: viewModel.selectedMonth).prefix(7)),
                            range: $evolutionMonths
                        )
                        .id(evolutionMonths)  // fuerza recrear el Chart al cambiar 6M/1A
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 80)
        }
    }

    private func viewModeButton(icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedView = index
            }
            HapticManager.shared.selection()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: selectedView == index ? .semibold : .medium))  // Slightly smaller icon
                .foregroundStyle(selectedView == index ? Color.white : Color.primary.opacity(0.5))
                .frame(width: 44, height: 36)  // More compact
        }
        .background(
            Capsule()
                .fill(selectedView == index ? DesignTokens.Colors.accent : Color.clear)
        )
    }

    // MARK: - Tab 4: Comparison View (VS)
    private var comparisonView: some View {
        MonthComparisonView(expenses: viewModel.allHistoricalExpenses)
    }

    // MARK: - Helpers
    private var monthlyIncome: Double {
        userDataManager.userDocument?.income ?? 0
    }

    // Reusa el total ya calculado por el VM (evita doble reduce por render)
    private var filteredTotal: Double { viewModel.totalFilteredAmount }

    private var savings: Double {
        viewModel.calculatedSavings
    }

    /// Totales de gasto de los últimos N meses (incluido el seleccionado).
    /// Llamado con 24 meses fijos — el chart hace scroll horizontal mostrando ventana de 6.
    private func monthlyEvolution(months: Int) -> [MonthlySpending] {
        let cal = Calendar.current
        var out: [MonthlySpending] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let d = cal.date(byAdding: .month, value: -offset, to: viewModel.selectedMonth)
            else { continue }
            let key = String(Formatters.localDayString(from: d).prefix(7)) // YYYY-MM
            let total = viewModel.allHistoricalExpenses
                .filter { $0.date.hasPrefix(key) }
                .reduce(0) { $0 + $1.amount }
            let label = cal.shortMonthSymbols[cal.component(.month, from: d) - 1]
            out.append(MonthlySpending(key: key, label: label.capitalized, total: total))
        }
        return out
    }

    private func buildChartData() -> [CategoryChartData] {
        // 1 pasada: acumula importe por categoría (sin leer color en el loop)
        var amounts: [String: Double] = [:]
        for expense in viewModel.filteredExpenses {
            amounts[expense.category, default: 0] += expense.amount
        }
        let total = filteredTotal

        // Mes anterior al seleccionado → "YYYY-MM" para comparar tendencia
        let cal = Calendar.current
        let prevPrefix: String? = cal.date(byAdding: .month, value: -1, to: viewModel.selectedMonth)
            .map { String(Formatters.localDayString(from: $0).prefix(7)) }
        var prevAmounts: [String: Double] = [:]
        if let prefix = prevPrefix {
            for e in viewModel.allHistoricalExpenses where e.date.hasPrefix(prefix) {
                prevAmounts[e.category, default: 0] += e.amount
            }
        }

        // color() solo 1× por categoría única (antes 1× por gasto)
        return amounts.map { key, amount in
            let prev = prevAmounts[key]
            let delta: Double? = (prev != nil && prev! > 0) ? (amount - prev!) / prev! : nil
            return CategoryChartData(
                name: key,
                amount: amount,
                percentage: total > 0 ? (amount / total) * 100 : 0,
                color: UserDataManager.shared.color(for: key),
                deltaVsPrevious: delta
            )
        }.sorted { $0.amount > $1.amount }
    }

    // MARK: - View States
    private var loadingView: some View {
        ExpenseListSkeleton()
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            ContentUnavailableView {
                Label("Sin gastos", systemImage: "wallet.bifold")
            } description: {
                Text("Añade tu primer gasto del mes")
            }
            Spacer()
        }
    }

    private func errorView(_ msg: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(msg)
        } actions: {
            Button("Reintentar") {
                Task { await viewModel.loadExpenses() }
            }
        }
    }
}

// MARK: - Monthly Evolution

struct MonthlySpending: Identifiable, Equatable {
    var id: String { key }
    let key: String      // "YYYY-MM"
    let label: String    // "Ene"
    let total: Double
}

struct MonthlyEvolutionChart: View {
    let data: [MonthlySpending]
    let selectedMonthKey: String
    @Binding var range: Int

    @State private var reveal: CGFloat = 0          // animación de entrada (0→1)
    @State private var scrubKey: String?            // mes bajo el dedo (scrub)
    @Environment(\.colorScheme) private var scheme

    // Precomputado (sin recompute en cada render)
    private var maxTotal: Double { data.map(\.total).max() ?? 1 }
    private var nonZero: [Double] { data.map(\.total).filter { $0 > 0 } }
    private var avg: Double { nonZero.isEmpty ? 0 : nonZero.reduce(0,+) / Double(nonZero.count) }

    /// Mes mostrado en cabecera: el que tocas (scrub) o el seleccionado.
    private var focused: MonthlySpending? {
        if let k = scrubKey { return data.first { $0.key == k } }
        return data.first { $0.key == selectedMonthKey } ?? data.last
    }

    /// Variación del mes enfocado vs el anterior en la serie.
    private var focusedDelta: Double? {
        guard let f = focused, let i = data.firstIndex(where: { $0.key == f.key }), i > 0 else { return nil }
        let prev = data[i - 1].total
        guard prev > 0 else { return nil }
        return (f.total - prev) / prev
    }

    private var accent: LinearGradient {
        LinearGradient(
            colors: [Color.clarityPrimary, Color.clarityAccent],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            chart
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.06), radius: 12, y: 6)
        }
        .onAppear {
            reveal = 0
            withAnimation(.easeOut(duration: 0.9)) { reveal = 1 }
        }
    }


    // MARK: Header (valor grande + tendencia + selector)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(scrubKey != nil ? "Detalle" : "Evolución")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text((focused?.total ?? 0).formattedCurrency)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: focused?.total)

                    if let d = focusedDelta, abs(d) >= 0.01 {
                        let up = d > 0
                        HStack(spacing: 2) {
                            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                            Text("\(abs(Int((d*100).rounded())))%")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(up ? Color.red : Color.green)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((up ? Color.red : Color.green).opacity(0.14), in: Capsule())
                    }
                }

                Text(headerSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Picker("", selection: $range) {
                Text("6M").tag(6)
                Text("1A").tag(12)
            }
            .pickerStyle(.segmented)
            .frame(width: 96)
        }
    }

    private var headerSubtitle: String {
        if let f = focused, scrubKey != nil {
            return mesAnio(f.key)
        }
        return avg > 0 ? "media \(avg.formattedCurrency)/mes" : "Sin gastos en el periodo"
    }

    // MARK: Chart (área + línea + punto + scrub)

    private var chart: some View {
        Chart {
            ForEach(data) { item in
                AreaMark(
                    x: .value("Mes", item.label),
                    y: .value("Gasto", item.total * Double(reveal))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.clarityPrimary.opacity(0.35), Color.clarityPrimary.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Mes", item.label),
                    y: .value("Gasto", item.total * Double(reveal))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(accent)
            }

            if avg > 0 {
                RuleMark(y: .value("Media", avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.35))
            }

            // Punto destacado (mes enfocado)
            if let f = focused, reveal > 0.95 {
                PointMark(
                    x: .value("Mes", f.label),
                    y: .value("Gasto", f.total)
                )
                .symbolSize(140)
                .foregroundStyle(Color.clarityPrimary)
                .annotation(position: .top, spacing: 6) {
                    Text(shortAmount(f.total))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                if scrubKey != nil {
                    RuleMark(x: .value("Mes", f.label))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.clarityPrimary.opacity(0.4))
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(range: .plotDimension(padding: 14))
        .frame(height: 160)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plot = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plot].origin.x
                                if let label: String = proxy.value(atX: x) {
                                    if let hit = data.first(where: { $0.label == label }),
                                       hit.key != scrubKey {
                                        scrubKey = hit.key
                                        HapticManager.shared.selection()
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.snappy) { scrubKey = nil }
                            }
                    )
            }
        }
    }

    private func shortAmount(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.1fk €", v / 1000) : String(format: "%.0f €", v)
    }

    private func mesAnio(_ key: String) -> String {
        // key = "YYYY-MM"
        let parts = key.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]) else { return key }
        let cal = Calendar.current
        let name = cal.standaloneMonthSymbols[(m - 1) % 12].capitalized
        return "\(name) \(parts[0])"
    }
}

#Preview {
    HomeView()
}
