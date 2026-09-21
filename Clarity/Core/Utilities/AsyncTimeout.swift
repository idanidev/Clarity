// AsyncTimeout.swift
// Timeout para operaciones remotas: sin cobertura o con red degradada, las
// llamadas de Firestore pueden no resolver nunca y dejaban la app colgada
// en la pantalla de carga (issue #32).

import Foundation

nonisolated struct TimeoutError: LocalizedError {
    let seconds: TimeInterval
    var errorDescription: String? {
        "La operación superó el tiempo límite (\(Int(seconds))s)"
    }
}

/// Quien llega primero —la operación o el reloj— reanuda la continuación; el
/// otro llega tarde y no hace nada.
private nonisolated final class Carrera: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var resuelta = false

    func gana() -> Bool {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        if resuelta { return false }
        resuelta = true
        return true
    }
}

/// Ejecuta `operation` y deja de esperarla si tarda más de `seconds`.
///
/// Con tareas sueltas y no con un `TaskGroup`: el grupo espera a todas sus
/// hijas antes de devolver, también a las canceladas, y Firestore no atiende a
/// la cancelación. Con el grupo, un tope de 1 s sobre una lectura de 5 s salía
/// a los 5 s, y una lectura que no contesta nunca no salía nunca: justo el caso
/// para el que existe esto. Aquí la operación que pierde sigue por su cuenta y
/// su resultado se descarta.
/// - Throws: `TimeoutError` si expira, o el error propio de la operación.
nonisolated func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let carrera = Carrera()
    return try await withCheckedThrowingContinuation { (continuacion: CheckedContinuation<T, Error>) in
        let trabajo = Task {
            do {
                let valor = try await operation()
                if carrera.gana() { continuacion.resume(returning: valor) }
            } catch {
                if carrera.gana() { continuacion.resume(throwing: error) }
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard carrera.gana() else { return }
            // Por si la operación sí coopera; si no, se queda sola.
            trabajo.cancel()
            continuacion.resume(throwing: TimeoutError(seconds: seconds))
        }
    }
}
