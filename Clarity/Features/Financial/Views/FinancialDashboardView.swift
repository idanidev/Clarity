//
//  FinancialDashboardView.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//  Updated: 2026-01-23 - ViewModel Integration & Monthly Wizard
//

import SwiftUI

struct FinancialDashboardView: View {
    @State private var viewModel = FinancialHubViewModel()
    
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
            .task {
                await viewModel.load()
            }
            .sheet(isPresented: $viewModel.showMonthlySetup) {
                MonthlySetupSheet(
                    monthName: viewModel.currentMonthName,
                    previousMonthIncome: viewModel.previousMonthIncome,
                    onConfirm: { income in
                        Task {
                            await viewModel.createMonthlyBudget(estimatedIncome: income)
                        }
                    }
                )
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
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
                        get: { viewModel.estimatedIncome },
                        set: { newValue in
                            Task { await viewModel.updateEstimatedIncome(newValue) }
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
                            GoalCardView(goal: goal)
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
                            GoalCardView(goal: goal) {
                                Task {
                                    await viewModel.feedPiggyBank(goalId: goal.id, amount: 50)
                                }
                            }
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
                // TODO: Show add goal sheet
            } label: {
                Label("Añadir Meta", systemImage: "plus")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.clarityPrimary))
            }
        }
        .padding(32)
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

