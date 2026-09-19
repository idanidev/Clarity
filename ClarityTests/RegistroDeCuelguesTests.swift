// RegistroDeCuelguesTests.swift
// El registro de cuelgues (`Clarity/Core/Diagnostics/`): el rastro de migas, la
// decisión de si el hilo principal está colgado, el informe en disco y el
// resumen que acaba en el pie del correo de soporte.
//
// Nada de esto toca la carpeta real de diagnósticos ni el vigilante de la app:
// la lógica es pura, y el almacén y el único vigilante que se arranca trabajan
// sobre carpetas temporales.

import Foundation
import Testing
@testable import Clarity

private let utc = TimeZone(identifier: "UTC")!

/// 19 de septiembre de 2026, 18:42:07 UTC, más los segundos que se pidan.
private func instante(_ segundos: TimeInterval = 0) -> Date {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = utc
    let base = calendario.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 18, minute: 42, second: 7))!
    return base.addingTimeInterval(segundos)
}

private func informe(
    segundos: Double = 41,
    recuperado: Bool = false,
    migas: [Miga] = [],
    fecha: Date = instante()
) -> InformeDeCuelgue {
    InformeDeCuelgue(
        fecha: fecha,
        segundosBloqueado: segundos,
        recuperado: recuperado,
        versionApp: "2.3.1",
        build: "43",
        versionIOS: "26.6.2",
        modelo: "iPhone14,5",
        migas: migas
    )
}

// MARK: - Arranque

@Suite("Diagnosticos")
@MainActor
struct DiagnosticosTests {

    @Test("bajo tests el vigilante no arranca: nada de esto escribe en la carpeta real")
    func noArrancaEnTests() {
        #expect(Diagnosticos.enTests)
    }
}

// MARK: - Migas

@Suite("BufferDeMigas")
@MainActor
struct BufferDeMigasTests {

    @Test("las migas salen en el orden en que se dejaron")
    func orden() {
        var buffer = BufferDeMigas(tope: 40)
        for texto in ["a", "b", "c"] { buffer.anade(texto, fecha: instante()) }
        #expect(buffer.enOrden.map(\.texto) == ["a", "b", "c"])
    }

    @Test("pasado el tope se caen las más viejas")
    func tope() {
        var buffer = BufferDeMigas(tope: 40)
        for i in 0..<45 { buffer.anade("m\(i)", fecha: instante(Double(i))) }

        let migas = buffer.enOrden
        #expect(migas.count == 40)
        #expect(migas.first?.texto == "m5")
        #expect(migas.last?.texto == "m44")
    }

    @Test("sigue en orden después de dar varias vueltas")
    func variasVueltas() {
        var buffer = BufferDeMigas(tope: 3)
        for i in 0..<8 { buffer.anade("m\(i)", fecha: instante(Double(i))) }
        #expect(buffer.enOrden.map(\.texto) == ["m5", "m6", "m7"])
    }

    @Test("la misma miga seguida no ocupa hueco: suma una vez y se queda con la última hora")
    func repetidas() {
        var buffer = BufferDeMigas(tope: 40)
        buffer.anade("teclado: willShow alto=336", fecha: instante(0))
        buffer.anade("teclado: willShow alto=336", fecha: instante(1))
        buffer.anade("teclado: willShow alto=336", fecha: instante(2))

        #expect(buffer.enOrden == [Miga(fecha: instante(2), texto: "teclado: willShow alto=336", veces: 3)])
    }

    @Test("con clave se agrupan textos distintos y manda el último: un bucle no llena el rastro")
    func agrupadasPorClave() {
        var buffer = BufferDeMigas(tope: 40)
        buffer.anade("pantalla: home", fecha: instante(0))
        for i in 0..<100 {
            buffer.anade("barra: margen=\(i % 2 == 0 ? 34 : 336)", fecha: instante(Double(i)), agrupando: "barra.margen")
        }

        let migas = buffer.enOrden
        #expect(migas.count == 2)
        #expect(migas.first?.texto == "pantalla: home")
        #expect(migas.last == Miga(fecha: instante(99), texto: "barra: margen=336", veces: 100))
    }

    @Test("otra miga en medio corta la racha")
    func rachaCortada() {
        var buffer = BufferDeMigas(tope: 40)
        buffer.anade("barra: alto=66", fecha: instante(0), agrupando: "barra.alto")
        buffer.anade("hoja añadir: aparece", fecha: instante(1))
        buffer.anade("barra: alto=66", fecha: instante(2), agrupando: "barra.alto")

        #expect(buffer.enOrden.map(\.veces) == [1, 1, 1])
    }

