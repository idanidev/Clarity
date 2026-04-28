// RecurringExpensesView.swift
// List of recurring expenses with active/paused sections

import FirebaseAuth
import SwiftUI

struct RecurringExpensesView: View {
    private let repository = DependencyContainer.shared.recurringExpenseRepository
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
        activeExpenses.reduce(0) { total, expense in
            let monthlyAmount: Double
            switch expense.frequency {
            case .monthly: monthlyAmount = expense.amount
            case .quarterly: monthlyAmount = expense.amount / 3
            case .semestral: monthlyAmount = expense.amount / 6
            case .yearly: monthlyAmount = expense.amount / 12
            }
            return total + monthlyAmount
        }
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
            // Recuperar gastos perdidos al abrir la vista
            await LocalRecurringExpenseManager.shared.recoverMissedExpenses()
        }
        .refreshable {
            loadExpenses()
            await LocalRecurringExpenseManager.shared.recoverMissedExpenses()
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
        }
        .listStyle(.insetGrouped)
    }
    
    private func loadExpenses() {
        Task {
            // Esperar auth en simulador (Keychain tarda más)
            if Auth.auth().currentUser == nil {
                for _ in 0..<5 {
                    try? await Task.sleep(for: .milliseconds(300))
                    if Auth.auth().currentUser != nil { break }
                }
            }
            do {
                expenses = try await repository.fetchAll()
            } catch {
                // Load errors surface via empty state in View
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
                HapticManager.shared.impact(.light)
            } catch {
                // Revert on error
                if let index = expenses.firstIndex(where: { $0.id == id }) {
                    expenses[index].active.toggle()
                }
                HapticManager.shared.notification(.error)
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
                    HapticManager.shared.notification(.success)
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(expense.name)
                        .font(.headline)
                        .foregroundStyle(expense.active ? .primary : .secondary)
                        .lineLimit(1)
                    
                    // Warning indicator if invalid
                    if !expense.isValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Badges — single row for monthly, two rows for non-monthly
                if expense.frequency.needsMonthSelection {
                    VStack(alignment: .leading, spacing: 4) {
                        frequencyBadge
                        HStack(spacing: 6) {
                            dayBadge
                            if expense.billingMonth > 0 {
                                monthBadge(for: expense.billingMonth)
                            } else {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        frequencyBadge
                        dayBadge
                    }
                }
            }
            
            Spacer()
            
            // Amount & Toggle
            VStack(alignment: .trailing, spacing: 6) {
                Text(Formatters.currency(expense.amount))
                    .scaledFont(size: 16, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(expense.active ? .primary : .secondary)
                
                Toggle("", isOn: Binding(
                    get: { expense.active },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(.green)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.name), \(Formatters.currency(expense.amount)), día \(expense.dayOfMonth), \(expense.active ? "activo" : "pausado")")
        .accessibilityHint("Pulsa para ver detalle")
    }
    
    // MARK: - Badge Views

    private var frequencyBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: frequencyIcon)
                .scaledFont(size: 9)
            Text(expense.frequency.displayName)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(frequencyColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(frequencyColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var dayBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
                .scaledFont(size: 9)
            Text("Día \(expense.dayOfMonth)")
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(expense.dayOfMonth == 0 ? .red : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(expense.dayOfMonth == 0 ? Color.red.opacity(0.15) : .secondary.opacity(0.12))
        .clipShape(Capsule())
    }

    private func monthBadge(for month: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar.badge.clock")
                .scaledFont(size: 9)
            Text(Formatters.shortMonthName(month))
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(Color.clarityPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.clarityPrimary.opacity(0.15))
        .clipShape(Capsule())
    }

    // Color based on frequency type
    private var frequencyColor: Color {
        switch expense.frequency {
        case .monthly: return .blue
        case .quarterly: return .orange
        case .semestral: return .purple
        case .yearly: return .green
        }
    }
    
    // Icon based on frequency type
    private var frequencyIcon: String {
        switch expense.frequency {
        case .monthly: return "repeat"
        case .quarterly: return "calendar.badge.clock"
        case .semestral: return "arrow.triangle.2.circlepath"
        case .yearly: return "calendar.badge.exclamationmark"
        }
    }
}

#Preview {
    NavigationStack {
        RecurringExpensesView()
    }
}
