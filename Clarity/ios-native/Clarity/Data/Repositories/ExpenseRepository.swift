// ExpenseRepository.swift
// Firestore repository for expenses

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
    
    // MARK: - CRUD Operations
    
    func fetchExpenses(for month: String? = nil) async throws -> [Expense] {
        guard let collection = expensesCollection else {
            throw RepositoryError.notAuthenticated
        }
        
        var query: Query = collection.order(by: "date", descending: true)
        
        if let month = month {
            let startDate = "\(month)-01"
            let endDate = "\(month)-31"
            query = query
                .whereField("date", isGreaterThanOrEqualTo: startDate)
                .whereField("date", isLessThanOrEqualTo: endDate)
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc -> Expense? in
            let data = doc.data()
            guard let amount = data["amount"] as? Double,
                  let name = data["name"] as? String,
                  let category = data["category"] as? String,
                  let date = data["date"] as? String,
                  let paymentMethod = data["paymentMethod"] as? String else {
                return nil
            }
            
            return Expense(
                id: doc.documentID,
                amount: amount,
                name: name,
                category: category,
                subcategory: data["subcategory"] as? String,
                date: date,
                paymentMethod: paymentMethod,
                notes: data["notes"] as? String,
                isDeductible: data["isDeductible"] as? Bool,
                recurring: data["recurring"] as? Bool,
                isRecurring: data["isRecurring"] as? Bool,
                recurringId: data["recurringId"] as? String
            )
        }
    }
    
    /// Fetch expenses by date range (start and end dates in yyyy-MM-dd format)
    func fetchExpenses(startDate: String, endDate: String) async throws -> [Expense] {
        guard let collection = expensesCollection else {
            throw RepositoryError.notAuthenticated
        }
        
        let query = collection
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .order(by: "date", descending: true)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc -> Expense? in
            let data = doc.data()
            guard let amount = data["amount"] as? Double,
                  let name = data["name"] as? String,
                  let category = data["category"] as? String,
                  let date = data["date"] as? String,
                  let paymentMethod = data["paymentMethod"] as? String else {
                return nil
            }
            
            return Expense(
                id: doc.documentID,
                amount: amount,
                name: name,
                category: category,
                subcategory: data["subcategory"] as? String,
                date: date,
                paymentMethod: paymentMethod,
                notes: data["notes"] as? String,
                isDeductible: data["isDeductible"] as? Bool,
                recurring: data["recurring"] as? Bool,
                isRecurring: data["isRecurring"] as? Bool,
                recurringId: data["recurringId"] as? String
            )
        }
    }
    
    func addExpense(_ expense: Expense) async throws -> String {
        guard let collection = expensesCollection else {
            throw RepositoryError.notAuthenticated
        }
        
        let now = Date()
        
        let data: [String: Any] = [
            "amount": expense.amount,
            "name": expense.name,
            "category": expense.category,
            "subcategory": expense.subcategory as Any,
            "date": expense.date,
            "paymentMethod": expense.paymentMethod,
            "notes": expense.notes as Any,
            "isDeductible": expense.isDeductible as Any,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ]
        
        let docRef = try await collection.addDocument(data: data)
        return docRef.documentID
    }
    
    func updateExpense(_ expense: Expense) async throws {
        guard let collection = expensesCollection,
              let id = expense.id else {
            throw RepositoryError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "amount": expense.amount,
            "name": expense.name,
            "category": expense.category,
            "subcategory": expense.subcategory as Any,
            "date": expense.date,
            "paymentMethod": expense.paymentMethod,
            "notes": expense.notes as Any,
            "isDeductible": expense.isDeductible as Any,
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await collection.document(id).updateData(data)
    }
    
    func deleteExpense(id: String) async throws {
        guard let collection = expensesCollection else {
            throw RepositoryError.notAuthenticated
        }
        
        try await collection.document(id).delete()
    }
    
    // MARK: - Real-time Listener
    
    func listenToExpenses(month: String?, onUpdate: @escaping ([Expense]) -> Void) -> ListenerRegistration? {
        guard let collection = expensesCollection else { return nil }
        
        var query: Query = collection.order(by: "date", descending: true)
        
        if let month = month {
            let startDate = "\(month)-01"
            let endDate = "\(month)-31"
            query = query
                .whereField("date", isGreaterThanOrEqualTo: startDate)
                .whereField("date", isLessThanOrEqualTo: endDate)
        }
        
        return query.addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            
            let expenses = documents.compactMap { doc -> Expense? in
                let data = doc.data()
                guard let amount = data["amount"] as? Double,
                      let name = data["name"] as? String,
                      let category = data["category"] as? String,
                      let date = data["date"] as? String,
                      let paymentMethod = data["paymentMethod"] as? String else {
                    return nil
                }
                
                return Expense(
                    id: doc.documentID,
                    amount: amount,
                    name: name,
                    category: category,
                    subcategory: data["subcategory"] as? String,
                    date: date,
                    paymentMethod: paymentMethod,
                    notes: data["notes"] as? String
                )
            }
            
            onUpdate(expenses)
        }
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
