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
                .id(category.id)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear) // cleaner background
            }
        }
        .listStyle(.plain) // Use plain list to avoid default inset group styling
        .scrollContentBackground(.hidden)
        .background(Color.black) // OLED Pure Black
    }
}

// MARK: - Category Section (Level 1)
struct CategorySection: View {
    @Binding var category: CategoryGroup
    let onExpenseDelete: (Expense) -> Void
    let onExpenseEdit: (Expense) -> Void
    let onExpenseDuplicate: (Expense) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Updated Header - Cleaner, less "grid" like
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    category.isExpanded.toggle()
                }
                HapticManager.selection()
            } label: {
                HStack(spacing: 12) {
                    // Modern color pill indicator
                    Capsule()
                        .fill(category.color)
                        .frame(width: 4, height: 24)
                    
                    Text(category.emoji)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("\(category.expenseCount) gastos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(category.totalAmount))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                        
                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(category.isExpanded ? 90 : 0))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#050505")!) // Almost pure black
                        .overlay(
                             RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.clarityPrimary.opacity(0.15), lineWidth: 1) // User's requested purple accent
                        )
                )
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if category.isExpanded {
                VStack(spacing: 0) {
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
                .padding(.leading, 12) // Indent content slightly
                .transition(.opacity)
            }
        }
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
        // Removed DisclaimerGroup for cleaner look, just listing items
        VStack(spacing: 0) {
            // Optional Subheader if needed, otherwise just expenses
            // The user wanted cleaner, so let's just show rows directly but maybe grouped visually
            if !subcategory.name.isEmpty && subcategory.name != "Sin subcategoría" {
               HStack {
                   Text(subcategory.name)
                       .font(.caption.weight(.semibold))
                       .foregroundStyle(categoryColor.opacity(0.8))
                       .padding(.vertical, 4)
                       .padding(.leading, 12)
                   Spacer()
               }
            }

            ForEach(subcategory.expenses, id: \.stableId) { expense in
                ExpenseRow(
                    expense: expense,
                    categoryColor: categoryColor,
                    onDelete: { onExpenseDelete(expense) },
                    onEdit: { onExpenseEdit(expense) },
                    onDuplicate: { onExpenseDuplicate(expense) }
                )
                // Minimal separator
                if expense.id != subcategory.expenses.last?.id {
                     Divider()
                         .padding(.leading, 20)
                         .opacity(0.3)
                }
            }
        }
    }
}

// MARK: - Expense Row (Level 3) - Clean Design
struct ExpenseRow: View {
    let expense: Expense
    var categoryColor: Color = .gray
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) { // increased spacing
            // Clean content without vertical bars
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        
                    Text(expense.paymentMethod)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(formatCurrency(expense.amount))
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(expense.amount > 50 ? .primary : .secondary) // Highlight big expenses
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.black) // Pure black for rows (OLED friendly)
        .contentShape(Rectangle())
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
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: expense.date) else { return expense.date }
        formatter.dateFormat = "d MMM" // Short date format "2 Ene"
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
            category: "Alimentacion",
            subcategory: "Cafeterías",
            date: "2026-01-02",
            paymentMethod: "Tarjeta"
        ),
        Expense(
            id: "2",
            amount: 45.30,
            name: "Mercadona",
            category: "Alimentacion",
            subcategory: "Supermercado",
            date: "2026-01-01",
            paymentMethod: "Efectivo"
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
        categories: .constant(categories),
        onExpenseDelete: { _ in },
        onExpenseEdit: { _ in },
        onExpenseDuplicate: { _ in }
    )
    .background(Color.black)
    .preferredColorScheme(.dark)
}
