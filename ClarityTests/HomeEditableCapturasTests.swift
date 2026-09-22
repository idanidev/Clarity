// HomeEditableCapturasTests.swift
// Capturas de la Home editable (2.4.0) pintadas con `ImageRenderer` y datos
// inventados, para ver lo que sale sin lanzar la app: el simulador tiene la
// sesión real del usuario.
//
// Deja los PNG en `CLARITY_CAPTURAS` si está (con xcodebuild,
// `TEST_RUNNER_CLARITY_CAPTURAS=<carpeta>`), y si no en el temporal de la app.
// No comprueba píxeles y no falla si no puede escribir: es para mirarlas.

import Testing
import SwiftUI
import UIKit
@testable import Clarity

@Suite("Capturas de la Home editable", .serialized)
@MainActor
struct HomeEditableCapturasTests {

    private typealias D = HomeDisposicion
    private let cal = Calendar.current
    private var hoy: Date { cal.date(from: DateComponents(year: 2026, month: 9, day: 18))! }

    // MARK: - Datos inventados

    private func gasto(_ importe: Double, _ cat: String, dia: Int, mes: Int = 9, _ nombre: String,
                       deudores: [Debtor]? = nil) -> Expense {
        Expense(id: UUID().uuidString, amount: importe, name: nombre, category: cat,
                date: String(format: "2026-%02d-%02d", mes, dia), isShared: deudores != nil, debtors: deudores)
    }

    private var gastos: [Expense] {
        [
            gasto(64.2, "Alimentación", dia: 2, "Supermercado"), gasto(18.5, "Restaurantes", dia: 3, "Cena"),
            gasto(42, "Restaurantes", dia: 6, "Comida", deudores: [Debtor(name: "Ana", amount: 21)]),
            gasto(35, "Transporte", dia: 8, "Gasolina"), gasto(71.3, "Alimentación", dia: 9, "Supermercado"),
            gasto(3.2, "Ocio", dia: 10, "Café"), gasto(2.8, "Ocio", dia: 11, "Café"), gasto(3.4, "Ocio", dia: 12, "Café"),
            gasto(4.1, "Ocio", dia: 13, "Café"), gasto(2.9, "Ocio", dia: 14, "Café"), gasto(58, "Restaurantes", dia: 15, "Cumpleaños"),
            gasto(12.99, "Suscripciones", dia: 16, "Música"), gasto(27.6, "Alimentación", dia: 17, "Fruta"),
        ]
    }

    private var resumenReal: HomeResumen {
        let metas = [
            Goal(name: "Restaurantes", type: .spendingLimit, targetAmount: 150, linkedCategoryId: "Restaurantes"),
            Goal(name: "Viaje", type: .savingsTarget, targetAmount: 1200, currentAmount: 430),
        ]
        let reglas = [RecurringExpense(id: "gym", amount: 35, name: "Gimnasio", category: "Deporte", subcategory: nil,
                                       paymentMethod: "Tarjeta", frequency: .monthly, dayOfMonth: 25, billingMonth: 0,
                                       active: true, icon: nil, startDate: nil, endDate: nil, lastCreated: nil,
                                       createdAt: nil, updatedAt: nil)]
        let anterior = [gasto(120, "Alimentación", dia: 4, mes: 8, "Supermercado"), gasto(95, "Restaurantes", dia: 9, mes: 8, "Cena"),
                        gasto(60, "Ocio", dia: 12, mes: 8, "Cine")]
        return HomeResumen.build(gastos: gastos, gastosMesAnterior: anterior, metas: metas, recurrentes: reglas,
                                 presupuesto: 1900, primerGasto: cal.date(byAdding: .day, value: -200, to: hoy),
                                 hoy: hoy, calendar: cal)
    }

    /// El real con los ejemplos de la galería para lo que no sale solo, menos
    /// lo que se quiere ver sin datos.
    private func resumenCompleto(sinDatos: Set<String>) -> HomeResumen {
        let r = resumenReal
        var disponibles = r.disponibles
        var relevancias = r.relevancias
        for ficha in D.catalogo where disponibles[ficha.id] == nil {
            disponibles[ficha.id] = EjemploDeTarjeta.contenido(ficha.id)
            relevancias[ficha.id] = 0.2
        }
        for clase in sinDatos {
            disponibles[clase] = nil
            relevancias[clase] = nil
        }
        return HomeResumen(total: r.total, numeroGastos: r.numeroGastos, presupuesto: r.presupuesto, ritmo: r.ritmo,
                           comparativa: r.comparativa, diasApuntando: r.diasApuntando, slots: r.slots,
                           diaMasCaro: r.diaMasCaro, disponibles: disponibles, relevancias: relevancias,
                           totalAnalisis: r.totalAnalisis, numeroAnalisis: r.numeroAnalisis,
                           mediaDiariaAnalisis: r.mediaDiariaAnalisis, comparativaAnalisis: r.comparativaAnalisis)
    }

