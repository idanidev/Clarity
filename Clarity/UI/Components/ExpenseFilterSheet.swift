// ExpenseFilterSheet.swift
// Advanced filter sheet for expenses with quick actions and comprehensive filters

import SwiftUI

// MARK: - Filter Sheet View
struct ExpenseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ExpenseFilter
    let availableCategories: [String]
    let availablePaymentMethods: [String]
    let onApply: () -> Void
    
    @State private var minAmountText: String = ""
    @State private var maxAmountText: String = ""
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var filterToEdit: ExpenseFilter?
    @State private var isEditMode = false
    @AppStorage("filters.onboardingSeen") private var onboardingSeen: Bool = false
    @State private var showOnboarding: Bool = false

    // Hold the @Observable singleton in @State so SwiftUI rastrea cambios
    @State private var userData = UserDataManager.shared

    private var savedPresets: [ExpenseFilter] { userData.savedFilters }
    
    init(
        filter: Binding<ExpenseFilter>,
        availableCategories: [String] = [],
        availablePaymentMethods: [String] = ["Tarjeta", "Efectivo", "Transferencia", "Bizum"],
        onApply: @escaping () -> Void
    ) {
        self._filter = filter
        self.availableCategories = availableCategories
        self.availablePaymentMethods = availablePaymentMethods
        self.onApply = onApply
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // 1. Saved Presets (Top Bar)
                    presetsSection

                    // 2. Main Criteria (Date & Amount)
                    seccion(String(localized: "filters.whenAndHowMuch", defaultValue: "Cuándo y Cuánto")) {
                        VStack(alignment: .leading, spacing: 20) {
                            dateRangeSelector
                            amountRangeSelector
                        }
                    }

                    // 3. Details (Category & Payment)
                    seccion(String(localized: "filters.details", defaultValue: "Detalles")) {
                        VStack(alignment: .leading, spacing: 20) {
                            if !availableCategories.isEmpty {
                                categorySelector
                            }
                            paymentMethodSelector
                        }
                    }

                    // 4. Options & Sort (Compact)
                    seccion(String(localized: "filters.options", defaultValue: "Opciones")) {
                        VStack(spacing: 16) {
                            Toggle(String(localized: "filters.onlyRecurring", defaultValue: "Solo recurrentes"), isOn: $filter.showOnlyRecurring)
                                .tint(Color.clarityPrimary)

                            Divider()

                            HStack {
                                Text(String(localized: "filters.sortBy", defaultValue: "Ordenar por"))
                                Spacer()
                                Menu {
                                    ForEach(ExpenseFilter.SortOption.allCases, id: \.self) { option in
                                        Button(option.rawValue) {
                                            filter.sortBy = option
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(filter.sortBy.rawValue)
                                            .foregroundStyle(Color.clarityPrimary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                }
                            }
                        }
                    }

                    // Clear All (Text Link)
                    if filter.hasActiveFilters {
                        Button(String(localized: "filters.clearAll", defaultValue: "Limpiar todos los filtros")) {
                            resetFilters()
                            HapticManager.shared.notification(.warning)
                        }
                        .foregroundStyle(Color.error)
                        .font(.subheadline)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .fondoClarity()
            .navigationTitle(String(localized: "filters.navigationTitle", defaultValue: "Filtros"))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "filters.apply", defaultValue: "Aplicar")) { applyFilters() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.clarityPrimary)
                }
            }
            .alert(String(localized: "filters.savePreset.title", defaultValue: "Guardar Filtro"), isPresented: $showSavePresetAlert) {
                TextField(String(localized: "filters.savePreset.namePlaceholder", defaultValue: "Nombre del filtro"), text: $newPresetName)
                Button(String(localized: "common.cancel", defaultValue: "Cancelar"), role: .cancel) { newPresetName = "" }
                Button(String(localized: "common.save", defaultValue: "Guardar")) {
                    saveCurrentAsPreset()
                }
            } message: {
                Text("Guarda esta configuración para usarla más tarde.")
            }
            .task {
                // Ensure data is fresh
                await UserDataManager.shared.loadUserData()
            }
            .onAppear {
                // Initialize text fields
                if let min = filter.minAmount { minAmountText = String(Int(min)) }
                if let max = filter.maxAmount { maxAmountText = String(Int(max)) }
                if !onboardingSeen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showOnboarding = true
                    }
                }
            }
            .sheet(isPresented: $showOnboarding, onDismiss: { onboardingSeen = true }) {
                FiltersOnboardingSheet()
            }
        }
    }
    
    // MARK: - Sections
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            CabeceraSeccionClarity(titulo: String(localized: "filters.myFilters", defaultValue: "Mis Filtros"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Save/Update Button
                    if isEditMode {
                        // Modo edición - Actualizar filtro existente
                        Button {
                            Task {
                                await updateExistingFilter()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text("Actualizar '\(newPresetName)'")
                            }
                            .font(.caption.weight(.bold))
                        }
                        .buttonStyle(BotonSecundarioClarity(color: Color.success))

                        // Botón para cancelar edición
                        Button {
                            isEditMode = false
                            filterToEdit = nil
                            HapticManager.shared.selection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                Text("Cancelar")
                            }
                            .font(.caption.weight(.bold))
                        }
                        .buttonStyle(BotonSecundarioClarity(color: Color.error))
                    } else if filter.hasActiveFilters {
                        // Modo normal - Guardar nuevo
                        Button {
                            showSavePresetAlert = true
                            HapticManager.shared.selection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Guardar nuevo")
                            }
                            .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.secundarioClarity)
                    }

                    let saved = savedPresets

                    if saved.isEmpty {
                        // Empty State - Always show if no saved filters
                        HStack {
                            Text("No hay filtros guardados")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    } else {
                        ForEach(saved) { preset in
                            presetChip(preset)
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 12)
            .glassCard(cornerRadius: CornerRadius.large)
        }
    }

    private var dateRangeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Período")
                .estiloEtiquetaClarity()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([ExpenseFilter.DateRange.thisMonth, .lastMonth, .thisYear, .allTime], id: \.self) { range in
                        dateChip(range)
                    }
                    // Custom trigger
                    Button {
                        filter.dateRange = .custom
                    } label: {
                        Text("Custom")
                            .font(.subheadline)
                            .modifier(ChipFiltro(seleccionado: filter.dateRange == .custom))
                    }
                }
            }

            if filter.dateRange == .custom {
                HStack {
                    DatePicker("", selection: $filter.customStartDate, displayedComponents: .date)
                    Text("-")
                        .foregroundStyle(Color.textSecondary)
                    DatePicker("", selection: $filter.customEndDate, displayedComponents: .date)
                }
                .labelsHidden()
                .tint(Color.clarityPrimary)
            }
        }
    }

    private var amountRangeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rango de Importe")
                .estiloEtiquetaClarity()

            HStack {
                TextField("Min", text: $minAmountText)
                    .keyboardType(.numberPad)
                    .monospacedDigit()
                    .padding(10)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .onChange(of: minAmountText) { _, val in filter.minAmount = Double(val) }

                Text("-")
                    .foregroundStyle(Color.textSecondary)

                TextField("Max", text: $maxAmountText)
                    .keyboardType(.numberPad)
                    .monospacedDigit()
                    .padding(10)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .onChange(of: maxAmountText) { _, val in filter.maxAmount = Double(val) }
            }
        }
    }

    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Categorías")
                    .estiloEtiquetaClarity()
                Spacer()
                Button(filter.selectedCategories.count == availableCategories.count ? "Ninguna" : "Todas") {
                    HapticManager.shared.selection()
                    if filter.selectedCategories.count == availableCategories.count {
                        filter.selectedCategories.removeAll()
                    } else {
                        filter.selectedCategories = Set(availableCategories)
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.clarityPrimary)
            }
            
            // Sort categories to prevent jumping
            let sortedCategories = availableCategories.sorted()
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(sortedCategories, id: \.self) { category in
                    categoryChip(category)
                }
            }
        }
    }
    
    private var paymentMethodSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Métodos de Pago")
                .estiloEtiquetaClarity()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availablePaymentMethods, id: \.self) { method in
                        paymentMethodChip(method)
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    /// Cabecera en mayúsculas pequeñas fuera y el contenido en una tarjeta de
    /// vidrio, como las secciones de la Home y de Recurrentes.
    private func seccion<Contenido: View>(_ titulo: String, @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            CabeceraSeccionClarity(titulo: titulo)
            contenido()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .glassCard(cornerRadius: CornerRadius.large)
        }
    }
    
    private func dateChip(_ range: ExpenseFilter.DateRange) -> some View {
        Button {
            filter.dateRange = range
            HapticManager.shared.selection()
        } label: {
            Text(range.rawValue)
                .font(.subheadline)
                .modifier(ChipFiltro(seleccionado: filter.dateRange == range))
        }
    }
    
    private func categoryChip(_ category: String) -> some View {
        let isSelected = filter.selectedCategories.contains(category)
        return Button {
            if isSelected { filter.selectedCategories.remove(category) }
            else { filter.selectedCategories.insert(category) }
            HapticManager.shared.selection()
        } label: {
            Text(category)
                .font(.caption)
                .lineLimit(1)
                .modifier(ChipFiltro(seleccionado: isSelected, horizontal: 10))
        }
    }
    
    private func paymentMethodChip(_ method: String) -> some View {
        let isSelected = filter.selectedPaymentMethods.contains(method)
        return Button {
            if isSelected { filter.selectedPaymentMethods.remove(method) }
            else { filter.selectedPaymentMethods.insert(method) }
            HapticManager.shared.selection()
        } label: {
            Text(method)
                .font(.caption)
                .modifier(ChipFiltro(seleccionado: isSelected, horizontal: 10))
        }
    }
    
    private func presetChip(_ preset: ExpenseFilter) -> some View {
        let isSavedDefault = UserDataManager.shared.defaultFilter?.id == preset.id
        // We compare everything EXCEPT the ID to check if it's "logically" the same filter,
        // or just rely on full equality if IDs are consistent.
        // Since `filter = preset` copies the ID, full equality works.
        let isActive = filter == preset
        
        return Button {
            filter = preset
            HapticManager.shared.selection()
            onApply()
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Text(preset.name ?? "Filtro")
                if isSavedDefault {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.warning)
                }
            }
            .font(.caption.weight(.medium))
            .padding(.vertical, 2)
            .modifier(ChipFiltro(seleccionado: isActive))
        }
        .contextMenu {
            Button {
                // Cargar el filtro para editarlo
                filter = preset
                filterToEdit = preset
                isEditMode = true
                newPresetName = preset.name ?? ""
                HapticManager.shared.selection()
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            
            Button {
                // El haptic era incondicional: sonaba a éxito aunque no se
                // hubiera guardado nada.
                let guardado = UserDataManager.shared.saveDefaultFilter(preset)
                HapticManager.shared.notification(guardado ? .success : .error)
            } label: {
                Label(isSavedDefault ? "Predeterminado" : "Marcar como predeterminado", systemImage: "star")
            }
            .disabled(isSavedDefault)
            
            Divider()
            
            Button(role: .destructive) {
                Task { await UserDataManager.shared.deleteFilter(preset) }
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Logic
    
    private func applyFilters() {
        onApply()
        dismiss()
    }
    
    private func resetFilters() {
        filter = ExpenseFilter()
        minAmountText = ""
        maxAmountText = ""
    }
    
    private func saveCurrentAsPreset() {
        guard !newPresetName.isEmpty else { return }
        Task {
            await UserDataManager.shared.saveFilter(filter, name: newPresetName)
            await MainActor.run {
                newPresetName = ""
                HapticManager.shared.notification(.success)
            }
        }
    }
    
    private func updateExistingFilter() async {
        guard let filterToEdit = filterToEdit else {
            return
        }

        var updatedFilter = filter
        updatedFilter.id = filterToEdit.id  // Mantener el mismo ID
        updatedFilter.name = newPresetName.isEmpty ? filterToEdit.name : newPresetName
        
        await UserDataManager.shared.updateFilter(updatedFilter)
        
        // IMPORTANTE: Recargar data para reflejar cambios
        await UserDataManager.shared.loadUserData()
        
        await MainActor.run {
            HapticManager.shared.notification(.success)
            isEditMode = false
            self.filterToEdit = nil
            newPresetName = ""
        }
    }
}

// MARK: - Chip

/// Chip seleccionable de los filtros: morado de marca y texto blanco si está
/// elegido; si no, un velo del color del texto que se lee sobre el vidrio en
/// claro y en oscuro, cosa que los grises de sistema no hacían.
private struct ChipFiltro: ViewModifier {
    let seleccionado: Bool
    var horizontal: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontal)
            .padding(.vertical, 6)
            .foregroundStyle(seleccionado ? Color.white : Color.primary)
            .background(seleccionado ? Color.clarityPrimary : Color.primary.opacity(0.08), in: Capsule())
    }
}

// MARK: - Preview
#Preview {
    ExpenseFilterSheet(
        filter: .constant(ExpenseFilter()),
        availableCategories: ["Comida 🍔", "Transporte 🚌", "Casa 🏠"]
    ) {}
}
