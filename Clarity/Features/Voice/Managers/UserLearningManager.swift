// UserLearningManager.swift
// Handles on-device reinforcement learning for categorization
// "God-Tier" architecture: Thread-safe, persistent, and lightweight

import Foundation

struct UserPreference: Codable {
    let category: String
    let subcategory: String?
    var count: Int // Reinforcement counter
}

actor UserLearningManager {
    static let shared = UserLearningManager()
    
    // Storage: [MerchantName : Preference]
    // Example: ["mercadona" : { category: "Ocio", count: 3 }]
    private var preferences: [String: UserPreference] = [:]
    
    private let storageKey = "voice_learning_preferences"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: "voice_learning_preferences"),
           let decoded = try? JSONDecoder().decode([String: UserPreference].self, from: data) {
            // Filter out corrupted data (merchant names with commands)
            let commandWords = ["anade", "añade", "anadir", "añadir", "anademe", "añademe", "gasta", "gastado", "compra", "comprado", "paga", "pagado", "apunta"]
            self.preferences = decoded.filter { (merchant, _) in
                !commandWords.contains(where: { merchant.contains($0) })
            }
            
            // If we filtered anything, save the cleaned data
            if self.preferences.count < decoded.count {
                print("🧹 Cleaned \(decoded.count - self.preferences.count) corrupted learning entries")
                if let cleanData = try? JSONEncoder().encode(self.preferences) {
                    UserDefaults.standard.set(cleanData, forKey: "voice_learning_preferences")
                }
            }
        }
    }
    
    // MARK: - Public API
    
    func getPreference(for merchant: String) -> (category: String, subcategory: String?)? {
        let normalized = normalize(merchant)
        guard let pref = preferences[normalized], pref.count >= 1 else { return nil }
        return (pref.category, pref.subcategory)
    }
    
    func learn(merchant: String, category: String, subcategory: String?) {
        let normalized = normalize(merchant)
        
        if var existing = preferences[normalized] {
            if existing.category == category && existing.subcategory == subcategory {
                existing.count += 1
            } else {
                existing = UserPreference(category: category, subcategory: subcategory, count: 1)
            }
            preferences[normalized] = existing
        } else {
            preferences[normalized] = UserPreference(category: category, subcategory: subcategory, count: 1)
        }
        
        save()
    }
    
    // MARK: - Helper
    private func normalize(_ text: String) -> String {
        return text
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    
    func clearAllLearning() async {
        preferences.removeAll()
        save()
        print("🧹 UserLearning: All learning data cleared")
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
