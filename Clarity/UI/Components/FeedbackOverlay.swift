// FeedbackOverlay.swift
// Visual component for displaying global feedback

import SwiftUI

struct FeedbackOverlay: View {
    var message: FeedbackMessage
    var onDismiss: () -> Void

    var body: some View {
        if message.type == .success && message.action == nil {
            successOverlay
        } else {
            standardOverlay
        }
    }

    // MARK: - Success Celebration Overlay

    private var successOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                SuccessAnimationView()

                VStack(spacing: 4) {
                    Text(message.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let detail = message.message {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(1)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.clarityPrimary.opacity(0.2), radius: 20, y: 8)
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            .onTapGesture {
                onDismiss()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .transition(.opacity)
        .zIndex(9999)
    }

    // MARK: - Standard Toast Overlay

    private var standardOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: message.type.icon)
                    .font(.title3)
                    .foregroundStyle(message.type.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let detail = message.message {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if let label = message.actionLabel, let action = message.action {
                    Button {
                        action()
                        onDismiss()
                    } label: {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(message.type.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(message.type.color.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .safeAreaPadding(.top)
            .onTapGesture {
                // Only dismiss on tap if there's no action button
                if message.action == nil {
                    onDismiss()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.height < -10 {
                            onDismiss()
                        }
                    }
            )

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(9999)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
        FeedbackOverlay(
            message: FeedbackMessage(type: .success, title: "Gasto guardado", message: "50€ en Mercadona", actionLabel: "Deshacer", action: {}),
            onDismiss: {}
        )
    }
}
