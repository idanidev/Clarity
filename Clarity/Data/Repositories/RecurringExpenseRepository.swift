// RecurringExpenseRepository.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class RecurringExpenseRepository: ObservableObject {
    private let db = Firestore.firestore()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var collection: CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("recurringExpenses")
    }
    
    func fetchAll() async throws -> [RecurringExpense] {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        let snapshot = try await collection.order(by: "dayOfMonth").getDocuments()
        
        // Debug: log decoding results
        var results: [RecurringExpense] = []
        for doc in snapshot.documents {
            do {
                let expense = try doc.data(as: RecurringExpense.self)
                results.append(expense)
            } catch {
                print("⚠️ Failed to decode document \(doc.documentID): \(error)")
            }
        }
        print("📋 Loaded \(results.count) recurring expenses (\(results.filter { $0.active }.count) active, \(results.filter { !$0.active }.count) paused)")
        return results
    }
    
    func fetchActive() async throws -> [RecurringExpense] {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        let snapshot = try await collection.whereField("active", isEqualTo: true).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: RecurringExpense.self) }
    }
    
    func add(_ expense: RecurringExpense) async throws -> String {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        let docRef = try await collection.addDocument(from: expense)
        return docRef.documentID
    }

    func update(_ expense: RecurringExpense) async throws {
        guard let collection = collection, let id = expense.id else {
            throw RepositoryError.notAuthenticated
        }
        try await collection.document(id).setData(from: expense, merge: true)
    }
    
    func toggleActive(id: String, active: Bool) async throws {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        try await collection.document(id).updateData([
            "active": active,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    func delete(id: String) async throws {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        try await collection.document(id).delete()
    }
}
