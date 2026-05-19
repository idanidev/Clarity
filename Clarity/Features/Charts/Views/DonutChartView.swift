// DonutChartView.swift
// Interactive donut chart with category breakdown

import SwiftUI

// MARK: - Chart Data Model
struct CategoryChartData: Identifiable, Equatable {
    var id: String { name }   // estable: antes UUID() rompía animaciones
    let name: String
    let amount: Double
    let percentage: Double
    let color: Color

    static func == (lhs: CategoryChartData, rhs: CategoryChartData) -> Bool {
        lhs.name == rhs.name && lhs.amount == rhs.amount
    }
}

// MARK: - Donut Chart View
struct DonutChartView: View {
    let categoryData: [CategoryChartData]
    let total: Double
    var expenses: [Expense] = []
    @State private var selectedCategory: CategoryChartData?
    @State private var animationProgress: CGFloat = 0
    @State private var centerTextOpacity: CGFloat = 0
    @State private var legendAppeared = false
    @State private var cachedSegments: [(start: Angle, end: Angle, data: CategoryChartData)] = []

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Donut chart in a glass card with subtle gradient
                GlassCard.withGradient(
                    LinearGradient(
                        colors: [Color.clarityPrimary.opacity(0.08), Color.clarityAccent.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) {
                    VStack(spacing: Spacing.lg) {
                        donutChart

                        // Separator
                        Rectangle()
                            .fill(Color.glassBorder)
                            .frame(height: 1)
                            .padding(.horizontal, Spacing.md)

                        // Legend ordered by amount
                        categoryLegend
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

                // Category grid cards
                categoryGrid

                // Drill-down detail
                if let selected = selectedCategory {
                    categoryDrillDown(for: selected)
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Donut Chart Component

    private var donutChart: some View {
        ZStack {
            // Glow ring behind the donut
            Circle()
                .stroke(
                    AngularGradient(
                        colors: categoryData.map { $0.color } + [categoryData.first?.color ?? .clear],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .blur(radius: 12)
                .opacity(Double(animationProgress) * 0.4)
                .frame(width: 290, height: 290)

            // Chart segments
            ForEach(cachedSegments, id: \.data.id) { segment in
                // Usa ángulos ya pre-calculados en cachedSegments (antes O(n²) reduce por render)
                let startPct = segment.start.degrees / 360.0
                let endPct = segment.end.degrees / 360.0
                let visibleEnd = min(endPct, max(startPct, Double(animationProgress)))

                if animationProgress > startPct {
                    Circle()
                        .trim(from: startPct, to: visibleEnd)
                        .stroke(
                            segment.data.color.gradient,
                            style: StrokeStyle(lineWidth: 52, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(selectedCategory == segment.data ? 1.06 : 1.0)
                        .shadow(
                            color: selectedCategory == segment.data ? segment.data.color.opacity(0.5) : .clear,
                            radius: 8
                        )
                        .animation(.bouncy(duration: AnimationDuration.normal), value: selectedCategory)
                        .onTapGesture {
                            withAnimation(.bouncy(duration: AnimationDuration.normal)) {
                                selectedCategory = selectedCategory == segment.data ? nil : segment.data
                            }
                        }
                }
            }

            // Inner shadow circle for depth
            Circle()
                .fill(Color.clear)
                .frame(width: 220, height: 220)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 2)
                        .blur(radius: 4)
                )
                .opacity(Double(animationProgress))

            // Center content
            VStack(spacing: Spacing.xxs) {
                if let selected = selectedCategory {
                    // Selected category info
                    Circle()
                        .fill(selected.color.gradient)
                        .frame(width: 10, height: 10)

                    Text(selected.name)
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(selected.color)
                        .lineLimit(1)

                    Text(Formatters.currency(selected.amount))
                        .scaledFont(size: 28, weight: .bold)
                        .foregroundStyle(Color.primary)
                        .contentTransition(.numericText())

                    Text("\(String(format: "%.1f", selected.percentage))%")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(.secondary)
                } else {
                    // Total
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: IconSize.medium))
                        .foregroundStyle(Color.clarityPrimary.gradient)

                    Text("Total")
                        .scaledFont(size: 13)
                        .foregroundStyle(.secondary)

                    Text(total.formattedCurrency)
                        .scaledFont(size: 28, weight: .bold)
                        .foregroundStyle(Color.primary)
                        .contentTransition(.numericText())

                    Text("\(categoryData.count) categorias")
                        .scaledFont(size: 12)
                        .foregroundStyle(.tertiary)
                }
            }
            .opacity(centerTextOpacity)
            .animation(.easeInOut(duration: AnimationDuration.fast), value: selectedCategory)
        }
        .frame(width: 320, height: 320)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Grafico de gastos por categoria. Total: \(total.formattedCurrency)")
        .padding(.top, Spacing.md)
        .onAppear {
            updateCachedSegments()
            animationProgress = 0
            centerTextOpacity = 0
            legendAppeared = false
            withAnimation(.easeInOut(duration: 1.2)) {
                animationProgress = 1.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.8)) {
                centerTextOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                legendAppeared = true
            }
        }
        .onChange(of: categoryData) { _, _ in
            updateCachedSegments()
            animationProgress = 0
            centerTextOpacity = 0
            legendAppeared = false
            withAnimation(.easeInOut(duration: 1.2)) {
                animationProgress = 1.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.8)) {
                centerTextOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                legendAppeared = true
            }
        }
    }

    // MARK: - Category Legend (below donut)

    private var categoryLegend: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(Array(categoryData.enumerated()), id: \.element.id) { index, data in
                HStack(spacing: Spacing.sm) {
                    // Color dot with gradient
                    Circle()
                        .fill(data.color.gradient)
                        .frame(width: 10, height: 10)

                    // Category name (emoji + nombre limpio)
                    let parts = data.name.categoryNameEmoji
                    if let e = parts.emoji { Text(e).font(.system(size: 13)) }
                    Text(parts.name)
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // Amount
                    Text(data.amount.formattedCurrency)
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundStyle(.primary)

                    // Percentage pill
                    Text("\(String(format: "%.1f", data.percentage))%")
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(data.color)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(data.color.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
                .opacity(legendAppeared ? 1 : 0)
                .offset(y: legendAppeared ? 0 : 8)
                .animation(
                    .easeOut(duration: 0.4).delay(Double(index) * 0.06),
                    value: legendAppeared
                )
                .onTapGesture {
                    withAnimation(.bouncy(duration: AnimationDuration.normal)) {
                        selectedCategory = selectedCategory == data ? nil : data
                    }
                }
            }
        }
    }

    // MARK: - Category Grid Component

    private var categoryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: Spacing.sm) {
            ForEach(Array(categoryData.enumerated()), id: \.element.id) { index, data in
                CategoryChartCard(
                    data: data,
                    isSelected: selectedCategory == data
                )
                .onTapGesture {
                    withAnimation(.bouncy(duration: AnimationDuration.normal)) {
                        if selectedCategory == data {
                            selectedCategory = nil
                        } else {
                            selectedCategory = data
                        }
                    }
                }
                .opacity(animationProgress)
                .scaleEffect(animationProgress)
                .animation(
                    .bouncy(duration: 0.6)
                        .delay(Double(index) * 0.08),
                    value: animationProgress
                )
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    @ViewBuilder
    private func categoryDrillDown(for category: CategoryChartData) -> some View {
        let filtered = expenses.filter { $0.category == category.name }
            .sorted { $0.amount > $1.amount }

        if !filtered.isEmpty {
            GlassCard.light {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Circle()
                            .fill(category.color.gradient)
                            .frame(width: 8, height: 8)
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(filtered.count) gastos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Spacing.sm)

                    VStack(spacing: 4) {
                        ForEach(filtered.prefix(5)) { expense in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let sub = expense.subcategory {
                                        Text(sub)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(Formatters.currency(expense.amount))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(category.color)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.glassBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        }

                        if filtered.count > 5 {
                            Text("+ \(filtered.count - 5) mas")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(Spacing.sm)
            }
            .padding(.horizontal, Spacing.md)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    private func updateCachedSegments() {
        var segments: [(start: Angle, end: Angle, data: CategoryChartData)] = []

        // Acumulado incremental — O(n) (antes 2 reduce O(n) por elemento = O(n²))
        var cumulative: Double = 0
        for data in categoryData {
            let start = Angle(degrees: (cumulative / 100) * 360 - 90)
            cumulative += data.percentage
            let end = Angle(degrees: (cumulative / 100) * 360 - 90)
            segments.append((start: start, end: end, data: data))
        }

        cachedSegments = segments
    }
}

// MARK: - Donut Segment Shape
struct DonutSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.55

        path.addArc(center: center, radius: outerRadius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()

        return path
    }
}

// MARK: - Category Chart Card
struct CategoryChartCard: View {
    let data: CategoryChartData
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Color indicator with gradient
            RoundedRectangle(cornerRadius: 3)
                .fill(data.color.gradient)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    let parts = data.name.categoryNameEmoji
                    if let e = parts.emoji {
                        Text(e).font(.system(size: 13))
                    }
                    Text(parts.name)
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Text(data.amount.formattedCurrency)
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundStyle(.secondary)

                    Text("(\(String(format: "%.1f", data.percentage))%)")
                        .scaledFont(size: 11)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .background {
            ZStack {
                Color.glassBackground
                if isSelected {
                    data.color.opacity(0.12)
                }
                // Subtle gradient on selected
                if isSelected {
                    LinearGradient(
                        colors: [data.color.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(
                    isSelected ? data.color.opacity(0.6) : Color.glassBorder,
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(
            color: isSelected ? data.color.opacity(0.2) : .clear,
            radius: 6, y: 2
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.bouncy(duration: AnimationDuration.fast), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    DonutChartView(
        categoryData: [
            CategoryChartData(name: "Vivienda", amount: 650, percentage: 47.1, color: Color(hex: "#3B82F6")),
            CategoryChartData(name: "Alimentacion", amount: 280, percentage: 20.3, color: Color(hex: "#6366F1")),
            CategoryChartData(name: "Transporte", amount: 150, percentage: 10.9, color: Color(hex: "#14B8A6")),
            CategoryChartData(name: "Ocio", amount: 120, percentage: 8.7, color: Color(hex: "#10B981")),
            CategoryChartData(name: "Compras", amount: 100, percentage: 7.2, color: Color(hex: "#FBBF24")),
            CategoryChartData(name: "Otros", amount: 80, percentage: 5.8, color: Color(hex: "#6B7280"))
        ],
        total: 1380.00,
        expenses: []
    )
    .preferredColorScheme(.dark)
}
