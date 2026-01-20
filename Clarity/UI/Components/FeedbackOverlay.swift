// FeedbackOverlay.swift
// Visual component for displaying global feedback

import SwiftUI

struct FeedbackOverlay: View {
    var message: FeedbackMessage
    var onDismiss: () -> Void
    
    var body: some View {
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.top, 8) // Top safe area usually handled by linkage, adding margin
            .onTapGesture {
                onDismiss()
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
        .zIndex(9999) // Always on top
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
        FeedbackOverlay(
            message: FeedbackMessage(type: .success, title: "Guardado", message: "Gasto registrado correctamente"),
            onDismiss: {}
        )
    }
}
