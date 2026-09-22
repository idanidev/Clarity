// HomeDisposicionTests.swift
// La Home editable (2.4.0): qué enseña cada tarjeta y cada pila, cómo se
// reparten en filas, las ediciones, la migración desde `HomePreferencias` y el
// formato que se guarda en el iPhone y en la cuenta.

import Testing
import Foundation
import FirebaseFirestore
@testable import Clarity

@Suite("Disposición de la Home", .serialized)
@MainActor
struct HomeDisposicionTests {

    private typealias D = HomeDisposicion
    private let cal = Calendar.current
    /// 10 de abril de 2026, viernes: el mismo «hoy» que `HomeResumenTests`.
    private var hoy: Date { cal.date(from: DateComponents(year: 2026, month: 4, day: 10))! }

    private func gasto(_ amount: Double, _ cat: String, dia: Int, mes: Int = 4, name: String = UUID().uuidString,
                       debtors: [Debtor]? = nil) -> Expense {
        Expense(id: UUID().uuidString, amount: amount, name: name, category: cat,
                date: String(format: "2026-%02d-%02d", mes, dia), isShared: debtors != nil, debtors: debtors)
    }

    private func regla(_ n: String, _ amount: Double = 10, dia: Int) -> RecurringExpense {
        RecurringExpense(id: n, amount: amount, name: n, category: "Ocio", subcategory: nil, paymentMethod: "Tarjeta",
                         frequency: .monthly, dayOfMonth: dia, billingMonth: 0, active: true, icon: nil,
                         startDate: nil, endDate: nil, lastCreated: nil, createdAt: nil, updatedAt: nil)
    }

    private func resumen(_ gastos: [Expense], anterior: [Expense] = [], metas: [Goal] = [],
                         recurrentes: [RecurringExpense] = [], presupuesto: Double? = nil,
                         preferencias: HomePreferencias = HomePreferencias()) -> HomeResumen {
        HomeResumen.build(gastos: gastos, gastosMesAnterior: anterior, metas: metas, recurrentes: recurrentes,
                          presupuesto: presupuesto, primerGasto: nil, hoy: hoy, calendar: cal,
                          preferencias: preferencias)
    }

    /// Relevancias inventadas: solo las clases que aparecen tienen datos.
    private func tarjetas(_ d: D, _ relevancias: [String: Double], ultimos: Bool = true) -> [D.Tarjeta] {
        d.tarjetas(relevancias: relevancias, hayUltimos: ultimos)
    }

    private func elemento(_ tipo: D.Tipo, _ tamano: D.Tamano, id: String? = nil) -> D.Elemento {
        D.Elemento(id: id ?? UUID().uuidString, tipo: tipo, tamano: tamano)
    }

    // MARK: - Quien nunca edita ve lo de siempre

    /// Cada pila de la disposición por defecto enseña lo mismo que su hueco.
    private func reproduceLosHuecos(_ r: HomeResumen, _ d: D, sourceLocation: SourceLocation = #_sourceLocation) {
        let t = d.tarjetas(relevancias: r.relevancias, hayUltimos: true)
        for (slot, id) in [(HomeResumen.Slot.a, "pila-a"), (.b, "pila-b"), (.c, "pila-c"), (.e, "pila-e")] {
            #expect(t.first { $0.id == id }?.clase == r.slots[slot]?.clase, "\(id)", sourceLocation: sourceLocation)
        }
    }

    @Test("La disposición por defecto reproduce los cuatro huecos de siempre")
    func porDefectoReproduceLosHuecos() {
        // Sin nada configurado (el caso de `HomeResumenTests.huecosNuncaVacios`).
        let sencillo = resumen([
            gasto(20, "Alimentación", dia: 1), gasto(30, "Ocio", dia: 2),
            gasto(46, "Ocio", dia: 4, name: "Cena"), gasto(12, "Transporte", dia: 8), gasto(9, "Alimentación", dia: 9),
        ])
        reproduceLosHuecos(sencillo, .porDefecto)
        #expect(D.porDefecto.tarjetas(relevancias: sencillo.relevancias, hayUltimos: true).compactMap(\.clase)
                == ["reparto", "diaCaro", "semana", "semanaASemana"])

