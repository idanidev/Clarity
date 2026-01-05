// RecurringExpensesView.swift
// List of recurring expenses with toggle and edit capabilities

import SwiftUI

struct RecurringExpensesView: View {
    @StateObject private var repository = RecurringExpenseRepository()
    @State private var expenses: [RecurringExpense] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea().overlay(.regularMaterial)
            
            if isLoading {
                ProgressView().tint(Color.clarityPrimary)
            } else if expenses.isEmpty {
                ContentUnavailableView {
                    Label("Sin gastos recurrentes", systemImage: "repeat.circle")
                } description: {
                    Text("Añade tus suscripciones o pagos fijos")
                } actions: {
                    Button("Añadir gasto recurrente") {
                        showAddSheet = true
                    }
                }
            } else {
                List {
                    ForEach(expenses) { expense in
                        RecurringExpenseRow(
                            expense: expense,
                            onToggle: {
                                toggleExpense(expense)
                            },
                            onDelete: {
                                deleteExpense(expense)
                            }
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
                        .foregroundStyle(Color.clarityPrimary)
                }
            }
        }
        .onAppear {
            loadExpenses()
        }
        .sheet(isPresented: $showAddSheet) {
            AddRecurringExpenseSheet {
                loadExpenses()
            }
        }
    }
    
    private func loadExpenses() {
        isLoading = true
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
            expenses[index].active.toggle()
        }
        
        Task {
            do {
                try await repository.toggleActive(id: id, active: !expense.active)
                HapticManager.selection()
            } catch {
                // Revert on error
                if let index = expenses.firstIndex(where: { $0.id == id }) {
                    expenses[index].active.toggle()
                }
            }
        }
    }
    
    private func deleteExpense(_ expense: RecurringExpense) {
        guard let id = expense.id else { return }
        
        // Optimistic remove
        expenses.removeAll { $0.id == id }
        
        Task {
            do {
                try await repository.delete(id: id)
                HapticManager.notification(.success)
            } catch {
                loadExpenses() // Reload to restore if failed
            }
        }
    }
}

// MARK: - Row Component

struct RecurringExpenseRow: View {
    let expense: RecurringExpense
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon Background
            ZStack {
                Circle()
                    .fill(Color(hex: "#2D2D4A")!)
                    .frame(width: 44, height: 44)
                
                Text(extractEmoji(from: expense.category))
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(expense.active ? .white : .gray)
                
                HStack(spacing: 6) {
                    Text(expense.frequency.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.bgSecondary)
                        .cornerRadius(4)
                    
                    Text("Día \(expense.dayOfMonth)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.currency(expense.amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(expense.active ? .white : .gray)
                
                Toggle("", isOn: Binding(
                    get: { expense.active },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .scaleEffect(0.8)
                .frame(width: 50, height: 30)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.bgPrimary)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
    
    private func extractEmoji(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "📝" : "📝"
    }
}
