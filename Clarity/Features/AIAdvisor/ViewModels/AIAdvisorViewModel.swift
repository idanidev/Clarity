//
//  AIAdvisorViewModel.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  ViewModel for AI Chat Interface
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class AIAdvisorViewModel {
    // MARK: - State
    private(set) var messages: [AIMessage] = []
    private(set) var isLoading = false
    private(set) var error: String?
    
    // Input
    var inputText = ""
    
    // Service
    private let aiService = AIServiceManager.shared
    
    // MARK: - Suggested Prompts
    let suggestions = [
        "¿Cómo voy este mes?",
        "¿En qué puedo ahorrar?",
        "Analiza mis gastos recientes",
        "¿Cuál es mi categoría más cara?"
    ]
    
    // MARK: - Computed
    
    var hasMessages: Bool {
        !messages.filter { $0.role != .system }.isEmpty
    }
    
    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    var currentProviderName: String {
        aiService.currentProvider.name
    }
    
    // MARK: - Actions
    
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = AIMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        
        // Haptic feedback
        HapticManager.shared.playSoftImpact()
        
        isLoading = true
        error = nil
        
        do {
            let response = try await aiService.generateResponse(userMessage: text)
            
            // Add AI response
            let aiMessage = AIMessage(role: .assistant, content: response)
            messages.append(aiMessage)
            
            // Success haptic
            HapticManager.shared.playSuccess()
            
        } catch {
            self.error = error.localizedDescription
            HapticManager.shared.error()
        }
        
        isLoading = false
    }
    
    func sendSuggestion(_ text: String) async {
        inputText = text
        await sendMessage()
    }
    
    func clearChat() {
        messages.removeAll()
        error = nil
    }
    
    func dismissError() {
        error = nil
    }
}
