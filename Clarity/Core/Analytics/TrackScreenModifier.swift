// TrackScreenModifier.swift
// Registra qué pantallas se visitan, para saber qué sobra y qué potenciar (#41).

import SwiftUI

private struct TrackScreenModifier: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
        content.task {
            AnalyticsService.shared.track(.screenViewed(name: name))
        }
    }
}

extension View {
    /// Emite `screen_viewed` la primera vez que la vista aparece.
    /// El nombre es fijo y escrito a mano: nunca contenido del usuario.
    func trackScreen(_ name: String) -> some View {
        modifier(TrackScreenModifier(name: name))
    }
}
