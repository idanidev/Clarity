// IncomeInputView.swift
//
// Display-only energy tank showing monthly income.
// Editing happens exclusively via the ⚙️ Salary Settings sheet.

import SwiftUI

struct IncomeInputView: View {
    let income: Double
    var currency: String = "€"
    var onTapToEdit: (() -> Void)? = nil

    // Config
    private let maxIncome: Double = 5000  // Visual Max for tank

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Energía Mensual")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()

                Button {
                    onTapToEdit?()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(Color.clarityPrimary)
                }
            }
            .padding(.horizontal)

            // The Energy Tank (display-only, tap to open settings)
            ZStack(alignment: .bottom) {
                // Background Tank
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .systemGray6))
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.clarityPrimary.opacity(0.1), lineWidth: 2)
                    )

                // Liquid Fill
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clarityPrimary, Color.clarityPrimary.opacity(0.7),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: geo.size.height * CGFloat(min(income / maxIncome, 1.0)))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: income)

                        // Decoration bubbles
                        if income > 0 {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 10, height: 10)
                                .offset(x: 20, y: -40)
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 20, height: 20)
                                .offset(x: -30, y: -20)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .frame(height: 180)

                // Value Overlay
                VStack {
                    Text(Formatters.currency(income))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                    Text("Disponible")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal)
            .onTapGesture { onTapToEdit?() }

            // Tip
            Text(incomeTip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .animation(.default, value: income)
        }
        .padding(.vertical)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private var incomeTip: String {
        if income < 1000 {
            return "🔋 Modo Ahorro: Prioriza lo esencial."
        } else if income < 2500 {
            return "⚡ Energía Estable: Buen momento para llenar huchas."
        } else {
            return "🚀 ¡A tope de energía! ¿Invertimos en sueños?"
        }
    }
}
