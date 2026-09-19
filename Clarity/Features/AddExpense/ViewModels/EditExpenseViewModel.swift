// EditExpenseViewModel.swift
// ViewModel for editing an existing expense

import Foundation
import Observation

@MainActor
@Observable
class EditExpenseViewModel {
    // MARK: - Form Fields
    var amount: Double?
    var name: String = ""
    var category: String = ""
    var subcategory: String?
    var date: Date = Date()
    var paymentMethod: PaymentMethod = .tarjeta
    var notes: String = ""

    // MARK: - Modo regalo (#37)
    var isShared: Bool = false
    var debtors: [Debtor] = []

    // Original Expense ID
    private let expenseId: String
    /// El gasto tal como llegó. El formulario no enseña estos campos, así que
    /// al guardar se copian de aquí: sin ellos la caché local perdía el vínculo
    /// con la hucha y con el recurrente, y borrar el gasto no devolvía el
    /// dinero a la hucha.
    private let original: Expense

    // MARK: - State
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var wasAutoCategorized = false // Usually false for edits, but keeps parity
    
    // MARK: - Dependencies
    private let repository: ExpenseRepositoryProtocol

    // MARK: - Init
    /// `repository` solo se pasa en los tests; la app usa el del contenedor.
    init(expense: Expense, repository: ExpenseRepositoryProtocol? = nil) {
        self.repository = repository ?? DependencyContainer.shared.expenseRepository
        self.expenseId = expense.id ?? ""
        self.original = expense
        self.amount = expense.amount
        self.name = expense.name
        self.category = expense.category
        self.subcategory = expense.subcategory
        
        // Parse Date — usar parser UTC compartido (consistente con storage)
        if let parsedDate = Formatters.date(from: expense.date) {
            self.date = parsedDate
        }
        
        // Parse Payment Method
        if let method = PaymentMethod(rawValue: expense.paymentMethod) {
            self.paymentMethod = method
        } else {
            self.paymentMethod = .otro // Fallback
        }
        
        self.notes = expense.notes ?? ""
        self.isShared = expense.isShared ?? false
        self.debtors = expense.debtors ?? []
    }
    
    // MARK: - Validation
    var isValid: Bool {
        guard let amount = amount, amount > 0 else { return false }
        return !name.isEmpty && !category.isEmpty
    }
    
    /// Descarta filas en blanco creadas con el stepper y nunca rellenadas.
    private var cleanedDebtors: [Debtor] {
        debtors.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty || $0.amount > 0 }
    }

    /// Un método de pago que no está en la lista (importado, de otra versión)
    /// se abre como «Otro». Si el usuario no lo cambia, se guarda el original:
    /// antes editar el importe lo reescribía a «Otro» para siempre.
    private var paymentMethodRaw: String {
        let conocido = PaymentMethod(rawValue: original.paymentMethod) != nil
        return (!conocido && paymentMethod == .otro) ? original.paymentMethod : paymentMethod.rawValue
    }

    // MARK: - Methods
    func save() async {
        guard isValid, let amount = amount else { return }
        
        isLoading = true
        
        let dateString = Formatters.localDayString(from: date)
        
        let updatedExpense = Expense(
            id: expenseId,
            amount: amount,
            name: name,
            category: category,
            subcategory: subcategory,
            date: dateString,
            paymentMethod: paymentMethodRaw,
            notes: notes.isEmpty ? nil : notes,
            isDeductible: original.isDeductible,
            recurring: original.recurring,
            isRecurring: original.isRecurring,
            recurringId: original.recurringId,
            goalId: original.goalId,
            isShared: isShared ? true : nil,
            debtors: isShared ? cleanedDebtors : nil,
            createdAt: original.createdAt
        )
        
        do {
            try await repository.updateExpense(updatedExpense)
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            HapticManager.shared.expenseEdited()
            FeedbackManager.shared.show(.success, title: "Gasto actualizado", message: "\(name) guardado correctamente")
        } catch {
            errorMessage = error.safeUserMessage
            showError = true
            FeedbackManager.shared.show(.error, title: "Error al actualizar", message: error.safeUserMessage)
        }

        isLoading = false
    }
}
