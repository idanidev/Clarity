//
//  SalaryOnboardingSheet.swift
//  Clarity
//
//  Onboarding contextual la primera vez que el usuario abre Nóminas.
//

import SwiftUI

struct SalaryOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            TabView(selection: $page) {
                IntroPage().tag(0)
                RecurringPage().tag(1)
                HistoryPage().tag(2)
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
                    Text(page < 2 ? "Siguiente" : "Configurar nómina")
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

private struct IntroPage: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#10B981").opacity(0.3), Color.clear],
                center: .center, startRadius: 0, endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#10B981"), Color(hex: "#34D399")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 110, height: 110)
                        .shadow(color: Color(hex: "#10B981").opacity(0.55), radius: 28, y: 10)

                    Image(systemName: "eurosign.circle.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appear ? 1 : 0.4)
                .opacity(appear ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Nóminas")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Tu ingreso mensual,\nhistórico y automático")
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

private struct RecurringPage: View {
    @State private var appear = false
    @State private var toggleOn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#8B5CF6").opacity(0.22), Color.clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8B5CF6"))
                    .scaleEffect(appear ? 1 : 0.4)

                Spacer().frame(height: 18)

                VStack(spacing: 8) {
                    Text("COBRO FIJO MENSUAL")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#8B5CF6"))
                        .tracking(2.5)
                    Text("Activa una vez,\nse repite siempre")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Define tu sueldo neto. Cada mes Clarity crea solo el presupuesto, sin que tengas que hacer nada.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)

                Spacer().frame(height: 18)

                // Mock toggle card
                HStack(spacing: 14) {
                    Image(systemName: toggleOn ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(toggleOn ? Color(hex: "#8B5CF6") : Color.white.opacity(0.3))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cobro fijo mensual")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("1.800 € se aplican cada mes")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(16)
                .background(toggleOn ? Color(hex: "#8B5CF6").opacity(0.14) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
                    toggleOn ? Color(hex: "#8B5CF6").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 28)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 24)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
            withAnimation(.spring(response: 0.4).delay(0.6)) { toggleOn = true }
        }
    }
}

private struct HistoryPage: View {
    @State private var appear = false
    @State private var showRows = false

    private let rows: [(month: String, amount: String, color: Color)] = [
        ("Abr", "1.950 €", Color(hex: "#10B981")),
        ("Mar", "1.800 €", Color(hex: "#3B82F6")),
        ("Feb", "1.800 €", Color(hex: "#3B82F6")),
        ("Ene", "1.800 €", Color(hex: "#3B82F6")),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#3B82F6").opacity(0.22), Color.clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                Image(systemName: "calendar")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color(hex: "#3B82F6"))
                    .scaleEffect(appear ? 1 : 0.4)

                Spacer().frame(height: 18)

                VStack(spacing: 8) {
                    Text("HISTORIAL ANUAL")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#3B82F6"))
                        .tracking(2.5)
                    Text("Edita meses pasados\ny pagas extra")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Si cobraste paga extra o un mes diferente, edítalo. Se reflejará en tus presupuestos antiguos.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 4)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)

                Spacer().frame(height: 24)

                VStack(spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        if showRows {
                            HStack(spacing: 14) {
                                Text(r.month)
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: 40, alignment: .leading)
                                    .foregroundStyle(Color.white.opacity(0.6))
                                Text(r.amount)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Circle()
                                    .fill(r.color)
                                    .frame(width: 8, height: 8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            .animation(.spring(response: 0.4).delay(Double(i) * 0.07), value: showRows)
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
            withAnimation(.spring(response: 0.5).delay(0.4)) { showRows = true }
        }
    }
}

#Preview {
    SalaryOnboardingSheet()
}