    @Test("agrupa sobre la última también con el búfer lleno y el índice recién dado la vuelta")
    func agrupaConElBufferLleno() {
        var buffer = BufferDeMigas(tope: 2)
        buffer.anade("a", fecha: instante(0))
        buffer.anade("b", fecha: instante(1))
        buffer.anade("b", fecha: instante(2))

        #expect(buffer.enOrden == [
            Miga(fecha: instante(0), texto: "a", veces: 1),
            Miga(fecha: instante(2), texto: "b", veces: 2),
        ])
    }

    @Test("un texto largo se recorta")
    func recorte() {
        var buffer = BufferDeMigas(tope: 40)
        buffer.anade(String(repeating: "x", count: 500), fecha: instante())
        #expect(buffer.enOrden.first?.texto.count == BufferDeMigas.largoMaximo)
    }

    @Test("el registro aguanta migas desde varios hilos a la vez")
    func variosHilos() {
        let registro = RegistroDeMigas(tope: 40)
        DispatchQueue.concurrentPerform(iterations: 8) { @Sendable hilo in
            for i in 0..<200 { registro.deja("hilo \(hilo) miga \(i)") }
        }
        #expect(registro.copia().count == 40)
    }
}

// MARK: - Detección

@Suite("DeteccionDeCuelgue")
@MainActor
struct DeteccionDeCuelgueTests {

    @Test("sin ping pendiente, responde")
    func sinPing() {
        #expect(DeteccionDeCuelgue.veredicto(ahora: 100, pingSinResponderDesde: nil) == .responde)
    }

    @Test("hasta el umbral es un tirón, no un cuelgue")
    func enElUmbral() {
        #expect(DeteccionDeCuelgue.veredicto(ahora: 102, pingSinResponderDesde: 100) == .responde)
        #expect(DeteccionDeCuelgue.veredicto(ahora: 103, pingSinResponderDesde: 100) == .responde)
    }

    @Test("pasado el umbral está colgado, con lo que lleva")
    func pasadoElUmbral() {
        #expect(DeteccionDeCuelgue.veredicto(ahora: 103.5, pingSinResponderDesde: 100) == .colgado(segundos: 3.5))
        #expect(DeteccionDeCuelgue.veredicto(ahora: 141, pingSinResponderDesde: 100) == .colgado(segundos: 41))
    }

    @Test("el umbral se puede cambiar")
    func umbralPropio() {
        #expect(DeteccionDeCuelgue.veredicto(ahora: 101.5, pingSinResponderDesde: 100, umbral: 1) == .colgado(segundos: 1.5))
    }
}

@Suite("SeguimientoDeCuelgue")
@MainActor
struct SeguimientoDeCuelgueTests {

    @Test("un solo ping en vuelo")
    func unSoloPing() {
        var seguimiento = SeguimientoDeCuelgue()
        #expect(seguimiento.ronda(ahora: 0) == .mandaPing)
        #expect(seguimiento.ronda(ahora: 1) == .nada)
        #expect(seguimiento.ronda(ahora: 2) == .nada)
    }

    @Test("si el principal contesta a tiempo no se escribe nada y se vuelve a preguntar")
    func contestaATiempo() {
        var seguimiento = SeguimientoDeCuelgue()
        _ = seguimiento.ronda(ahora: 0)
        #expect(seguimiento.respuesta(ahora: 0.5) == .nada)
        #expect(seguimiento.ronda(ahora: 1) == .mandaPing)
    }

