// FeedbackManager.swift
// Global manager for app-wide feedback (toasts, alerts, haptics)

import SwiftUI
import Observation

enum FeedbackType {
    case success
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .success: return Color.green
        case .error: return Color.red
        case .warning: return Color.orange
        case .info: return Color.blue
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var haptic: HapticManager.NotificationType {
        switch self {
        case .success: return .success
        case .error: return .error
        case .warning: return .warning
        case .info: return .warning // Fallback
        }
    }
}

struct FeedbackMessage: Identifiable, Equatable {
    let id = UUID()
    let type: FeedbackType
    let title: String
    let message: String?
    
    static func == (lhs: FeedbackMessage, rhs: FeedbackMessage) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class FeedbackManager {
    static let shared = FeedbackManager()
    
    var currentMessage: FeedbackMessage?
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    @MainActor
    func show(_ type: FeedbackType, title: String, message: String? = nil) {
        // Cancel previous dismissal if any
        dismissTask?.cancel()
        
        // Update state
        withAnimation(.snappy) {
            currentMessage = FeedbackMessage(type: type, title: title, message: message)
        }
        
        // Haptic
        HapticManager.shared.notification(type.haptic)
        
        // Auto-dismiss
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                await dismiss()
            }
        }
    }
    
    @MainActor
    func dismiss() {
        withAnimation(.snappy) {
            currentMessage = nil
        }
    }
}
