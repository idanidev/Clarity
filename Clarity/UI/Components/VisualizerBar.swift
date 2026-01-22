// VisualizerBar.swift
// Component for Voice Expense Button

import SwiftUI

struct VisualizerBar: View {
    let audioLevel: Float
    let index: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.9))
            .frame(width: 3, height: height(for: index))
            .animation(.easeInOut(duration: 0.1), value: audioLevel)
    }
    
    private func height(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let variability = CGFloat(index + 1) * 2
        // Dynamic height based on level, clamped
        let levelHeight = CGFloat(audioLevel) * 25.0
        return min(30, max(baseHeight, levelHeight + variability))
    }
}
