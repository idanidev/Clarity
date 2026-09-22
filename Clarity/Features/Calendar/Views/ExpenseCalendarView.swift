// ExpenseCalendarView.swift
// El calendario de Gráficas: cuánto se gastó cada día del mes y, debajo, la
// semana del día que se toque.
//
// Rehecho en la 2.4.0 con el estilo del resto de la página. El de antes traía
// dos tarjetas oscuras propias dentro del vidrio, sus flechas de mes —que no
// seguían al mes de la cabecera— y un `ScrollView` propio: anidado en el de la
// página, se quedaba el dedo y la página no se desplazaba desde él.

import SwiftUI

struct ExpenseCalendarView: View {
    let expenses: [Expense]
    /// El mes de la cabecera de la Home, el mismo que el resto de la página.
    let mes: Date
    /// El día tocado. Sin ninguno, la semana es la de hoy (o la primera del mes
    /// si se mira otro).
    @State private var elegido: Date?

    private let calendario = Calendar.current
    private static let diasSemana = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
    private let columnas = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let semana = diasDeLaSemana
        let totales = totalesPorDia(semana: semana)
        let maximo = dias.map { totales[clave($0), default: 0] }.max() ?? 0
        let conGasto = dias.filter { totales[clave($0), default: 0] > 0 }.count

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Calendario").font(.subheadline.weight(.semibold))
                Spacer()
                Text(conGasto == 1 ? "1 día con gastos" : "\(conGasto) días con gastos")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            LazyVGrid(columns: columnas, spacing: 4) {
                ForEach(Self.diasSemana, id: \.self) { d in
                    Text(d)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                ForEach(0..<desfase, id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(dias, id: \.self) { dia in
                    let importe = totales[clave(dia), default: 0]
                    CeldaDia(
                        dia: calendario.component(.day, from: dia),
                        importe: importe,
                        intensidad: maximo > 0 ? importe / maximo : 0,
                        esHoy: calendario.isDateInToday(dia),
                        elegido: elegido.map { calendario.isDate($0, inSameDayAs: dia) } ?? false
                    ) {
                        withAnimation(.snappy(duration: AnimationDuration.fast)) {
                            // Tocar otra vez el mismo día vuelve a la semana de hoy.
                            if let e = elegido, calendario.isDate(e, inSameDayAs: dia) {
                                elegido = nil
                            } else {
                                elegido = dia
                            }
                        }
                        HapticManager.shared.selection()
                    }
                }
            }

            SemanaCalendario(
                titulo: tituloSemana(semana),
                dias: semana.enumerated().map { i, dia in
                    (Self.diasSemana[i], totales[clave(dia), default: 0], calendario.isDateInToday(dia))
                }
            )
            .padding(.top, 4)
        }
        .padding(16)
        .onChange(of: mesClave) { _, _ in elegido = nil }
    }

    // MARK: - Fechas

    private var mesClave: String { String(clave(mes).prefix(7)) }

    private var primerDia: Date {
        calendario.date(from: calendario.dateComponents([.year, .month], from: mes)) ?? mes
    }

    private var dias: [Date] {
        let inicio = primerDia
        let cuantos = calendario.range(of: .day, in: .month, for: inicio)?.count ?? 30
        return (0..<cuantos).compactMap { calendario.date(byAdding: .day, value: $0, to: inicio) }
    }

    /// Huecos antes del día 1, con la semana empezando en lunes.
    private var desfase: Int {
        let diaSemana = calendario.component(.weekday, from: primerDia)  // 1 = domingo
        return (diaSemana + 5) % 7
    }

    /// De lunes a domingo, alrededor del día elegido, de hoy o del día 1.
    private var diasDeLaSemana: [Date] {
        let referencia: Date
        if let elegido {
            referencia = elegido
        } else if calendario.isDate(mes, equalTo: Date(), toGranularity: .month) {
            referencia = Date()
        } else {
            referencia = primerDia
        }
        let desdeLunes = (calendario.component(.weekday, from: referencia) + 5) % 7
        let lunes = calendario.date(byAdding: .day, value: -desdeLunes, to: calendario.startOfDay(for: referencia)) ?? referencia
        return (0..<7).compactMap { calendario.date(byAdding: .day, value: $0, to: lunes) }
    }

