// VoiceSettings.swift
// User preferences for voice expense entry

import Foundation

struct VoiceSettings: Codable {
    var autoConfirm: Bool
    var autoConfirmDelay: TimeInterval  // Seconds before auto-confirm
    var vibration: Bool
    var showSuggestions: Bool
    var silenceTimeout: TimeInterval
    var debugMode: Bool  // Show detailed logs
    
    static let `default` = VoiceSettings(
        autoConfirm: false,  // Changed to false by default - less aggressive
        autoConfirmDelay: 3.0, // Reduced from 5.0 to 3.0 for better UX
        vibration: true,
        showSuggestions: true,
        silenceTimeout: 2.5,
        debugMode: false
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

