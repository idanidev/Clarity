// CategoryBreakdownTable.swift
// Detalle en tabla de una categoría seleccionada en el gráfico (issue #38).

import SwiftUI

struct CategoryBreakdownTable: View {
    let category: CategoryChartData
    let expenses: [Expense]

    @State private var sort: SortField = .amount
    @State private var showAll = false

    /// Filas visibles antes de pedir "ver todos".
    private static let collapsedRowCount = 6

    enum SortField: String, CaseIterable, Identifiable {
        case amount = "Importe"
        case date = "Fecha"
        case name = "Concepto"

        var id: String { rawValue }
    }

    private var rows: [Expense] {
        let own = expenses.filter { $0.category == category.name }
        switch sort {
        case .amount: return own.sorted { $0.amount > $1.amount }
        case .date: return own.sorted { $0.date > $1.date }
        case .name: return own.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private var visibleRows: [Expense] {
        showAll ? rows : Array(rows.prefix(Self.collapsedRowCount))
    }

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            GlassCard.light {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    CategoryBreakdownHeader(category: category, expenses: rows)

                    Divider().opacity(0.4)

                    CategorySubcategoryBreakdown(category: category, expenses: rows)

                    Divider().opacity(0.4)

                    sortPicker

                    tableHeader

                    VStack(spacing: 2) {
                        ForEach(visibleRows) { expense in
                            CategoryBreakdownRow(expense: expense, tint: category.color)
                        }
                    }

                    if rows.count > Self.collapsedRowCount {
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(.easeInOut(duration: AnimationDuration.normal)) {
                                showAll.toggle()
                            }
                        } label: {
                            Text(showAll
                                 ? "Ver menos"
                                 : "Ver los \(rows.count) gastos")
                                .scaledFont(size: 13, weight: .semibold)
                                .foregroundStyle(category.color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.sm)
            }
            .padding(.horizontal, Spacing.md)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    private var sortPicker: some View {
        Picker("Ordenar por", selection: $sort) {
            ForEach(SortField.allCases) { field in
                Text(field.rawValue).tag(field)
            }
        }
        .pickerStyle(.segmented)
    }

    private var tableHeader: some View {
        HStack {
            Text("Concepto")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundStyle(.tertiary)
            Spacer()
            Text("Fecha")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundStyle(.tertiary)
                .frame(width: 62, alignment: .trailing)
            Text("Importe")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundStyle(.tertiary)
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.xs)
    }
}

// MARK: - Cabecera con métricas

private struct CategoryBreakdownHeader: View {
    let category: CategoryChartData
    let expenses: [Expense]

    private var average: Double {
        guard !expenses.isEmpty else { return 0 }
        return category.amount / Double(expenses.count)
    }

    private var largest: Expense? {
        expenses.max { $0.amount < $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(category.color.gradient)
                    .frame(width: 10, height: 10)

                let parts = category.name.categoryNameEmoji
                if let emoji = parts.emoji { Text(emoji).font(.system(size: 15)) }
                Text(parts.name)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(.primary)

                Spacer()

                if let delta = category.deltaVsPrevious {
                    DeltaPill(delta: delta)
                }
            }

            HStack(spacing: Spacing.xs) {
                MetricCell(title: "Total", value: Formatters.currency(category.amount), tint: category.color)
                MetricCell(title: "Gastos", value: "\(expenses.count)", tint: category.color)
                MetricCell(title: "Media", value: Formatters.currency(average), tint: category.color)
                MetricCell(
                    title: "% del mes",
                    value: "\(String(format: "%.1f", category.percentage))%",
                    tint: category.color
                )
            }

            if let largest {
                Text("Mayor gasto: \(largest.name) · \(Formatters.currency(largest.amount))")
                    .scaledFont(size: 11)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct MetricCell: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .scaledFont(size: 10)
                .foregroundStyle(.tertiary)
            Text(value)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xxs)
        .padding(.horizontal, Spacing.xs)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}

private struct DeltaPill: View {
    let delta: Double

    private var isUp: Bool { delta >= 0 }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text("\(String(format: "%.0f", abs(delta) * 100))%")
                .scaledFont(size: 11, weight: .semibold)
        }
        .foregroundStyle(isUp ? Color.error : Color.success)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 3)
        .background((isUp ? Color.error : Color.success).opacity(0.12))
        .clipShape(Capsule())
        .accessibilityLabel(isUp ? "Sube un \(Int(abs(delta) * 100)) por ciento" : "Baja un \(Int(abs(delta) * 100)) por ciento")
    }
}

// MARK: - Desglose por subcategoría

private struct CategorySubcategoryBreakdown: View {
    let category: CategoryChartData
    let expenses: [Expense]

    private struct Slice: Identifiable {
        let id: String
        let total: Double
        let count: Int
    }

    private var slices: [Slice] {
        let grouped = Dictionary(grouping: expenses) { $0.subcategory ?? "Sin subcategoría" }
        return grouped
            .map { Slice(id: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }, count: $0.value.count) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        if slices.count > 1 {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Por subcategoría")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(.tertiary)

                ForEach(slices) { slice in
                    let share = category.amount > 0 ? slice.total / category.amount : 0
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(slice.id)
                                .scaledFont(size: 13)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("(\(slice.count))")
                                .scaledFont(size: 11)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(Formatters.currency(slice.total))
                                .scaledFont(size: 13, weight: .semibold)
                                .foregroundStyle(.primary)
                            Text("\(String(format: "%.0f", share * 100))%")
                                .scaledFont(size: 11, weight: .semibold)
                                .foregroundStyle(category.color)
                                .frame(width: 34, alignment: .trailing)
                        }

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(category.color.opacity(0.25))
                                .frame(width: max(2, geo.size.width * share), height: 4)
                        }
                        .frame(height: 4)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Fila de gasto

private struct CategoryBreakdownRow: View {
    let expense: Expense
    let tint: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 1) {
                Text(expense.name)
                    .scaledFont(size: 14)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let sub = expense.subcategory, !sub.isEmpty {
                        Text(sub)
                    }
                    Text("·")
                    Text(expense.paymentMethod)
                }
                .scaledFont(size: 11)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: Spacing.xs)

            Text(Formatters.shortDisplay(expense.date))
                .scaledFont(size: 12)
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)

            Text(Formatters.currency(expense.amount))
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(tint)
                .frame(width: 78, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 7)
        .background(Color.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.name), \(Formatters.currency(expense.amount)), \(Formatters.displayDate(expense.date))")
    }
}

// MARK: - Adaptador desde el stat del ViewModel
// El VM no importa SwiftUI (no puede construir Color), así que el mapeo vive aquí.
extension ChartsViewModel.CategoryStat {
    var asChartData: CategoryChartData {
        CategoryChartData(
            name: name,
            amount: amount,
            percentage: percentage,
            color: Color(hex: colorHex),
            deltaVsPrevious: deltaVsPrevious
        )
    }
}
