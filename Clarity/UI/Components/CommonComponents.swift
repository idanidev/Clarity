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


// MARK: - Button Styles
struct ClarityProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.clarityPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.bouncy(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ClarityProminentButtonStyle {
    static var clarityProminent: ClarityProminentButtonStyle { ClarityProminentButtonStyle() }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.clarityHeadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(
                disabled ? Color.gray : Color.clarityPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
        }
        .disabled(disabled || isLoading)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.clarityHeadline)
                .foregroundStyle(Color.clarityPrimary)                .frame(maxWidth: .infinity)
                .frame(height: Spacing.buttonHeight)
                .background(Color.clarityPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
        }
    }
}

#Preview("Loading") {
    LoadingView()
}


// Empty State Preview removed as struct was deleted
