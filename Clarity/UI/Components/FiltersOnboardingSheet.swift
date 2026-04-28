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
            Color.black.ignoresSafeArea()

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
                            .fill(i == page ? Color.white : Color.white.opacity(0.3))
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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 24)

                if page == 0 {
                    Button("Saltar") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.5))
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
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#3B82F6").opacity(0.28), Color.clear],
                center: .center, startRadius: 0, endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#3B82F6"), Color(hex: "#6366F1")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 110, height: 110)
                        .shadow(color: Color(hex: "#3B82F6").opacity(0.55), radius: 28, y: 10)

                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appear ? 1 : 0.4)
                .opacity(appear ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Filtros")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Encuentra cualquier gasto\nen segundos")
                        .font(.title3)
                        .foregroundStyle(Color.white.opacity(0.6))
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

private struct ApplyPage: View {
    @State private var appear = false
    @State private var showChips = false

    private let chips: [(icon: String, label: String, color: Color)] = [
        ("calendar", "Este mes", Color(hex: "#3B82F6")),
        ("eurosign.circle", "20-100€", Color(hex: "#10B981")),
        ("tag", "Comida", Color(hex: "#F59E0B")),
        ("creditcard", "Tarjeta", Color(hex: "#EC4899")),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#10B981").opacity(0.18), Color.clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(appear ? 1 : 0.4)

                Spacer().frame(height: 18)

                VStack(spacing: 8) {
                    Text("CÓMO FUNCIONAN")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#10B981"))
                        .tracking(2.5)
                    Text("Combina criterios\ny aplica")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("Fecha, importe, categoría, método de pago. Mezcla los que necesites.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)

                Spacer().frame(height: 28)

                // Mock chips
                VStack(spacing: 10) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { i, chip in
                        if showChips {
                            HStack(spacing: 12) {
                                Image(systemName: chip.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(chip.color)
                                    .frame(width: 36, height: 36)
                                    .background(chip.color.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(chip.label)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(chip.color)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(chip.color.opacity(0.25), lineWidth: 1))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()
            }
        }
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
        ("🍔", "Comida fuera", "Hostelería · Tarjeta", Color(hex: "#F59E0B")),
        ("🚗", "Coche", "Transporte · >50€", Color(hex: "#3B82F6")),
        ("🎁", "Regalos", "Este año · Efectivo", Color(hex: "#EC4899")),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#8B5CF6").opacity(0.22), Color.clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                Image(systemName: "bookmark.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8B5CF6"))
                    .scaleEffect(appear ? 1 : 0.4)

                Spacer().frame(height: 16)

                VStack(spacing: 8) {
                    Text("FILTROS GUARDADOS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#8B5CF6"))
                        .tracking(2.5)
                    Text("Guarda los\nque más uses")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("Aplica una combinación favorita con un toque. Sin volver a configurarla.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)

                Spacer().frame(height: 28)

                VStack(spacing: 10) {
                    ForEach(Array(presets.enumerated()), id: \.offset) { i, p in
                        if showCards {
                            HStack(spacing: 12) {
                                Text(p.emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 44)
                                    .background(p.color.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(p.summary)
                                        .font(.caption)
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.45).delay(Double(i) * 0.08), value: showCards)
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
            withAnimation(.spring(response: 0.5).delay(0.4)) { showCards = true }
        }
    }
}

#Preview {
    FiltersOnboardingSheet()
}
