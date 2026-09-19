// VoiceFlowFixesTests.swift
// La lógica pura de los arreglos del flujo de voz (auditoría 2.3.1): cuándo
// guarda sola la hoja de confirmación, qué descripción llega al formulario
// manual cuando al dictado le falta el importe, cómo se agrupan las recargas
// del widget y la señal de «categorías del usuario ya cargadas».
//
// Nada de esto toca disco ni red: el coordinador se prueba por el método que
// no apunta estadísticas, y el gestor de datos, con el almacén de mentira.

import Foundation
import Testing
@testable import Clarity

// MARK: - Cuenta atrás de la hoja de confirmación

@Suite("Voz · cuenta atrás de la confirmación")
@MainActor
struct VoiceCountdownPolicyTests {

    private func ajustes(retardo: TimeInterval, autoConfirm: Bool = false) -> VoiceSettings {
        var s = VoiceSettings.default
        s.autoConfirmDelay = retardo
        s.autoConfirm = autoConfirm
        return s
    }

    @Test("Detección completa: hay cuenta atrás")
    func deteccionCompleta() {
        #expect(ajustes(retardo: 5).arrancaCuentaAtras(deteccionCompleta: true))
    }

    @Test("Detección incompleta: no se guarda solo, revise quien revise")
    func deteccionIncompleta() {
        #expect(!ajustes(retardo: 5).arrancaCuentaAtras(deteccionCompleta: false))
        // «Confirmación automática» decide otra cosa (saltarse la hoja): no
        // resucita la cuenta atrás de un gasto con la categoría supuesta.
        #expect(!ajustes(retardo: 5, autoConfirm: true).arrancaCuentaAtras(deteccionCompleta: false))
    }

    @Test("Sin retardo configurado no hay cuenta atrás ni con detección completa")
    func sinRetardo() {
        #expect(!ajustes(retardo: 0).arrancaCuentaAtras(deteccionCompleta: true))
    }
}

// MARK: - Descripción para el formulario manual

@Suite("Voz · descripción para el formulario manual")
@MainActor
struct VoiceManualDraftTests {

    private let parser = SmartTransactionParser()

    @Test("Quita el verbo de comando y pone mayúscula inicial")
    func quitaElVerbo() {
        #expect(parser.descripcionParaFormulario(de: "Añade gasolina") == "Gasolina")
        #expect(parser.descripcionParaFormulario(de: "apunta mercadona") == "Mercadona")
    }

    @Test("«añade» no sobrevive aunque vaya detrás de una muletilla")
    func quitaElVerboTrasMuletilla() {
        let limpio = parser.descripcionParaFormulario(de: "pues añade mercadona")
        #expect(limpio == "Mercadona")
        #expect(!limpio.lowercased().contains("añade"))
    }

    @Test("Quita preposiciones y artículos como en un gasto bien parseado")
    func quitaPreposiciones() {
        #expect(parser.descripcionParaFormulario(de: "apunta café en el bar") == "Café bar")
    }

    @Test("Si no queda nada devuelve vacío, no «Gasto General»")
    func vacioSiNoQuedaNada() {
        // En el campo del formulario un «Gasto General» habría que borrarlo a mano.
        #expect(parser.descripcionParaFormulario(de: "añade") == "")
        #expect(parser.descripcionParaFormulario(de: "   ") == "")
    }

    @Test("El gasto bien parseado conserva su «Gasto General» de siempre")
    func elParserNoCambia() async {
        let resultado = await parser.parse("20 euros", history: [])
        guard case .success(let tx) = resultado else {
            Issue.record("Se esperaba un gasto")
            return
        }
        #expect(tx.merchant == "Gasto General")
    }

    @Test("El coordinador publica el borrador limpio y no pasa a error")
    func coordinadorPublicaBorrador() {
        let coordinador = VoiceExpenseCoordinator()
        coordinador.marcarOrigenSiri()

        coordinador.proponerBorradorManual(desde: "Añade gasolina")

        #expect(coordinador.borradorManual == "Gasolina")
        #expect(coordinador.state == .idle)
        #expect(!coordinador.showError)
        // Lo guardará el formulario manual: la marca de Siri no se queda puesta.
        #expect(coordinador.origen == .voice)

        coordinador.descartarBorradorManual()
        #expect(coordinador.borradorManual == nil)
    }
}

// MARK: - Recargas del widget agrupadas

