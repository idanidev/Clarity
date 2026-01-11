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
        
        let snapshot = try await collection.order(by: "date", descending: true).getDocuments()
        
        return snapshot.documents.compactMap { doc in
            guard let dto = try? doc.data(as: ExpenseDTO.self) else { return nil }
            return dto.toDomain(id: doc.documentID)
        }
    }
    
    func addExpense(_ expense: Expense) async throws -> String {
        guard let collection = expensesCollection else { throw URLError(.userAuthenticationRequired) }
        
        let docRef = collection.document()
        let dto = ExpenseDTO(from: expense)
        try docRef.setData(from: dto)
        return docRef.documentID
    }
    
    func updateExpense(_ expense: Expense) async throws {
        guard let collection = expensesCollection, let id = expense.id else { throw URLError(.userAuthenticationRequired) }
        let dto = ExpenseDTO(from: expense)
        try collection.document(id).setData(from: dto, merge: true)
    }
    
    func deleteExpense(id: String) async throws {
        guard let collection = expensesCollection else { throw URLError(.userAuthenticationRequired) }
        try await collection.document(id).delete()
    }
}


