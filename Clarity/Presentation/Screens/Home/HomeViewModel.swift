// HomeViewModel.swift
// ViewModel for the main expense list/dashboard

import Foundation
import OSLog
import SwiftUI

enum HomeViewState: Equatable {
    case idle
    case loading
    case loaded([Expense])
    case error(AppError)  // Changed from String
    case empty

    static func == (lhs: HomeViewState, rhs: HomeViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.empty, .empty): return true
        case (.loaded(let l), .loaded(let r)): return l == r
        case (.error(let l), .error(let r)): return l == r
        default: return false
        }
    }
}

/// Lo que la Home saca de los gastos del mes. Se resuelve una vez por cambio de
/// datos, no en cada pintado: ver `HomeViewModel.derivados`.
struct HomeDerivados {
    let gastosDelMes: [Expense]
    let gastosMesAnterior: [Expense]
    let resumen: HomeResumen
    let gruposDelMes: [CategoryGroup]
    let ultimosGastos: [Expense]
    let gastosPorDia: [(dia: Int, importe: Double)]
    let comparativaPorCategoria: [(categoria: String, actual: Double, anterior: Double)]
    let semanasDelMes: [(etiqueta: String, importe: Double)]
    /// Todas las tarjetas de la disposición, con lo que enseña cada una.
    let tarjetas: [HomeDisposicion.Tarjeta]
    /// Las que tienen algo que enseñar, ya en filas: lo que se pinta fuera de edición.
    let filas: [[HomeDisposicion.Tarjeta]]
}

@MainActor
@Observable
final class HomeViewModel {

    // Output
    private(set) var state: HomeViewState = .idle
    private(set) var hasLoaded = false  // Prevents redundant reloads on tab switch

    // Month selector state
    /// Cambiar de mes mueve el filtro Y trae los gastos de ese mes. Las dos
    /// cosas cuelgan de aquí a propósito: cuando traerlos era responsabilidad
    /// de quien asignaba el mes, el selector se acordaba de pedirlos y el
    /// swipe de la gráfica no, así que deslizar dejaba el filtro en un mes
    /// cuyos gastos no se habían cargado nunca y la gráfica decía "Sin datos"
    /// teniéndolos. Ahora asignar el mes basta, venga de donde venga.
    var selectedMonth: Date = Date() {
        didSet {
            // Reasignar el mismo mes (o un día distinto del mismo mes) no
            // recarga: el filtro ya cubre ese rango.
            guard !Calendar.current.isDate(
                selectedMonth, equalTo: oldValue, toGranularity: .month) else { return }

            // Un mes ya traído —y el anterior, que se precarga para la
            // comparativa— se enseña al momento. Sin esto el mes salía vacío
            // mientras llegaba de red: la Home cambiaba al cartel de "sin
            // gastos" y se volvía a montar entera, y en Gráficas el anillo se
            // quedaba con todos los sectores a cero y Swift Charts reventaba
            // dividiendo entre cero.
            if let enMemoria = mesesEnMemoria[Self.monthKey(selectedMonth)] {
                currentMonthExpenses = enMemoria
                if searchText.isEmpty { allExpenses = enMemoria }
                cargandoMes = false
            } else {
                cargandoMes = true
            }
            invalidarDerivados()

            updateFilterForSelectedMonth()

            // Deslizar rápido varios meses deja peticiones en vuelo; sin
            // cancelar, la del mes que ya abandonaste puede llegar la última
            // y pisar la buena.
            monthChangeTask?.cancel()
            let mes = selectedMonth
            monthChangeTask = Task { [weak self] in
                guard let self, !Task.isCancelled else { return }
                // Presupuesto y gastos a la vez: en serie, cada cambio de mes
                // esperaba dos idas y vueltas a red antes de pedir los gastos.
                async let presupuesto: Void = self.loadMonthlyBudget(for: mes)
                await self.loadExpenses()
                await presupuesto
                guard !Task.isCancelled else { return }
                self.cargandoMes = false
                await self.loadMesAnterior()
                await self.loadNormal()
            }
        }
    }

