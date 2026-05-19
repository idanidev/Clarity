// ChartsView.swift
// Premium Charts hub: Hero total, donut, capacity bar, daily bars, category cards, insights.

import SwiftUI
import Charts

struct ChartsView: View {
    @State private var vm = ChartsViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundAurora()
                    .ignoresSafeArea()

                if vm.isLoading && vm.expenses.isEmpty {
                    ProgressView().tint(.clarityPrimary)
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.lg) {
                            PeriodPicker(selection: $vm.selectedPeriod)
                                .padding(.horizontal, Spacing.md)

                            HeroTotalView(
                                total: vm.total,
                                delta: vm.deltaPercent,
                                previousTotal: vm.previousTotal,
                                sparkline: vm.dailySeries.map { $0.amount }
                            )
                            .padding(.horizontal, Spacing.md)

                            if vm.filteredExpenses.isEmpty {
                                EmptyChartsView()
                                    .padding(.top, 40)
                            } else {
                                PremiumDonut(
                                    stats: vm.categoryStats,
                                    total: vm.total,
                                    selectedName: $vm.selectedCategoryName
                                )
                                .padding(.horizontal, Spacing.md)

                                SegmentedCapacityBar(
                                    stats: vm.categoryStats,
                                    selectedName: $vm.selectedCategoryName
                                )
                                .padding(.horizontal, Spacing.md)

                                InsightsRotator(insights: vm.insights)
                                    .padding(.horizontal, Spacing.md)

                                DailyBarChartView(points: vm.dailySeries)
                                    .padding(.horizontal, Spacing.md)

                                CategoryGrid(
                                    stats: vm.categoryStats,
                                    selectedName: $vm.selectedCategoryName
                                )
                                .padding(.horizontal, Spacing.md)
                            }

                            Color.clear.frame(height: 80)
                        }
                        .padding(.top, Spacing.sm)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Análisis")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }
}

// MARK: - Background

private struct BackgroundAurora: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        ZStack {
            Color.bgPrimary
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let a = CGFloat(sin(t / 6) * 40)
                let b = CGFloat(cos(t / 8) * 40)
                ZStack {
                    Circle()
                        .fill(Color.clarityPrimary.opacity(0.28))
                        .frame(width: 320, height: 320)
                        .blur(radius: 80)
                        .offset(x: -80 + a, y: -180 + b)
                    Circle()
                        .fill(Color.clarityAccent.opacity(0.22))
                        .frame(width: 360, height: 360)
                        .blur(radius: 90)
                        .offset(x: 120 - a, y: 220 - b)
                }
                // Rasteriza el blur en GPU (1 textura) en vez de recomponer
                // 2 blurs grandes por frame. Fondo no interactivo → seguro.
                .drawingGroup()
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Period Picker

private struct PeriodPicker: View {
    @Binding var selection: ChartsViewModel.Period
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ChartsViewModel.Period.allCases) { p in
                let isOn = p == selection
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = p
                    }
                    HapticManager.shared.selection()
                } label: {
                    Text(p.label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isOn ? Color.white : Color.secondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isOn {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clarityPrimary, .clarityAccent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "periodPill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(.ultraThinMaterial))
    }
}

// MARK: - Hero Total

private struct HeroTotalView: View {
    let total: Double
    let delta: Double
    let previousTotal: Double
    let sparkline: [Double]

    @State private var displayed: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOTAL GASTADO")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Formatters.currency(displayed))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: displayed))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.white.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Spacer()
                DeltaBadge(delta: delta, enabled: previousTotal > 0)
            }

            if !sparkline.isEmpty {
                Sparkline(values: sparkline, tint: .clarityPrimary)
                    .frame(height: 44)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        )
        .onAppear { animate(to: total) }
        .onChange(of: total) { _, new in animate(to: new) }
    }

    private func animate(to target: Double) {
        withAnimation(.easeOut(duration: 0.8)) { displayed = target }
    }
}

private struct DeltaBadge: View {
    let delta: Double
    let enabled: Bool
    var body: some View {
        let up = delta > 0
        let color: Color = !enabled ? .secondary : (up ? .red : .green)
        let symbol = !enabled ? "minus" : (up ? "arrow.up.right" : "arrow.down.right")
        let text = !enabled ? "—" : "\(up ? "+" : "")\(Int((delta * 100).rounded()))%"
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.15)))
    }
}

