// AsyncTimeout.swift
// Timeout para operaciones remotas: sin cobertura o con red degradada, las
// llamadas de Firestore pueden no resolver nunca y dejaban la app colgada
// en la pantalla de carga (issue #32).

import Foundation

struct TimeoutError: LocalizedError {
    let seconds: TimeInterval
    var errorDescription: String? {
        "La operación superó el tiempo límite (\(Int(seconds))s)"
    }
}

/// Ejecuta `operation` cancelándola si tarda más de `seconds`.
/// - Throws: `TimeoutError` si expira, o el error propio de la operación.
func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError(seconds: seconds)
        }

        guard let result = try await group.next() else {
            throw TimeoutError(seconds: seconds)
        }
        group.cancelAll()
        return result
    }
}
