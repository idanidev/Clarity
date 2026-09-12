// CalendarioPage.swift
// Tercera página de la Home: cuándo (#65).

import SwiftUI

struct CalendarioPage: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ExpenseCalendarView(expenses: viewModel.allHistoricalExpenses)
                    .padding(.vertical, 8)
                    .glassCard()

                semanas
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .trackScreen("home_calendario")
    }

    private var semanas: some View {
        let filas = viewModel.semanasDelMes
        let maximo = filas.map(\.importe).max() ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("Por semanas").font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(Array(filas.enumerated()), id: \.offset) { _, f in
                    VStack(spacing: 3) {
                        Text(f.etiqueta).font(.caption2).foregroundStyle(.secondary)
                        Text(Formatters.currencyCompact(f.importe))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(maximo > 0 && f.importe == maximo ? Color.error : .primary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}
