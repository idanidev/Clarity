// CacheConCaducidadTests.swift
// La política de la caché de reglas recurrentes: caducidad, invalidación,
// dueño y una sola carga para las peticiones simultáneas. El repositorio
// habla con Firestore y no se puede probar sin red; la política, sí.

import Foundation
import Testing
@testable import Clarity

@Suite("CacheConCaducidad")
@MainActor
struct CacheConCaducidadTests {

    /// Reloj que avanza a mano, para probar la caducidad sin esperar.
    @MainActor
    private final class Reloj {
        var ahora = Date(timeIntervalSince1970: 1_800_000_000)
    }

    @MainActor
    private final class Contador {
        var cargas = 0
    }

    /// Retiene una carga hasta que el test la suelta.
    @MainActor
    private final class Puerta {
        private var abierta = false
        private var esperando: [CheckedContinuation<Void, Never>] = []

        func esperar() async {
            guard !abierta else { return }
            await withCheckedContinuation { esperando.append($0) }
        }

        func abrir() {
            abierta = true
            esperando.forEach { $0.resume() }
            esperando = []
        }
    }

    private struct FalloDePrueba: Error {}

    private func nuevaCache(_ reloj: Reloj, ttl: TimeInterval = 60) -> CacheConCaducidad<[String]> {
        CacheConCaducidad(ttl: ttl, ahora: { reloj.ahora })
    }

    @Test("Dentro del TTL se sirve lo guardado sin volver a cargar")
    func sirveLoGuardado() async throws {
        let reloj = Reloj(), contador = Contador()
        let cache = nuevaCache(reloj)

        let primero = try await cache.valor(para: "uid") { contador.cargas += 1; return ["netflix"] }
        reloj.ahora += 59
        let segundo = try await cache.valor(para: "uid") { contador.cargas += 1; return ["otra cosa"] }

        #expect(primero == ["netflix"])
        #expect(segundo == ["netflix"])
        #expect(contador.cargas == 1)
    }

    @Test("Pasado el TTL se vuelve a cargar")
    func caduca() async throws {
        let reloj = Reloj(), contador = Contador()
        let cache = nuevaCache(reloj)

        _ = try await cache.valor(para: "uid") { contador.cargas += 1; return ["v1"] }
        reloj.ahora += 60
        let segundo = try await cache.valor(para: "uid") { contador.cargas += 1; return ["v2"] }

        #expect(segundo == ["v2"])
        #expect(contador.cargas == 2)
    }

    @Test("Si el reloj va hacia atrás no se alarga la vigencia")
    func relojHaciaAtras() async throws {
        let reloj = Reloj(), contador = Contador()
        let cache = nuevaCache(reloj)

        _ = try await cache.valor(para: "uid") { contador.cargas += 1; return ["v1"] }
        reloj.ahora -= 3600
        _ = try await cache.valor(para: "uid") { contador.cargas += 1; return ["v2"] }

        #expect(contador.cargas == 2)
    }

    @Test("Invalidar obliga a cargar de nuevo: quien lee tras escribir ve lo escrito")
    func invalidar() async throws {
        let reloj = Reloj(), contador = Contador()
        let cache = nuevaCache(reloj)

        _ = try await cache.valor(para: "uid") { contador.cargas += 1; return ["antes"] }
        cache.invalidar()
        let despues = try await cache.valor(para: "uid") { contador.cargas += 1; return ["despues"] }

        #expect(despues == ["despues"])
        #expect(contador.cargas == 2)
    }

    @Test("Lo guardado para un usuario no se le sirve a otro")
    func cambioDeUsuario() async throws {
        let reloj = Reloj(), contador = Contador()
        let cache = nuevaCache(reloj)

        _ = try await cache.valor(para: "ana") { contador.cargas += 1; return ["de ana"] }
        let deLuis = try await cache.valor(para: "luis") { contador.cargas += 1; return ["de luis"] }
        // Y al volver la primera tampoco se reutiliza lo de antes del cambio.
        let deAna = try await cache.valor(para: "ana") { contador.cargas += 1; return ["de ana, otra vez"] }

        #expect(deLuis == ["de luis"])
        #expect(deAna == ["de ana, otra vez"])
        #expect(contador.cargas == 3)
    }

    @Test("Vaciar, al cerrar sesión, no deja nada que servir")
    func vaciar() async throws {
        let reloj = Reloj(), contador = Contador()
        let cache = nuevaCache(reloj)

        _ = try await cache.valor(para: "uid") { contador.cargas += 1; return ["v1"] }
        cache.vaciar()
        let otra = try await cache.valor(para: "uid") { contador.cargas += 1; return ["v2"] }

        #expect(otra == ["v2"])
        #expect(contador.cargas == 2)
    }

    @Test("Las peticiones simultáneas comparten una sola carga")
    func cargaCompartida() async throws {
        let reloj = Reloj(), contador = Contador(), puerta = Puerta()
        let cache = nuevaCache(reloj)

        let peticiones = (1...4).map { n in
            Task {
                try await cache.valor(para: "uid") {
                    contador.cargas += 1
                    await puerta.esperar()
                    return ["carga de la petición \(n)"]
                }
            }
        }
        // Que lleguen todas mientras la primera sigue cargando.
        while contador.cargas == 0 { await Task.yield() }
        for _ in 0..<20 { await Task.yield() }
        puerta.abrir()

        var resultados: [[String]] = []
        for peticion in peticiones { resultados.append(try await peticion.value) }

        #expect(contador.cargas == 1)
        #expect(Set(resultados).count == 1)
    }

    @Test("Una carga que estaba en marcha al invalidar no se guarda")
    func cargaEnMarchaAlInvalidar() async throws {
        let reloj = Reloj(), contador = Contador(), puerta = Puerta()
        let cache = nuevaCache(reloj)

        let lenta = Task {
            try await cache.valor(para: "uid") {
                contador.cargas += 1
                await puerta.esperar()
                return ["lo que había antes de escribir"]
            }
        }
        while contador.cargas == 0 { await Task.yield() }

        // Llega una escritura mientras la lectura sigue fuera.
        cache.invalidar()
        let fresca = try await cache.valor(para: "uid") { contador.cargas += 1; return ["lo escrito"] }
        puerta.abrir()
        // Quien la pidió antes de la escritura recibe lo suyo…
        #expect(try await lenta.value == ["lo que había antes de escribir"])

        // …pero lo que queda guardado es lo posterior a la escritura.
        let guardado = try await cache.valor(para: "uid") { contador.cargas += 1; return ["no debería cargarse"] }
        #expect(fresca == ["lo escrito"])
        #expect(guardado == ["lo escrito"])
        #expect(contador.cargas == 2)
    }

    @Test("Un fallo se propaga a todos los que esperaban y no se guarda")
    func fallo() async throws {
        let reloj = Reloj(), contador = Contador(), puerta = Puerta()
        let cache = nuevaCache(reloj)

        let peticiones = (1...2).map { _ in
            Task {
                try await cache.valor(para: "uid") {
                    contador.cargas += 1
                    await puerta.esperar()
                    throw FalloDePrueba()
                }
            }
        }
        while contador.cargas == 0 { await Task.yield() }
        for _ in 0..<20 { await Task.yield() }
        puerta.abrir()

        for peticion in peticiones {
            await #expect(throws: FalloDePrueba.self) { try await peticion.value }
        }

        let despues = try await cache.valor(para: "uid") { contador.cargas += 1; return ["recuperado"] }
        #expect(despues == ["recuperado"])
    }
}
