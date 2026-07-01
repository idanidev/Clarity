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

    /// Legacy method - fetches ALL expenses (for backwards compatibility)
    func getExpenses() async throws -> [Expense] {
        guard let collection = expensesCollection else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let snapshot = try await collection.order(by: "date", descending: true).getDocuments()
        
        return snapshot.documents.compactMap { doc in
            guard let dto = try? doc.data(as: ExpenseDTO.self) else { return nil }
            return dto.toDomain(id: doc.documentID)
        }
    }
    
    /// Fetches ALL expenses matching the filter (Server-Side Date Filter, No Limit)
    func getExpenses(filter: ExpenseFilter?) async throws -> [Expense] {
        guard let collection = expensesCollection else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // Base Query
        var query: Query = collection
        
        // Apply Date Filter Server-Side
        if let filter = filter, filter.dateRange != .allTime {
            // "All Time" fetches everything.
            // Specific ranges use Firestore index.
            let (start, end) = ExpenseFilter.queryRange(for: filter.dateRange, customStart: filter.customStartDate, customEnd: filter.customEndDate)
            query = query
                .whereField("date", isGreaterThanOrEqualTo: start)
                .whereField("date", isLessThanOrEqualTo: end)
        }
        
        // Always order by date descending
        query = query.order(by: "date", descending: true)
        
        // NO LIMIT - Fetch All
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            guard let dto = try? doc.data(as: ExpenseDTO.self) else { return nil }
            return dto.toDomain(id: doc.documentID)
        }
    }
    
    /// Fetch acotado por rango de fechas ("yyyy-MM-dd" inclusive). Rango sobre un solo
    /// campo + orderBy el mismo campo → NO requiere índice compuesto en Firestore.
    /// Pensado para dedupe de recurrentes y vistas de mes (evita bajar todo el historial).
    func getExpenses(from startDate: String, to endDate: String) async throws -> [Expense] {
        guard let collection = expensesCollection else {
            throw URLError(.userAuthenticationRequired)
        }

        let snapshot = try await collection
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard let dto = try? doc.data(as: ExpenseDTO.self) else { return nil }
            return dto.toDomain(id: doc.documentID)
        }
    }

    // MARK: - Write Operations

    func addExpense(_ expense: Expense) async throws -> String {
        guard let collection = expensesCollection else {
            throw URLError(.userAuthenticationRequired)
        }

        // Si el caller trae id propio NO vacío (p.ej. id determinista
        // "rec_<regla>_<YYYY-MM>" de cargos recurrentes → write idempotente
        // multi-dispositivo), se respeta. Con id nil o "" (flujos manuales/voz),
        // auto-id de Firestore — `document("")` lanzaría excepción de Firestore.
        let customId = expense.id.flatMap { $0.isEmpty ? nil : $0 }
        let docRef = customId.map { collection.document($0) } ?? collection.document()
        let dto = ExpenseDTO(from: expense)
        try await docRef.setData(from: dto)
        return docRef.documentID
    }

    func updateExpense(_ expense: Expense) async throws {
        guard let collection = expensesCollection, let id = expense.id else {
            throw URLError(.userAuthenticationRequired)
        }
        let dto = ExpenseDTO(from: expense)
        try await collection.document(id).setData(from: dto, merge: true)
    }
    
    func deleteExpense(id: String) async throws {
        guard let collection = expensesCollection else {
            throw URLError(.userAuthenticationRequired)
        }
        try await collection.document(id).delete()
    }
}
