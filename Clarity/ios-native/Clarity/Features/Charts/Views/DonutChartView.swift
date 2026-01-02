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
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Donut Chart
                ZStack {
                    // Chart segments
                    ForEach(Array(categoryData.enumerated()), id: \.element.id) { index, data in
                        DonutSegment(
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index)
                        )
                        .fill(data.color)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedCategory == data {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = data
                                }
                            }
                        }
                        .scaleEffect(selectedCategory == data ? 1.05 : 1.0)
                    }
                    
                    // Center hole
                    Circle()
                        .fill(Color.bgPrimary)
                        .frame(width: 140, height: 140)
                    
                    // Center text
                    VStack(spacing: 4) {
                        Text("Total")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text(formatCurrency(total))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 260, height: 260)
                .padding(.top, Spacing.md)
                
                // Category Grid (2 columns)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Spacing.sm) {
                    ForEach(categoryData) { data in
                        CategoryChartCard(
                            data: data,
                            isSelected: selectedCategory == data
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedCategory == data {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = data
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Selected category detail (if any)
                if let selected = selectedCategory {
                    SelectedCategoryDetailView(data: selected)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.bgPrimary)
    }
    
    // Calculate start angle for segment
    private func startAngle(for index: Int) -> Angle {
        let precedingPercentages = categoryData.prefix(index).reduce(0) { $0 + $1.percentage }
        return Angle(degrees: (precedingPercentages / 100) * 360 - 90)
    }
    
    // Calculate end angle for segment
    private func endAngle(for index: Int) -> Angle {
        let includingPercentages = categoryData.prefix(index + 1).reduce(0) { $0 + $1.percentage }
        return Angle(degrees: (includingPercentages / 100) * 360 - 90)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
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
                    Text(formatCurrency(data.amount))
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
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }
}

// MARK: - Selected Category Detail
struct SelectedCategoryDetailView: View {
    let data: CategoryChartData
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Circle()
                        .fill(data.color)
                        .frame(width: 10, height: 10)
                    
                    Text(data.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(String(format: "%.1f", data.percentage))% del total")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(formatCurrency(data.amount))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.rowPadding)
            }
            .background(Color.bgSecondary)
            
            // Placeholder for expense list (would show expenses for this category)
            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Gastos de esta categoría aparecerán aquí")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgCard)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .stroke(data.color.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f €", value)
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