        // Con todo configurado (`huecosCompletos`): límites, cargos, deudas, comparativa.
        let metas = [
            Goal(name: "Ocio", type: .spendingLimit, targetAmount: 300, linkedCategoryId: "Ocio"),
            Goal(name: "Moto", type: .savingsTarget, targetAmount: 5000, currentAmount: 200),
        ]
        let completo = resumen([gasto(209.54, "Ocio", dia: 3, debtors: [Debtor(name: "Marcos", amount: 40)])],
                               anterior: [gasto(260, "Ocio", dia: 5, mes: 3)], metas: metas,
                               recurrentes: [regla("Netflix", 12.99, dia: 15)], presupuesto: 2080)
        reproduceLosHuecos(completo, .porDefecto)
        #expect(D.porDefecto.tarjetas(relevancias: completo.relevancias, hayUltimos: true).compactMap(\.clase)
                == ["limites", "cargos", "teDeben", "comparativa"])
    }

    @Test("Migrada, lo ocultado y lo ordenado en la hoja de antes pesan igual que en los huecos")
    func migradaReproduceLasPreferencias() {
        let gastos = (1...9).map { gasto(Double($0), "Ocio", dia: $0) } + [gasto(46, "Ocio", dia: 4, name: "Cena")]
        let preferencias = HomePreferencias(ocultas: ["diaCaro", "reparto"], prioridad: ["hormiga", "racha"])
        let r = resumen(gastos, preferencias: preferencias)
        let d = D.migrada(desde: preferencias)
        #expect(d.elementos == D.porDefecto.elementos)
        #expect(d.ocultas == preferencias.ocultas)
        #expect(d.prioridad == preferencias.prioridad)
        #expect(d.actualizada == D.nunca)
        reproduceLosHuecos(r, d)
        // Lo ordenado gana los huecos pequeños a lo que puntúa más (semana, 0,65).
        #expect(Set([r.slots[.b]?.clase, r.slots[.c]?.clase]) == ["hormiga", "racha"])
    }

    @Test("Lo oculto sigue disponible para colocarlo a mano: ocultar solo lo saca de pilas y huecos")
    func ocultasSiguenDisponibles() {
        let gastos = [gasto(20, "Ocio", dia: 1), gasto(46, "Ocio", dia: 4), gasto(12, "Transporte", dia: 8)]
        let r = resumen(gastos, preferencias: HomePreferencias(ocultas: ["reparto"]))
        #expect(r.disponibles["reparto"] != nil)
        #expect(r.relevancias["reparto"] != nil)
        #expect(!r.slots.values.map(\.clase).contains("reparto"))
    }

    // MARK: - Catálogo

    @Test("Los tamaños salen de las colas de los huecos: A o E, ancha; B o C, pequeña; y la comparativa, las dos")
    func tamanosDelCatalogo() {
        let anchas = Set(HomeResumen.Slot.a.candidatos + HomeResumen.Slot.e.candidatos)
        // «Frente al mes pasado» solo iba en huecos anchos, pero en media fila se
        // lee bien (se ve en las capturas): admite los dos.
        let pequenas = Set(HomeResumen.Slot.b.candidatos + HomeResumen.Slot.c.candidatos + ["comparativa"])
        #expect(D.catalogo.count == 18)
        #expect(Set(D.catalogo.map(\.id)) == anchas.union(pequenas))
        for ficha in D.catalogo {
            #expect(ficha.tamanos.contains(.ancha) == anchas.contains(ficha.id), "\(ficha.id)")
            #expect(ficha.tamanos.contains(.pequena) == pequenas.contains(ficha.id), "\(ficha.id)")
        }
        #expect(D.catalogo.filter { $0.tamanos.count == 2 }.map(\.id).sorted() == ["comparativa", "fueraDeNormal", "hucha", "subeFuerte"])
        // Una pila pequeña de las que añade el usuario también la tiene en cuenta, la última.
        #expect(D.candidatosDePila(.pequena).last == "comparativa")
        #expect(D.candidatosDePila(.ancha) == ["limites", "fueraDeNormal", "reparto", "sitios", "limiteSugerido",
                                               "hucha", "comparativa", "semanaASemana", "subeFuerte"])
        #expect(D.tamanos(de: .ultimos) == [.ancha])
        #expect(Set(D.tamanos(de: .pila)) == [.ancha, .pequena])
    }

    // MARK: - Pilas

    @Test("Una pila no enseña lo que ya está colocado a mano")
    func pilaSinLoColocado() {
        let d = D(elementos: [elemento(.clase("limites"), .ancha), elemento(.pila, .ancha, id: "p")])
        let t = tarjetas(d, ["limites": 1, "reparto": 0.3])
        #expect(t.map(\.clase) == ["limites", "reparto"])
    }

    @Test("Dos pilas no enseñan lo mismo: la de arriba elige primero")
    func pilasSinRepetir() {
        let d = D(elementos: [elemento(.pila, .pequena, id: "1"), elemento(.pila, .pequena, id: "2")])
        #expect(tarjetas(d, ["teDeben": 0.8, "cargos": 0.5]).map(\.clase) == ["teDeben", "cargos"])
    }

    @Test("La pila respeta su tamaño: una pequeña no enseña lo que solo va a lo ancho")
    func pilaRespetaTamano() {
        let d = D(elementos: [elemento(.pila, .pequena, id: "p")])
        #expect(tarjetas(d, ["limites": 1, "racha": 0.2]).first?.clase == "racha")
        // Lo que admite los dos cabe en las dos.
        #expect(tarjetas(d, ["limites": 1, "hucha": 0.5]).first?.clase == "hucha")
    }

    @Test("La pila no enseña lo oculto, pero colocado a mano sí sale")
    func pilaYOcultas() {
        var d = D(elementos: [elemento(.pila, .ancha, id: "p")], ocultas: ["limites"])
        #expect(tarjetas(d, ["limites": 1, "reparto": 0.3]).first?.clase == "reparto")
        d.elementos.append(elemento(.clase("limites"), .ancha))
        let t = tarjetas(d, ["limites": 1, "reparto": 0.3])
        #expect(t.last?.clase == "limites" && t.last?.conDatos == true)
    }

    @Test("Una pila sin nada que enseñar no se pinta fuera de edición")
    func pilaVacia() {
        let d = D(elementos: [elemento(.pila, .pequena, id: "p"), elemento(.ultimos, .ancha, id: "u")])
        let t = tarjetas(d, ["limites": 1])
        #expect(t.first?.clase == nil)
        #expect(t.first?.conDatos == false)
        #expect(t.filter(\.conDatos).map(\.id) == ["u"])
    }

    @Test("La prioridad de antes sigue ganando dentro de las pilas")
    func prioridadEnPilas() {
        let d = D(elementos: [elemento(.pila, .pequena, id: "p")], prioridad: ["racha"])
        #expect(tarjetas(d, ["teDeben": 0.8, "racha": 0.2]).first?.clase == "racha")
    }

    // MARK: - Qué se pinta

    @Test("Una tarjeta colocada sin datos este mes no se pinta; los últimos, solo con gastos")
    func sinDatos() {
        let d = D(elementos: [elemento(.clase("teDeben"), .pequena, id: "t"), elemento(.ultimos, .ancha, id: "u")])
        let sin = tarjetas(d, [:], ultimos: false)
        #expect(sin.map(\.conDatos) == [false, false])
        let con = tarjetas(d, ["teDeben": 0.8], ultimos: true)
        #expect(con.map(\.conDatos) == [true, true])
    }

    @Test("Una clase que esta versión no conoce se conserva pero no se pinta")
    func claseDesconocida() {
        let d = D(elementos: [elemento(.clase("deOtraVersion"), .ancha, id: "x"), elemento(.ultimos, .ancha, id: "u")])
        #expect(tarjetas(d, ["deOtraVersion": 1]).map(\.id) == ["u"])
        #expect(d.normalizada().elementos.count == 2)
    }

    // MARK: - Filas

    @Test("Las pequeñas van de dos en dos y las anchas solas; una suelta antes de una ancha deja media fila vacía")
    func filas() {
        let p = D.Tamano.pequena, a = D.Tamano.ancha
        func filas(_ tamanos: [D.Tamano]) -> [[Int]] {
            D.filas(Array(tamanos.indices)) { tamanos[$0] }
        }
        #expect(filas([a, p, p, a, a]) == [[0], [1, 2], [3], [4]])
        #expect(filas([p, a, p, p, p]) == [[0], [1], [2, 3], [4]])
        #expect(filas([p]) == [[0]])
        #expect(filas([]) == [])
    }

    // MARK: - Editar

    @Test("Añadir pone la tarjeta arriba; una clase y los últimos, una sola vez; pilas, las que se quiera")
    func anadir() {
        var d = D.porDefecto
        let r1 = d.anadir(.clase("hucha"), tamano: .pequena, id: "h")
        #expect(r1 == "h")
        #expect(d.elementos.first == D.Elemento(id: "h", tipo: .clase("hucha"), tamano: .pequena))
        let r2 = d.anadir(.clase("hucha"))
        #expect(r2 == nil)
        let r3 = d.anadir(.ultimos)
        #expect(r3 == nil)
        let r4 = d.anadir(.pila, tamano: .pequena)
        #expect(r4 != nil)
        let r5 = d.anadir(.clase("inventada"))
        #expect(r5 == nil)
        // Un tamaño que no admite: el suyo.
        let r6 = d.anadir(.clase("limites"), tamano: .pequena, id: "l")
        #expect(r6 == "l")
        #expect(d.elementos.first?.tamano == .ancha)
    }

    @Test("Cambiar de tamaño solo a uno que admita, y la pila de un hueco pasa a ser una pila cualquiera")
    func cambiarTamano() {
        var d = D.porDefecto
        let r7 = d.cambiarTamano("ultimos", a: .pequena)
        #expect(!r7)
        let r8 = d.cambiarTamano("pila-a", a: .ancha)
        #expect(!r8)
        let r9 = d.cambiarTamano("pila-a", a: .pequena)
        #expect(r9)
        #expect(d.elementos[0].tamano == .pequena)
        #expect(d.elementos[0].hueco == nil)
        // Ya sin la cola del hueco A elige entre todo lo pequeño.
        #expect(d.tarjetas(relevancias: ["racha": 0.2], hayUltimos: true).first?.clase == "racha")
    }

    @Test("Ordenar, mover un puesto y quitar")
    func ordenarMoverQuitar() {
        var d = D.porDefecto
        let r10 = d.ordenar(["pila-e", "ultimos"])
        #expect(r10)
        #expect(d.elementos.map(\.id) == ["pila-e", "ultimos", "pila-a", "pila-b", "pila-c"])
        let r11 = d.ordenar(d.elementos.map(\.id))
        #expect(!r11)
        let r12 = d.mover("pila-e", puestos: 1)
        #expect(r12)
        #expect(d.elementos.map(\.id).prefix(2) == ["ultimos", "pila-e"])
        let r13 = d.mover("ultimos", puestos: -1)
        #expect(!r13)
        let r14 = d.quitar("pila-b")
        #expect(r14)
        let r15 = d.quitar("pila-b")
        #expect(!r15)
        #expect(!d.elementos.map(\.id).contains("pila-b"))
    }

    @Test("Sacar de la pila y devolver")
    func ocultarYDevolver() {
        var d = D.porDefecto
        let r16 = d.noEnsenarEnPila("hucha")
        #expect(r16)
        let r17 = d.noEnsenarEnPila("hucha")
        #expect(!r17)
        let r18 = d.devolverAPila("hucha")
        #expect(r18)
        #expect(d.ocultas.isEmpty)
    }

    @Test("Volver a la Home de siempre: las tarjetas de siempre, nada oculto ni ordenado")
    func restablecer() {
        var d = D.migrada(desde: HomePreferencias(ocultas: ["racha"], prioridad: ["hucha"]))
        d.quitar("pila-a")
        d.anadir(.clase("limites"))
        #expect(!d.esLaDeSiempre)
        let cambio = d.restablecer()
        #expect(cambio)
        #expect(d.esLaDeSiempre)
        let otra = d.restablecer()
        #expect(!otra)
    }

    // MARK: - iPhone y cuenta

    @Test("Gana la más reciente; la del iPhone se sube si la cuenta no la tiene; la no editada, nunca")
    func masReciente() {
        var local = D.porDefecto
        var remota = D.porDefecto
        remota.elementos.removeLast()
        remota.actualizada = Date(timeIntervalSince1970: 100)

        // Nunca editada en el iPhone: manda la cuenta.
        #expect(D.masReciente(local: local, remota: remota) == (remota, false))
        #expect(D.masReciente(local: local, remota: nil) == (local, false))

        local.actualizada = Date(timeIntervalSince1970: 200)
        #expect(D.masReciente(local: local, remota: remota) == (local, true))
        #expect(D.masReciente(local: local, remota: nil) == (local, true))

        remota.actualizada = Date(timeIntervalSince1970: 300)
        #expect(D.masReciente(local: local, remota: remota) == (remota, false))

        remota = local
        #expect(D.masReciente(local: local, remota: remota) == (local, false))
    }

    @Test("En el iPhone: sin copia, la Home de siempre con lo de la hoja de antes; con copia, esa")
    func cargarYGuardar() throws {
        let suite = "tests.home.disposicion"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(D.cargar(de: defaults) == .porDefecto)

        HomePreferencias(ocultas: ["racha"], prioridad: ["hucha"]).guardar(en: defaults)
        let migrada = D.cargar(de: defaults)
        #expect(migrada.ocultas == ["racha"])
        #expect(migrada.prioridad == ["hucha"])

        var editada = migrada
        editada.quitar("pila-e")
        editada.actualizada = Date(timeIntervalSince1970: 1_000)
        editada.guardar(en: defaults)
        #expect(D.cargar(de: defaults) == editada)
    }

    // MARK: - Formato

    @Test("JSON de ida y vuelta, con el formato legible que queda en Firestore")
    func json() throws {
        var d = D.porDefecto
        d.anadir(.clase("hucha"), tamano: .pequena, id: "h")
        d.ocultas = ["racha", "diaCaro"]
        d.actualizada = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try JSONEncoder().encode(d)
        #expect(try JSONDecoder().decode(D.self, from: data) == d)

        let objeto = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let elementos = try #require(objeto["elementos"] as? [[String: Any]])
        #expect(elementos[0]["tipo"] as? String == "clase")
        #expect(elementos[0]["clase"] as? String == "hucha")
        #expect(elementos[0]["tamano"] as? String == "pequena")
        #expect(elementos[1]["hueco"] as? String == "a")
        #expect(objeto["ocultas"] as? [String] == ["diaCaro", "racha"])
    }

    @Test("Leer es tolerante: lo que no se entiende se salta y el resto se queda, sin repetidos")
    func lecturaTolerante() throws {
        let json = """
        {"elementos": [
            {"id": "1", "tipo": "clase", "clase": "limites", "tamano": "ancha"},
            {"id": "2", "tipo": "widgetDelFuturo", "tamano": "ancha"},
            {"id": "3", "tipo": "clase", "clase": "limites", "tamano": "ancha"},
            {"id": "4", "tipo": "clase", "clase": "racha", "tamano": "gigante"},
            {"id": "5", "tipo": "pila", "tamano": "pequena", "hueco": "a"},
            {"id": "1", "tipo": "ultimos", "tamano": "ancha"},
            {"id": "6", "tipo": "clase", "clase": "hucha", "tamano": "pequena"},
            {"id": "7", "tipo": "clase", "clase": "reparto", "tamano": "pequena"}
        ], "ocultas": ["racha"]}
        """
        let d = try JSONDecoder().decode(D.self, from: Data(json.utf8))
        #expect(d.elementos.map(\.id) == ["1", "5", "6", "7"])
        // La pila pequeña no puede llevar la cola del hueco A, que es ancho.
        #expect(d.elementos[1].hueco == nil)
        // «Dónde se te va» no cabe en media fila: vuelve a la suya.
        #expect(d.elementos[3].tamano == .ancha)
        #expect(d.ocultas == ["racha"])
        #expect(d.actualizada == D.nunca)

        // Sin lista no es una disposición.
        #expect(throws: (any Error).self) { try JSONDecoder().decode(D.self, from: Data(#"{"ocultas": []}"#.utf8)) }
    }

    @Test("Firestore de ida y vuelta, con la fecha como Timestamp")
    func firestore() throws {
        var d = D.porDefecto
        d.anadir(.pila, tamano: .pequena, id: "nueva")
        d.actualizada = Date(timeIntervalSince1970: 1_700_000_000)
        let campos = try Firestore.Encoder().encode(d)
        #expect(campos["actualizada"] is Timestamp)
        #expect(try Firestore.Decoder().decode(D.self, from: campos) == d)
    }

    @Test("A la cuenta va un único campo, homeDisposicion: nada de categories ni del resto del documento")
    func camposQueSeEscriben() throws {
        let campos = try UserDataService.camposHomeDisposicion(.porDefecto)
        #expect(Array(campos.keys) == ["homeDisposicion"])
        let dentro = try #require(campos["homeDisposicion"] as? [String: Any])
        #expect(Set(dentro.keys) == ["elementos", "ocultas", "prioridad", "actualizada"])
    }

    @Test("El documento de usuario se lee igual sin el campo, con él, y con él roto")
    func documentoDeUsuario() throws {
        let sin = try JSONDecoder().decode(UserDocument.self, from: Data(#"{"displayName": "Dani"}"#.utf8))
        #expect(sin.homeDisposicion == nil)
        #expect(sin.displayName == "Dani")

        var d = D.porDefecto
        d.actualizada = Date(timeIntervalSince1970: 5)
        var doc = UserDocument(displayName: "Dani")
        doc.homeDisposicion = d
        let ida = try JSONDecoder().decode(UserDocument.self, from: JSONEncoder().encode(doc))
        #expect(ida.homeDisposicion == d)

        let roto = try JSONDecoder().decode(UserDocument.self, from: Data(#"{"displayName": "Dani", "homeDisposicion": 42}"#.utf8))
        #expect(roto.homeDisposicion == nil)
        #expect(roto.displayName == "Dani")
    }
}
