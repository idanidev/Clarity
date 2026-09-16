//
//  FinancialDashboardView.swift
//  Clarity
//

import SwiftUI

struct FinancialDashboardView: View {
    @State private var viewModel: FinancialHubViewModel
    @AppStorage("metas.onboardingSeen") private var onboardingSeen: Bool = false
    @State private var showOnboarding: Bool = false

    init() {
        _viewModel = State(initialValue: FinancialHubViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HomeFondo()

                if viewModel.isLoading {
                    CargaClarity(texto: "Cargando tus metas")
                } else {
                    scrollContent
                }
            }
            .trackScreen("metas")
            .navigationTitle(String(localized: "financial.navigationTitle", defaultValue: "Metas"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await viewModel.load()
                if !onboardingSeen {
                    try? await Task.sleep(for: .milliseconds(300))
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding, onDismiss: { onboardingSeen = true }) {
                MetasOnboardingSheet()
            }
            .sheet(isPresented: $viewModel.showSalarySettings) {
                SalarySettingsSheetWrapper(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showMonthlySetup) {
                MonthlySetupSheet(
                    monthName: viewModel.currentMonthName,
                    previousMonthIncome: viewModel.previousMonthIncome,
                    onConfirm: { income in
                        Task { await viewModel.createMonthlyBudget(income: income) }
                    }
                )
            }
            .sheet(isPresented: $viewModel.showAddGoal) {
                AddGoalSheet { newGoal in
                    Task { await viewModel.createGoal(newGoal) }
                }
            }
            .sheet(item: $viewModel.editingGoal) { goal in
                AddGoalSheet(editingGoal: goal) { updatedGoal in
                    Task { await viewModel.updateGoal(updatedGoal) }
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.clearError() } }
                )
            ) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
        // Encima del NavigationStack y no dentro, para que el velo tape también
        // el título y el botón de añadir mientras dura la enhorabuena.
        .overlay {
            if let meta = viewModel.huchaCompletada {
                CelebracionClarity(
                    icono: "star.fill",
                    titulo: "¡Hucha completada!",
                    detalle: "Has llegado a \(Formatters.currency(meta.targetAmount)) en \(meta.name).",
                    onCerrar: { viewModel.huchaCompletada = nil }
                )
            }
        }
    }

    // MARK: - Main scroll

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                summaryCard

                if viewModel.goals.isEmpty {
                    emptyGoals
                } else {
                    goalsContent
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xxs)
            .padding(.bottom, Spacing.lg)
        }
    }

    // MARK: - Summary Card

    /// Tarjeta principal, como la de la Home: lo que queda libre en grande y,
    /// debajo, de dónde sale.
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mes y nómina
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "financial.summary.thisMonth", defaultValue: "Este mes"))
                        .estiloEtiquetaClarity()
                    Text("\(viewModel.currentMonthName.capitalized) \(viewModel.currentYear)")
                        .font(.headline)
                }
                Spacer()
                Button {
                    viewModel.showSalarySettings = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            // Libre
            Text(String(localized: "financial.summary.free", defaultValue: "Libre"))
                .estiloEtiquetaClarity()
                .padding(.top, Spacing.md)

            Text(Formatters.currency(viewModel.freeCash))
                .estiloCifraClarity()
                .foregroundStyle(viewModel.freeCash >= 0 ? Color.primary : Color.error)
                .contentTransition(.numericText(value: viewModel.freeCash))
                .animation(.snappy(duration: 0.5), value: viewModel.freeCash)
                .padding(.top, 2)

            // Gastado sobre ingresos
            BarraProgresoClarity(progreso: spendingRatio, color: barColor)
                .padding(.top, 14)

            Divider()
                .padding(.vertical, 14)

            // Ingresos, gastado y lo guardado en huchas
            HStack(alignment: .top, spacing: Spacing.xs) {
                statColumn(
                    title: String(localized: "financial.summary.income", defaultValue: "Ingresos"),
                    amount: viewModel.income,
                    color: Color.primary
                )

                statColumn(
                    title: String(localized: "financial.summary.spent", defaultValue: "Gastado"),
                    amount: viewModel.totalSpent,
                    color: spentColor
                )

                // Como antes, solo si hay algo guardado: una hucha a 0 € no dice nada.
                if viewModel.savingsAllocated > 0 {
                    statColumn(
                        title: String(localized: "financial.goals.piggyBanks", defaultValue: "Huchas"),
                        amount: viewModel.savingsAllocated,
                        color: Color.primary
                    )
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: CornerRadius.xlarge)
    }

    private func statColumn(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
            Text(Formatters.currency(amount))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spendingRatio: Double {
        guard viewModel.income > 0 else { return 0 }
        return min(viewModel.totalSpent / viewModel.income, 1.0)
    }

    private var spentColor: Color {
        spendingRatio > 0.9 ? Color.error : (spendingRatio > 0.7 ? Color.warning : Color.primary)
    }

    private var barColor: Color {
        spendingRatio > 0.9 ? Color.error : (spendingRatio > 0.7 ? Color.warning : Color.success)
    }

    // MARK: - Goals Content

    private var goalsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Primero, porque sale del mismo "Libre" de la tarjeta de arriba.
            if !viewModel.monthlySavingsGoals.isEmpty {
                CabeceraSeccionClarity(
                    titulo: String(localized: "financial.goals.monthlySavings", defaultValue: "Ahorro mensual")
                )
                .padding(.top, Spacing.xs)

                ForEach(viewModel.monthlySavingsGoals) { goal in
                    GoalCardView(
                        goal: goal,
                        monthlySavings: viewModel.monthlySavings,
                        onEdit: { viewModel.editingGoal = goal },
                        onDelete: { Task { await viewModel.deleteGoal(goal.id) } }
                    )
                }
            }

            if !viewModel.spendingLimits.isEmpty {
                CabeceraSeccionClarity(
                    titulo: String(localized: "financial.goals.spendingLimits", defaultValue: "Límites de Gasto")
                )
                .padding(.top, Spacing.xs)

                ForEach(viewModel.spendingLimits) { goal in
                    GoalCardView(
                        goal: goal,
                        spentAmountProvider: { viewModel.getSpentAmount(for: $0) },
                        onEdit: { viewModel.editingGoal = goal },
                        onDelete: { Task { await viewModel.deleteGoal(goal.id) } }
                    )
                }
            }

            if !viewModel.savingsTargets.isEmpty {
                CabeceraSeccionClarity(
                    titulo: String(localized: "financial.goals.piggyBanks", defaultValue: "Huchas")
                )
                .padding(.top, Spacing.xs)

                ForEach(viewModel.savingsTargets) { goal in
                    GoalCardView(
                        goal: goal,
                        spentAmountProvider: { viewModel.getSpentAmount(for: $0) },
                        onFeed: { amount in
                            Task { await viewModel.feedPiggyBank(goalId: goal.id, amount: amount) }
                        },
                        onEdit: { viewModel.editingGoal = goal },
                        onDelete: { Task { await viewModel.deleteGoal(goal.id) } }
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    /// No es `EstadoVacioClarity` porque hay que conservar la explicación de las
    /// tres herramientas: una tarjeta de vidrio por cada una y el botón debajo.
    private var emptyGoals: some View {
        VStack(spacing: Spacing.sm) {
            VStack(spacing: 6) {
                Text("Tus metas financieras")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Tres herramientas para ordenar tu dinero")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xxs)

            explainerCard(
                icon: "🐖",
                iconColor: Color.clarityPrimary,
                title: "Hucha",
                subtitle: "Ahorra hacia un objetivo",
                example: "Ej: 1.500€ para vacaciones. Cada aportación se registra como gasto y suma a tu hucha."
            )
            explainerCard(
                icon: "🛡️",
                iconColor: Color.warning,
                title: "Escudo",
                subtitle: "Limita el gasto mensual de una categoría",
                example: "Ej: máximo 200€/mes en Ocio. Clarity te avisa cuando te acercas al límite."
            )
            explainerCard(
                icon: GoalType.monthlySavings.defaultIcon,
                iconColor: Color.success,
                title: "Ahorro mensual",
                subtitle: "Guarda una cantidad fija cada mes",
                example: "Ej: ahorrar 300€/mes. Lo que te quede de tus ingresos tras gastar cuenta como ahorrado."
            )

            Button {
                viewModel.showAddGoal = true
                HapticManager.shared.impact(.light)
            } label: {
                Label("Crear mi primera meta", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.principalClarity)
            .padding(.top, Spacing.xxs)
        }
    }

    private func explainerCard(icon: String, iconColor: Color, title: String, subtitle: String, example: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            CirculoIconoClarity(icono: icon, color: iconColor, tamano: 52, esSimbolo: icon.contains("."))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                Text(example)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: CornerRadius.large)
    }
}
