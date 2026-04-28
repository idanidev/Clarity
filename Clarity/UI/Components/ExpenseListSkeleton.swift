// ExpenseListSkeleton.swift
// Premium loading skeleton for expense lists

import SwiftUI

struct ExpenseListSkeleton: View {
    var rowCount: Int = 6

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section header skeleton
                sectionHeader

                // Expense rows
                ForEach(0..<rowCount, id: \.self) { index in
                    expenseRow(index: index)
                    if index < rowCount - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }

                // Second section
                sectionHeader
                    .padding(.top, 12)

                ForEach(0..<3, id: \.self) { index in
                    expenseRow(index: index + rowCount)
                    if index < 2 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollDisabled(true)
    }

    private var sectionHeader: some View {
        HStack {
            SkeletonView(cornerRadius: 4)
                .frame(width: 80, height: 13)
            Spacer()
            SkeletonView(cornerRadius: 4)
                .frame(width: 55, height: 13)
        }
        .padding(.vertical, 10)
    }

    private func expenseRow(index: Int) -> some View {
        HStack(spacing: 12) {
            // Category circle icon
            SkeletonView(cornerRadius: 14)
                .frame(width: 36, height: 36)

            // Name + date
            VStack(alignment: .leading, spacing: 5) {
                SkeletonView(cornerRadius: 4)
                    .frame(width: randomWidth(index: index, min: 90, max: 150), height: 15)
                SkeletonView(cornerRadius: 3)
                    .frame(width: randomWidth(index: index, min: 60, max: 90), height: 11)
            }

            Spacer()

            // Amount
            SkeletonView(cornerRadius: 4)
                .frame(width: 60, height: 15)
        }
        .padding(.vertical, 10)
    }

    private func randomWidth(index: Int, min: CGFloat, max: CGFloat) -> CGFloat {
        // Deterministic pseudo-random based on index so it doesn't jitter
        let seed = CGFloat((index * 37 + 13) % 100) / 100.0
        return min + seed * (max - min)
    }
}

#Preview {
    ExpenseListSkeleton()
        .preferredColorScheme(.dark)
        .background(Color(.systemBackground))
}
