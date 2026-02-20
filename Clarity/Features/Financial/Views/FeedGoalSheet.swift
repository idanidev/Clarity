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
            VStack(spacing: 24) {
                // Goal Header
                VStack(spacing: 8) {
                    Text(goal.icon ?? "🐖")
                        .font(.system(size: 56))

                    Text(goal.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Text("Faltan \(Formatters.currency(remaining))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                Divider()

                // Quick Amount Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cantidad rápida")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

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
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("o")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.secondary.opacity(0.3))
                }
                .padding(.horizontal)

                // Custom Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cantidad personalizada")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack {
                        Text("€")
                            .font(.title.bold())
                            .foregroundStyle(.secondary)

                        TextField("0", text: $customAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .onChange(of: customAmount) { _, _ in
                                // Clear quick selection when typing
                                selectedQuickAmount = nil
                            }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                // Preview
                if let amount = selectedAmount, isValid {
                    VStack(spacing: 4) {
                        Text("Vista previa")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 4) {
                            Text(Formatters.currency(goal.currentAmount + amount))
                                .font(.headline)
                            Text("de \(Formatters.currency(goal.targetAmount))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(uiColor: .systemGray6))

                                Capsule()
                                    .fill(Color.clarityPrimary)
                                    .frame(
                                        width: min(
                                            CGFloat(
                                                (goal.currentAmount + amount) / goal.targetAmount)
                                                * geo.size.width, geo.size.width))
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clarityPrimary.opacity(0.1))
                    )
                    .padding(.horizontal)
                }

                Spacer()

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
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isValid ? Color.clarityPrimary : Color.secondary)
                    )
                }
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Alimentar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(550)])
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

                if amount <= remaining {
                    Text("\(Int((amount / remaining) * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                            ? Color.clarityPrimary
                            : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.clarityPrimary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .foregroundStyle(isSelected ? .white : .primary)
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
        onFeed: { amount in
            print("Fed \(amount)")
        }
    )
}
