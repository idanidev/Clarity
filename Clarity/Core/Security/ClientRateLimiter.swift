// ClientRateLimiter.swift
// Capa 11 de seguridad — rate limiting en cliente (complemento al rate limiting en servidor).
// Evita ráfagas accidentales o abusivas de llamadas a Firebase/AI.

import Foundation

actor ClientRateLimiter {
    static let shared = ClientRateLimiter()

    private var timestamps: [String: [Date]] = [:]

    private init() {}

    /// Comprueba si la acción puede ejecutarse.
    /// - Parameters:
    ///   - action: Identificador de la acción (ej: "auth.signIn", "ai.chat")
    ///   - maxAttempts: Máximo de intentos en la ventana de tiempo
    ///   - window: Ventana de tiempo en segundos
    func checkLimit(action: String, maxAttempts: Int = 10, window: TimeInterval = 60) throws {
        let now = Date()
        let cutoff = now.addingTimeInterval(-window)
        timestamps[action] = (timestamps[action] ?? []).filter { $0 > cutoff }
        guard (timestamps[action]?.count ?? 0) < maxAttempts else {
            throw AppError.rateLimited
        }
        timestamps[action, default: []].append(now)
    }

    /// Elimina el historial de una acción (ej: tras logout)
    func reset(action: String) {
        timestamps.removeValue(forKey: action)
    }

    func resetAll() {
        timestamps.removeAll()
    }
}

// MARK: - Límites predefinidos para Clarity

extension ClientRateLimiter {
    /// Login / registro: máximo 5 intentos por minuto
    func checkAuthLimit() throws {
        try checkLimit(action: "auth.signIn", maxAttempts: 5, window: 60)
    }

    /// Mensajes al AI: máximo 20 por minuto
    func checkAILimit() throws {
        try checkLimit(action: "ai.chat", maxAttempts: 20, window: 60)
    }

    /// Creación de gastos: máximo 30 por minuto
    func checkExpenseCreationLimit() throws {
        try checkLimit(action: "expense.create", maxAttempts: 30, window: 60)
    }
}
