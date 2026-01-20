// SearchBarView.swift
// Barra de búsqueda moderna con efectors glassmórficos
// Diseño prominente inspirado en SkillsMP

import SwiftUI

/// Barra de búsqueda moderna y prominente
struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var filter: ExpenseFilter
    let onFilterChange: () -> Void
    
    @State private var isSearchFocused = false
    
    var body: some View {
        // Campo de búsqueda principal - solo búsqueda, sin botón de filtros (ya está abajo)
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icono de búsqueda con animación
            Image(systemName: isSearchFocused || !searchText.isEmpty ? "magnifyingglass.circle.fill" : "magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    isSearchFocused || !searchText.isEmpty 
                        ? DesignTokens.Colors.primary.gradient 
                        : DesignTokens.Colors.textSecondary.gradient
                )
                .symbolEffect(.bounce, value: isSearchFocused)
            
            // TextField con placeholder mejorado
            TextField("", text: $searchText, prompt: Text("Buscar gastos...").foregroundStyle(DesignTokens.Colors.textSecondary))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .font(.system(size: 16, weight: .medium))
                .textFieldStyle(.plain)
                .onSubmit {
                    HapticManager.shared.selection()
                }
            
            // Botón de limpiar con animación
            if !searchText.isEmpty {
                Button {
                    withAnimation(.bouncy) {
                        searchText = ""
                    }
                    HapticManager.shared.selection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 14)
        .background {
            ZStack {
                // Fondo base visible
                Color(.secondarySystemBackground)

                // Gradiente sutil si está activo
                if isSearchFocused {
                    DesignTokens.Colors.primary.opacity(0.08)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(
                    isSearchFocused 
                        ? DesignTokens.Colors.primary.opacity(0.4)
                        : DesignTokens.Colors.textPrimary.opacity(0.1),
                    lineWidth: isSearchFocused ? 1.5 : 1
                )
        )
        .shadow(
            color: isSearchFocused ? DesignTokens.Colors.primary.opacity(0.1) : .black.opacity(0.05),
            radius: isSearchFocused ? 12 : 8,
            y: isSearchFocused ? 4 : 2
        )
        .animation(.bouncy(duration: 0.3), value: isSearchFocused)
    }
}

// MARK: - Pills de Filtros Activos Modernas
struct ActiveFilterPillsView: View {
    @Binding var filter: ExpenseFilter
    let onFilterChange: () -> Void
    
    var body: some View {
        if filter.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // Pill de rango de fechas
                    if filter.dateRange != .thisMonth {
                        FilterPill(
                            text: filter.dateRange.rawValue,
                            icon: "calendar.circle.fill",
                            color: DesignTokens.Colors.primary,
                            onRemove: {
                                withAnimation(.bouncy) {
                                    filter.dateRange = .thisMonth
                                    onFilterChange()
                                }
                            }
                        )
                    }
                    
                    // Pills de métodos de pago
                    ForEach(Array(filter.selectedPaymentMethods), id: \.self) { method in
                        FilterPill(
                            text: method,
                            icon: paymentIcon(for: method),
                            color: Color(hex: "#3B82F6")!,
                            onRemove: {
                                withAnimation(.bouncy) {
                                    filter.selectedPaymentMethods.remove(method)
                                    onFilterChange()
                                }
                            }
                        )
                    }
                    
                    // Pills de categorías
                    ForEach(Array(filter.selectedCategories), id: \.self) { category in
                        FilterPill(
                            text: category.components(separatedBy: " ").dropFirst().joined(separator: " "),
                            icon: "tag.circle.fill",
                            color: Color(hex: "#10B981")!,
                            onRemove: {
                                withAnimation(.bouncy) {
                                    filter.selectedCategories.remove(category)
                                    onFilterChange()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
        }
    }
    
    private func paymentIcon(for method: String) -> String {
        let m = method.lowercased()
        if m.contains("tarjeta") { return "creditcard.circle.fill" }
        if m.contains("efectivo") { return "banknote.circle.fill" }
        if m.contains("bizum") { return "arrow.left.arrow.right.circle.fill" }
        if m.contains("transferencia") { return "arrow.up.arrow.down.circle.fill" }
        return "dollarsign.circle.fill"
    }
}

// MARK: - Pill de Filtro Moderna
struct FilterPill: View {
    let text: String
    var icon: String = ""
    var color: Color = .clarityPrimary
    let onRemove: () -> Void
    

    
    var body: some View {
        HStack(spacing: 6) {
            // Icono si se proporciona
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Texto
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            
            // Botón eliminar
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            ZStack {
                // Gradiente del color
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Overlay glassm\u00f3rfico
                Color.white.opacity(0.1)
            }
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        
        VStack(spacing: 24) {
            Text("Barra de Búsqueda Moderna")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            SearchBarView(
                searchText: .constant(""),
                filter: .constant(ExpenseFilter(dateRange: .lastMonth)),
                onFilterChange: {}
            )
            .padding(.horizontal)
            
            Text("Filtros Activos")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            ActiveFilterPillsView(
                filter: .constant(ExpenseFilter(
                    selectedCategories: ["🏡 Vivienda", "🍕 Comida"],
                    selectedPaymentMethods: ["Tarjeta", "Bizum"],
                    dateRange: .last3Months
                )),
                onFilterChange: {}
            )
        }
    }
    .preferredColorScheme(.dark)
}
