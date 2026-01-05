// AIAssistantViewModel.swift
// AI Assistant logic

import Foundation
import FirebaseFunctions
import Observation

@MainActor
@Observable
class AIAssistantViewModel {
    // MARK: - Properties (No @Published)
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading = false
    
    var quotaRemaining: Int = 3
    var quotaTotal: Int = 3
    var isUnlimited: Bool = false
    
    // MARK: - Suggestions
    let suggestions = [
        "Analiza mis gastos de este mes",
        "¿En qué categoría gasto más?",
        "Dame consejos para ahorrar",
        "Compara mis gastos con el mes anterior"
    ]
    
    // MARK: - Dependencies
    private let functions = Functions.functions()
    
    // MARK: - Methods
    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(content: text, isUser: true)
        messages.append(userMessage)
        inputText = ""
        
        // Send to AI
        Task {
            await askAI(query: text)
        }
    }
    
    private func askAI(query: String) async {
        isLoading = true
        
        do {
            let callable = functions.httpsCallable("askDeepSeek")
            
            let data: [String: Any] = [
                "query": query,
                "contextData": [:] // Could include expense data
            ]
            
            let result = try await callable.call(data)
            
            if let response = result.data as? [String: Any],
               let content = response["content"] as? String {
                
                let aiMessage = ChatMessage(content: content, isUser: false)
                messages.append(aiMessage)
                
                // Update quota
                if let remaining = response["quotaRemaining"] as? Int {
                    quotaRemaining = remaining
                }
            }
        } catch {
            let errorMessage = ChatMessage(
                content: "Lo siento, ha ocurrido un error. Inténtalo de nuevo.",
                isUser: false
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
}

// MARK: - Chat Message
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date = Date()
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
