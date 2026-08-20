// ProBadge.swift
// Distintivo para funciones que requieren Clarity Pro.

import SwiftUI

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .scaledFont(size: 10, weight: .bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.clarityPrimary.gradient)
            .clipShape(Capsule())
            .accessibilityLabel("Función Pro")
    }
}
