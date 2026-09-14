// RecurringExpensesView.swift
// Gastos recurrentes: lo que cuestan al mes, lo que viene y lo que va a plazos (#64, #65).
//
// Antes era una lista agrupada con un interruptor y hasta tres etiquetas por
// fila, que en pantallas estrechas partían "Mensual" en dos líneas. Ahora arriba
// está lo que se quiere saber de un vistazo —cuánto al mes y cuánto queda por
// cobrar este mes—, luego lo que viene, luego lo que va a plazos con su
// progreso, y cada regla en una tarjeta con una sola línea de detalle. Pausar y
// borrar están al deslizar y al mantener pulsado, como en la lista de gastos.

import FirebaseAuth
import SwiftUI

struct RecurringExpensesView: View {
    private let repository = DependencyContainer.shared.recurringExpenseRepository
    @State private var expenses: [RecurringExpense] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    /// Lo que se tocó para abrir el detalle: "regla|<stableId>" desde una
    /// tarjeta o "cargo|<stableId>|<fecha>" desde una ficha de próximos. La
    /// misma regla puede estar a la vez en los dos sitios y el zoom tiene que
    /// salir del que se tocó, así que el id no puede ser solo el `stableId`.
    @State private var detalleId: String?
    @Namespace private var zoom

    var body: some View {
        Group {
            if isLoading {
                CargaClarity(texto: "Cargando tus recurrentes")
            } else if expenses.isEmpty {
                emptyState
            } else {
                lista(Clasificacion(expenses, hoy: Date()))
            }
        }
        .fondoClarity()
        .navigationTitle("Gastos Recurrentes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Añadir gasto recurrente")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddRecurringExpenseSheet {
                loadExpenses()
            }
        }
        .navigationDestination(item: $detalleId) { id in
            // El segundo trozo del id es el `stableId` de la regla.
            let partes = id.split(separator: "|", omittingEmptySubsequences: false)
            if partes.count >= 2, let regla = expenses.first(where: { $0.stableId == String(partes[1]) }) {
                RecurringExpenseDetailView(expense: regla) {
                    loadExpenses()
                }
                .transicionZoom(id: id, en: zoom)
            }
        }
        .task {
            loadExpenses()
            // Recuperar gastos perdidos al abrir la vista
            await LocalRecurringExpenseManager.shared.recoverMissedExpenses()
        }
        .refreshable {
            loadExpenses()
            await LocalRecurringExpenseManager.shared.recoverMissedExpenses()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sin gastos recurrentes", systemImage: "repeat.circle")
        } description: {
            Text("Suscripciones, el alquiler, el gimnasio o una compra a plazos: apúntalos una vez y se cargan solos.")
        } actions: {
            Button("Añadir gasto recurrente") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.clarityPrimary)
        }
    }

    // MARK: - Lista

    private func lista(_ c: Clasificacion) -> some View {
        let hoy = Date()
        let enMarcha = c.activas + c.aPlazos.map(\.regla)
        let proximos = CalculoRecurrentes.proximosCargos(enMarcha, hoy: hoy)
        return List {
            ResumenRecurrentes(reglas: enMarcha, hoy: hoy)
                .filaRecurrente(arriba: 4, abajo: 6)

            if !proximos.isEmpty {
                CabeceraSeccion(titulo: "Próximos cargos", detalle: "45 días")
                    .filaRecurrente(arriba: 12, abajo: 2)
                carruselProximos(proximos)
            }

            if !c.aPlazos.isEmpty {
                let quedan = c.aPlazos.reduce(0) { $0 + Double($1.total - $1.hechos) * $1.regla.amount }
                CabeceraSeccion(titulo: "A plazos", detalle: "quedan \(Formatters.currency(quedan))")
                    .filaRecurrente(arriba: 12, abajo: 2)
                ForEach(c.aPlazos) { plan in
                    tarjeta(plan.regla) { FilaPlazos(plan: plan) }
                }
            }

            if !c.activas.isEmpty {
                CabeceraSeccion(titulo: "Activos", detalle: "\(c.activas.count)")
                    .filaRecurrente(arriba: 12, abajo: 2)
                ForEach(c.activas, id: \.stableId) { regla in
                    tarjeta(regla) { FilaRecurrente(regla: regla, estado: .activa) }
                }
            }

            if !c.pausadas.isEmpty {
                CabeceraSeccion(titulo: "Pausados", detalle: "no se cargan")
                    .filaRecurrente(arriba: 12, abajo: 2)
                ForEach(c.pausadas, id: \.stableId) { regla in
                    tarjeta(regla) { FilaRecurrente(regla: regla, estado: .pausada) }
                }
            }

            if !c.terminadas.isEmpty {
                CabeceraSeccion(titulo: "Terminados", detalle: nil)
                    .filaRecurrente(arriba: 12, abajo: 2)
                ForEach(c.terminadas, id: \.stableId) { regla in
                    tarjeta(regla) { FilaRecurrente(regla: regla, estado: .terminada) }
                }
            }

            Text("Se cargan solos el día indicado. Desliza una tarjeta para pausarla o borrarla.")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .filaRecurrente(arriba: 14, abajo: 16)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    /// Lo que viene, a lo ancho: una ficha por cargo con su día.
    private func carruselProximos(_ proximos: [CargoProximo]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Spacing.xs) {
                ForEach(proximos) { cargo in
                    let idZoom = "cargo|\(cargo.regla.stableId)|\(cargo.fecha)"
                    Button { detalleId = idZoom } label: {
                        TarjetaCargo(cargo: cargo)
                            .origenZoom(id: idZoom, en: zoom)
                    }
                    .buttonStyle(TarjetaButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sinHuecoBarraInferior()
        .filaRecurrente(arriba: 4, abajo: 4, lados: 0)
    }

    /// Cada regla es una tarjeta que abre su detalle, con pausar y borrar al
    /// deslizar y al mantener pulsado.
    private func tarjeta<Contenido: View>(_ regla: RecurringExpense, @ViewBuilder contenido: () -> Contenido) -> some View {
        let idZoom = "regla|\(regla.stableId)"
        return Button { detalleId = idZoom } label: {
            contenido()
                .origenZoom(id: idZoom, en: zoom)
        }
        .buttonStyle(TarjetaButtonStyle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { alternar(regla) } label: {
                Label(regla.active ? "Pausar" : "Reanudar", systemImage: regla.active ? "pause.fill" : "play.fill")
            }
            .tint(regla.active ? Color.clarityPrimary : Color.success)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { borrar(regla) } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
        .contextMenu {
            Button { detalleId = idZoom } label: {
                Label("Ver detalle", systemImage: "info.circle")
            }
            Button { alternar(regla) } label: {
                Label(regla.active ? "Pausar" : "Reanudar", systemImage: regla.active ? "pause" : "play")
            }
            Button(role: .destructive) { borrar(regla) } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
        .filaRecurrente()
    }

    // MARK: - Datos

    private func loadExpenses() {
        Task {
            // Esperar auth en simulador (Keychain tarda más)
            if Auth.auth().currentUser == nil {
                for _ in 0..<5 {
                    try? await Task.sleep(for: .milliseconds(300))
                    if Auth.auth().currentUser != nil { break }
                }
            }
            do {
                expenses = try await repository.fetchAll()
            } catch {
                // Load errors surface via empty state in View
            }
            isLoading = false
        }
    }

    private func alternar(_ regla: RecurringExpense) {
        guard let id = regla.id else { return }

        // Optimistic update
        if let index = expenses.firstIndex(where: { $0.id == id }) {
            withAnimation(.snappy) {
                expenses[index].active.toggle()
            }
        }

        Task {
            do {
                try await repository.toggleActive(id: id, active: !regla.active)
                HapticManager.shared.impact(.light)
            } catch {
                // Revert on error
                if let index = expenses.firstIndex(where: { $0.id == id }) {
                    expenses[index].active.toggle()
                }
                HapticManager.shared.notification(.error)
            }
        }
    }

    private func borrar(_ regla: RecurringExpense) {
        guard let id = regla.id else { return }

        // Optimistic remove
        withAnimation(.snappy) {
            expenses.removeAll { $0.id == id }
        }

        Task {
            do {
                try await repository.delete(id: id)
                HapticManager.shared.notification(.success)
            } catch {
                loadExpenses() // Reload to restore
            }
        }
    }
}

// MARK: - Clasificación

/// Un plan a plazos en curso.
private struct Plan: Identifiable {
    let regla: RecurringExpense
    let hechos: Int
    let total: Int
    var id: String { regla.stableId }
}

/// Las reglas repartidas por lo que le importan a quien las mira.
private struct Clasificacion {
    var aPlazos: [Plan] = []
    var activas: [RecurringExpense] = []
    var pausadas: [RecurringExpense] = []
    /// Planes con todos los plazos cobrados. Se desactivan solos al día
    /// siguiente del último cargo; hasta entonces ya se enseñan aquí.
    var terminadas: [RecurringExpense] = []

    init(_ reglas: [RecurringExpense], hoy: Date) {
        for regla in reglas.sorted(by: { $0.dayOfMonth < $1.dayOfMonth }) {
            if let p = RecurringScheduler.plazos(de: regla, hoy: hoy) {
                if p.hechos >= p.total {
                    terminadas.append(regla)
                } else if regla.active {
                    aPlazos.append(Plan(regla: regla, hechos: p.hechos, total: p.total))
                } else {
                    pausadas.append(regla)
                }
            } else if regla.active {
                activas.append(regla)
            } else {
                pausadas.append(regla)
            }
        }
    }
}

/// Un cargo concreto que está por venir.
private struct CargoProximo: Identifiable {
    let regla: RecurringExpense
    /// "yyyy-MM-dd".
    let fecha: String
    var id: String { regla.stableId + fecha }
}

private enum CalculoRecurrentes {
    /// Lo que cuesta una regla repartido por meses: un anual de 120 € son 10 €.
    static func alMes(_ regla: RecurringExpense) -> Double {
        regla.amount / Double(RecurringScheduler.mesesEntreCargos(regla.frequency))
    }

    /// La fecha fin como "yyyy-MM-dd", o `nil` si no tiene. Hay reglas guardadas
    /// con `endDate` vacío: tomado como tope, "" es menor que cualquier fecha y
    /// les quitaba todos los cargos —Gympass y Spotify no salían en próximos—.
    static func fin(_ regla: RecurringExpense) -> String? {
        guard let fin = regla.endDate, fin.count >= 10 else { return nil }
        return String(fin.prefix(10))
    }

    /// Los cargos de hoy en adelante, hasta 45 días, en orden.
    static func proximosCargos(_ reglas: [RecurringExpense], hoy: Date, calendar: Calendar = .current) -> [CargoProximo] {
        let hoyTexto = Formatters.localDayString(from: hoy)
        let limite = Formatters.localDayString(from: calendar.date(byAdding: .day, value: 45, to: hoy) ?? hoy)
        return reglas
            .filter(\.isValid)
            .flatMap { regla -> [CargoProximo] in
                let tope = Self.fin(regla).map { min($0, limite) } ?? limite
                return RecurringScheduler.fechasDeCargo(
                    frecuencia: regla.frequency, dia: regla.dayOfMonth, billingMonth: regla.billingMonth,
                    desde: hoy, hasta: tope, limite: 3, calendar: calendar
                )
                .filter { $0 >= hoyTexto }
                .map { CargoProximo(regla: regla, fecha: $0) }
            }
            .sorted { ($0.fecha, $0.regla.name) < ($1.fecha, $1.regla.name) }
    }

    /// Lo que se carga este mes: lo ya cobrado hasta hoy y lo que falta.
    static func cargosDelMes(_ reglas: [RecurringExpense], hoy: Date, calendar: Calendar = .current) -> (cobrado: Double, pendiente: Double) {
        guard let inicio = calendar.date(from: calendar.dateComponents([.year, .month], from: hoy)),
              let fin = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: inicio)
        else { return (0, 0) }
        let hoyTexto = Formatters.localDayString(from: hoy)
        let finTexto = Formatters.localDayString(from: fin)
        var cobrado = 0.0
        var pendiente = 0.0
        for regla in reglas where regla.isValid {
            let tope = Self.fin(regla).map { min($0, finTexto) } ?? finTexto
            guard let fecha = RecurringScheduler.fechasDeCargo(
                frecuencia: regla.frequency, dia: regla.dayOfMonth, billingMonth: regla.billingMonth,
                desde: inicio, hasta: tope, limite: 1, calendar: calendar
            ).first else { continue }
            if fecha <= hoyTexto { cobrado += regla.amount } else { pendiente += regla.amount }
        }
        return (cobrado, pendiente)
    }
}

/// "yyyy-MM-dd" como medianoche local. `Formatters.date(from:)` da medianoche
/// UTC, que al oeste de Greenwich cae en el día anterior.
private func fechaLocal(_ texto: String) -> Date? {
    let partes = texto.prefix(10).split(separator: "-").compactMap { Int($0) }
    guard partes.count == 3 else { return nil }
    return Calendar.current.date(from: DateComponents(year: partes[0], month: partes[1], day: partes[2]))
}

private extension RecurringExpense {
    /// El icono elegido; si no hay, el emoji de la categoría.
    var emojiVisible: String {
        if let icon, !icon.isEmpty { return icon }
        let emoji = category.soloEmoji
        return emoji.isEmpty ? "💰" : emoji
    }
}

// MARK: - Piezas

/// Cabecera: cuánto cuesta todo al mes y cómo va el mes en curso.
private struct ResumenRecurrentes: View {
    let reglas: [RecurringExpense]
    let hoy: Date

    var body: some View {
        let alMes = reglas.reduce(0) { $0 + CalculoRecurrentes.alMes($1) }
        let mes = CalculoRecurrentes.cargosDelMes(reglas, hoy: hoy)
        let totalMes = mes.cobrado + mes.pendiente

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AL MES")
                    .font(.caption2.weight(.medium))
                    .tracking(0.7)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(reglas.count == 1 ? "1 en marcha" : "\(reglas.count) en marcha")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.clarityPrimary)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.clarityPrimary.opacity(0.16), in: Capsule())
            }

            Text(Formatters.currency(alMes))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .tracking(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: alMes))
                .padding(.top, 4)

            Text("\(Formatters.currency(alMes * 12)) al año")
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)

            if totalMes > 0 {
                BarraProgreso(progreso: mes.cobrado / totalMes, color: .clarityPrimary)
                    .padding(.top, 16)
                HStack {
                    Text("Cobrado \(Formatters.currency(mes.cobrado))")
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(mes.pendiente > 0 ? "Quedan \(Formatters.currency(mes.pendiente)) este mes" : "Todo cobrado este mes")
                        .foregroundStyle(mes.pendiente > 0 ? Color.primary : Color.success)
                        .fontWeight(.medium)
                }
                .font(.footnote)
                .padding(.top, 8)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: CornerRadius.xlarge)
        .accessibilityElement(children: .combine)
    }
}

