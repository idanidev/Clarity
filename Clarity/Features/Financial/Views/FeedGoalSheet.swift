//
//  FeedGoalSheet.swift
//  Clarity
//
//  Created by Clarity AI on 2026-02-05.
//  Sheet for feeding piggy bank goals with custom amounts
//

import SwiftUI

struct FeedGoalSheet: View {
    @Environment(\.dismiss) var dismiss

    let goal: Goal
    let onFeed: (Double) -> Void

    @State private var customAmount: String = ""
    @State private var selectedQuickAmount: Double?
    /// «Cancelar» con cambios: pregunta antes de tirarlos (`confirmarDescarte`).
    @State private var preguntarDescarte = false

    /// La hoja abre vacía: cualquier cantidad, elegida o escrita, es un cambio.
    private var hayCambios: Bool {
        selectedQuickAmount != nil || !customAmount.isEmpty
    }

    // Quick amount options
    private let quickAmounts: [Double] = [10, 25, 50, 100]

    // Computed
    private var remaining: Double {
        max(0, goal.targetAmount - goal.currentAmount)
    }

    private var selectedAmount: Double? {
        if let quick = selectedQuickAmount {
            return quick
        }
        return Double(customAmount.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        guard let amount = selectedAmount else { return false }
        return amount > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(spacing: 24) {
                // Goal Header
                VStack(spacing: 6) {
                    CirculoIconoClarity(
                        icono: iconoMeta.icono,
                        color: colorMeta,
                        tamano: 72,
                        esSimbolo: iconoMeta.esSimbolo
                    )
                    .padding(.bottom, 4)

                    Text(goal.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Text("Faltan \(Formatters.currency(remaining))")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top)

                // Quick Amount Buttons
                VStack(alignment: .leading, spacing: 12) {
                    CabeceraSeccionClarity(titulo: String(localized: "Cantidad rápida"))

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 12
                    ) {
                        ForEach(quickAmounts, id: \.self) { amount in
                            quickAmountButton(amount: amount)
                        }
                    }
                }
                .padding(.horizontal)

                // OR Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.textTertiary.opacity(0.5))
                    Text("o")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.textTertiary.opacity(0.5))
                }
                .padding(.horizontal)

                // Custom Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cantidad personalizada")
                        .estiloEtiquetaClarity()

                    HStack(alignment: .firstTextBaseline) {
                        Text("€")
                            .scaledFont(size: 28, weight: .bold, design: .rounded)
                            .foregroundStyle(Color.textSecondary)

                        TextField("0", text: $customAmount)
                            .keyboardType(.decimalPad)
                            .scaledFont(size: 44, weight: .bold, design: .rounded)
                            .onChange(of: customAmount) { _, _ in
                                selectedQuickAmount = nil
                            }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: CornerRadius.large)
                .padding(.horizontal)

                // Preview
                if let amount = selectedAmount, isValid {
                    VStack(spacing: 4) {
                        Text("Vista previa")
                            .estiloEtiquetaClarity()

                        HStack(spacing: 4) {
                            Text(Formatters.currency(goal.currentAmount + amount))
                                .font(.headline)
                                .monospacedDigit()
                            Text("de \(Formatters.currency(goal.targetAmount))")
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(Color.textSecondary)
                        }

                        // Mini progress bar
                        BarraProgresoClarity(
                            progreso: goal.targetAmount > 0 ? (goal.currentAmount + amount) / goal.targetAmount : 0,
                            color: Color.clarityPrimary,
                            alto: 8
                        )
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                    .padding()
                    .glassCard(cornerRadius: CornerRadius.large, tint: Color.clarityPrimary)
                    .padding(.horizontal)
                }

                // Feed Button
                Button {
                    if let amount = selectedAmount {
                        onFeed(amount)
                        HapticManager.shared.notification(.success)
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Alimentar Hucha")
                    }
                }
                .buttonStyle(.principalClarity)
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.bottom)
              }
            }
            .fondoClarity()
            .navigationTitle("Alimentar")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCancelarFormulario(
                        preguntando: $preguntarDescarte,
                        hayCambios: hayCambios
                    ) { dismiss() }
                }
            }
            .confirmarDescarte(
                preguntando: $preguntarDescarte,
                hayCambios: hayCambios
            ) { dismiss() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Components

    @ViewBuilder
    private func quickAmountButton(amount: Double) -> some View {
        let isSelected = selectedQuickAmount == amount

        Button {
            selectedQuickAmount = amount
            customAmount = ""
            HapticManager.shared.impact(.light)
        } label: {
            VStack(spacing: 4) {
                Text("€\(Int(amount))")
                    .font(.title3.bold())
                    .monospacedDigit()

                if amount <= remaining {
                    Text("\(Int((amount / remaining) * 100))%")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            // La elegida, en vidrio teñido de marca y con borde: así se distingue
            // también en iOS 17, donde el tinte del vidrio es suave.
            .glassCard(cornerRadius: CornerRadius.medium, tint: isSelected ? Color.clarityPrimary : nil)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.clarityPrimary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(TarjetaButtonStyle())
    }

    // MARK: - Helpers

    /// El mismo criterio de icono que la tarjeta de la meta.
    private var iconoMeta: (icono: String, esSimbolo: Bool) {
        if let sysImage = goal.systemImage, !sysImage.isEmpty {
            return (sysImage, true)
        }
        if let icon = goal.icon, !icon.isEmpty {
            return (icon, icon.contains(".") || icon.count > 2)
        }
        return ("🐖", false)
    }

    private var colorMeta: Color {
        if let hex = goal.colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return Color.clarityPrimary
    }
}

#Preview {
    FeedGoalSheet(
        goal: Goal(
            name: "Vacaciones 2026",
            type: .savingsTarget,
            targetAmount: 1000,
            currentAmount: 450,
            icon: "✈️"
        ),
        onFeed: { _ in
        }
    )
}
