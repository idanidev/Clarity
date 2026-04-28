//
//  AIService.swift
//  Clarity
//
//  Multi-Provider AI Service — Gemini 2.0 Flash (primary) + Groq (fallback)
//

import Foundation
import OSLog

// MARK: - Protocol

protocol AIServiceProvider {
    var name: String { get }
    var hasKey: Bool { get }
    /// messages: OpenAI-style array [{role: system/user/assistant, content: "..."}]
    func send(messages: [[String: String]]) async throws -> String
}

extension AIServiceProvider {
    func categorizeBatch(descriptions: [String], categories: [String]) async throws -> [String: String] {
        let prompt = """
            Classify these expenses into the following categories: \(categories.joined(separator: ", ")).
            Return strictly JSON format: {"description": "category"}.
            Expenses:
            \(descriptions.joined(separator: "\n"))
            """
        let response = try await send(messages: [
            ["role": "system", "content": "You are a JSON classifier."],
            ["role": "user", "content": prompt]
        ])
        let clean = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        guard let data = clean.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
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
        case user, assistant, system
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

    var errorDescription: String? {
        switch self {
        case .noAPIKey:            return "API Key no configurada"
        case .networkError(let m): return "Error de red: \(m)"
        case .invalidResponse:     return "Respuesta inválida del servidor"
        case .rateLimited:         return "Límite de uso alcanzado. Cambiando proveedor..."
        }
    }
}

// MARK: - Gemini 2.0 Flash Provider

class GeminiProvider: AIServiceProvider {
    let name = "Gemini 2.0 Flash"

    private static let keychainKey = "clarity.api.gemini"

    private var apiKey: String? {
        // 1. Keychain (fuente segura, configurada por el usuario desde Settings)
        if let key = APIKeychain.get(Self.keychainKey), !key.isEmpty { return key }
        // 2. Secrets.swift (compilado, solo para desarrollo)
        return Secrets.geminiAPIKey.isEmpty ? nil : Secrets.geminiAPIKey
    }

    static func saveKey(_ key: String) { APIKeychain.set(key, forKey: keychainKey) }
    static func deleteKey() { APIKeychain.delete(keychainKey) }

    var hasKey: Bool { apiKey != nil }

    private let model = "gemini-2.0-flash"

    func send(messages: [[String: String]]) async throws -> String {
        guard let apiKey else { throw AIServiceError.noAPIKey }

        // Extract system prompt — Gemini uses system_instruction separately
        let systemText = messages.first(where: { $0["role"] == "system" })?["content"] ?? ""
        let conversation = messages.filter { $0["role"] != "system" }

        // Build Gemini contents (roles: "user" / "model")
        let contents: [[String: Any]] = conversation.map { msg in
            let role = msg["role"] == "assistant" ? "model" : "user"
            return ["role": role, "parts": [["text": msg["content"] ?? ""]]]
        }

        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": ["maxOutputTokens": 4096, "temperature": 0.65]
        ]
        if !systemText.isEmpty {
            body["system_instruction"] = ["parts": [["text": systemText]]]
        }

