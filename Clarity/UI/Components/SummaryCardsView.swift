// SummaryCardsView.swift
// Summary cards showing totals at top of dashboard

import SwiftUI

struct SummaryCardsView: View {
    let totalExpenses: Double
    let expenseCount: Int
    let savings: Double
    let savingsPercentage: Int
    let available: Double
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Card 1: Total
            SummaryCard(
                icon: "circle.grid.cross",
                title: "TOTAL",
                value: formatCurrency(totalExpenses),
                valueColor: .white
            )
            
            // Card 2: Gastos
            SummaryCard(
                icon: "chart.bar.fill",
                title: "GASTOS",
                value: "\(expenseCount)",
                valueColor: .white
            )
            
            // Card 3: Ahorro
            SummaryCard(
                icon: "dollarsign.circle.fill",
                title: "AHORRO",
                value: formatCurrency(savings),
                subtitle: "\(savingsPercentage)%",
                valueColor: .green,
                iconColor: .yellow
            )
            
            // Card 4: Disponible
            SummaryCard(
                icon: "arrow.up.right",
                title: "DISPONIBLE",
                value: formatCurrency(available),
                valueColor: .green
            )
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }
}

// MARK: - Individual Summary Card
struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String? = nil
    var valueColor: Color = .white
    var iconColor: Color = .gray
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(valueColor.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        
        SummaryCardsView(
            totalExpenses: 1380.10,
            expenseCount: 33,
            savings: 2694.00,
            savingsPercentage: 200,
            available: 1319.90
        )
        .padding(.horizontal)
    }
    .preferredColorScheme(.dark)
}
