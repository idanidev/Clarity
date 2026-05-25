// MonthlyEvolutionChart.swift
// Gráfica de evolución mensual con área + línea + scrub interactivo.
// Movida desde HomeView.swift para separar concerns y aligerar el body de Home.

import Charts
import SwiftUI

struct MonthlyEvolutionChart: View {
    let data: [MonthlySpending]
    let selectedMonthKey: String
    @Binding var range: Int

    @State private var reveal: CGFloat = 0          // animación de entrada (0→1)
    @State private var scrubKey: String?            // mes bajo el dedo
    @Environment(\.colorScheme) private var scheme

    private var nonZero: [Double] { data.map(\.total).filter { $0 > 0 } }
    private var avg: Double { nonZero.isEmpty ? 0 : nonZero.reduce(0,+) / Double(nonZero.count) }

    /// Mes mostrado en cabecera: el que tocas (scrub) o el seleccionado.
    private var focused: MonthlySpending? {
        if let k = scrubKey { return data.first { $0.key == k } }
        return data.first { $0.key == selectedMonthKey } ?? data.last
    }

    /// Variación del mes enfocado vs el anterior en la serie.
    private var focusedDelta: Double? {
        guard let f = focused,
              let i = data.firstIndex(where: { $0.key == f.key }),
              i > 0
        else { return nil }
        let prev = data[i - 1].total
        guard prev > 0 else { return nil }
        return (f.total - prev) / prev
    }

    private var accent: LinearGradient {
        LinearGradient(
            colors: [Color.clarityPrimary, Color.clarityAccent],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            chart
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.06), radius: 12, y: 6)
        }
        .onAppear {
            reveal = 0
            withAnimation(.easeOut(duration: 0.9)) { reveal = 1 }
        }
    }

    // MARK: Header (valor grande + tendencia + selector 6M/1A)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(scrubKey != nil ? "Detalle" : "Evolución")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text((focused?.total ?? 0).formattedCurrency)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: focused?.total)

                    if let d = focusedDelta, abs(d) >= 0.01 {
                        let up = d > 0
                        HStack(spacing: 2) {
                            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                            Text("\(abs(Int((d*100).rounded())))%")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(up ? Color.red : Color.green)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((up ? Color.red : Color.green).opacity(0.14), in: Capsule())
                    }
                }

                Text(headerSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Picker("", selection: $range) {
                Text("6M").tag(6)
                Text("1A").tag(12)
            }
            .pickerStyle(.segmented)
            .frame(width: 96)
        }
    }

    private var headerSubtitle: String {
        if let f = focused, scrubKey != nil {
            return mesAnio(f.key)
        }
        return avg > 0 ? "media \(avg.formattedCurrency)/mes" : "Sin gastos en el periodo"
    }

    // MARK: Chart (área + línea + punto + scrub)

    private var chart: some View {
        Chart {
            ForEach(data) { item in
                AreaMark(
                    x: .value("Mes", item.label),
                    y: .value("Gasto", item.total * Double(reveal))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.clarityPrimary.opacity(0.35), Color.clarityPrimary.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Mes", item.label),
                    y: .value("Gasto", item.total * Double(reveal))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(accent)
            }

            if avg > 0 {
                RuleMark(y: .value("Media", avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.35))
            }

            // Punto destacado (mes enfocado)
            if let f = focused, reveal > 0.95 {
                PointMark(
                    x: .value("Mes", f.label),
                    y: .value("Gasto", f.total)
                )
                .symbolSize(140)
                .foregroundStyle(Color.clarityPrimary)
                .annotation(position: .top, spacing: 6) {
                    Text(shortAmount(f.total))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                if scrubKey != nil {
                    RuleMark(x: .value("Mes", f.label))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.clarityPrimary.opacity(0.4))
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(range: .plotDimension(padding: 14))
        .frame(height: 160)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plot = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plot].origin.x
                                if let label: String = proxy.value(atX: x) {
                                    if let hit = data.first(where: { $0.label == label }),
                                       hit.key != scrubKey {
                                        scrubKey = hit.key
                                        HapticManager.shared.selection()
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.snappy) { scrubKey = nil }
                            }
                    )
            }
        }
    }

    private func shortAmount(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.1fk €", v / 1000) : String(format: "%.0f €", v)
    }

    private func mesAnio(_ key: String) -> String {
        // key = "YYYY-MM"
        let parts = key.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]) else { return key }
        let cal = Calendar.current
        let name = cal.standaloneMonthSymbols[(m - 1) % 12].capitalized
        return "\(name) \(parts[0])"
    }
}
