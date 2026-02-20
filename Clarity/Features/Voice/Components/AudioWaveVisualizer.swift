// AudioWaveVisualizer.swift
// Real-time audio wave visualization using SwiftUI Canvas

import Combine
import SwiftUI

struct AudioWaveVisualizer: View {
    let audioLevel: Float
    let isActive: Bool

    @State private var phase: Double = 0

    var body: some View {
        // Only animate at 60fps when active. When idle, standard refresh or static.
        TimelineView(.animation(minimumInterval: isActive ? 0.016 : 1.0)) { timeline in
            Canvas { context, size in
                drawWaves(
                    context: context, size: size, time: timeline.date.timeIntervalSinceReferenceDate
                )
            }
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    private func drawWaves(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let amplitude = isActive ? CGFloat(audioLevel) * 30 + 5 : 5.0
        let frequency: Double = 2.0

        // Create gradient colors
        let colors = [
            Color.purple.opacity(0.6),
            Color.blue.opacity(0.6),
            Color.purple.opacity(0.6),
        ]
        let gradient = Gradient(colors: colors)

        // Draw multiple waves for depth effect
        for i in 0..<3 {
            let yOffset = CGFloat(i) * 5

            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))

            let step: CGFloat = 2
            var x: CGFloat = 0
            while x <= size.width {
                let relativeX = x / size.width
                let sine = sin((relativeX * frequency * .pi * 2) + time * 2)
                let y = (size.height / 2) + (sine * amplitude) + yOffset
                path.addLine(to: CGPoint(x: x, y: y))
                x += step
            }

            context.stroke(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: size.height / 2),
                    endPoint: CGPoint(x: size.width, y: size.height / 2)
                ),
                lineWidth: 3
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AudioWaveVisualizer(audioLevel: 0.5, isActive: true)
        AudioWaveVisualizer(audioLevel: 0.0, isActive: false)
    }
    .padding()
    .background(Color.black)
}
