//
//  AIAdvisorViewModel.swift
//  Clarity
//
//  ViewModel for AI Chat Interface
//

import Foundation
import OSLog
import Observation

// MARK: - Suggestion Model

struct AISuggestion: Identifiable {
    let id = UUID()
    let display: String
    let prompt: String
    let isDeepAnalysis: Bool

    init(_ display: String, prompt: String, deep: Bool = false) {
        self.display = display
        self.prompt = prompt
        self.isDeepAnalysis = deep
    }
}

// MARK: - ViewModel

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
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "AIAdvisorViewModel")

    // MARK: - Suggestions

    let suggestions: [AISuggestion] = [
        AISuggestion(
            "Auditoría completa",
            prompt: "Haz una auditoría completa: analiza cada categoría, compara con meses anteriores, identifica problemas de ritmo de gasto, evalúa mis límites de gasto y huchas, y dame un plan de acción concreto con cifras.",
            deep: true
        ),
        AISuggestion(
            "¿Dónde gasto de más?",
            prompt: "Analiza en qué categorías estoy gastando más de lo razonable. Compara con mis ingresos y con los meses anteriores. Identifica los 3 mayores problemas con cifras exactas y menciona gastos concretos por nombre."
        ),
        AISuggestion(
            "¿Cómo voy este mes?",
            prompt: "Diagnóstico rápido del mes: ¿estoy dentro del presupuesto? ¿Mi ritmo de gasto es sostenible para lo que queda de mes? ¿Algún límite de gasto en riesgo? Usa los insights de ritmo y proyección."
        ),
        AISuggestion(
            "3 formas de ahorrar",
            prompt: "Basándote en mis gastos reales de este mes, dame exactamente 3 acciones concretas y medibles para reducir gastos. Con cifras de cuánto ahorraría con cada una. Menciona gastos específicos que podría evitar o reducir."
        ),
        AISuggestion(
            "¿Cuánto me queda?",
            prompt: "Calcula exactamente cuánto dinero me queda disponible hasta fin de mes, descontando los compromisos fijos pendientes. ¿Cuánto puedo gastar por día de aquí a final de mes? Si tengo huchas activas, recuérdame cuánto he destinado."
        ),
        AISuggestion(
            "vs mes pasado",
            prompt: "Compara este mes con el anterior en detalle: ¿gasto más o menos? ¿En qué categorías ha cambiado más? ¿La tendencia es buena o preocupante? Dame cifras exactas y menciona gastos nuevos que no tenía el mes pasado."
        ),
        AISuggestion(
            "Patrón semanal",
            prompt: "Analiza mis patrones de gasto por día de la semana. ¿Qué días gasto más? ¿Hay un patrón de 'gasto de fin de semana'? Dame estrategias específicas para los días más caros."
        ),
    ]

    // MARK: - Computed

    var hasMessages: Bool {
        !messages.filter { $0.role != .system }.isEmpty
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var currentProviderName: String {
        aiService.currentProviderName
    }

    // MARK: - Actions

    var remainingQueries: Int { AIRateLimiter.shared.remaining }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard AIRateLimiter.shared.canQuery else {
            error = AIRateLimiter.shared.limitReachedMessage()
            HapticManager.shared.error()
            return
        }

        let userMessage = AIMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""

        HapticManager.shared.playSoftImpact()

        isLoading = true
        error = nil

        do {
            let history = messages.filter { $0.role != .system }.dropLast()
            let response = try await aiService.generateResponse(
                userMessage: text,
                history: Array(history)
            )

            messages.append(AIMessage(role: .assistant, content: cleanHeaders(response)))
            await AIRateLimiter.shared.record()
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.safeUserMessage
            HapticManager.shared.error()
        }

        isLoading = false
    }

    func sendSuggestion(_ suggestion: AISuggestion) async {
        guard !isLoading else { return }

        guard AIRateLimiter.shared.canQuery else {
            error = AIRateLimiter.shared.limitReachedMessage()
            HapticManager.shared.error()
            return
        }

        // Show the short display text as the user bubble
        messages.append(AIMessage(role: .user, content: suggestion.display))

        HapticManager.shared.playSoftImpact()

        isLoading = true
        error = nil

        do {
            let history = messages.filter { $0.role != .system }.dropLast()
            let response = try await aiService.generateResponse(
                userMessage: suggestion.prompt,
                history: Array(history),
                customSystemPrompt: suggestion.isDeepAnalysis ? auditorPersona : nil
            )

            messages.append(AIMessage(role: .assistant, content: cleanHeaders(response)))
            await AIRateLimiter.shared.record()
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.safeUserMessage
            HapticManager.shared.error()
            logger.error("AI Error: \(error)")
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

    // MARK: - Private

    private var auditorPersona: String {
        """
        Eres un auditor financiero implacable. Analiza los datos reales en <financial_context> \
        y haz un diagnóstico profundo sin compasión.

        ABRE con la cifra más alarmante o relevante. Nada de introducciones.

        ESTRUCTURA cubriendo lo relevante (no todo siempre):
        - El problema principal con cifras exactas del contexto
        - Categorías donde más se gasta vs ingresos — menciona gastos por nombre real
        - Comparación con meses anteriores si hay tendencia clara
        - Si hay <limites_gasto>, cuáles están en riesgo o excedidos
        - Ritmo de gasto vs lo que queda de mes (usa "Proyección fin de mes" del resumen)
        - Acciones concretas, medibles, con cifras de ahorro estimado

        FORMATO: Sin encabezados markdown (#). Usa **negritas** para cifras y emojis para separar visualmente. \
        Cada bloque debe ser corto y directo — máximo 2 líneas por punto.

        REGLAS: Solo cifras reales del contexto. Nunca inventes. Si algo va bien, dilo en una línea y pasa \
        a lo que necesita atención.
        """
    }

    private func cleanHeaders(_ text: String) -> String {
        text
            .replacingOccurrences(of: "### ", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "# ", with: "")
    }
}
