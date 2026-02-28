// OnboardingView.swift
// First-time user onboarding flow

import SwiftUI

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
}

struct OnboardingView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "chart.bar.fill",
            title: "Controla tus gastos",
            subtitle: "Registra cada gasto fácilmente y visualiza a dónde va tu dinero con gráficos claros.",
            gradient: [Color(hex: "#8B5CF6"), Color(hex: "#6366F1")]
        ),
        OnboardingPage(
            icon: "mic.fill",
            title: "Añade gastos por voz",
            subtitle: "Di \"20 euros en el supermercado\" y Clarity lo entiende. Rápido, sin teclear.",
            gradient: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")]
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Asistente IA financiero",
            subtitle: "Pregúntale a la IA sobre tus hábitos de gasto y recibe consejos personalizados.",
            gradient: [Color(hex: "#10B981"), Color(hex: "#059669")]
        ),
        OnboardingPage(
            icon: "target",
            title: "Metas y presupuestos",
            subtitle: "Define presupuestos mensuales y metas de ahorro. Clarity te avisa cuando te acerques al límite.",
            gradient: [Color(hex: "#F59E0B"), Color(hex: "#D97706")]
        )
    ]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Saltar") {
                            onComplete()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding()
                    }
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.clarityPrimary : Color.primary.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Siguiente" : "Empezar")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.clarityGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Individual Page

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: page.gradient.first?.opacity(0.4) ?? .clear, radius: 20, y: 10)

                Image(systemName: page.icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Text
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView { }
        .preferredColorScheme(.dark)
}
