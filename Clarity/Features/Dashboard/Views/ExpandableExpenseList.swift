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
        lhs.id == rhs.id && lhs.totalAmount == rhs.totalAmount && lhs.subcategories == rhs.subcategories
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
    let categories: [CategoryGroup] // Read-only value
    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void
    let onExpenseDuplicate: (Expense) -> Void
    
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
                    onExpenseEdit: onExpenseEdit,
                    onExpenseDuplicate: onExpenseDuplicate
                )
                .id(category.id)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.bgPrimary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
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
        HapticManager.selection()
    }
    
    private func toggleSubcategory(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if collapsedSubcategories.contains(id) {
                collapsedSubcategories.remove(id)
            } else {
                collapsedSubcategories.insert(id)
            }
        }
        HapticManager.selection()
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
    let onExpenseDuplicate: (Expense) -> Void
    
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
                        onExpenseEdit: onExpenseEdit,
                        onExpenseDuplicate: onExpenseDuplicate
                    )
                }
            }
        } header: {
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 12) {
                    // Simple Color Indicator
                    Circle()
                        .fill(category.color)
                        .frame(width: 12, height: 12)
                        .shadow(color: category.color.opacity(0.5), radius: 4, x: 0, y: 0)
                    
                    Text(category.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    
                    Spacer()
                    
                    Text(category.totalAmount.formattedCurrency)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.9))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(category.color.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(category.color.opacity(0.3), lineWidth: 1)
                        )
                )
                .background(Color.bgPrimary)
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
    let onExpenseDuplicate: (Expense) -> Void
    
    var body: some View {
        // Subcategory Header (if distinct subcategory)
        if !subcategory.name.isEmpty && subcategory.name != "General" {
            Button {
                onToggleExpand()
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 20)
                    
                    Text(subcategory.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text("\(subcategory.expenses.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.05))
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.bgPrimary)
        }

        if isExpanded || subcategory.name == "General" || subcategory.name.isEmpty {
            ForEach(subcategory.expenses, id: \.stableId) { expense in
                ExpenseRow(
                    expense: expense,
                    categoryColor: categoryColor,
                    onDelete: { onExpenseDelete(expense) },
                    onEdit: { onExpenseEdit(expense) },
                    onDuplicate: { onExpenseDuplicate(expense) }
                )
                .listRowBackground(Color.bgPrimary)
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
    let onDuplicate: () -> Void
    
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
        .swipeActions(edge: .leading) {
            Button {
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.orange)
            
            Button {
                onDuplicate()
            } label: {
                Label("Duplicar", systemImage: "doc.on.doc")
            }
            .tint(.blue)
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
        onExpenseEdit: { _ in },
        onExpenseDuplicate: { _ in }
    )
    .preferredColorScheme(.dark)
}
