// HomeEdicion.swift
// El modo edición de la Home, como el de la pantalla de inicio (2.4.0): si se
// está editando, qué tarjeta se arrastra y por dónde va.
//
// Aparte de `HomeViewModel`, que ya carga con todo lo del mes: esto es estado
// de pantalla que dura lo que dura la edición. El modelo solo guarda el orden
// cuando se suelta la tarjeta.

import Foundation
import CoreGraphics

@MainActor
@Observable
final class HomeEdicion {

    /// El espacio de coordenadas de la rejilla: marcos, dedo y copia flotante.
    nonisolated static let espacio = "rejilla-home"

    private(set) var activa = false
    var mostrandoGaleria = false

    /// La tarjeta que se arrastra.
    private(set) var arrastrando: String?
    /// El orden mientras se arrastra: las demás se apartan en vivo. Con el
    /// contenido de cada una fijado al empezar, para que una pila no cambie de
    /// tarjeta a medio camino. `nil` sin arrastre.
    var orden: [HomeDisposicion.Tarjeta]?
    /// Dónde va la copia flotante de la tarjeta, en la rejilla.
    private(set) var marcoArrastre: CGRect = .zero
    /// Soltada y volviendo a su sitio.
    private(set) var soltando = false

    /// Dónde está cada tarjeta. Sin observar: lo leen los gestos, no el pintado,
    /// y apuntarlo repintaría la rejilla con cada medida.
    @ObservationIgnored var marcos: [String: CGRect] = [:]
    @ObservationIgnored private var marcoInicial: CGRect = .zero
    /// La última tarjeta sobre la que se reordenó. Mientras el dedo siga
    /// encima no se vuelve a mover: al apartarse, la otra ocupa el sitio bajo
    /// el dedo y sin esto las dos se intercambiarían sin parar.
    @ObservationIgnored private var ultimoObjetivo: String?

    // MARK: - Entrar y salir

    /// - Parameter trasMenu: desde un menú contextual. Se espera a que se
    ///   recoja: cambiar la pantalla de debajo mientras se cierra dejaba la
    ///   vista previa volviendo a una tarjeta que ya no está.
    func entrar(trasMenu: Bool = false) {
        guard !activa else { return }
        if trasMenu {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                self?.entrar()
            }
            return
        }
        activa = true
        Migas.deja("home: entra en edición")
    }

    func salir() {
        guard activa else { return }
        activa = false
        mostrandoGaleria = false
        arrastrando = nil
        orden = nil
        soltando = false
        marcos = [:]
        Migas.deja("home: sale de edición")
    }

    // MARK: - Arrastrar

    /// Levanta la tarjeta `id`. `tarjetas` es lo que se ve ahora en la rejilla.
    @discardableResult
    func empezarArrastre(_ id: String, tarjetas: [HomeDisposicion.Tarjeta]) -> Bool {
        guard arrastrando == nil, let marco = marcos[id] else { return false }
        arrastrando = id
        orden = tarjetas
        marcoInicial = marco
        marcoArrastre = marco
        ultimoObjetivo = nil
        soltando = false
        return true
    }

    /// La copia flotante sigue al dedo. Sin animación: va pegada a él.
    func seguir(traslacion: CGSize) {
        marcoArrastre = marcoInicial.offsetBy(dx: traslacion.width, dy: traslacion.height)
    }

    /// El orden nuevo si el dedo ha entrado en otra tarjeta, para aplicarlo
    /// animado; `nil` si no toca moverse.
    func reordenar(dedo: CGPoint) -> [HomeDisposicion.Tarjeta]? {
        guard let id = arrastrando, let orden else { return nil }
        let objetivo = Self.objetivo(de: id, en: orden.map(\.id), dedo: dedo, marcos: marcos)
        defer { ultimoObjetivo = objetivo?.id }
        guard let objetivo, objetivo.id != ultimoObjetivo,
              let origen = orden.firstIndex(where: { $0.id == id }), origen != objetivo.indice
        else { return nil }
        var nuevo = orden
        nuevo.insert(nuevo.remove(at: origen), at: objetivo.indice)
        return nuevo
    }

    /// Suelta la tarjeta: la copia vuelve a su sitio (quien llama lo anima).
    /// Devuelve el orden nuevo si cambió, para guardarlo.
    func soltar() -> [String]? {
        guard let id = arrastrando, !soltando else { return nil }
        soltando = true
        if let destino = marcos[id] { marcoArrastre = destino }
        return orden?.map(\.id)
    }

    /// Ya en su sitio: fuera la copia flotante.
    func acabarArrastre() {
        arrastrando = nil
        orden = nil
        soltando = false
        ultimoObjetivo = nil
    }

    /// A qué puesto va la tarjeta `id` con el dedo en `dedo`: al de la tarjeta
    /// que tenga debajo, delante o detrás según venga de antes o de después, o
    /// al final si el dedo baja de la última. `nil` sobre un hueco, sobre su
    /// propio sitio o fuera. `id` del objetivo para no repetir (`ultimoObjetivo`).
    nonisolated static func objetivo(de id: String, en ids: [String], dedo: CGPoint,
                                     marcos: [String: CGRect]) -> (indice: Int, id: String)? {
        if let i = ids.firstIndex(where: { $0 != id && marcos[$0]?.contains(dedo) == true }) {
            return (i, ids[i])
        }
        let fondo = ids.compactMap { marcos[$0]?.maxY }.max() ?? .infinity
        if dedo.y > fondo, let ultimo = ids.indices.last { return (ultimo, "fin") }
        return nil
    }
}
