// ExpandableExpenseList.swift
// Hierarchical expense list with expandable categories and subcategories

import SwiftUI

// MARK: - Models

struct CategoryGroup: Identifiable, Equatable {
    // Stable ID based on name for consistent diffing
    var id: String { name }
    let name: String
    let emoji: String
    let color: Color
    var totalAmount: Double
    var expenseCount: Int
    // isExpanded removed from logic (handled by View)
    var subcategories: [SubcategoryGroup]

    static func == (lhs: CategoryGroup, rhs: CategoryGroup) -> Bool {
        lhs.id == rhs.id && lhs.totalAmount == rhs.totalAmount
            && lhs.subcategories == rhs.subcategories
    }
}

struct SubcategoryGroup: Identifiable, Equatable {
    var id: String { name }
    let name: String
    var totalAmount: Double
    var expenseCount: Int
    var expenses: [Expense]
}

// MARK: - Main Expandable List
struct ExpandableExpenseList: View {
    let categories: [CategoryGroup]  // Read-only value
    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void
    var onLoadMore: (() -> Void)? = nil  // Optional for pagination

    // Local View State for expansion
    // Storing IDs of COLLAPSED items (default behavior is expanded)
    @State private var collapsedCategories: Set<String> = []
    @State private var collapsedSubcategories: Set<String> = []

    var body: some View {
        List {
            ForEach(categories, id: \.name) { category in
                CategorySection(
                    category: category,
                    isExpanded: !collapsedCategories.contains(category.id),
                    onToggleExpand: {
                        toggleCategory(category.id)
                    },
                    isSubcategoryExpanded: { subID in
                        !collapsedSubcategories.contains(subID)
                    },
                    onToggleSubcategory: { subID in
                        toggleSubcategory(subID)
                    },
                    onExpenseDelete: onExpenseDelete,
                    onExpenseEdit: onExpenseEdit
                )
                .id(category.id)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.systemGroupedBackground))
            }

            // Infinite Scroll Trigger
            if let onLoadMore = onLoadMore {
                Color.clear
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onAppear {
                        onLoadMore()
                    }
            }
        }
        .listStyle(.plain)  // ⬆️ Full width para móvil
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions
    private func toggleCategory(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if collapsedCategories.contains(id) {
                collapsedCategories.remove(id)
            } else {
                collapsedCategories.insert(id)
            }
        }
        HapticManager.shared.selection()
    }

    private func toggleSubcategory(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if collapsedSubcategories.contains(id) {
                collapsedSubcategories.remove(id)
            } else {
                collapsedSubcategories.insert(id)
            }
        }
        HapticManager.shared.selection()
    }
}

// MARK: - Category Section (Level 1)
struct CategorySection: View {
    let category: CategoryGroup
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let isSubcategoryExpanded: (String) -> Bool
    let onToggleSubcategory: (String) -> Void

    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Section {
            if isExpanded {
                ForEach(category.subcategories) { subcategory in
                    SubcategorySection(
                        subcategory: subcategory,
                        categoryColor: category.color,
                        isExpanded: isSubcategoryExpanded(category.id + "_" + subcategory.id),
                        onToggleExpand: {
                            onToggleSubcategory(category.id + "_" + subcategory.id)
                        },
                        onExpenseDelete: onExpenseDelete,
                        onExpenseEdit: onExpenseEdit
                    )
                }
            }
        } header: {
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 0) {
                    // Barra de acento izquierda — el color de la categoría de un vistazo
                    RoundedRectangle(cornerRadius: 2)
                        .fill(category.color)
                        .frame(width: 4)
                        .padding(.vertical, 1)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.name)
                                .scaledFont(size: 17, weight: .bold)
                                .foregroundStyle(.primary)

                            Text("\(category.expenseCount) gastos")
                                .scaledFont(size: 13)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(category.totalAmount.formattedCurrency)
                            .scaledFont(size: 18, weight: .heavy, design: .rounded)
                            .foregroundStyle(category.color)

