// AddExpenseViewModel.swift
// Add expense form logic

import Foundation
import Combine

@MainActor
class AddExpenseViewModel: ObservableObject {
    // MARK: - Form Fields
    @Published var amount: Double?
    @Published var name: String = ""
    @Published var category: String = ""
    @Published var subcategory: String?
    @Published var date: Date = Date()
    @Published var paymentMethod: PaymentMethod = .tarjeta
    @Published var notes: String = ""
    
    // MARK: - State
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let repository = ExpenseRepository()
    
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
        } catch {
            errorMessage = error.localizedDescription
            showError = true
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
    }
}
