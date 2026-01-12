// ExpenseListSkeleton.swift
// Standardized loading skeleton for expense lists

import SwiftUI

struct ExpenseListSkeleton: View {
    var rowCount: Int = 5
    
    var body: some View {
        List {
            ForEach(0..<rowCount, id: \.self) { _ in
                HStack(spacing: 12) {
                    // Category Color Dot
                    SkeletonView(cornerRadius: 4)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Title
                        SkeletonView(cornerRadius: 4)
                            .frame(width: 140, height: 16)
                        
                        // Subtitle (Date + Method)
                        SkeletonView(cornerRadius: 3)
                            .frame(width: 100, height: 12)
                    }
                    
                    Spacer()
                    
                    // Amount
                    SkeletonView(cornerRadius: 4)
                        .frame(width: 70, height: 16)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.bgPrimary)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .disabled(true) // Prevent interaction
    }
}

#Preview {
    ExpenseListSkeleton()
        .preferredColorScheme(.dark)
}
