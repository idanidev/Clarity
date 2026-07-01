// ExpenseRepository.swift
// Data layer implementation of the repository contract

import FirebaseAuth
import Foundation
import OSLog

@MainActor
final class ExpenseRepository: ExpenseRepositoryProtocol {
    private let remoteDataSource: FirebaseExpenseDataSource
    private let swiftDataSource: SwiftDataExpenseDataSource
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "ExpenseRepo")

    init(remote: FirebaseExpenseDataSource, swiftData: SwiftDataExpenseDataSource) {
        self.remoteDataSource = remote
        self.swiftDataSource = swiftData
    }

    // MARK: - Read
    
    func getExpenses(policy: CachePolicy) async throws -> [Expense] {
        switch policy {
        case .cacheFirst(_):
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

    func getExpenses(from startDate: String, to endDate: String) async throws -> [Expense] {
        do {
            return try await remoteDataSource.getExpenses(from: startDate, to: endDate)
        } catch {
            // Offline: filtra la cache local por el mismo rango (comparación
            // lexicográfica válida porque date es "yyyy-MM-dd").
            logger.warning("Range fetch failed, falling back to cache: \(error.localizedDescription)")
            let cached = try swiftDataSource.fetchExpenses()
            return cached.filter { $0.date >= startDate && $0.date <= endDate }
        }
    }
    
    // MARK: - Paginated Fetch
    
    func getExpensesPaginated(page: Int, filter: ExpenseFilter?) async throws -> PageResult {
        // HYBRID APPROACH: If page query, we try to fetch ALL to satisfy user request "pedir todo"
        // But we keep the signature.
        // Actually, let's use the new getExpenses(filter:) logic for "page 0" and return all.
        // Infinite scroll will just receive empty on page 1.
        
        if page == 0 {
            let expenses = try await remoteDataSource.getExpenses(filter: filter)
            
            if !expenses.isEmpty {
                // Bulk save to local cache (might be heavy if >1000, but simplest path)
                Task { try? await saveToLocal(expenses) }
            }
            
            return PageResult(expenses: expenses, hasMore: false) // No more pages, we fetched all.
        } else {
            return PageResult(expenses: [], hasMore: false)
        }
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
        // Capturar uid antes del await para detectar cambio de usuario durante el sync
        // (evita escribir datos del usuario A en cache local del usuario B tras sign-out/in).
        let uidAtStart = Auth.auth().currentUser?.uid
        let remote = try await remoteDataSource.getExpenses()
        let uidAfter = Auth.auth().currentUser?.uid
        guard uidAtStart == uidAfter, uidAfter != nil else {
            logger.warning("syncFromRemote: user changed mid-sync, discarding remote payload")
            return
        }
        try await saveToLocal(remote)

        // Remove local expenses that no longer exist remotely (deleted on another device)
        // Only run orphan detection if we got a reasonable number of remote expenses
        // to avoid deleting local data when the network response is incomplete
        let local = try swiftDataSource.fetchExpenses()
        if remote.count > 0 && remote.count >= local.count / 2 {
            let remoteIds = Set(remote.compactMap(\.id))
            let orphans = local.filter { expense in
                guard let id = expense.id else { return false }
                return !remoteIds.contains(id)
            }
            for orphan in orphans {
                if let id = orphan.id {
                    try? swiftDataSource.deleteExpense(id)
                }
            }
            if !orphans.isEmpty {
                logger.debug("Removed \(orphans.count) orphaned local expenses")
            }
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastSyncTimestamp")
        logger.debug("Background sync complete")
    }
    
    private func saveToLocal(_ expenses: [Expense]) async throws {
        // Sync strategy: Insert or Update
        for expense in expenses {
           try swiftDataSource.upsertExpense(expense) 
        }
    }
}
