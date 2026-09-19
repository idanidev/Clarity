//
//  MonthlySetupSheet.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  "The Ritual" - New Month Setup Wizard
//

import SwiftUI

struct MonthlySetupSheet: View {
    @Environment(\.dismiss) private var dismiss

    let monthName: String
    let previousMonthIncome: Double?
    let onConfirm: (Double) -> Void

    @State private var incomeText: String = ""
    @FocusState private var isInputFocused: Bool

    // Seasonal emoji based on month
    private var seasonalEmoji: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: return "❄️"
        case 3, 4, 5: return "🌸"
        case 6, 7, 8: return "☀️"
        case 9, 10, 11: return "🍂"
        default: return "✨"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("¡Bienvenido a \(monthName)! \(seasonalEmoji)")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("Vamos a organizar tus finanzas.\n¿Cuál es tu ingreso estimado para este mes?")
                        .font(.body)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                Spacer()

                // Income Input
                // Sin tarjeta a propósito: con el teclado abierto la hoja ya va
                // justa de alto en pantallas pequeñas.
                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("€")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textSecondary)

                        TextField("0", text: $incomeText)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .focused($isInputFocused)
                            .foregroundStyle(Color.primary)
                    }
                    .padding(.horizontal, 32)

                    // Quick Tip — solo la nómina/ingreso fijo del mes. Los ingresos
                    // puntuales (bonus, freelance…) se añaden aparte como "ingresos extra"
                    // para no contarlos dos veces.
                    Text("Indica tu nómina o ingreso fijo del mes. Los extras los añades luego.")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    // "Use same as last month" button
                    if let previousIncome = previousMonthIncome {
                        Button {
                            incomeText = String(format: "%.0f", previousIncome)
                            HapticManager.shared.selection()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Usar lo mismo del mes pasado (\(Formatters.currency(previousIncome)))")
                            }
                        }
                        .buttonStyle(.secundarioClarity)
                    }

                    // Confirm Button
                    Button {
                        confirmSetup()
                    } label: {
                        Text("Empezar el Mes")
                    }
                    .buttonStyle(.principalClarity)
                    .disabled(!isValid)

                    // La hoja no se puede cerrar y el importe tiene que ser
                    // mayor que 0: quien no cobra este mes se quedaba encerrado
                    // o tenía que inventarse una cifra.
                    Button("Este mes no tengo ingresos") {
                        HapticManager.shared.selection()
                        onConfirm(0)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(HomeFondo())
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                // No cancel - This is obligatory!
                // User MUST set up the month before using the dashboard
            }
            .interactiveDismissDisabled(true) // Prevent swipe to dismiss
            .onAppear {
                isInputFocused = true
            }
        }
    }

    // MARK: - Logic

    private var isValid: Bool {
        guard let amount = Double(incomeText), amount > 0 else { return false }
        return true
    }

    private func confirmSetup() {
        guard let amount = Double(incomeText) else { return }

        HapticManager.shared.playSuccess()
        onConfirm(amount)
    }
}

// MARK: - Preview

#Preview("New Month - No Previous") {
    MonthlySetupSheet(
        monthName: "Febrero",
        previousMonthIncome: nil,
        onConfirm: { _ in }
    )
}

#Preview("New Month - With Previous") {
    MonthlySetupSheet(
        monthName: "Febrero",
        previousMonthIncome: 1850,
        onConfirm: { _ in }
    )
}
