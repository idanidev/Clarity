// AIAssistantView.swift
// AI Assistant chat interface

import SwiftUI

struct AIAssistantView: View {
    @StateObject private var viewModel = AIAssistantViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quota Indicator
                QuotaIndicatorView(
                    remaining: viewModel.quotaRemaining,
                    total: viewModel.quotaTotal,
                    isUnlimited: viewModel.isUnlimited
                )
                .padding()
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Spacing.sm) {
                            if viewModel.messages.isEmpty {
                                SuggestionsView(suggestions: viewModel.suggestions) { suggestion in
                                    viewModel.sendMessage(suggestion)
                                }
                            }
                            
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Bar
                ChatInputBar(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    onSend: {
                        viewModel.sendMessage(viewModel.inputText)
                    }
                )
            }
            .navigationTitle("Asistente IA")
        }
    }
}

// MARK: - Quota Indicator
struct QuotaIndicatorView: View {
    let remaining: Int
    let total: Int
    let isUnlimited: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.clarityPrimary)
            
            if isUnlimited {
                Text("Consultas ilimitadas")
                    .font(.clarityCaption)
            } else {
                Text("\(remaining)/\(total) consultas restantes")
                    .font(.clarityCaption)
                
                Spacer()
                
                ProgressView(value: Double(remaining), total: Double(total))
                    .frame(width: 60)
                    .tint(Color.clarityPrimary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.xs)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Suggestions
struct SuggestionsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("¿Qué quieres saber?")
                .font(.clarityTitle3)
            
            Text("Pregúntame sobre tus gastos, análisis o consejos de ahorro")
                .font(.claritySubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: Spacing.sm) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.claritySubheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Chat Bubble
struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: Spacing.xxs) {
                Text(message.content)
                    .font(.clarityBody)
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .padding()
                    .background(
                        message.isUser 
                            ? Color.clarityPrimary 
                            : Color.secondaryBackground
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(message.formattedTime)
                    .font(.clarityCaption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - Chat Input Bar
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Escribe tu pregunta...", text: $text)
                .textFieldStyle(.roundedBorder)
            
            Button(action: onSend) {
                if isLoading {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(text.isEmpty ? .secondary : Color.clarityPrimary)
                }
            }
            .disabled(text.isEmpty || isLoading)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    AIAssistantView()
}
