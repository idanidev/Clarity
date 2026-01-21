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
        mainContent
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                radius: 2, x: 0, y: 1
            )
    }

    private var mainContent: some View {

        HStack(spacing: 0) {
            // Barra de color de categoría (izquierda)
            Rectangle()
                .fill(userDataColor)
                .frame(width: 4)

            // Contenido principal
            VStack(alignment: .leading, spacing: 6) {
                // Fila 1: Nombre + Importe
                HStack {
                    Text(expense.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: DesignTokens.Spacing.xs)

                    Text(formattedAmount)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }

                // Fila 2: Fecha + Método de pago + (Recurrente si aplica)
                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    Text("•")
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .font(.system(size: 10))

                    // Icono de método de pago
                    HStack(spacing: 3) {
                        Image(systemName: paymentIcon)
                            .font(.system(size: 10))
                        Text(expense.paymentMethod)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                    Spacer()

                    // Indicador de recurrente
                    if expense.isRecurring == true || expense.recurring == true {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        }
                        .foregroundStyle(DesignTokens.Colors.accent)
                    }
                    
                    // Subcategoría si existe
                    if let sub = expense.subcategory, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.textSecondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 8)
        }
        .background(DesignTokens.Colors.surface)
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
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: expense.date) else { return expense.date }
        
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
    
    private var formattedAmount: String {
        String(format: "%.2f€", expense.amount)
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
