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
        autoConfirmDelay: 5.0,
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
        var changed = false
        // Migrate: old default silenceTimeout was 4.0s
        if settings.silenceTimeout >= 3.0 {
            settings.silenceTimeout = `default`.silenceTimeout
            changed = true
        }
        // Migrate: bump autoConfirmDelay to 5s minimum
        if settings.autoConfirmDelay < 5.0 {
            settings.autoConfirmDelay = `default`.autoConfirmDelay
            changed = true
        }
        if changed { settings.save() }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: VoiceSettings.storageKey)
        }
    }
}

