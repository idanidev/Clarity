// ExpandableExpenseList.swift
// Hierarchical expense list with expandable categories and subcategories

import SwiftUI

// MARK: - Models

struct CategoryGroup: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let color: Color
    var totalAmount: Double
    var expenseCount: Int
    var isExpanded: Bool = true
    var subcategories: [SubcategoryGroup]
}

struct SubcategoryGroup: Identifiable {
    let id = UUID()
    let name: String
    var totalAmount: Double
    var expenseCount: Int
    var isExpanded: Bool = true
    var expenses: [Expense]
}

// MARK: - Main Expandable List
struct ExpandableExpenseList: View {
    @Binding var categories: [CategoryGroup]
    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void
    let onExpenseDuplicate: (Expense) -> Void
    
    var body: some View {
        List {
            ForEach($categories) { $category in
                CategorySection(
                    category: $category,
                    onExpenseDelete: onExpenseDelete,
                    onExpenseEdit: onExpenseEdit,
                    onExpenseDuplicate: onExpenseDuplicate
                )
                .id(category.id) // Critical for diff performance
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
        .environment(\.defaultMinListRowHeight, 0) // iOS 26 optimization
    }
}

// MARK: - Category Section (Level 1)
struct CategorySection: View {
    @Binding var category: CategoryGroup
    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void
    let onExpenseDuplicate: (Expense) -> Void
    
    var body: some View {
        Section {
            if category.isExpanded {
                ForEach($category.subcategories) { $subcategory in
                    SubcategorySection(
                        subcategory: $subcategory,
                        categoryColor: category.color,
                        onExpenseDelete: onExpenseDelete,
                        onExpenseEdit: onExpenseEdit,
                        onExpenseDuplicate: onExpenseDuplicate
                    )
                }
            }
        } header: {
            Button {
                withAnimation(.bouncy(duration: 0.25)) {
                    category.isExpanded.toggle()
                }
                HapticManager.selection()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: category.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)
                    
                    Circle()
                        .fill(category.color)
                        .frame(width: 10, height: 10)
                    
                    Text("\(category.name)\(category.emoji)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text("\(category.expenseCount) gasto\(category.expenseCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    Text(formatCurrency(category.totalAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
                .padding(.vertical, 0)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.name), \(category.expenseCount) gastos, total \(formatCurrency(category.totalAmount))")
            .accessibilityHint(category.isExpanded ? "Toca para contraer" : "Toca para expandir")
        }
        .listRowBackground(
            Color(.secondarySystemBackground)
                .overlay(
                    Rectangle()
                        .fill(category.color)
                        .frame(width: 3),
                    alignment: .leading
                )
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowSeparator(.hidden)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }
}

// MARK: - Subcategory Section (Level 2)
struct SubcategorySection: View {
    @Binding var subcategory: SubcategoryGroup
    let categoryColor: Color
    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void
    let onExpenseDuplicate: (Expense) -> Void
    
    var body: some View {
        DisclosureGroup(isExpanded: $subcategory.isExpanded) {
            ForEach(subcategory.expenses) { expense in
                ExpenseRow(
                    expense: expense,
                    categoryColor: categoryColor,
                    onDelete: { onExpenseDelete(expense) },
                    onEdit: { onExpenseEdit(expense) },
                    onDuplicate: { onExpenseDuplicate(expense) }
                )
            }
        } label: {
            HStack(spacing: 6) {
                Text(subcategory.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("\(subcategory.expenseCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(formatCurrency(subcategory.totalAmount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .tint(.secondary)
        .listRowBackground(
            Color(.tertiarySystemBackground)
                .overlay(
                    Rectangle()
                        .fill(categoryColor.opacity(0.6))
                        .frame(width: 3),
                    alignment: .leading
                )
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
        .listRowSeparator(.hidden)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }
}

// MARK: - Expense Row (Level 3) with iOS 26 Design
struct ExpenseRow: View {
    let expense: Expense
    var categoryColor: Color = .gray
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.xs) {  // Reduced from sm
            // Icon
            Image(systemName: "doc.text.fill")
                .font(.system(size: IconSize.small))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
                .frame(width: 20)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {  // Reduced spacing
                HStack(spacing: Spacing.xxs) {
                    Text(expense.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if let subcategory = expense.subcategory, !subcategory.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(subcategory)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tertiary)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(expense.paymentMethod)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small / 2))
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {  // Reduced spacing
                Text(formatCurrency(expense.amount))
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                
                if expense.notes != nil {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 6)  // Reduced from Spacing.xs (8)
        .padding(.leading, 4)    // Reduced from Spacing.xs (8)
        .accessibilityLabel("\(expense.name), \(formatCurrency(expense.amount)), \(formattedDate)")
        .accessibilityHint("Desliza para editar o eliminar")
        .contentShape(Rectangle())
        .listRowBackground(
            Color(.systemBackground)
                .overlay(
                    Rectangle()
                        .fill(categoryColor.opacity(0.4))
                        .frame(width: 3),
                    alignment: .leading
                )
        )
        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 12))
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                HapticManager.notification(.warning)
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash.fill")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                HapticManager.impact(.light)
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(Color.accentColor)
            
            Button {
                HapticManager.impact(.light)
                onDuplicate()
            } label: {
                Label("Duplicar", systemImage: "doc.on.doc.fill")
            }
            .tint(.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.name), \(formatCurrency(expense.amount)), \(formattedDate)")
        .accessibilityHint("Desliza para editar o eliminar")
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: expense.date) else { return expense.date }
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }
}

// MARK: - Preview
#Preview {
    let sampleExpenses = [
        Expense(
            id: "1",
            amount: 4.50,
            name: "Café Starbucks",
            category: "Alimentacion 🥗",
            subcategory: "Cafeterías",
            date: "2026-01-02",
            paymentMethod: "Tarjeta"
        ),
        Expense(
            id: "2",
            amount: 45.30,
            name: "Mercadona",
            category: "Alimentacion 🥗",
            subcategory: "Supermercado",
            date: "2026-01-01",
            paymentMethod: "Efectivo"
        )
    ]
    
    let categories = [
        CategoryGroup(
            name: "Alimentación",
            emoji: "🥗",
            color: Color(hex: "#6366F1")!,
            totalAmount: 49.80,
            expenseCount: 2,
            subcategories: [
                SubcategoryGroup(
                    name: "Cafeterías",
                    totalAmount: 4.50,
                    expenseCount: 1,
                    expenses: [sampleExpenses[0]]
                ),
                SubcategoryGroup(
                    name: "Supermercado",
                    totalAmount: 45.30,
                    expenseCount: 1,
                    expenses: [sampleExpenses[1]]
                )
            ]
        )
    ]
    
    ExpandableExpenseList(
        categories: .constant(categories),
        onExpenseDelete: { _ in },
        onExpenseEdit: { _ in },
        onExpenseDuplicate: { _ in }
    )
    .preferredColorScheme(.dark)
}
