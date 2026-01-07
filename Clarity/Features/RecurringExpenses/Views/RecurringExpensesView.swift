// RecurringExpensesView.swift
// List of recurring expenses with active/paused sections

import SwiftUI

struct RecurringExpensesView: View {
    @StateObject private var repository = RecurringExpenseRepository()
    @State private var expenses: [RecurringExpense] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    
    private var activeExpenses: [RecurringExpense] {
        expenses.filter { $0.active }.sorted { $0.dayOfMonth < $1.dayOfMonth }
    }
    
    private var pausedExpenses: [RecurringExpense] {
        expenses.filter { !$0.active }.sorted { $0.dayOfMonth < $1.dayOfMonth }
    }
    
    private var totalActiveMonthly: Double {
        activeExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(Color.clarityPrimary)
            } else if expenses.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Gastos Recurrentes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddRecurringExpenseSheet {
                loadExpenses()
            }
        }
        .task {
            loadExpenses()
        }
        .refreshable {
            loadExpenses()
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sin Gastos Recurrentes", systemImage: "repeat.circle")
        } description: {
            Text("Añade suscripciones o pagos que se repiten cada mes")
        } actions: {
            Button("Añadir Gasto Recurrente") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var list: some View {
        List {
            // Active
            if !activeExpenses.isEmpty {
                Section {
                    ForEach(activeExpenses, id: \.stableId) { expense in
                        NavigationLink {
                            RecurringExpenseDetailView(expense: expense) {
                                loadExpenses()
                            }
                        } label: {
                            RecurringExpenseRow(expense: expense) {
                                toggleExpense(expense)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteExpenses(at: indexSet, from: activeExpenses)
                    }
                } header: {
                    HStack {
                        Label("Activos", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Text(Formatters.currency(totalActiveMonthly) + "/mes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.clarityPrimary)
                    }
                } footer: {
                    Text("Se cargarán automáticamente el día indicado")
                        .font(.caption2)
                }
            }
            
            // Paused
            if !pausedExpenses.isEmpty {
                Section {
                    ForEach(pausedExpenses, id: \.stableId) { expense in
                        NavigationLink {
                            RecurringExpenseDetailView(expense: expense) {
                                loadExpenses()
                            }
                        } label: {
                            RecurringExpenseRow(expense: expense) {
                                toggleExpense(expense)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteExpenses(at: indexSet, from: pausedExpenses)
                    }
                } header: {
                    Label("Pausados", systemImage: "pause.circle.fill")
                        .foregroundStyle(.orange)
                } footer: {
                    Text("No se crearán cargos automáticamente")
                        .font(.caption2)
                }
            }
            
            // Add button
            Section {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Añadir Gasto Recurrente", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.clarityPrimary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func loadExpenses() {
        Task {
            do {
                expenses = try await repository.fetchAll()
            } catch {
                print("Error loading recurring expenses: \(error)")
            }
            isLoading = false
        }
    }
    
    private func toggleExpense(_ expense: RecurringExpense) {
        guard let id = expense.id else { return }
        
        // Optimistic update
        if let index = expenses.firstIndex(where: { $0.id == id }) {
            withAnimation(.bouncy) {
                expenses[index].active.toggle()
            }
        }
        
        Task {
            do {
                try await repository.toggleActive(id: id, active: !expense.active)
                HapticManager.impact(.light)
            } catch {
                // Revert on error
                if let index = expenses.firstIndex(where: { $0.id == id }) {
                    expenses[index].active.toggle()
                }
                HapticManager.notification(.error)
            }
        }
    }
    
    private func deleteExpenses(at offsets: IndexSet, from list: [RecurringExpense]) {
        for index in offsets {
            let expense = list[index]
            guard let id = expense.id else { continue }
            
            // Optimistic remove
            expenses.removeAll { $0.id == id }
            
            Task {
                do {
                    try await repository.delete(id: id)
                    HapticManager.notification(.success)
                } catch {
                    loadExpenses() // Reload to restore
                }
            }
        }
    }
}

// MARK: - Row Component

struct RecurringExpenseRow: View {
    let expense: RecurringExpense
    let onToggle: () -> Void
    
    private var categoryColor: Color {
        UserDataManager.shared.color(for: expense.category)
    }
    
    private var emoji: String {
        // Use saved icon, fallback to extracting from category or default
        if let icon = expense.icon, !icon.isEmpty {
            return icon
        }
        let components = expense.category.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "💰" : "💰"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(categoryColor.gradient)
                    .frame(width: 50, height: 50)
                
                Text(emoji)
                    .font(.title3)
            }
            .opacity(expense.active ? 1.0 : 0.5)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.headline)
                    .foregroundStyle(expense.active ? .primary : .secondary)
                
                HStack(spacing: 6) {
                    // Frequency badge
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(expense.frequency.displayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
                    
                    Text("•")
                        .font(.caption2)
                    
                    // Day badge
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text("Día \(expense.dayOfMonth)")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Amount & Toggle
            VStack(alignment: .trailing, spacing: 8) {
                Text(Formatters.currency(expense.amount))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(expense.active ? .primary : .secondary)
                
                Toggle("", isOn: Binding(
                    get: { expense.active },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(.green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        RecurringExpensesView()
    }
}
