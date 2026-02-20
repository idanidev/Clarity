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
            ForEach(categories) { category in
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
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
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

    var body: some View {
        Section {
            if isExpanded {
                ForEach(category.subcategories) { subcategory in
                    SubcategorySection(
                        subcategory: subcategory,
                        categoryColor: category.color,
                        isExpanded: isSubcategoryExpanded(category.id + "_" + subcategory.id),
                        onToggleExpand: {
                            // Unique ID for subselection scope
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
                HStack(spacing: 12) {
                    // Barra de color más ancha y prominente
                    RoundedRectangle(cornerRadius: 3)
                        .fill(category.color.gradient)
                        .frame(width: 6, height: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.name)
                            .font(.title3.weight(.semibold))  // ⬆️ Más grande (19pt)
                            .foregroundStyle(.primary)

                        Text("\(category.expenseCount) gastos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(category.totalAmount.formattedCurrency)
                            .font(.title3.weight(.bold))  // ⬆️ Más grande
                            .foregroundStyle(category.color)

                        Text("del total")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Image(
                        systemName: isExpanded
                            ? "chevron.up.circle.fill" : "chevron.down.circle.fill"
                    )
                    .font(.title3)
                    .foregroundStyle(category.color)
                    .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
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

    var body: some View {
        // Subcategory Header (if distinct subcategory) - INDENTED from category
        if !subcategory.name.isEmpty && subcategory.name != "General" {
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 12) {
                    // Conector visual más grueso
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(categoryColor.opacity(0.25))
                            .frame(width: 3)  // ⬆️ Más ancho

                        Circle()
                            .fill(categoryColor)
                            .frame(width: 8, height: 8)
                            .offset(y: 12)
                    }
                    .frame(width: 16, height: 32)

                    Text(subcategory.name)
                        .font(.body.weight(.medium))  // ⬆️ Más grande (17pt)
                        .foregroundStyle(.primary)  // ⬆️ Primary en vez de secondary

                    Spacer()

                    // Badge contador
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text("\(subcategory.expenses.count)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .padding(.leading, 20)  // ⬆️ Mayor indentación
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 28, bottom: 2, trailing: 16))
            .listRowBackground(Color(.systemGroupedBackground))
        }

        if isExpanded || subcategory.name == "General" || subcategory.name.isEmpty {
            ForEach(subcategory.expenses, id: \.stableId) { expense in
                Button {
                    // Tap Action (Details)
                    // We can pass a closure or specific action logic here
                    // Current logic requires edit/delete, taps were handled via ModernExpenseCard onTap
                    // But ExpandableExpenseList doesn't accept onTap in its init?
                    // Let's check init: onExpenseDelete, onExpenseEdit.
                    // It doesn't seem to expose a generic 'onTap'.
                    // For now, let's assume tap triggers edit or we need to add onTap to ExpandableExpenseList?
                    // ExpenseRowView (standard) had 'showDetail'.
                    // Let's add onTap support or defaulting to edit.
                    onExpenseEdit(expense)  // Default tap to edit for now, or we can add expand support.
                    // The user wants detail?
                } label: {
                    ModernExpenseCard(
                        expense: expense,
                        onTap: nil,
                        onDelete: nil,
                        onEdit: nil
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 3, leading: 56, bottom: 3, trailing: 16))  // ⬆️ Mayor indentación
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    // Solo eliminar a la derecha
                    Button(role: .destructive) {
                        onExpenseDelete(expense)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    // Solo Editar a la izquierda
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: expense.date) else { return expense.date }
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
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
