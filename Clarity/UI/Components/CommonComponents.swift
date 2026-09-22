// LoadingView.swift
// Reusable loading indicator

import SwiftUI

struct LoadingView: View {
    var message: String = String(localized: "common.loading", defaultValue: "Cargando...")
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.clarityPrimary)
            
            Text(message)
                .font(.claritySubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondaryBackground)
    }
}

#Preview("Loading") {
    LoadingView()
}
