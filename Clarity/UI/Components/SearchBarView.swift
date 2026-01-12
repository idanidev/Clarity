// SearchBarView.swift
// Search bar with native iOS filter menu

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var filter: ExpenseFilter
    let onFilterChange: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Search Field
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                
                TextField("Buscar gastos...", text: $searchText)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(Color(hex: "#0A0A0A")!) // Darker OLED background
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1) // Subtle border definition
            )
            
            // Native iOS Filter Menu
            Menu {
                // Quick period filters
                Section("Período") {
                    ForEach(ExpenseFilter.DateRange.allCases, id: \.self) { range in
                        Button {
                            filter.dateRange = range
                            onFilterChange()
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                if filter.dateRange == range {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                // Quick payment method filters
                Section("Método de Pago") {
                    ForEach(["Tarjeta", "Efectivo", "Bizum", "Transferencia"], id: \.self) { method in
                        Button {
                            if filter.selectedPaymentMethods.contains(method) {
                                filter.selectedPaymentMethods.remove(method)
                            } else {
                                filter.selectedPaymentMethods.insert(method)
                            }
                            onFilterChange()
                        } label: {
                            HStack {
                                Text(method)
                                if filter.selectedPaymentMethods.contains(method) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                // Clear filters
                if filter.hasActiveFilters {
                    Divider()
                    
                    Button(role: .destructive) {
                        filter = ExpenseFilter()
                        onFilterChange()
                    } label: {
                        Label("Limpiar filtros", systemImage: "xmark.circle")
                    }
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 18))
                        .foregroundColor(filter.hasActiveFilters ? Color.clarityPrimary : .gray)
                        .padding(10)
                        .background(filter.hasActiveFilters ? Color.clarityPrimary.opacity(0.15) : Color.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    if filter.hasActiveFilters {
                        Circle()
                            .fill(Color.clarityPrimary)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }
    }
}

// MARK: - Active Filter Pills
struct ActiveFilterPillsView: View {
    @Binding var filter: ExpenseFilter
    let onFilterChange: () -> Void
    
    var body: some View {
        if filter.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    // Date range pill
                    if filter.dateRange != .thisMonth {
                        FilterPill(
                            text: filter.dateRange.rawValue,
                            onRemove: {
                                filter.dateRange = .thisMonth
                                onFilterChange()
                            }
                        )
                    }
                    
                    // Payment method pills
                    ForEach(Array(filter.selectedPaymentMethods), id: \.self) { method in
                        FilterPill(
                            text: method,
                            onRemove: {
                                filter.selectedPaymentMethods.remove(method)
                                onFilterChange()
                            }
                        )
                    }
                    
                    // Category pills
                    ForEach(Array(filter.selectedCategories), id: \.self) { category in
                        FilterPill(
                            text: category.components(separatedBy: " ").first ?? category,
                            onRemove: {
                                filter.selectedCategories.remove(category)
                                onFilterChange()
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }

            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4) // Reduced padding
        }
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(Color(hex: "#0A0A0A")!) // Dark OLED
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        
        VStack {
            SearchBarView(
                searchText: .constant(""),
                filter: .constant(ExpenseFilter(dateRange: .lastMonth)),
                onFilterChange: {}
            )
            .padding(.horizontal)
            
            ActiveFilterPillsView(
                filter: .constant(ExpenseFilter(
                    selectedPaymentMethods: ["Tarjeta", "Bizum"],
                    dateRange: .last3Months
                )),
                onFilterChange: {}
            )
        }
    }
    .preferredColorScheme(.dark)
}
