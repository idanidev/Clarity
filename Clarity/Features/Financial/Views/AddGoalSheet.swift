//
//  AddGoalSheet.swift
//  Clarity
//
//  Crear / editar Hucha o Escudo con Form nativo iOS.
//

import SwiftUI

struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss

    var editingGoal: Goal? = nil
    var onSave: (Goal) -> Void

    // State
    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var selectedType: GoalType = .savingsTarget
    @State private var selectedSymbol: String = "eurosign.circle"
    @State private var deadline: Date = Date()
    @State private var useDeadline: Bool = false
    @State private var showSymbolPicker = false
    @State private var selectedCategory: String = ""      // For shields
    @State private var savingsCategory: String = ""       // For piggy banks
    @State private var savingsSubcategory: String = ""    // For piggy banks
    @State private var showNewCategory = false
    @State private var showAddSubcategory = false
    @State private var newSubcategoryName = ""

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !targetAmount.isEmpty else { return false }
        if selectedType == .savingsTarget {
            let cats = UserDataManager.shared.categories
            let subs = cats.first(where: { $0.name == savingsCategory })?.subcategories ?? []
            if !subs.isEmpty && savingsSubcategory.isEmpty { return false }
            if savingsCategory.isEmpty { return false }
        }
        if selectedType == .spendingLimit && selectedCategory.isEmpty { return false }
        return true
    }

    private var amountLabel: String {
        selectedType == .savingsTarget
            ? String(localized: "goal.savingsTarget", defaultValue: "Objetivo de Ahorro")
            : String(localized: "goal.monthlyLimit", defaultValue: "Límite Mensual")
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Tipo (solo al crear) ──
                if editingGoal == nil {
                    Section {
                        Picker("", selection: $selectedType) {
                            Label("Hucha", systemImage: "banknote").tag(GoalType.savingsTarget)
                            Label("Escudo", systemImage: "shield").tag(GoalType.spendingLimit)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
                    } footer: {
                        Text(selectedType == .savingsTarget
                            ? "Hucha: ahorra hacia un objetivo (vacaciones, coche, etc)."
                            : "Escudo: limita el gasto mensual de una categoría."
                        )
                    }
                }

                // ── Nombre + icono ──
                Section {
                    HStack(spacing: 14) {
                        Button {
                            showSymbolPicker = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.clarityPrimary.opacity(0.15))
                                Image(systemName: selectedSymbol)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.clarityPrimary)
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        TextField(
                            String(localized: "goal.namePlaceholder", defaultValue: "Nombre"),
                            text: $name
                        )
                        .font(.body)
                        .submitLabel(.done)
                    }
                } header: {
                    Text("Nombre")
                }

                // ── Cantidad ──
                Section {
                    HStack(spacing: 4) {
                        Text("€")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("0", text: $targetAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text(amountLabel)
                }

                // ── Categoría vinculada ──
                if selectedType == .spendingLimit {
                    Section {
                        NavigationLink {
                            ShieldCategoryPickerView(selectedCategory: $selectedCategory)
                        } label: {
                            HStack {
                                Label(
                                    selectedCategory.isEmpty ? "Selecciona categoría" : selectedCategory,
                                    systemImage: "tag"
                                )
                                .foregroundStyle(selectedCategory.isEmpty ? .secondary : .primary)
                            }
                        }
                    } header: {
                        Text("Categoría a vigilar")
                    } footer: {
                        Text("El escudo cuenta los gastos de esta categoría hasta el límite.")
                    }
                } else {
                    let categories = UserDataManager.shared.categories
                    Section {
                        if !categories.isEmpty {
                            Picker("Categoría", selection: $savingsCategory) {
                                ForEach(categories, id: \.name) { cat in
                                    Text(cat.name).tag(cat.name)
                                }
                            }
                            .onChange(of: savingsCategory) { _, _ in
                                savingsSubcategory = ""
                            }

                            let subcats = categories.first(where: { $0.name == savingsCategory })?.subcategories ?? []
                            if !subcats.isEmpty {
                                Picker("Subcategoría", selection: $savingsSubcategory) {
                                    ForEach(subcats, id: \.self) { sub in
                                        Text(sub).tag(sub)
                                    }
                                }
                            }

                            // Inline add subcategory
                            if let currentCat = categories.first(where: { $0.name == savingsCategory }) {
                                if showAddSubcategory {
                                    HStack {
                                        TextField("Nueva subcategoría", text: $newSubcategoryName)
                                            .submitLabel(.done)
                                            .onSubmit { addSubcategory(to: currentCat) }
                                        Button {
                                            addSubcategory(to: currentCat)
                                        } label: {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                        .disabled(newSubcategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                                        Button {
                                            showAddSubcategory = false
                                            newSubcategoryName = ""
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else {
                                    Button {
                                        showAddSubcategory = true
                                    } label: {
                                        Label("Nueva subcategoría", systemImage: "plus.circle")
                                            .foregroundStyle(Color.clarityPrimary)
                                    }
                                }
                            }
                        }

                        Button {
                            showNewCategory = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            Label("Nueva categoría", systemImage: "plus.circle.fill")
                                .foregroundStyle(Color.clarityPrimary)
                        }
                    } header: {
                        Text("Categoría del gasto")
                    } footer: {
                        Text("Cada aportación se registra como un gasto en esta categoría.")
                    }
                    .onAppear {
                        if savingsCategory.isEmpty, let first = categories.first {
                            savingsCategory = first.name
                            savingsSubcategory = first.subcategories.first ?? ""
                        }
                    }
                }

                // ── Fecha límite (sólo huchas) ──
                if selectedType == .savingsTarget {
                    Section {
                        Toggle(
                            String(localized: "goal.deadline", defaultValue: "Fecha límite"),
                            isOn: $useDeadline.animation()
                        )

                        if useDeadline {
                            DatePicker(
                                "Fecha",
                                selection: $deadline,
                                in: Date()...,
                                displayedComponents: .date
                            )
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .onAppear { prefill() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingGoal != nil ? "Actualizar" : "Guardar") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $selectedSymbol)
        }
        .sheet(isPresented: $showNewCategory) {
            NewCategorySheet()
        }
    }

    private func addSubcategory(to category: Category) {
        let trimmed = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !category.subcategories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            HapticManager.shared.notification(.warning)
            return
        }
        let categoryId = category.id ?? category.name
        let subToAdd = trimmed
        Task {
            await UserDataManager.shared.addSubcategory(subToAdd, toCategoryId: categoryId)
            await MainActor.run {
                savingsSubcategory = subToAdd
                newSubcategoryName = ""
                showAddSubcategory = false
                HapticManager.shared.notification(.success)
            }
        }
    }

    private var navigationTitle: String {
        if editingGoal != nil {
            return selectedType == .savingsTarget ? "Editar Hucha" : "Editar Escudo"
        }
        return selectedType == .savingsTarget ? "Nueva Hucha" : "Nuevo Escudo"
    }

    private func prefill() {
        guard let goal = editingGoal else { return }
        name = goal.name
        targetAmount = String(goal.targetAmount)
        selectedType = goal.type
        if let symbol = goal.systemImage ?? goal.icon, !symbol.isEmpty {
            selectedSymbol = symbol
        }
        selectedCategory = goal.linkedCategoryId ?? ""
        savingsCategory = goal.savingsExpenseCategory ?? ""
        savingsSubcategory = goal.savingsExpenseSubcategory ?? ""
        if let d = goal.deadline {
            deadline = d
            useDeadline = true
        }
    }

    private func save() {
        guard let amount = Double(targetAmount.replacingOccurrences(of: ",", with: ".")) else {
            return
        }

        var updatedGoal = Goal(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType,
            targetAmount: amount,
            linkedCategoryId: selectedType == .spendingLimit && !selectedCategory.isEmpty ? selectedCategory : nil,
            savingsExpenseCategory: selectedType == .savingsTarget && !savingsCategory.isEmpty ? savingsCategory : nil,
            savingsExpenseSubcategory: selectedType == .savingsTarget && !savingsSubcategory.isEmpty ? savingsSubcategory : nil,
            deadline: useDeadline ? deadline : nil,
            icon: selectedSymbol
        )

        if let existing = editingGoal {
            updatedGoal.documentId = existing.documentId
            updatedGoal.currentAmount = existing.currentAmount
            updatedGoal.createdAt = existing.createdAt
        }

        onSave(updatedGoal)
        dismiss()
    }
}

#Preview {
    AddGoalSheet(onSave: { _ in })
}
