
import FirebaseAuth
import FirebaseFirestore
// RecurringExpenseRepository.swift
import Foundation
import OSLog

class RecurringExpenseRepository {
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "RecurringExpenseRepository")
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
        // Cache-first: serve from disk instantly, fallback to server (también si cache vacío)
        let query = collection.order(by: "dayOfMonth")
        let snapshot: QuerySnapshot
        do {
            let cached = try await query.getDocuments(source: .cache)
            snapshot = cached.isEmpty ? try await query.getDocuments(source: .server) : cached
        } catch {
            snapshot = try await query.getDocuments(source: .server)
        }
        var results: [RecurringExpense] = []
        for doc in snapshot.documents {
            do {
                let expense = try doc.data(as: RecurringExpense.self)
                results.append(expense)
            } catch {
                logger.warning("⚠️ Failed to decode document \(doc.documentID): \(error)")
            }
        }
        logger.debug("📋 Loaded \(results.count) recurring expenses (\(results.filter { $0.active }.count) active, \(results.filter { !$0.active }.count) paused)")
        return results
    }

    func fetchActive() async throws -> [RecurringExpense] {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        let query = collection.whereField("active", isEqualTo: true)
        let snapshot: QuerySnapshot
        do {
            let cached = try await query.getDocuments(source: .cache)
            snapshot = cached.isEmpty ? try await query.getDocuments(source: .server) : cached
        } catch {
            snapshot = try await query.getDocuments(source: .server)
        }
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
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    func delete(id: String) async throws {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        try await collection.document(id).delete()
    }
}
