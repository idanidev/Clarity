// SkeletonView.swift
// Shimmering loading placeholder

import SwiftUI

struct SkeletonView: View {
    @State private var phase: CGFloat = 0
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.bgSecondary)
            .overlay(
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width)
                        .offset(x: -geo.size.width + (phase * 2 * geo.size.width))
                }
            )
            .mask(Rectangle().cornerRadius(cornerRadius))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

// MARK: - Modifiers for easy usage

extension View {
    @ViewBuilder
    func skeleton(active: Bool, cornerRadius: CGFloat = 8) -> some View {
        if active {
            SkeletonView(cornerRadius: cornerRadius)
        } else {
            self
        }
    }
}

#Preview {
    VStack {
        SkeletonView()
            .frame(width: 200, height: 20)
        
        Text("Loaded Content")
            .skeleton(active: true)
            .frame(width: 150, height: 20)
    }
    .padding()
    .background(Color.bgPrimary)
}
