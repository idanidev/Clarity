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
        autoConfirm: false,
        autoConfirmDelay: 3.0,
        vibration: true,
        showSuggestions: true,
        silenceTimeout: 1.5,
        debugMode: false
    )

    private static let storageKey = "voiceSettings"

    static func load() -> VoiceSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              var settings = try? JSONDecoder().decode(VoiceSettings.self, from: data) else {
            return .default
        }
        // Migrate: old default was 4.0s which causes noticeable lag
        if settings.silenceTimeout >= 3.0 {
            settings.silenceTimeout = `default`.silenceTimeout
            settings.save()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: VoiceSettings.storageKey)
        }
    }
}

