// SuccessAnimationView.swift
// Animated checkmark with confetti burst for success feedback

import SwiftUI

struct SuccessAnimationView: View {
    @State private var circleProgress: CGFloat = 0
    @State private var checkmarkProgress: CGFloat = 0
    @State private var circleScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0
    @State private var particles: [ConfettiParticle] = []

    private let circleSize: CGFloat = 64
    private let accentColor = Color.clarityPrimary

    var body: some View {
        ZStack {
            // Glow behind circle
            Circle()
                .fill(accentColor.opacity(0.3))
                .frame(width: circleSize + 20, height: circleSize + 20)
                .blur(radius: 12)
                .opacity(glowOpacity)

            // Animated circle
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: circleSize, height: circleSize)
                .rotationEffect(.degrees(-90))
                .scaleEffect(circleScale)

            // Filled circle background (appears after circle completes)
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: circleSize, height: circleSize)
                .scaleEffect(circleScale)
                .opacity(checkmarkProgress > 0 ? 1 : 0)

            // Animated checkmark
            CheckmarkShape()
                .trim(from: 0, to: checkmarkProgress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 28, height: 28)
                .scaleEffect(circleScale)

            // Confetti particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.offset.width, y: particle.offset.height)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
        }
        .frame(width: 140, height: 140)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Phase 1: Circle draws itself (0 - 0.4s)
        withAnimation(.easeInOut(duration: 0.4)) {
            circleProgress = 1.0
            circleScale = 1.0
        }

        // Phase 2: Glow appears (0.3s)
        withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
            glowOpacity = 1.0
        }

        // Phase 3: Checkmark draws (0.35 - 0.65s)
        withAnimation(.easeOut(duration: 0.3).delay(0.35)) {
            checkmarkProgress = 1.0
        }

        // Phase 4: Confetti burst (0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            spawnConfetti()
        }

        // Phase 5: Glow fades (1.0 - 1.5s)
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            glowOpacity = 0.3
        }
    }

    private func spawnConfetti() {
        let colors: [Color] = [
            .clarityPrimary,
            .claritySecondary,
            .clarityAccent,
            .green,
            .white.opacity(0.8)
        ]

        // Create 12 particles in a radial burst
        for i in 0..<12 {
            let angle = Double(i) * (360.0 / 12.0) + Double.random(in: -15...15)
            let distance: CGFloat = CGFloat.random(in: 40...60)
            let rad = angle * .pi / 180.0

            let particle = ConfettiParticle(
                color: colors[i % colors.count],
                size: CGFloat.random(in: 4...7),
                offset: .zero,
                opacity: 1.0,
                scale: 1.0,
                targetOffset: CGSize(
                    width: cos(rad) * distance,
                    height: sin(rad) * distance
                )
            )
            particles.append(particle)
        }

        // Animate particles outward
        for index in particles.indices {
            withAnimation(.easeOut(duration: 0.5)) {
                particles[index].offset = particles[index].targetOffset
            }
            // Fade and shrink
            withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
                particles[index].opacity = 0
                particles[index].scale = 0.3
            }
        }
    }
}

// MARK: - Checkmark Shape

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Start from left, go down to bottom-center, then up-right
        let start = CGPoint(x: rect.width * 0.15, y: rect.height * 0.50)
        let mid = CGPoint(x: rect.width * 0.40, y: rect.height * 0.78)
        let end = CGPoint(x: rect.width * 0.85, y: rect.height * 0.22)

        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

// MARK: - Confetti Particle Model

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var offset: CGSize
    var opacity: Double
    var scale: CGFloat
    var targetOffset: CGSize
}

#Preview {
    ZStack {
        Color.black
        SuccessAnimationView()
    }
}
