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
        case .info: return .warning
        }
    }
}

struct FeedbackMessage: Identifiable, Equatable {
    let id = UUID()
    let type: FeedbackType
    let title: String
    let message: String?
    let actionLabel: String?
    let action: (() -> Void)?

    init(type: FeedbackType, title: String, message: String? = nil, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        self.type = type
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }

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
    func show(_ type: FeedbackType, title: String, message: String? = nil, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        dismissTask?.cancel()

        withAnimation(.snappy) {
            currentMessage = FeedbackMessage(type: type, title: title, message: message, actionLabel: actionLabel, action: action)
        }

        HapticManager.shared.notification(type.haptic)

        // Dismiss timing: 5s with action, 1.8s for success animation, 3s default
        let duration: UInt64 = if action != nil {
            5_000_000_000
        } else if type == .success {
            1_800_000_000
        } else {
            3_000_000_000
        }
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: duration)
            if !Task.isCancelled {
                dismiss()
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
