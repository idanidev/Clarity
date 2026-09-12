// GastosPage.swift
// Tercera página de la Home: todos los gastos del mes, por categoría (#65).
//
// Es un `List` a propósito: deslizar para borrar, menú contextual y el
// desplazamiento con inercia son del sistema y se comportan como en Mail. El
// vidrio va solo en las cabeceras de categoría —una por categoría, no una por
// gasto— para que una lista larga no arrastre cientos de materiales.

import SwiftUI

struct GastosPage: View {
    @Bindable var viewModel: HomeViewModel
    let onEditar: (Expense) -> Void

    /// Categorías plegadas. Persiste entre sesiones igual que en la lista vieja.
    @State private var plegadas: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "expenses.collapsedCategories") ?? [])

    var body: some View {
        List {
            ForEach(viewModel.categoryGroups) { grupo in
                Section {
                    if !plegadas.contains(grupo.id) {
                        ForEach(grupo.subcategories) { sub in
                            if grupo.subcategories.count > 1 {
                                CabeceraSubcategoria(nombre: sub.name, total: sub.totalAmount)
                                    .fila()
                            }
                            ForEach(sub.expenses, id: \.stableId) { gasto in
                                FilaGasto(gasto: gasto, color: grupo.color)
                                    .fila()
                                    .contentShape(Rectangle())
                                    .onTapGesture { onEditar(gasto) }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteExpense(gasto) }
                                        } label: { Label("Borrar", systemImage: "trash") }
                                        Button { onEditar(gasto) } label: { Label("Editar", systemImage: "pencil") }
                                            .tint(Color.clarityPrimary)
                                    }
                                    .contextMenu {
                                        Button { onEditar(gasto) } label: { Label("Editar", systemImage: "pencil") }
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteExpense(gasto) }
                                        } label: { Label("Borrar", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                } header: {
                    CabeceraCategoria(grupo: grupo, plegada: plegadas.contains(grupo.id)) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if plegadas.contains(grupo.id) { plegadas.remove(grupo.id) } else { plegadas.insert(grupo.id) }
                        }
                        UserDefaults.standard.set(Array(plegadas), forKey: "expenses.collapsedCategories")
                        HapticManager.shared.selection()
                    }
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
            }

            Color.clear.frame(height: 90).fila()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .trackScreen("home_gastos")
    }
}

private extension View {
    /// Fila sin fondo ni separador: la lista pinta solo lo nuestro.
    func fila() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
    }
}

/// Cabecera de categoría: emoji, nombre, total y un chevron que gira al plegar.
private struct CabeceraCategoria: View {
    let grupo: CategoryGroup
    let plegada: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(grupo.color.opacity(0.22))
                    Circle().strokeBorder(grupo.color.opacity(0.5), lineWidth: 0.5)
                    Text(grupo.emoji).font(.system(size: 16))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(grupo.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(grupo.expenseCount == 1 ? "1 gasto" : "\(grupo.expenseCount) gastos")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Formatters.currency(grupo.totalAmount))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(grupo.color)
                    .contentTransition(.numericText(value: grupo.totalAmount))
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(plegada ? -90 : 0))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .glassCard(cornerRadius: CornerRadius.medium)
            .overlay(alignment: .leading) {
                // La barra de color de la lista vieja, que decía la categoría de un vistazo.
                RoundedRectangle(cornerRadius: 2).fill(grupo.color).frame(width: 3).padding(.vertical, 10)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CabeceraSubcategoria: View {
    let nombre: String
    let total: Double

    var body: some View {
        HStack {
            Text(nombre.isEmpty ? "Sin subcategoría" : nombre).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Spacer()
            Text(Formatters.currency(total)).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6).padding(.top, 6)
    }
}

private struct FilaGasto: View {
    let gasto: Expense
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5).fill(color.opacity(0.7)).frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(gasto.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Text("\(Formatters.shortDisplay(gasto.date)) · \(gasto.paymentMethod)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(Formatters.currency(gasto.amount)).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }
}
