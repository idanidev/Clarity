// SummaryCardsView.swift
// Tarjetas de resumen modernas con glassmorfismo
// Estilo mejorado inspirado en SkillsMP

import SwiftUI

// MARK: - Tarjeta de Resumen Individual Moderna
struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String? = nil
    var valueColor: Color = .white
    var iconColor: Color = .gray
    var gradient: LinearGradient? = nil
    var isAnimated: Bool = true

    @State private var animateValue = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isSmallDevice: Bool {
        horizontalSizeClass == .compact
    }

    private var iconSize: CGFloat {
        isSmallDevice ? 24 : 28
    }

    private var iconFontSize: CGFloat {
        isSmallDevice ? 11 : 12
    }

    private var valueSize: CGFloat {
        isSmallDevice ? 16 : 18
    }

    private var titleSize: CGFloat {
        isSmallDevice ? 9 : 10
    }

    private var verticalPadding: CGFloat {
        isSmallDevice ? 10 : 12
    }

    private var horizontalPadding: CGFloat {
        isSmallDevice ? 6 : 8
    }

    private var cardSpacing: CGFloat {
        isSmallDevice ? 6 : 8
    }

    var body: some View {
        VStack(spacing: cardSpacing) {
            // Icono con gradiente - RESPONSIVE
            ZStack {
                Circle()
                    .fill(gradient ?? LinearGradient(colors: [valueColor, valueColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: valueColor.opacity(0.3), radius: 4, y: 2)

                Image(systemName: icon)
                    .font(.system(size: iconFontSize, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Valor principal - RESPONSIVE
            Text(value)
                .font(.system(size: valueSize, weight: .heavy, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .opacity(animateValue ? 1 : 0)
                .scaleEffect(animateValue ? 1 : 0.8)

            // Título - RESPONSIVE
            Text(title)
                .font(.system(size: titleSize, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            // Subtítulo opcional
            if let subtitle = subtitle {
                 Text(subtitle)
                    .font(.system(size: titleSize - 1, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .background {
            ZStack {
                // 🎨 GLASSMORPHISM PROFESIONAL
                // Capa base con blur
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(.ultraThinMaterial)

                // Gradiente de acento ultra sutil
                if let gradient = gradient {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .fill(gradient.opacity(0.08))
                } else {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .fill(valueColor.opacity(0.06))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            // Borde sutil con gradiente
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        // Sombras profesionales iOS-style (múltiples capas)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .shadow(color: valueColor.opacity(0.08), radius: 12, x: 0, y: 6)
        .onAppear {
            if isAnimated {
                // 🎭 Animación de entrada suave estilo iOS
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0).delay(0.05)) {
                    animateValue = true
                }
            } else {
                animateValue = true
            }
        }
        .onChange(of: value) { _, _ in
            // 🎭 Animación de cambio de valor ultra smooth
            if isAnimated {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    animateValue = false
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.08)) {
                    animateValue = true
                }
            }
        }
    }
}

// MARK: - Vista de Tarjetas de Resumen
struct SummaryCardsView: View {
    let totalExpenses: Double
    let expenseCount: Int
    let savings: Double
    let savingsPercentage: Int
    let available: Double

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var cardSpacing: CGFloat {
        horizontalSizeClass == .compact ? 8 : 10
    }

    var body: some View {
        HStack(spacing: cardSpacing) {
            // Card 1: Total (Violeta con gradiente)
            SummaryCard(
                icon: "chart.bar.fill",
                title: "Total",
                value: totalExpenses.formattedCurrency,
                valueColor: .clarityPrimary,
                gradient: Color.clarityGradient
            )
            
            // Card 2: Gastos (Azul)
            SummaryCard(
                icon: "list.bullet.rectangle",
                title: "Gastos",
                value: "\(expenseCount)",
                valueColor: Color(hex: "#3B82F6"),
                gradient: LinearGradient(
                    colors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Card 3: Ahorro (Verde/Rojo según valor)
            SummaryCard(
                icon: savings >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                title: "Ahorro",
                value: savings.formattedCurrency,
                valueColor: savings >= 0 ? .green : .red,
                gradient: LinearGradient(
                    colors: savings >= 0 
                        ? [Color(hex: "#10B981"), Color(hex: "#059669")]
                        : [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        
        VStack(spacing: 24) {
            Text("Resumen Financiero")
                .font(.title.bold())
                .foregroundStyle(.white)
            
            SummaryCardsView(
                totalExpenses: 1380.10,
                expenseCount: 33,
                savings: 2694.00,
                savingsPercentage: 200,
                available: 1319.90
            )
            .padding(.horizontal)
            
            SummaryCardsView(
                totalExpenses: 3250.75,
                expenseCount: 89,
                savings: -450.25,
                savingsPercentage: -14,
                available: 549.75
            )
            .padding(.horizontal)
        }
    }
    .preferredColorScheme(.dark)
}
