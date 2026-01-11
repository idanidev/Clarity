// SummaryCardsView.swift
// Summary cards showing totals at top of dashboard

import SwiftUI

// MARK: - Individual Summary Card
struct SummaryCard: View {
    let icon: String // Kept for compatibility but might not be used in new design
    let title: String
    let value: String
    var subtitle: String? = nil
    var valueColor: Color = .white
    var iconColor: Color = .gray
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 16, weight: .bold)) // Slightly larger
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.gray)
                
            if let subtitle = subtitle {
                 Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.black) // OLED Black
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(valueColor.opacity(0.3), lineWidth: 1) // Colored border based on value type
        )
    }
}

struct SummaryCardsView: View {
    let totalExpenses: Double
    let expenseCount: Int
    let savings: Double
    let savingsPercentage: Int
    let available: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // Card 1: Total (Purple)
            SummaryCard(
                icon: "",
                title: "Total",
                value: formatCurrency(totalExpenses),
                valueColor: .clarityPrimary // User asked for primary purple
            )
            
            // Card 2: Gastos (Blue-ish/Cyan per screenshot/theme)
            SummaryCard(
                icon: "",
                title: "Gastos",
                value: "\(expenseCount)",
                valueColor: Color(hex: "#3B82F6")! // Blue
            )
            
            // Card 3: Ahorro (Green)
            SummaryCard(
                icon: "",
                title: "Ahorro",
                value: formatCurrency(savings),
                valueColor: .green
            )
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
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
