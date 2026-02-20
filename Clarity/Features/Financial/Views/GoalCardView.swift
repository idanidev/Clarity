//
//  GoalCardView.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//

import SwiftUI

struct GoalCardView: View {
    let goal: Goal
    var onFeed: ((Double) -> Void)?  // Only for Piggy Banks - now with amount
    var onArchive: (() -> Void)?  // Archive action

    // Animation State
    @State private var coinOffset: CGFloat = 0
    @State private var coinOpacity: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(goal.icon ?? (goal.type == .savingsTarget ? "🐖" : "🛡️"))
                    .font(.title2)
                    .padding(8)
                    .background(.fill.tertiary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(goal.type == .savingsTarget ? "Meta de Ahorro" : "Límite Mensual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status Badge
                statusBadge
            }

            // Progress Bar
            ProgressBar(
                value: goal.currentAmount,
                total: goal.targetAmount,
                color: progressColor,
                isWarning: goal.isOverLimit
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
        .overlay(coinAnimationOverlay)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Archive action (swipe left)
            Button(role: .destructive) {
                HapticManager.shared.notification(.warning)
                onArchive?()
            } label: {
                Label("Archivar", systemImage: "archivebox.fill")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            // Quick Feed (only for piggy banks, swipe right)
            if goal.type == .savingsTarget, let onFeed = onFeed {
                Button {
                    HapticManager.shared.impact(.medium)
                    showFeedSheet = true
                } label: {
                    Label("Alimentar", systemImage: "plus.circle.fill")
                }
                .tint(.green)
            }
        }
        .contextMenu {
            // Edit (future feature)
            Button {
                // TODO: Implement edit functionality
            } label: {
                Label("Editar", systemImage: "pencil")
            }

            Divider()

            // Archive
            Button(role: .destructive) {
                onArchive?()
            } label: {
                Label("Archivar", systemImage: "archivebox.fill")
            }
        }
    }

    // MARK: - Components

    private var statusBadge: some View {
        Group {
            if goal.type == .spendingLimit {
                if goal.isOverLimit {
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
                Text("\(Int(goal.progress * 100))%")
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
                FeedGoalSheet(goal: goal, onFeed: { _ in onFeed(0) })
            }
        }
    }

    // MARK: - Animation

    private var coinAnimationOverlay: some View {
        ZStack {
            if coinOpacity > 0 {
                Image(systemName: "centsign.circle.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
                    .offset(y: coinOffset)
                    .opacity(coinOpacity)
            }
        }
    }

    private func animateCoin() {
        // Reset
        coinOffset = -50
        coinOpacity = 0

        // Sequence
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            coinOpacity = 1.0
            coinOffset = 0  // Fly down to button
        }

        HapticManager.shared.playCustomPattern(.expenseAdded)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                coinOpacity = 0
                coinOffset = 20
            }
        }
    }

    // MARK: - Helpers

    private var progressColor: Color {
        if goal.type == .spendingLimit {
            return goal.progress > 0.9 ? .red : (goal.progress > 0.7 ? .orange : .green)
        } else {
            return Color.clarityPrimary  // Standard purple for savings
        }
    }

    private var mainStatText: String {
        if goal.type == .spendingLimit {
            return Formatters.currency(goal.targetAmount - goal.currentAmount) + " restan"
        } else {
            return Formatters.currency(goal.currentAmount) + " ahorrado"
        }
    }
}

// Simple Progress Bar
struct ProgressBar: View {
    var value: Double
    var total: Double
    var color: Color
    var isWarning: Bool

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
    }
}
