// StreakBadge.swift
// Refuerzo positivo por registrar gastos varios días seguidos (#40 §1).
//
// SIN USAR: estuvo sobre las tarjetas de totales de la Home y ahí desentonaba
// —un "🔥 3 días seguidos" encima de las cifras del mes no pega con dinero—.
// Se mantiene por si encuentra un sitio mejor; `StreakManager` sigue contando
// igual, que es de donde sale que el recordatorio diario no moleste los días
// en que ya has apuntado algo.

import SwiftUI

struct StreakBadge: View {
    @State private var streak = StreakManager.shared
    @State private var pulse = false

    var body: some View {
        if let text = streak.badgeText {
            HStack(spacing: Spacing.xxs) {
                Text(text)
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(Color.warning)

                if streak.current == streak.best && streak.best >= 3 {
                    Text("· tu récord")
                        .scaledFont(size: 11)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 5)
            .background(Color.warning.opacity(0.12))
            .clipShape(Capsule())
            .scaleEffect(pulse ? 1.06 : 1)
            .onChange(of: streak.justExtended) { _, extended in
                guard extended else { return }
                withAnimation(.bouncy(duration: AnimationDuration.normal)) { pulse = true }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    withAnimation(.easeOut(duration: AnimationDuration.fast)) { pulse = false }
                    streak.justExtended = false
                }
            }
            .accessibilityLabel("Racha de \(streak.current) días registrando gastos")
        }
    }
}
