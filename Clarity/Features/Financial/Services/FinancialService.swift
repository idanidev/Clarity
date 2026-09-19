//
//  FinancialService.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  Firestore CRUD for Financial Hub
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

/// Firebase service for MonthlyBudget and Goal persistence
@MainActor
class FinancialService {
    static let shared = FinancialService()

    private let db = Firestore.firestore()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "FinancialService")

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    /// Margen antes de dar por perdida una lectura. El mismo que
    /// `ExpenseRepository`. Solo lecturas: una escritura que agota el tiempo
    /// sigue adelante por su cuenta y puede acabar aplicándose.
    private static let remoteReadTimeout: TimeInterval = 8

    // MARK: - Collections
    private func budgetsCollection(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("monthly_budgets")
    }

    private func goalsCollection(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("goals")
    }

    // MARK: - Monthly Budget CRUD

    /// Fetch the budget for a specific month — cache first, server fallback
    func fetchMonthlyBudget(year: Int, month: Int) async throws -> MonthlyBudget? {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }

        let documentId = MonthlyBudget.generateDocumentId(userId: userId, year: year, month: month)
        let docRef = budgetsCollection(userId).document(documentId)

        // Try cache first for instant load; fallback to server if cache is empty/missing.
        // Con tope de espera (#32), alrededor del bloque entero para que el
        // tiempo agotado salga como un error de red y no dispare otra lectura.
        let document = try await withTimeout(Self.remoteReadTimeout) {
            do {
                let cached = try await docRef.getDocument(source: .cache)
                return cached.exists ? cached : try await docRef.getDocument(source: .server)
            } catch {
                return try await docRef.getDocument(source: .server)
            }
        }

        guard document.exists else { return nil }

        return try document.data(as: MonthlyBudget.self)
    }

    /// Fetch the previous month's budget (for "Use same as last month" feature)
    func fetchPreviousMonthBudget() async throws -> MonthlyBudget? {
        let calendar = Calendar.current
        let now = Date()

        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: now) else {
            return nil
        }

        let year = calendar.component(.year, from: previousMonth)
        let month = calendar.component(.month, from: previousMonth)

        return try await fetchMonthlyBudget(year: year, month: month)
    }

    /// Save or update a monthly budget
    func saveMonthlyBudget(_ budget: MonthlyBudget) async throws {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }

        var budgetToSave = budget
        budgetToSave.userId = userId
        budgetToSave.updatedAt = Date()

        let documentId = MonthlyBudget.generateDocumentId(
            userId: userId, year: budget.year, month: budget.month)

        try await budgetsCollection(userId).document(documentId).setData(
            from: budgetToSave, merge: true)
        logger.info("✅ Saved budget for \(budget.year)-\(budget.month)")
    }

    /// Persiste la lista completa de ingresos extra del mes. updateData targeted —
    /// NO usa saveMonthlyBudget (setData del doc entero) para no pisar
    /// savingsAllocated, que se actualiza con FieldValue.increment concurrentes.
    /// Requiere que el budget del mes exista (el VM lo garantiza tras load()).
    func updateExtraIncomes(_ entries: [IncomeEntry], year: Int, month: Int) async throws {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }

        let documentId = MonthlyBudget.generateDocumentId(userId: userId, year: year, month: month)
        let dicts = try entries.map { try Firestore.Encoder().encode($0) }

        try await budgetsCollection(userId).document(documentId).updateData([
            "extraIncomes": dicts,
            "updatedAt": FieldValue.serverTimestamp(),
        ])

        logger.info("💵 Updated extraIncomes (\(entries.count) entradas)")
    }

    /// Update only the savingsAllocated field (for feeding piggy banks)
    func updateSavingsAllocated(year: Int, month: Int, amount: Double) async throws {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }

        let documentId = MonthlyBudget.generateDocumentId(userId: userId, year: year, month: month)

        try await budgetsCollection(userId).document(documentId).updateData([
            "savingsAllocated": FieldValue.increment(amount),
            "updatedAt": FieldValue.serverTimestamp(),
        ])

        logger.info("💰 Updated savingsAllocated")
    }

    // MARK: - Goals CRUD

    /// Fetch all active goals for the current user — cache first
    func fetchGoals() async throws -> [Goal] {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }

        let query = goalsCollection(userId)
            .whereField("userId", isEqualTo: userId)
            .whereField("isArchived", isEqualTo: false)

        // Con tope de espera (#32): ver `fetchMonthlyBudget`.
        let snapshot = try await withTimeout(Self.remoteReadTimeout) {
            do {
                let cached = try await query.getDocuments(source: .cache)
                return cached.isEmpty ? try await query.getDocuments(source: .server) : cached
            } catch {
                return try await query.getDocuments(source: .server)
            }
        }

        // Una meta que no se puede decodificar desaparecía de la lista sin
        // dejar rastro. Sigue sin salir —no hay caso «desconocido» al que
        // mandarla: los tipos alimentan selectores—, pero ahora se sabe cuál.
        let goals = snapshot.documents.compactMap { doc -> Goal? in
            do {
                return try doc.data(as: Goal.self)
            } catch {
                logger.error("Meta \(doc.documentID, privacy: .public) no decodificable: \(error.localizedDescription)")
                return nil
            }
        }

        logger.info("✅ Fetched \(goals.count) goals")
        return goals
    }

    /// Save or update a goal. Devuelve el id del documento: al crear es el que
    /// asigna Firestore, y sin él la meta en memoria no se podía editar ni
    /// borrar hasta recargar la pestaña.
    @discardableResult
    func saveGoal(_ goal: Goal) async throws -> String {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }

        var goalToSave = goal
        goalToSave.userId = userId
        goalToSave.updatedAt = Date()

        let documentId: String
        if let existingId = goal.documentId {
            try await goalsCollection(userId).document(existingId).setData(
                from: goalToSave, merge: true)
            documentId = existingId
        } else {
            documentId = try await goalsCollection(userId).addDocument(from: goalToSave).documentID
        }

        logger.info("✅ Saved goal: \(goal.name)")
        return documentId
    }

    /// Feed a piggy bank (add to currentAmount and record history)
    func feedPiggyBank(goalId: String, amount: Double, note: String? = nil) async throws {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }

        let entry = Goal.SavedEntry(amount: amount, date: Date(), note: note)

        try await goalsCollection(userId).document(goalId).updateData([
            "currentAmount": FieldValue.increment(amount),
            "savedHistory": FieldValue.arrayUnion([try Firestore.Encoder().encode(entry)]),
            "updatedAt": FieldValue.serverTimestamp(),
        ])

        logger.info("🐖 Fed piggy bank \(goalId, privacy: .private)")
    }

    /// Refund from a piggy bank (decrement currentAmount). Used when the linked expense is deleted.
    func refundPiggyBank(goalId: String, amount: Double) async throws {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }

        try await goalsCollection(userId).document(goalId).updateData([
            "currentAmount": FieldValue.increment(-amount),
            "updatedAt": FieldValue.serverTimestamp(),
        ])

        logger.info("↩️ Refunded piggy bank \(goalId, privacy: .private)")
    }

    func archiveGoal(_ goalId: String) async throws {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }
        try await goalsCollection(userId).document(goalId).updateData([
            "isArchived": true,
            "updatedAt": FieldValue.serverTimestamp(),
        ])

        logger.info("📦 Archived goal \(goalId)")
    }

    func deleteGoal(_ goalId: String) async throws {
        guard let userId = userId else {
            throw FinancialServiceError.notAuthenticated
        }
        try await goalsCollection(userId).document(goalId).delete()
        logger.info("🗑️ Deleted goal \(goalId)")
    }
}

// MARK: - Errors
enum FinancialServiceError: LocalizedError {
    case notAuthenticated
    case documentNotFound
    case encodingError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Usuario no autenticado"
        case .documentNotFound:
            return "Documento no encontrado"
        case .encodingError:
            return "Error al codificar datos"
        }
    }
}