    private var ultimos: [Expense] { Array(gastos.suffix(3).reversed()) }

    /// Pequeñas y anchas mezcladas, una pila de cada, y «Racha» sin datos
    /// suelta antes de una ancha.
    private var mezclada: D {
        D(elementos: [
            D.Elemento(id: "hucha", tipo: .clase("hucha"), tamano: .pequena),
            D.Elemento(id: "pila-p", tipo: .pila, tamano: .pequena),
            D.Elemento(id: "limites", tipo: .clase("limites"), tamano: .ancha),
            D.Elemento(id: "teDeben", tipo: .clase("teDeben"), tamano: .pequena),
            D.Elemento(id: "fuera", tipo: .clase("fueraDeNormal"), tamano: .pequena),
            D.Elemento(id: "ultimos", tipo: .ultimos, tamano: .ancha),
            D.Elemento(id: "racha", tipo: .clase("racha"), tamano: .pequena),
            D.Elemento(id: "pila-a", tipo: .pila, tamano: .ancha),
            D.Elemento(id: "vacia", tipo: .pila, tamano: .pequena),
        ], ocultas: ["cargos"])
    }

    private let acciones = AccionesDeTarjeta(abrir: { _ in }, editarGasto: { _, _ in }, editarHome: {},
                                             quitar: { _ in }, cambiarTamano: { _, _ in }, noEnsenarEnPila: { _ in })
    private let accionesEdicion = AccionesDeEdicion(quitar: { _ in }, cambiarTamano: { _, _ in }, mover: { _, _ in }, ordenar: { _ in })

    // MARK: - Las capturas

    @Test("Pinta la Home normal, en edición y la galería")
    func capturas() throws {
        let carpeta = Self.carpeta()

        // 1. Quien nunca edita: la disposición por defecto con los datos reales.
        let real = resumenReal
        guardar(normal(real, .porDefecto), "01-normal-por-defecto", en: carpeta)

        // 2. Mezclada, fuera de edición: sin «Racha» (sin datos) ni la pila vacía.
        // Con pocas cosas con datos: la pila ancha enseña «Tus sitios», la pequeña
        // «Día más caro» y la última pequeña no tiene nada.
        let completo = resumenCompleto(sinDatos: ["racha", "diaSemana", "ranking", "hormiga", "semana", "ahorro", "subeFuerte",
                                                  "reparto", "comparativa", "semanaASemana", "limiteSugerido"])
        guardar(normal(completo, mezclada), "02-normal-mezclada", en: carpeta)

        // 3. La misma en edición: todas, la sin datos atenuada, con «−», asas y marca de pila.
        guardar(edicion(completo, mezclada), "03-edicion", en: carpeta)

        // 4. En edición con una tarjeta levantada y llevada con el dedo.
        guardar(edicion(completo, mezclada, arrastrando: "teDeben"), "04-edicion-arrastrando", en: carpeta)

        // 5. La galería: con datos reales donde los hay, ejemplos donde no, y
        //    la sección de lo que se sacó de la pila.
        var conOcultas = mezclada
        conOcultas.ocultas = ["cargos", "diaCaro"]
        guardar(galeria(real, conOcultas, parte: 0), "05-galeria-1", en: carpeta)
        guardar(galeria(real, conOcultas, parte: 1), "05-galeria-2", en: carpeta)

        // 6 y 7. Cada clase en los dos tamaños, admita uno o dos: para decidir
        //        (y comprobar) qué se pinta bien en cada uno.
        let mitad = D.catalogo.count / 2
        guardar(catalogo(Array(D.catalogo.prefix(mitad))), "06-catalogo-1", en: carpeta)
        guardar(catalogo(Array(D.catalogo.dropFirst(mitad))), "07-catalogo-2", en: carpeta)
    }

    // MARK: - Pantallas

