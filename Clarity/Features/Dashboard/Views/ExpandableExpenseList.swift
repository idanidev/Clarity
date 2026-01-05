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
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
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
                        onExpenseDelete: onExpenseDelete,
                        onExpenseEdit: onExpenseEdit,
                        onExpenseDuplicate: onExpenseDuplicate
                    )
                }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    category.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: category.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    Circle()
                        .fill(category.color)
                        .frame(width: 14, height: 14)
                    
                    Text("\(category.name) \(category.emoji)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(category.expenseCount) gasto\(category.expenseCount == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(formatCurrency(category.totalAmount))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(
            Color.bgSecondary
                .overlay(
                    Rectangle()
                        .fill(category.color)
                        .frame(width: 3),
                    alignment: .leading
                )
        )
        .listRowSeparator(.hidden)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }
}

// MARK: - Subcategory Section (Level 2)
struct SubcategorySection: View {
    @Binding var subcategory: SubcategoryGroup
    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void
    let onExpenseDuplicate: (Expense) -> Void
    
    var body: some View {
        DisclosureGroup(isExpanded: $subcategory.isExpanded) {
            ForEach(subcategory.expenses) { expense in
                ExpenseRow(
                    expense: expense,
                    onDelete: { onExpenseDelete(expense) },
                    onEdit: { onExpenseEdit(expense) },
                    onDuplicate: { onExpenseDuplicate(expense) }
                )
            }
        } label: {
            HStack(spacing: 6) {
                Text(subcategory.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                
                Text("\(subcategory.expenseCount)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatCurrency(subcategory.totalAmount))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
        }
        .tint(.gray)
        .listRowBackground(Color.bgCard)
        .listRowSeparator(.hidden)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }
}

// MARK: - Expense Row (Level 3) with Menu
struct ExpenseRow: View {
    let expense: Expense
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(expense.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let subcategory = expense.subcategory, !subcategory.isEmpty {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(subcategory)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(formattedDate)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    Text(expense.paymentMethod)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(formatCurrency(expense.amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                if expense.notes != nil {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .listRowBackground(Color.bgPrimary)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(Color.clarityPrimary)
            
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
