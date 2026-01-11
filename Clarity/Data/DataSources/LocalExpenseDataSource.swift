// LocalExpenseDataSource.swift
// Local cache for expenses (In-Memory + UserDefaults/File persistence placeholder)

import Foundation

actor LocalExpenseDataSource {
    private var cache: [Expense] = []
    
    func getExpenses() async throws -> [Expense] {
        return cache
    }
    
    func save(_ expenses: [Expense]) async throws {
        self.cache = expenses
    }
    
    func add(_ expense: Expense) async throws {
        cache.append(expense)
    }
    
    func delete(_ id: String) async throws {
        cache.removeAll { $0.id == id }
    }
    
    func clear() async {
        cache = []
    }
}
