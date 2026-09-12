// HomeView.swift
// Main screen implementing Clean Architecture + MVVM
// Restored full functionality: Tabs (List/Graph/Calendar), 3-Card Summary, No Title

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private var userDataManager = UserDataManager.shared

    // UI State
    @State private var mostrarCalendario = false
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
            .trackScreen("home")
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // La búsqueda nativa se pliega al desplazar, así que no ocupa sitio
            // mientras no se usa —que es casi siempre—.
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Buscar gastos"
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    MonthSelectorView(currentMonth: $viewModel.selectedMonth)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            mostrarCalendario.toggle()
                        }
                        HapticManager.shared.selection()
                    } label: {
                        Image(systemName: mostrarCalendario ? "list.bullet" : "calendar")
                    }
                    .accessibilityLabel(mostrarCalendario ? "Ver como lista" : "Ver como calendario")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        if viewModel.selectedFilter.hasActiveFilters {
                            Button {
                                viewModel.selectedFilter = ExpenseFilter()
                                HapticManager.shared.notification(.success)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel("Limpiar filtros")
                        }

                        Button {
                            showFilterSheet = true
                            HapticManager.shared.selection()
                        } label: {
                            Image(
                                systemName: viewModel.selectedFilter.hasActiveFilters
                                    ? "line.3.horizontal.decrease.circle.fill"
                                    : "line.3.horizontal.decrease.circle"
                            )
                        }
                        .accessibilityLabel("Filtros")
                    }
                    .tint(
                        viewModel.selectedFilter.hasActiveFilters
                            ? DesignTokens.Colors.accent : DesignTokens.Colors.textPrimary
                    )
                }
            }
            .refreshable { await viewModel.refresh() }
            .task {
                await viewModel.loadIfNeeded()
            }
            // Cambios desde otras pantallas (ingreso extra en Ajustes, nómina, huchas…)
            // → recarga SOLO el budget para que el ahorro quede al día. NO recarga la
            // lista de gastos: borrar un gasto postea esta misma notificación y recargar
            // la lista durante la animación de swipe crasheaba la List.
            .onReceive(NotificationCenter.default.publisher(for: .expenseDidChange)) { _ in
                Task { await viewModel.reloadBudget() }
            }
            // El documento puede llegar después de que la Home ya esté montada.
            .onReceive(NotificationCenter.default.publisher(for: .userDocumentDidLoad)) { _ in
                viewModel.applyDefaultFilterIfNeeded()
            }
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
            // Los gastos del mes, por lista o por calendario. El donut de
            // categorías estaba aquí y en Análisis enseñando lo mismo: esta
            // pantalla dice cuánto llevas, la otra dice en qué se te va.
            Group {
                if mostrarCalendario {
                    calendarView
                } else {
                    listView
                }
            }
            .animation(.easeInOut(duration: 0.2), value: mostrarCalendario)
            .padding(.bottom, 60)  // Espacio para el botón de voz

            // Botón de voz, la acción principal de la pantalla
            voiceButtonBar
        }
    }

    // MARK: - Botón de voz

    private var voiceButtonBar: some View {
        HStack {
            Spacer()
            SimpleVoiceButton(
                viewModel: viewModel,
                categories: UserDataManager.shared.categories
            )
        }
        .padding(.trailing, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    // MARK: - Tab 1: List View
    private var listView: some View {
        VStack(spacing: 0) {
            // Sin cabecera fija: los totales bajan dentro de la lista y el mes,
            // la búsqueda y los filtros suben a la barra de navegación.
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
                ) {
                    SummaryCardsView(
                        totalExpenses: filteredTotal,
                        expenseCount: viewModel.filteredExpenses.count,
                        savings: savings,
                        savingsPercentage: savings > 0
                            ? Int((savings / (monthlyIncome > 0 ? monthlyIncome : 1)) * 100)
                            : 0,
                        available: savings
                    )
                }
            }
        }
    }

    // MARK: - Tab 3: Calendar View
    private var calendarView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.allHistoricalExpenses.isEmpty {
                    SinGastosEmptyView(
                        titulo: "El calendario está vacío",
                        mensaje: "Cada gasto que apuntes aparecerá aquí en su día.",
                        icono: "calendar"
                    ) { showAddExpense = true }
                } else {
                    // Historial completo: el calendario navega meses internamente
                    // (con filteredExpenses solo veía el mes seleccionado).
                    ExpenseCalendarView(expenses: viewModel.allHistoricalExpenses)

                    // Evolución mensual — totales pre-agregados en VM (memo dict)
                    let evo = viewModel.monthlyEvolution(months: evolutionMonths)
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

    // MARK: - Helpers
    // Misma fuente que el VM (budget del mes, nómina + extras) — antes leía el
    // income raíz del userDocument y el % de ahorro discrepaba del importe.
    private var monthlyIncome: Double {
        viewModel.monthlyIncome
    }

    // Reusa el total ya calculado por el VM (evita doble reduce por render)
    private var filteredTotal: Double { viewModel.totalFilteredAmount }

    private var savings: Double {
        viewModel.calculatedSavings
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

    /// Qué se encuentra alguien que acaba de terminar el onboarding.
    ///
    /// Antes era un cartel sin salida: "Sin gastos · Añade tu primer gasto del
    /// mes". El usuario venía de que le prometieran que basta con hablar, y
    /// aterrizaba en una frase que le decía qué hacer pero no cómo: el micro
    /// está flotando en otra esquina y el `+` en la barra. De 21 que terminaban
    /// el onboarding, solo 14 llegaban a apuntar algo.
    ///
    /// Ahora la promesa y la acción están en el mismo sitio.
    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()

            Image(systemName: "wallet.bifold")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.clarityPrimary.opacity(0.7))

            Text("Aún no has apuntado nada")
                .scaledFont(size: 20, weight: .semibold)

            Text("Di «20 euros en gasolina» y aparecerá aquí, ya clasificado.")
                .scaledFont(size: 15)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)

            // El mismo gesto que enseña el onboarding, aquí y grande.
            SimpleVoiceButton(
                viewModel: viewModel,
                categories: UserDataManager.shared.categories
            )
            .scaleEffect(1.15)
            .padding(.top, DesignTokens.Spacing.xs)

            Button {
                AnalyticsService.shared.track(.emptyStateAction(method: "manual"))
                showAddExpense = true
                HapticManager.shared.selection()
            } label: {
                Text("Prefiero escribirlo")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(Color.clarityPrimary)
            }
            .padding(.top, DesignTokens.Spacing.xxs)

            Spacer()
        }
        .task { AnalyticsService.shared.track(.emptyStateShown) }
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


#Preview {
    HomeView()
}
