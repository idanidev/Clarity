// DebtsView.swift
// "Te deben": quién tiene que devolverte dinero de los gastos en modo regalo (#37).

import SwiftUI

struct DebtsView: View {
    @State private var viewModel: DebtsViewModel

    @MainActor
    init(viewModel: DebtsViewModel? = nil) {
        let vm = viewModel ?? DependencyContainer.shared.makeDebtsViewModel()
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        List {
            if !viewModel.summaries.isEmpty {
                Section {
                    DebtsTotalHeader(
                        pending: viewModel.totalPending,
                        paid: viewModel.totalPaid
                    )
                    .filaTarjetaClarity(arriba: 0, abajo: 0, lados: 0)
                }
            }

            ForEach(viewModel.visibleSummaries) { summary in
                DebtExpenseSection(summary: summary, viewModel: viewModel)
            }
        }
        .listStyle(.insetGrouped)
        .fondoClarity()
        .trackScreen("te_deben")
        .navigationTitle("Te deben")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: AnimationDuration.fast)) {
                        viewModel.showPaid.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.showPaid ? "eye.slash" : "eye")
                }
                .accessibilityLabel(viewModel.showPaid ? "Ocultar cobrados" : "Mostrar cobrados")
            }
        }
        .overlay {
            if viewModel.visibleSummaries.isEmpty && !viewModel.isLoading {
                EstadoVacioClarity(
                    icono: "gift",
                    titulo: String(localized: "Nadie te debe nada"),
                    texto: String(localized: "Marca un gasto como «modo regalo» al crearlo y apunta quién te lo tiene que devolver.")
                )
                .padding(.horizontal, Spacing.md)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

// MARK: - Cabecera de totales

private struct DebtsTotalHeader: View {
    let pending: Double
    let paid: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pendiente de cobrar")
                .estiloEtiquetaClarity()

            Text(Formatters.currency(pending))
                .estiloCifraClarity()
                .contentTransition(.numericText())
                .padding(.top, 4)

            // Cuánto de lo prestado ha vuelto ya, con los mismos dos importes.
            if pending + paid > 0 {
                BarraProgresoClarity(progreso: paid / (pending + paid), color: Color.success)
                    .padding(.top, Spacing.md)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Ya cobrado")
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(Formatters.currency(paid))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(Color.success)
            }
            .font(.footnote)
            .padding(.top, Spacing.xs)
        }
        .padding(20)
        .glassCard(cornerRadius: CornerRadius.xlarge)
    }
}

// MARK: - Un gasto con sus deudores

private struct DebtExpenseSection: View {
    let summary: DebtsViewModel.DebtSummary
    @Bindable var viewModel: DebtsViewModel

    var body: some View {
        Section {
            ForEach(summary.expense.debtors ?? []) { debtor in
                Button {
                    Task {
                        await viewModel.togglePaid(
                            expenseId: summary.expense.id ?? "",
                            debtorId: debtor.id
                        )
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: debtor.isPaid ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(debtor.isPaid ? Color.success : Color.textTertiary)
                            .font(.system(size: 22))

                        Text(debtor.name)
                            .scaledFont(size: 15)
                            .foregroundStyle(debtor.isPaid ? Color.textSecondary : Color.primary)
                            .strikethrough(debtor.isPaid, color: Color.textSecondary)

                        Spacer()

                        Text(Formatters.currency(debtor.amount))
                            .scaledFont(size: 15, weight: .semibold)
                            .monospacedDigit()
                            .foregroundStyle(debtor.isPaid ? Color.textSecondary : Color.clarityPrimary)
                    }
                }
                .buttonStyle(.plain)
            }

            if summary.pending > 0 {
                Button {
                    Task { await viewModel.markAllPaid(expenseId: summary.expense.id ?? "") }
                } label: {
                    Label("Marcar todo como cobrado", systemImage: "checkmark.circle")
                }
                .buttonStyle(.secundarioClarity)
            }
        } header: {
            HStack {
                Text(summary.expense.name)
                Spacer()
                Text(Formatters.shortDisplay(summary.expense.date))
                    .foregroundStyle(Color.textTertiary)
            }
        } footer: {
            HStack {
                Text("Total \(Formatters.currency(summary.expense.amount))")
                Spacer()
                if summary.pending > 0 {
                    Text("Te deben \(Formatters.currency(summary.pending))")
                        .foregroundStyle(Color.clarityPrimary)
                } else {
                    Text("Cobrado")
                        .foregroundStyle(Color.success)
                }
            }
            .monospacedDigit()
        }
    }
}
