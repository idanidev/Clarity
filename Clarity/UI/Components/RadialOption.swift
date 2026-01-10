// RadialOption.swift
// Options for radial menu interaction

import Foundation

enum RadialOption: String, CaseIterable, Identifiable, Sendable {
    case manual
    case voice
    case recurring
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .manual: "pencil.line"
        case .voice: "mic.fill"
        case .recurring: "arrow.triangle.2.circlepath"
        }
    }
    
    var label: String {
        switch self {
        case .manual: "Manual"
        case .voice: "Voz"
        case .recurring: "Recurrente"
        }
    }
    
    // Visual position in arc (degrees, 0 is top)
    var angle: Double {
        switch self {
        case .manual: -50      // Top-left
        case .voice: 0         // Top-center
        case .recurring: 50    // Top-right
        }
    }
}
