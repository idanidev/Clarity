// LocalRecurringExpenseManagerTests.swift
// `LocalRecurringExpenseManager` es lo que sustituye a las Cloud Functions:
// al abrir la app crea GASTOS DE VERDAD a partir de las reglas recurrentes.
// La lógica pura (frecuencias, dedupe, clamp) ya estaba cubierta en
// `RecurringSchedulerTests`; lo que no tenía ni un test era el manager: el
// candado diario, qué se guarda exactamente, qué pasa si falla la red, la
// caducidad de las reglas y la recuperación de cargos perdidos.
//
// Nada de esto toca lo real: repos dobles, un `UserDefaults` propio por test
// (los tests corren dentro de la app, y las claves del candado en `.standard`
// son las de la sesión de verdad) y el reloj fijado.

import Testing
import Foundation
@testable import Clarity

@Suite("Recurrentes locales (manager)", .serialized)
@MainActor
struct LocalRecurringExpenseManagerTests {

    // MARK: - Entorno

    private static let claveComprobacion = "lastRecurringExpensesCheck"
    private static let claveRecuperacion = "lastRecurringExpensesRecovery"

    /// Repos dobles + un `UserDefaults` aparte, vacío al empezar y al acabar.
    @MainActor
    private final class Entorno {
        let reglas = MockRecurringExpenseRepository()
        let gastos = MockExpenseRepository()
        let defaults: UserDefaults
        /// Un único dominio, siempre el mismo, y no uno por test con un UUID:
        /// `removePersistentDomain` vacía el dominio pero deja su plist, y con
        /// nombres únicos cada pasada sembraba decenas de archivos vacíos en el
        /// contenedor de la app. No hay pisotones: la suite es `.serialized` y
        /// nadie más usa este nombre.
        private let suite = "tests.recurrentes"

        init() throws {
            defaults = try #require(UserDefaults(suiteName: suite))
            defaults.removePersistentDomain(forName: suite)
        }

        func manager(hoy: Date) -> LocalRecurringExpenseManager {
            LocalRecurringExpenseManager(
                recurringRepo: reglas, expenseRepo: gastos, defaults: defaults, ahora: { hoy })
        }

        /// Que no quede ni el plist del dominio en el contenedor de la app.
        func limpiar() {
            defaults.removePersistentDomain(forName: suite)
        }
    }

