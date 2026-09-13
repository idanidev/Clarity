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
            // El fondo de la app detrás de las tres páginas; cada página pone
            // encima solo su brillo de color.
            HomeFondo()

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
                            .fill(i == page ? Color.primary : Color.textTertiary)
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

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.success.opacity(0.3), Color.clear],
                center: .center, startRadius: 0, endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                CirculoIconoClarity(icono: "eurosign", color: Color.success, tamano: 110, esSimbolo: true)
                    .scaleEffect(appear ? 1 : 0.4)
                    .opacity(appear ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Nóminas")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Text("Tu ingreso mensual,\nhistórico y automático")
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

private struct RecurringPage: View {
    @State private var appear = false
    @State private var toggleOn = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.clarityPrimary.opacity(0.22), Color.clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                CirculoIconoClarity(icono: "arrow.clockwise", color: Color.clarityPrimary, tamano: 88, esSimbolo: true)
                    .scaleEffect(appear ? 1 : 0.4)

                Spacer().frame(height: 18)

                VStack(spacing: 8) {
                    Text("COBRO FIJO MENSUAL")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.clarityPrimary)
                        .tracking(2.5)
                    Text("Activa una vez,\nse repite siempre")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                    Text("Define tu sueldo neto. Cada mes Clarity crea solo el presupuesto, sin que tengas que hacer nada.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
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
                        .foregroundStyle(toggleOn ? Color.clarityPrimary : Color.textTertiary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cobro fijo mensual")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Text("1.800 € se aplican cada mes")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .glassCard(cornerRadius: CornerRadius.large, tint: toggleOn ? Color.clarityPrimary : nil)
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
        ("Abr", "1.950 €", Color.success),
        ("Mar", "1.800 €", Color.info),
        ("Feb", "1.800 €", Color.info),
        ("Ene", "1.800 €", Color.info),
    ]

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.info.opacity(0.22), Color.clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                CirculoIconoClarity(icono: "calendar", color: Color.info, tamano: 88, esSimbolo: true)
                    .scaleEffect(appear ? 1 : 0.4)

                Spacer().frame(height: 18)

                VStack(spacing: 8) {
                    Text("HISTORIAL ANUAL")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.info)
                        .tracking(2.5)
                    Text("Edita meses pasados\ny pagas extra")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                    Text("Si cobraste paga extra o un mes diferente, edítalo. Se reflejará en tus presupuestos antiguos.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
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
                                    .foregroundStyle(Color.textSecondary)
                                Text(r.amount)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Circle()
                                    .fill(r.color)
                                    .frame(width: 8, height: 8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .glassCard(cornerRadius: CornerRadius.small)
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