    var selectedFilter: ExpenseFilter = ExpenseFilter() {
        didSet {
            applyFilters()
            // Tarjetas, últimos y gráficas también siguen al filtro.
            invalidarDerivados()
        }
    }
    var searchText: String = "" {
        didSet {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: esperaBusqueda)
                if !Task.isCancelled {
                    // Reload with allTime filter when searching so results cross all months;
                    // applyFilters() will skip the date filter while searchText is non-empty.
                    if let sustituta = recargaTrasBuscar {
                        await sustituta()  // solo en tests; ver `recargaTrasBuscar`
                    } else {
                        await loadExpenses(silent: true)
                    }
                }
            }
        }
    }

    /// Espera del debounce de la búsqueda (los 300 ms de siempre). Los tests la
    /// acortan, como `EditExpenseViewModel.esperaSugerencia`.
    @ObservationIgnored var esperaBusqueda: Duration = .milliseconds(300)

    /// Sustituto de la recarga que se lanza al vencer la espera. En la app es
    /// siempre `nil` y se llama a `loadExpenses(silent:)`, como antes. Solo lo
    /// ponen los tests, y no por comodidad: `loadExpenses` lee el presupuesto y
    /// los recurrentes de Firestore y reescribe los datos del widget, y los
    /// tests corren dentro de la app con la sesión real.
    @ObservationIgnored var recargaTrasBuscar: (@MainActor () async -> Void)?

    /// La recarga pendiente de la última tecla. `private(set)` para que los
    /// tests puedan esperarla en vez de dormir a ojo.
    private(set) var searchTask: Task<Void, Never>?
    private var monthChangeTask: Task<Void, Never>?

    // Data for View
    var categoryGroups: [CategoryGroup] = []
    var filteredExpenses: [Expense] = []
    var dateFilteredExpenses: [Expense] = []  // For filtered view
    var currentMonthExpenses: [Expense] = [] {  // Para cálculo de AHORROS (sin filtros)
        didSet { invalidarDerivados() }
    }
    var income: Double = 0 {
        didSet { if income != oldValue { invalidarDerivados() } }
    }
    var showAddExpense = false  // From DashboardViewModel
    var currentMonthlyBudget: MonthlyBudget? = nil {  // For savingsAllocated
        didSet { invalidarDerivados() }
    }
    var previousMonthlyBudget: MonthlyBudget? = nil  // Para cálculo de ahorros

    // Computed properties (from DashboardViewModel)
    var totalFilteredAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    /// Filtros de verdad: categorías, métodos de pago, importes o solo
    /// recurrentes. Ni el rango de fechas ni el orden cuentan: el mes lo mueve
    /// la barra, y contarlo hacía que la Home dijera "filtrado" en cuanto
    /// cambiabas de mes.
    var filtroActivo: Bool {
        let f = selectedFilter
        return !f.selectedCategories.isEmpty || !f.selectedPaymentMethods.isEmpty
            || f.minAmount != nil || f.maxAmount != nil || f.showOnlyRecurring
    }

    /// Quita los filtros sin moverse del mes que se está viendo. Asignar un
    /// `ExpenseFilter()` a secas volvía al mes actual aunque enseñaras otro, y
    /// la lista se quedaba vacía.
    func limpiarFiltros() {
        selectedFilter = ExpenseFilter()
        if !Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) {
            updateFilterForSelectedMonth()
        }
    }

    /// El nombre del filtro guardado, solo si lo puesto sigue siendo ese filtro.
    /// Al tocar una categoría en la hoja el filtro conservaba el nombre y la
    /// Home decía "Favs" con otras categorías. El período no cuenta: lo mueve
    /// el mes que se está viendo.
    var nombreFiltroActual: String? {
        let f = selectedFilter
        guard let nombre = f.name,
              let guardado = UserDataManager.shared.savedFilters.first(where: { $0.id == f.id })
        else { return nil }
        let esElMismo = guardado.selectedCategories == f.selectedCategories
            && guardado.selectedPaymentMethods == f.selectedPaymentMethods
            && guardado.minAmount == f.minAmount
            && guardado.maxAmount == f.maxAmount
            && guardado.showOnlyRecurring == f.showOnlyRecurring
        return esElMismo ? nombre : nil
    }

    var calculatedSavings: Double {
        let periodExpenses = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let savingsAllocated = currentMonthlyBudget?.savingsAllocated ?? 0
        return monthlyIncome - periodExpenses - savingsAllocated
    }

    /// Income for the currently selected month (from MonthlyBudget).
    /// totalIncome = nómina + ingresos extra del mes. Internal (no private):
    /// HomeView lo usa para el % de ahorro — antes leía el income RAÍZ del
    /// userDocument y podía discrepar del importe calculado aquí.
    var monthlyIncome: Double {
        return currentMonthlyBudget?.totalIncome ?? income
    }

    /// Income del mes ANTERIOR al seleccionado (para cálculo de ahorros)
    /// La nómina de diciembre se usa para pagar gastos de enero
    private var previousMonthIncome: Double {
        // Si tenemos el budget del mes anterior cargado, usarlo
        if let previousBudget = previousMonthlyBudget {
            return previousBudget.totalIncome
        }

        // Fallback: usar el mismo income del mes actual
        // (asumiendo que la nómina es estable)
        return currentMonthlyBudget?.totalIncome ?? income
    }

    /// Load MonthlyBudget from Firebase for a specific month
    private func loadMonthlyBudget(for date: Date) async {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        do {
            currentMonthlyBudget = try await financialService.fetchMonthlyBudget(
                year: year,
                month: month
            )

            if currentMonthlyBudget == nil {
                // Only auto-create for the actual current month (not historical months)
                let calendar2 = Calendar.current
                let realYear = calendar2.component(.year, from: Date())
                let realMonth = calendar2.component(.month, from: Date())
                if year == realYear && month == realMonth {
                    await autoCreateBudgetIfFixedSalary(year: year, month: month)
                }
            }
        } catch {
            logger.error("❌ Error loading budget for \(month)/\(year): \(error.localizedDescription)")
            currentMonthlyBudget = nil
        }

        // Cargar también el budget del mes ANTERIOR para cálculo de ahorros
        guard let previousDate = calendar.date(byAdding: .month, value: -1, to: date) else {
            return
        }

        let previousYear = calendar.component(.year, from: previousDate)
        let previousMonth = calendar.component(.month, from: previousDate)

        do {
            previousMonthlyBudget = try await financialService.fetchMonthlyBudget(
                year: previousYear,
                month: previousMonth
            )

        } catch {
            logger.error("❌ Error loading previous month budget: \(error.localizedDescription)")
            previousMonthlyBudget = nil
        }
    }

    /// Auto-creates the monthly budget if the user has a fixed recurring salary configured.
    /// Uses the cached UserDocument from UserDataManager (no extra auth import needed).
    /// FinancialService handles auth internally.
    private func autoCreateBudgetIfFixedSalary(year: Int, month: Int) async {
        let doc = UserDataManager.shared.userDocument
        guard let fixedIncome = doc?.income,
            fixedIncome > 0,
            doc?.settings?.isSalaryRecurring == true
        else { return }

        logger.info(
            "🔄 Nómina fija (€\(fixedIncome)). Creando presupuesto \(month)/\(year) automáticamente..."
        )
        // userId is resolved by FinancialService internally from FirebaseAuth
        let budget = MonthlyBudget(
            userId: "",  // overridden by saveMonthlyBudget
            year: year,
            month: month,
            income: fixedIncome
        )
        do {
            try await financialService.saveMonthlyBudget(budget)
            currentMonthlyBudget = budget
            logger.info("✅ Presupuesto de nómina fija creado: €\(fixedIncome)")
        } catch {
            logger.error("❌ Error auto-creating fixed salary budget: \(error.localizedDescription)")
        }
    }

    // Internal
    private let getExpensesUseCase: GetExpensesUseCase
    private let deleteExpenseUseCase: DeleteExpenseUseCase
    private let addExpenseUseCase: AddExpenseUseCase
    private let recurringRepository = DependencyContainer.shared.recurringExpenseRepository
    // El del contenedor, como los repositorios: así el modo demo (DEBUG) le
    // pone el suyo en memoria. Sin estado propio: da igual una instancia u otra.
    private let financialService = DependencyContainer.shared.financialService
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "HomeViewModel")

    // Cached formatters (DateFormatter is expensive to create)
    private let filterDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let monthDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    // Exposed for View Logic (loading check)
    var allExpenses: [Expense] = []
    /// All historical expenses (from cache, not paginated). Used by MonthComparison, Charts.
    private(set) var allHistoricalExpenses: [Expense] = [] {
        didSet {
            _monthlyTotalsByKey = nil  // invalidar memo
            invalidarDerivados()
        }
    }

    /// Memo: gasto total agregado por "YYYY-MM". Se reconstruye cuando cambia
    /// `allHistoricalExpenses`. Evita filter+reduce O(N·M) por render del calendar.
    @ObservationIgnored private var _monthlyTotalsByKey: [String: Double]?

    private func monthlyTotalsByKey() -> [String: Double] {
        if let cached = _monthlyTotalsByKey { return cached }
        var dict: [String: Double] = [:]
        dict.reserveCapacity(64)
        for e in allHistoricalExpenses {
            let key = String(e.date.prefix(7))  // "YYYY-MM"
            dict[key, default: 0] += e.amount
        }
        _monthlyTotalsByKey = dict
        return dict
    }

    /// Serie de los últimos N meses desde `selectedMonth` (inclusive),
    /// usando el dict memoizado (O(N) consulta vs O(N·M) anterior).
    func monthlyEvolution(months: Int) -> [MonthlySpending] {
        let totals = monthlyTotalsByKey()
        let cal = Calendar.current
        var out: [MonthlySpending] = []
        out.reserveCapacity(months)
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let d = cal.date(byAdding: .month, value: -offset, to: selectedMonth) else { continue }
            let key = String(Formatters.localDayString(from: d).prefix(7))
            let label = cal.shortMonthSymbols[cal.component(.month, from: d) - 1].capitalized
            out.append(MonthlySpending(key: key, label: label, total: totals[key] ?? 0))
        }
        return out
    }
    var allRecurringRules: [RecurringExpense] = [] {  // Keep them for reference
        didSet { invalidarDerivados() }
    }

    // MARK: - Home nueva (#65)

    /// Límites y huchas. Se cargan aparte porque viven en otra colección.
    private(set) var metas: [Goal] = [] {
        didSet { invalidarDerivados() }
    }

    func loadMetas() async {
        metas = (try? await financialService.fetchGoals()) ?? []
    }

    /// El mes anterior, cargado de red igual que el actual. Sin esto la
    /// comparativa dependía del histórico de caché y en un dispositivo con la
    /// caché vacía no salía nunca.
    private(set) var gastosMesAnteriorCargados: [Expense] = [] {
        didSet { invalidarDerivados() }
    }

    /// Mientras llegan de red los gastos de un mes que no estaba en memoria. En
    /// ese rato la Home no cambia al cartel de "aún no has apuntado nada".
    private(set) var cargandoMes = false

    /// Gastos de cada mes ya traído, por "yyyy-MM".
    @ObservationIgnored private var mesesEnMemoria: [String: [Expense]] = [:]

    // MARK: Tu normal

    /// Cuántos meses hacia atrás forman la costumbre del usuario.
    static let mesesNormal = 6

    // MARK: Disposición de la Home (2.4.0)

    /// Qué tarjetas lleva la Home, en qué orden y de qué tamaño. Solo cambia
    /// por los métodos de abajo, que la sellan y la guardan.
    private(set) var disposicion: HomeDisposicion = .porDefecto {
        didSet { if disposicion != oldValue { invalidarDerivados() } }
    }
    private let almacenDisposicion: HomeDisposicionAlmacen
    /// La hora con la que se sellan los cambios. Los tests la fijan.
    @ObservationIgnored var reloj: () -> Date = { Date() }
    /// Cuánto se espera antes de subir a la cuenta: varios cambios seguidos
    /// (quitar dos tarjetas, cambiar un tamaño) son una sola escritura.
    @ObservationIgnored var esperaSubida: Duration = .seconds(1)
    /// La subida pendiente, para que los tests puedan esperarla.
    @ObservationIgnored private(set) var subidaPendiente: Task<Void, Never>?

    func ordenarTarjetas(_ ids: [String]) { cambiarDisposicion { $0.ordenar(ids) } }
    func quitarTarjeta(_ id: String) { cambiarDisposicion { $0.quitar(id) } }
    func cambiarTamano(_ id: String, a tamano: HomeDisposicion.Tamano) {
        cambiarDisposicion { $0.cambiarTamano(id, a: tamano) }
    }
    /// Un puesto antes o después, para VoiceOver.
    func moverTarjeta(_ id: String, puestos: Int) { cambiarDisposicion { $0.mover(id, puestos: puestos) } }
    func anadirTarjeta(_ tipo: HomeDisposicion.Tipo, tamano: HomeDisposicion.Tamano) {
        cambiarDisposicion { $0.anadir(tipo, tamano: tamano) != nil }
    }
    func noEnsenarEnPila(_ clase: String) { cambiarDisposicion { $0.noEnsenarEnPila(clase) } }
    func devolverAPila(_ clase: String) { cambiarDisposicion { $0.devolverAPila(clase) } }
    func restablecerDisposicion() { cambiarDisposicion { $0.restablecer() } }

    /// Un cambio del usuario: con su hora, a la copia del iPhone al momento y
    /// a la cuenta al poco. `cambio` dice si cambió algo; si no, ni se sella.
    private func cambiarDisposicion(_ cambio: (inout HomeDisposicion) -> Bool) {
        var nueva = disposicion
        guard cambio(&nueva) else { return }
        nueva.actualizada = reloj()
        disposicion = nueva
        almacenDisposicion.guardarLocal(nueva)
        programarSubida()
    }

    /// Con el documento de la cuenta ya leído, gana la más reciente. Si es la
    /// del iPhone (se editó sin cobertura, o la subida no llegó), se sube.
    /// Se llama al montar la Home y cada vez que llega el documento.
    func sincronizarDisposicion() {
        guard almacenDisposicion.documentoCargado() else { return }
        let (ganadora, subirLocal) = HomeDisposicion.masReciente(local: disposicion, remota: almacenDisposicion.remota())
        if ganadora != disposicion {
            disposicion = ganadora
            almacenDisposicion.guardarLocal(ganadora)
        }
        if subirLocal { programarSubida() }
    }

    private func programarSubida() {
        subidaPendiente?.cancel()
        let espera = esperaSubida
        subidaPendiente = Task { [weak self] in
            if espera > .zero { try? await Task.sleep(for: espera) }
            guard let self, !Task.isCancelled else { return }
            await self.almacenDisposicion.subir(self.disposicion)
        }
    }

    /// Todas las tarjetas de la disposición con lo que enseña cada una este
    /// mes: la rejilla de edición las pinta todas.
    var tarjetasHome: [HomeDisposicion.Tarjeta] { derivados.tarjetas }

    /// Las que se pintan fuera de edición, en filas.
    var filasHome: [[HomeDisposicion.Tarjeta]] { derivados.filas }

    /// Los meses anteriores al que se enseña, traídos de red una vez por mes
    /// visitado, para medir el mes contra la costumbre del usuario y no contra
    /// el mes pasado a secas.
    private(set) var historicoNormal: [Expense] = [] {
        didSet { invalidarDerivados() }
    }
    /// Ingresos de esos meses, por "yyyy-MM": para el ahorro medio.
    private(set) var presupuestosNormal: [String: Double] = [:] {
        didSet { invalidarDerivados() }
    }
    @ObservationIgnored private var mesNormalCargado: String?

    /// Trae el tramo de "tu normal" del mes que se enseña. Mientras no llega,
    /// los derivados tiran del histórico en caché, que suele bastar.
    func loadNormal() async {
        let cal = Calendar.current
        let clave = Self.monthKey(selectedMonth)
        guard mesNormalCargado != clave,
              let inicioMes = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth)),
              let desde = cal.date(byAdding: .month, value: -Self.mesesNormal, to: inicioMes),
              let hasta = cal.date(byAdding: .day, value: -1, to: inicioMes)
        else { return }
        var filtro = ExpenseFilter()
        filtro.dateRange = .custom
        filtro.customStartDate = desde
        filtro.customEndDate = hasta
        let resultado = try? await getExpensesUseCase.executePaginated(page: 0, filter: filtro)

        var presupuestos: [String: Double] = [:]
        for atras in 1...Self.mesesNormal {
            guard let mes = cal.date(byAdding: .month, value: -atras, to: inicioMes) else { continue }
            let presupuesto = try? await financialService.fetchMonthlyBudget(
                year: cal.component(.year, from: mes), month: cal.component(.month, from: mes))
            if let ingresos = presupuesto?.totalIncome, ingresos > 0 { presupuestos[Self.monthKey(mes)] = ingresos }
        }

        // Si mientras llegaba se cambió de mes, este ya no es su tramo.
        guard Self.monthKey(selectedMonth) == clave, let resultado else { return }
        let gastos = ExpenseSanitizer.sanitize(expenses: resultado.expenses, rules: allRecurringRules)
        // Cada mes traído queda en memoria: cambiar a él es instantáneo.
        for (mes, delMes) in Dictionary(grouping: gastos, by: { String($0.date.prefix(7)) }) {
            mesesEnMemoria[mes] = delMes
        }
        historicoNormal = gastos
        presupuestosNormal = presupuestos
        mesNormalCargado = clave
    }

    // MARK: Derivados

    /// Sube con cada cambio en lo que alimenta la Home, y las vistas dependen de
    /// esto. Antes `resumen` y compañía eran computadas: cada pintado recorría
    /// los gastos varias veces y parseaba la fecha de todo el histórico, y eso
    /// era buena parte del tirón al deslizar y al cambiar de mes.
    private(set) var revisionDerivados = 0
    @ObservationIgnored private var cacheDerivados: (revision: Int, valor: HomeDerivados)?

    private func invalidarDerivados() { revisionDerivados &+= 1 }

    private var derivados: HomeDerivados {
        let revision = revisionDerivados
        if let cache = cacheDerivados, cache.revision == revision { return cache.valor }
        let valor = calcularDerivados()
        cacheDerivados = (revision, valor)
        return valor
    }

    /// Gastos del mes que se enseña, sin filtros.
    ///
    /// La fuente principal es `currentMonthExpenses`, que llega de red en cada
    /// carga. El histórico completo solo está si la caché local lo tenía —en un
    /// dispositivo con la caché vacía se queda en cero— y la primera versión de
    /// esta pantalla tiraba de él: por eso no enseñaba nada. Queda como respaldo
    /// para meses distintos del cargado.
    var gastosDelMes: [Expense] { derivados.gastosDelMes }

    var gastosMesAnterior: [Expense] { derivados.gastosMesAnterior }

    /// Todo lo que pinta la primera página, resuelto por `HomeResumen`.
    var resumen: HomeResumen { derivados.resumen }

    /// Los tres últimos del mes, el más reciente primero.
    var ultimosGastos: [Expense] { derivados.ultimosGastos }

    /// Importe por día del mes, con ceros en los días sin gasto.
    var gastosPorDia: [(dia: Int, importe: Double)] { derivados.gastosPorDia }

    /// Actual frente a anterior por categoría, las cuatro que más pesan este mes.
    var comparativaPorCategoria: [(categoria: String, actual: Double, anterior: Double)] {
        derivados.comparativaPorCategoria
    }

    /// Totales por semana del mes, con su etiqueta "1–7".
    var semanasDelMes: [(etiqueta: String, importe: Double)] { derivados.semanasDelMes }

    /// Las categorías del mes entero, sin el filtro de la lista. Resumen y
    /// Gráficas cuentan sobre el total del mes; si sus categorías salieran
    /// filtradas, los porcentajes dejarían de sumar y faltarían categorías
    /// —con el filtro Favs activo desaparecía Vivienda, la de 650 €—.
    /// El filtro sigue aplicando a la lista de gastos.
    var gruposDelMes: [CategoryGroup] { derivados.gruposDelMes }

    /// "agosto", para los textos de la comparativa.
    var nombreMesAnterior: String {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return "el mes pasado" }
        return Formatters.fullMonthName(Calendar.current.component(.month, from: prev)).lowercased()
    }

    // MARK: Cierre del mes anterior

    /// Meses ya celebrados, por "yyyy-MM". Observado: al marcar uno, la tarjeta
    /// de enhorabuena desaparece.
    private(set) var cierresCelebrados: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "celebrados.cierreMes") ?? [])

    /// Si el mes anterior se cerró dentro del presupuesto y aún no se ha
    /// celebrado: su nombre y lo que sobró. Solo mirando el mes actual.
    var cierreDeMesPendiente: (mes: String, sobrante: Double)? {
        let cal = Calendar.current
        guard cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month),
              let anterior = cal.date(byAdding: .month, value: -1, to: selectedMonth)
        else { return nil }
        let clave = Self.monthKey(anterior)
        // Por fecha: si los cargados son de otro mes, suman cero y no se celebra.
        let total = gastosMesAnteriorCargados
            .filter { $0.date.hasPrefix(clave) }
            .reduce(0) { $0 + $1.amount }
        guard let sobrante = CierreDeMes.sobrante(
            hoy: Date(),
            totalAnterior: total,
            presupuestoAnterior: previousMonthlyBudget?.totalIncome,
            yaCelebrado: cierresCelebrados.contains(clave),
            calendar: cal
        ) else { return nil }
        return (nombreMesAnterior, sobrante)
    }

    func marcarCierreCelebrado() {
        guard let anterior = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return }
        cierresCelebrados.insert(Self.monthKey(anterior))
        UserDefaults.standard.set(Array(cierresCelebrados), forKey: "celebrados.cierreMes")
    }

    /// Al abrir la app el presupuesto del mes anterior puede no estar aún: se
    /// pide solo cuando podría tocar celebrar —primera semana, sin celebrar—.
    func comprobarCierreDeMes() async {
        let cal = Calendar.current
        guard cal.component(.day, from: Date()) <= CierreDeMes.diasParaCelebrar,
              previousMonthlyBudget == nil,
              let anterior = cal.date(byAdding: .month, value: -1, to: Date()),
              !cierresCelebrados.contains(Self.monthKey(anterior))
        else { return }
        let presupuesto = try? await financialService.fetchMonthlyBudget(
            year: cal.component(.year, from: anterior),
            month: cal.component(.month, from: anterior)
        )
        // Si mientras llegaba se cambió de mes, ese ya no es el anterior.
        guard cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month),
              previousMonthlyBudget == nil, let presupuesto
        else { return }
        previousMonthlyBudget = presupuesto
    }

    func loadMesAnterior() async {
        let cal = Calendar.current
        guard let prev = cal.date(byAdding: .month, value: -1, to: selectedMonth),
              let start = cal.date(from: cal.dateComponents([.year, .month], from: prev)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return }
        var filtro = ExpenseFilter()
        filtro.dateRange = .custom
        filtro.customStartDate = start
        filtro.customEndDate = end
        let resultado = try? await getExpensesUseCase.executePaginated(page: 0, filter: filtro)
        let gastos = ExpenseSanitizer.sanitize(expenses: resultado?.expenses ?? [], rules: allRecurringRules)
        // Queda en memoria: ir al mes anterior es lo más habitual y ya está aquí.
        if resultado != nil { mesesEnMemoria[Self.monthKey(prev)] = gastos }
        gastosMesAnteriorCargados = gastos
    }

    /// El filtro puesto, como condición sobre un gasto. `nil` sin filtros. Las
    /// categorías se comparan igual que en la lista: por la primera palabra, sin
    /// tildes ni mayúsculas.
    private func criterioDeFiltro() -> ((Expense) -> Bool)? {
        guard filtroActivo else { return nil }
        let f = selectedFilter
        let categorias = Set(f.selectedCategories.map(Self.primeraPalabra))
        return { gasto in
            if !categorias.isEmpty, !categorias.contains(Self.primeraPalabra(gasto.category)) { return false }
            if !f.selectedPaymentMethods.isEmpty, !f.selectedPaymentMethods.contains(gasto.paymentMethod) { return false }
            if let minimo = f.minAmount, gasto.amount < minimo { return false }
            if let maximo = f.maxAmount, gasto.amount > maximo { return false }
            if f.showOnlyRecurring, !(gasto.isRecurring ?? gasto.recurring ?? false) { return false }
            return true
        }
    }

    nonisolated private static func primeraPalabra(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " / ", with: " ")
            .replacingOccurrences(of: " - ", with: " ")
            .components(separatedBy: " ").first ?? ""
    }

    @ObservationIgnored private var cacheEvolucion: (revision: Int, meses: Int, valor: [MonthlySpending])?

    /// Los últimos `meses` meses hasta el que se enseña. Con filtros suma solo lo
    /// que los pasa, igual que el resto de Gráficas.
    func evolucion(meses: Int) -> [MonthlySpending] {
        let revision = revisionDerivados
        if let cache = cacheEvolucion, cache.revision == revision, cache.meses == meses { return cache.valor }
        let valor: [MonthlySpending]
        if let criterio = criterioDeFiltro() {
            var totales: [String: Double] = [:]
            for gasto in allHistoricalExpenses where criterio(gasto) {
                totales[String(gasto.date.prefix(7)), default: 0] += gasto.amount
            }
            let cal = Calendar.current
            valor = stride(from: meses - 1, through: 0, by: -1).compactMap { offset in
                guard let d = cal.date(byAdding: .month, value: -offset, to: selectedMonth) else { return nil }
                let key = String(Formatters.localDayString(from: d).prefix(7))
                let label = cal.shortMonthSymbols[cal.component(.month, from: d) - 1].capitalized
                return MonthlySpending(key: key, label: label, total: totales[key] ?? 0)
            }
        } else {
            valor = monthlyEvolution(months: meses)
        }
        cacheEvolucion = (revision, meses, valor)
        return valor
    }

    private func calcularDerivados() -> HomeDerivados {
        let cal = Calendar.current
        let clave = Self.monthKey(selectedMonth)

        let cargados = currentMonthExpenses.filter { $0.date.hasPrefix(clave) }
        let gastos = cargados.isEmpty ? allHistoricalExpenses.filter { $0.date.hasPrefix(clave) } : cargados

        let anteriores: [Expense] = {
            guard let prev = cal.date(byAdding: .month, value: -1, to: selectedMonth) else { return [] }
            let k = Self.monthKey(prev)
            let delAnterior = gastosMesAnteriorCargados.filter { $0.date.hasPrefix(k) }
            if !delAnterior.isEmpty { return delAnterior }
            if let enMemoria = mesesEnMemoria[k], !enMemoria.isEmpty { return enMemoria }
            return allHistoricalExpenses.filter { $0.date.hasPrefix(k) }
        }()

        // En un mes pasado no quedan días: el "hoy" del cálculo es su último día.
        let hoy: Date = {
            if cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) { return Date() }
            guard let range = cal.range(of: .day, in: .month, for: selectedMonth),
                  let start = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth))
            else { return selectedMonth }
            return cal.date(byAdding: .day, value: range.count - 1, to: start) ?? selectedMonth
        }()

        // Las fechas son "yyyy-MM-dd": la menor como texto es la primera, sin
        // parsear el histórico entero.
        let primerGasto = allHistoricalExpenses.lazy
            .map(\.date)
            .filter { $0.count >= 10 }
            .min()
            .flatMap { Formatters.date(from: String($0.prefix(10))) }

        // Con filtros, lo que se analiza —las tarjetas de en qué se gasta, los
        // últimos y las gráficas— es lo que los pasa. Total, presupuesto y
        // límites siguen siendo del mes entero: se miden contra todo.
        let criterio = criterioDeFiltro()
        let analisis = criterio.map { gastos.filter($0) } ?? gastos
        let anterioresAnalisis = criterio.map { anteriores.filter($0) } ?? anteriores

        // Tu normal: del tramo traído de red o, hasta que llegue, del
        // histórico en caché.
        let normal = HomeNormal.build(
            historico: historicoNormal.isEmpty ? allHistoricalExpenses : historicoNormal,
            mes: selectedMonth,
            meses: Self.mesesNormal,
            presupuestos: presupuestosNormal,
            calendar: cal
        )

        let resumen = HomeResumen.build(
            gastos: gastos,
            gastosMesAnterior: anteriores,
            metas: metas,
            recurrentes: allRecurringRules,
            presupuesto: monthlyIncome > 0 ? monthlyIncome : nil,
            primerGasto: primerGasto,
            hoy: hoy,
            calendar: cal,
            normal: normal,
            filtro: criterio
        )

        let ultimos = Array(analisis.sorted {
            ($0.date, $0.createdAt ?? .distantPast) > ($1.date, $1.createdAt ?? .distantPast)
        }.prefix(3))

        // Día sacado del propio texto de la fecha: sin un DateFormatter por gasto.
        let diasMes = cal.range(of: .day, in: .month, for: selectedMonth)?.count ?? 30
        var importes = [Double](repeating: 0, count: diasMes + 1)
        for g in analisis {
            if let d = Int(g.date.dropFirst(8).prefix(2)), d >= 1, d <= diasMes { importes[d] += g.amount }
        }
        let porDia = (1...diasMes).map { (dia: $0, importe: importes[$0]) }

        // Mismo tramo del mes anterior, igual que la comparativa del resumen.
        let actualPorCategoria = Dictionary(grouping: analisis, by: \.category).mapValues { $0.reduce(0) { $0 + $1.amount } }
        let hastaDia = resumen.comparativaAnalisis?.hastaDia ?? resumen.comparativa?.hastaDia ?? 31
        let tramo = HomeResumen.mismoTramo(anterioresAnalisis, hastaDia: hastaDia, calendar: cal)
        let anteriorPorCategoria = Dictionary(grouping: tramo, by: \.category).mapValues { $0.reduce(0) { $0 + $1.amount } }
        let comparativa = actualPorCategoria.sorted { $0.value > $1.value }.prefix(4)
            .map { (categoria: $0.key, actual: $0.value, anterior: anteriorPorCategoria[$0.key] ?? 0) }

        // Semanas contadas desde el día 1 del mes. `date(bySetting:of:)` busca la
        // siguiente fecha con ese día, y para los días anteriores al de
        // `selectedMonth` saltaba al mes siguiente.
        var semanas: [Int: (desde: Int, hasta: Int, importe: Double)] = [:]
        if let inicioMes = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth)) {
            for (dia, importe) in porDia {
                guard let fecha = cal.date(byAdding: .day, value: dia - 1, to: inicioMes) else { continue }
                let w = cal.component(.weekOfMonth, from: fecha)
                let prev = semanas[w] ?? (dia, dia, 0)
                semanas[w] = (min(prev.desde, dia), max(prev.hasta, dia), prev.importe + importe)
            }
        }
        let semanasDelMes = semanas.keys.sorted().compactMap { semanas[$0] }
            .map { (etiqueta: "\($0.desde)–\($0.hasta)", importe: $0.importe) }

        // Qué enseña cada tarjeta de la Home, y en qué filas van las que salen.
        let tarjetas = disposicion.tarjetas(relevancias: resumen.relevancias, hayUltimos: !ultimos.isEmpty)
        let filas = HomeDisposicion.filas(tarjetas.filter(\.conDatos), tamano: \.tamano)

        return HomeDerivados(
            gastosDelMes: gastos,
            gastosMesAnterior: anteriores,
            resumen: resumen,
            gruposDelMes: agrupar(analisis),
            ultimosGastos: ultimos,
            gastosPorDia: porDia,
            comparativaPorCategoria: Array(comparativa),
            semanasDelMes: semanasDelMes,
            tarjetas: tarjetas,
            filas: filas
        )
    }

    private static func monthKey(_ date: Date) -> String {
        String(Formatters.localDayString(from: date).prefix(7))
    }

    // Pagination
    var currentPage = 0
    var hasMorePages = true
    var isLoadingMore = false

    init(
        getExpensesUseCase: GetExpensesUseCase,
        deleteExpenseUseCase: DeleteExpenseUseCase,
        addExpenseUseCase: AddExpenseUseCase,
        /// `nil` = el de la app. Los tests pasan uno en memoria.
        almacenDisposicion: HomeDisposicionAlmacen? = nil
    ) {
        self.getExpensesUseCase = getExpensesUseCase
        self.deleteExpenseUseCase = deleteExpenseUseCase
        self.addExpenseUseCase = addExpenseUseCase
        let almacenDisposicion = almacenDisposicion ?? .app
        self.almacenDisposicion = almacenDisposicion
        // La del iPhone, para arrancar ya con la Home del usuario; la de la
        // cuenta se mira al llegar el documento (`sincronizarDisposicion`).
        self.disposicion = almacenDisposicion.cargarLocal()

        // Load income
        self.income = UserDataManager.shared.userDocument?.income ?? 0

        // ✅ FIX: Force "This Month" filter by default to prevent summing ALL history
        if let savedDefault = UserDataManager.shared.defaultFilter {
            self.selectedFilter = savedDefault
        } else {
            self.selectedFilter = ExpenseFilter(dateRange: .thisMonth)
        }
    }

    // MARK: - Intents

    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else { return }
        do {
            try await deleteExpenseUseCase.execute(id: id)

            // Rollback linked piggy bank if this expense was a savings contribution
            if let goalId = expense.goalId {
                let comps = Calendar.current.dateComponents([.year, .month], from: expense.dateAsDate)
                if let year = comps.year, let month = comps.month {
                    try? await financialService.refundPiggyBank(goalId: goalId, amount: expense.amount)
                    try? await financialService.updateSavingsAllocated(year: year, month: month, amount: -expense.amount)
                }
            }

            mesesEnMemoria.removeValue(forKey: String(expense.date.prefix(7)))
            // `loadExpenses` ya actualiza el widget: repetirlo aquí gastaba dos
            // recargas de WidgetKit por cada borrado.
            await loadExpenses()
            // Avisar a otras VMs (FinancialHub escudos/metas) para refresh inmediato
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            FeedbackManager.shared.show(
                .success, title: "Gasto eliminado",
                message: "\(expense.name) se ha borrado correctamente")
        } catch {
            state = .error(.deletionFailed(error.localizedDescription))
            FeedbackManager.shared.show(
                .error, title: "Error al borrar", message: error.localizedDescription)
        }
    }

    // Flag to track if we've attempted to apply the default filter
    private var hasAppliedDefaultFilter = false

    /// Called from .task — skips if data already loaded to avoid re-fetching on tab switch.
    /// Use refresh() or loadExpenses() directly for forced reloads.
    /// Aplica el filtro predeterminado, si lo hay y no se ha aplicado ya.
    ///
    /// Ojo con el caso "todavía no lo sé": si el documento del usuario aún no ha
    /// llegado, no hay filtro que leer, pero tampoco se puede concluir que no
    /// exista. Darlo por resuelto ahí es lo que hacía que el filtro se perdiera
    /// en cada arranque desde que la interfaz dejó de esperar a la carga (#32).
    func applyDefaultFilterIfNeeded() {
        guard !hasAppliedDefaultFilter else { return }

        if let defaultFilter = UserDataManager.shared.defaultFilter {
            logger.debug("🏠 ✅ Applying Default Filter: '\(defaultFilter.name ?? "Unnamed")'")
            self.selectedFilter = defaultFilter
            self.hasAppliedDefaultFilter = true
            applyFilters()
        } else if UserDataManager.shared.userDocument != nil {
            // Documento cargado y sin filtro predeterminado: no hay nada que
            // aplicar y no hace falta volver a mirar.
            logger.debug("🏠 ⚠️ No default filter found, using 'Este mes'")
            self.hasAppliedDefaultFilter = true
        }
        // Sin documento todavía: se deja pendiente y se reintenta cuando llegue.
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await loadExpenses()
    }

    func loadExpenses(silent: Bool = false) async {

        // ✅ ESPERAR a que UserDataManager termine de cargar ANTES de continuar
        if !UserDataManager.shared.hasLoaded {
            logger.info("⏳ Waiting for UserDataManager to load...")
            await UserDataManager.shared.loadUserData()
            logger.info("✅ UserDataManager loaded!")
        }

        // Refresh income
        self.income = UserDataManager.shared.userDocument?.income ?? 0

        applyDefaultFilterIfNeeded()

        if !silent && allExpenses.isEmpty {
            state = .loading
        }

        currentPage = 0
        hasMorePages = true

        // El mes que se pide. Si mientras llega se cambia de mes, esta respuesta
        // ya no manda: la del mes nuevo está en camino y pisarla enseñaría el
        // mes equivocado.
        let mesPedido = selectedMonth
        func sigueSiendoElMes() -> Bool {
            Calendar.current.isDate(selectedMonth, equalTo: mesPedido, toGranularity: .month)
        }

        do {
            // Load budget for the SELECTED month (not necessarily current month)
            let calendar = Calendar.current
            let selectedYear = calendar.component(.year, from: mesPedido)
            let selectedMonthNum = calendar.component(.month, from: mesPedido)

            do {
                let presupuesto = try await financialService.fetchMonthlyBudget(
                    year: selectedYear, month: selectedMonthNum)
                if sigueSiendoElMes() { self.currentMonthlyBudget = presupuesto }
            } catch {
                logger.warning("⚠️ Failed to load monthly budget: \(error)")
            }

            // Build a date-only filter for the selected month (no category/payment filters)
            // This is used ONLY to calculate real savings — unaffected by user filters
            let calendar2 = Calendar.current
            let monthComponents = calendar2.dateComponents([.year, .month], from: mesPedido)
            let monthStart = calendar2.date(from: monthComponents) ?? mesPedido
            let monthEnd =
                calendar2.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
                ?? mesPedido
            let monthOnlyFilter = ExpenseFilter(
                dateRange: .custom,
                customStartDate: monthStart,
                customEndDate: monthEnd
            )

            // Launch month-savings and rules fetches in parallel
            async let monthExpensesTask = getExpensesUseCase.executePaginated(
                page: 0, filter: monthOnlyFilter)
            async let rulesTask = recurringRepository.fetchAll()

            // For display:
            // • Searching → use local SwiftData cache (ALL expenses, no Firebase pagination limit)
            //   so annual/old expenses are always findable regardless of month.
            // • Browsing → paginated Firebase fetch with the selected date filter.
            let displayExpenses: [Expense]
            let morePages: Bool
            if !searchText.isEmpty {
                displayExpenses = (try? await getExpensesUseCase.execute()) ?? []
                morePages = false
            } else {
                let result = try await getExpensesUseCase.executePaginated(
                    page: 0, filter: selectedFilter)
                displayExpenses = result.expenses
                morePages = result.hasMore
            }

            let monthResult = try await monthExpensesTask
            let rules = (try? await rulesTask) ?? []

            let sanitized = ExpenseSanitizer.sanitize(expenses: displayExpenses, rules: rules)
            let sanitizedMonth = ExpenseSanitizer.sanitize(
                expenses: monthResult.expenses, rules: rules)

            // En memoria aunque ya se haya cambiado de mes: volver será instantáneo.
            mesesEnMemoria[Self.monthKey(mesPedido)] = sanitizedMonth
            guard sigueSiendoElMes() else { return }

            self.allRecurringRules = rules
            self.allExpenses = sanitized
            self.currentMonthExpenses = sanitizedMonth
            self.hasMorePages = morePages

            // Solo cargar historial completo si está vacío (no en cada keystroke
            // de búsqueda / cada delete). Decodificar cientos de records en
            // @MainActor bloqueaba el hilo en cada loadExpenses.
            if allHistoricalExpenses.isEmpty,
               let allCached = try? await getExpensesUseCase.execute(policy: .cacheFirst()) {
                self.allHistoricalExpenses = ExpenseSanitizer.sanitize(expenses: allCached, rules: rules)
            }

            applyFilters()
            hasLoaded = true

            // ── Widget update ──
            WidgetDataManager.shared.updateFromExpenses(
                sanitizedMonth,
                monthBudget: currentMonthlyBudget?.totalIncome
            )
        } catch {
            logger.error("❌ Error loading expenses: \(error)")
            if !silent {
                state = .error(.dataLoadingFailed(error.localizedDescription))
            }
        }
    }

    func loadMore() async {
        guard hasMorePages, !isLoadingMore else { return }
        isLoadingMore = true

        do {
            currentPage += 1
            let result = try await getExpensesUseCase.executePaginated(
                page: currentPage, filter: selectedFilter)

            self.allExpenses.append(contentsOf: result.expenses)
            self.allExpenses = deduplicate(expenses: self.allExpenses)
            self.hasMorePages = result.hasMore

            applyFilters()  // Re-apply filters to new full set
        } catch {
            // Silently fail or show toast? For infinite scroll, usually silent or small indicator
            logger.error("Error loading more: \(error)")
            currentPage -= 1  // Revert page logic
        }

        isLoadingMore = false
    }

    func refresh() async {
        await loadExpenses(silent: true)
        // Recarga el budget del mes → el ahorro refleja nómina + ingresos extra al día
        // (antes solo recargaba gastos; añadir un ingreso extra no actualizaba el ahorro).
        await loadMonthlyBudget(for: selectedMonth)
    }

    /// Recarga SOLO el budget del mes (nómina + ingresos extra) → recalcula el ahorro.
    /// Se usa al recibir `.expenseDidChange` desde otras pantallas: NO recarga la lista
    /// de gastos (hacerlo re-entraba durante el borrado con swipe y crasheaba la List).
    func reloadBudget() async {
        await loadMonthlyBudget(for: selectedMonth)
    }

    /// Inserts an expense directly into in-memory state — no network roundtrip.
    /// Used by the voice flow after a successful save so the UI updates instantly.
    func prependExpense(_ expense: Expense) {
        allExpenses.insert(expense, at: 0)

        // Also add to current-month array if the expense belongs to this month
        let monthPrefix = String(format: "%04d-%02d",
                                 Calendar.current.component(.year, from: Date()),
                                 Calendar.current.component(.month, from: Date()))
        if expense.date.hasPrefix(monthPrefix) {
            currentMonthExpenses.insert(expense, at: 0)
        }
        // Lo guardado de ese mes ya no está completo: que se vuelva a pedir.
        mesesEnMemoria.removeValue(forKey: String(expense.date.prefix(7)))

        // Keep UserDataManager in sync so GoalCardView / FinancialDashboard see the new expense
        UserDataManager.shared.expenses.insert(expense, at: 0)

        applyFilters()

        // ── Widget update (inmediato, sin esperar red) ──
        WidgetDataManager.shared.updateFromExpenses(
            currentMonthExpenses,
            monthBudget: currentMonthlyBudget?.totalIncome
        )
    }

    /// Removes an expense from in-memory state (used by undo).
    func removeExpense(id: String) {
        allExpenses.removeAll { $0.id == id }
        currentMonthExpenses.removeAll { $0.id == id }
        mesesEnMemoria.removeAll()
        UserDataManager.shared.expenses.removeAll { $0.id == id }
        applyFilters()
        WidgetDataManager.shared.updateFromExpenses(
            currentMonthExpenses,
            monthBudget: currentMonthlyBudget?.totalIncome
        )
    }

    /// Duplicates an expense — saves to repository and refreshes state.
    func duplicateExpense(_ expense: Expense) async throws {
        let duplicated = Expense(
            amount: expense.amount,
            name: expense.name,
            category: expense.category,
            subcategory: expense.subcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: expense.paymentMethod,
            notes: expense.notes,
            isDeductible: expense.isDeductible
        )
        let id = try await addExpenseUseCase.execute(duplicated)
        var saved = duplicated
        saved.id = id
        prependExpense(saved)
    }

    // MARK: - Helpers

    /// Updates the filter to match the selected month (al cambiar `selectedMonth` y en `limpiarFiltros`)
    private func updateFilterForSelectedMonth() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)

        guard let startOfMonth = calendar.date(from: components),
            let endOfMonth = calendar.date(
                byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else {
            return
        }

        var newFilter = selectedFilter
        newFilter.dateRange = .custom
        newFilter.customStartDate = startOfMonth
        newFilter.customEndDate = endOfMonth
        selectedFilter = newFilter

        logger.debug(
            "📅 Month changed to: \(self.monthDateFormatter.string(from: self.selectedMonth))")
    }

    // monthDateFormatter is defined as a private let above

    private func applyFilters() {
        logger.debug("📋 Applying filters: \(self.selectedFilter.dateRange.rawValue)")
        // NOTE: currentMonthExpenses is populated in loadExpenses() with a month-only fetch.
        // We do NOT recompute it here to avoid overwriting with already-filtered allExpenses.

        // When searching we already fetched allTime data, so skip the date filter here.
        // Otherwise, filter by the selected date range.
        var result: [Expense]
        if !searchText.isEmpty {
            dateFilteredExpenses = allExpenses
            result = allExpenses
        } else {
            let (startStr, endStr) = selectedFilter.dateRangeForQuery()
            dateFilteredExpenses = allExpenses.filter { expense in
                expense.date >= startStr && expense.date <= endStr
            }
            result = dateFilteredExpenses
        }

        // Search
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.category.localizedCaseInsensitiveContains(searchText)
                    || ($0.subcategory?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Category Filter — pre-normaliza UNA vez las categorías del filtro
        // (antes recreaba la closure + normalizaba por cada par gasto×categoría).
        if !selectedFilter.selectedCategories.isEmpty {
            func firstWord(_ s: String) -> String {
                s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .replacingOccurrences(of: " / ", with: " ")
                    .replacingOccurrences(of: " - ", with: " ")
                    .components(separatedBy: " ").first ?? ""
            }
            let filterFirstWords = Set(selectedFilter.selectedCategories.map(firstWord))
            result = result.filter { filterFirstWords.contains(firstWord($0.category)) }
        }

        // Payment Method Filter
        if !selectedFilter.selectedPaymentMethods.isEmpty {
            result = result.filter { expense in
                selectedFilter.selectedPaymentMethods.contains(expense.paymentMethod)
            }
        }

        self.filteredExpenses = result

        // 4. Build Groups
        buildCategoryGroups(from: result)

        if result.isEmpty {
            state = .empty
        } else {
            state = .loaded(result)
        }
    }

    private func deduplicate(expenses: [Expense]) -> [Expense] {
        var seen = Set<String>()
        return expenses.filter { expense in
            guard let id = expense.id, !id.isEmpty else { return true }
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
    }

    private func buildCategoryGroups(from expenses: [Expense]) {
        self.categoryGroups = agrupar(expenses)
    }

    private func agrupar(_ expenses: [Expense]) -> [CategoryGroup] {
        var groups: [String: CategoryGroup] = [:]

        for expense in expenses {
            let categoryName = extractCategoryName(from: expense.category)
            let emoji = extractEmoji(from: expense.category)

            if groups[categoryName] == nil {
                groups[categoryName] = CategoryGroup(
                    name: categoryName,
                    emoji: emoji,
                    color: colorForCategory(categoryName),
                    totalAmount: 0,
                    expenseCount: 0,
                    subcategories: []
                )
            }

            groups[categoryName]?.totalAmount += expense.amount
            groups[categoryName]?.expenseCount += 1

            // Add to subcategory
            let subcategoryName = expense.subcategory ?? "Sin subcategoría"
            if let subIndex = groups[categoryName]?.subcategories.firstIndex(where: {
                $0.name == subcategoryName
            }) {
                groups[categoryName]?.subcategories[subIndex].totalAmount += expense.amount
                groups[categoryName]?.subcategories[subIndex].expenseCount += 1
                groups[categoryName]?.subcategories[subIndex].expenses.append(expense)
            } else {
                groups[categoryName]?.subcategories.append(
                    SubcategoryGroup(
                        name: subcategoryName,
                        totalAmount: expense.amount,
                        expenseCount: 1,
                        expenses: [expense]
                    )
                )
            }
        }

        return Array(groups.values).sorted {
            if $0.totalAmount == $1.totalAmount {
                return $0.name < $1.name
            }
            return $0.totalAmount > $1.totalAmount
        }
    }

    // MARK: - Helpers
    private func extractCategoryName(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.first ?? category
    }

    private func extractEmoji(from category: String) -> String {
        // Extract all emoji characters from the string (works with or without spaces)
        return category.filter { scalar in
            scalar.unicodeScalars.contains {
                $0.properties.isEmoji && $0.properties.isEmojiPresentation
            }
        }.map { String($0) }.joined()
    }

    private func colorForCategory(_ name: String) -> Color {
        UserDataManager.shared.color(for: name)
    }
}
