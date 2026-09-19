// TrackScreenModifier.swift
// Registra qué pantallas se visitan, para saber qué sobra y qué potenciar (#41).

import SwiftUI

private struct TrackScreenModifier: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
        content
            // Miga para el registro de cuelgues. En `onAppear` y no dentro del
            // `.task`: si el hilo principal se cuelga nada más aparecer la
            // pantalla, la tarea no llega a arrancar y el informe no sabría dónde
            // estaba la app.
            .onAppear { Migas.deja("pantalla: \(name)") }
            .task {
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
