// ExpenseFilterSheet.swift
// Advanced filter sheet for expenses with quick actions and comprehensive filters

import SwiftUI

// MARK: - Filter Model
struct ExpenseFilter: Equatable {
    var selectedCategories: Set<String> = []
    var selectedPaymentMethods: Set<String> = []
    var dateRange: DateRange = .thisMonth
    var customStartDate: Date = Date()
    var customEndDate: Date = Date()
    var minAmount: Double? = nil
    var maxAmount: Double? = nil
    var sortBy: SortOption = .dateDesc
    var showOnlyRecurring: Bool = false
    
    enum DateRange: String, CaseIterable {
        case allTime = "Todos"
        case today = "Hoy"
        case yesterday = "Ayer"
        case thisWeek = "Esta semana"
        case lastWeek = "Semana pasada"
        case thisMonth = "Este mes"
        case lastMonth = "Mes anterior"
        case last3Months = "Últimos 3 meses"
        case last6Months = "Últimos 6 meses"
        case last12Months = "Últimos 12 meses"
        case thisYear = "Este año"
        case lastYear = "Año pasado"
        case custom = "Personalizado"
    }
    
    enum SortOption: String, CaseIterable {
        case dateDesc = "Más recientes"
        case dateAsc = "Más antiguos"
        case amountDesc = "Mayor importe"
        case amountAsc = "Menor importe"
        case nameAsc = "A-Z"
        case nameDesc = "Z-A"
    }
    
    var hasActiveFilters: Bool {
        !selectedCategories.isEmpty || 
        !selectedPaymentMethods.isEmpty || 
        dateRange != .thisMonth ||
        minAmount != nil ||
        maxAmount != nil ||
        showOnlyRecurring ||
        sortBy != .dateDesc
    }
    
    var activeFilterCount: Int {
        var count = 0
        if !selectedCategories.isEmpty { count += 1 }
        if !selectedPaymentMethods.isEmpty { count += 1 }
        if dateRange != .thisMonth { count += 1 }
        if minAmount != nil || maxAmount != nil { count += 1 }
        if showOnlyRecurring { count += 1 }
        if sortBy != .dateDesc { count += 1 }
        return count
    }
    
    /// Returns date range as String tuple for filtering expenses
    func dateRangeForQuery() -> (start: String, end: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let now = Date()
        
        let (startDate, endDate): (Date, Date) = {
            switch dateRange {
            case .allTime:
                let start = calendar.date(byAdding: .year, value: -10, to: now)!
                return (start, now)
                
            case .today:
                let start = calendar.startOfDay(for: now)
                return (start, now)
                
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
                let start = calendar.startOfDay(for: yesterday)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                return (start, end)
                
            case .thisWeek:
                let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                return (start, now)
                
            case .lastWeek:
                let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                let start = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
                return (start, thisWeekStart)
                
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
                return (start, end)
                
            case .lastMonth:
                let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
                return (start, thisMonthStart)
                
            case .last3Months:
                let start = calendar.date(byAdding: .month, value: -3, to: now)!
                return (start, now)
                
            case .last6Months:
                let start = calendar.date(byAdding: .month, value: -6, to: now)!
                return (start, now)
                
            case .last12Months:
                let start = calendar.date(byAdding: .month, value: -12, to: now)!
                return (start, now)
                
            case .thisYear:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return (start, now)
                
            case .lastYear:
                let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
                let start = calendar.date(byAdding: .year, value: -1, to: thisYearStart)!
                return (start, thisYearStart)
                
            case .custom:
                return (customStartDate, customEndDate)
            }
        }()
        
        return (formatter.string(from: startDate), formatter.string(from: endDate))
    }
}

// MARK: - Filter Sheet View
struct ExpenseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ExpenseFilter
    let availableCategories: [String]
    let availablePaymentMethods: [String]
    let onApply: () -> Void
    
    @State private var minAmountText: String = ""
    @State private var maxAmountText: String = ""
    
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
                    title: "Solo tarjeta",
                    icon: "creditcard.fill",
                    isActive: filter.selectedPaymentMethods == ["Tarjeta"],
                    action: {
                        if filter.selectedPaymentMethods == ["Tarjeta"] {
                            filter.selectedPaymentMethods = []
                        } else {
                            filter.selectedPaymentMethods = ["Tarjeta"]
                        }
                        applyFilters()
                    }
                )
                
                quickActionChip(
                    title: "Solo efectivo",
                    icon: "banknote.fill",
                    isActive: filter.selectedPaymentMethods == ["Efectivo"],
                    action: {
                        if filter.selectedPaymentMethods == ["Efectivo"] {
                            filter.selectedPaymentMethods = []
                        } else {
                            filter.selectedPaymentMethods = ["Efectivo"]
                        }
                        applyFilters()
                    }
                )
                
                quickActionChip(
                    title: "Gastos grandes",
                    icon: "arrow.up.circle.fill",
                    isActive: filter.minAmount == 50,
                    action: {
                        if filter.minAmount == 50 {
                            filter.minAmount = nil
                            minAmountText = ""
                        } else {
                            filter.minAmount = 50
                            minAmountText = "50"
                        }
                        applyFilters()
                    }
                )
                
                quickActionChip(
                    title: "Gastos pequeños",
                    icon: "arrow.down.circle.fill",
                    isActive: filter.maxAmount == 20,
                    action: {
                        if filter.maxAmount == 20 {
                            filter.maxAmount = nil
                            maxAmountText = ""
                        } else {
                            filter.maxAmount = 20
                            maxAmountText = "20"
                        }
                        applyFilters()
                    }
                )
                
                quickActionChip(
                    title: "Recurrentes",
                    icon: "arrow.triangle.2.circlepath",
                    isActive: filter.showOnlyRecurring,
                    action: { 
                        filter.showOnlyRecurring.toggle()
                        applyFilters()
                    }
                )
                
                quickActionChip(
                    title: "Limpiar todo",
                    icon: "xmark.circle.fill",
                    isActive: false,
                    isDestructive: true,
                    action: { 
                        resetFilters() 
                        // Intentionally keeping open on reset as per previous thought
                    }
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .shadow(color: .black.opacity(0.1), radius: 5, y: -5)
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
                            HapticManager.selection()
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
                    HapticManager.selection()
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
            HapticManager.notification(.warning)
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
            HapticManager.selection()
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
            HapticManager.selection()
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
            HapticManager.selection()
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
            HapticManager.selection()
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
            HapticManager.selection()
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
            HapticManager.selection()
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
        HapticManager.notification(.success)
        dismiss()
    }
    
    private func resetFilters() {
        filter = ExpenseFilter()
        minAmountText = ""
        maxAmountText = ""
        // Not applying automatically on reset to allow user to review
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
