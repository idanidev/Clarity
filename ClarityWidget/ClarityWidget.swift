// ClarityWidget.swift — Widget Extension Target
// Supports: Small, Medium, Large, Lock Screen Circular/Rectangular/Inline
//
// Estilo nuevo (#65): el de la app. Fondo negro con el brillo violeta arriba,
// etiquetas en mayúsculas pequeñas, cifras redondeadas, tarjetas de vidrio,
// importes como "34,50 €" y el "+" como círculo de marca. Los widgets de la
// pantalla bloqueada los pinta el sistema en monocromo y siguen como estaban.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Group

private let kAppGroupID = "group.com.idanidev.clarity"
private let kWidgetKey  = "widgetData_v2"

// MARK: - Timeline Entry

struct ClarityEntry: TimelineEntry {
    let date: Date
    let data: SharedWidgetData
}

// MARK: - Timeline Provider

struct ClarityProvider: TimelineProvider {

    func placeholder(in context: Context) -> ClarityEntry {
        ClarityEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClarityEntry) -> Void) {
        completion(ClarityEntry(date: .now, data: load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClarityEntry>) -> Void) {
        let entry      = ClarityEntry(date: .now, data: load() ?? .placeholder)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func load() -> SharedWidgetData? {
        guard
            let defaults = UserDefaults(suiteName: kAppGroupID),
            let raw      = defaults.data(forKey: kWidgetKey),
            let decoded  = try? JSONDecoder().decode(SharedWidgetData.self, from: raw)
        else { return nil }
        return decoded
    }
}

// MARK: - Widget Definition

struct ClaritySpendingWidget: Widget {
    let kind = "ClaritySpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClarityProvider()) { entry in
            ClarityWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Clarity · Gastos")
        .description("Resumen de tus gastos diarios y mensuales.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Entry View Router

struct ClarityWidgetEntryView: View {
    let entry: ClarityEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        // Estado vacío: usuario sin gastos → CTA en lugar del dashboard
        if entry.data.isEmpty, family == .systemSmall || family == .systemMedium || family == .systemLarge {
            EmptyWidgetView(family: family)
                .containerBackground(for: .widget) { WidgetGradientBackground() }
        } else {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
                .containerBackground(for: .widget) { WidgetGradientBackground() }
        case .systemMedium:
            MediumWidgetView(data: entry.data)
                .containerBackground(for: .widget) { WidgetGradientBackground() }
        case .systemLarge:
            LargeWidgetView(data: entry.data)
                .containerBackground(for: .widget) { WidgetGradientBackground() }
        case .accessoryCircular:
            LockScreenCircularView(data: entry.data)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            LockScreenRectangularView(data: entry.data)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            LockScreenInlineView(data: entry.data)
                .containerBackground(for: .widget) { Color.clear }
        default:
            SmallWidgetView(data: entry.data)
                .containerBackground(for: .widget) { WidgetGradientBackground() }
        }
        }  // close else
    }
}

// MARK: - Estilo

/// Los colores del estilo nuevo, repetidos aquí: el widget es otro target y no
/// ve `Color.clarityPrimary` ni el resto de tokens de la app.
enum EstiloWidget {
    /// #8B5CF6, el `clarityPrimary` de la app.
    static let marca = Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255)
    /// #10B981, `success`.
    static let exito = Color(red: 0x10 / 255, green: 0xB9 / 255, blue: 0x81 / 255)
    /// #F59E0B, `warning`.
    static let aviso = Color(red: 0xF5 / 255, green: 0x9E / 255, blue: 0x0B / 255)
    /// #EF4444, `error`.
    static let error = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    static let textoSecundario = Color.white.opacity(0.7)
    static let textoTerciario = Color.white.opacity(0.42)
}

extension Color {
    // Los nombres de siempre, ya con la paleta de la app.
    static let wPurple = EstiloWidget.marca
    static let wIndigo = EstiloWidget.marca
    static let wGreen  = EstiloWidget.exito
    static let wOrange = EstiloWidget.aviso
    static let wRed    = EstiloWidget.error

