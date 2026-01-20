// ExpenseRepository.swift
// Data layer implementation of the repository contract

import Foundation
import OSLog

@MainActor
final class ExpenseRepository: ExpenseRepositoryProtocol {
    private let remoteDataSource: FirebaseExpenseDataSource
    private let swiftDataSource: SwiftDataExpenseDataSource
    private let legacyDataSource: LocalExpenseDataSource? // Optional for migration
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "ExpenseRepo")
    
    init(remote: FirebaseExpenseDataSource, swiftData: SwiftDataExpenseDataSource, legacy: LocalExpenseDataSource? = nil) {
        self.remoteDataSource = remote
        self.swiftDataSource = swiftData
        self.legacyDataSource = legacy
        
        Task { await checkMigration() }
    }
    
    // MARK: - Migration
    
    private func checkMigration() async {
        let key = "didMigrateToSwiftData_v1"
        guard !UserDefaults.standard.bool(forKey: key), let legacy = legacyDataSource else { return }
        
        logger.info("Starting migration from JSON to SwiftData...")
        
        let legacyExpenses = await legacy.getExpenses()
        guard !legacyExpenses.isEmpty else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }
        
        do {
            for expense in legacyExpenses {
                try swiftDataSource.upsertExpense(expense)
            }
            UserDefaults.standard.set(true, forKey: key)
            logger.info("Migration successful. Moved \(legacyExpenses.count) items.")
            
            // Optional: Clear legacy? 
            // try? await legacy.clear() 
            // Keeping it for safety for now.
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Read
    
    func getExpenses(policy: CachePolicy) async throws -> [Expense] {
        switch policy {
        case .cacheFirst(let maxAge):
            // Check SwiftData
            let cached = try swiftDataSource.fetchExpenses()
            
            // "Freshness" in SwiftData is tricky without a metadata table.
            // For now, we assume if we have data, it's good, but we trigger sync.
            // Improve: Store last sync timestamp in UserDefaults.
            
            if !cached.isEmpty {
                logger.debug("Returning SwiftData expenses")
                
                Task {
                    try? await syncFromRemote()
                }
                
                return cached
            }
            
            logger.debug("SwiftData empty, fetching remote")
            return try await fetchAndCache()
            
        case .networkFirst:
            do {
                return try await fetchAndCache()
            } catch {
                logger.warning("Network failed, checking SwiftData: \(error.localizedDescription)")
                let cached = try swiftDataSource.fetchExpenses()
                if !cached.isEmpty {
                    return cached
                }
                throw error
            }
            
        case .cacheOnly:
            return try swiftDataSource.fetchExpenses()
        }
    }
    
    func getExpenses() async throws -> [Expense] {
        try await getExpenses(policy: .cacheFirst(maxAge: 300))
    }
    
    // MARK: - Paginated Fetch
    
    func getExpensesPaginated(page: Int) async throws -> PageResult {
        if page == 0 {
            let result = try await remoteDataSource.getFirstPage()
            if !result.expenses.isEmpty {
                try await saveToLocal(result.expenses)
            }
            return result
        } else {
            let result = try await remoteDataSource.getNextPage()
            if !result.expenses.isEmpty {
                // Append to local
                try await saveToLocal(result.expenses)
            }
            return result
        }
    }
    
    func resetPagination() async {
        await remoteDataSource.resetPagination()
    }
    
    // MARK: - Write
    
    func addExpense(_ expense: Expense) async throws -> String {
        // 1. Add to remote
        let id = try await remoteDataSource.addExpense(expense)
        
        // 2. Add to local
        var expenseWithId = expense
        expenseWithId.id = id
        try swiftDataSource.addExpense(expenseWithId)
        
        return id
    }
    
    func deleteExpense(id: String) async throws {
        try await remoteDataSource.deleteExpense(id: id)
        try swiftDataSource.deleteExpense(id)
    }
    
    func updateExpense(_ expense: Expense) async throws {
        try await remoteDataSource.updateExpense(expense)
        try swiftDataSource.updateExpense(expense)
    }
    
    // MARK: - Helpers
    
    private func fetchAndCache() async throws -> [Expense] {
        let remote = try await remoteDataSource.getExpenses()
        try await saveToLocal(remote)
        return remote
    }
    
    private func syncFromRemote() async throws {
        logger.debug("Background syncing...")
        let remote = try await remoteDataSource.getExpenses()
        try await saveToLocal(remote)
        logger.debug("Background sync complete")
    }
    
    private func saveToLocal(_ expenses: [Expense]) async throws {
        // Sync strategy: Insert or Update
        for expense in expenses {
           try swiftDataSource.upsertExpense(expense) 
        }
    }
}
