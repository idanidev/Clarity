//
//  AddGoalSheet.swift
//  Clarity
//
//  Crear / editar Hucha, Escudo o Ahorro mensual con Form nativo iOS.
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
    /// «Cancelar» con cambios: pregunta antes de tirarlos (`confirmarDescarte`).
    @State private var preguntarDescarte = false
    /// Foto del formulario al abrir (ya con los datos de la meta, si se edita).
    @State private var estadoInicial: EstadoFormulario?
    /// El usuario ha elegido a mano la categoría o la subcategoría de la hucha.
    /// Va aparte de la foto porque esos dos campos también cambian solos —la
    /// primera categoría se elige sola al abrir y la subcategoría se vacía al
    /// cambiar de categoría—, y eso no es algo que el usuario pueda perder.
    @State private var categoriaHuchaTocada = false

    /// Lo que el usuario puede tocar, salvo la categoría de la hucha (ver arriba).
    private struct EstadoFormulario: Equatable {
        var nombre: String
        var importe: String
        var tipo: GoalType
        var simbolo: String
        var fechaLimite: Date?
        var categoriaEscudo: String
    }

    private var estadoActual: EstadoFormulario {
        EstadoFormulario(
            nombre: name, importe: targetAmount, tipo: selectedType, simbolo: selectedSymbol,
            fechaLimite: useDeadline ? deadline : nil, categoriaEscudo: selectedCategory)
    }

    /// No basta con que haya texto —al editar siempre lo hay—: se compara con la
    /// foto de cuando se abrió.
    private var hayCambios: Bool {
        guard let estadoInicial else { return false }
        return categoriaHuchaTocada || estadoInicial != estadoActual
    }

    /// El mismo enlace, pero que además apunta que ha sido el usuario.
    private func tocadoPorElUsuario(_ enlace: Binding<String>) -> Binding<String> {
        Binding(
            get: { enlace.wrappedValue },
            set: {
                enlace.wrappedValue = $0
                categoriaHuchaTocada = true
            }
        )
    }

    private var canSave: Bool {
        guard !targetAmount.isEmpty else { return false }
        switch selectedType {
        case .monthlySavings:
            // Solo pide el importe: sin nombre se llama "Ahorro mensual".
            return true
        case .savingsTarget:
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
            let cats = UserDataManager.shared.categories
            let subs = cats.first(where: { $0.name == savingsCategory })?.subcategories ?? []
            if !subs.isEmpty && savingsSubcategory.isEmpty { return false }
            return !savingsCategory.isEmpty
        case .spendingLimit:
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
            return !selectedCategory.isEmpty
        }
    }

    private var amountLabel: String {
        switch selectedType {
        case .savingsTarget:
            return String(localized: "goal.savingsTarget", defaultValue: "Objetivo de Ahorro")
        case .spendingLimit:
            return String(localized: "goal.monthlyLimit", defaultValue: "Límite Mensual")
        case .monthlySavings:
            return String(localized: "goal.monthlySavings", defaultValue: "Ahorro al mes")
        }
    }

    private var typeFooter: String {
        switch selectedType {
        case .savingsTarget:
            return "Hucha: ahorra hacia un objetivo (vacaciones, coche, etc)."
        case .spendingLimit:
            return "Escudo: limita el gasto mensual de una categoría."
        case .monthlySavings:
            return "Ahorro mensual: lo que te quede de tus ingresos tras gastar cuenta como ahorrado. Empieza de cero cada mes."
        }
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
                            Label("Ahorrar al mes", systemImage: "calendar").tag(GoalType.monthlySavings)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
                        .onChange(of: selectedType) { _, nuevo in
                            // El icono inicial es el de hucha/escudo; al pasar a ahorro
                            // mensual sin haber elegido otro, se propone el suyo.
                            if nuevo == .monthlySavings && selectedSymbol == Self.simboloInicial {
                                selectedSymbol = GoalType.monthlySavings.defaultIcon
                            }
                        }
                    } footer: {
                        Text(typeFooter)
                    }
                }

                // ── Nombre + icono ──
                Section {
                    HStack(spacing: 14) {
                        Button {
                            showSymbolPicker = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            // No es CirculoIconoClarity: ese oculta el icono a
                            // VoiceOver y aquí es la única etiqueta del botón.
                            ZStack {
                                Circle()
                                    .fill(Color.clarityPrimary.opacity(0.22))
                                Circle()
                                    .strokeBorder(Color.clarityPrimary.opacity(0.5), lineWidth: 0.5)
                                Image(systemName: selectedSymbol)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.clarityPrimary)
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        TextField(namePlaceholder, text: $name)
                            .font(.body)
                            .submitLabel(.done)
                    }
                } header: {
                    Text(selectedType == .monthlySavings ? "Nombre (opcional)" : "Nombre")
                }

                // ── Cantidad ──
                Section {
                    HStack(spacing: 4) {
                        Text("€")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                        TextField("0", text: $targetAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text(amountLabel)
                }

                // ── Categoría vinculada (el ahorro mensual no lleva) ──
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
                                .foregroundStyle(selectedCategory.isEmpty ? Color.textSecondary : Color.primary)
                            }
                        }
                    } header: {
                        Text("Categoría a vigilar")
                    } footer: {
                        Text("El escudo cuenta los gastos de esta categoría hasta el límite.")
                    }
                } else if selectedType == .savingsTarget {
                    let categories = UserDataManager.shared.categories
                    Section {
                        if !categories.isEmpty {
                            Picker("Categoría", selection: tocadoPorElUsuario($savingsCategory)) {
                                ForEach(categories, id: \.name) { cat in
                                    Text(cat.name).tag(cat.name)
                                }
                            }
                            .onChange(of: savingsCategory) { _, _ in
                                savingsSubcategory = ""
                            }

                            let subcats = categories.first(where: { $0.name == savingsCategory })?.subcategories ?? []
                            if !subcats.isEmpty {
                                Picker("Subcategoría", selection: tocadoPorElUsuario($savingsSubcategory)) {
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
                                                .foregroundStyle(Color.success)
                                        }
                                        .disabled(newSubcategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                                        .accessibilityLabel("Confirmar subcategoría")
                                        Button {
                                            showAddSubcategory = false
                                            newSubcategoryName = ""
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(Color.textSecondary)
                                        }
                                        .accessibilityLabel("Cancelar subcategoría")
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
                        .tint(Color.clarityPrimary)

                        if useDeadline {
                            DatePicker(
                                "Fecha",
                                selection: $deadline,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .tint(Color.clarityPrimary)
                        }
                    }
                }
            }
            .fondoClarity()
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .onAppear {
                prefill()
                // La foto, una sola vez y después de rellenar: `onAppear` vuelve a
                // saltar al regresar del selector de categoría del escudo.
                if estadoInicial == nil { estadoInicial = estadoActual }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCancelarFormulario(
                        preguntando: $preguntarDescarte,
                        hayCambios: hayCambios
                    ) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingGoal != nil ? "Actualizar" : "Guardar") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .confirmarDescarte(
                preguntando: $preguntarDescarte,
                hayCambios: hayCambios
            ) { dismiss() }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $selectedSymbol)
                .sinHuecoBarraInferior()  // hoja sin barra de pestañas debajo
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
                categoriaHuchaTocada = true
                newSubcategoryName = ""
                showAddSubcategory = false
                HapticManager.shared.notification(.success)
            }
        }
    }

    /// Icono con el que abre la hoja; sirve para saber si el usuario ha elegido otro.
    private static let simboloInicial = "eurosign.circle"

    private var namePlaceholder: String {
        selectedType == .monthlySavings
            ? String(localized: "goal.monthlySavingsName", defaultValue: "Ahorro mensual")
            : String(localized: "goal.namePlaceholder", defaultValue: "Nombre")
    }

    private var navigationTitle: String {
        switch (editingGoal != nil, selectedType) {
        case (true, .savingsTarget): return "Editar Hucha"
        case (true, .spendingLimit): return "Editar Escudo"
        case (true, .monthlySavings): return "Editar Ahorro mensual"
        case (false, .savingsTarget): return "Nueva Hucha"
        case (false, .spendingLimit): return "Nuevo Escudo"
        case (false, .monthlySavings): return "Nuevo Ahorro mensual"
        }
    }

    private func prefill() {
        guard let goal = editingGoal else { return }
        name = goal.name
        // Sin el ".0" de String(Double) cuando el objetivo es entero.
        targetAmount = goal.targetAmount == goal.targetAmount.rounded()
            ? String(Int(goal.targetAmount))
            : String(goal.targetAmount)
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

        var goalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if goalName.isEmpty && selectedType == .monthlySavings {
            goalName = GoalType.monthlySavings.displayName
        }

        var updatedGoal = Goal(
            name: goalName,
            type: selectedType,
            // El ahorro mensual se mide cada mes de cero; el resto conserva lo que tuviera.
            recurrence: editingGoal?.recurrence ?? (selectedType == .monthlySavings ? .monthly : .oneTime),
            targetAmount: amount,
            linkedCategoryId: selectedType == .spendingLimit && !selectedCategory.isEmpty ? selectedCategory : nil,
            savingsExpenseCategory: selectedType == .savingsTarget && !savingsCategory.isEmpty ? savingsCategory : nil,
            savingsExpenseSubcategory: selectedType == .savingsTarget && !savingsSubcategory.isEmpty ? savingsSubcategory : nil,
            deadline: selectedType == .savingsTarget && useDeadline ? deadline : nil,
            icon: selectedSymbol
        )
        // La tarjeta prefiere `systemImage` a `icon`: se escribe también ahí para
        // que un símbolo antiguo no tape el recién elegido.
        updatedGoal.systemImage = selectedSymbol.contains(".") ? selectedSymbol : nil

        if let existing = editingGoal {
            updatedGoal.documentId = existing.documentId
            updatedGoal.currentAmount = existing.currentAmount
            updatedGoal.createdAt = existing.createdAt
            updatedGoal.colorHex = existing.colorHex
            // Sin esto el merge de Firestore pisaba el historial de aportaciones
            // de la hucha con un array vacío.
            updatedGoal.savedHistory = existing.savedHistory
        }

        onSave(updatedGoal)
        dismiss()
    }
}

#Preview {
    AddGoalSheet(onSave: { _ in })
}
