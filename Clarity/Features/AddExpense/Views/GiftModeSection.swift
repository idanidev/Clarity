// GiftModeSection.swift
// Sección de formulario del "modo regalo": marcas el gasto como adelantado por
// ti y apuntas quién te lo tiene que devolver, por número de personas o por
// nombre (#37).

import SwiftUI

struct GiftModeSection: View {
    @Binding var isShared: Bool
    @Binding var debtors: [Debtor]
    /// Importe total del gasto — se usa para repartir a partes iguales.
    let totalAmount: Double
    var focused: FocusState<AddExpField?>.Binding

    private var owedTotal: Double {
        debtors.reduce(0) { $0 + $1.amount }
    }

    private var exceedsTotal: Bool {
        totalAmount > 0 && owedTotal > totalAmount + 0.001
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { isShared },
                set: { newValue in
                    withAnimation(.easeInOut(duration: AnimationDuration.fast)) {
                        isShared = newValue
                    }
                    if newValue && debtors.isEmpty {
                        addDebtor()
                    }
                    HapticManager.shared.selection()
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Modo regalo")
                        Text("Lo pagas tú y te lo devuelven")
                            .scaledFont(size: 11)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(Color.clarityPrimary)
                }
            }

            if isShared {
                peopleStepper

                ForEach($debtors) { $debtor in
                    DebtorRow(debtor: $debtor, focused: focused)
                }
                .onDelete { offsets in
                    debtors.remove(atOffsets: offsets)
                }

                Button {
                    addDebtor()
                    HapticManager.shared.lightTap()
                } label: {
                    Label("Añadir persona", systemImage: "person.badge.plus")
                        .scaledFont(size: 14, weight: .medium)
                }

                if totalAmount > 0 && !debtors.isEmpty {
                    Button {
                        debtors = debtors.splitEvenly(total: totalAmount)
                        HapticManager.shared.selection()
                    } label: {
                        Label("Repartir a partes iguales", systemImage: "divide.circle")
                            .scaledFont(size: 14, weight: .medium)
                    }
                }

                summaryRow
            }
        } header: {
            Text("Regalo / compartido")
        } footer: {
            if isShared {
                if exceedsTotal {
                    Text("Lo que te deben (\(Formatters.currency(owedTotal))) supera el importe del gasto (\(Formatters.currency(totalAmount))).")
                        .foregroundStyle(Color.error)
                } else {
                    Text("Indica cuántos sois o escribe los nombres. Puedes marcar a cada uno cuando te pague.")
                }
            }
        }
    }

    private var peopleStepper: some View {
        Stepper(
            value: Binding(
                get: { debtors.count },
                set: { setPeopleCount($0) }
            ),
            in: 0...20
        ) {
            HStack {
                Text("Personas que te deben")
                    .scaledFont(size: 14)
                Spacer()
                Text("\(debtors.count)")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(Color.clarityPrimary)
                    .contentTransition(.numericText())
            }
        }
    }

    private var summaryRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Te deben")
                    .scaledFont(size: 11)
                    .foregroundStyle(.secondary)
                Text(Formatters.currency(debtors.pendingAmount))
                    .scaledFont(size: 16, weight: .bold)
                    .foregroundStyle(Color.clarityPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Te cuesta a ti")
                    .scaledFont(size: 11)
                    .foregroundStyle(.secondary)
                Text(Formatters.currency(max(0, totalAmount - owedTotal)))
                    .scaledFont(size: 16, weight: .bold)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func addDebtor() {
        debtors.append(
            Debtor(name: Debtor.placeholderName(index: debtors.count), amount: 0)
        )
    }

    /// El stepper permite decir "somos 4" sin escribir nombres: rellena o recorta
    /// la lista manteniendo lo que el usuario ya haya tecleado.
    private func setPeopleCount(_ count: Int) {
        let clamped = max(0, min(20, count))
        if clamped > debtors.count {
            for index in debtors.count..<clamped {
                debtors.append(Debtor(name: Debtor.placeholderName(index: index), amount: 0))
            }
        } else if clamped < debtors.count {
            debtors.removeLast(debtors.count - clamped)
        }
    }
}

// MARK: - Fila de deudor

private struct DebtorRow: View {
    @Binding var debtor: Debtor
    var focused: FocusState<AddExpField?>.Binding

    /// Texto crudo del importe: evita reparsear Double↔String en cada tecla.
    @State private var amountText: String = ""

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Button {
                debtor.isPaid.toggle()
                HapticManager.shared.selection()
            } label: {
                Image(systemName: debtor.isPaid ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(debtor.isPaid ? Color.success : Color.secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(debtor.isPaid ? "Marcado como pagado" : "Marcar como pagado")

            TextField("Nombre", text: $debtor.name)
                .textInputAutocapitalization(.words)
                .focused(focused, equals: .debtorName(debtor.id))
                .scaledFont(size: 15)

            TextField("0,00", text: $amountText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .focused(focused, equals: .debtorAmount(debtor.id))
                .scaledFont(size: 15, weight: .semibold)
                .onChange(of: amountText) { _, newValue in
                    debtor.amount = Double(newValue.replacingOccurrences(of: ",", with: ".")) ?? 0
                }

            Text("€")
                .scaledFont(size: 13)
                .foregroundStyle(.secondary)
        }
        .opacity(debtor.isPaid ? 0.55 : 1)
        .onAppear {
            // El reparto automático escribe en `amount`; el campo se sincroniza
            // al aparecer y cuando cambia desde fuera.
            amountText = debtor.amount > 0 ? String(format: "%.2f", debtor.amount) : ""
        }
        .onChange(of: debtor.amount) { _, newValue in
            let rendered = newValue > 0 ? String(format: "%.2f", newValue) : ""
            if Double(amountText.replacingOccurrences(of: ",", with: ".")) != newValue {
                amountText = rendered
            }
        }
    }
}
