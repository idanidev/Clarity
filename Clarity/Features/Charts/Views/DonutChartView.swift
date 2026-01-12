// DonutChartView.swift
// Interactive donut chart with category breakdown

import SwiftUI

// MARK: - Chart Data Model
struct CategoryChartData: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let amount: Double
    let percentage: Double
    let color: Color
    
    static func == (lhs: CategoryChartData, rhs: CategoryChartData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Donut Chart View
struct DonutChartView: View {
    let categoryData: [CategoryChartData]
    let total: Double
    @State private var selectedCategory: CategoryChartData?
    @State private var animationProgress: CGFloat = 0
    @State private var cachedSegments: [(start: Angle, end: Angle, data: CategoryChartData)] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                donutChart
                categoryGrid

            }
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.bgPrimary)
    }
    
    // MARK: - Donut Chart Component
    
    // MARK: - Donut Chart Component
    
    private var donutChart: some View {
        ZStack {
            // Chart segments
            // We use standard Circle().trim() to achieve a perfect "clock wipe" animation.
            // This avoids any morphing artifacts from custom shapes.
            ForEach(Array(cachedSegments.enumerated()), id: \.element.data.id) { index, segment in
                let startPct = calculateStartPercentage(for: index)
                let endPct = startPct + (segment.data.percentage / 100.0)
                
                // Determine how much of this segment is visible based on global animation (0...1)
                // The trim endpoint logic:
                // We want the segment to be drawn from its real start up to the CURRENT animation progress.
                // But capped at its real end.
                // And only if animation has passed the start.
                let visibleEnd = min(endPct, max(startPct, Double(animationProgress)))
                                
                if animationProgress > startPct {
                    Circle()
                        .trim(from: startPct, to: visibleEnd)
                        .stroke(segment.data.color, style: StrokeStyle(lineWidth: 35, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(selectedCategory == segment.data ? 1.05 : 1.0)
                        .onTapGesture {
                            withAnimation(.bouncy(duration: 0.3)) {
                                selectedCategory = selectedCategory == segment.data ? nil : segment.data
                            }
                        }
                }
            }
            
            // Center text
            VStack(spacing: 2) {
                Text("Total")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .opacity(animationProgress > 0.1 ? 1 : 0)
                
                Text(total.formattedCurrency)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(animationProgress > 0.1 ? 1 : 0)
            }
        }
        .frame(width: 200, height: 200)
        .padding(.top, Spacing.xl)
        .onAppear {
            updateCachedSegments()
            animationProgress = 0
            withAnimation(.linear(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: categoryData) { _, _ in
            updateCachedSegments()
            animationProgress = 0
            withAnimation(.linear(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func calculateStartPercentage(for index: Int) -> Double {
        return categoryData.prefix(index).reduce(0) { $0 + $1.percentage } / 100.0
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
                    withAnimation(.bouncy(duration: 0.3)) {
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
                        .delay(Double(index) * 0.1),
                    value: animationProgress
                )
            }
        }
        .padding(.horizontal)
    }
    

    
    // MARK: - Angle Calculations
    private func startAngle(for index: Int) -> Angle {
        let precedingPercentages = categoryData.prefix(index).reduce(0) { $0 + $1.percentage }
        return Angle(degrees: (precedingPercentages / 100) * 360 - 90)
    }
    
    // Calculate end angle for segment
    private func endAngle(for index: Int) -> Angle {
        let includingPercentages = categoryData.prefix(index + 1).reduce(0) { $0 + $1.percentage }
        return Angle(degrees: (includingPercentages / 100) * 360 - 90)
    }
    
    private func updateCachedSegments() {
        var segments: [(start: Angle, end: Angle, data: CategoryChartData)] = []
        
        for (index, data) in categoryData.enumerated() {
            segments.append((
                start: startAngle(for: index),
                end: endAngle(for: index),
                data: data
            ))
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
            // Color indicator
            Circle()
                .fill(data.color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                // Name
                Text(data.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Amount + percentage
                HStack(spacing: 4) {
                    Text(data.amount.formattedCurrency)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    
                    Text("(\(String(format: "%.1f", data.percentage))%)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? data.color : Color.borderDefault, lineWidth: isSelected ? 2 : 1)
        )
    }
    

}

    



// MARK: - Preview
#Preview {
    DonutChartView(
        categoryData: [
            CategoryChartData(name: "Vivienda 🏠", amount: 650, percentage: 47.1, color: Color(hex: "#3B82F6")!),
            CategoryChartData(name: "Alimentación 🥗", amount: 280, percentage: 20.3, color: Color(hex: "#6366F1")!),
            CategoryChartData(name: "Transporte 🚎", amount: 150, percentage: 10.9, color: Color(hex: "#14B8A6")!),
            CategoryChartData(name: "Ocio 🍻", amount: 120, percentage: 8.7, color: Color(hex: "#10B981")!),
            CategoryChartData(name: "Compras 🛒", amount: 100, percentage: 7.2, color: Color(hex: "#FBBF24")!),
            CategoryChartData(name: "Otros 📦", amount: 80, percentage: 5.8, color: Color(hex: "#6B7280")!)
        ],
        total: 1380.00
    )
    .preferredColorScheme(.dark)
}
