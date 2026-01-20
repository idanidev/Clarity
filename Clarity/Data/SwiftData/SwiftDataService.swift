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
        do {
            let schema = Schema([
                ExpenseModel.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
