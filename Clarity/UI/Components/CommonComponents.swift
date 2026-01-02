// LoadingView.swift
// Reusable loading indicator

import SwiftUI

struct LoadingView: View {
    var message: String = "Cargando..."
    
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

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.clarityTitle3)
                
                Text(message)
                    .font(.claritySubheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.clarityHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clarityPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                }
                .padding(.horizontal, Spacing.xl)
            }
        }
        .padding(Spacing.xl)
    }
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

#Preview("Empty State") {
    EmptyStateView(
        icon: "wallet.bifold",
        title: "No hay gastos",
        message: "Añade tu primer gasto para comenzar a controlar tus finanzas",
        actionTitle: "Añadir Gasto"
    ) {
        print("Add tapped")
    }
}