    private func normal(_ r: HomeResumen, _ d: D) -> some View {
        let tarjetas = d.tarjetas(relevancias: r.relevancias, hayUltimos: true)
        let filas = D.filas(tarjetas.filter(\.conDatos), tamano: \.tamano)
        return Anfitrion { zoom in
            VStack(spacing: 12) {
                HeroCard(resumen: r, mesAnterior: "agosto", filtrado: nil, animarCifra: false)
                ForEach(filas, id: \.first?.id) { fila in
                    FilaDeTarjetas(fila: fila, contenidos: r.disponibles, ultimos: ultimos, zoom: zoom, acciones: acciones)
                }
            }
        }
    }

    private func edicion(_ r: HomeResumen, _ d: D, arrastrando: String? = nil) -> some View {
        var tarjetas = d.tarjetas(relevancias: r.relevancias, hayUltimos: true)
        let estado = HomeEdicion()
        if let arrastrando, let i = tarjetas.firstIndex(where: { $0.id == arrastrando }) {
            // A mano lo que harían el gesto y las medidas: levantada sobre su
            // sitio (segunda fila, izquierda), llevada hacia la derecha y
            // arriba, y ya colocada delante de la de al lado.
            estado.marcos[arrastrando] = CGRect(x: 0, y: 470, width: 178, height: 128)
            estado.empezarArrastre(arrastrando, tarjetas: tarjetas)
            estado.seguir(traslacion: CGSize(width: 120, height: -60))
            tarjetas.swapAt(i, i + 1)
            estado.orden = tarjetas
        }
        return Anfitrion { zoom in
            RejillaEditable(resumen: r, mesAnterior: "agosto", tarjetas: tarjetas, ultimos: ultimos,
                            edicion: estado, zoom: zoom, acciones: accionesEdicion)
        }
    }

    /// En dos mitades, desplazada con un recorte: entera es tan alta que el PNG no sale.
    private func galeria(_ r: HomeResumen, _ d: D, parte: Int) -> some View {
        let alto: CGFloat = 2_600
        return ContenidoGaleria(disposicion: d, contenidos: r.disponibles, relevancias: r.relevancias, ultimos: ultimos,
                                onAnadir: { _, _ in }, onDevolver: { _ in }, onRestablecer: {})
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: alto, alignment: .top)
            .offset(y: -alto * CGFloat(parte))
            .frame(height: alto, alignment: .top)
            .clipped()
    }

    private func catalogo(_ fichas: [D.Ficha]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(fichas) { ficha in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(ficha.nombre) · admite \(ficha.tamanos.map(\.nombre).joined(separator: " y "))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                    if let contenido = EjemploDeTarjeta.contenido(ficha.id) {
                        RejillaHome {
                            SlotCard(contenido: contenido, compacta: true)
                                .layoutValue(key: TamanoEnRejilla.self, value: .pequena)
                            SlotCard(contenido: contenido, compacta: false)
                                .layoutValue(key: TamanoEnRejilla.self, value: .ancha)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pintar y guardar

    private static func carpeta() -> URL {
        if let ruta = ProcessInfo.processInfo.environment["CLARITY_CAPTURAS"], !ruta.isEmpty {
            return URL(fileURLWithPath: ruta, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("capturas-home", isDirectory: true)
    }

    private func guardar<V: View>(_ vista: V, _ nombre: String, en carpeta: URL, ancho: CGFloat = 402) {
        let lienzo = vista
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 24)
            .frame(width: ancho)
            .background(HomeFondo(intensidad: .home))
            // El vidrio de antes de iOS 26: el de iOS 26 no sale en `ImageRenderer`
            // y el texto encima se queda transparente.
            .environment(\.vidrioSinLiquidGlass, true)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: lienzo)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: ancho, height: nil)
        guard let imagen = renderer.uiImage, let datos = imagen.pngData() else {
            print("📸 [capturas] no se pudo pintar \(nombre) (\(renderer.uiImage.map { "\($0.size)" } ?? "sin imagen"))")
            return
        }
        do {
            try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            let destino = carpeta.appendingPathComponent("\(nombre).png")
            try datos.write(to: destino)
            print("📸 [capturas] \(destino.path)")
        } catch {
            // En otro Mac o sin permiso: se avisa y se sigue, no es un fallo.
            print("📸 [capturas] no se pudo escribir \(nombre): \(error.localizedDescription)")
        }
    }
}

/// Un `@Namespace` para lo que pide uno (el zoom de las tarjetas).
private struct Anfitrion<Contenido: View>: View {
    @Namespace private var zoom
    let contenido: (Namespace.ID) -> Contenido

    var body: some View { contenido(zoom) }
}
