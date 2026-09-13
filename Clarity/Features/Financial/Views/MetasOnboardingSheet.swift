//
//  MetasOnboardingSheet.swift
//  Clarity
//
//  Onboarding contextual la primera vez que el usuario abre la pestaña Metas.
//  Explica las dos herramientas (Hucha / Escudo) con ejemplos visuales.
//

import SwiftUI

struct MetasOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // El fondo de la app una sola vez, detrás de las páginas: cada página
            // solo añade su brillo y se desliza sobre él.
            HomeFondo()

            TabView(selection: $page) {
                IntroPage().tag(0)
                HuchaPage().tag(1)
                EscudoPage().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // Dot indicators
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.clarityPrimary : Color.textTertiary)
                            .frame(width: i == page ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }

                // CTA
                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                        HapticManager.shared.selection()
                    } else {
                        HapticManager.shared.notification(.success)
                        dismiss()
                    }
                } label: {
                    Text(page < 2 ? "Siguiente" : "Empezar")
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

// MARK: - Pages

private struct IntroPage: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.clarityPrimary.opacity(0.3), Color.clear],
                center: .center, startRadius: 0, endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                CirculoIconoClarity(icono: "target", color: Color.clarityPrimary, tamano: 110, esSimbolo: true)
                    .scaleEffect(appear ? 1 : 0.4)
                    .opacity(appear ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Metas")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Dos herramientas\npara dominar tu dinero")
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
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appear = true }
        }
    }
}

private struct HuchaPage: View {
    @State private var appear = false
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.success.opacity(0.18), Color.clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                Text("🐖")
                    .font(.system(size: 72))
                    .scaleEffect(appear ? 1 : 0.4)

                Spacer().frame(height: 16)

                VStack(spacing: 8) {
                    Text("HUCHA")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.success)
                        .tracking(2.5)
                    Text("Ahorra hacia\nun objetivo")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("Define cuánto quieres juntar y ve sumando aportaciones poco a poco.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)

                Spacer().frame(height: 20)

                // Mock card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CirculoIconoClarity(icono: "✈️", color: Color.success, tamano: 50)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vacaciones Japón")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Objetivo: 2.500 €")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Text("60%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.success)
                    }

                    BarraProgresoClarity(progreso: Double(progress), color: Color.success, alto: 8)

                    HStack {
                        Text("1.500 € ahorrados")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text("Faltan 1.000 €")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: CornerRadius.large)
                .padding(.horizontal, 28)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 24)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.4)) { progress = 0.6 }
        }
    }
}

private struct EscudoPage: View {
    @State private var appear = false
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.warning.opacity(0.18), Color.clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                Text("🛡️")
                    .font(.system(size: 72))
                    .scaleEffect(appear ? 1 : 0.4)

                Spacer().frame(height: 16)

                VStack(spacing: 8) {
                    Text("ESCUDO")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.warning)
                        .tracking(2.5)
                    Text("Limita el gasto\nde una categoría")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("Pon un tope mensual y Clarity te avisa cuando te acercas al límite.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)

                Spacer().frame(height: 20)

                // Mock card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CirculoIconoClarity(icono: "🍿", color: Color.warning, tamano: 50)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ocio")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Límite: 200 €/mes")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Text("85%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.warning)
                    }

                    BarraProgresoClarity(progreso: Double(progress), color: Color.warning, alto: 8)

                    HStack {
                        Text("170 € gastados")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text("Quedan 30 €")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.warning)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: CornerRadius.large)
                .padding(.horizontal, 28)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 24)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.4)) { progress = 0.85 }
        }
    }
}

#Preview {
    MetasOnboardingSheet()
}
