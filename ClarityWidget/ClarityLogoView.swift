// ClarityLogoView.swift (Widget target)
// Copia del componente principal para el target ClarityWidgetExtension.

import SwiftUI

struct ClarityLogoView: View {
    var size: CGFloat = 120

    private var cornerRadius: CGFloat { size * 0.22 }
    private var padding: CGFloat      { size * 0.18 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 139/255, green: 92/255, blue: 246/255),
                            Color(red: 99/255,  green: 102/255, blue: 241/255),
                            Color(red: 79/255,  green: 70/255, blue: 229/255),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear,
                        ],
                        center: .init(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: size * 0.40
                    )
                )
                .frame(width: size * 0.7, height: size * 0.7)
                .offset(x: -size * 0.05, y: -size * 0.08)

            ClarityGem()
                .padding(padding)
        }
        .frame(width: size, height: size)
    }
}

private struct ClarityGem: View {
    var body: some View {
        Canvas { ctx, size in
            let w  = size.width
            let h  = size.height
            let cx = w / 2

            let top      = CGPoint(x: cx, y: 0)
            let gLeft    = CGPoint(x: 0,  y: h * 0.38)
            let gRight   = CGPoint(x: w,  y: h * 0.38)
            let gCenterL = CGPoint(x: cx * 0.55, y: h * 0.38)
            let gCenterR = CGPoint(x: cx * 1.45, y: h * 0.38)
            let gCenter  = CGPoint(x: cx, y: h * 0.38)
            let bottom   = CGPoint(x: cx, y: h)
            let pavLeft  = CGPoint(x: w * 0.22, y: h * 0.65)
            let pavRight = CGPoint(x: w * 0.78, y: h * 0.65)

            // Corona
            var f1 = Path()
            f1.move(to: top); f1.addLine(to: gCenterL); f1.addLine(to: gLeft); f1.closeSubpath()
            ctx.fill(f1, with: .color(.white.opacity(0.95)))

            var f2 = Path()
            f2.move(to: top); f2.addLine(to: gCenter); f2.addLine(to: gCenterL); f2.closeSubpath()
            ctx.fill(f2, with: .color(.white.opacity(0.85)))

            var f3 = Path()
            f3.move(to: top); f3.addLine(to: gCenterR); f3.addLine(to: gCenter); f3.closeSubpath()
            ctx.fill(f3, with: .color(.white.opacity(0.72)))

            var f4 = Path()
            f4.move(to: top); f4.addLine(to: gRight); f4.addLine(to: gCenterR); f4.closeSubpath()
            ctx.fill(f4, with: .color(.white.opacity(0.60)))

            // Pabellon
            var f5 = Path()
            f5.move(to: gLeft); f5.addLine(to: gCenterL); f5.addLine(to: pavLeft); f5.closeSubpath()
            ctx.fill(f5, with: .color(.white.opacity(0.78)))

            var f6 = Path()
            f6.move(to: gCenterL); f6.addLine(to: gCenterR); f6.addLine(to: bottom)
            f6.addLine(to: pavLeft); f6.closeSubpath()
            ctx.fill(f6, with: .color(.white.opacity(0.68)))

            var f7 = Path()
            f7.move(to: gCenterR); f7.addLine(to: pavRight); f7.addLine(to: bottom); f7.closeSubpath()
            ctx.fill(f7, with: .color(.white.opacity(0.50)))

            var f8 = Path()
            f8.move(to: gCenterR); f8.addLine(to: gRight); f8.addLine(to: pavRight); f8.closeSubpath()
            ctx.fill(f8, with: .color(.white.opacity(0.42)))

            // Aristas
            let lineWidth = max(w * 0.018, 0.5)
            var edges = Path()
            edges.move(to: top);      edges.addLine(to: gLeft)
            edges.move(to: top);      edges.addLine(to: gCenterL)
            edges.move(to: top);      edges.addLine(to: gCenter)
            edges.move(to: top);      edges.addLine(to: gCenterR)
            edges.move(to: top);      edges.addLine(to: gRight)
            edges.move(to: gLeft);    edges.addLine(to: gRight)
            edges.move(to: gLeft);    edges.addLine(to: pavLeft)
            edges.move(to: pavLeft);  edges.addLine(to: bottom)
            edges.move(to: gCenterL); edges.addLine(to: pavLeft)
            edges.move(to: gCenterL); edges.addLine(to: bottom)
            edges.move(to: gCenterR); edges.addLine(to: bottom)
            edges.move(to: gCenterR); edges.addLine(to: pavRight)
            edges.move(to: pavRight); edges.addLine(to: bottom)
            edges.move(to: gRight);   edges.addLine(to: pavRight)
            ctx.stroke(
                edges,
                with: .color(.white.opacity(0.15)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            let highlightCenter = CGPoint(
                x: (top.x + gCenterL.x + gLeft.x) / 3,
                y: (top.y + gCenterL.y + gLeft.y) / 3
            )
            let highlightRadius = w * 0.18
            let highlight = Path(ellipseIn: CGRect(
                x: highlightCenter.x - highlightRadius * 0.6,
                y: highlightCenter.y - highlightRadius * 0.4,
                width: highlightRadius * 1.2,
                height: highlightRadius * 0.8
            ))
            ctx.fill(highlight, with: .color(.white.opacity(0.25)))
        }
    }
}
