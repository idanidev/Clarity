// DebtsViewModel.swift
// Estado de la pantalla "Te deben": gastos en modo regalo con importes
// pendientes de cobrar (#37).

import Foundation
import Observation

@MainActor
@Observable
final class DebtsViewModel {

    struct DebtSummary: Identifiable, Sendable {
        let expense: Expense
        var id: String { expense.stableId }
        var pending: Double { expense.debtors?.pendingAmount ?? 0 }
        var paid: Double { expense.debtors?.paidAmount ?? 0 }
    }

    private(set) var summaries: [DebtSummary] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var showPaid = false

    private let getExpensesUseCase: GetExpensesUseCase
    private let repository: any ExpenseRepositoryProtocol

    init(
        getExpensesUseCase: GetExpensesUseCase,
        repository: any ExpenseRepositoryProtocol
    ) {
        self.getExpensesUseCase = getExpensesUseCase
        self.repository = repository
    }

    /// Total que te deben ahora mismo.
    var totalPending: Double {
        summaries.reduce(0) { $0 + $1.pending }
    }

    /// Total ya devuelto (histórico).
    var totalPaid: Double {
        summaries.reduce(0) { $0 + $1.paid }
    }

    var visibleSummaries: [DebtSummary] {
        showPaid ? summaries : summaries.filter { $0.pending > 0 }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let all = try await getExpensesUseCase.execute(policy: .cacheFirst())
            summaries = all
                .filter { ($0.isShared ?? false) && !($0.debtors?.isEmpty ?? true) }
                .sorted { $0.date > $1.date }
                .map { DebtSummary(expense: $0) }
        } catch {
            errorMessage = error.safeUserMessage
        }
    }

    /// Marca a una persona como que ya te ha pagado (o lo revierte).
    func togglePaid(expenseId: String, debtorId: String) async {
        guard let index = summaries.firstIndex(where: { $0.expense.id == expenseId }),
              var debtors = summaries[index].expense.debtors,
              let debtorIndex = debtors.firstIndex(where: { $0.id == debtorId })
        else { return }

        debtors[debtorIndex].isPaid.toggle()
        let updated = rebuild(summaries[index].expense, debtors: debtors)
        summaries[index] = DebtSummary(expense: updated)

        do {
            try await repository.updateExpense(updated)
            HapticManager.shared.success()
            AnalyticsService.shared.track(.debtSettled)
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
        } catch {
            // Revertir el cambio optimista si el guardado falla.
            debtors[debtorIndex].isPaid.toggle()
            summaries[index] = DebtSummary(expense: rebuild(updated, debtors: debtors))
            errorMessage = error.safeUserMessage
        }
    }

    /// Marca todas las personas de un gasto como pagadas.
    func markAllPaid(expenseId: String) async {
        guard let index = summaries.firstIndex(where: { $0.expense.id == expenseId }),
              let debtors = summaries[index].expense.debtors
        else { return }

        let updatedDebtors = debtors.map { debtor -> Debtor in
            var copy = debtor
            copy.isPaid = true
            return copy
        }
        let updated = rebuild(summaries[index].expense, debtors: updatedDebtors)
        summaries[index] = DebtSummary(expense: updated)

        do {
            try await repository.updateExpense(updated)
            HapticManager.shared.success()
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
        } catch {
            summaries[index] = DebtSummary(expense: rebuild(updated, debtors: debtors))
            errorMessage = error.safeUserMessage
        }
    }

    private func rebuild(_ expense: Expense, debtors: [Debtor]) -> Expense {
        Expense(
            id: expense.id,
            amount: expense.amount,
            name: expense.name,
            category: expense.category,
            subcategory: expense.subcategory,
            date: expense.date,
            paymentMethod: expense.paymentMethod,
            notes: expense.notes,
            isDeductible: expense.isDeductible,
            recurring: expense.recurring,
            isRecurring: expense.isRecurring,
            recurringId: expense.recurringId,
            goalId: expense.goalId,
            isShared: expense.isShared,
            debtors: debtors,
            createdAt: expense.createdAt,
            updatedAt: Date()
        )
    }
}
