//
//  FiltersOnboardingSheet.swift
//  Clarity
//
//  Onboarding contextual la primera vez que el usuario abre el sheet de filtros.
//

import SwiftUI

struct FiltersOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // El fondo de la app detrás de todas las páginas, que van transparentes:
            // así el vidrio de las tarjetas de ejemplo tiene algo que refractar.
            HomeFondo()

            TabView(selection: $page) {
                IntroPage().tag(0)
                ApplyPage().tag(1)
                SavedPage().tag(2)
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
                    Text(page < 2 ? "Siguiente" : "Entendido")
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
        VStack(spacing: 22) {
            Spacer()

            CirculoIconoClarity(
                icono: "line.3.horizontal.decrease.circle.fill",
                color: .clarityPrimary,
                tamano: 110,
                esSimbolo: true
            )
            .scaleEffect(appear ? 1 : 0.4)
            .opacity(appear ? 1 : 0)

            VStack(spacing: 10) {
                Text("Filtros")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Encuentra cualquier gasto\nen segundos")
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
        }
    }
}

private struct ApplyPage: View {
    @State private var appear = false
    @State private var showChips = false

    private let chips: [(icon: String, label: String, color: Color)] = [
        ("calendar", "Este mes", Color.clarityPrimary),
        ("eurosign.circle", "20-100€", Color.success),
        ("tag", "Comida", Color.warning),
        ("creditcard", "Tarjeta", Color.claritySecondary),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 50)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.clarityPrimary)
                .scaleEffect(appear ? 1 : 0.4)

            Spacer().frame(height: 18)

            VStack(spacing: 8) {
                Text("CÓMO FUNCIONAN")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.success)
                    .tracking(2.5)
                Text("Combina criterios\ny aplica")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Fecha, importe, categoría, método de pago. Mezcla los que necesites.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            Spacer().frame(height: 18)

            // Mock chips
            VStack(spacing: 10) {
                ForEach(Array(chips.enumerated()), id: \.offset) { i, chip in
                    if showChips {
                        HStack(spacing: 12) {
                            CirculoIconoClarity(icono: chip.icon, color: chip.color, tamano: 36, esSimbolo: true)
                            Text(chip.label)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(chip.color)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassCard(cornerRadius: CornerRadius.medium)
                        .transition(.move(edge: .leading).combined(with: .opacity))
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
            for i in 0..<chips.count {
                withAnimation(.spring(response: 0.45).delay(0.4 + Double(i) * 0.12)) {
                    if i == 0 { showChips = true }
                }
            }
            withAnimation(.spring(response: 0.5).delay(0.4)) { showChips = true }
        }
    }
}

private struct SavedPage: View {
    @State private var appear = false
    @State private var showCards = false

    private let presets: [(emoji: String, name: String, summary: String, color: Color)] = [
        ("🍔", "Comida fuera", "Hostelería · Tarjeta", Color.warning),
        ("🚗", "Coche", "Transporte · >50€", Color.clarityPrimary),
        ("🎁", "Regalos", "Este año · Efectivo", Color.claritySecondary),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 50)

            Image(systemName: "bookmark.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Color.clarityPrimary)
                .scaleEffect(appear ? 1 : 0.4)

            Spacer().frame(height: 16)

            VStack(spacing: 8) {
                Text("FILTROS GUARDADOS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.clarityPrimary)
                    .tracking(2.5)
                Text("Guarda los\nque más uses")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Aplica una combinación favorita con un toque. Sin volver a configurarla.")
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
                ForEach(Array(presets.enumerated()), id: \.offset) { i, p in
                    if showCards {
                        HStack(spacing: 12) {
                            CirculoIconoClarity(icono: p.emoji, color: p.color, tamano: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(p.summary)
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.bold())
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(14)
                        .glassCard(cornerRadius: CornerRadius.medium)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.45).delay(Double(i) * 0.08), value: showCards)
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
            withAnimation(.spring(response: 0.5).delay(0.4)) { showCards = true }
        }
    }
}

#Preview {
    FiltersOnboardingSheet()
}