    static func budgetAccent(for pct: Double) -> Color {
        if pct < 0.60 { return .wGreen }
        if pct < 0.85 { return .wOrange }
        return .wRed
    }
}

/// Importes como en la app: "34,50 €" y no "€34.50".
@MainActor
enum FormatoWidget {
    private static let euros: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    /// Con `sinDecimales` queda "1004 €": para los datos pequeños, donde los
    /// céntimos no caben.
    static func importe(_ valor: Double, simbolo: String = "€", sinDecimales: Bool = false) -> String {
        euros.currencySymbol = simbolo
        euros.minimumFractionDigits = sinDecimales ? 0 : 2
        euros.maximumFractionDigits = sinDecimales ? 0 : 2
        return euros.string(from: NSNumber(value: valor)) ?? "\(valor) \(simbolo)"
    }
}

extension String {
    /// El nombre sin sus emojis. Las categorías llegan como "Vivienda🏡" y el
    /// emoji ya se enseña aparte: sin esto salía dos veces.
    var sinEmojiWidget: String {
        var escalares = String.UnicodeScalarView()
        for escalar in unicodeScalars {
            let propiedades = escalar.properties
            // Los dígitos y "#" o "*" también cuentan como emoji: se conservan.
            let esEmoji = propiedades.isEmojiPresentation
                || (propiedades.isEmoji && escalar.value > 0x238C)
                || escalar.value == 0xFE0F || escalar.value == 0x200D
            if !esEmoji { escalares.append(escalar) }
        }
        let limpio = String(escalares).trimmingCharacters(in: .whitespaces)
        return limpio.isEmpty ? self : limpio
    }
}

// MARK: - Piezas

/// Etiqueta en mayúsculas pequeñas, como "GASTADO ESTE MES" en la Home.
struct EtiquetaWidget: View {
    let texto: String
    var tamano: CGFloat = 10

    var body: some View {
        Text(texto.uppercased())
            .font(.system(size: tamano, weight: .medium))
            .tracking(0.7)
            .foregroundStyle(EstiloWidget.textoSecundario)
            .lineLimit(1)
    }
}

/// La cifra protagonista, redondeada y en negrita.
struct CifraWidget: View {
    let texto: String
    let tamano: CGFloat

    var body: some View {
        Text(texto)
            .font(.system(size: tamano, weight: .bold, design: .rounded))
            .tracking(tamano >= 26 ? -1 : -0.4)
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .widgetAccentable()
    }
}

/// El "+" de la app: círculo de marca con el signo en blanco.
struct BotonAnadirWidget: View {
    var tamano: CGFloat = 30