/// Un cargo que viene: día grande, cuándo, quién y cuánto.
private struct TarjetaCargo: View {
    let cargo: CargoProximo

    var body: some View {
        let fecha = fechaLocal(cargo.fecha)
        let cal = Calendar.current
        let esHoy = fecha.map { cal.isDateInToday($0) } ?? false
        let cuando: String = {
            guard let fecha else { return "" }
            if esHoy { return "Hoy" }
            if cal.isDateInTomorrow(fecha) { return "Mañana" }
            return fecha.formatted(.dateTime.weekday(.wide))
        }()

        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(fecha.map { String(cal.component(.day, from: $0)) } ?? "")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(fecha?.formatted(.dateTime.month(.abbreviated)) ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            Text(cuando.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(esHoy ? Color.clarityPrimary : Color.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                EmojiRecurrente(regla: cargo.regla, tamano: 24)
                Text(cargo.regla.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
            }
            Text(Formatters.currency(cargo.regla.amount))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .padding(.top, 4)
        }
        .padding(12)
        .frame(width: 132, height: 146, alignment: .topLeading)
        .glassCard(cornerRadius: CornerRadius.large, tint: esHoy ? Color.clarityPrimary : nil, interactivo: true)
        .accessibilityElement(children: .combine)
    }
}

/// Una regla normal: emoji, nombre, frecuencia y día, e importe.
private struct FilaRecurrente: View {
    enum Estado { case activa, pausada, terminada }

    let regla: RecurringExpense
    let estado: Estado

    private var detalle: String {
        if regla.dayOfMonth == 0 { return "Falta el día de cobro" }
        if regla.frequency.needsMonthSelection {
            guard regla.billingMonth > 0 else { return "Falta el mes de cobro" }
            return "\(regla.frequency.displayName) · \(regla.dayOfMonth) \(Formatters.shortMonthName(regla.billingMonth).lowercased())"
        }
        return "\(regla.frequency.displayName) · día \(regla.dayOfMonth)"
    }

    var body: some View {
        HStack(spacing: 12) {
            EmojiRecurrente(regla: regla)
                .saturation(estado == .activa ? 1 : 0.25)

            VStack(alignment: .leading, spacing: 3) {
                Text(regla.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if !regla.isValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                    } else if estado == .terminada {
                        Image(systemName: "checkmark.seal.fill")
                    } else if estado == .pausada {
                        Image(systemName: "pause.circle.fill")
                    }
                    Text(estado == .terminada ? "Todos los plazos pagados" : detalle)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(!regla.isValid ? Color.error : (estado == .terminada ? Color.success : Color.textSecondary))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Formatters.currency(regla.amount))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                if regla.frequency != .monthly {
                    Text("≈ \(Formatters.currency(CalculoRecurrentes.alMes(regla)))/mes")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .opacity(estado == .activa ? 1 : 0.62)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: CornerRadius.large, interactivo: true)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Pulsa para ver el detalle. Desliza para pausar o borrar.")
    }
}

/// Un plan a plazos: por qué plazo va, cuánto queda y cuándo acaba.
private struct FilaPlazos: View {
    let plan: Plan

    var body: some View {
        let regla = plan.regla
        let quedan = Double(plan.total - plan.hechos) * regla.amount

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                EmojiRecurrente(regla: regla)
                VStack(alignment: .leading, spacing: 3) {
                    Text(regla.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text("Plazo \(plan.hechos) de \(plan.total)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Formatters.currency(regla.amount))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    Text("quedan \(Formatters.currency(quedan))")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
            }

            BarraProgreso(
                progreso: Double(plan.hechos) / Double(max(plan.total, 1)),
                color: UserDataManager.shared.color(for: regla.category)
            )

            if let fin = regla.endDate, let fecha = fechaLocal(fin) {
                Text("Último cargo el \(fecha.formatted(.dateTime.day().month(.wide).year()))")
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: CornerRadius.large, interactivo: true)
        .accessibilityElement(children: .combine)
    }
}

/// El emoji de la regla en un círculo del color de su categoría, como en la Home.
private struct EmojiRecurrente: View {
    let regla: RecurringExpense
    var tamano: CGFloat = 44

    var body: some View {
        let color = UserDataManager.shared.color(for: regla.category)
        ZStack {
            Circle().fill(color.opacity(0.22))
            Circle().strokeBorder(color.opacity(0.5), lineWidth: 0.5)
            // Hay iconos guardados con más de un emoji: encogen para caber en
            // el círculo en vez de cortarse con puntos suspensivos.
            Text(regla.emojiVisible)
                .font(.system(size: tamano * 0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(tamano * 0.12)
        }
        .frame(width: tamano, height: tamano)
    }
}

private struct BarraProgreso: View {
    let progreso: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(max(progreso, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

private struct CabeceraSeccion: View {
    let titulo: String
    let detalle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            if let detalle {
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 6)
        .accessibilityAddTraits(.isHeader)
    }
}

private extension View {
    /// Fila sin fondo ni separador: la lista solo pinta las tarjetas.
    func filaRecurrente(arriba: CGFloat = 5, abajo: CGFloat = 5, lados: CGFloat = Spacing.sm) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: arriba, leading: lados, bottom: abajo, trailing: lados))
    }
}

#Preview {
    NavigationStack {
        RecurringExpensesView()
    }
}
