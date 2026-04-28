// OfflineBanner.swift
// Shows a banner when the device is offline

import SwiftUI

struct OfflineBanner: View {
    var network = NetworkMonitor.shared

    var body: some View {
        if !network.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption.bold())
                Text(String(localized: "offline.title", defaultValue: "Sin conexión"))
                    .font(.caption.bold())
                Spacer()
                Text(String(localized: "offline.usingLocalData", defaultValue: "Usando datos locales"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.gradient)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sin conexión a internet. Usando datos locales.")
        }
    }
}