    var body: some View {
        Button(intent: OpenAddExpenseIntent()) {
            ZStack {
                Circle().fill(EstiloWidget.marca)
                Image(systemName: "plus")
                    .font(.system(size: tamano * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: tamano, height: tamano)
            .widgetAccentable()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Añadir gasto")
    }
}

/// El emoji en un círculo de marca, como las categorías de la app.
struct EmojiWidget: View {
    let emoji: String
    var tamano: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(EstiloWidget.marca.opacity(0.22))
            Circle().strokeBorder(EstiloWidget.marca.opacity(0.5), lineWidth: 0.5)
            Text(emoji)
                .font(.system(size: tamano * 0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: tamano, height: tamano)
    }
}

extension View {
    /// La tarjeta de vidrio de la app en versión widget: velo claro y borde fino.
    func tarjetaWidget(radio: CGFloat = 16) -> some View {
        let forma = RoundedRectangle(cornerRadius: radio, style: .continuous)
        return self
            .background(Color.white.opacity(0.06), in: forma)
            .overlay(forma.strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

// MARK: - Empty State

struct EmptyWidgetView: View {
    let family: WidgetFamily

    private var pequeno: Bool { family == .systemSmall }

    var body: some View {
        VStack(spacing: pequeno ? 8 : 12) {
            ZStack {
                Circle().fill(EstiloWidget.marca)
                Image(systemName: "plus")
                    .font(.system(size: pequeno ? 20 : 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: pequeno ? 44 : 56, height: pequeno ? 44 : 56)
            .widgetAccentable()

            VStack(spacing: 4) {
                Text("Sin gastos aún")
                    .font(.system(size: pequeno ? 14 : 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(pequeno ? "Toca para añadir" : "Toca + para registrar tu primer gasto")
                    .font(.system(size: pequeno ? 11 : 12))
                    .foregroundStyle(EstiloWidget.textoSecundario)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "clarity://add-expense"))
    }
}

// MARK: - Background

/// El fondo de la app: negro con un brillo violeta arriba que se apaga.
struct WidgetGradientBackground: View {
    var body: some View {
        ZStack {
            Color.black
            EllipticalGradient(
                colors: [EstiloWidget.marca.opacity(0.5), EstiloWidget.marca.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadiusFraction: 0,
                endRadiusFraction: 0.8
            )
        }
    }
}

// MARK: ─────────────────────────────────────────
// MARK: SMALL WIDGET  (2×2)
// MARK: ─────────────────────────────────────────

struct SmallWidgetView: View {
    let data: SharedWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                HStack(spacing: 5) {
                    EtiquetaWidget(texto: "Hoy")
                    Text(data.topCategoryEmoji)
                        .font(.system(size: 12))
                }
                .padding(.top, 6)
                Spacer(minLength: 4)
                BotonAnadirWidget(tamano: 28)
            }

            CifraWidget(texto: FormatoWidget.importe(data.todayTotal, simbolo: data.currency), tamano: 30)
                .padding(.top, 2)

            Spacer(minLength: 6)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                MiniStatView(label: "Semana", value: FormatoWidget.importe(data.weekTotal, simbolo: data.currency, sinDecimales: true))
                Spacer(minLength: 4)
                MiniStatView(label: "Mes", value: FormatoWidget.importe(data.monthTotal, simbolo: data.currency, sinDecimales: true), alineacion: .trailing)
            }

            if let pct = data.budgetPercent {
                BudgetBarView(percent: pct, showLabel: false, height: 4)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hoy \(data.formattedToday), semana \(data.formattedWeek)")
    }
}

// MARK: ─────────────────────────────────────────
// MARK: MEDIUM WIDGET  (4×2)
// MARK: ─────────────────────────────────────────

struct MediumWidgetView: View {
    let data: SharedWidgetData

    var body: some View {
        HStack(spacing: 10) {

            // Izquierda: lo de hoy en grande, semana y mes debajo. Ancho fijo:
            // a partes iguales, la tarjeta de la derecha cortaba los nombres.
            VStack(alignment: .leading, spacing: 0) {
                EtiquetaWidget(texto: data.monthName)

                Spacer(minLength: 4)

                EtiquetaWidget(texto: "Hoy", tamano: 9)
                CifraWidget(texto: FormatoWidget.importe(data.todayTotal, simbolo: data.currency), tamano: 28)
                    .padding(.top, 1)

                Spacer(minLength: 6)

                HStack(spacing: 12) {
                    MiniStatView(label: "Semana", value: FormatoWidget.importe(data.weekTotal, simbolo: data.currency, sinDecimales: true))
                    MiniStatView(label: "Mes", value: FormatoWidget.importe(data.monthTotal, simbolo: data.currency, sinDecimales: true))
                }

                if let pct = data.budgetPercent {
                    BudgetBarView(percent: pct, showLabel: false)
                        .padding(.top, 8)
                }
            }
            .frame(width: 128, alignment: .leading)

            // Derecha: últimos gastos en una tarjeta, con el "+" arriba
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 4) {
                    EtiquetaWidget(texto: "Últimos", tamano: 9)
                    Spacer(minLength: 4)
                    BotonAnadirWidget(tamano: 24)
                }
                ForEach(data.recentExpenses.prefix(3)) { expense in
                    ExpenseRowView(expense: expense, compact: true, simbolo: data.currency)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .tarjetaWidget()
        }
    }
}

// MARK: ─────────────────────────────────────────
// MARK: LARGE WIDGET  (4×4)
// MARK: ─────────────────────────────────────────

struct LargeWidgetView: View {
    let data: SharedWidgetData

    var body: some View {
        // Todo tiene que caber en el grande de un iPhone de 6,1": el mes y el
        // "+" van dentro de la tarjeta principal, las categorías en una fila de
        // fichas y los últimos gastos son cuatro si caben y tres si no.
        VStack(alignment: .leading, spacing: 8) {
            tarjetaPrincipal

            if !data.topMonthCategories.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    EtiquetaWidget(texto: "Top categorías", tamano: 9)
                    HStack(spacing: 6) {
                        ForEach(data.topMonthCategories.prefix(3)) { cat in
                            FichaCategoriaWidget(stat: cat, simbolo: data.currency)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                EtiquetaWidget(texto: "Últimos gastos", tamano: 9)
                ViewThatFits(in: .vertical) {
                    ultimos(4)
                    ultimos(3)
                    ultimos(2)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hoy \(data.formattedToday), semana \(data.formattedWeek), mes \(data.formattedMonth)")
    }

    /// Como la tarjeta de la Home: lo gastado este mes en grande.
    private var tarjetaPrincipal: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                EtiquetaWidget(texto: "\(data.monthName) · gastado", tamano: 9)
                Spacer(minLength: 4)
                BotonAnadirWidget(tamano: 26)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                CifraWidget(texto: FormatoWidget.importe(data.monthTotal, simbolo: data.currency), tamano: 28)
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    datoEnLinea("Hoy", FormatoWidget.importe(data.todayTotal, simbolo: data.currency))
                    datoEnLinea("Semana", FormatoWidget.importe(data.weekTotal, simbolo: data.currency, sinDecimales: true))
                }
            }
            .padding(.top, 2)

            if let pct = data.budgetPercent, let budget = data.monthBudget {
                BudgetBarView(percent: pct, showLabel: false, height: 5)
                    .padding(.top, 8)
                HStack {
                    Text("\(Int((pct * 100).rounded())) % del presupuesto")
                        .foregroundStyle(EstiloWidget.textoSecundario)
                    Spacer(minLength: 4)
                    Text(FormatoWidget.importe(budget, simbolo: data.currency, sinDecimales: true))
                        .foregroundStyle(Color.budgetAccent(for: pct))
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
                .padding(.top, 5)
            }
        }
        .padding(12)
        .tarjetaWidget(radio: 18)
    }

    private func datoEnLinea(_ etiqueta: String, _ valor: String) -> some View {
        HStack(spacing: 4) {
            Text(etiqueta.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(EstiloWidget.textoSecundario)
            Text(valor)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .lineLimit(1)
    }

    private func ultimos(_ cuantos: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(data.recentExpenses.prefix(cuantos)) { expense in
                ExpenseRowView(expense: expense, compact: false, simbolo: data.currency)
            }
        }
    }
}

/// Una categoría del top en ficha: emoji y nombre, importe y su parte del mes.
struct FichaCategoriaWidget: View {
    let stat: WidgetCategoryStat
    var simbolo: String = "€"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(stat.emoji)
                    .font(.system(size: 11))
                Text(stat.name.sinEmojiWidget)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(EstiloWidget.textoSecundario)
                    .lineLimit(1)
            }
            Text(FormatoWidget.importe(stat.amount, simbolo: simbolo, sinDecimales: true))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(EstiloWidget.marca)
                        .frame(width: max(geo.size.width * stat.percent, 3))
                        .widgetAccentable()
                }
            }
            .frame(height: 3)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjetaWidget(radio: 12)
    }
}

// MARK: ─────────────────────────────────────────
// MARK: LOCK SCREEN — Circular
// MARK: ─────────────────────────────────────────

struct LockScreenCircularView: View {
    let data: SharedWidgetData

    var body: some View {
        if let pct = data.budgetPercent {
            Gauge(value: pct) {
                Image(systemName: "eurosign")
            } currentValueLabel: {
                Text(compact(data.todayTotal))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            ZStack {
                Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 2)
                VStack(spacing: 0) {
                    Text("HOY")
                        .font(.system(size: 7, weight: .bold))
                    Text(compact(data.todayTotal))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
            }
        }
    }

    private func compact(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.0fk", v / 1000) : String(format: "%.0f", v)
    }
}

// MARK: ─────────────────────────────────────────
// MARK: LOCK SCREEN — Rectangular
// MARK: ─────────────────────────────────────────

struct LockScreenRectangularView: View {
    let data: SharedWidgetData

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 3) {
                Label(data.formattedToday, systemImage: "calendar")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Label("Semana  \(data.formattedWeek)", systemImage: "calendar.badge.clock")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: ─────────────────────────────────────────
// MARK: LOCK SCREEN — Inline
// MARK: ─────────────────────────────────────────

struct LockScreenInlineView: View {
    let data: SharedWidgetData

    var body: some View {
        Label(
            "\(data.formattedToday) hoy  ·  \(data.formattedMonth) mes",
            systemImage: "chart.pie.fill"
        )
        .font(.system(size: 12, weight: .semibold, design: .rounded))
    }
}

// MARK: ─────────────────────────────────────────
// MARK: SHARED SUBVIEWS
// MARK: ─────────────────────────────────────────

struct ExpenseRowView: View {
    let expense: WidgetExpense
    let compact: Bool
    var simbolo: String = "€"

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            EmojiWidget(emoji: expense.emoji, tamano: compact ? 22 : 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(expense.name)
                    .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !compact {
                    Text(expense.category.sinEmojiWidget)
                        .font(.system(size: 10))
                        .foregroundStyle(EstiloWidget.textoTerciario)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 2)

            VStack(alignment: .trailing, spacing: 1) {
                Text(FormatoWidget.importe(expense.amount, simbolo: simbolo))
                    .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !compact {
                    Text(expense.timeAgo)
                        .font(.system(size: 9))
                        .foregroundStyle(EstiloWidget.textoTerciario)
                }
            }
        }
    }
}

struct BudgetBarView: View {
    let percent: Double
    let showLabel: Bool
    var height: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel {
                HStack {
                    Text("Presupuesto")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(EstiloWidget.textoSecundario)
                    Spacer()
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.budgetAccent(for: percent))
                }
            }
            // Cápsula lisa, como las barras de la app.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(Color.budgetAccent(for: percent))
                        .frame(width: max(geo.size.width * percent, height))
                        .widgetAccentable()
                }
            }
            .frame(height: height)
        }
    }
}

struct StatPillView: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            EtiquetaWidget(texto: label, tamano: 8)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
        }
    }
}

/// Fila Top categoría: emoji + nombre + barra + importe
struct CategoryBarRow: View {
    let stat: WidgetCategoryStat
    var simbolo: String = "€"

    var body: some View {
        HStack(spacing: 8) {
            Text(stat.emoji)
                .font(.system(size: 13))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) {
                    Text(stat.name.sinEmojiWidget)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(FormatoWidget.importe(stat.amount, simbolo: simbolo, sinDecimales: true))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(EstiloWidget.marca)
                            .frame(width: max(geo.size.width * stat.percent, 4))
                            .widgetAccentable()
                    }
                }
                .frame(height: 4)
            }
        }
    }
}

/// Dato pequeño: etiqueta encima y cifra debajo.
struct MiniStatView: View {
    let label: String
    let value: String
    var alineacion: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alineacion, spacing: 1) {
            EtiquetaWidget(texto: label, tamano: 8)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ClaritySpendingWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    ClaritySpendingWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    ClaritySpendingWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview("Lock Circular", as: .accessoryCircular) {
    ClaritySpendingWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}

#Preview("Lock Rectangular", as: .accessoryRectangular) {
    ClaritySpendingWidget()
} timeline: {
    ClarityEntry(date: .now, data: .placeholder)
}
