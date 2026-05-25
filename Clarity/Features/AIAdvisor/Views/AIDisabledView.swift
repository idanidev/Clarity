// AIDisabledView.swift
// Placeholder mientras la feature de IA está deshabilitada temporalmente.
// Razones: providers (Gemini/Groq) inestables y feature aún sin pulir.
// Para reactivar: sustituir AIDisabledView() por AIAdvisorView() en
// MainTabView.swift y MoreMenuView.swift.

import SwiftUI

struct AIDisabledView: View {
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

            Text("Próximamente")
                .font(.title2.weight(.bold))

            Text("Estamos puliendo el asistente IA para que dé consejos financieros realmente útiles. Volverá pronto, mejor que nunca.")
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
