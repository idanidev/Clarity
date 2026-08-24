// AIDisabledView.swift
// Lo que se ve cuando Clara no puede funcionar en este iPhone.
//
// Ya no es un "próximamente" genérico: `ClaraGateView` decide, y si llega aquí
// es por un motivo concreto —el dispositivo no lo soporta, Apple Intelligence
// está desactivada, el modelo se está descargando— y ese motivo se cuenta.

import SwiftUI

struct AIDisabledView: View {
    /// Por qué Clara no está disponible. Vacío = mensaje genérico.
    var motivo: String = ""

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.clarityPrimary, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, Spacing.sm)

            Text(motivo.isEmpty ? "Próximamente" : "Clara, aquí no")
                .font(.title2.weight(.bold))

            Text(motivo.isEmpty
                 ? "Estamos puliendo el asistente IA para que dé consejos financieros realmente útiles. Volverá pronto, mejor que nunca."
                 : motivo)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("IA")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AIDisabledView()
    }
}
