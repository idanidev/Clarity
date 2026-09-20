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
    /// Ahorro del mes (ingresos − gastado) para las metas de ahorro mensual; los
    /// demás tipos lo ignoran. Puede venir negativo: la tarjeta enseña 0 € y avisa.
    var monthlySavings: Double = 0
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

                    subtitulo
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
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

                    Text(subStatText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.textSecondary)

                    if mesEnNegativo {
                        Text("Este mes no cierra en positivo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.error)
                    }
                }

                Spacer()

                if goal.type == .savingsTarget {
                    feedButton
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: CornerRadius.large, interactivo: true)
        .contentShape(Rectangle())
        // Tocar la tarjeta abre la edición; el botón de alimentar se queda su
        // toque porque los gestos del hijo ganan al del padre.
        .onTapGesture {
            HapticManager.shared.impact(.light)
            onEdit?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.name), \(mainStatText) \(subStatText)")
        .accessibilityHint("Edita la meta")
        .accessibilityAddTraits(.isButton)
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

    /// `Text` y no `String` para que los literales sigan pasando por la localización.
    private var subtitulo: Text {
        switch goal.type {
        case .spendingLimit:
            if let cat = goal.linkedCategoryId, !cat.isEmpty {
                return Text(cat)
            }
            return Text("Límite Mensual")
        case .savingsTarget:
            return Text("Meta de Ahorro")
        case .monthlySavings:
            // No repite el nombre por defecto ("Ahorro mensual"): dice de dónde
            // sale. Corto, que a la derecha va el chip "Objetivo cumplido".
            return Text("Ingresos − gastos")
        }
    }

    private var statusBadge: some View {
        Group {
            switch goal.type {
            case .spendingLimit:
                if displayedCurrentAmount > goal.targetAmount {
                    chip(Text("¡Roto! 💔"), color: Color.error)
                } else {
                    chip(Text("Protegido"), color: Color.success)
                }
            case .savingsTarget:
                chip(Text("\(porcentaje)%"), color: Color.clarityPrimary)
            case .monthlySavings:
                if objetivoCumplido {
                    chip(Text("Objetivo cumplido"), color: Color.success)
                } else {
                    chip(Text("\(porcentaje)%"), color: Color.clarityPrimary)
                }
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
    /// Uno por tarjeta: así el id "aportar" no choca entre huchas.
    @Namespace private var ns

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
        .origenZoom(id: "aportar", en: ns)
        .sheet(isPresented: $showFeedSheet) {
            if let onFeed = onFeed {
                FeedGoalSheet(goal: goal, onFeed: onFeed)
                    .transicionZoomDeHoja(id: "aportar", en: ns)
            }
        }
    }

    // MARK: - Helpers

    /// Real spending for spendingLimit goals — delegated to FinancialHubViewModel via spentAmountProvider.
    /// For monthlySavings goals, the month's savings (never below 0). For savingsTarget goals, goal.currentAmount.
    private var displayedCurrentAmount: Double {
        if goal.type == .spendingLimit, let categoryId = goal.linkedCategoryId, !categoryId.isEmpty {
            return spentAmountProvider?(categoryId) ?? 0
        }
        if goal.type == .monthlySavings {
            return max(monthlySavings, 0)
        }
        return goal.currentAmount
    }

    /// De 0 a 1 para la barra; la barra recorta lo que se pase.
    private var progreso: Double {
        goal.targetAmount > 0 ? displayedCurrentAmount / goal.targetAmount : 0
    }

    private var porcentaje: Int {
        Int(min(max(progreso, 0), 1) * 100)
    }

    /// Solo para el ahorro mensual: se ha gastado más de lo ingresado.
    private var mesEnNegativo: Bool {
        goal.type == .monthlySavings && monthlySavings < 0
    }

    private var objetivoCumplido: Bool {
        goal.type == .monthlySavings && goal.targetAmount > 0 && displayedCurrentAmount >= goal.targetAmount
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
        let porDefecto = goal.type.defaultIcon
        return (porDefecto, porDefecto.contains("."))
    }

    private var colorMeta: Color {
        if let hex = goal.colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        switch goal.type {
        case .savingsTarget: return Color.clarityPrimary
        case .spendingLimit: return Color.warning
        case .monthlySavings: return Color.success
        }
    }

    private var progressColor: Color {
        switch goal.type {
        case .spendingLimit:
            let ratio = goal.targetAmount > 0 ? displayedCurrentAmount / goal.targetAmount : 0
            return ratio > 0.9 ? Color.error : (ratio > 0.7 ? Color.warning : Color.success)
        case .savingsTarget:
            return Color.clarityPrimary
        case .monthlySavings:
            return objetivoCumplido ? Color.success : Color.clarityPrimary
        }
    }

    private var mainStatText: String {
        switch goal.type {
        case .spendingLimit:
            return Formatters.currency(goal.targetAmount - displayedCurrentAmount) + " restan"
        case .savingsTarget, .monthlySavings:
            return Formatters.currency(displayedCurrentAmount) + " ahorrado"
        }
    }

    private var subStatText: String {
        goal.type == .monthlySavings
            ? "de \(Formatters.currency(goal.targetAmount)) este mes"
            : "de \(Formatters.currency(goal.targetAmount))"
    }
}
