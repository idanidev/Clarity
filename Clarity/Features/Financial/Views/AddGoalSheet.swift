//
//  AddGoalSheet.swift
//  Clarity
//
//  Created by Clarity AI on 2026-02-02.
//

import SwiftUI

struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss

    // Callbacks
    var onSave: (Goal) -> Void

    // State
    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var selectedType: GoalType = .savingsTarget
    @State private var selectedSymbol: String = "dollarsign.circle"
    @State private var deadline: Date = Date()
    @State private var useDeadline: Bool = false
    @State private var showSymbolPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header Card
                    VStack(spacing: 16) {
                        Picker("Tipo", selection: $selectedType) {
                            Text("Hucha").tag(GoalType.savingsTarget)
                            Text("Escudo").tag(GoalType.spendingLimit)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // Icon & Name
                        HStack(spacing: 16) {
                            Button {
                                showSymbolPicker = true
                                HapticManager.shared.impact(.light)
                            } label: {
                                Image(systemName: selectedSymbol)
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.clarityPrimary)
                                    .frame(width: 70, height: 70)
                                    .background(
                                        Circle()
                                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                    )
                            }

                            TextField("Nombre de la meta", text: $name)
                                .font(.title3.weight(.medium))
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)

                    // Amount Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            selectedType == .savingsTarget ? "Objetivo de Ahorro" : "Límite Mensual"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                        HStack {
                            Text("€")
                                .font(.title.bold())
                                .foregroundStyle(.secondary)

                            TextField("0", text: $targetAmount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: .black.opacity(0.05), radius: 5)
                    )
                    .padding(.horizontal)

                    // Deadline Toggle (Only for savings)
                    if selectedType == .savingsTarget {
                        Toggle("Fecha límite", isOn: $useDeadline.animation())
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                            .padding(.horizontal)

                        if useDeadline {
                            DatePicker("Fecha", selection: $deadline, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                )
                                .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle(selectedType == .savingsTarget ? "Nueva Hucha" : "Nuevo Escudo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .bold()
                    .disabled(name.isEmpty || targetAmount.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $selectedSymbol)
        }
    }

    private func save() {
        guard let amount = Double(targetAmount.replacingOccurrences(of: ",", with: ".")) else {
            return
        }

        let newGoal = Goal(
            name: name,
            type: selectedType,
            targetAmount: amount,
            deadline: useDeadline ? deadline : nil,
            icon: selectedSymbol  // Store SF Symbol in icon field
        )

        onSave(newGoal)
        dismiss()
    }
}

#Preview {
    AddGoalSheet(onSave: { _ in })
}
