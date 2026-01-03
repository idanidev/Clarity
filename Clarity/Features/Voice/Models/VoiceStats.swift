// VoiceStats.swift
// Usage statistics for voice expense feature

import Foundation

struct VoiceStats: Codable {
    var totalUses: Int
    var successfulUses: Int
    var failedUses: Int
    var lastUsed: Date?
    
    static let `default` = VoiceStats(
        totalUses: 0,
        successfulUses: 0,
        failedUses: 0,
        lastUsed: nil
    )
    
    private static let storageKey = "voiceStats"
    
    static func load() -> VoiceStats {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stats = try? JSONDecoder().decode(VoiceStats.self, from: data) else {
            return .default
        }
        return stats
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: VoiceStats.storageKey)
        }
    }
    
    mutating func recordSuccess() {
        totalUses += 1
        successfulUses += 1
        lastUsed = Date()
        save()
    }
    
    mutating func recordFailure() {
        totalUses += 1
        failedUses += 1
        lastUsed = Date()
        save()
    }
}
