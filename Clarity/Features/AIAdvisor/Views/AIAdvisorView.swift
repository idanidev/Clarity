//
//  AIAdvisorView.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  Modern Chat UI for AI Financial Advisor
//

import SwiftUI

struct AIAdvisorView: View {
    @State private var viewModel = AIAdvisorViewModel()
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if viewModel.hasMessages {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                // Typing Indicator
                                if viewModel.isLoading {
                                    TypingIndicator()
                                        .id("typing")
                                }
                            } else {
                                // Empty State with Suggestions
                                emptyState
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        // Auto-scroll to bottom
                        withAnimation(.easeOut(duration: 0.3)) {
                            if viewModel.isLoading {
                                proxy.scrollTo("typing", anchor: .bottom)
                            } else if let lastMessage = viewModel.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input Bar
                inputBar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Clarity Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(AIServiceManager.ProviderType.allCases, id: \.self) { provider in
                            Button {
                                AIServiceManager.shared.currentProviderType = provider
                            } label: {
                                HStack {
                                    Text(provider.rawValue)
                                    if AIServiceManager.shared.currentProviderType == provider {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            viewModel.clearChat()
                        } label: {
                            Label("Limpiar Chat", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Color.clarityPrimary)
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(spacing: 8) {
                Text("Clarity Advisor")
                    .font(.title2.bold())
                
                Text("Tu asesor financiero personal.\nPregúntame sobre tus gastos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Suggestions
            VStack(spacing: 12) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        Task {
                            await viewModel.sendSuggestion(suggestion)
                        }
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(Color.clarityPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.clarityPrimary.opacity(0.1))
                            )
                    }
                }
            }
            
            Spacer()
            
            // Provider indicator
            Text("Usando: \(viewModel.currentProviderName)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Pregunta algo...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isInputFocused)
                .lineLimit(1...4)
            
            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(viewModel.canSend ? Color.clarityPrimary : .gray)
            }
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIMessage
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(LocalizedStringKey(message.content)) // Supports Markdown
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isUser ? Color.clarityPrimary : Color(uiColor: .secondarySystemGroupedBackground))
                    )
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationOffset = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset == index ? -4 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                animationOffset = 2
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AIAdvisorView()
}
