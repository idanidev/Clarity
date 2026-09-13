// SeccionFinRecurrente.swift
// Cuándo termina un gasto recurrente: nunca, en una fecha o tras N plazos (#64).
//
// Con plazos, un recurrente sirve para financiaciones: el móvil a 24 meses, la
// matrícula en 3 cuotas. Todo acaba guardado como `endDate`, que el scheduler
// ya respetaba; lo que faltaba era poder ponerlo.

import SwiftUI

enum FinRecurrente: String, CaseIterable, Identifiable {
    case nunca, fecha, plazos
    var id: Self { self }
    var titulo: String {
        switch self {
        case .nunca: "Nunca"
        case .fecha: "Fecha"
        case .plazos: "Plazos"
        }
    }
}

struct SeccionFinRecurrente: View {
    @Binding var fin: FinRecurrente
    @Binding var fecha: Date
    @Binding var plazos: Int
    let importe: Double
    /// Último cargo calculado para los plazos, "yyyy-MM-dd".
    let ultimoCargoPlazos: String

    var body: some View {
        Section {
            Picker("Termina", selection: $fin.animation(.snappy)) {
                ForEach(FinRecurrente.allCases) { Text($0.titulo).tag($0) }
            }
            .pickerStyle(.segmented)

            switch fin {
            case .nunca:
                EmptyView()
            case .fecha:
                DatePicker("Último cargo", selection: $fecha, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.clarityPrimary)
            case .plazos:
                Stepper(value: $plazos, in: 2...360) {
                    HStack {
                        Text("Plazos")
                        Spacer()
                        Text("\(plazos)").fontWeight(.semibold).monospacedDigit()
                            .contentTransition(.numericText(value: Double(plazos)))
                    }
                }
            }
        } header: {
            Text("Final")
        } footer: {
            switch fin {
            case .nunca:
                Text("Se cobra hasta que lo pauses o lo borres.")
            case .fecha:
                Text("No se crea ningún cargo después del \(fecha.formatted(date: .long, time: .omitted)).")
            case .plazos:
                if importe > 0 {
                    Text("\(plazos) × \(Formatters.currency(importe)) = **\(Formatters.currency(importe * Double(plazos)))**. Último cargo el \(Formatters.displayDate(ultimoCargoPlazos)).")
                } else {
                    Text("Último cargo el \(Formatters.displayDate(ultimoCargoPlazos)).")
                }
            }
        }
    }
}
