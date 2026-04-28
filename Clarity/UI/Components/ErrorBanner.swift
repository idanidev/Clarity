// ErrorBanner.swift
// Reusable error display component

import SwiftUI

struct ErrorBanner: View {
    let error: Error
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            Text(error.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(Color.red.opacity(0.9))
        .cornerRadius(12)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - View Modifier

struct ErrorBannerModifier: ViewModifier {
    @Binding var error: Error?
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let error = error {
                ErrorBanner(error: error) {
                    withAnimation {
                        self.error = nil
                    }
                }
                .padding(.top, 60) // Adjust based on NavBar
                .zIndex(100)
                .task {
                    try? await Task.sleep(for: .seconds(5))
                    withAnimation {
                        self.error = nil
                    }
                }
            }
        }
    }
}

extension View {
    func withErrorBanner(error: Binding<Error?>) -> some View {
        modifier(ErrorBannerModifier(error: error))
    }
}
