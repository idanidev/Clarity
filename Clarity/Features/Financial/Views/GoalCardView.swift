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
        VStack(spacing: 12) {
            // Header
            HStack {
                Group {
                    if let sysImage = goal.systemImage, !sysImage.isEmpty {
                        Image(systemName: sysImage)
                    } else if let icon = goal.icon, !icon.isEmpty {
                        if icon.contains(".") || icon.count > 2 {
                            Image(systemName: icon)
                        } else {
                            Text(icon)
                        }
                    } else {
                        Text(goal.type == .savingsTarget ? "🐖" : "🛡️")
                    }
                }
                .font(.title2)
                .padding(8)
                .background(.fill.tertiary)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if goal.type == .spendingLimit, let cat = goal.linkedCategoryId, !cat.isEmpty {
                        Text(cat)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(goal.type == .savingsTarget ? "Meta de Ahorro" : "Límite Mensual")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Status Badge
                statusBadge
            }

            // Progress Bar
            ProgressBar(
                value: displayedCurrentAmount,
                total: goal.targetAmount,
                color: progressColor,
                isWarning: goal.type == .spendingLimit && displayedCurrentAmount > goal.targetAmount
            )
            .frame(height: 12)

            // Stats & Action
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text(mainStatText)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("de \(Formatters.currency(goal.targetAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if goal.type == .savingsTarget {
                    feedButton
                }
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .primary.opacity(0.05), radius: 10, y: 4)
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
                    Text("¡Roto! 💔")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red))
                } else {
                    Text("Protegido")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green.opacity(0.1)))
                }
            } else {
                let pct =
                    goal.targetAmount > 0 ? min(goal.currentAmount / goal.targetAmount, 1.0) : 0
                Text("\(Int(pct * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(Color.clarityPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.clarityPrimary.opacity(0.1)))
            }
        }
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
            .font(.footnote.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.clarityPrimary))
        }
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

    private var progressColor: Color {
        if goal.type == .spendingLimit {
            let ratio = goal.targetAmount > 0 ? displayedCurrentAmount / goal.targetAmount : 0
            return ratio > 0.9 ? .red : (ratio > 0.7 ? .orange : .green)
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
