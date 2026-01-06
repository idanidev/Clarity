// BudgetsView.swift
// Budgets and goals view

import SwiftUI

struct BudgetsView: View {
    @State private var viewModel = BudgetsViewModel()
    
    var body: some View {
        List {
            // Monthly Savings Goal Section
            if viewModel.monthlySavingsGoal > 0 {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Meta de Ahorro Mensual")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: viewModel.currentSavings >= viewModel.monthlySavingsGoal ? "checkmark.circle.fill" : "target")
                                .foregroundColor(viewModel.currentSavings >= viewModel.monthlySavingsGoal ? .green : Color.clarityPrimary)
                                .font(.system(size: 24))
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        HStack {
                            Text(Formatters.currency(viewModel.currentSavings))
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.primary)
                            
                            Text("/ \(Formatters.currency(viewModel.monthlySavingsGoal))")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            let percentage = viewModel.monthlySavingsGoal > 0 ? (viewModel.currentSavings / viewModel.monthlySavingsGoal * 100) : 0
                            Text("\(Int(percentage))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        
                        ProgressView(value: min(viewModel.currentSavings, viewModel.monthlySavingsGoal), total: viewModel.monthlySavingsGoal)
                            .tint(viewModel.currentSavings >= viewModel.monthlySavingsGoal ? .green : Color.clarityPrimary)
                        
                        if viewModel.currentSavings >= viewModel.monthlySavingsGoal {
                            Text("¡Meta cumplida! 🎉")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        } else {
                            Text("Te faltan \(Formatters.currency(viewModel.monthlySavingsGoal - viewModel.currentSavings))")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Category Budgets Section
            if viewModel.budgetProgress.isEmpty {
                ContentUnavailableView(
                    "Sin Presupuestos por Categoría",
                    systemImage: "target",
                    description: Text("Configura presupuestos para controlar gastos por categoría")
                )
            } else {
                ForEach(viewModel.budgetProgress) { progress in
                    BudgetProgressRow(progress: progress)
                }
            }
        }
        .navigationTitle("Metas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showEditBudgets = true
                } label: {
                    Text("Editar")
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditBudgets) {
            EditBudgetsSheet(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Budget Progress Row
struct BudgetProgressRow: View {
    let progress: BudgetProgress
    
    private var progressColor: Color {
        if progress.isOverBudget { return .red }
        if progress.isNearLimit { return .orange }
        return .green
    }
    
    private var statusIcon: String {
        if progress.isOverBudget { return "exclamationmark.triangle.fill" }
        if progress.isNearLimit { return "exclamationmark.circle.fill" }
        return "checkmark.circle.fill"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(progress.category)
                    .font(.clarityHeadline)
                
                Spacer()
                
                Image(systemName: statusIcon)
                    .foregroundStyle(progressColor)
            }
            
            HStack {
                Text("€\(progress.spent, specifier: "%.2f")")
                    .font(.claritySubheadline)
                    .fontWeight(.semibold)
                
                Text("/ €\(progress.limit, specifier: "%.0f")")
                    .font(.claritySubheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(progress.percentage, specifier: "%.0f")%")
                    .font(.clarityCaption)
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: min(progress.percentage, 100), total: 100)
                .tint(progressColor)
            
            if progress.isOverBudget {
                Text("¡Presupuesto superado por €\(progress.spent - progress.limit, specifier: "%.2f")!")
                    .font(.clarityCaption)
                    .foregroundStyle(.red)
            } else if progress.isNearLimit {
                Text("Te quedan €\(progress.remaining, specifier: "%.2f")")
                    .font(.clarityCaption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Edit Budgets Sheet
struct EditBudgetsSheet: View {
    var viewModel: BudgetsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(DefaultCategory.allCases, id: \.self) { category in
                    HStack {
                        Text(category.rawValue)
                            .font(.clarityBody)
                        
                        Spacer()
                        
                        TextField(
                            "€0",
                            value: Binding(
                                get: { viewModel.budgetLimits[category.rawValue] ?? 0 },
                                set: { viewModel.budgetLimits[category.rawValue] = $0 }
                            ),
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Editar Presupuestos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await viewModel.saveBudgets()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    BudgetsView()
}
