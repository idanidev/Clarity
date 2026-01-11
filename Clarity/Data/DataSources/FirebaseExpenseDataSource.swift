// FirebaseExpenseDataSource.swift
// Remote data source for Expenses

import Foundation
import FirebaseFirestore
import FirebaseAuth

actor FirebaseExpenseDataSource {
    private let db = Firestore.firestore()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var expensesCollection: CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("expenses")
    }
    
    func getExpenses() async throws -> [Expense] {
        guard let collection = expensesCollection else { throw URLError(.userAuthenticationRequired) }
        
        // Fetch all (or implement pagination/filtering here if needed)
        let snapshot = try await collection.order(by: "date", descending: true).getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Expense.self)
        }
    }
    
    func addExpense(_ expense: Expense) async throws -> String {
        guard let collection = expensesCollection else { throw URLError(.userAuthenticationRequired) }
        
        let docRef = collection.document()
        // Note: Expense needs to be Encodable. 
        // We might need to ensure 'id' is nil so Firestore generates it, or use the generated docRef.documentID
        var expenseToAdd = expense
        // If Domain Expense is used directly, we handle mapping here or assuming Codable
        try docRef.setData(from: expenseToAdd)
        return docRef.documentID
    }
    
    func updateExpense(_ expense: Expense) async throws {
        guard let collection = expensesCollection, let id = expense.id else { throw URLError(.userAuthenticationRequired) }
        try collection.document(id).setData(from: expense, merge: true)
    }
    
    func deleteExpense(id: String) async throws {
        guard let collection = expensesCollection else { throw URLError(.userAuthenticationRequired) }
        try await collection.document(id).delete()
    }
}
