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
    func send(prompt: String, context: String, systemInstruction: String?) async throws -> String
    func categorizeBatch(descriptions: [String], categories: [String]) async throws -> [String:
        String]
}

extension AIServiceProvider {
    // Default implementation for providers that don't support custom batching (fallback to loop or basic json)
    func categorizeBatch(descriptions: [String], categories: [String]) async throws -> [String:
        String]
    {
        // Build a JSON prompt
        let prompt = """
            Classify these expenses into the following categories: \(categories.joined(separator: ", ")).
            Return strictly JSON format: {"description": "category"}.
            Expenses:
            \(descriptions.joined(separator: "\n"))
            """
        let response = try await send(
            prompt: prompt, context: "", systemInstruction: "You are a JSON classifier.")

        // Basic cleanup and parsing (naive)
        let cleanJson = response.replacingOccurrences(of: "```json", with: "").replacingOccurrences(
            of: "```", with: "")
        guard let data = cleanJson.data(using: .utf8),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return dict
    }
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
        return Secrets.geminiAPIKey
    }

    func send(prompt: String, context: String, systemInstruction: String? = nil) async throws
        -> String
    {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }

        let finalContext =
            systemInstruction != nil ? "\(systemInstruction!)\n\n\(context)" : context

        // Using gemini-2.0-flash-lite (faster, cheaper, supports latest features)
        let url = URL(
            string:
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=\(apiKey)"
        )!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Build request body
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": "\(finalContext)\n\nUser: \(prompt)"]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1024,
            ],
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
            let text = parts.first?["text"] as? String
        else {
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
        let savedKey = UserDefaults.standard.string(forKey: "groq_api_key")
        if let key = savedKey, !key.isEmpty {
            return key
        }
        // Fallback for local testing
        return Secrets.groqAPIKey
    }

    // Free models on Groq (very fast inference)
    private let model = "llama-3.1-8b-instant"

    func send(prompt: String, context: String, systemInstruction: String? = nil) async throws
        -> String
    {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey
        }

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        // System instruction handling
        let systemPrompt = systemInstruction ?? context

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt],
            ],
            "max_tokens": 1024,
            "temperature": 0.7,
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
            let content = message["content"] as? String
        else {
            throw AIServiceError.invalidResponse
        }

        return content
    }
}

// MARK: - AI Service Manager (Singleton)

@MainActor
class AIServiceManager {
    static let shared = AIServiceManager()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "AIService")

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
            let rawValue =
                UserDefaults.standard.string(forKey: "ai_provider") ?? ProviderType.groq.rawValue
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
    /// - Parameters:
    ///   - userMessage: The user's query
    ///   - customSystemPrompt: Optional override for the AI persona (e.g. Auditor Mode)
    func generateResponse(userMessage: String, customSystemPrompt: String? = nil) async throws
        -> String
    {
        let context = await buildFinancialContext()

        logger.info("🧠 Sending to \(self.currentProvider.name): \(userMessage.prefix(50))...")

        do {
            let response = try await currentProvider.send(
                prompt: userMessage, context: context, systemInstruction: customSystemPrompt)
            logger.info("✅ Response received (\(response.count) chars)")
            return response
        } catch {
            logger.error("❌ AI Error: \(error.localizedDescription)")

            // Fallback to other provider if primary fails
            if let fallbackResponse = try? await tryFallback(
                prompt: userMessage, context: context, systemInstruction: customSystemPrompt)
            {
                logger.info("✅ Fallback succeeded")
                return fallbackResponse
            }

            throw error
        }
    }

    /// Try the other provider as fallback
    private func tryFallback(prompt: String, context: String, systemInstruction: String?)
        async throws -> String
    {
        let fallbackProvider: AIServiceProvider = currentProviderType == .gemini ? groq : gemini
        logger.info("🔄 Trying fallback: \(fallbackProvider.name)")
        return try await fallbackProvider.send(
            prompt: prompt, context: context, systemInstruction: systemInstruction)
    }

    // MARK: - Batch Operations

    func categorizeExpenses(descriptions: [String], categories: [String]) async throws -> [String:
        String]
    {
        let uniqueDescriptions = Array(Set(descriptions))  // Dedup to save tokens
        logger.info(
            "🤖 Categorizing \(uniqueDescriptions.count) items with \(self.currentProvider.name)")

        // Chunking (max 50 to avoid token limits)
        let chunks = uniqueDescriptions.chunked(into: 50)
        var results: [String: String] = [:]

        for chunk in chunks {
            let chunkResult = try await currentProvider.categorizeBatch(
                descriptions: chunk, categories: categories)
            results.merge(chunkResult) { (_, new) in new }
        }

        return results
    }

    // MARK: - Dynamic Context Builder

    private func buildFinancialContext() async -> String {
        // Fetch current month's budget
        let year = Calendar.current.component(.year, from: Date())
        let month = Calendar.current.component(.month, from: Date())

        // Optimistic fetch (non-blocking if possible, but we need it for context)
        let budget = try? await FinancialService.shared.fetchMonthlyBudget(year: year, month: month)

        // Use PromptBuilder for optimized context
        return PromptBuilder.buildFinancialContext(
            user: UserDataManager.shared.userDocument,
            expenses: UserDataManager.shared.expenses,
            goals: [],  // Goals can be fetched via FinancialService if needed, passing empty for now or need to inject
            monthBudget: budget
        ) + "\n\n" + defaultPersona
    }

    private var defaultPersona: String {
        """
        Role: Eres Clarity Advisor, un analista financiero experto y riguroso. NO eres un chatbot básico.

        Data Context: Tienes los datos del usuario en <financial_context>.
        Principles: Usa los principios en <financial_principles> para juzgar las decisiones.

        Instrucciones de Pensamiento (Internal Monologue):
        Antes de responder, DEBES analizar la situación paso a paso dentro de un bloque <analysis>.
        1. Identifica el estado actual (Income vs Expenses).
        2. Revisa patrones históricos y tendencias.
        3. Aplica la regla 50/30/20 y otras reglas financieras relevantes.
        4. Decide la recomendación.

        Instrucciones de Respuesta (Output):
        - Solo después del análisis, genera la respuesta final al usuario.
        - Sé directo, usa emojis para suavizar, pero sé firme si la salud financiera corre riesgo.
        - NO muestres el bloque <analysis> en la respuesta final (o hazlo muy breve si es educativo).

        Ejemplos (Few-Shot):

        Input: "¿Me puedo comprar unas zapatillas de 120€?"
        <analysis>
        Income: 1500, Savings: 300 (Allocated). Free Cash: 1200.
        Spent so far: 800. Remaining: 400.
        Item cost: 120.
        Rule Check: Is it a 'Want'? Yes. Do we have excess cash? Yes.
        Trend: User buys lots of clothes (historical data says 150/month).
        Recommendation: Yes, but warn about impacting savings goals.
        </analysis>
        Response: "✅ Puedes permitírtelas, te quedarían 280€ libres. Peeeero... he visto que este mes ya llevas gasto en ropa. ¿Quizás esperar al mes que viene para no apretar el margen?"

        Input: "Analiza mi mes"
        <analysis>
        Income: 2000. Spent: 2100.
        Over Budget: Yes (100€).
        Top Category: Restaurants (500€).
        Rule 50/30/20: Wants are at 40%.
        Recommendation: Cut dining out immediately.
        </analysis>
        Response: "🚨 Alerta roja. Has gastado 100€ más de lo que ingresas. El culpable principal son los Restaurantes (500€). Cierra el grifo ya o tirarás de ahorros."

        Formato de Respuesta: Texto plano natural.
        """
    }
}