    private func tituloSemana(_ semana: [Date]) -> String {
        guard let lunes = semana.first, let domingo = semana.last else { return "Semana" }
        if semana.contains(where: calendario.isDateInToday) { return "Esta semana" }
        let mismoMes = calendario.isDate(lunes, equalTo: domingo, toGranularity: .month)
        let desde = mismoMes ? lunes.formatted(.dateTime.day()) : lunes.formatted(.dateTime.day().month(.abbreviated))
        let hasta = domingo.formatted(.dateTime.day().month(.abbreviated))
        return "Semana del \(desde) al \(hasta)"
    }

    private func clave(_ fecha: Date) -> String { Formatters.localDayString(from: fecha) }

    /// Una sola pasada por los gastos: los del mes y los de la semana, que puede
    /// caer a caballo de otro mes.
    private func totalesPorDia(semana: [Date]) -> [String: Double] {
        let prefijo = mesClave
        let clavesSemana = Set(semana.map(clave))
        var totales: [String: Double] = [:]
        for gasto in expenses where gasto.date.hasPrefix(prefijo) || clavesSemana.contains(gasto.date) {
            totales[gasto.date, default: 0] += gasto.amount
        }
        return totales
    }
}

// MARK: - Día

private struct CeldaDia: View {
    let dia: Int
    let importe: Double
    /// 0…1 frente al día más caro del mes: más gasto, más color.
    let intensidad: Double
    let esHoy: Bool
    let elegido: Bool
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            VStack(spacing: 1) {
                Text("\(dia)")
                    .font(.footnote.weight(esHoy ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(esHoy ? Color.white : (importe > 0 ? Color.primary : Color.textSecondary))
                // Siempre ocupa su línea: así todas las celdas miden lo mismo.
                Text(importe > 0 ? Formatters.currencyCompact(importe) : " ")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(esHoy ? Color.white.opacity(0.9) : Color.claritySecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(fondo, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            .overlay {
                if elegido {
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .strokeBorder(Color.clarityPrimary, lineWidth: 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(descripcion)
        .accessibilityHint("Enseña su semana debajo")
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }

    private var fondo: Color {
        if esHoy { return Color.clarityPrimary }
        guard importe > 0 else { return Color.clear }
        return Color.clarityPrimary.opacity(0.12 + 0.28 * min(max(intensidad, 0), 1))
    }

    private var descripcion: String {
        var texto = "Día \(dia)"
        if esHoy { texto += ", hoy" }
        texto += importe > 0 ? ", \(Formatters.currency(importe)) en gastos" : ", sin gastos"
        return texto
    }
}

// MARK: - Semana

private struct SemanaCalendario: View {
    let titulo: String
    let dias: [(etiqueta: String, importe: Double, esHoy: Bool)]

    private let alto: CGFloat = 64

    var body: some View {
        let total = dias.reduce(0) { $0 + $1.importe }
        let maximo = dias.map(\.importe).max() ?? 0
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo).font(.subheadline.weight(.semibold))
                Spacer()
                if total > 0 {
                    Text(Formatters.currency(total))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: total))
                } else {
                    Text("Sin gastos").font(.caption).foregroundStyle(Color.textSecondary)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(dias.enumerated()), id: \.offset) { _, d in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            Capsule().fill(Color.primary.opacity(0.06))
                            if d.importe > 0, maximo > 0 {
                                Capsule()
                                    .fill(Color.clarityPrimary)
                                    .frame(height: max(alto * d.importe / maximo, 6))
                            }
                        }
                        .frame(maxWidth: 18)
                        .frame(height: alto)
                        Text(d.etiqueta)
                            .font(.caption2.weight(d.esHoy ? .semibold : .regular))
                            .foregroundStyle(d.esHoy ? Color.clarityPrimary : Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(d.etiqueta), \(d.importe > 0 ? Formatters.currency(d.importe) : "sin gastos")")
                }
            }
            .animation(.snappy(duration: AnimationDuration.normal), value: dias.map(\.importe))
        }
    }
}

// MARK: - Preview
#Preview {
    ExpenseCalendarView(expenses: [], mes: Date())
        .glassCard()
        .padding()
        .preferredColorScheme(.dark)
}