    @Test("colgado: escribe al pasar el umbral, reescribe cada poco y anota la duración final")
    func cuelgueCompleto() {
        var seguimiento = SeguimientoDeCuelgue()
        #expect(seguimiento.ronda(ahora: 0) == .mandaPing)
        for t in 1...3 { #expect(seguimiento.ronda(ahora: Double(t)) == .nada) }

        #expect(seguimiento.ronda(ahora: 4) == .escribe(segundos: 4, recuperado: false))
        #expect(seguimiento.ronda(ahora: 5) == .nada)
        #expect(seguimiento.ronda(ahora: 6) == .escribe(segundos: 6, recuperado: false))

        #expect(seguimiento.respuesta(ahora: 7.5) == .escribe(segundos: 7.5, recuperado: true))
        // Episodio cerrado: vuelta a empezar.
        #expect(seguimiento.ronda(ahora: 8) == .mandaPing)
        #expect(seguimiento.respuesta(ahora: 8.5) == .nada)
    }

    @Test("el tiempo que el proceso estuvo suspendido no cuenta como cuelgue")
    func suspension() {
        var seguimiento = SeguimientoDeCuelgue()
        _ = seguimiento.ronda(ahora: 0)
        #expect(seguimiento.ronda(ahora: 1) == .nada)

        // Un minuto sin que corra ni el propio vigilante: proceso suspendido.
        #expect(seguimiento.ronda(ahora: 61) == .nada)
        #expect(seguimiento.ronda(ahora: 62) == .nada)
        // Si al volver sigue sin contestar, ahí sí: 2 s de antes + 2 de ahora.
        #expect(seguimiento.ronda(ahora: 63) == .escribe(segundos: 4, recuperado: false))
    }

    @Test("pasar a segundo plano con un cuelgue abierto lo cierra como recuperado")
    func pausaConCuelgue() {
        var seguimiento = SeguimientoDeCuelgue()
        _ = seguimiento.ronda(ahora: 0)
        for t in 1...4 { _ = seguimiento.ronda(ahora: Double(t)) }

        #expect(seguimiento.pausa(ahora: 5) == .escribe(segundos: 5, recuperado: true))
        // La respuesta al ping viejo llega después y ya no pinta nada.
        #expect(seguimiento.respuesta(ahora: 5.1) == .nada)
    }

    @Test("pausar olvida el ping: la vuelta del segundo plano no parece un cuelgue")
    func pausaSinCuelgue() {
        var seguimiento = SeguimientoDeCuelgue()
        _ = seguimiento.ronda(ahora: 0)
        #expect(seguimiento.pausa(ahora: 0.2) == .nada)
        // Dos horas después.
        #expect(seguimiento.ronda(ahora: 7200) == .mandaPing)
        #expect(seguimiento.ronda(ahora: 7201) == .nada)
    }
}

// MARK: - Vigilante (de verdad)

@Suite("VigilanteDeCuelgues")
@MainActor
struct VigilanteDeCuelguesTests {

    /// Ocupa el hilo principal —este test corre en él— sin soltarlo hasta que el
    /// vigilante, desde el suyo, deja un informe en disco. Síncrona a propósito:
    /// un `await` soltaría el hilo y el ping se contestaría.
    private func bloqueaElPrincipalHastaQueHayaInforme(en almacen: AlmacenDeDiagnosticos) -> InformeDeCuelgue? {
        let limite = Date().addingTimeInterval(5)
        while Date() < limite {
            if let informe = almacen.ultimoCuelgue() { return informe }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return nil
    }

    @Test("con el hilo principal bloqueado, el informe aparece en disco; al soltarlo, se cierra")
    func cuelgueDeVerdad() async throws {
        let almacen = AlmacenDeDiagnosticos(
            carpeta: FileManager.default.temporaryDirectory
                .appendingPathComponent("vigilante-tests-\(UUID().uuidString)", isDirectory: true)
        )
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        let registro = RegistroDeMigas()
        registro.deja("hoja añadir: aparece")

        // El mismo vigilante, con el reloj acelerado: 0,2 s de umbral en vez de 3.
        var ritmo = SeguimientoDeCuelgue()
        ritmo.intervalo = 0.05
        ritmo.umbral = 0.2
        ritmo.cadaCuantoReescribir = 0.1
        let vigilante = VigilanteDeCuelgues(almacen: almacen, registro: registro, seguimiento: ritmo)
        vigilante.reanuda()
        defer { vigilante.pausa() }

        let enPlenoCuelgue = try #require(bloqueaElPrincipalHastaQueHayaInforme(en: almacen))
        #expect(!enPlenoCuelgue.recuperado)
        #expect(enPlenoCuelgue.segundosBloqueado >= 0.2)
        #expect(enPlenoCuelgue.migas.map(\.texto) == ["hoja añadir: aparece"])
        #expect(enPlenoCuelgue.modelo == DatosDelAparato.modelo)

        // Se suelta el hilo: el ping se contesta y queda anotada la duración final.
        var cerrado: InformeDeCuelgue?
        for _ in 0..<100 where cerrado == nil {
            try await Task.sleep(for: .milliseconds(50))
            if let informe = almacen.ultimoCuelgue(), informe.recuperado { cerrado = informe }
        }
        let alFinal = try #require(cerrado)
        #expect(alFinal.segundosBloqueado >= enPlenoCuelgue.segundosBloqueado)
        #expect(alFinal.fecha == enPlenoCuelgue.fecha)
    }
}

// MARK: - Informe y almacén

@Suite("InformeDeCuelgue")
@MainActor
struct InformeDeCuelgueTests {

