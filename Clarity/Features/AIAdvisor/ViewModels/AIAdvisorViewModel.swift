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
    
    /// Triggers "The Auditor" mode for deep analysis
    func triggerDeepAnalysis() async {
        guard !isLoading else { return }
        
        // This is a special command that triggers the analysis prompt
        let prompt = "Analiza todos mis gastos"
        
        // Add user message (local only)
        let userMessage = AIMessage(role: .user, content: prompt)
        messages.append(userMessage)
        
        isLoading = true
        error = nil
        
        // Define The Auditor Persona
        let auditorPersona = """
        ACTÚA COMO: Auditor Financiero Senior (Agresivo pero justo).
        
        TU MISIÓN:
        Analiza los datos financieros proporcionados y genera un informe estructurado en MARKDOWN.
        
        FORMATO DE RESPUESTA (Usa exactamente estos emojis y secciones):
        
        # 🕵️‍♂️ Informe de Auditoría
        
        ### 🔍 El Diagnóstico
        [Identifica la mayor fuga de dinero o comportamiento riesgoso. Sé directo.]
        
        ### 📉 La Tijera
        [Elige UN gasto recurrente o categoría para recortar. Calcula el ahorro anual proyectado (x12). Sé dramático con el impacto a largo plazo.]
        
        ### 🚀 Plan de Acción
        [Un reto concreto para la próxima semana. Ej: "Cero gastos en cafeterías".]
        
        NOTA: No saludes. Ve al grano. Usa negritas para cifras importantes.
        """
        
        do {
            HapticManager.shared.playImpact(.heavy)
            
            let response = try await aiService.generateResponse(userMessage: prompt, customSystemPrompt: auditorPersona)
            
            // Add AI response
            let aiMessage = AIMessage(role: .assistant, content: response)
            messages.append(aiMessage)
            
            HapticManager.shared.playSuccess()
            
        } catch {
            self.error = error.localizedDescription
            HapticManager.shared.error()
            print("❌ AI Error: \(error)")
        }
        
        isLoading = false
    }
    
    func clearChat() {
        messages = []
        error = nil
    }
    
    func dismissError() {
        error = nil
    }
}
