//
//  AIAdvisorView.swift
//  Clarity
//
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

                                if viewModel.isLoading {
                                    TypingIndicator()
                                        .id("typing")
                                }
                            } else {
                                emptyState
                            }
                        }
                        .padding()
                        .onTapGesture {
                            isInputFocused = false
                        }
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if viewModel.isLoading {
                                proxy.scrollTo("typing", anchor: .bottom)
                            } else if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Quick action chips (visible once conversation has started)
                if viewModel.hasMessages {
                    quickActions
                }

                // Input Bar
                inputBar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Clara")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await AIRateLimiter.shared.sync()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.clearChat()
                        } label: {
                            Label("Limpiar Chat", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Opciones del chat")
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
                .scaledFont(size: 56)
                .foregroundStyle(Color.clarityPrimary)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 8) {
                Text("Clara")
                    .font(.title2.bold())

                Text("Asesora financiera con acceso\na todos tus datos reales.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Vertical suggestion buttons (prominent, first visit)
            VStack(spacing: 10) {
                ForEach(viewModel.suggestions) { suggestion in
                    Button {
                        Task { await viewModel.sendSuggestion(suggestion) }
                    } label: {
                        Text(suggestion.display)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.clarityPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .fill(Color.clarityPrimary.opacity(0.1))
                            )
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 4) {
                Text("Usando: \(viewModel.currentProviderName)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("\(viewModel.remainingQueries) de 3 consultas semanales")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    // MARK: - Quick Actions (inline chips during conversation)

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.suggestions) { suggestion in
                    Button {
                        Task { await viewModel.sendSuggestion(suggestion) }
                    } label: {
                        Text(suggestion.display)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.clarityPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.clarityPrimary.opacity(0.08))
                            )
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
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
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .scaledFont(size: 32)
                    .foregroundStyle(viewModel.canSend ? Color.clarityPrimary : .gray)
            }
            .disabled(!viewModel.canSend)
            .accessibilityLabel("Enviar mensaje")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(LocalizedStringKey(message.content))
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .textSelection(.enabled)
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

#Preview {
    AIAdvisorView()
}
