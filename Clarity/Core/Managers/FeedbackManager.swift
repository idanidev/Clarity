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

        // El aviso es solo visual y dura poco: VoiceOver no llegaba a leerlo, así
        // que ni oía «Gasto añadido» ni sabía que había un «Deshacer». Se le dice.
        let conVoiceOver = UIAccessibility.isVoiceOverRunning
        if conVoiceOver {
            Self.anunciar(Self.textoDelAnuncio(title: title, message: message, actionLabel: action == nil ? nil : actionLabel))
        }

        let duration = Self.duracion(type, conAccion: action != nil, conVoiceOver: conVoiceOver)
        dismissTask = Task {
            try? await Task.sleep(for: duration)
            if !Task.isCancelled {
                dismiss()
            }
        }
    }

    /// Cuánto se queda el aviso en pantalla.
    ///
    /// Sin VoiceOver: 4 s con acción, 0,9 s el de éxito (rápido, para seguir
    /// metiendo gastos) y 2,2 s el resto. Con VoiceOver, bastante más: hay que
    /// oír el anuncio entero y, si hay «Deshacer», llegar hasta el botón
    /// deslizando, que no es cosa de cuatro segundos.
    static func duracion(_ type: FeedbackType, conAccion: Bool, conVoiceOver: Bool) -> Duration {
        if conAccion {
            return conVoiceOver ? .seconds(12) : .seconds(4)
        }
        if type == .success {
            return conVoiceOver ? .seconds(3) : .milliseconds(900)
        }
        return conVoiceOver ? .seconds(6) : .milliseconds(2_200)
    }

    /// Lo que oye VoiceOver: el título, el detalle y, si la hay, la acción.
    static func textoDelAnuncio(title: String, message: String?, actionLabel: String?) -> String {
        var partes = [title]
        if let message, !message.isEmpty { partes.append(message) }
        if let actionLabel, !actionLabel.isEmpty { partes.append("Acción disponible: \(actionLabel)") }
        return partes.joined(separator: ". ")
    }

    /// Con prioridad alta: el aviso suele salir justo al cerrarse una hoja, y el
    /// cambio de pantalla se comía un anuncio normal antes de que empezara.
    @MainActor
    private static func anunciar(_ texto: String) {
        let anuncio = NSAttributedString(
            string: texto,
            attributes: [.accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.high]
        )
        UIAccessibility.post(notification: .announcement, argument: anuncio)
    }

    @MainActor
    func dismiss() {
        withAnimation(.snappy) {
            currentMessage = nil
        }
    }
}