    /// Mediodía UTC: el mismo día del calendario en (casi) cualquier huso, y el
    /// mismo que verá `Formatters.isoString`, que también es UTC.
    private func dia(_ anio: Int, _ mes: Int, _ dia: Int) throws -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        return try #require(utc.date(from: DateComponents(year: anio, month: mes, day: dia, hour: 12)))
    }

    /// «Hoy» de casi todos los tests.
    private func quinceDeSeptiembre() throws -> Date { try dia(2026, 9, 15) }

    private func regla(
        id: String? = "netflix",
        nombre: String = "Netflix",
        importe: Double = 12.99,
        frecuencia: RecurringFrequency = .monthly,
        dia: Int,
        billingMonth: Int = 0,
        activa: Bool = true,
        fin: String? = nil,
        inicio: String? = nil,
        creada: String? = nil
    ) -> RecurringExpense {
        RecurringExpense(
            id: id, amount: importe, name: nombre, category: "Suscripciones📺",
            subcategory: "Streaming", paymentMethod: "Tarjeta", frequency: frecuencia,
            dayOfMonth: dia, billingMonth: billingMonth, active: activa, icon: nil,
            startDate: inicio, endDate: fin, lastCreated: nil, createdAt: creada, updatedAt: nil)
    }

    private func cargo(de reglaId: String, fecha: String) -> Expense {
        Expense(id: "ya-\(fecha)", amount: 12.99, name: "Netflix", category: "Suscripciones📺",
                date: fecha, isRecurring: true, recurringId: reglaId)
    }

    // MARK: - checkAndCreatePendingExpenses

    @Test("el día de cobro crea el gasto, con los datos de la regla y el id determinista")
    func creaElGastoDelDia() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 15)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.expenses.count == 1)
        let pedido = try #require(entorno.gastos.addedExpenses.first)
        // Id determinista: dos dispositivos creando el mismo cargo escriben el
        // MISMO documento en Firestore, no dos.
        #expect(pedido.id == "rec_netflix_2026-09")
        #expect(pedido.date == "2026-09-15")
        #expect(pedido.amount == 12.99)
        #expect(pedido.name == "Netflix")
        #expect(pedido.category == "Suscripciones📺")
        #expect(pedido.subcategory == "Streaming")
        #expect(pedido.paymentMethod == "Tarjeta")
        #expect(pedido.isRecurring == true)
        #expect(pedido.recurringId == "netflix")
        #expect(entorno.defaults.string(forKey: Self.claveComprobacion) == "2026-09-15")
    }

    @Test("la segunda llamada del día no duplica: ni siquiera vuelve a preguntar")
    func segundaLlamadaNoDuplica() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 15)]
        let manager = entorno.manager(hoy: try quinceDeSeptiembre())

        await manager.checkAndCreatePendingExpenses()
        await manager.checkAndCreatePendingExpenses()

        #expect(entorno.gastos.expenses.count == 1)
        #expect(entorno.reglas.fetchAllCalls == 1)
    }

    // Otro dispositivo, o la app reinstalada: el candado local no está, pero el
    // gasto del mes sí. Lo que evita el duplicado es el gasto, no el candado.
    @Test("sin el candado del día tampoco duplica: manda que el gasto ya exista")
    func sinCandadoTampocoDuplica() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 15)]
        let manager = entorno.manager(hoy: try quinceDeSeptiembre())

        await manager.checkAndCreatePendingExpenses()
        entorno.defaults.removeObject(forKey: Self.claveComprobacion)
        await manager.checkAndCreatePendingExpenses()

        #expect(entorno.reglas.fetchAllCalls == 2)
        #expect(entorno.gastos.expenses.count == 1)
    }

    @Test("si el cargo de este mes ya existe (otro día, a mano u otro móvil) no se crea")
    func noCreaSiYaExisteElDelMes() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 15)]
        entorno.gastos.expenses = [cargo(de: "netflix", fecha: "2026-09-03")]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.isEmpty)
        #expect(entorno.gastos.expenses.count == 1)
    }

    @Test("el cargo del mes pasado no cuenta como el de este")
    func elDelMesPasadoNoCuenta() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 15)]
        entorno.gastos.expenses = [cargo(de: "netflix", fecha: "2026-08-15")]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.map(\.date) == ["2026-09-15"])
    }

    @Test("una regla pausada no genera gasto; las activas de su lado, sí")
    func respetaLasPausadas() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [
            regla(id: "gimnasio", nombre: "Gimnasio", dia: 15, activa: false),
            regla(id: "netflix", dia: 15),
        ]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.map(\.recurringId) == ["netflix"])
    }

    @Test("solo reglas pausadas: nada que crear, y el día queda comprobado")
    func soloPausadas() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 15, activa: false)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.isEmpty)
        #expect(entorno.defaults.string(forKey: Self.claveComprobacion) == "2026-09-15")
    }

    @Test("si hoy no es el día de cobro no se crea nada")
    func otroDiaNoCrea() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 20)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.isEmpty)
    }

    // Septiembre = mes 9. Trimestral desde marzo: 3, 6, 9, 12. Desde enero: 1, 4, 7, 10.
    @Test("frecuencias no mensuales: solo se cobra en los meses que marca billingMonth", arguments: [
        (RecurringFrequency.yearly, 9, true),
        (.yearly, 3, false),
        (.quarterly, 3, true),
        (.quarterly, 12, true),
        (.quarterly, 1, false),
        (.semestral, 3, true),
        (.semestral, 9, true),
        (.semestral, 1, false),
        // Sin mes de facturación (0) una regla no mensual no sabe cuándo toca.
        (.yearly, 0, false),
        (.quarterly, 0, false),
        (.semestral, 0, false),
    ])
    func frecuenciaConBillingMonth(_ frecuencia: RecurringFrequency, _ billingMonth: Int, _ toca: Bool) async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "seguro", nombre: "Seguro", frecuencia: frecuencia,
                                      dia: 15, billingMonth: billingMonth)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        let esperado: [String?] = toca ? ["rec_seguro_2026-09"] : []
        #expect(entorno.gastos.addedExpenses.map(\.id) == esperado)
    }

    @Test("una regla caducada se desactiva y no cobra")
    func caducadaSeDesactiva() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "plazos", dia: 15, fin: "2026-09-14")]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.isEmpty)
        let desactivada = try #require(entorno.reglas.updated.first)
        #expect(desactivada.id == "plazos")
        #expect(desactivada.active == false)
    }

    // El último plazo se perdía: `endDate` es medianoche y a media mañana «hoy»
    // ya la había pasado. Se compara por día, así que el día del fin aún cobra.
    @Test("el día en que termina todavía se cobra el último plazo", arguments: [
        "2026-09-15", "2026-09-15T00:00:00Z",
    ])
    func elDiaDelFinAunCobra(_ fin: String) async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "plazos", dia: 15, fin: fin)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.map(\.id) == ["rec_plazos_2026-09"])
        #expect(entorno.reglas.updated.isEmpty)
    }

    @Test("un importe negativo se guarda como cero, nunca en negativo")
    func importeNegativo() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(importe: -5, dia: 15)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.map(\.amount) == [0])
    }

    // Si el fallo marcase el día como comprobado, un arranque sin cobertura se
    // comería los recurrentes de hoy.
    @Test("si no se pueden leer las reglas, el día NO queda comprobado y se reintenta")
    func falloAlLeerNoQuemaElDia() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 15)]
        entorno.reglas.shouldFail = true
        let manager = entorno.manager(hoy: try quinceDeSeptiembre())

        await manager.checkAndCreatePendingExpenses()
        #expect(entorno.defaults.string(forKey: Self.claveComprobacion) == nil)
        #expect(entorno.gastos.addedExpenses.isEmpty)

        entorno.reglas.shouldFail = false
        await manager.checkAndCreatePendingExpenses()
        #expect(entorno.gastos.addedExpenses.count == 1)
    }

    @Test("si falla el guardado del gasto, el día NO queda comprobado y se reintenta")
    func falloAlGuardarNoQuemaElDia() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(dia: 15)]
        entorno.gastos.shouldFailAdd = true
        let manager = entorno.manager(hoy: try quinceDeSeptiembre())

        await manager.checkAndCreatePendingExpenses()
        #expect(entorno.defaults.string(forKey: Self.claveComprobacion) == nil)
        #expect(entorno.gastos.expenses.isEmpty)

        entorno.gastos.shouldFailAdd = false
        await manager.checkAndCreatePendingExpenses()
        #expect(entorno.gastos.expenses.count == 1)
    }

    @Test("al día siguiente el candado de ayer ya no vale")
    func elCandadoEsPorDia() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "a", dia: 15), regla(id: "b", dia: 16)]

        await entorno.manager(hoy: try dia(2026, 9, 15)).checkAndCreatePendingExpenses()
        await entorno.manager(hoy: try dia(2026, 9, 16)).checkAndCreatePendingExpenses()

        #expect(entorno.gastos.addedExpenses.map(\.id) == ["rec_a_2026-09", "rec_b_2026-09"])
        #expect(entorno.defaults.string(forKey: Self.claveComprobacion) == "2026-09-16")
    }

    // MARK: - recoverMissedExpenses

    /// Un cargo de `reglaId` en cada uno de `meses`: así lo único que falta en
    /// la ventana de recuperación es lo que el test quiere ver recuperado.
    private func historialCompleto(de reglaId: String, meses: [String]) -> [Expense] {
        meses.map { cargo(de: reglaId, fecha: "\($0)-10") }
    }

    private static let octubreAAgosto = [
        "2025-10", "2025-11", "2025-12", "2026-01", "2026-02", "2026-03",
        "2026-04", "2026-05", "2026-06", "2026-07", "2026-08",
    ]

    @Test("recupera el cargo perdido del mes en curso, con la fecha de su día de cobro")
    func recuperaElDelMesEnCurso() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "luz", nombre: "Luz", dia: 10)]
        entorno.gastos.expenses = historialCompleto(de: "luz", meses: Self.octubreAAgosto)

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        let recuperado = try #require(entorno.gastos.addedExpenses.first)
        #expect(entorno.gastos.addedExpenses.count == 1)
        // La fecha es la del día de cobro (el 10), no la de hoy (el 15).
        #expect(recuperado.date == "2026-09-10")
        #expect(recuperado.id == "rec_luz_2026-09")
        #expect(recuperado.recurringId == "luz")
        #expect(recuperado.isRecurring == true)
        #expect(recuperado.name == "Luz")
        #expect(entorno.defaults.string(forKey: Self.claveRecuperacion) == "2026-09-15")
    }

    @Test("no adelanta el cargo de este mes si su día aún no ha llegado")
    func noRecuperaSiElDiaNoHaLlegado() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "luz", dia: 20)]
        entorno.gastos.expenses = historialCompleto(de: "luz", meses: Self.octubreAAgosto)

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        #expect(entorno.gastos.addedExpenses.isEmpty)
    }

    @Test("el mismo día de cobro ya cuenta como llegado")
    func recuperaElMismoDiaDeCobro() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "luz", dia: 15)]
        entorno.gastos.expenses = historialCompleto(de: "luz", meses: Self.octubreAAgosto)

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        #expect(entorno.gastos.addedExpenses.map(\.date) == ["2026-09-15"])
    }

    @Test("recuperar dos veces no duplica, ni con el candado del día ni sin él")
    func recuperarDosVecesNoDuplica() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "luz", dia: 10)]
        entorno.gastos.expenses = historialCompleto(de: "luz", meses: Self.octubreAAgosto)
        let manager = entorno.manager(hoy: try quinceDeSeptiembre())

        await manager.recoverMissedExpenses()
        await manager.recoverMissedExpenses()
        #expect(entorno.reglas.fetchAllCalls == 1)
        #expect(entorno.gastos.addedExpenses.count == 1)

        entorno.defaults.removeObject(forKey: Self.claveRecuperacion)
        await manager.recoverMissedExpenses()
        #expect(entorno.reglas.fetchAllCalls == 2)
        #expect(entorno.gastos.addedExpenses.count == 1)
    }

    @Test("trimestral con billingMonth: recupera solo sus meses, cada uno con su id")
    func recuperaTrimestral() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        // Desde marzo: 3, 6, 9, 12. En la ventana oct-2025 … sep-2026 caen cuatro.
        entorno.reglas.rules = [regla(id: "seguro", frecuencia: .quarterly, dia: 10, billingMonth: 3)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        let recuperados = entorno.gastos.addedExpenses.sorted { $0.date < $1.date }
        #expect(recuperados.map(\.date) == ["2025-12-10", "2026-03-10", "2026-06-10", "2026-09-10"])
        #expect(recuperados.map(\.id) == [
            "rec_seguro_2025-12", "rec_seguro_2026-03", "rec_seguro_2026-06", "rec_seguro_2026-09",
        ])
    }

    @Test("anual con billingMonth: recupera el de su mes aunque hayan pasado meses")
    func recuperaAnual() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "dominio", frecuencia: .yearly, dia: 10, billingMonth: 3)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        #expect(entorno.gastos.addedExpenses.map(\.date) == ["2026-03-10"])
    }

    // Ojo: el ajuste de día del manager cuenta los días del mes con
    // `Calendar.current` sobre una fecha en UTC. En un huso al oeste de UTC el
    // «1 de septiembre a medianoche UTC» es 31 de agosto, saldrían 31 días y la
    // fecha sería «2026-09-31». En ese huso este test fallaría, y con razón.
    @Test("un día 31 se recupera en el último día de un mes de 30")
    func recuperaConDiaAjustado() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "alquiler", dia: 31)]
        // Hoy es 5 de octubre: falta septiembre; octubre aún no toca (día 31).
        entorno.gastos.expenses = historialCompleto(de: "alquiler", meses: [
            "2025-11", "2025-12", "2026-01", "2026-02", "2026-03",
            "2026-04", "2026-05", "2026-06", "2026-07", "2026-08",
        ])

        await entorno.manager(hoy: try dia(2026, 10, 5)).recoverMissedExpenses()

        #expect(entorno.gastos.addedExpenses.map(\.date) == ["2026-09-30"])
    }

    @Test("ni las pausadas ni las caducadas se recuperan")
    func noRecuperaPausadasNiCaducadas() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [
            regla(id: "pausada", dia: 10, activa: false),
            regla(id: "caducada", dia: 10, fin: "2026-09-14"),
        ]

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        #expect(entorno.gastos.addedExpenses.isEmpty)
    }

    @Test("si no se pueden leer las reglas, la recuperación se reintenta otro rato")
    func falloAlRecuperarNoQuemaElDia() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.shouldFail = true

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        #expect(entorno.defaults.string(forKey: Self.claveRecuperacion) == nil)
    }

    // La recuperación no inventa gastos anteriores al alta de la regla. Antes la
    // ventana eran 12 meses a secas: a una regla mensual recién creada se le
    // rellenaban los 11 meses anteriores en cuanto se abría Recurrentes.
    @Test("una regla dada de alta el mes pasado solo recupera desde ese mes")
    func reglaNuevaNoRellenaAntesDeSuAlta() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "nueva", dia: 1, inicio: "2026-08-20")]

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        let meses = entorno.gastos.addedExpenses.map { String($0.date.prefix(7)) }.sorted()
        // Agosto entero cuenta aunque el alta fuera el día 20 y el cobro el 1,
        // igual que al guardar la regla (`createCurrentPeriodExpenseIfDue`).
        #expect(meses == ["2026-08", "2026-09"])
    }

    @Test("sin `startDate`, el alta sale de `createdAt`")
    func altaDesdeCreatedAt() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "nueva", dia: 1, creada: "2026-09-03T10:15:00Z")]

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        let meses = entorno.gastos.addedExpenses.map { String($0.date.prefix(7)) }
        #expect(meses == ["2026-09"])
    }

    @Test("una regla antigua sin fechas conserva la ventana de 12 meses")
    func reglaSinFechasRellenaLaVentana() async throws {
        let entorno = try Entorno()
        defer { entorno.limpiar() }
        entorno.reglas.rules = [regla(id: "antigua", dia: 1)]

        await entorno.manager(hoy: try quinceDeSeptiembre()).recoverMissedExpenses()

        let meses = entorno.gastos.addedExpenses.map { String($0.date.prefix(7)) }.sorted()
        #expect(meses == Self.octubreAAgosto + ["2026-09"])
    }

    @Test("el mes de alta se lee de fechas válidas y se ignora lo ilegible", arguments: [
        ("2026-08-20", nil, "2026-08"),
        (nil, "2026-09-03T10:15:00Z", "2026-09"),
        ("", "2025-12-01", "2025-12"),
        ("ayer", nil, nil),
        ("2026-13-01", nil, nil),
        (nil, nil, nil),
    ] as [(String?, String?, String?)])
    func mesDeAlta(inicio: String?, creada: String?, esperado: String?) {
        let r = regla(dia: 1, inicio: inicio, creada: creada)
        #expect(RecurringScheduler.mesDeAlta(de: r) == esperado)
    }
}
