// SuccessToast.swift
// Shared Success Toast Component

import SwiftUI

struct SuccessToast: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .padding(.horizontal)
    }
}
