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
                VStack(spacing: 16) {
                    // 1. Saved Presets (Top Bar)
                    presetsSection
                    
                    // 2. Main Criteria (Date & Amount)
                    VStack(spacing: 0) {
                        sectionHeader("Cuándo y Cuánto", icon: "calendar.badge.clock")
                            .padding()
                        
                        Divider()
                        
                        VStack(spacing: 20) {
                            dateRangeSelector
                            amountRangeSelector
                        }
                        .padding()
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // 3. Details (Category & Payment)
                    VStack(spacing: 0) {
                        sectionHeader("Detalles", icon: "tag.fill")
                            .padding()
                        
                        Divider()
                        
                        VStack(spacing: 20) {
                            if !availableCategories.isEmpty {
                                categorySelector
                            }
                            paymentMethodSelector
                        }
                        .padding()
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // 4. Options & Sort (Compact)
                    VStack(spacing: 0) {
                        sectionHeader("Opciones", icon: "slider.horizontal.3")
                            .padding()
                        
                        Divider()
                        
                        VStack(spacing: 16) {
                            Toggle("Solo recurrentes", isOn: $filter.showOnlyRecurring)
                                .tint(Color.clarityPrimary)
                            
                            Divider()
                            
                            HStack {
                                Text("Ordenar por")
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
                                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Clear All (Text Link)
                    if filter.hasActiveFilters {
                        Button("Limpiar todos los filtros") {
                            resetFilters()
                            HapticManager.shared.notification(.warning)
                        }
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding(.top, 8)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { applyFilters() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.clarityPrimary)
                }
            }
            .alert("Guardar Filtro", isPresented: $showSavePresetAlert) {
                TextField("Nombre del filtro", text: $newPresetName)
                Button("Cancelar", role: .cancel) { newPresetName = "" }
                Button("Guardar") {
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
            }
        }
    }
    
    // MARK: - Sections
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Mis Filtros", icon: "bookmark.fill")
                .padding()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Save Button (Always visible if active filters)
                    if filter.hasActiveFilters {
                        Button {
                            showSavePresetAlert = true
                            HapticManager.shared.selection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Guardar nuevo")
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.clarityPrimary.opacity(0.1))
                            .foregroundStyle(Color.clarityPrimary)
                            .clipShape(Capsule())
                        }
                    }
                    
                    let saved = UserDataManager.shared.savedFilters
                    
                    if saved.isEmpty {
                        // Empty State - Always show if no saved filters
                        HStack {
                            Text("No hay filtros guardados")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
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
                .padding(.horizontal)
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal)
        }
        .background(Color(.secondarySystemGroupedBackground)) // Visual separation like other cards
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var dateRangeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Período")
                .font(.caption)
                .foregroundStyle(.secondary)
            
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(filter.dateRange == .custom ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(filter.dateRange == .custom ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            
            if filter.dateRange == .custom {
                HStack {
                    DatePicker("", selection: $filter.customStartDate, displayedComponents: .date)
                    Text("-")
                    DatePicker("", selection: $filter.customEndDate, displayedComponents: .date)
                }
                .labelsHidden()
            }
        }
    }
    
    private var amountRangeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rango de Importe")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                TextField("Min", text: $minAmountText)
                    .keyboardType(.numberPad)
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: minAmountText) { _, val in filter.minAmount = Double(val) }
                
                Text("-")
                
                TextField("Max", text: $maxAmountText)
                    .keyboardType(.numberPad)
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: maxAmountText) { _, val in filter.maxAmount = Double(val) }
            }
        }
    }
    
    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Categorías")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .font(.caption)
                .foregroundStyle(.secondary)
            
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
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.clarityPrimary)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
    
    private func dateChip(_ range: ExpenseFilter.DateRange) -> some View {
        Button {
            filter.dateRange = range
            HapticManager.shared.selection()
        } label: {
            Text(range.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(filter.dateRange == range ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(filter.dateRange == range ? .white : .primary)
                .clipShape(Capsule())
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.clarityPrimary : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
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
                        .foregroundStyle(Color.yellow)
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.clarityPrimary.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(isActive ? Color.clarityPrimary : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.clarityPrimary : Color.clear, lineWidth: 1)
            )
        }
        .contextMenu {
            Button {
                Task {
                    UserDataManager.shared.saveDefaultFilter(preset)
                    await MainActor.run { HapticManager.shared.notification(.success) }
                }
            } label: {
                Label("Marcar como predeterminado", systemImage: "star")
            }
            
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
}

// MARK: - Preview
#Preview {
    ExpenseFilterSheet(
        filter: .constant(ExpenseFilter()),
        availableCategories: ["Comida 🍔", "Transporte 🚌", "Casa 🏠"]
    ) {}
}