        // API key en header (no en URL — evita logs/proxies/network inspectors)
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: urlStr) else { throw AIServiceError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        if http.statusCode == 429 { throw AIServiceError.rateLimited }
        guard http.statusCode == 200 else {
            throw AIServiceError.networkError("Status \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else { throw AIServiceError.invalidResponse }

        return text
    }
}

// MARK: - Groq Provider

class GroqProvider: AIServiceProvider {
    let name = "Groq (llama-3.3-70b)"

    private static let keychainKey = "clarity.api.groq"

    private var apiKey: String? {
        if let key = APIKeychain.get(Self.keychainKey), !key.isEmpty { return key }
        return Secrets.groqAPIKey.isEmpty ? nil : Secrets.groqAPIKey
    }

    static func saveKey(_ key: String) { APIKeychain.set(key, forKey: keychainKey) }
    static func deleteKey() { APIKeychain.delete(keychainKey) }

    var hasKey: Bool { apiKey != nil }

    private let model = "llama-3.3-70b-versatile"

    func send(messages: [[String: String]]) async throws -> String {
        guard let apiKey else { throw AIServiceError.noAPIKey }

        guard let groqURL = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw AIServiceError.invalidResponse
        }
        var request = URLRequest(url: groqURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 4096,
            "temperature": 0.65
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        if http.statusCode == 429 { throw AIServiceError.rateLimited }
        guard http.statusCode == 200 else {
            throw AIServiceError.networkError("Status \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else { throw AIServiceError.invalidResponse }

        return content
    }
}

// MARK: - AI Service Manager

@MainActor
class AIServiceManager {
    static let shared = AIServiceManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "AIService")
    private let gemini = GeminiProvider()
    private let groq = GroqProvider()

    /// Preferred provider key stored in UserDefaults ("gemini" | "groq")
    var preferredProviderKey: String {
        get { UserDefaults.standard.string(forKey: "ai_preferred_provider") ?? "gemini" }
        set { UserDefaults.standard.set(newValue, forKey: "ai_preferred_provider") }
    }

    var currentProvider: AIServiceProvider {
        preferredProviderKey == "groq" ? groq : gemini
    }

    private var fallbackProvider: AIServiceProvider {
        preferredProviderKey == "groq" ? gemini : groq
    }

    var currentProviderName: String { currentProvider.name }

    private init() {}

    // MARK: - Public API

    /// Sends a message with full financial context + conversation history.
    /// Automatically falls back to the other provider if rate-limited.
    func generateResponse(
        userMessage: String,
        history: [AIMessage] = [],
        customSystemPrompt: String? = nil
    ) async throws -> String {
        let financialContext = await buildFinancialContext()
        let persona = customSystemPrompt ?? defaultPersona
        let systemContent = persona + "\n\n" + financialContext

        // Build message array: system + last 12 history exchanges + new user message
        var messages: [[String: String]] = [["role": "system", "content": systemContent]]
        for msg in history.suffix(12) {
            let role = msg.role == .assistant ? "assistant" : "user"
            messages.append(["role": role, "content": msg.content])
        }
        messages.append(["role": "user", "content": userMessage])

        logger.info("🧠 [\(self.currentProvider.name)] Sending message (\(userMessage.count) chars)")

        do {
            let response = try await currentProvider.send(messages: messages)
            logger.info("✅ Response received (\(response.count) chars)")
            return response
        } catch AIServiceError.rateLimited {
            logger.warning("⚠️ Rate limited on \(self.currentProvider.name), trying \(self.fallbackProvider.name)")
            let response = try await fallbackProvider.send(messages: messages)
            logger.info("✅ Fallback response received (\(response.count) chars)")
            return response
        }
    }

    // MARK: - Batch Operations

    func categorizeExpenses(descriptions: [String], categories: [String]) async throws -> [String: String] {
        let unique = Array(Set(descriptions))
        logger.info("🤖 Categorizing \(unique.count) items")
        var results: [String: String] = [:]
        for chunk in unique.chunked(into: 50) {
            let r = try await currentProvider.categorizeBatch(descriptions: chunk, categories: categories)
            results.merge(r) { _, new in new }
        }
        return results
    }

    // MARK: - Financial Context

    private func buildFinancialContext() async -> String {
        let year = Calendar.current.component(.year, from: Date())
        let month = Calendar.current.component(.month, from: Date())

        let financialService = DependencyContainer.shared.financialService
        async let budget = financialService.fetchMonthlyBudget(year: year, month: month)
        async let goals = financialService.fetchGoals()
        async let recurring = DependencyContainer.shared.recurringExpenseRepository.fetchAll()

        return PromptBuilder.buildFinancialContext(
            user: UserDataManager.shared.userDocument,
            expenses: UserDataManager.shared.expenses,
            goals: (try? await goals) ?? [],
            monthBudget: try? await budget,
            recurringExpenses: (try? await recurring) ?? []
        )
    }

    // MARK: - Personas

    private var defaultPersona: String {
        """
        Eres Clara, asesora financiera personal dentro de Clarity. \
        Hablas español natural, directo y con opinión propia — como una amiga que sabe de finanzas, \
        no como un chatbot corporativo.

        DATOS: Los datos REALES del usuario están en <financial_context>. Son tu única fuente de verdad. \
        Nunca inventes cifras. Si no hay datos de un período, dilo.

        PRIMERA FRASE: SIEMPRE abre con un dato concreto del contexto. Ejemplos:
        - "Llevas **847€** gastados a día 15, eso es el 62% de tus ingresos..."
        - "Alimentación se lleva **312€**, un 23% del total — es tu categoría más pesada..."
        - "A este ritmo acabas el mes en **2.100€**, que son **300€** por encima de lo que ingresas..."
        NUNCA abras con: "Claro", "Buena pregunta", "Entiendo", "Vamos a ver", "Por supuesto", \
        "Analizando tus datos", "Según tus datos". Ve directo al dato.

        FORMATO:
        - Sin encabezados markdown (sin # ## ###).
        - **Negritas** para cifras clave y porcentajes.
        - Emojis con criterio: ⚠️ alerta, ✅ bien, 📉📈 tendencia, 💡 consejo, 🎯 meta.
        - Frases cortas. Un párrafo = una idea. No más de 3 líneas por bloque.
        - Pregunta simple → respuesta de 2-4 frases. Análisis completo → detallado pero sin relleno.

        ESTILO:
        - Menciona gastos individuales por nombre real ("esa cena de **45€** en Restaurantes") \
          para demostrar que has leído los datos, no que estás dando consejos genéricos.
        - Directa y honesta — si algo está mal, lo dices sin endulzar.
        - Cierra SIEMPRE con una acción concreta o una pregunta que invite a profundizar.
        - Zero relleno: nada de "espero haberte ayudado", "no dudes en preguntar", "recuerda que".
        - Si hay buenas noticias, celébralas en una línea y pasa a lo siguiente.

        ANÁLISIS:
        - Presupuesto: usa "Realmente disponible" de <resumen> (ya descuenta compromisos fijos). \
          Compara "Proyección fin de mes" con ingresos para alertar déficit.
        - Categorías: usa <limites_gasto> si existen — alerta EXCEDIDO/ALERTA. \
          Top 2-3 categorías más pesadas, picos vs meses anteriores.
        - Ahorro: "Tasa de ahorro" < 10% → sugiere objetivo concreto. \
          Estado de huchas en <metas>.
        - Tendencias: <tendencia_3_meses> para contextualizar. "Media diaria" para evaluar ritmo.
        - Ritmo: usa <insights> para el indicador de ritmo y el gasto más grande. \
          Si % gastado > % mes → "vas por delante del ritmo saludable".
        - Patrones: usa el día de mayor gasto de <insights> para dar consejos específicos \
          (ej: "Los sábados es cuando más gastas — planifica esos días").

        LÍMITE: Solo finanzas personales. \
        Otro tema: "Solo puedo ayudarte con tus finanzas en Clarity."
        """
    }
}
