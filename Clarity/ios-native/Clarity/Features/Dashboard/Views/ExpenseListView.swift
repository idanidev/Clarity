// ExpenseListView.swift
// List of expenses

import SwiftUI

struct ExpenseListView: View {
    let expenses: [Expense]
    let onDelete: (Expense) -> Void
    
    var body: some View {
        List {
            ForEach(expenses) { expense in
                ExpenseRowView(expense: expense)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(expense)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Expense Row
struct ExpenseRowView: View {
    let expense: Expense
    @State private var showDetail = false
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Text(categoryEmoji)
                    .font(.title3)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(.clarityHeadline)
                    .lineLimit(1)
                
                HStack(spacing: Spacing.xxs) {
                    if let subcategory = expense.subcategory {
                        Text(subcategory)
                            .font(.clarityCaption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(formattedDate)
                        .font(.clarityCaption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            Text("€\(expense.amount, specifier: "%.2f")")
                .font(.clarityAmountSmall)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
        .onTapGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            ExpenseDetailSheet(expense: expense)
        }
    }
    
    private var categoryEmoji: String {
        let category = expense.category
        if category.contains("🫄") { return "🥗" }
        if category.contains("🍻") { return "🍻" }
        if category.contains("🏡") { return "🏡" }
        if category.contains("🚎") { return "🚎" }
        if category.contains("🛒") { return "🛒" }
        if category.contains("🏥") { return "🏥" }
        if category.contains("📺") { return "📺" }
        if category.contains("📖") { return "📖" }
        if category.contains("🗺️") { return "🗺️" }
        return "📦"
    }
    
    private var categoryColor: Color {
        for cat in DefaultCategory.allCases {
            if expense.category.contains(cat.rawValue.prefix(5)) {
                return cat.color
            }
        }
        return .gray
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: expense.date) else { return expense.date }
        
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}

// MARK: - Category Grouped View
struct CategoryGroupedView: View {
    let categories: [String: [Expense]]
    let onDelete: (Expense) -> Void
    
    var body: some View {
        List {
            ForEach(sortedCategories, id: \.self) { category in
                Section {
                    ForEach(categories[category] ?? []) { expense in
                        ExpenseRowView(expense: expense)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDelete(expense)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(category)
                            .font(.clarityHeadline)
                        Spacer()
                        Text("€\(categoryTotal(category), specifier: "%.2f")")
                            .font(.claritySubheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var sortedCategories: [String] {
        categories.keys.sorted { a, b in
            categoryTotal(a) > categoryTotal(b)
        }
    }
    
    private func categoryTotal(_ category: String) -> Double {
        (categories[category] ?? []).reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Expense Detail Sheet
struct ExpenseDetailSheet: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Detalles") {
                    LabeledContent("Nombre", value: expense.name)
                    LabeledContent("Monto", value: String(format: "€%.2f", expense.amount))
                    LabeledContent("Categoría", value: expense.category)
                    if let sub = expense.subcategory {
                        LabeledContent("Subcategoría", value: sub)
                    }
                    LabeledContent("Fecha", value: expense.date)
                    LabeledContent("Método de pago", value: expense.paymentMethod)
                }
                
                if let notes = expense.notes, !notes.isEmpty {
                    Section("Notas") {
                        Text(notes)
                    }
                }
            }
            .navigationTitle("Detalle del Gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ExpenseListView(
        expenses: Expense.samples,
        onDelete: { _ in }
    )
}
