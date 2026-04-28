// ClarityWidget.swift
// ⚠️ Add this file ONLY to the ClarityWidget extension target (NOT the main app)
//
// Supports: Small, Medium, Large, Lock Screen Circular/Rectangular/Inline

import WidgetKit
import SwiftUI

// MARK: - App Group

private let kAppGroupID  = "group.com.idanidev.clarity"
private let kWidgetKey   = "widgetData_v2"

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

// MARK: - Widget Bundle

@main
struct ClarityWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaritySpendingWidget()
    }
}

// MARK: - Widget

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
    }
}

// MARK: - Background

struct WidgetGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.07, blue: 0.13),
                Color(red: 0.12, green: 0.09, blue: 0.20),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Design Tokens (Widget-local, mirrors DesignSystem)

extension Color {
    static let wPurple = Color(red: 0.686, green: 0.322, blue: 0.871)  // #AF52DE
    static let wIndigo = Color(red: 0.345, green: 0.337, blue: 0.839)  // #5856D6
    static let wGreen  = Color(red: 0.204, green: 0.780, blue: 0.349)  // #34C759
    static let wOrange = Color(red: 1.000, green: 0.584, blue: 0.000)  // #FF9500
    static let wRed    = Color(red: 1.000, green: 0.231, blue: 0.188)  // #FF3B30

    static func budgetAccent(for pct: Double) -> Color {
        if pct < 0.60 { return .wGreen }
        if pct < 0.85 { return .wOrange }
        return .wRed
    }
}

// MARK: ─────────────────────────────────────────
// MARK: SMALL WIDGET  (2×2)
// MARK: ─────────────────────────────────────────

struct SmallWidgetView: View {
    let data: SharedWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──
            HStack(spacing: 4) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.wPurple)
                Text("CLARITY")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.wPurple)
                Spacer()
                Text(data.topCategoryEmoji)
                    .font(.system(size: 16))
            }

            Spacer(minLength: 6)

            // ── Main Amount ──
            VStack(alignment: .leading, spacing: 1) {
                Text("HOY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(1.2)
                Text(data.formattedToday)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            // ── Week + Month row ──
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("SEMANA")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .kerning(0.6)
                    Text(data.formattedWeek)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("MES")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .kerning(0.6)
                    Text(data.formattedMonth)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.wIndigo)
                }
            }

            // ── Budget bar ──
            if let pct = data.budgetPercent {
                Spacer(minLength: 6)
                BudgetBarView(percent: pct, showLabel: false)
            }
        }
        .padding(12)
    }
}

// MARK: ─────────────────────────────────────────
// MARK: MEDIUM WIDGET  (4×2)
// MARK: ─────────────────────────────────────────

struct MediumWidgetView: View {
    let data: SharedWidgetData

    var body: some View {
        HStack(spacing: 0) {

            // ── Left: Stats ──
            VStack(alignment: .leading, spacing: 0) {

                HStack(spacing: 4) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.wPurple)
                    Text("CLARITY")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(Color.wPurple)
                    Spacer()
                    Text(data.monthName)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer()

                // Today (big)
                VStack(alignment: .leading, spacing: 1) {
                    Text("HOY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .kerning(1.0)
                    Text(data.formattedToday)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                }

                Spacer()

                // Week + Month (small)
                HStack(spacing: 14) {
                    MiniStatView(label: "SEMANA", value: data.formattedWeek)
                    MiniStatView(label: "MES",    value: data.formattedMonth)
                }

                // Budget bar
                if let pct = data.budgetPercent {
                    Spacer(minLength: 8)
                    BudgetBarView(percent: pct, showLabel: false)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 12)

            // ── Divider ──
            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(width: 1)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)

            // ── Right: Recent expenses ──
            VStack(alignment: .leading, spacing: 0) {
                Text("ÚLTIMOS")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .kerning(0.8)
                    .padding(.bottom, 7)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data.recentExpenses.prefix(4)) { expense in
                        ExpenseRowView(expense: expense, compact: true)
                    }
                }

                Spacer()
            }
            .padding(.trailing, 12)
            .padding(.vertical, 12)
        }
    }
}

// MARK: ─────────────────────────────────────────
// MARK: LARGE WIDGET  (4×4)
// MARK: ─────────────────────────────────────────

struct LargeWidgetView: View {
    let data: SharedWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.wPurple)
                    Text("CLARITY")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.wPurple)
                }
                Spacer()
                Text("\(data.monthName)  \(currentYear())")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.bottom, 16)

            // ── Stats row ──
            HStack(spacing: 0) {
                StatPillView(label: "HOY",    value: data.formattedToday,  accent: Color.wPurple)
                Spacer()
                Rectangle().fill(.white.opacity(0.07)).frame(width: 1, height: 44)
                Spacer()
                StatPillView(label: "SEMANA", value: data.formattedWeek,   accent: Color.wIndigo)
                Spacer()
                Rectangle().fill(.white.opacity(0.07)).frame(width: 1, height: 44)
                Spacer()
                StatPillView(label: "MES",    value: data.formattedMonth,  accent: .white.opacity(0.8))
            }

            // ── Budget section ──
            if let pct = data.budgetPercent, let budget = data.formattedBudget {
                VStack(alignment: .leading, spacing: 7) {
                    Rectangle()
                        .fill(.white.opacity(0.07))
                        .frame(height: 1)
                        .padding(.vertical, 12)

                    HStack {
                        Label("Presupuesto mensual", systemImage: "target")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Text("\(data.formattedMonth) / \(budget)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.budgetAccent(for: pct))
                    }

                    BudgetBarView(percent: pct, showLabel: false, height: 8)
                }
            }

            // ── Divider ──
            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(height: 1)
                .padding(.vertical, 10)

            // ── Recent expenses ──
            VStack(alignment: .leading, spacing: 0) {
                Text("ÚLTIMOS GASTOS")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .kerning(0.8)
                    .padding(.bottom, 8)

                VStack(spacing: 8) {
                    ForEach(data.recentExpenses.prefix(5)) { expense in
                        ExpenseRowView(expense: expense, compact: false)
                    }
                }
            }

            Spacer()
        }
        .padding(13)
    }

    private func currentYear() -> String {
        Calendar.current.component(.year, from: Date()).description
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

// Single expense row (compact = medium widget, full = large)
struct ExpenseRowView: View {
    let expense: WidgetExpense
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            // Emoji bubble
            ZStack {
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: compact ? 26 : 32, height: compact ? 26 : 32)
                Text(expense.emoji)
                    .font(.system(size: compact ? 13 : 16))
            }

            // Name + category
            VStack(alignment: .leading, spacing: 1) {
                Text(expense.name)
                    .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !compact {
                    Text(expense.category)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 2)

            // Amount + time
            VStack(alignment: .trailing, spacing: 1) {
                Text(expense.formattedAmount)
                    .font(.system(size: compact ? 11 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(expense.timeAgo)
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

// Budget progress bar
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
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.budgetAccent(for: percent))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(.white.opacity(0.12))
                        .frame(height: height)
                    LinearGradient(
                        colors: [
                            Color.budgetAccent(for: percent).opacity(0.7),
                            Color.budgetAccent(for: percent),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))
                    .frame(width: max(geo.size.width * percent, height), height: height)
                }
            }
            .frame(height: height)
        }
    }
}

// Small stat pill (large widget top row)
struct StatPillView: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(0.8)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
        }
    }
}

// Tiny stat (medium widget bottom row)
struct MiniStatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(0.8)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
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
