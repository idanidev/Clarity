// ModernExpenseCard.swift
// Tarjeta simple de gastos con swipe actions
// Diseño minimalista con colores de categoría

import SwiftUI

/// Tarjeta simple para mostrar un gasto individual con swipe actions
struct ModernExpenseCard: View {
    let expense: Expense
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // Barra lateral con gradiente vertical
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [userDataColor, userDataColor.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 8)
                .padding(.leading, 8)

            // Contenido principal
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.name)
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text(formattedDate)
                            .scaledFont(size: 12)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                        Text("·")
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .scaledFont(size: 10)

                        Image(systemName: paymentIcon)
                            .scaledFont(size: 10)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                        Text(expense.paymentMethod)
                            .scaledFont(size: 12)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                        if expense.isRecurring == true || expense.recurring == true {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .scaledFont(size: 10)
                                .foregroundStyle(DesignTokens.Colors.accent)
                        }

                        if let sub = expense.subcategory, !sub.isEmpty, sub != "General" {
                            Text(sub)
                                .scaledFont(size: 10, weight: .medium)
                                .foregroundStyle(userDataColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(userDataColor.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 8)

                Text(formattedAmount)
                    .scaledFont(size: 16, weight: .heavy, design: .rounded)
                    .foregroundStyle(userDataColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
        }
        // Fondo base + tintado sutil del color de categoría
        .background(
            ZStack {
                Color(uiColor: .secondarySystemGroupedBackground)
                userDataColor.opacity(colorScheme == .dark ? 0.07 : 0.055)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        // Borde visible en modo claro, invisible en oscuro
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.clear
                        : userDataColor.opacity(0.15),
                    lineWidth: 0.75
                )
        )
        .shadow(
            color: colorScheme == .dark
                ? .clear
                : userDataColor.opacity(0.12),
            radius: 4, x: 0, y: 2
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(expense.name), \(formattedAmount), \(formattedDate), \(expense.paymentMethod)")
        .accessibilityHint(onEdit != nil ? "Pulsa para editar" : "")
    }

    
    // MARK: - Computed Properties
    
    private var userDataColor: Color {
        UserDataManager.shared.color(for: expense.category)
    }
    
    private var paymentIcon: String {
        switch expense.paymentMethod.lowercased() {
        case "tarjeta", "tarjeta de crédito", "tarjeta de débito":
            return "creditcard.fill"
        case "efectivo":
            return "banknote.fill"
        case "bizum":
            return "iphone.gen3"
        case "transferencia":
            return "arrow.left.arrow.right"
        case "apple pay":
            return "apple.logo"
        case "paypal":
            return "p.circle.fill"
        default:
            return "creditcard"
        }
    }
    
    private static let inputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    private var formattedDate: String {
        guard let date = Self.inputDateFormatter.date(from: expense.date) else { return expense.date }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInYesterday(date) { return "Ayer" }

        return Self.displayDateFormatter.string(from: date)
    }

    private var formattedAmount: String {
        let value = expense.amount
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f€", value)
        }
        return String(format: "%.2f€", value)
    }
}

// MARK: - Preview

#Preview("Lista Simple") {
    List {
        ModernExpenseCard(
            expense: Expense(
                amount: 45.90,
                name: "Supermercado Mercadona",
                category: "🛒 Compras",
                subcategory: "Alimentación",
                date: "2026-01-15",
                paymentMethod: "Tarjeta"
            )
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 32, bottom: 3, trailing: 16))
        .listRowSeparator(.hidden)
        
        ModernExpenseCard(
            expense: Expense(
                amount: 1250.00,
                name: "Alquiler apartamento",
                category: "🏡 Vivienda",
                subcategory: nil,
                date: "2026-01-01",
                paymentMethod: "Transferencia"
            )
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 32, bottom: 3, trailing: 16))
        .listRowSeparator(.hidden)
        
        ModernExpenseCard(
            expense: Expense(
                amount: 89.99,
                name: "Cena con amigos",
                category: "🍻 Ocio",
                subcategory: "Restaurantes",
                date: "2026-01-14",
                paymentMethod: "Bizum"
            )
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 32, bottom: 3, trailing: 16))
        .listRowSeparator(.hidden)
        
        ModernExpenseCard(
            expense: Expense(
                amount: 35.00,
                name: "Netflix + HBO",
                category: "📺 Entretenimiento",
                subcategory: "Streaming",
                date: "2026-01-10",
                paymentMethod: "Apple Pay"
            )
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 32, bottom: 3, trailing: 16))
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color(.systemGroupedBackground))
}
