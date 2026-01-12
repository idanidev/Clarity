// ExpenseRepository.swift
// Data layer implementation of the repository contract

import Foundation
import OSLog

final class ExpenseRepository: ExpenseRepositoryProtocol {
    private let remoteDataSource: FirebaseExpenseDataSource
    private let localDataSource: LocalExpenseDataSource
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "ExpenseRepo")
    
    init(remote: FirebaseExpenseDataSource, local: LocalExpenseDataSource) {
        self.remoteDataSource = remote
        self.localDataSource = local
    }
    
    // MARK: - Read
    
    func getExpenses(policy: CachePolicy) async throws -> [Expense] {
        switch policy {
        case .cacheFirst(let maxAge):
            // Check local cache
            let cached = await localDataSource.getExpenses()
            let lastUpdate = await localDataSource.lastUpdateTimestamp()
            
            let isFresh = if let lastUpdate {
                Date().timeIntervalSince(lastUpdate) < maxAge
            } else {
                false
            }
            
            if !cached.isEmpty && isFresh {
                logger.debug("Returning cached expenses (fresh)")
                
                // Trigger background sync safely
                Task {
                    try? await syncFromRemote()
                }
                
                return cached
            }
            
            // varied: if cache is stale or empty, try network, fallback to cache
            logger.debug("Cache stale or empty, fetching remote")
            return try await fetchAndCache()
            
        case .networkFirst:
            do {
                return try await fetchAndCache()
            } catch {
                logger.warning("Network failed, checking cache: \(error.localizedDescription)")
                let cached = await localDataSource.getExpenses()
                if !cached.isEmpty {
                    return cached
                }
                throw error
            }
            
        case .cacheOnly:
            return await localDataSource.getExpenses()
        }
    }
    
    /// Default convenience: Cache First (5 min)
    func getExpenses() async throws -> [Expense] {
        try await getExpenses(policy: .cacheFirst(maxAge: 300))
    }
    
    // MARK: - Write
    
    func addExpense(_ expense: Expense) async throws -> String {
        // 1. Add to remote (Truth)
        let id = try await remoteDataSource.addExpense(expense)
        
        // 2. Add to local with specific ID returned by Firestore
        var expenseWithId = expense
        expenseWithId.id = id
        try await localDataSource.add(expenseWithId)
        
        return id
    }
    
    func deleteExpense(id: String) async throws {
        try await remoteDataSource.deleteExpense(id: id)
        try await localDataSource.delete(id)
    }
    
    func updateExpense(_ expense: Expense) async throws {
        try await remoteDataSource.updateExpense(expense)
        try await localDataSource.update(expense)
    }
    
    // MARK: - Helpers
    
    private func fetchAndCache() async throws -> [Expense] {
        let remote = try await remoteDataSource.getExpenses()
        try await localDataSource.save(remote, timestamp: Date())
        return remote
    }
    
    private func syncFromRemote() async throws {
        logger.debug("Backgound syncing...")
        let remote = try await remoteDataSource.getExpenses()
        try await localDataSource.save(remote, timestamp: Date())
        logger.debug("Background sync complete")
    }
}
