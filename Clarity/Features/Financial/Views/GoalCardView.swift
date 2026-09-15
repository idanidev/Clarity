//
//  GoalCardView.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//

import SwiftUI

struct GoalCardView: View {
    let goal: Goal
    /// Closure that returns the spent amount for a given category name.
    /// Provided by FinancialDashboardView via FinancialHubViewModel.getSpentAmount(for:).
    var spentAmountProvider: ((String) -> Double)? = nil
    var onFeed: ((Double) -> Void)?  // Only for Piggy Banks
    var onEdit: (() -> Void)?       // Edit action
    var onDelete: (() -> Void)?    // Delete action

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                CirculoIconoClarity(
                    icono: iconoMeta.icono,
                    color: colorMeta,
                    tamano: 44,
                    esSimbolo: iconoMeta.esSimbolo
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if goal.type == .spendingLimit, let cat = goal.linkedCategoryId, !cat.isEmpty {
                        Text(cat)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text(goal.type == .savingsTarget ? "Meta de Ahorro" : "Límite Mensual")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Status Badge
                statusBadge
            }

            // Progress Bar
            // Cerca del tope la barra ondula para avisar sin gritar; ocupa lo mismo,
            // así que cambiar de una a otra no mueve la tarjeta.
            if goal.type == .spendingLimit && progreso >= 0.85 {
                BarraOndulada(progreso: progreso, color: progressColor, alto: 8)
            } else {
                BarraProgresoClarity(progreso: progreso, color: progressColor, alto: 8)
            }

            // Stats & Action
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mainStatText)
                        .estiloCifraClarity(tamano: 24)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("de \(Formatters.currency(goal.targetAmount))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if goal.type == .savingsTarget {
                    feedButton
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: CornerRadius.large, interactivo: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.name), \(mainStatText) de \(Formatters.currency(goal.targetAmount))")
        .accessibilityHint(goal.type == .savingsTarget ? "Meta de ahorro" : "Límite de gasto")
        .contextMenu {
            Button {
                onEdit?()
            } label: {
                Label("Editar", systemImage: "pencil")
            }

            Divider()

            // Eliminar
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Eliminar", systemImage: "trash.fill")
            }
        }
        .confirmationDialog(
            "¿Eliminar \"\(goal.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Esta acción no se puede deshacer. Los gastos vinculados se mantendrán.")
        }
    }

    // MARK: - Components

    private var statusBadge: some View {
        Group {
            if goal.type == .spendingLimit {
                if displayedCurrentAmount > goal.targetAmount {
                    chip(Text("¡Roto! 💔"), color: Color.error)
                } else {
                    chip(Text("Protegido"), color: Color.success)
                }
            } else {
                let pct =
                    goal.targetAmount > 0 ? min(goal.currentAmount / goal.targetAmount, 1.0) : 0
                chip(Text("\(Int(pct * 100))%"), color: Color.clarityPrimary)
            }
        }
    }

    /// Chip tintado como los de la Home. Recibe un `Text` y no un `String` para
    /// que los literales sigan pasando por la localización.
    private func chip(_ texto: Text, color: Color) -> some View {
        texto
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }

    @State private var showFeedSheet = false

    private var feedButton: some View {
        Button {
            showFeedSheet = true
            HapticManager.shared.impact(.light)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                Text("Alimentar")
            }
        }
        .buttonStyle(.secundarioClarity)
        .sheet(isPresented: $showFeedSheet) {
            if let onFeed = onFeed {
                FeedGoalSheet(goal: goal, onFeed: onFeed)
            }
        }
    }

    // MARK: - Helpers

    /// Real spending for spendingLimit goals — delegated to FinancialHubViewModel via spentAmountProvider.
    /// For savingsTarget goals, returns goal.currentAmount.
    private var displayedCurrentAmount: Double {
        if goal.type == .spendingLimit, let categoryId = goal.linkedCategoryId, !categoryId.isEmpty {
            return spentAmountProvider?(categoryId) ?? 0
        }
        return goal.currentAmount
    }

    /// De 0 a 1 para la barra; la barra recorta lo que se pase.
    private var progreso: Double {
        goal.targetAmount > 0 ? displayedCurrentAmount / goal.targetAmount : 0
    }

    /// El mismo criterio de siempre para elegir icono: SF Symbol si lo hay,
    /// emoji si el icono guardado es corto, y el de la clase de meta si no hay nada.
    private var iconoMeta: (icono: String, esSimbolo: Bool) {
        if let sysImage = goal.systemImage, !sysImage.isEmpty {
            return (sysImage, true)
        }
        if let icon = goal.icon, !icon.isEmpty {
            return (icon, icon.contains(".") || icon.count > 2)
        }
        return (goal.type == .savingsTarget ? "🐖" : "🛡️", false)
    }

    private var colorMeta: Color {
        if let hex = goal.colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return goal.type == .savingsTarget ? Color.clarityPrimary : Color.warning
    }

    private var progressColor: Color {
        if goal.type == .spendingLimit {
            let ratio = goal.targetAmount > 0 ? displayedCurrentAmount / goal.targetAmount : 0
            return ratio > 0.9 ? Color.error : (ratio > 0.7 ? Color.warning : Color.success)
        } else {
            return Color.clarityPrimary
        }
    }

    private var mainStatText: String {
        if goal.type == .spendingLimit {
            return Formatters.currency(goal.targetAmount - displayedCurrentAmount) + " restan"
        } else {
            return Formatters.currency(displayedCurrentAmount) + " ahorrado"
        }
    }
}

// Simple Progress Bar
struct ProgressBar: View {
    var value: Double
    var total: Double
    var color: Color
    var isWarning: Bool

    private var percentage: Int {
        total > 0 ? Int(min(value / total, 1.0) * 100) : 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.fill.tertiary)

                Capsule()
                    .fill(color)
                    .frame(width: min(CGFloat(value / total) * geo.size.width, geo.size.width))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Progreso \(percentage) por ciento")
        .accessibilityValue("\(percentage)%")
    }
}
