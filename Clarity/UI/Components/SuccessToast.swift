// SuccessToast.swift
// Shared Success Toast Component

import SwiftUI

struct SuccessToast: View {
    let message: String
    /// Pasa a `true` al aparecer: dispara el rebote del check.
    @State private var aparecido = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.success)
                // El check rebota al aparecer: se nota que se ha guardado. Con
                // «Reducir movimiento» aparece quieto.
                .reboteDeSimbolo(cuando: aparecido)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding()
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .padding(.horizontal)
        .safeAreaPadding(.top)  // avoid Dynamic Island / notch
        .onAppear { aparecido = true }
    }
}
