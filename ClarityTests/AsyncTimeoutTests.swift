// AsyncTimeoutTests.swift
// `withTimeout` tiene que soltar a quien espera aunque la operación no atienda
// a la cancelación, que es lo que hace Firestore con mala cobertura (#32).

import Testing
import Foundation
@testable import Clarity

@MainActor
struct AsyncTimeoutTests {

    private struct Fallo: Error, Equatable {}

    @Test("Una operación rápida devuelve su valor")
    func devuelveAntesDelTope() async throws {
        let valor = try await withTimeout(2) { 42 }
        #expect(valor == 42)
    }

    @Test("El error propio de la operación llega tal cual")
    func propagaElError() async {
        await #expect(throws: Fallo.self) {
            try await withTimeout(2) { throw Fallo() }
        }
    }

    @Test("Una operación lenta que coopera con la cancelación lanza TimeoutError")
    func topeConOperacionQueCoopera() async {
        await #expect(throws: TimeoutError.self) {
            try await withTimeout(0.1) {
                try await Task.sleep(for: .seconds(5))
                return 0
            }
        }
    }

    @Test("Una operación que ignora la cancelación no retiene a quien espera")
    func topeConOperacionSorda() async {
        let reloj = ContinuousClock()
        let inicio = reloj.now
        await #expect(throws: TimeoutError.self) {
            try await withTimeout(0.2) {
                // Como una lectura de Firestore: no mira `Task.isCancelled`.
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) { c.resume() }
                }
                return 0
            }
        }
        // Con el `TaskGroup` de antes esto tardaba los 3 s enteros.
        #expect(reloj.now - inicio < .seconds(1.5))
    }
}
