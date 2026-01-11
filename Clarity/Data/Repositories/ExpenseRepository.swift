// ExpenseRepository.swift
// Data layer implementation of the repository contract

import Foundation

final class ExpenseRepository: ExpenseRepositoryProtocol {
    private let remoteDataSource: FirebaseExpenseDataSource
    private let localDataSource: LocalExpenseDataSource
    
    init(remote: FirebaseExpenseDataSource, local: LocalExpenseDataSource) {
        self.remoteDataSource = remote
        self.localDataSource = local
    }
    
    func getExpenses() async throws -> [Expense] {
        // Strategy: Return cache if available, but always background sync? 
        // Or User logic: "Primero caché local, luego sincroniza" implies return local if exists, else fetch.
        // But for strict "observable" update, typically we return a stream. 
        // For async/await, we usually just fetch fresh.
        // Let's implementation the user's snippet logic:
        
        let cached = try await localDataSource.getExpenses()
        if !cached.isEmpty {
            return cached
        }
        
        let remote = try await remoteDataSource.getExpenses()
        try await localDataSource.save(remote)
        return remote
    }
    
    func addExpense(_ expense: Expense) async throws {
        // 1. Add to remote
        let _ = try await remoteDataSource.addExpense(expense)
        // 2. Add to local (optimistic or confirmed)
        try await localDataSource.add(expense)
    }
    
    func deleteExpense(id: String) async throws {
        try await remoteDataSource.deleteExpense(id: id)
        try await localDataSource.delete(id)
    }
    
    func updateExpense(_ expense: Expense) async throws {
        try await remoteDataSource.updateExpense(expense)
        // Refresh cache or update local item
        // For simplicity allow next fetch to update or simpler update
        try await localDataSource.add(expense) // Simplistic update
    }
}
