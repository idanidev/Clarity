// SwiftDataService.swift
// Manager for SwiftData Container and Context

import Foundation
import SwiftData

@MainActor
final class SwiftDataService {
    static let shared = SwiftDataService()
    
    let container: ModelContainer
    
    var context: ModelContext {
        container.mainContext
    }
    
    private init() {
        let schema = Schema([
            ExpenseModel.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If the persistent store is corrupted, try deleting and recreating
            try? FileManager.default.removeItem(at: modelConfiguration.url)
            do {
                self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // Last resort: in-memory only so the app doesn't crash
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = try! ModelContainer(for: schema, configurations: [memoryConfig])
            }
        }
    }
}
