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

    /// Margen antes de dar la lectura remota por perdida y servir cache local.
    private static let remoteReadTimeout: TimeInterval = 8
    /// Cuándo se volcó por última vez el historial remoto en la caché.
    private static let lastSyncKey = "lastSyncTimestamp"

    init(remote: FirebaseExpenseDataSource, swiftData: SwiftDataExpenseDataSource) {
        self.remoteDataSource = remote
        self.swiftDataSource = swiftData
    }

    // MARK: - Read
    
    func getExpenses(policy: CachePolicy) async throws -> [Expense] {
        switch policy {
        case .cacheFirst(let maxAge):
            // Check SwiftData
            let cached = try swiftDataSource.fetchExpenses()

            if !cached.isEmpty {
                logger.debug("Returning SwiftData expenses")

                // Solo si la última sincronización es más vieja que `maxAge`:
                // antes se bajaba todo el historial de Firestore en cada
                // arranque, aunque se hubiera hecho hacía un minuto.
                let ultima = UserDefaults.standard.double(forKey: Self.lastSyncKey)
                if Date().timeIntervalSince1970 - ultima > maxAge {
                    Task {
                        try? await syncFromRemote()
                    }
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
            let remote = remoteDataSource
            return try await withTimeout(Self.remoteReadTimeout) {
                try await remote.getExpenses(from: startDate, to: endDate)
            }
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
        
        guard page == 0 else {
            return PageResult(expenses: [], hasMore: false)
        }

        do {
            // Timeout: sin cobertura Firestore puede no resolver nunca y la Home
            // se quedaba en blanco en vez de caer a la cache local (issue #32).
            let remote = remoteDataSource
            let expenses = try await withTimeout(Self.remoteReadTimeout) {
                try await remote.getExpenses(filter: filter)
            }

            if !expenses.isEmpty {
                // Bulk save to local cache (might be heavy if >1000, but simplest path)
                Task { try? await saveToLocal(expenses) }
            }

            return PageResult(expenses: expenses, hasMore: false) // No more pages, we fetched all.
        } catch {
            logger.warning("Paginated fetch failed, falling back to cache: \(error.localizedDescription)")
            let cached = try swiftDataSource.fetchExpenses()
            let filtered = filter?.apply(to: cached) ?? cached
            guard !filtered.isEmpty || !cached.isEmpty else { throw error }
            return PageResult(expenses: filtered, hasMore: false)
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
        // Se purgan los locales que ya no existen en remoto (borrados desde
        // otro dispositivo), pero solo si la respuesta trae un número razonable
        // de gastos: una respuesta a medias no debe borrar la caché.
        let locales = try swiftDataSource.count()
        let purgar = remote.count > 0 && remote.count >= locales / 2
        try swiftDataSource.upsertAll(remote, purgandoHuerfanos: purgar)

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastSyncKey)
        logger.debug("Background sync complete")
    }
    
    private func saveToLocal(_ expenses: [Expense]) async throws {
        // En bloque y con un solo save: ver `upsertAll`.
        try swiftDataSource.upsertAll(expenses)
    }
}
