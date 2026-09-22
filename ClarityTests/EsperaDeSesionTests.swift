// EsperaDeSesionTests.swift
// La espera a que Auth restaure la sesión: se reanuda una sola vez y retira
// siempre la escucha, llegue la sesión o salte el tope.

import Testing
import Foundation
@testable import Clarity

@MainActor
struct EsperaDeSesionTests {

    /// Hace de Firebase Auth: guarda a quién avisar y cuenta las retiradas.
    @MainActor
    private final class EscuchaFalsa {
        var alCambiar: (@MainActor (Bool) -> Void)?
        var retiradas = 0

        /// Deja correr a la tarea que espera hasta que se haya registrado.
        func esperaRegistro() async {
            for _ in 0..<1_000 where alCambiar == nil { await Task.yield() }
        }
    }

    @Test("Cuando llega la sesión devuelve true y retira la escucha")
    func llegaLaSesion() async {
        let escucha = EscuchaFalsa()
        let espera = Task { @MainActor in
            await EsperaDeSesion.esperar(tope: .seconds(5)) { alCambiar in
                escucha.alCambiar = alCambiar
                return { escucha.retiradas += 1 }
            }
        }
        await escucha.esperaRegistro()

        // El primer aviso de Firebase suele ser «todavía no hay nadie»: se ignora.
        escucha.alCambiar?(false)
        #expect(escucha.retiradas == 0)

        escucha.alCambiar?(true)
        // Un aviso repetido no reanuda la continuación dos veces (eso revienta).
        escucha.alCambiar?(true)

        #expect(await espera.value)
        #expect(escucha.retiradas == 1)
    }

    @Test("Si nadie entra, el tope devuelve false y también retira la escucha")
    func saltaElTope() async {
        let escucha = EscuchaFalsa()
        let haySesion = await EsperaDeSesion.esperar(tope: .milliseconds(50)) { alCambiar in
            escucha.alCambiar = alCambiar
            return { escucha.retiradas += 1 }
        }

        #expect(!haySesion)
        #expect(escucha.retiradas == 1)

        // Una sesión que llega tarde ya no hace nada.
        escucha.alCambiar?(true)
        #expect(escucha.retiradas == 1)
    }

    @Test("Una escucha que avisa nada más registrarse también se retira")
    func avisoInmediato() async {
        let escucha = EscuchaFalsa()
        let haySesion = await EsperaDeSesion.esperar(tope: .seconds(5)) { alCambiar in
            alCambiar(true)
            return { escucha.retiradas += 1 }
        }

        #expect(haySesion)
        #expect(escucha.retiradas == 1)
    }
}
