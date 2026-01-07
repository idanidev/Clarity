// BudgetsView.swift
// Budgets and goals view - Goal-focused design

import SwiftUI

struct BudgetsView: View {
    @State private var viewModel = BudgetsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Goal Section
                if viewModel.monthlySavingsGoal > 0 {
                    heroGoalCard
                }
                
                // Category Budgets
                if viewModel.budgetProgress.isEmpty {
                    emptyState
                } else {
                    categoryBudgetsSection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Metas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showEditBudgets = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
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
    
    // MARK: - Hero Goal Card
    private var heroGoalCard: some View {
        VStack(spacing: 20) {
            // Circular Progress Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                    .frame(width: 160, height: 160)
                
                // Progress ring
                let progress = min(viewModel.currentSavings / viewModel.monthlySavingsGoal, 1.0)
                let ringStyle: AnyShapeStyle = viewModel.currentSavings >= viewModel.monthlySavingsGoal 
                    ? AnyShapeStyle(Color.green)
                    : AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringStyle, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progress)
                
                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.currentSavings >= viewModel.monthlySavingsGoal ? .green : .primary)
                    
                    Text("completado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Goal Info
            VStack(spacing: 8) {
                Text("🎯 Meta de Ahorro")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text(Formatters.currency(viewModel.currentSavings))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("de \(Formatters.currency(viewModel.monthlySavingsGoal))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Motivational message
                motivationalMessage
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    @ViewBuilder
    private var motivationalMessage: some View {
        let remaining = viewModel.monthlySavingsGoal - viewModel.currentSavings
        let progress = viewModel.currentSavings / viewModel.monthlySavingsGoal
        
        if viewModel.currentSavings >= viewModel.monthlySavingsGoal {
            Label("¡Meta cumplida! 🎉", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.green.opacity(0.15))
                .clipShape(Capsule())
        } else if progress >= 0.75 {
            Label("¡Casi lo logras! Faltan \(Formatters.currency(remaining))", systemImage: "flame.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if progress >= 0.5 {
            Label("¡Vas por buen camino! 💪", systemImage: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.blue)
        } else {
            Label("Faltan \(Formatters.currency(remaining)) para tu meta", systemImage: "target")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Category Budgets Section
    private var categoryBudgetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Presupuestos por Categoría")
                .font(.headline)
                .padding(.leading, 4)
            
            ForEach(viewModel.budgetProgress) { progress in
                BudgetProgressCard(progress: progress)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 50))
                .foregroundStyle(Color.clarityPrimary.gradient)
            
            Text("Sin Presupuestos")
                .font(.title2.weight(.semibold))
            
            Text("Configura presupuestos para controlar\ntus gastos por categoría")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.showEditBudgets = true
            } label: {
                Label("Crear Presupuestos", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.clarityPrimary)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Budget Progress Card
struct BudgetProgressCard: View {
    let progress: BudgetProgress
    
    private var progressColor: Color {
        if progress.isOverBudget { return .red }
        if progress.isNearLimit { return .orange }
        return .green
    }
    
    private var emoji: String {
        if progress.isOverBudget { return "🚨" }
        if progress.isNearLimit { return "⚠️" }
        return "✅"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Mini Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: min(progress.percentage / 100, 1.0))
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text(emoji)
                    .font(.system(size: 16))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.category)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("€\(progress.spent, specifier: "%.0f")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(progressColor)
                    
                    Text("/ €\(progress.limit, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(min(progress.percentage, 999)))%")
                    .font(.headline)
                    .foregroundStyle(progressColor)
                
                if progress.isOverBudget {
                    Text("+€\(progress.spent - progress.limit, specifier: "%.0f")")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    Text("€\(progress.remaining, specifier: "%.0f") left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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