    private func carpetaTemporal() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("diagnosticos-tests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("sobrevive a codificarse y decodificarse")
    func idaYVuelta() throws {
        let original = informe(migas: [
            Miga(fecha: instante(-3), texto: "barra: pulsa +"),
            Miga(fecha: instante(-2), texto: "teclado: willShow alto=336", veces: 3),
        ])
        let copia = try AlmacenDeDiagnosticos.decodifica(AlmacenDeDiagnosticos.codifica(original))
        #expect(copia == original)
    }

    @Test("las fechas conservan los milisegundos")
    func milisegundos() throws {
        let original = informe(migas: [Miga(fecha: instante(0.25), texto: "pantalla: anadir_gasto")])
        let datos = try AlmacenDeDiagnosticos.codifica(original)

        #expect(String(decoding: datos, as: UTF8.self).contains("2026-09-19T18:42:07.250Z"))
        let copia = try AlmacenDeDiagnosticos.decodifica(datos)
        let fecha = try #require(copia.migas.first?.fecha)
        #expect(abs(fecha.timeIntervalSince(instante(0.25))) < 0.001)
    }

    @Test("el JSON lleva lo que hay que saber del aparato y del cuelgue")
    func claves() throws {
        let datos = try AlmacenDeDiagnosticos.codifica(informe(migas: [Miga(fecha: instante(), texto: "app: arranca")]))
        let json = try #require(JSONSerialization.jsonObject(with: datos) as? [String: Any])

        #expect(Set(json.keys) == [
            "fecha", "segundosBloqueado", "recuperado", "versionApp", "build", "versionIOS", "modelo", "migas",
        ])
        #expect(json["segundosBloqueado"] as? Double == 41)
        #expect(json["modelo"] as? String == "iPhone14,5")
    }

    @Test("el almacén guarda, relee y pisa el informe")
    func almacen() {
        let almacen = AlmacenDeDiagnosticos(carpeta: carpetaTemporal())
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        #expect(almacen.ultimoCuelgue() == nil)
        almacen.guarda(informe(segundos: 4))
        almacen.guarda(informe(segundos: 6))
        #expect(almacen.ultimoCuelgue() == informe(segundos: 6))
        #expect(almacen.urlUltimoCuelgue.lastPathComponent == "ultimo_cuelgue.json")
    }

    @Test("un archivo estropeado no es un informe")
    func archivoEstropeado() throws {
        let almacen = AlmacenDeDiagnosticos(carpeta: carpetaTemporal())
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        try FileManager.default.createDirectory(at: almacen.carpeta, withIntermediateDirectories: true)
        try Data("{ medio informe".utf8).write(to: almacen.urlUltimoCuelgue)
        #expect(almacen.ultimoCuelgue() == nil)
    }

    @Test("un tirón del que la app salió no pisa un cuelgue más largo del que no salió")
    func queConservar() {
        let mortal = informe(segundos: 41, recuperado: false)
        let tiron = informe(segundos: 3.4, recuperado: true)
        let largo = informe(segundos: 60, recuperado: true)
        let viejoRecuperado = informe(segundos: 50, recuperado: true)

        #expect(InformeDeCuelgue.queConservar(anterior: mortal, recuperado: tiron) == mortal)
        #expect(InformeDeCuelgue.queConservar(anterior: mortal, recuperado: largo) == largo)
        #expect(InformeDeCuelgue.queConservar(anterior: viejoRecuperado, recuperado: tiron) == tiron)
        #expect(InformeDeCuelgue.queConservar(anterior: nil, recuperado: tiron) == tiron)
    }

