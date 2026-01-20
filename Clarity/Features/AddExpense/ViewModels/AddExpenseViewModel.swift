// AddExpenseViewModel.swift
// Add expense form logic

import Foundation
import Observation

@MainActor
@Observable
class AddExpenseViewModel {
    // MARK: - Form Fields (No @Published needed)
    var amount: Double?
    var name: String = ""
    var category: String = ""
    var subcategory: String?
    var date: Date = Date()
    // Explicitly ignoring PaymentMethod if it's enum-based and not Observable-compliant, 
    // but enum with rawValue usually works fine if it's Equatable.
    // Assuming PaymentMethod is simple enum, it works with @Observable.
    var paymentMethod: PaymentMethod = .tarjeta
    var notes: String = ""
    
    // MARK: - State
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var wasAutoCategorized = false  // Track if category was auto-filled
    
    // MARK: - Dependencies
    private let repository = DependencyContainer.shared.expenseRepository
    
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

        let expense = Expense(
            amount: amount,
            name: name,
            category: category,
            subcategory: subcategory,
            date: dateString,
            paymentMethod: paymentMethod.rawValue,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            _ = try await repository.addExpense(expense)
            HapticManager.shared.expenseAdded()
            FeedbackManager.shared.show(.success, title: "Gasto añadido", message: "\(name) guardado correctamente")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            FeedbackManager.shared.show(.error, title: "Error al guardar", message: error.localizedDescription)
        }

        isLoading = false
    }
    
    func reset() {
        amount = nil
        name = ""
        category = ""
        subcategory = nil
        date = Date()
        paymentMethod = .tarjeta
        notes = ""
        wasAutoCategorized = false
    }
}
