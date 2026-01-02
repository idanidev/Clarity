// FloatingButtons.swift
// Floating action buttons (FABs)

import SwiftUI

// MARK: - Floating Mic Button
struct FloatingMicButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.brandGradientDiagonal)
                    .frame(width: Spacing.fabSize, height: Spacing.fabSize)
                    .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Floating Filter Button
struct FloatingFilterButton: View {
    let hasActiveFilters: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.bgSecondary)
                    .frame(width: Spacing.fabSmallSize, height: Spacing.fabSmallSize)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: Spacing.fabSmallSize, height: Spacing.fabSmallSize)
                
                if hasActiveFilters {
                    Circle()
                        .fill(Color.error)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
    }
}

// MARK: - FAB Stack (Filter + Mic)
struct FloatingButtonStack: View {
    let hasActiveFilters: Bool
    let onFilterTap: () -> Void
    let onMicTap: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            FloatingFilterButton(
                hasActiveFilters: hasActiveFilters,
                action: onFilterTap
            )
            
            FloatingMicButton(action: onMicTap)
        }
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                FloatingButtonStack(
                    hasActiveFilters: true,
                    onFilterTap: {},
                    onMicTap: {}
                )
                .padding(.trailing, Spacing.md)
                .padding(.bottom, 100)
            }
        }
    }
    .preferredColorScheme(.dark)
}
