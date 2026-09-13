//
//  VoiceOnboardingSheet.swift
//  Clarity
//
//  Onboarding contextual la primera vez que el usuario abre la grabación por voz.
//

import SwiftUI

struct VoiceOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // El fondo de la app detrás de todas las páginas, que van transparentes:
            // así el vidrio de los ejemplos tiene algo que refractar.
            HomeFondo()

            TabView(selection: $page) {
                IntroPage().tag(0)
                ExamplePage().tag(1)
                SiriPage().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.clarityPrimary : Color.primary.opacity(0.25))
                            .frame(width: i == page ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }

                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                        HapticManager.shared.selection()
                    } else {
                        HapticManager.shared.notification(.success)
                        dismiss()
                    }
                } label: {
                    Text(page < 2 ? "Siguiente" : "Empezar a hablar")
                }
                .buttonStyle(.principalClarity)
                .padding(.horizontal, 24)

                if page == 0 {
                    Button("Saltar") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Color.clear.frame(height: 20)
                }
            }
            .padding(.bottom, 28)
        }
        .preferredColorScheme(.dark)
    }
}

private struct IntroPage: View {
    @State private var appear = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .strokeBorder(Color.clarityPrimary.opacity(0.3 - Double(i) * 0.08), lineWidth: 1.5)
                        .frame(width: CGFloat(120 + i * 50), height: CGFloat(120 + i * 50))
                        .scaleEffect(pulse ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(Double(i) * 0.2), value: pulse)
                }
                CirculoIconoClarity(icono: "mic.fill", color: .clarityPrimary, tamano: 110, esSimbolo: true)
            }
            .scaleEffect(appear ? 1 : 0.4)
            .opacity(appear ? 1 : 0)

            VStack(spacing: 10) {
                Text("Voz")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Añade gastos sin\nteclear ni un dígito")
                    .font(.title3)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 20)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appear = true }
            pulse = true
        }
    }
}

private struct ExamplePage: View {
    @State private var appear = false
    @State private var showBubbles = false

    private let examples = [
        "20 euros gasolina",
        "compré café por 3 con 50",
        "alquiler 700",
        "comida con tarjeta 12.40",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 45)

            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.clarityPrimary)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating, isActive: appear)
                .scaleEffect(appear ? 1 : 0.4)

            Spacer().frame(height: 18)

            VStack(spacing: 8) {
                Text("CÓMO HABLARLE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.success)
                    .tracking(2.5)
                Text("Di importe + descripción")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Clarity entiende lenguaje natural. Detecta importe, categoría y método de pago automáticamente.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            Spacer().frame(height: 24)

            VStack(spacing: 8) {
                ForEach(Array(examples.enumerated()), id: \.offset) { i, ex in
                    if showBubbles {
                        HStack(spacing: 10) {
                            Image(systemName: "quote.opening")
                                .font(.caption.bold())
                                .foregroundStyle(Color.success)
                            Text(ex)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassCard(cornerRadius: CornerRadius.small)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .animation(.spring(response: 0.4).delay(Double(i) * 0.08), value: showBubbles)
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
            withAnimation(.spring(response: 0.5).delay(0.4)) { showBubbles = true }
        }
    }
}

private struct SiriPage: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 50)

            Text("✨")
                .font(.system(size: 64))
                .scaleEffect(appear ? 1 : 0.4)

            Spacer().frame(height: 18)

            VStack(spacing: 8) {
                Text("CON SIRI")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.clarityPrimary)
                    .tracking(2.5)
                Text("Sin abrir la app")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Empieza siempre por \"Clarity\" para que Siri te entienda al instante.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            Spacer().frame(height: 18)

            VStack(spacing: 10) {
                siriBubble("Oye Siri, Clarity añade un gasto")
                siriBubble("Oye Siri, Clarity cuánto llevo gastado")
                siriBubble("Oye Siri, Clarity nuevo gasto")
            }
            .padding(.horizontal, 28)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 24)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
        }
    }

    /// Frase para Siri: vidrio teñido de marca para distinguirla de los ejemplos
    /// de la página anterior, que son para el micro.
    private func siriBubble(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.caption.bold())
                .foregroundStyle(Color.clarityPrimary)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: CornerRadius.small, tint: Color.clarityPrimary)
    }
}

#Preview {
    VoiceOnboardingSheet()
}
