// VoiceSettings.swift
// User preferences for voice expense entry

import Foundation

struct VoiceSettings: Codable {
    var autoConfirm: Bool
    var vibration: Bool
    var showSuggestions: Bool
    var silenceTimeout: TimeInterval
    
    static let `default` = VoiceSettings(
        autoConfirm: true,
        vibration: true,
        showSuggestions: true,
        silenceTimeout: 2.5  // Auto-close after 2.5s of silence
    )
    
    private static let storageKey = "voiceSettings"
    
    static func load() -> VoiceSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(VoiceSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: VoiceSettings.storageKey)
        }
    }
}
