

import Foundation
import OSLog

actor LocalExpenseDataSource {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "LocalDataSource")
    private let fileName = "expenses_cache.json"
    
    private var cache: [Expense] = []
    private var lastUpdated: Date?
    
    private var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }
    
    init() {
        Task { await loadFromDisk() }
    }
    
    // MARK: - API
    
    func getExpenses() -> [Expense] {
        return cache
    }
    
    func lastUpdateTimestamp() -> Date? {
        return lastUpdated
    }
    
    func save(_ expenses: [Expense], timestamp: Date = Date()) throws {
        self.cache = expenses
        self.lastUpdated = timestamp
        try persistToDisk()
    }
    
    func add(_ expense: Expense) throws {
        cache.append(expense)
        try persistToDisk()
    }
    
    func delete(_ id: String) throws {
        cache.removeAll { $0.id == id }
        try persistToDisk()
    }
    
    func update(_ expense: Expense) throws {
        if let index = cache.firstIndex(where: { $0.id == expense.id }) {
            cache[index] = expense
            try persistToDisk()
        }
    }
    
    func clear() throws {
        cache = []
        lastUpdated = nil
        try removeFile()
    }
    
    // MARK: - Persistence Logic
    
    private func loadFromDisk() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(CacheContainer.self, from: data)
            self.cache = decoded.expenses
            self.lastUpdated = decoded.timestamp
            logger.debug("Loaded \(self.cache.count) expenses from disk cache")
        } catch {
            logger.error("Failed to load cache: \(error.localizedDescription)")
        }
    }
    
    private func persistToDisk() throws {
        guard let url = fileURL else { return }
        let container = CacheContainer(expenses: cache, timestamp: lastUpdated ?? Date())
        let data = try JSONEncoder().encode(container)
        try data.write(to: url)
    }
    
    private func removeFile() throws {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
    
    // Helper struct for JSON structure
    private struct CacheContainer: Codable {
        let expenses: [Expense]
        let timestamp: Date
    }
}