                        Image(systemName: "chevron.right")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundStyle(category.color.opacity(0.7))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                            .frame(width: 18)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                }
                .background(
                    ZStack {
                        Color(uiColor: .secondarySystemGroupedBackground)
                        LinearGradient(
                            colors: [
                                category.color.opacity(colorScheme == .dark ? 0.13 : 0.07),
                                category.color.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            category.color.opacity(colorScheme == .dark ? 0.18 : 0.25),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: colorScheme == .dark ? .clear : category.color.opacity(0.10),
                    radius: 4, x: 0, y: 2
                )
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.98))
        }
    }

}

// MARK: - Subcategory Section (Level 2)
struct SubcategorySection: View {
    let subcategory: SubcategoryGroup
    let categoryColor: Color
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        // Subcategory Header (if distinct subcategory) - INDENTED from category
        if !subcategory.name.isEmpty && subcategory.name != "General" {
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 10) {
                    // Barra izquierda del color de categoría
                    RoundedRectangle(cornerRadius: 2)
                        .fill(categoryColor.opacity(0.5))
                        .frame(width: 2, height: 18)

                    Text(subcategory.name)
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.55 : 0.70))

                    Spacer()

                    Text("\(subcategory.expenses.count)")
                        .scaledFont(size: 12, weight: .semibold, design: .rounded)
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            categoryColor.opacity(colorScheme == .dark ? 0.15 : 0.10),
                            in: Capsule()
                        )

                    Image(systemName: "chevron.right")
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.97))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 28, bottom: 2, trailing: 16))
            .listRowBackground(Color(.systemGroupedBackground))
        }

        if isExpanded || subcategory.name == "General" || subcategory.name.isEmpty {
            ForEach(subcategory.expenses, id: \.stableId) { expense in
                Button {
                    onExpenseEdit(expense)
                } label: {
                    ModernExpenseCard(
                        expense: expense,
                        onTap: nil,
                        onDelete: nil,
                        onEdit: nil
                    )
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.97))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 3, leading: 28, bottom: 3, trailing: 16))
                .transition(.opacity.combined(with: .offset(y: 6)))
                .contextMenu {
                    Button {
                        onExpenseEdit(expense)
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        onExpenseDelete(expense)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onExpenseDelete(expense)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        onExpenseEdit(expense)
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
    }
}

// MARK: - Expense Row (Standard Version)
struct ExpenseRow: View {
    let expense: Expense
    var categoryColor: Color = .gray
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Marker
            Circle()
                .fill(categoryColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                HStack {
                    Text(formattedDate)
                    if !expense.paymentMethod.isEmpty {
                        Text("•")
                        Text(expense.paymentMethod)
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.secondary)
            }

            Spacer()

            Text(expense.amount.formattedCurrency)
                .font(.body.monospacedDigit())
                .foregroundStyle(Color.primary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }

    private var formattedDate: String {
        Formatters.shortDisplay(expense.date)
    }

}

// MARK: - Preview
#Preview {
    let sampleExpenses = [
        Expense(
            id: "1",
            amount: 4.50,
            name: "Café Starbucks",
            category: "Alimentacion",
            subcategory: "Cafeterías",
            date: "2026-01-02",
            paymentMethod: "Tarjeta"
        )
    ]

    let categories = [
        CategoryGroup(
            name: "Alimentación",
            emoji: "🥗",
            color: .green,
            totalAmount: 49.80,
            expenseCount: 2,
            subcategories: [
                SubcategoryGroup(
                    name: "General",
                    totalAmount: 49.80,
                    expenseCount: 2,
                    expenses: sampleExpenses
                )
            ]
        )
    ]

    ExpandableExpenseList(
        categories: categories,
        onExpenseDelete: { _ in },
        onExpenseEdit: { _ in }
    )
    .preferredColorScheme(.dark)
}
