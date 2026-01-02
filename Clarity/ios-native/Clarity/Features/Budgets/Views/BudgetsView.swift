// BudgetsView.swift
// Budgets and goals view

import SwiftUI

struct BudgetsView: View {
    @StateObject private var viewModel = BudgetsViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.budgetProgress.isEmpty {
                    ContentUnavailableView(
                        "Sin Presupuestos",
                        systemImage: "target",
                        description: Text("Configura presupuestos mensuales para controlar tus gastos")
                    )
                } else {
                    ForEach(viewModel.budgetProgress) { progress in
                        BudgetProgressRow(progress: progress)
                    }
                }
            }
            .navigationTitle("Presupuestos")
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
    @ObservedObject var viewModel: BudgetsViewModel
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
