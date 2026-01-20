// StatCard.swift
// Shared statistic card component for dashboards

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    var isConfidential: Bool = false
    
    @State private var userDataManager = UserDataManager.shared
    
    var body: some View {
        VStack(spacing: 6) {
            Group {
                if isConfidential && userDataManager.privacyMode {
                    Text("****")
                } else {
                    Text(value)
                }
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(.numericText())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            ZStack {
                color.opacity(0.12)
                    .blendMode(.overlay)
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            if isConfidential {
                userDataManager.togglePrivacyMode()
            }
        }
        .animation(.snappy, value: userDataManager.privacyMode)
    }
}

#Preview {
    HStack {
        StatCard(title: "Total", value: "1.200 €", color: .purple)
        StatCard(title: "Gastos", value: "45", color: .blue)
        StatCard(title: "Ahorro", value: "800 €", color: .green)
    }
    .padding()
    .background(Color.black)
}
