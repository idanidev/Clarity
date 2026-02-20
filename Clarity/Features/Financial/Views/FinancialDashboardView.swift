//
//  FinancialDashboardView.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//  Updated: 2026-01-23 - ViewModel Integration & Monthly Wizard
//

import SwiftUI

struct FinancialDashboardView: View {
    @State private var viewModel: FinancialHubViewModel

    init() {
        print("🟢 FinancialDashboardView: Init")
        _viewModel = State(initialValue: FinancialHubViewModel())
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Cargando...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    dashboardContent
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Balance y Metas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showSalarySettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(isPresented: $viewModel.showSalarySettings) {
                SalarySettingsSheet(
                    income: Binding(
                        get: { viewModel.income },
                        set: { _ in }  // Updated via Save action
                    ),
                    isRecurring: $viewModel.isSalaryRecurring,
                    onSave: {
                        // The sheet manages its own state, but on save we call VM
                        // We need a way to pass the new values back.
                        // Actually, SalarySettingsSheet binds to 'income' and 'isRecurring'
                        // We should adapt it to call VM.
                    }
                )
            }
            // Fix: SalarySettingsSheet logic needs to be cleaner.
            // Let's create a wrapper or binding.
            .sheet(isPresented: $viewModel.showSalarySettings) {
                SalarySettingsSheetWrapper(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showMonthlySetup) {
                MonthlySetupSheet(
                    monthName: viewModel.currentMonthName,
                    previousMonthIncome: viewModel.previousMonthIncome,
                    onConfirm: { income in
                        Task {
                            await viewModel.createMonthlyBudget(income: income)
                        }
                    }
                )
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

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Energy Tank (Income)
                IncomeInputView(
                    income: Binding(
                        get: { viewModel.income },
                        set: { newValue in
                            Task { await viewModel.updateIncome(newValue) }
                        }
                    )
                )

                // 2. Free Cash Indicator
                freeCashCard

                // 3. Spending Limits (Shields)
                if !viewModel.spendingLimits.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🛡️ Escudos (Límites)")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.spendingLimits) { goal in
                            GoalCardView(
                                goal: goal,
                                onArchive: {
                                    Task {
                                        await viewModel.archiveGoal(goal.id)
                                    }
                                }
                            )
                        }
                    }
                }

                // 4. Savings Targets (Piggy Banks)
                if !viewModel.savingsTargets.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🐖 Huchas (Sueños)")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.savingsTargets) { goal in
                            GoalCardView(
                                goal: goal,
                                onFeed: { amount in
                                    Task {
                                        await viewModel.feedPiggyBank(
                                            goalId: goal.id, amount: amount)
                                    }
                                },
                                onArchive: {
                                    Task {
                                        await viewModel.archiveGoal(goal.id)
                                    }
                                }
                            )
                        }
                    }
                }

                // Empty State
                if viewModel.goals.isEmpty {
                    emptyGoalsState
                }
            }
            .padding()
        }
    }

    // MARK: - Components

    private var freeCashCard: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Dinero Libre")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(Formatters.currency(viewModel.freeCash))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(viewModel.freeCash > 0 ? Color.clarityPrimary : .red)
                    .contentTransition(.numericText())
            }

            Spacer()

            ChartPieIcon(percentage: viewModel.freeCashPercentage)
                .frame(width: 40, height: 40)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private var emptyGoalsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Sin metas todavía")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Añade un límite de gasto o una meta de ahorro para empezar a gestionar tu dinero")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.showAddGoal = true
            } label: {
                Label("Añadir Meta", systemImage: "plus")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.clarityPrimary))
                    .shadow(color: Color.clarityPrimary.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(32)
        .sheet(isPresented: $viewModel.showAddGoal) {
            AddGoalSheet { newGoal in
                Task {
                    await viewModel.createGoal(newGoal)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FinancialDashboardView()
}

// MARK: - Helper Views

struct ChartPieIcon: View {
    var percentage: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .systemGray6), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, min(1, percentage)))
                .stroke(Color.clarityPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
