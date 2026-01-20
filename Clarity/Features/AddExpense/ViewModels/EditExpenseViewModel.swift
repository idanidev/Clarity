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
    
    // Original Expense ID
    private let expenseId: String
    
    // MARK: - State
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var wasAutoCategorized = false // Usually false for edits, but keeps parity
    
    // MARK: - Dependencies
    private let repository = DependencyContainer.shared.expenseRepository
    
    // MARK: - Init
    init(expense: Expense) {
        self.expenseId = expense.id ?? ""
        self.amount = expense.amount
        self.name = expense.name
        self.category = expense.category
        self.subcategory = expense.subcategory
        
        // Parse Date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsedDate = formatter.date(from: expense.date) {
            self.date = parsedDate
        }
        
        // Parse Payment Method
        if let method = PaymentMethod(rawValue: expense.paymentMethod) {
            self.paymentMethod = method
        } else {
            self.paymentMethod = .otro // Fallback
        }
        
        self.notes = expense.notes ?? ""
    }
    
    // MARK: - Validation
    var isValid: Bool {
        guard let amount = amount, amount > 0 else { return false }
        return !name.isEmpty && !category.isEmpty
    }
    
    // MARK: - Methods
    func save() async {
        guard isValid, let amount = amount else { return }
        
        isLoading = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let updatedExpense = Expense(
            id: expenseId,
            amount: amount,
            name: name,
            category: category,
            subcategory: subcategory,
            date: dateString,
            paymentMethod: paymentMethod.rawValue,
            notes: notes.isEmpty ? nil : notes,
            isDeductible: false // Preserved or default
        )
        
        do {
            try await repository.updateExpense(updatedExpense)
            HapticManager.shared.expenseEdited()
            FeedbackManager.shared.show(.success, title: "Gasto actualizado", message: "\(name) guardado correctamente")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            FeedbackManager.shared.show(.error, title: "Error al actualizar", message: error.localizedDescription)
        }

        isLoading = false
    }
}
