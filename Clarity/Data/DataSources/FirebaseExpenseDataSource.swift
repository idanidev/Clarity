// FirebaseExpenseDataSource.swift
// Remote data source for Expenses with pagination support

import Foundation
import FirebaseFirestore
import FirebaseAuth

import FirebaseFirestore
import FirebaseAuth

// PageResult is now defined in ExpenseRepositoryProtocol.swift

actor FirebaseExpenseDataSource {
    private let db = Firestore.firestore()
    private let pageSize = 50
    
    // Pagination state
    private var lastDocument: DocumentSnapshot?
    private var hasMorePages = true
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var expensesCollection: CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("expenses")
    }
    
    // MARK: - Paginated Fetch
    
    /// Fetches the first page and resets pagination state
    func getFirstPage() async throws -> PageResult {
        lastDocument = nil
        hasMorePages = true
        return try await getNextPage()
    }
    
    /// Fetches the next page using cursor
    func getNextPage() async throws -> PageResult {
        guard hasMorePages else {
            return PageResult(expenses: [], hasMore: false)
        }
        
        guard let collection = expensesCollection else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var query = collection
            .order(by: "date", descending: true)
            .limit(to: pageSize)
        
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        
        lastDocument = snapshot.documents.last
        hasMorePages = snapshot.documents.count == pageSize
        
        let expenses = snapshot.documents.compactMap { doc -> Expense? in
            guard let dto = try? doc.data(as: ExpenseDTO.self) else { return nil }
            return dto.toDomain(id: doc.documentID)
        }
        
        return PageResult(expenses: expenses, hasMore: hasMorePages)
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
    
    /// Resets pagination state
    func resetPagination() {
        lastDocument = nil
        hasMorePages = true
    }
    
    // MARK: - Write Operations
    
    func addExpense(_ expense: Expense) async throws -> String {
        guard let collection = expensesCollection else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let docRef = collection.document()
        let dto = ExpenseDTO(from: expense)
        try docRef.setData(from: dto)
        return docRef.documentID
    }
    
    func updateExpense(_ expense: Expense) async throws {
        guard let collection = expensesCollection, let id = expense.id else {
            throw URLError(.userAuthenticationRequired)
        }
        let dto = ExpenseDTO(from: expense)
        try collection.document(id).setData(from: dto, merge: true)
    }
    
    func deleteExpense(id: String) async throws {
        guard let collection = expensesCollection else {
            throw URLError(.userAuthenticationRequired)
        }
        try await collection.document(id).delete()
    }
}
