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
                Color(.systemGroupedBackground).ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scrollContent
                }
            }
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
    }

    // MARK: - Main scroll

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard

                if viewModel.goals.isEmpty {
                    emptyGoals
                } else {
                    goalsContent
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Month header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "financial.summary.thisMonth", defaultValue: "Este mes"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text("\(viewModel.currentMonthName.capitalized) \(viewModel.currentYear)")
                        .font(.headline)
                }
                Spacer()
                Button {
                    viewModel.showSalarySettings = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }

            // Stats row
            HStack(spacing: 0) {
                statColumn(title: String(localized: "financial.summary.income", defaultValue: "Ingresos"), amount: viewModel.income, color: .primary)

                Divider().frame(height: 40)

                statColumn(
                    title: String(localized: "financial.summary.spent", defaultValue: "Gastado"),
                    amount: viewModel.totalSpent,
                    color: spendingRatio > 0.9 ? .red : spendingRatio > 0.7 ? .orange : .primary
                )

                Divider().frame(height: 40)

                statColumn(
                    title: String(localized: "financial.summary.free", defaultValue: "Libre"),
                    amount: viewModel.freeCash,
                    color: viewModel.freeCash >= 0 ? Color.clarityPrimary : .red
                )
            }

            // Spending bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(barColor)
                        .frame(width: min(CGFloat(spendingRatio) * geo.size.width, geo.size.width))
                        .animation(.spring(response: 0.5), value: spendingRatio)
                }
            }
            .frame(height: 6)

            // Savings allocated footnote
            if viewModel.savingsAllocated > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "banknote")
                    Text("\(Formatters.currency(viewModel.savingsAllocated)) guardado en huchas")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func statColumn(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Formatters.currency(amount))
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var spendingRatio: Double {
        guard viewModel.income > 0 else { return 0 }
        return min(viewModel.totalSpent / viewModel.income, 1.0)
    }

    private var barColor: Color {
        spendingRatio > 0.9 ? .red : spendingRatio > 0.7 ? .orange : Color.clarityPrimary
    }

    // MARK: - Goals Content

    private var goalsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.spendingLimits.isEmpty {
                sectionLabel(String(localized: "financial.goals.spendingLimits", defaultValue: "Límites de Gasto"))
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
                sectionLabel(String(localized: "financial.goals.piggyBanks", defaultValue: "Huchas"))
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    // MARK: - Empty State

    private var emptyGoals: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 8)

            VStack(spacing: 6) {
                Text("Tus metas financieras")
                    .font(.title3.bold())
                Text("Dos herramientas para ordenar tu dinero")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                explainerCard(
                    icon: "🐖",
                    iconBg: Color.clarityPrimary.opacity(0.18),
                    title: "Hucha",
                    subtitle: "Ahorra hacia un objetivo",
                    example: "Ej: 1.500€ para vacaciones. Cada aportación se registra como gasto y suma a tu hucha."
                )
                explainerCard(
                    icon: "🛡️",
                    iconBg: Color.warning.opacity(0.18),
                    title: "Escudo",
                    subtitle: "Limita el gasto mensual de una categoría",
                    example: "Ej: máximo 200€/mes en Ocio. Clarity te avisa cuando te acercas al límite."
                )
            }

            Button {
                viewModel.showAddGoal = true
                HapticManager.shared.impact(.light)
            } label: {
                Label("Crear mi primera meta", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.clarityPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer().frame(height: 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func explainerCard(icon: String, iconBg: Color, title: String, subtitle: String, example: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(icon)
                .font(.system(size: 28))
                .frame(width: 52, height: 52)
                .background(Circle().fill(iconBg))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(example)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
