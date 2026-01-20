// ExpenseFilterSheet.swift
// Advanced filter sheet for expenses with quick actions and comprehensive filters

import SwiftUI

// MARK: - Filter Model
// ExpenseFilter struct moved to Domain/Models/ExpenseFilter.swift

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
    
    private var presetManager: FilterPresetManager { FilterPresetManager.shared }
    
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
                VStack(spacing: 20) {
                    // Saved Presets
                    savedPresetsSection
                    
                    // Date Range
                    dateRangeSection
                    
                    // Amount Range
                    amountRangeSection
                    
                    // Categories
                    if !availableCategories.isEmpty {
                        categoriesSection
                    }
                    
                    // Payment Methods
                    paymentMethodsSection
                    
                    // Sort Options
                    sortSection
                    
                    // Additional Options
                    additionalOptionsSection
                    
                    // Clear All Button
                    if filter.hasActiveFilters {
                        clearAllButton
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                quickActionsSection
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { applyFilters() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Guardar Preset", isPresented: $showSavePresetAlert) {
                TextField("Nombre del preset", text: $newPresetName)
                Button("Cancelar", role: .cancel) { newPresetName = "" }
                Button("Guardar") {
                    saveCurrentAsPreset()
                }
            } message: {
                Text("Dale un nombre a este filtro para acceder rápidamente")
            }
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Acciones Rápidas", icon: "bolt.fill")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                quickActionChip(
                    title: "Este mes",
                    icon: "calendar",
                    isActive: filter.dateRange == .thisMonth,
                    action: { 
                        filter.dateRange = .thisMonth
                        applyFilters()
                    }
                )
                
                quickActionChip(
                    title: "Mes pasado",
                    icon: "calendar.badge.clock",
                    isActive: filter.dateRange == .lastMonth,
                    action: { 
                        filter.dateRange = .lastMonth
                        applyFilters()
                    }
                )
                
                quickActionChip(
                    title: "Limpiar filtros",
                    icon: "xmark.circle.fill",
                    isActive: false,
                    isDestructive: true,
                    action: { 
                        resetFilters()
                        applyFilters()
                        HapticManager.shared.notification(.success)
                    }
                )
            }
            
            Divider()
            
            saveAsDefaultButton
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .shadow(color: .black.opacity(0.1), radius: 5, y: -5)
    }
    
    @State private var didSaveDefault = false
    
    private var saveAsDefaultButton: some View {
        Button {
            UserDataManager.shared.saveDefaultFilter(filter)
            withAnimation(.bouncy) {
                didSaveDefault = true
            }
            HapticManager.shared.notification(.success)
            
            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    didSaveDefault = false
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: didSaveDefault ? "checkmark.circle.fill" : "star.fill")
                    .foregroundStyle(didSaveDefault ? .green : Color.clarityPrimary)
                Text(didSaveDefault ? "¡Guardado como predeterminado!" : "Guardar como filtro por defecto")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(didSaveDefault ? .green : Color.clarityPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(didSaveDefault ? Color.green.opacity(0.15) : Color.clarityPrimary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(didSaveDefault ? Color.green.opacity(0.3) : Color.clarityPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(didSaveDefault)
    }
    
    // MARK: - Date Range Section
    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "📅 Período", icon: "calendar")
            
            // Popular options as chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([ExpenseFilter.DateRange.today, .yesterday, .thisWeek, .thisMonth, .lastMonth, .last3Months], id: \.self) { range in
                        dateChip(range)
                    }
                }
            }
            
            // All options dropdown
            DisclosureGroup("Más opciones de fecha") {
                VStack(spacing: 0) {
                    ForEach(ExpenseFilter.DateRange.allCases, id: \.self) { range in
                        Button {
                            filter.dateRange = range
                            HapticManager.shared.selection()
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if filter.dateRange == range {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.clarityPrimary)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        
                        if range != ExpenseFilter.DateRange.allCases.last {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            }
            .tint(.secondary)
            
            // Custom date pickers
            if filter.dateRange == .custom {
                VStack(spacing: 12) {
                    DatePicker("Desde", selection: $filter.customStartDate, displayedComponents: .date)
                        .tint(Color.clarityPrimary)
                    DatePicker("Hasta", selection: $filter.customEndDate, displayedComponents: .date)
                        .tint(Color.clarityPrimary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Amount Range Section
    private var amountRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "💰 Rango de Importe", icon: "eurosign.circle.fill")
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mínimo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("0", text: $minAmountText)
                            .keyboardType(.decimalPad)
                            .onChange(of: minAmountText) { _, newValue in
                                filter.minAmount = Double(newValue)
                            }
                        Text("€")
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Máximo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("∞", text: $maxAmountText)
                            .keyboardType(.decimalPad)
                            .onChange(of: maxAmountText) { _, newValue in
                                filter.maxAmount = Double(newValue)
                            }
                        Text("€")
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            // Preset buttons
            HStack(spacing: 8) {
                presetAmountButton("<10€", min: nil, max: 10)
                presetAmountButton("10-50€", min: 10, max: 50)
                presetAmountButton("50-100€", min: 50, max: 100)
                presetAmountButton(">100€", min: 100, max: nil)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "📁 Categorías", icon: "folder.fill")
                Spacer()
                Button(filter.selectedCategories.isEmpty ? "Todas" : "Ninguna") {
                    if filter.selectedCategories.isEmpty {
                        filter.selectedCategories = Set(availableCategories)
                    } else {
                        filter.selectedCategories.removeAll()
                    }
                    HapticManager.shared.selection()
                }
                .font(.caption)
                .foregroundStyle(Color.clarityPrimary)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(availableCategories, id: \.self) { category in
                    categoryChip(category)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Payment Methods Section
    private var paymentMethodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "💳 Método de Pago", icon: "creditcard.fill")
            
            HStack(spacing: 8) {
                ForEach(availablePaymentMethods, id: \.self) { method in
                    paymentMethodChip(method)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Sort Section
    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "↕️ Ordenar por", icon: "arrow.up.arrow.down")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ExpenseFilter.SortOption.allCases, id: \.self) { option in
                    sortChip(option)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Additional Options Section
    private var additionalOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "⚙️ Opciones", icon: "gearshape.fill")
            
            Toggle(isOn: $filter.showOnlyRecurring) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Color.clarityPrimary)
                    Text("Solo gastos recurrentes")
                }
            }
            .tint(Color.clarityPrimary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Clear All Button
    private var clearAllButton: some View {
        Button {
            resetFilters()
            HapticManager.shared.notification(.warning)
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("Limpiar todos los filtros")
            }
            .font(.headline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.clarityPrimary)
            Text(title)
                .font(.headline)
        }
    }
    
    private func quickActionChip(title: String, icon: String, isActive: Bool, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticManager.shared.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isActive ? Color.clarityPrimary :
                isDestructive ? Color.red.opacity(0.15) :
                Color(.tertiarySystemGroupedBackground)
            )
            .foregroundStyle(
                isActive ? .white :
                isDestructive ? .red :
                .primary
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func dateChip(_ range: ExpenseFilter.DateRange) -> some View {
        Button {
            filter.dateRange = range
            HapticManager.shared.selection()
        } label: {
            Text(range.rawValue)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(filter.dateRange == range ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(filter.dateRange == range ? .white : .primary)
                .clipShape(Capsule())
        }
    }
    
    private func categoryChip(_ category: String) -> some View {
        let isSelected = filter.selectedCategories.contains(category)
        
        return Button {
            if isSelected {
                filter.selectedCategories.remove(category)
            } else {
                filter.selectedCategories.insert(category)
            }
            HapticManager.shared.selection()
        } label: {
            Text(category)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
    
    private func paymentMethodChip(_ method: String) -> some View {
        let isSelected = filter.selectedPaymentMethods.contains(method)
        let icon = paymentMethodIcon(method)
        
        return Button {
            if isSelected {
                filter.selectedPaymentMethods.remove(method)
            } else {
                filter.selectedPaymentMethods.insert(method)
            }
            HapticManager.shared.selection()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(method)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func paymentMethodIcon(_ method: String) -> String {
        switch method {
        case "Tarjeta": return "creditcard.fill"
        case "Efectivo": return "banknote.fill"
        case "Bizum": return "iphone.gen3"
        case "Transferencia": return "arrow.left.arrow.right"
        default: return "questionmark.circle"
        }
    }
    
    private func sortChip(_ option: ExpenseFilter.SortOption) -> some View {
        Button {
            filter.sortBy = option
            HapticManager.shared.selection()
        } label: {
            HStack {
                Text(option.rawValue)
                    .font(.subheadline)
                Spacer()
                if filter.sortBy == option {
                    Image(systemName: "checkmark")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(filter.sortBy == option ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(filter.sortBy == option ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func presetAmountButton(_ title: String, min: Double?, max: Double?) -> some View {
        let isActive = filter.minAmount == min && filter.maxAmount == max
        
        return Button {
            filter.minAmount = min
            filter.maxAmount = max
            minAmountText = min.map { String(Int($0)) } ?? ""
            maxAmountText = max.map { String(Int($0)) } ?? ""
            HapticManager.shared.selection()
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Actions
    
    private func applyFilters() {
        onApply()
        HapticManager.shared.notification(.success)
        dismiss()
    }
    
    private func resetFilters() {
        filter = ExpenseFilter()
        minAmountText = ""
        maxAmountText = ""
        // Not applying automatically on reset to allow user to review
    }
    
    // MARK: - Saved Presets Section
    private var savedPresetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "Presets Guardados", icon: "star.fill")
                Spacer()
                // Save current filter as preset
                if filter.hasActiveFilters {
                    Button {
                        showSavePresetAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Guardar")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.clarityPrimary)
                    }
                }
            }
            
            if presetManager.presets.isEmpty {
                Text("No tienes presets guardados")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(presetManager.presets) { preset in
                            presetChip(preset)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func presetChip(_ preset: FilterPreset) -> some View {
        Button {
            filter = preset.filter
            HapticManager.shared.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 12))
                Text(preset.name)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(preset.colorValue)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(preset.colorValue.opacity(0.15))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(preset.colorValue.opacity(0.3), lineWidth: 1)
            )
        }
        .contextMenu {
            Button(role: .destructive) {
                presetManager.deletePreset(preset)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
    
    private func saveCurrentAsPreset() {
        guard !newPresetName.isEmpty else { return }
        let preset = FilterPreset(
            name: newPresetName,
            filter: filter
        )
        presetManager.savePreset(preset)
        newPresetName = ""
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Alias for backwards compatibility
typealias FilterSheet = ExpenseFilterSheet

#Preview {
    ExpenseFilterSheet(
        filter: .constant(ExpenseFilter()),
        availableCategories: ["Alimentación 🥗", "Ocio 🍻", "Compras 🛒", "Transporte 🚗", "Suscripciones 📱"]
    ) {}
    .preferredColorScheme(.dark)
}
