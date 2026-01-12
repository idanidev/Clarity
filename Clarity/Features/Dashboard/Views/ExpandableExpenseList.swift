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
                .listRowBackground(Color(red: 0, green: 0, blue: 0)) // Force pure black row
            }
        }
        .listStyle(.plain) // Use plain list to avoid default inset group styling
        .scrollContentBackground(.hidden)
        .background(Color(red: 0, green: 0, blue: 0)) // RGB 000 HARDCODED
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    category.isExpanded.toggle()
                }
                HapticManager.selection()
            } label: {
                HStack(spacing: 12) {
                    // Simple Color Indicator
                    Circle()
                        .fill(category.color)
                        .frame(width: 12, height: 12)
                        .shadow(color: category.color.opacity(0.5), radius: 4, x: 0, y: 0)
                    
                    Text(category.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                    
                    Spacer()
                    
                    Text(formatCurrency(category.totalAmount))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .rotationEffect(.degrees(category.isExpanded ? 90 : 0))
                        .foregroundStyle(Color.white.opacity(0.4))
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
                // Add padding to container to match spec if needed, but List handles it usually.
                // Spec shows spacing between categories is handled by parent VStack in user snippet,
                // but here we are in a Section Header.
            }
            .buttonStyle(.plain)
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
        // Subcategory Header (if distinct subcategory)
        if !subcategory.name.isEmpty && subcategory.name != "General" {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    subcategory.isExpanded.toggle()
                }
                HapticManager.selection()
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(subcategory.isExpanded ? 90 : 0))
                        .frame(width: 20)
                    
                    Text(subcategory.name)
                        .font(.subheadline.weight(.semibold)) // More distinct weight
                        .foregroundStyle(.primary) // Clearer text
                    
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
                .background(Color.white.opacity(0.05)) // Subtle background for header
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.black)
        }

        if subcategory.isExpanded || subcategory.name == "General" || subcategory.name.isEmpty {
            ForEach(subcategory.expenses, id: \.stableId) { expense in
                ExpenseRow(
                    expense: expense,
                    categoryColor: categoryColor,
                    onDelete: { onExpenseDelete(expense) },
                    onEdit: { onExpenseEdit(expense) },
                    onDuplicate: { onExpenseDuplicate(expense) }
                )
                .listRowBackground(Color(red: 0, green: 0, blue: 0))
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
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Text(formattedDate)
                    if !expense.paymentMethod.isEmpty {
                        Text("•")
                            Text(expense.paymentMethod)
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(formatCurrency(expense.amount))
                .font(.body.monospacedDigit())
                .foregroundColor(.white)
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
    .preferredColorScheme(.dark)
}
