// ExpenseFilterSheet.swift
// Filter sheet for expenses with category, date range, and payment method filters

import SwiftUI

// MARK: - Filter Model
struct ExpenseFilter: Equatable {
    var selectedCategories: Set<String> = []
    var selectedPaymentMethods: Set<String> = []
    var dateRange: DateRange = .thisMonth
    var customStartDate: Date = Date()
    var customEndDate: Date = Date()
    
    enum DateRange: String, CaseIterable {
        case thisMonth = "Este mes"
        case lastMonth = "Mes anterior"
        case last3Months = "Últimos 3 meses"
        case last6Months = "Últimos 6 meses"
        case thisYear = "Este año"
        case custom = "Personalizado"
    }
    
    var hasActiveFilters: Bool {
        !selectedCategories.isEmpty || 
        !selectedPaymentMethods.isEmpty || 
        dateRange != .thisMonth
    }
    
    func dateRangeForQuery() -> (start: String, end: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let now = Date()
        
        switch dateRange {
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (formatter.string(from: start), formatter.string(from: end))
            
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (formatter.string(from: start), formatter.string(from: end))
            
        case .last3Months:
            let end = now
            let start = calendar.date(byAdding: .month, value: -3, to: now)!
            return (formatter.string(from: start), formatter.string(from: end))
            
        case .last6Months:
            let end = now
            let start = calendar.date(byAdding: .month, value: -6, to: now)!
            return (formatter.string(from: start), formatter.string(from: end))
            
        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (formatter.string(from: start), formatter.string(from: now))
            
        case .custom:
            return (formatter.string(from: customStartDate), formatter.string(from: customEndDate))
        }
    }
}

// MARK: - Filter Sheet View
struct ExpenseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ExpenseFilter
    let availableCategories: [String]  // Dynamic from user's expenses
    let availablePaymentMethods: [String]  // Dynamic from user's expenses
    let onApply: () -> Void
    
    init(
        filter: Binding<ExpenseFilter>,
        availableCategories: [String] = [],
        availablePaymentMethods: [String] = ["Tarjeta", "Efectivo", "Transferencia", "Bizum"],
        onApply: @escaping () -> Void
    ) {
        self._filter = filter
        self.availableCategories = availableCategories.isEmpty ? [] : availableCategories
        self.availablePaymentMethods = availablePaymentMethods
        self.onApply = onApply
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Date Range Section
                Section("Período") {
                    ForEach(ExpenseFilter.DateRange.allCases, id: \.self) { range in
                        Button {
                            filter.dateRange = range
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                    .foregroundColor(.white)
                                Spacer()
                                if filter.dateRange == range {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.clarityPrimary)
                                }
                            }
                        }
                    }
                    
                    // Custom date pickers
                    if filter.dateRange == .custom {
                        DatePicker("Desde", selection: $filter.customStartDate, displayedComponents: .date)
                            .tint(Color.clarityPrimary)
                        DatePicker("Hasta", selection: $filter.customEndDate, displayedComponents: .date)
                            .tint(Color.clarityPrimary)
                    }
                }
                
                // Categories Section (only show if user has categories)
                if !availableCategories.isEmpty {
                    Section("Categorías") {
                        Button {
                            if filter.selectedCategories.isEmpty {
                                filter.selectedCategories = Set(availableCategories)
                            } else {
                                filter.selectedCategories.removeAll()
                            }
                        } label: {
                            HStack {
                                Text(filter.selectedCategories.isEmpty ? "Seleccionar todas" : "Quitar todas")
                                    .foregroundColor(Color.clarityPrimary)
                            }
                        }
                        
                        ForEach(availableCategories, id: \.self) { category in
                            Button {
                                if filter.selectedCategories.contains(category) {
                                    filter.selectedCategories.remove(category)
                                } else {
                                    filter.selectedCategories.insert(category)
                                }
                            } label: {
                                HStack {
                                    Text(category)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if filter.selectedCategories.contains(category) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.clarityPrimary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Payment Methods Section
                Section("Método de Pago") {
                    ForEach(availablePaymentMethods, id: \.self) { method in
                        Button {
                            if filter.selectedPaymentMethods.contains(method) {
                                filter.selectedPaymentMethods.remove(method)
                            } else {
                                filter.selectedPaymentMethods.insert(method)
                            }
                        } label: {
                            HStack {
                                Text(method)
                                    .foregroundColor(.white)
                                Spacer()
                                if filter.selectedPaymentMethods.contains(method) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.clarityPrimary)
                                }
                            }
                        }
                    }
                }
                
                // Clear Filters
                if filter.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            filter = ExpenseFilter()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Limpiar todos los filtros")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ExpenseFilterSheet(
        filter: .constant(ExpenseFilter()),
        availableCategories: ["Alimentación 🥗", "Ocio 🍻", "Compras 🛒"]
    ) {}
    .preferredColorScheme(.dark)
}
