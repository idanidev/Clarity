// BudgetRepository.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class BudgetRepository: ObservableObject {
    private let db = Firestore.firestore()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var budgetsCollection: CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("budgets")
    }
    
    func fetchBudget(for month: String) async throws -> MonthlyBudget? {
        guard let collection = budgetsCollection else {
            throw RepositoryError.notAuthenticated
        }
        let doc = try await collection.document(month).getDocument()
        return try? doc.data(as: MonthlyBudget.self)
    }
    
    func saveBudget(_ budget: MonthlyBudget) async throws {
        guard let collection = budgetsCollection else {
            throw RepositoryError.notAuthenticated
        }
        try collection.document(budget.month).setData(from: budget)
    }
    
    func fetchAllBudgets() async throws -> [MonthlyBudget] {
        guard let collection = budgetsCollection else {
            throw RepositoryError.notAuthenticated
        }
        let snapshot = try await collection.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: MonthlyBudget.self) }
    }
}