    @Test("de MetricKit sobran los más viejos, y solo los suyos")
    func sobrantesDeMetricKit() {
        let nombres = (1...7).map { "metrickit_2026091\($0)-080000.json" }
            + ["ultimo_cuelgue.json", "metrickit_notas.txt", ".DS_Store"]

        let sobrantes = AlmacenDeDiagnosticos.sobrantesDeMetricKit(entre: nombres.shuffled())
        #expect(Set(sobrantes) == ["metrickit_20260911-080000.json", "metrickit_20260912-080000.json"])
        #expect(AlmacenDeDiagnosticos.sobrantesDeMetricKit(entre: Array(nombres.prefix(5))).isEmpty)
    }

    @Test("el nombre de MetricKit ordena por fecha")
    func nombreDeMetricKit() {
        #expect(AlmacenDeDiagnosticos.nombreMetricKit(fecha: instante()) == "metrickit_20260919-184207.json")
        #expect(AlmacenDeDiagnosticos.nombreMetricKit(fecha: instante(), indice: 2) == "metrickit_20260919-184207_2.json")
    }

    @Test("en disco quedan los cinco payloads de MetricKit más recientes")
    func metricKitEnDisco() throws {
        let almacen = AlmacenDeDiagnosticos(carpeta: carpetaTemporal())
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        almacen.guarda(informe())
        for dia in 0..<7 {
            almacen.guardaMetricKit(Data("{}".utf8), fecha: instante(Double(dia) * 86_400))
        }

        let nombres = try FileManager.default.contentsOfDirectory(atPath: almacen.carpeta.path)
        let deMetricKit = nombres.filter { $0.hasPrefix("metrickit_") }.sorted()
        #expect(deMetricKit.count == 5)
        #expect(deMetricKit.first == "metrickit_20260921-184207.json")
        #expect(deMetricKit.last == "metrickit_20260925-184207.json")
        // Y el informe de cuelgue sigue donde estaba.
        #expect(nombres.contains("ultimo_cuelgue.json"))
    }
}

// MARK: - Resumen para el correo

@Suite("ResumenDeCuelgue")
@MainActor
struct ResumenDeCuelgueTests {

