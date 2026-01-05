// ExpenseRepository.swift
// Firestore repository for expenses - Using Codable (built into FirebaseFirestore 10+)

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ExpenseRepository: ObservableObject {
    private let db = Firestore.firestore()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var expensesCollection: CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("expenses")
    }
    
    // MARK: - Fetch Expenses (Codable)
    
    func fetchExpenses(for month: String? = nil, limit: Int? = nil) async throws -> [Expense] {
        guard let collection = expensesCollection else {
            throw RepositoryError.notAuthenticated
        }
        
        var query: Query = collection
        
        if let month = month {
            let startDate = "\(month)-01"
            let endDate = "\(month)-31"
            query = query
                .whereField("date", isGreaterThanOrEqualTo: startDate)
                .whereField("date", isLessThanOrEqualTo: endDate)
        }
        
        // Optimization: Order + Limit
        query = query.order(by: "date", descending: true)
        
        if let limit = limit {
            query = query.limit(to: limit)
        }
        
        let snapshot = try await query.getDocuments()
        
        print("🔥 FIREBASE: Found \(snapshot.documents.count) documents (limit: \(limit ?? -1))")
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Expense.self)
        }
    }
    }
    
    func fetchExpenses(startDate: String, endDate: String) async throws -> [Expense] {
        guard let collection = expensesCollection else {
            throw RepositoryError.notAuthenticated
        }
        
        let snapshot = try await collection
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Expense.self)
        }
    }
    
    // MARK: - Add Expense
    
    func addExpense(_ expense: Expense) async throws -> String {
        guard let collection = expensesCollection else {
            throw RepositoryError.notAuthenticated
        }
        
        let now = Date()
        let expenseData = ExpenseCreate(
            amount: expense.amount,
            name: expense.name,
            category: expense.category,
            subcategory: expense.subcategory,
            date: expense.date,
            paymentMethod: expense.paymentMethod,
            notes: expense.notes,
            isDeductible: expense.isDeductible,
            createdAt: now,
            updatedAt: now
        )
        
        let docRef = collection.document()
        try docRef.setData(from: expenseData)
        return docRef.documentID
    }
    
    // MARK: - Update Expense
    
    func updateExpense(_ expense: Expense) async throws {
        guard let collection = expensesCollection,
              let id = expense.id else {
            throw RepositoryError.notAuthenticated
        }
        
        let updateData = ExpenseUpdate(
            amount: expense.amount,
            name: expense.name,
            category: expense.category,
            subcategory: expense.subcategory,
            date: expense.date,
            paymentMethod: expense.paymentMethod,
            notes: expense.notes,
            isDeductible: expense.isDeductible,
            updatedAt: Date()
        )
        
        try collection.document(id).setData(from: updateData, merge: true)
    }
    
    // MARK: - Delete Expense
    
    func deleteExpense(id: String) async throws {
        guard let collection = expensesCollection else {
            throw RepositoryError.notAuthenticated
        }
        try await collection.document(id).delete()
    }
    
    // MARK: - Aggregations
    
    func getTotalForMonth(_ month: String) async throws -> Double {
        let expenses = try await fetchExpenses(for: month)
        return expenses.reduce(0) { $0 + $1.amount }
    }
    
    func getCategoryTotals(for month: String) async throws -> [String: Double] {
        let expenses = try await fetchExpenses(for: month)
        var totals: [String: Double] = [:]
        for expense in expenses {
            totals[expense.category, default: 0] += expense.amount
        }
        return totals
    }
}

// MARK: - Structs auxiliares para crear/actualizar

private struct ExpenseCreate: Codable {
    let amount: Double
    let name: String
    let category: String
    let subcategory: String?
    let date: String
    let paymentMethod: String
    let notes: String?
    let isDeductible: Bool?
    let createdAt: Date
    let updatedAt: Date
}

private struct ExpenseUpdate: Codable {
    let amount: Double
    let name: String
    let category: String
    let subcategory: String?
    let date: String
    let paymentMethod: String
    let notes: String?
    let isDeductible: Bool?
    let updatedAt: Date
}

// MARK: - Errors

enum RepositoryError: LocalizedError {
    case notAuthenticated
    case documentNotFound
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Usuario no autenticado"
        case .documentNotFound:
            return "Documento no encontrado"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
