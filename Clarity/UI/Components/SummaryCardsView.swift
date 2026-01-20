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
    
    var body: some View {
        VStack(spacing: 10) {
            // Icono con gradiente
            ZStack {
                Circle()
                    .fill(gradient ?? LinearGradient(colors: [valueColor, valueColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .shadow(color: valueColor.opacity(0.3), radius: 6, y: 3)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Valor principal
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .opacity(animateValue ? 1 : 0)
                .scaleEffect(animateValue ? 1 : 0.8)
            
            // Título
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                
            // Subtítulo opcional
            if let subtitle = subtitle {
                 Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background {
            ZStack {
                // Fondo base adaptativo
                Color(.secondarySystemBackground)

                // Gradiente de fondo sutil
                if let gradient = gradient {
                    gradient.opacity(0.15)
                } else {
                    valueColor.opacity(0.12)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(
                    LinearGradient(
                        colors: [valueColor.opacity(0.3), valueColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .shadow(color: valueColor.opacity(0.1), radius: 8, y: 4)
        .onAppear {
            if isAnimated {
                withAnimation(.bouncy(duration: 0.5).delay(0.1)) {
                    animateValue = true
                }
            } else {
                animateValue = true
            }
        }
        .onChange(of: value) { _, _ in
            // Animación al cambiar valor
            if isAnimated {
                withAnimation(.bouncy(duration: 0.3)) {
                    animateValue = false
                }
                withAnimation(.bouncy(duration: 0.3).delay(0.1)) {
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
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
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
                valueColor: Color(hex: "#3B82F6")!,
                gradient: LinearGradient(
                    colors: [Color(hex: "#3B82F6")!, Color(hex: "#2563EB")!],
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
                        ? [Color(hex: "#10B981")!, Color(hex: "#059669")!]
                        : [Color(hex: "#EF4444")!, Color(hex: "#DC2626")!],
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