    @Test("cabecera legible y una línea por miga, con su hora")
    func formato() {
        let texto = ResumenDeCuelgue.paraElPie(
            informe(migas: [
                Miga(fecha: instante(-2.5), texto: "barra: pulsa +"),
                Miga(fecha: instante(-2), texto: "hoja añadir: aparece"),
                Miga(fecha: instante(-1.75), texto: "teclado: willShow alto=336", veces: 3),
            ]),
            zona: utc
        )

        #expect(texto == """


        Último cuelgue: 2026-09-19 18:42:07 +0000 · 41.0 s · la app no se recuperó
        Clarity 2.3.1 (43) · iPhone14,5 · iOS 26.6.2
        18:42:04.500 barra: pulsa +
        18:42:05.000 hoja añadir: aparece
        18:42:05.250 teclado: willShow alto=336 ×3
        """)
    }

    @Test("dice si la app salió sola del cuelgue")
    func recuperado() {
        let texto = ResumenDeCuelgue.paraElPie(informe(segundos: 3.44, recuperado: true), zona: utc)
        #expect(texto.contains("· 3.4 s · se recuperó"))
    }

    @Test("solo las doce últimas migas, en orden")
    func soloLasUltimas() {
        let migas = (0..<40).map { Miga(fecha: instante(Double($0)), texto: "paso \($0)!") }
        let lineas = ResumenDeCuelgue.paraElPie(informe(migas: migas), zona: utc)
            .split(separator: "\n")
            .filter { $0.contains("paso ") }

        #expect(lineas.count == 12)
        #expect(lineas.first?.hasSuffix("paso 28!") == true)
        #expect(lineas.last?.hasSuffix("paso 39!") == true)
    }

    @Test("nunca pasa del tope: si no cabe, se caen las migas más viejas")
    func topeDeLargo() {
        let largo = String(repeating: "x", count: 200)
        let migas = (0..<40).map { Miga(fecha: instante(Double($0)), texto: "\($0)-\(largo)", veces: 99) }
        let texto = ResumenDeCuelgue.paraElPie(informe(migas: migas), zona: utc)

        #expect(texto.count <= ResumenDeCuelgue.topeDeCaracteres)
        #expect(texto.hasPrefix("\n\nÚltimo cuelgue: "))
        // La más reciente es la última en caerse.
        #expect(texto.contains(" 39-xxx"))
        #expect(!texto.contains(" 28-xxx"))
    }

    @Test("con migas de tamaño real, las doce caben enteras")
    func cabenLasDoce() {
        let migas = (0..<12).map {
            Miga(fecha: instante(Double($0)), texto: String(repeating: "m", count: BufferDeMigas.largoMaximo - 2) + String(format: "%02d", $0))
        }
        let texto = ResumenDeCuelgue.paraElPie(informe(migas: migas), zona: utc)

        #expect(texto.count <= ResumenDeCuelgue.topeDeCaracteres)
        #expect(texto.split(separator: "\n").count == 2 + 12)
    }

    @Test("hasta un tope ridículo se respeta")
    func topeMinimo() {
        let texto = ResumenDeCuelgue.paraElPie(informe(migas: [Miga(fecha: instante(), texto: "app: arranca")]), zona: utc, tope: 20)
        #expect(texto.count == 20)
    }
}

// MARK: - Migas de la sesión anterior

private func sesion(_ textos: [String], hasta volcado: Date = instante(), build: String = "43") -> SesionDeMigas {
    SesionDeMigas(
        volcado: volcado,
        versionApp: "2.3.1",
        build: build,
        migas: textos.enumerated().map { Miga(fecha: instante(Double($0.offset) - 10), texto: $0.element) }
    )
}

@Suite("VolcadoDeMigas")
@MainActor
struct VolcadoDeMigasTests {

    private func almacenTemporal() -> AlmacenDeDiagnosticos {
        AlmacenDeDiagnosticos(
            carpeta: FileManager.default.temporaryDirectory
                .appendingPathComponent("volcado-tests-\(UUID().uuidString)", isDirectory: true)
        )
    }

    private func existe(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    @Test("lo volcado se relee igual, con sus horas y sus repeticiones, una vez es la sesión anterior")
    func volcadoYRelectura() {
        let almacen = almacenTemporal()
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        var original = sesion(["app: arranca", "barra: pulsa +", "hoja añadir: aparece"])
        original.migas[2].veces = 3

        almacen.guardaSesion(original)
        #expect(almacen.urlMigasDeSesion.lastPathComponent == "migas_sesion.json")
        #expect(existe(almacen.urlMigasDeSesion))
        // Mientras sea la sesión en curso, no cuenta como anterior.
        #expect(almacen.sesionAnterior() == nil)

        almacen.rotaSesion()
        #expect(almacen.sesionAnterior() == original)
    }

    @Test("al arrancar, la sesión volcada pasa a ser la anterior y sustituye a la que hubiera")
    func rotacion() {
        let almacen = almacenTemporal()
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        almacen.guardaSesion(sesion(["pantalla: home"], build: "42"))
        almacen.rotaSesion()
        almacen.guardaSesion(sesion(["pantalla: anadir_gasto"], build: "43"))
        almacen.rotaSesion()

        #expect(almacen.urlMigasDeSesionAnterior.lastPathComponent == "migas_sesion_anterior.json")
        #expect(almacen.sesionAnterior() == sesion(["pantalla: anadir_gasto"], build: "43"))
        #expect(!existe(almacen.urlMigasDeSesion))
    }

    @Test("la sesión en curso no pisa la anterior por mucho que vuelque")
    func laActualNoPisaLaAnterior() {
        let almacen = almacenTemporal()
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        almacen.guardaSesion(sesion(["hoja añadir: aparece"]))
        almacen.rotaSesion()
        almacen.guardaSesion(sesion(["pantalla: home"]))
        almacen.guardaSesion(sesion(["pantalla: home", "app: a segundo plano"]))

        #expect(almacen.sesionAnterior() == sesion(["hoja añadir: aparece"]))
    }

    @Test("si la sesión pasada no volcó nada, rotar no toca la anterior ni se inventa una")
    func rotarSinNadaQueRotar() {
        let almacen = almacenTemporal()
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        almacen.rotaSesion()
        #expect(almacen.sesionAnterior() == nil)

        almacen.guardaSesion(sesion(["pantalla: home"]))
        almacen.rotaSesion()
        almacen.rotaSesion()
        #expect(almacen.sesionAnterior() == sesion(["pantalla: home"]))
    }

    @Test("un archivo estropeado no es una sesión")
    func archivoEstropeado() throws {
        let almacen = almacenTemporal()
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        try FileManager.default.createDirectory(at: almacen.carpeta, withIntermediateDirectories: true)
        try Data("[ media sesión".utf8).write(to: almacen.urlMigasDeSesionAnterior)
        #expect(almacen.sesionAnterior() == nil)
    }

    @Test("de punta a punta: migas en memoria, volcado, arranque siguiente, sesión anterior")
    func dePuntaAPunta() throws {
        let almacen = almacenTemporal()
        defer { try? FileManager.default.removeItem(at: almacen.carpeta) }

        let registro = RegistroDeMigas()
        registro.deja("barra: pulsa +", fecha: instante(-2))
        registro.deja("hoja añadir: aparece", fecha: instante(-1))

        let sesionQueSeCierra = VolcadoDeMigas(almacen: almacen, registro: registro)
        sesionQueSeCierra.vuelca()
        sesionQueSeCierra.esperaAlDisco()

        // Arranque siguiente: otro registro, vacío, y lo primero es rotar.
        let sesionNueva = VolcadoDeMigas(almacen: almacen, registro: RegistroDeMigas())
        sesionNueva.rota()
        sesionNueva.vuelca()
        sesionNueva.esperaAlDisco()

        let anterior = try #require(almacen.sesionAnterior())
        #expect(anterior.migas.map(\.texto) == ["barra: pulsa +", "hoja añadir: aparece"])
        #expect(anterior.versionApp == DatosDelAparato.versionApp)
        #expect(anterior.build == DatosDelAparato.build)
    }
}

@Suite("Pie de soporte: cuelgue, sesión anterior o nada")
@MainActor
struct EleccionDelPieTests {

    private let cuelgue = informe(migas: [Miga(fecha: instante(-1), texto: "hoja añadir: aparece")])
    private let anterior = sesion(["barra: pulsa +", "hoja añadir: aparece", "app: deja de estar activa"])

    /// Una semana antes de que empezara la sesión anterior.
    private let cuelgueViejo = informe(
        migas: [Miga(fecha: instante(-7 * 86_400 - 1), texto: "pantalla: presupuestos")],
        fecha: instante(-7 * 86_400)
    )

    @Test("un cuelgue de la sesión anterior o posterior va entero, y la sesión anterior no entra")
    func ganaElCuelgueReciente() {
        let soloElCuelgue = ResumenDeCuelgue.paraElPie(cuelgue, zona: utc)
        let texto = ResumenDeCuelgue.paraElPie(cuelgue: cuelgue, sesionAnterior: anterior, zona: utc)
        #expect(texto == soloElCuelgue)
        #expect(!texto.contains("Sesión anterior"))

        // Justo en la primera miga de la sesión anterior ya cuenta como suyo.
        let enElPrincipio = informe(fecha: instante(-10))
        #expect(ResumenDeCuelgue.paraElPie(cuelgue: enElPrincipio, sesionAnterior: anterior, zona: utc)
            == ResumenDeCuelgue.paraElPie(enElPrincipio, zona: utc))
    }

    @Test("sin sesión anterior con la que comparar, el cuelgue va entero por viejo que sea")
    func cuelgueSinSesionAnterior() {
        let soloElCuelgue = ResumenDeCuelgue.paraElPie(cuelgueViejo, zona: utc)
        #expect(ResumenDeCuelgue.paraElPie(cuelgue: cuelgueViejo, sesionAnterior: nil, zona: utc) == soloElCuelgue)
        #expect(ResumenDeCuelgue.paraElPie(cuelgue: cuelgueViejo, sesionAnterior: sesion([]), zona: utc) == soloElCuelgue)
    }

    @Test("un cuelgue más viejo que la sesión anterior no la tapa: se queda en una línea al final")
    func cuelgueViejoEnUnaLinea() {
        let texto = ResumenDeCuelgue.paraElPie(cuelgue: cuelgueViejo, sesionAnterior: anterior, zona: utc)
        #expect(texto == """


        Sesión anterior (hasta 2026-09-19 18:42:07 +0000) · Clarity 2.3.1 (43)
        18:41:57.000 barra: pulsa +
        18:41:58.000 hoja añadir: aparece
        18:41:59.000 app: deja de estar activa
        Cuelgue previo: 2026-09-12 18:42:07 +0000, 41.0 s
        """)
        // Las migas del cuelgue viejo no viajan: solo la línea.
        #expect(!texto.contains("pantalla: presupuestos"))
    }

    @Test("con cuelgue viejo tampoco se pasa del tope: se recortan migas, no la línea del cuelgue")
    func topeConCuelgueViejo() {
        let largo = String(repeating: "x", count: 200)
        let texto = ResumenDeCuelgue.paraElPie(
            cuelgue: cuelgueViejo,
            sesionAnterior: sesion((0..<40).map { "\($0)-\(largo)" }),
            zona: utc
        )

        #expect(texto.count <= ResumenDeCuelgue.topeDeCaracteres)
        #expect(texto.hasPrefix("\n\nSesión anterior (hasta "))
        #expect(texto.hasSuffix("\nCuelgue previo: 2026-09-12 18:42:07 +0000, 41.0 s"))
        #expect(texto.contains(" 39-xxx"))
        #expect(!texto.contains(" 28-xxx"))

        // La línea ocupa sitio: caben menos migas que sin ella, no las mismas a costa del tope.
        let sinCuelgue = ResumenDeCuelgue.paraElPie(cuelgue: nil, sesionAnterior: sesion((0..<40).map { "\($0)-\(largo)" }), zona: utc)
        #expect(texto.split(separator: "\n").count <= sinCuelgue.split(separator: "\n").count + 1)
    }

    @Test("con migas de tamaño real caben las doce y, detrás, la línea del cuelgue viejo")
    func cabenLasDoceYLaLinea() {
        let textos = (0..<12).map { String(repeating: "m", count: BufferDeMigas.largoMaximo - 2) + String(format: "%02d", $0) }
        let texto = ResumenDeCuelgue.paraElPie(cuelgue: cuelgueViejo, sesionAnterior: sesion(textos), zona: utc)

        #expect(texto.count <= ResumenDeCuelgue.topeDeCaracteres)
        #expect(texto.split(separator: "\n").count == 1 + 12 + 1)
        #expect(texto.hasSuffix(", 41.0 s"))
    }

    @Test("sin cuelgue, las migas de la sesión anterior")
    func sesionAnterior() {
        let texto = ResumenDeCuelgue.paraElPie(cuelgue: nil, sesionAnterior: anterior, zona: utc)
        #expect(texto == """


        Sesión anterior (hasta 2026-09-19 18:42:07 +0000) · Clarity 2.3.1 (43)
        18:41:57.000 barra: pulsa +
        18:41:58.000 hoja añadir: aparece
        18:41:59.000 app: deja de estar activa
        """)
    }

    @Test("sin cuelgue ni sesión anterior, el pie se queda como estaba")
    func nada() {
        #expect(ResumenDeCuelgue.paraElPie(cuelgue: nil, sesionAnterior: nil, zona: utc).isEmpty)
        // Una sesión que no dejó migas no merece ni la cabecera.
        #expect(ResumenDeCuelgue.paraElPie(cuelgue: nil, sesionAnterior: sesion([]), zona: utc).isEmpty)
    }

    @Test("de la sesión anterior, solo las doce últimas migas, en orden")
    func soloLasUltimas() {
        let lineas = ResumenDeCuelgue.paraElPie(cuelgue: nil, sesionAnterior: sesion((0..<40).map { "paso \($0)!" }), zona: utc)
            .split(separator: "\n")
            .filter { $0.contains("paso ") }

        #expect(lineas.count == 12)
        #expect(lineas.first?.hasSuffix("paso 28!") == true)
        #expect(lineas.last?.hasSuffix("paso 39!") == true)
    }

    @Test("el bloque de la sesión anterior tampoco pasa del tope: se caen las migas más viejas")
    func topeDeLargo() {
        let largo = String(repeating: "x", count: 200)
        let texto = ResumenDeCuelgue.paraElPie(cuelgue: nil, sesionAnterior: sesion((0..<40).map { "\($0)-\(largo)" }), zona: utc)

        #expect(texto.count <= ResumenDeCuelgue.topeDeCaracteres)
        #expect(texto.hasPrefix("\n\nSesión anterior (hasta "))
        #expect(texto.contains(" 39-xxx"))
        #expect(!texto.contains(" 28-xxx"))
    }

    @Test("con migas de tamaño real, las doce de la sesión anterior caben enteras")
    func cabenLasDoce() {
        let textos = (0..<12).map { String(repeating: "m", count: BufferDeMigas.largoMaximo - 2) + String(format: "%02d", $0) }
        let texto = ResumenDeCuelgue.paraElPie(cuelgue: nil, sesionAnterior: sesion(textos), zona: utc)

        #expect(texto.count <= ResumenDeCuelgue.topeDeCaracteres)
        #expect(texto.split(separator: "\n").count == 1 + 12)
    }
}
