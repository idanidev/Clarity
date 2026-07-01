// ExpenseRepositoryProtocol.swift
// Domain contract for Expense data access
// Updated for Phase 2: Caching Strategy

import Foundation

/// Defines how data should be fetched
enum CachePolicy: Sendable {
    /// Return local cache if available and < maxAge, then background sync.
    /// Default maxAge is 5 minutes (300s).
    case cacheFirst(maxAge: TimeInterval = 300)
    
    /// Always fetch from remote, update cache on success.
    /// Fallback to cache if remote fails.
    case networkFirst
    
    /// Only return local data (offline mode).
    case cacheOnly
}

protocol ExpenseRepositoryProtocol: Sendable {
    func getExpenses(policy: CachePolicy) async throws -> [Expense]
    // Convenience overload for default behavior
    func getExpenses() async throws -> [Expense]

    /// Fetch acotado por rango de fechas inclusive ("yyyy-MM-dd").
    /// Remote-first con fallback a cache filtrada; NO muta la cache local
    /// (el sync/orphan-cleanup global sigue siendo cosa de getExpenses(policy:)).
    func getExpenses(from startDate: String, to endDate: String) async throws -> [Expense]

    func addExpense(_ expense: Expense) async throws -> String
    func deleteExpense(id: String) async throws
    func updateExpense(_ expense: Expense) async throws

    // Pagination
    func getExpensesPaginated(page: Int, filter: ExpenseFilter?) async throws -> PageResult
}

// Helper for Domain Pagination
struct PageResult: Sendable {
    let expenses: [Expense]
    let hasMore: Bool
    
    // Default memberwise init is sufficient and prevents isolation issues
}
