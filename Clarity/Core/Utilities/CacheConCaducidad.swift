// CacheConCaducidad.swift
// Caché en memoria para una lectura que varias pantallas piden casi a la vez.

import Foundation

/// Guarda un valor durante `ttl` segundos y hace que las peticiones
/// simultáneas compartan una sola carga.
///
/// Pensada para las reglas recurrentes: al arrancar las piden la Home, Metas,
/// las gráficas y el gestor de recurrentes en el mismo segundo, y cada una
/// hacía su consulta.
///
/// Va por usuario (`dueño`): lo guardado para uno nunca se le sirve a otro,
/// aunque nadie haya llamado a `invalidar()` entre medias.
///
/// Sin `Sendable` en `Valor` a propósito: todo ocurre en el main actor, y los
/// modelos con `@DocumentID` de Firestore no lo son.
@MainActor
final class CacheConCaducidad<Valor> {
    private let ttl: TimeInterval
    private let ahora: () -> Date

    private var guardado: (valor: Valor, fecha: Date)?
    private var dueñoActual: String?
    /// Sube con cada invalidación. Una carga que empezó antes no se guarda al
    /// terminar: puede traer lo que había antes de la escritura que invalidó.
    private var generacion = 0
    /// Generación de la carga en marcha, si la hay.
    private var enVuelo: Int?
    /// Quién espera el resultado de cada carga, además de quien la lanzó.
    private var esperando: [Int: [CheckedContinuation<Valor, Error>]] = [:]

    /// `ahora` es inyectable para probar la caducidad sin esperar.
    init(ttl: TimeInterval, ahora: @escaping () -> Date = Date.init) {
        self.ttl = ttl
        self.ahora = ahora
    }

    /// Lo guardado si sigue vigente; si no, el resultado de `cargar`, que se
    /// ejecuta una sola vez aunque lleguen más peticiones mientras tanto.
    func valor(para dueño: String, cargar: () async throws -> Valor) async throws -> Valor {
        // Otro usuario: ni lo guardado ni lo que esté en marcha valen para él.
        if dueñoActual != dueño {
            invalidar()
            dueñoActual = dueño
        }

        if let guardado {
            let edad = ahora().timeIntervalSince(guardado.fecha)
            // `edad >= 0`: si el reloj va hacia atrás no se alarga la vigencia.
            if edad >= 0, edad < ttl { return guardado.valor }
        }

        let miGeneracion = generacion
        if enVuelo == miGeneracion {
            return try await withCheckedThrowingContinuation {
                esperando[miGeneracion, default: []].append($0)
            }
        }

        enVuelo = miGeneracion
        let resultado: Result<Valor, Error>
        do {
            resultado = .success(try await cargar())
        } catch {
            resultado = .failure(error)
        }

        // Si mientras llegaba se invalidó y hay otra carga, `enVuelo` es suyo.
        if enVuelo == miGeneracion { enVuelo = nil }
        if generacion == miGeneracion, case .success(let valor) = resultado {
            guardado = (valor, ahora())
        }
        for continuacion in esperando.removeValue(forKey: miGeneracion) ?? [] {
            continuacion.resume(with: resultado)
        }
        return try resultado.get()
    }

    /// Tras una escritura: lo guardado ya no vale, y la carga que esté en
    /// marcha tampoco se guardará.
    func invalidar() {
        generacion += 1
        guardado = nil
    }

    /// Al cerrar sesión o cambiar de usuario.
    func vaciar() {
        invalidar()
        dueñoActual = nil
    }
}
