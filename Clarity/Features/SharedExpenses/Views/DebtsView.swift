// DebtsView.swift
// "Te deben": quién tiene que devolverte dinero de los gastos en modo regalo (#37).

import SwiftUI

struct DebtsView: View {
    @State private var viewModel: DebtsViewModel
    @State private var showAddExpense = false

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
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(viewModel.visibleSummaries) { summary in
                DebtExpenseSection(summary: summary, viewModel: viewModel)
            }
        }
        .listStyle(.insetGrouped)
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
                SinGastosEmptyView(
                    titulo: "Nadie te debe nada",
                    mensaje: "Marca un gasto como «modo regalo» al crearlo y apunta quién te lo tiene que devolver.",
                    icono: "gift"
                ) { showAddExpense = true }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet {
                Task { await viewModel.load() }
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
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pendiente de cobrar")
                    .scaledFont(size: 12)
                    .foregroundStyle(.secondary)
                Text(Formatters.currency(pending))
                    .scaledFont(size: 28, weight: .bold)
                    .foregroundStyle(Color.clarityPrimary)
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Ya cobrado")
                    .scaledFont(size: 12)
                    .foregroundStyle(.secondary)
                Text(Formatters.currency(paid))
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundStyle(Color.success)
            }
        }
        .padding(Spacing.md)
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
                            .foregroundStyle(debtor.isPaid ? Color.success : Color.secondary)
                            .font(.system(size: 20))

                        Text(debtor.name)
                            .scaledFont(size: 15)
                            .foregroundStyle(.primary)
                            .strikethrough(debtor.isPaid, color: .secondary)

                        Spacer()

                        Text(Formatters.currency(debtor.amount))
                            .scaledFont(size: 15, weight: .semibold)
                            .foregroundStyle(debtor.isPaid ? Color.secondary : Color.clarityPrimary)
                    }
                }
                .buttonStyle(.plain)
            }

            if summary.pending > 0 {
                Button {
                    Task { await viewModel.markAllPaid(expenseId: summary.expense.id ?? "") }
                } label: {
                    Label("Marcar todo como cobrado", systemImage: "checkmark.circle")
                        .scaledFont(size: 14, weight: .medium)
                }
            }
        } header: {
            HStack {
                Text(summary.expense.name)
                Spacer()
                Text(Formatters.shortDisplay(summary.expense.date))
                    .foregroundStyle(.tertiary)
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
        }
    }
}
