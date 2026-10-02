// SacarDeHuchaSheet.swift
// Sacar dinero de una hucha (2.4.2). Lo apartado sigue siendo del usuario: al
// sacarlo vuelve a su dinero libre de este mes, sin pasar por ningún gasto.

import SwiftUI

struct SacarDeHuchaSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goal: Goal
    let onSacar: (Double) -> Void

    @State private var texto = ""
    @FocusState private var enfocado: Bool

    private var importe: Double? {
        Double(texto.replacingOccurrences(of: ",", with: "."))
    }

    /// Lo que hay en la hucha manda: no se puede sacar más.
    private var demasiado: Bool {
        (importe ?? 0) > goal.currentAmount + 0.005
    }

    private var valido: Bool {
        guard let importe else { return false }
        return importe > 0 && !demasiado
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(goal.name)
                        .font(.title3.bold())
                    Text("Hay \(Formatters.currency(goal.currentAmount)) en la hucha")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 8)

                HStack(alignment: .firstTextBaseline) {
                    Text("€")
                        .scaledFont(size: 28, weight: .bold, design: .rounded)
                        .foregroundStyle(Color.textSecondary)
                    TextField("0", text: $texto)
                        .keyboardType(.decimalPad)
                        .scaledFont(size: 44, weight: .bold, design: .rounded)
                        .focused($enfocado)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: CornerRadius.large)

                Button {
                    texto = String(format: "%.2f", goal.currentAmount).replacingOccurrences(of: ".", with: ",")
                    HapticManager.shared.selection()
                } label: {
                    Text("Sacarlo todo")
                }
                .buttonStyle(.secundarioClarity)

                Text(demasiado
                     ? "No hay tanto en la hucha."
                     : "Vuelve a tu dinero libre de este mes. No cuenta como gasto.")
                    .font(.footnote)
                    .foregroundStyle(demasiado ? Color.error : Color.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)

                Button {
                    guard valido, let importe else { return }
                    onSacar(importe)
                    dismiss()
                } label: {
                    if valido, let importe {
                        Text("Sacar \(Formatters.currency(importe))")
                    } else {
                        Text("Sacar")
                    }
                }
                .buttonStyle(.principalClarity)
                .disabled(!valido)
            }
            .padding()
            .fondoClarity()
            .navigationTitle("Sacar dinero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear { enfocado = true }
        }
        .presentationDetents([.medium, .large])
    }
}
