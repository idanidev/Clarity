//
//  AIService.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  Multi-Provider AI Service (Strategy Pattern)
//

import Foundation
import OSLog

// MARK: - Protocol (Strategy)

protocol AIServiceProvider {
    var name: String { get }
    func send(prompt: String, context: String) async throws -> String
}

// MARK: - AI Message Model

struct AIMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    
    enum Role: String {
        case user
        case assistant
        case system
    }
    
    init(role: Role, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case noAPIKey
    case networkError(String)
    case invalidResponse
    case rateLimited
    case providerUnavailable
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API Key no configurada"
        case .networkError(let message):
            return "Error de red: \(message)"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .rateLimited:
            return "Demasiadas solicitudes. Espera un momento."
        case .providerUnavailable:
            return "Proveedor de IA no disponible"
        }
    }
}

// MARK: - Gemini Provider

class GeminiProvider: AIServiceProvider {
    let name = "Gemini"
    
    // TODO: Move to secure storage (Keychain) for production
    private var apiKey: String? {
        // Hardcoded for development - replace with your key
        return "AIzaSyBblEpBQTj9vaWa7acd7mgh3aWj6QfO3Vk"
    }
    
    func send(prompt: String, context: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }
        
        // Using gemini-1.5-flash-latest (auto-resolves to latest available version)
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": "\(context)\n\nUser: \(prompt)"]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1024
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw AIServiceError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("Status \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AIServiceError.invalidResponse
        }
        
        return text
    }
}

// MARK: - Groq Provider (Free Tier - Very Fast!)

class GroqProvider: AIServiceProvider {
    let name = "Groq"
    
    // Get free API key from https://console.groq.com/keys
    private var apiKey: String? {
        // TODO: Get your free key from Groq Console
        return UserDefaults.standard.string(forKey: "groq_api_key")
    }
    
    // Free models on Groq (very fast inference)
    private let model = "llama-3.1-8b-instant"
    
    func send(prompt: String, context: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }
        
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": context],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw AIServiceError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("Status \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse OpenAI-compatible response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }
        
        return content
    }
}

// MARK: - AI Service Manager (Singleton)

@MainActor
class AIServiceManager {
    static let shared = AIServiceManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "AIService")
    
    enum ProviderType: String, CaseIterable {
        case gemini = "Gemini"
        case groq = "Groq"
    }
    
    // Available providers
    private let gemini = GeminiProvider()
    private let groq = GroqProvider()
    
    // Current selection (stored in UserDefaults)
    var currentProviderType: ProviderType {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "ai_provider") ?? ProviderType.groq.rawValue
            return ProviderType(rawValue: rawValue) ?? .groq
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ai_provider")
        }
    }
    
    var currentProvider: AIServiceProvider {
        switch currentProviderType {
        case .gemini: return gemini
        case .groq: return groq
        }
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Generate a response with automatic context injection
    func generateResponse(userMessage: String) async throws -> String {
        let context = buildFinancialContext()
        
        logger.info("🧠 Sending to \(self.currentProvider.name): \(userMessage.prefix(50))...")
        
        do {
            let response = try await currentProvider.send(prompt: userMessage, context: context)
            logger.info("✅ Response received (\(response.count) chars)")
            return response
        } catch {
            logger.error("❌ AI Error: \(error.localizedDescription)")
            
            // Fallback to other provider if primary fails
            if let fallbackResponse = try? await tryFallback(prompt: userMessage, context: context) {
                logger.info("✅ Fallback succeeded")
                return fallbackResponse
            }
            
            throw error
        }
    }
    
    /// Try the other provider as fallback
    private func tryFallback(prompt: String, context: String) async throws -> String {
        let fallbackProvider: AIServiceProvider = currentProviderType == .gemini ? groq : gemini
        logger.info("🔄 Trying fallback: \(fallbackProvider.name)")
        return try await fallbackProvider.send(prompt: prompt, context: context)
    }
    
    // MARK: - Dynamic Context Builder
    
    private func buildFinancialContext() -> String {
        let userData = UserDataManager.shared
        let expenses = userData.expenses
        
        // Get current month stats
        let calendar = Calendar.current
        let now = Date()
        let currentMonthExpenses = expenses.filter {
            guard let date = Formatters.date(from: $0.date) else { return false }
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        }
        
        let totalSpent = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        
        // Top category
        let categoryTotals = Dictionary(grouping: currentMonthExpenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let topCategory = categoryTotals.max(by: { $0.value < $1.value })?.key ?? "N/A"
        
        // Recent transactions (last 5)
        let recentTransactions = currentMonthExpenses
            .sorted { Formatters.date(from: $0.date) ?? Date() > Formatters.date(from: $1.date) ?? Date() }
            .prefix(5)
            .map { "- \($0.name): \(Formatters.currency($0.amount)) (\($0.category))" }
            .joined(separator: "\n")
        
        // Build system prompt
        return """
        Role: Eres Clarity Advisor, un asesor financiero personal amigable y motivador.
        Responde siempre en español. Sé conciso pero útil.
        
        Datos del Usuario (Este Mes):
        - Gastado hasta ahora: \(Formatters.currency(totalSpent))
        - Categoría principal: \(topCategory)
        - Número de gastos: \(currentMonthExpenses.count)
        
        Últimas Transacciones:
        \(recentTransactions.isEmpty ? "Sin gastos recientes" : recentTransactions)
        
        Instrucciones:
        - Basa tus respuestas en los datos reales del usuario.
        - Si te preguntan "cómo voy", analiza el gasto vs. patrones típicos.
        - Ofrece consejos prácticos y específicos.
        - Usa emojis para hacer las respuestas más amigables.
        - Mantén las respuestas breves (máximo 3 párrafos).
        """
    }
}
