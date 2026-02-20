//
//  SymbolPickerView.swift
//  Clarity
//
//  Created by Clarity AI on 2026-02-05.
//  Premium SF Symbol picker with categories and search
//

import SwiftUI

struct SymbolPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSymbol: String

    @State private var searchText = ""
    @State private var selectedCategory: SymbolCategory = .finance

    enum SymbolCategory: String, CaseIterable {
        case finance = "Finanzas"
        case home = "Hogar"
        case travel = "Viajes"
        case education = "Educación"
        case health = "Salud"
        case sports = "Deportes"
        case shopping = "Compras"
        case entertainment = "Ocio"

        var symbols: [String] {
            switch self {
            case .finance:
                return [
                    "dollarsign.circle", "eurosign.circle", "banknote", "creditcard",
                    "chart.line.uptrend.xyaxis", "chart.pie", "wallet.pass", "building.columns",
                ]
            case .home:
                return [
                    "house", "lightbulb", "bed.double", "sofa", "refrigerator", "stove", "washer",
                    "fan.desk",
                ]
            case .travel:
                return [
                    "airplane", "car", "bus", "tram", "ferry", "bicycle", "figure.walk",
                    "location.circle",
                ]
            case .education:
                return [
                    "graduationcap", "book", "pencil", "backpack", "textbook", "studentdesk",
                    "brain.head.profile", "laptopcomputer",
                ]
            case .health:
                return [
                    "cross.case", "heart.text.square", "pills", "syringe", "bandage", "stethoscope",
                    "medical.thermometer", "eyeglasses",
                ]
            case .sports:
                return [
                    "figure.run", "dumbbell", "figure.strengthtraining.traditional", "sportscourt",
                    "baseball", "football", "basketball", "tennis.racket",
                ]
            case .shopping:
                return [
                    "cart", "bag", "giftcard", "shippingbox", "tshirt", "shoe", "bag.circle",
                    "basket",
                ]
            case .entertainment:
                return [
                    "film", "tv", "music.note", "guitars", "gamecontroller", "headphones", "ticket",
                    "popcorn",
                ]
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Buscar símbolos", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
                .padding()

                // Category Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SymbolCategory.allCases, id: \.self) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)

                // Symbols Grid
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 70, maximum: 80))
                        ], spacing: 16
                    ) {
                        ForEach(filteredSymbols, id: \.self) { symbol in
                            symbolButton(symbol)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Elegir Ícono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .bold()
                }
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func categoryChip(_ category: SymbolCategory) -> some View {
        let isSelected = selectedCategory == category

        Button {
            selectedCategory = category
            HapticManager.shared.impact(.light)
        } label: {
            Text(category.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected ? Color.clarityPrimary : Color(uiColor: .tertiarySystemFill))
                )
        }
    }

    @ViewBuilder
    private func symbolButton(_ symbol: String) -> some View {
        let isSelected = selectedSymbol == symbol

        Button {
            selectedSymbol = symbol
            HapticManager.shared.impact(.medium)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(isSelected ? .white : Color.clarityPrimary)
                    .background(
                        Circle().fill(
                            isSelected ? Color.clarityPrimary : Color(uiColor: .tertiarySystemFill))
                    )

                Text(symbolName(symbol))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
    }

    // MARK: - Helpers

    private var filteredSymbols: [String] {
        let baseSymbols = selectedCategory.symbols

        if searchText.isEmpty {
            return baseSymbols
        }

        return baseSymbols.filter { symbol in
            symbol.localizedCaseInsensitiveContains(searchText)
                || symbolName(symbol).localizedCaseInsensitiveContains(searchText)
        }
    }

    private func symbolName(_ symbol: String) -> String {
        // Convert camelCase and dots to readable names
        symbol
            .replacingOccurrences(of: ".", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

#Preview {
    SymbolPickerView(selectedSymbol: .constant("dollarsign.circle"))
}