@Suite("Widget · recargas agrupadas")
@MainActor
struct WidgetReloadGroupingTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test("Sin peticiones no hay nada que recargar")
    func sinPeticiones() {
        let agrupador = AgrupadorDeRecargas()
        #expect(!agrupador.hayPendiente)
        #expect(agrupador.vencimiento == nil)
    }

    @Test("Una petición vence pasado el margen")
    func unaPeticion() {
        var agrupador = AgrupadorDeRecargas(margen: 1, tope: 3)
        agrupador.pedir(a: t0)
        #expect(agrupador.vencimiento == t0.addingTimeInterval(1))
    }

    @Test("Una ráfaga (2N escrituras) es una sola recarga, tras la última")
    func rafaga() {
        var agrupador = AgrupadorDeRecargas(margen: 1, tope: 3)
        // Dictado de tres gastos: prepend + refresh por cada uno.
        for i in 0..<6 { agrupador.pedir(a: t0.addingTimeInterval(Double(i) * 0.2)) }

        // Un único vencimiento para las seis, contado desde la última.
        #expect(agrupador.vencimiento == t0.addingTimeInterval(1.0 + 1))

        agrupador.recargada()
        #expect(!agrupador.hayPendiente)
        #expect(agrupador.vencimiento == nil)
    }

    @Test("Una ráfaga que no para no aplaza la recarga más allá del tope")
    func topeDeEspera() {
        var agrupador = AgrupadorDeRecargas(margen: 1, tope: 3)
        for i in 0..<10 { agrupador.pedir(a: t0.addingTimeInterval(Double(i) * 0.5)) }
        // Última petición en t0+4,5 → por margen tocaría en t0+5,5; manda el tope.
        #expect(agrupador.vencimiento == t0.addingTimeInterval(3))
    }

    @Test("Tras recargar, la siguiente petición abre otra ráfaga")
    func rafagaNueva() {
        var agrupador = AgrupadorDeRecargas(margen: 1, tope: 3)
        agrupador.pedir(a: t0)
        agrupador.recargada()

        let luego = t0.addingTimeInterval(60)
        agrupador.pedir(a: luego)
        #expect(agrupador.vencimiento == luego.addingTimeInterval(1))
    }
}

// MARK: - Categorías del usuario ya cargadas (enlace de Siri en frío)

@Suite("UserDataManager · espera de categorías del usuario", .serialized)
@MainActor
struct UserCategoriesReadySignalTests {

    private func cat(_ id: String, _ name: String) -> Clarity.Category {
        Clarity.Category(id: id, name: name, color: "#6366F1", subcategories: [],
                         order: 0, createdAt: nil, updatedAt: nil)
    }

    private func makeSUT() -> UserDataManager {
        let store = MockUserDataStore()
        store.storedCategories = [cat("cat-a", "Coche")]
        return UserDataManager(service: store, userIdProvider: { "test-uid" })
    }

    @Test("Con valores de fábrica en memoria, `hasLoaded` engaña y la señal no")
    func fabricaNoCuenta() async {
        let manager = makeSUT()
        manager.categories = [cat("def", "Alimentación")]  // lo que deja el `init` real

        #expect(manager.hasLoaded)
        #expect(!manager.categoriasDelUsuarioCargadas)
        // Nadie carga: se agota el tope (corto, para no alargar la suite) y sigue.
        let llegaron = await manager.esperarCategoriasDelUsuario(tope: .milliseconds(150))
        #expect(!llegaron)
    }

    @Test("Cargadas del almacén, la espera vuelve en el acto")
    func cargadasNoEspera() async {
        let manager = makeSUT()
        await manager.refreshCategories()

        #expect(manager.categoriasDelUsuarioCargadas)
        let inicio = ContinuousClock.now
        let llegaron = await manager.esperarCategoriasDelUsuario(tope: .seconds(5))
        #expect(llegaron)
        #expect(ContinuousClock.now - inicio < .seconds(1))
        #expect(manager.categories.map(\.name) == ["Coche"])
    }

    @Test("La espera despierta cuando la carga termina a mitad")
    func despiertaAlCargar() async {
        let manager = makeSUT()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            await manager.refreshCategories()
        }
        let llegaron = await manager.esperarCategoriasDelUsuario(tope: .seconds(5))
        #expect(llegaron)
    }

    @Test("Al cerrar sesión la señal se apaga")
    func cierreDeSesion() async {
        let manager = makeSUT()
        await manager.refreshCategories()
        manager.clearCache()
        #expect(!manager.categoriasDelUsuarioCargadas)
    }
}