private struct Sparkline: View {
    let values: [Double]
    let tint: Color
    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 1)
            let step = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : 0
            Path { p in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height - (CGFloat(v / maxV) * geo.size.height)
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(
                LinearGradient(colors: [tint, .clarityAccent], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )

            Path { p in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height - (CGFloat(v / maxV) * geo.size.height)
                    if i == 0 { p.move(to: CGPoint(x: x, y: geo.size.height)); p.addLine(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
                p.addLine(to: CGPoint(x: CGFloat(values.count - 1) * step, y: geo.size.height))
                p.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [tint.opacity(0.35), tint.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Premium Donut

private struct PremiumDonut: View {
    let stats: [ChartsViewModel.CategoryStat]
    let total: Double
    @Binding var selectedName: String?

    @State private var progress: CGFloat = 0
    @State private var pulse: Bool = false

    private var selected: ChartsViewModel.CategoryStat? {
        guard let n = selectedName else { return nil }
        return stats.first(where: { $0.name == n })
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(Array(segments().enumerated()), id: \.offset) { idx, seg in
                    DonutSlice(start: seg.start, end: seg.end)
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [Color(hex: seg.stat.colorHex), Color(hex: seg.stat.colorHex).opacity(0.7)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: selectedName == seg.stat.name ? 42 : 32, lineCap: .butt)
                        )
                        .shadow(color: Color(hex: seg.stat.colorHex).opacity(selectedName == seg.stat.name ? 0.5 : 0), radius: 12)
                        .scaleEffect(selectedName == seg.stat.name ? 1.04 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedName)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedName = selectedName == seg.stat.name ? nil : seg.stat.name
                            }
                            HapticManager.shared.selection()
                        }
                }

                // Center content
                VStack(spacing: 4) {
                    if let sel = selected {
                        Text(sel.name.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color(hex: sel.colorHex))
                        Text(Formatters.currency(sel.amount))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: sel.amount))
                        Text("\(Int(sel.percentage.rounded()))% del total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("TOTAL")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                        Text(Formatters.currency(total))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: total))
                        Text("\(stats.count) categorías")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.scale.combined(with: .opacity))
                .id(selectedName ?? "__total__")
            }
            .frame(height: 260)
            .padding(.vertical, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { progress = 1 }
        }
    }

    private func segments() -> [(start: Angle, end: Angle, stat: ChartsViewModel.CategoryStat)] {
        var result: [(Angle, Angle, ChartsViewModel.CategoryStat)] = []
        var cursor: Double = -90
        let gap: Double = 2
        for s in stats {
            let sweep = (s.percentage / 100) * 360 - gap
            let end = cursor + max(sweep, 0.5)
            result.append((Angle(degrees: cursor), Angle(degrees: end), s))
            cursor = end + gap
        }
        return result
    }
}

private struct DonutSlice: Shape {
    let start: Angle
    let end: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2 - 20
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r, startAngle: start, endAngle: end, clockwise: false)
        return p
    }
}

// MARK: - Segmented Capacity Bar

private struct SegmentedCapacityBar: View {
    let stats: [ChartsViewModel.CategoryStat]
    @Binding var selectedName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DISTRIBUCIÓN")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stats) { s in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: s.colorHex))
                            .frame(width: max(geo.size.width * CGFloat(s.percentage / 100) - 2, 2))
                            .opacity(selectedName == nil || selectedName == s.name ? 1 : 0.35)
                            .scaleEffect(y: selectedName == s.name ? 1.3 : 1, anchor: .center)
                            .animation(.spring(response: 0.35), value: selectedName)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedName = selectedName == s.name ? nil : s.name
                                }
                                HapticManager.shared.selection()
                            }
                    }
                }
            }
            .frame(height: 14)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Daily Bar Chart

private struct DailyBarChartView: View {
    let points: [ChartsViewModel.DailyPoint]
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("POR DÍA")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let sel = selectedDate, let p = points.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                    Text("\(dayLabel(p.date)) · \(Formatters.currency(p.amount))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Día", point.date, unit: .day),
                    y: .value("Gasto", point.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.clarityPrimary, .clarityAccent],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .opacity(selectedDate == nil || Calendar.current.isDate(point.date, inSameDayAs: selectedDate ?? .distantPast) ? 1 : 0.4)

                if let sel = selectedDate {
                    RuleMark(x: .value("Sel", sel, unit: .day))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartXSelection(value: $selectedDate)
            .frame(height: 180)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private static let dayLabelFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_ES")
        df.dateFormat = "d MMM"
        return df
    }()

    private func dayLabel(_ d: Date) -> String {
        Self.dayLabelFormatter.string(from: d)
    }
}

// MARK: - Category Grid

private struct CategoryGrid: View {
    let stats: [ChartsViewModel.CategoryStat]
    @Binding var selectedName: String?

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORÍAS")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(stats) { s in
                    CategoryPremiumCard(stat: s, highlighted: selectedName == s.name)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35)) {
                                selectedName = selectedName == s.name ? nil : s.name
                            }
                            HapticManager.shared.selection()
                        }
                }
            }
        }
    }
}

private struct CategoryPremiumCard: View {
    let stat: ChartsViewModel.CategoryStat
    let highlighted: Bool

    var body: some View {
        let tint = Color(hex: stat.colorHex)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                Text(stat.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if stat.deltaVsPrevious != 0 {
                    Text("\(stat.deltaVsPrevious > 0 ? "+" : "")\(Int((stat.deltaVsPrevious * 100).rounded()))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(stat.deltaVsPrevious > 0 ? Color.red : Color.green)
                }
            }

            Text(Formatters.currency(stat.amount))
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("\(Int(stat.percentage.rounded()))% del total")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Sparkline(values: stat.sparkline, tint: tint)
                .frame(height: 28)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tint.opacity(highlighted ? 0.7 : 0.15), lineWidth: highlighted ? 2 : 1)
                )
        )
        .scaleEffect(highlighted ? 1.03 : 1)
        .shadow(color: highlighted ? tint.opacity(0.35) : .clear, radius: 10)
    }
}

// MARK: - Insights Rotator

private struct InsightsRotator: View {
    let insights: [ChartsViewModel.Insight]
    @State private var index: Int = 0

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            TimelineView(.periodic(from: .now, by: 3.5)) { ctx in
                let i = Int(ctx.date.timeIntervalSinceReferenceDate / 3.5) % max(insights.count, 1)
                InsightCard(insight: insights[i])
                    .id(i)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: i)
            }
        }
    }
}

private struct InsightCard: View {
    let insight: ChartsViewModel.Insight
    var body: some View {
        let tint = Color(hex: insight.tintHex)
        HStack(spacing: 14) {
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: insight.id)
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint.opacity(0.2)))

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.caption.weight(.bold))
                Text(insight.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Empty

private struct EmptyChartsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
            Text("Sin datos en este periodo")
                .font(.headline)
            Text("Añade gastos para ver tus estadísticas aquí")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

#Preview {
    ChartsView()
}
