// EsperaDeSesion.swift
// Esperar a que Firebase Auth restaure la sesión, sin sondear.
//
// Al arrancar, `Auth.auth().currentUser` es nil durante un momento aunque el
// usuario tenga sesión: Firebase la está leyendo del llavero. Metas sondeaba
// 5 × 300 ms y, si el arranque iba lento, se rendía con un «No autenticado»
// falso. Aquí se escucha el cambio de sesión, con un tope para no esperar para
// siempre a alguien que de verdad no ha entrado.
//
// Mismo patrón que `UserDataManager.loadUserData()`: el listener se retira
// SIEMPRE —llegue la sesión o salte el tope— y la continuación se reanuda una
// sola vez.

import FirebaseAuth
import Foundation

@MainActor
enum EsperaDeSesion {
    /// Retira la escucha. Se llama una sola vez.
    typealias Retirar = @MainActor () -> Void

    /// `true` si hay sesión, ya o antes de que pase `tope`.
    static func haySesion(tope: Duration = .seconds(3)) async -> Bool {
        if Auth.auth().currentUser != nil { return true }
        return await esperar(tope: tope) { alCambiar in
            let escucha = Auth.auth().addStateDidChangeListener { _, user in
                let hay = user != nil
                // Firebase avisa en el hilo principal; el salto lo deja escrito
                // para el compilador y no cuesta nada si ya estamos en él.
                Task { @MainActor in alCambiar(hay) }
            }
            return { Auth.auth().removeStateDidChangeListener(escucha) }
        }
    }

    /// El mecanismo, sin Firebase, para poder probarlo.
    ///
    /// - Parameter escuchar: registra la escucha y devuelve cómo retirarla. Llama
    ///   a `alCambiar(true)` cuando hay sesión; los avisos con `false` se ignoran
    ///   (el primero de Firebase suele ser «todavía no hay nadie»).
    static func esperar(
        tope: Duration,
        escuchar: (_ alCambiar: @escaping @MainActor (Bool) -> Void) -> Retirar
    ) async -> Bool {
        let estado = Estado()
        return await withCheckedContinuation { (continuacion: CheckedContinuation<Bool, Never>) in
            let resolver: @MainActor (Bool) -> Void = { haySesion in
                guard !estado.resuelto else { return }
                estado.resuelto = true
                estado.tope?.cancel()
                estado.retirar?()
                estado.retirar = nil
                continuacion.resume(returning: haySesion)
            }

            let retirar = escuchar { haySesion in
                if haySesion { resolver(true) }
            }
            if estado.resuelto {
                // La escucha avisó antes de devolver cómo retirarla: se retira ahora.
                retirar()
                return
            }
            estado.retirar = retirar

            estado.tope = Task { @MainActor in
                try? await Task.sleep(for: tope)
                guard !Task.isCancelled else { return }
                resolver(false)
            }
        }
    }

    /// Todo corre en el main actor, así que no hace falta cerrojo.
    @MainActor
    private final class Estado {
        var resuelto = false
        var retirar: Retirar?
        var tope: Task<Void, Never>?
    }
}
