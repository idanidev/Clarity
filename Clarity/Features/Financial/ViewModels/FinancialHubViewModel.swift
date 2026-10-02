//
//  FinancialHubViewModel.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  Brain for Financial Hub: Month detection, state management, freeCash calculation
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
// SwiftUI removed — animations belong in the View layer

@MainActor
@Observable
class FinancialHubViewModel {
    // MARK: - State
    private(set) var currentBudget: MonthlyBudget?
    private(set) var goals: [Goal] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var error: String?

    // Monthly Setup Wizard
    var showMonthlySetup = false
    var previousMonthIncome: Double?

    // Salary Settings
    var isSalaryRecurring = false
    var showSalarySettings = false
    var showAddGoal = false
    var editingGoal: Goal? = nil

    /// La hucha que acaba de llegar a su objetivo con la última aportación.
    /// La vista enseña la enhorabuena mientras no sea nil y la limpia al cerrarla.
    var huchaCompletada: Goal? = nil

    // Services
    private let service: FinancialService
    private let getExpensesUseCase: GetExpensesUseCase
    private let recurringRepository: RecurringExpenseRepository

    // El deinit es nonisolated y necesita leerlo para dar de baja el observer.
    // El compilador sugiere quitar el (unsafe), pero sin él no compila: `nonisolated`
    // no se admite en propiedades almacenadas mutables.
    nonisolated(unsafe) private var expenseObserver: Any?

    init() {
        self.service = DependencyContainer.shared.financialService
        self.getExpensesUseCase = DependencyContainer.shared.makeGetExpensesUseCase()
        self.recurringRepository = DependencyContainer.shared.recurringExpenseRepository

        // Listen for expense changes even when the view isn't visible
        expenseObserver = NotificationCenter.default.addObserver(
            forName: .expenseDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.hasLoaded else { return }
                await self.refrescar()
            }
        }
    }

    deinit {
        if let observer = expenseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Computed Properties

    /// Current month/year based on device date
    var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    var currentMonthName: String {
        Formatters.fullMonthName(currentMonth)
    }

    /// The "Energy" available for spending — nómina del mes + ingresos extra.
    var income: Double {
        currentBudget?.totalIncome ?? 0
    }

    /// Nómina base del mes (sin extras) — para mostrar el desglose.
    var baseSalary: Double {
        currentBudget?.income ?? 0
    }

    /// Ingresos extra del mes en curso.
    var extraIncomes: [IncomeEntry] {
        currentBudget?.extraIncomes ?? []
    }

    /// Lo apartado en huchas este mes: lo que suman sus movimientos de ahorro
    /// (aportaciones, y retiradas en negativo). Como en la Home, de los
    /// movimientos y no de `savingsAllocated` del presupuesto, que se descuadra.
    var savingsAllocated: Double { apartadoDelMes }
    private(set) var apartadoDelMes: Double = 0

    /// Separated goal lists
    var spendingLimits: [Goal] {
        goals.filter { $0.type == .spendingLimit }
    }

    var savingsTargets: [Goal] {
        goals.filter { $0.type == .savingsTarget }
    }

    /// Metas de "ahorrar X al mes". Su progreso no vive en la meta sino en `monthlySavings`.
    var monthlySavingsGoals: [Goal] {
        goals.filter { $0.type == .monthlySavings }
    }

    /// All expenses for the current month, loaded server-side for accuracy.
    /// Refreshed on demand via refreshCurrentMonthExpenses().
    private(set) var currentMonthExpenses: [Expense] = []

    /// Total spent this month.
    var totalSpent: Double {
        currentMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    /// Libre = ingresos − gastado − apartado en huchas. Lo apartado ya no está
    /// en `totalSpent` (las aportaciones no son gasto), pero tampoco está libre.
    var freeCash: Double { income - totalSpent - savingsAllocated }

    /// Lo ahorrado este mes para las metas de ahorro mensual: lo mismo que queda
    /// "libre" arriba. Puede ser negativo (gastado más que ingresado); la tarjeta
    /// lo enseña como 0 € con aviso.
    var monthlySavings: Double { freeCash }

    /// Percentage of income remaining
    var freeCashPercentage: Double {
        guard income > 0 else { return 0 }
        return max(0, min(1, freeCash / income))
    }

    // MARK: - Lifecycle

    func load() async {
        guard !hasLoaded && !isLoading else { return }

        // Esperar a que Auth restaure la sesión. Antes se sondeaba 5 × 300 ms y,
        // si el arranque iba lento, saltaba un «No autenticado» falso. Ahora se
        // escucha el cambio de sesión, con tope: ver `EsperaDeSesion`.
        guard await EsperaDeSesion.haySesion() else {
            error = "No autenticado"
            return
        }
        // Mientras se esperaba pudo entrar otra llamada (la tarea de la vista y
        // un «Reintentar», por ejemplo): que no carguen las dos.
        guard !hasLoaded && !isLoading else { return }

        isLoading = true
        error = nil

        do {
            // 0. Load User Settings first to check recurring preference
            if let doc = try await documentoDelUsuario() {
                self.isSalaryRecurring = doc.settings?.isSalaryRecurring ?? false
            }

            // 1. Check if budget exists for current month
            if let budget = try await service.fetchMonthlyBudget(
                year: currentYear, month: currentMonth)
            {
                currentBudget = budget
            } else {
                // CHECK RECURRING HERE
                if let doc = try await documentoDelUsuario(),
                    let baseIncome = doc.income,
                    doc.settings?.isSalaryRecurring == true
                {
                    await createMonthlyBudget(income: baseIncome)
                } else {
                    // No budget & No recurring → Trigger wizard
                    if let previous = try await service.fetchPreviousMonthBudget() {
                        previousMonthIncome = previous.income
                    }
                    showMonthlySetup = true
                }
            }

            // 2. Load goals + current month expenses in parallel
            let calendar = Calendar.current
            let monthComponents = DateComponents(year: currentYear, month: currentMonth)
            let monthStart = calendar.date(from: monthComponents) ?? Date()
            let monthEnd = calendar.date(
                byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? Date()
            let monthFilter = ExpenseFilter(
                dateRange: .custom,
                customStartDate: monthStart,
                customEndDate: monthEnd
            )

            async let goalsTask = service.fetchGoals()
            async let expensesTask = getExpensesUseCase
                .executePaginated(page: 0, filter: monthFilter)
            async let rulesTask = recurringRepository.fetchAll()

            goals = try await goalsTask
            let expensesResult = (try? await expensesTask) ?? PageResult(expenses: [], hasMore: false)
            let rules = (try? await rulesTask) ?? []
            repartir(ExpenseSanitizer.sanitize(expenses: expensesResult.expenses, rules: rules))

            hasLoaded = true

        } catch {
            self.error = error.safeUserMessage
        }

        isLoading = false
    }

    /// El documento del usuario, recién leído de Firestore; `nil` sin sesión.
    /// En modo demo (DEBUG), el de la demo, sin Auth ni Firestore.
    private func documentoDelUsuario() async throws -> UserDocument? {
        #if DEBUG
        if ModoDemo.activo { return UserDataManager.shared.userDocument }
        #endif
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        return try await UserDataService.shared.loadUserDocument(userId: userId)
    }

    // MARK: - Monthly Setup Actions

    /// Called when user completes the Monthly Setup Wizard
    func createMonthlyBudget(income: Double) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "No autenticado"
            return
        }

        let budget = MonthlyBudget(
            userId: userId,
            year: currentYear,
            month: currentMonth,
            income: income
        )

        do {
            try await service.saveMonthlyBudget(budget)
            currentBudget = budget
            showMonthlySetup = false
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.safeUserMessage
        }
    }

    func updateIncome(_ newIncome: Double) async {
        guard var budget = currentBudget else { return }

        budget.income = newIncome

        do {
            try await service.saveMonthlyBudget(budget)
            currentBudget = budget
            AnalyticsService.shared.track(.budgetConfigured(source: "income_update"))
        } catch {
            self.error = error.safeUserMessage
        }
    }

    // MARK: - Ingresos extra (vinculados a la nómina del mes)

    /// Añade un ingreso extra al mes en curso. Optimista con revert en fallo.
    func addExtraIncome(name: String, amount: Double) async {
        guard amount > 0, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard var budget = currentBudget else {
            // Sin budget no hay doc al que colgar el ingreso (wizard pendiente).
            self.error = "Configura primero la nómina de este mes"
            return
        }

        let entry = IncomeEntry(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            date: Formatters.isoString(from: Date())
        )
        budget.extraIncomes.append(entry)
        currentBudget = budget  // optimista — income/freeCash se recalculan solos

        do {
            try await service.updateExtraIncomes(budget.extraIncomes, year: currentYear, month: currentMonth)
            // Notifica al resto de pantallas (Home → recalcula ahorro con el nuevo total).
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            AnalyticsService.shared.track(.extraIncomeLogged)
            HapticManager.shared.playSuccess()
            FeedbackManager.shared.show(
                .success,
                title: "Ingreso añadido",
                message: "\(entry.name) — +\(Formatters.currency(amount)) este mes"
            )
        } catch {
            currentBudget?.extraIncomes.removeAll { $0.id == entry.id }
            self.error = "Error al guardar el ingreso: \(error.safeUserMessage)"
        }
    }

    /// Edita un ingreso extra existente (concepto/importe). Optimista con revert en fallo.
    func updateExtraIncome(_ updated: IncomeEntry) async {
        guard var budget = currentBudget,
              let idx = budget.extraIncomes.firstIndex(where: { $0.id == updated.id }) else { return }
        let previous = budget.extraIncomes[idx]
        budget.extraIncomes[idx] = updated
        currentBudget = budget

        do {
            try await service.updateExtraIncomes(budget.extraIncomes, year: currentYear, month: currentMonth)
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            HapticManager.shared.selection()
        } catch {
            if let i = currentBudget?.extraIncomes.firstIndex(where: { $0.id == updated.id }) {
                currentBudget?.extraIncomes[i] = previous
            }
            self.error = "Error al actualizar el ingreso: \(error.safeUserMessage)"
        }
    }

    /// Elimina un ingreso extra del mes en curso. Optimista con revert en fallo.
    func removeExtraIncome(_ entry: IncomeEntry) async {
        guard var budget = currentBudget,
              budget.extraIncomes.contains(where: { $0.id == entry.id }) else { return }

        budget.extraIncomes.removeAll { $0.id == entry.id }
        currentBudget = budget

        do {
            try await service.updateExtraIncomes(budget.extraIncomes, year: currentYear, month: currentMonth)
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            HapticManager.shared.selection()
        } catch {
            currentBudget?.extraIncomes.append(entry)
            self.error = "Error al eliminar el ingreso: \(error.safeUserMessage)"
        }
    }

    /// Update Salary Settings from Sheet
    func updateSalarySettings(amount: Double, recurring: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isSalaryRecurring = recurring

        do {
            // 1. Update Remote User
            try await Firestore.firestore().collection("users").document(userId).updateData([
                "income": amount,
                "settings.isSalaryRecurring": recurring,
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            // 2. Update Current Month Budget if valid
            if var budget = currentBudget {
                budget.income = amount
                try await service.saveMonthlyBudget(budget)
                currentBudget = budget
            }

            HapticManager.shared.playSuccess()
        } catch {
            self.error = "Error al guardar ajustes: \(error.safeUserMessage)"
        }
    }

    // MARK: - Goal Actions

    /// Aporta a una hucha: el movimiento de ahorro (lo que baja lo libre) y la
    /// hucha, por ese orden. El movimiento se guarda al momento, con o sin
    /// conexión; la hucha espera al servidor. Antes iba al revés y, sin
    /// conexión, la hucha subía al volver la red sin movimiento que la
    /// acompañara: el dinero estaba en la hucha y seguía libre.
    func feedPiggyBank(goalId: String, amount: Double) async {
        // Solo las huchas se alimentan: así la enhorabuena de hucha completada no
        // puede saltar por otro tipo de meta.
        guard amount > 0,
              let goalIndex = goals.firstIndex(where: { $0.id == goalId }),
              goals[goalIndex].type == .savingsTarget else { return }
        let goalName = goals[goalIndex].name
        let category = goals[goalIndex].savingsExpenseCategory ?? "Ahorros"
        let subcategory = goals[goalIndex].savingsExpenseSubcategory
        // Antes de la actualización optimista: solo se celebra el cruce del objetivo,
        // no cada aportación a una hucha que ya estaba llena.
        let importeAnterior = goals[goalIndex].currentAmount

        // El movimiento de ahorro: sale en la Home, en su sección (no es gasto,
        // ver `Expense.esAhorro`), y borrarlo devuelve el dinero.
        let aportacion = Expense(
            amount: amount,
            name: "Aportación a \(goalName)",
            category: category,
            subcategory: subcategory,
            date: Formatters.localDayString(from: Date()),
            paymentMethod: "Transferencia",
            goalId: goalId
        )
        guard let guardada = await guardarMovimiento(aportacion) else {
            self.error = "No se ha podido apartar el dinero. Inténtalo de nuevo."
            return
        }

        // Optimistic UI update (animation handled by View)
        sumarAHucha(goalId, amount)
        apartadoDelMes += amount

        do {
            try await service.feedPiggyBank(goalId: goalId, amount: amount)
        } catch {
            // La hucha no ha subido: fuera también el movimiento.
            await deshacerMovimiento(guardada)
            sumarAHucha(goalId, -amount)
            apartadoDelMes -= amount
            self.error = error.safeUserMessage
            return
        }
        // Informativo: lo que se muestra se cuenta de los movimientos.
        try? await service.updateSavingsAllocated(year: currentYear, month: currentMonth, amount: amount)
        // Con la hucha ya movida: la Home recarga su tarjeta de huchas.
        NotificationCenter.default.post(name: .expenseDidChange, object: nil)

        HapticManager.shared.playCustomPattern(.expenseAdded)

        // Por id y no por índice: durante los await la lista puede haber cambiado.
        if let meta = goals.first(where: { $0.id == goalId }),
           meta.targetAmount > 0,
           importeAnterior < meta.targetAmount,
           meta.currentAmount >= meta.targetAmount {
            huchaCompletada = meta
        }
    }

    /// Saca dinero de una hucha: vuelve a estar libre este mes. Queda como un
    /// movimiento en negativo junto a las aportaciones; borrarlo lo devuelve a
    /// la hucha. Si se apartó en otro mes, lo apartado de este queda en
    /// negativo, y es justo lo que hace falta: ese dinero vuelve a lo libre ahora.
    func withdrawPiggyBank(goalId: String, amount: Double) async {
        guard let indice = goals.firstIndex(where: { $0.id == goalId }),
              goals[indice].type == .savingsTarget else { return }
        let nombre = goals[indice].name
        let categoria = goals[indice].savingsExpenseCategory ?? "Ahorros"
        let subcategoria = goals[indice].savingsExpenseSubcategory

        // Lo que tiene la hucha ahora, no lo que había al abrir Metas: si desde
        // la Home se borró una aportación, sacar lo de antes la dejaba en negativo.
        let disponible = (try? await service.fetchGoals())?.first(where: { $0.id == goalId })?.currentAmount
            ?? goals.first(where: { $0.id == goalId })?.currentAmount ?? 0
        let importe = min(amount, disponible)
        guard importe > 0.005 else {
            if let i = goals.firstIndex(where: { $0.id == goalId }) { goals[i].currentAmount = disponible }
            self.error = "Esa hucha ya no tiene dinero que sacar."
            return
        }

        let retirada = Expense(
            amount: -importe,
            name: "Retirada de \(nombre)",
            category: categoria,
            subcategory: subcategoria,
            date: Formatters.localDayString(from: Date()),
            paymentMethod: "Transferencia",
            goalId: goalId
        )
        guard let guardada = await guardarMovimiento(retirada) else {
            self.error = "No se ha podido sacar el dinero. Inténtalo de nuevo."
            return
        }

        sumarAHucha(goalId, -importe)
        apartadoDelMes -= importe

        do {
            try await service.refundPiggyBank(goalId: goalId, amount: importe)
        } catch {
            await deshacerMovimiento(guardada)
            sumarAHucha(goalId, importe)
            apartadoDelMes += importe
            self.error = error.safeUserMessage
            return
        }
        try? await service.updateSavingsAllocated(year: currentYear, month: currentMonth, amount: -importe)
        NotificationCenter.default.post(name: .expenseDidChange, object: nil)
        HapticManager.shared.playSuccess()
    }

    /// Guarda un movimiento de ahorro y se lo pasa a la Home, que lo pinta al
    /// momento y recalcula lo libre. `nil` si no se ha podido guardar.
    private func guardarMovimiento(_ movimiento: Expense) async -> Expense? {
        do {
            var guardado = movimiento
            guardado.id = try await DependencyContainer.shared.expenseRepository.addExpense(movimiento)
            AvisoDeGasto.anadido(guardado)
            return guardado
        } catch {
            return nil
        }
    }

    /// Borra un movimiento cuya hucha no se ha podido mover, para que no se
    /// descuadren. También de la Home, que ya lo tenía pintado.
    private func deshacerMovimiento(_ movimiento: Expense) async {
        guard let id = movimiento.id else { return }
        try? await DependencyContainer.shared.expenseRepository.deleteExpense(id: id)
        AvisoDeGasto.quitado(movimiento)
    }

    private func sumarAHucha(_ goalId: String, _ importe: Double) {
        if let i = goals.firstIndex(where: { $0.id == goalId }) { goals[i].currentAmount += importe }
    }

    /// Create a new goal
    func createGoal(_ goal: Goal) async {
        do {
            let documentId = try await service.saveGoal(goal)
            // Se guarda en memoria ya con el id de Firestore: sin él, editar la meta
            // recién creada la duplicaba (sin id se hace addDocument) y borrarla o
            // alimentarla apuntaba a un documento que no existe.
            var saved = goal
            saved.documentId = documentId
            goals.append(saved)
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.safeUserMessage
        }
    }

    /// Update an existing goal
    func updateGoal(_ goal: Goal) async {
        // Lo que hay en la hucha, tal como está ahora: el formulario trae lo que
        // había al abrirlo, y guardarlo pisaba lo aportado o sacado después.
        var goal = goal
        if let actual = (try? await service.fetchGoals())?.first(where: { $0.id == goal.id }) {
            goal.currentAmount = actual.currentAmount
            goal.savedHistory = actual.savedHistory
        }
        do {
            try await service.saveGoal(goal)
            if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[idx] = goal
            }
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.safeUserMessage
        }
    }

    /// Delete a goal permanently
    func deleteGoal(_ goalId: String) async {
        do {
            try await service.deleteGoal(goalId)
            goals.removeAll { $0.id == goalId }
            HapticManager.shared.notification(.success)
        } catch {
            self.error = error.safeUserMessage
        }
    }

    // MARK: - Helpers

    /// Spent amount for a category this month, computed from sanitized currentMonthExpenses.
    /// Used by GoalCardView (Shields) via spentAmountProvider closure.
    func getSpentAmount(for categoryId: String) -> Double {
        guard !categoryId.isEmpty else { return 0 }
        let target = Self.normalizeCategory(categoryId)
        return currentMonthExpenses
            .filter {
                let catPart = $0.category.components(separatedBy: " / ").first ?? $0.category
                return Self.normalizeCategory(catPart) == target
            }
            .reduce(0) { $0 + $1.amount }
    }

    private static func normalizeCategory(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .unicodeScalars
            .filter { CharacterSet.letters.union(.whitespaces).contains($0) }
            .reduce("") { $0 + String($1) }
            .trimmingCharacters(in: .whitespaces)
    }

    /// Lightweight refresh of current month expenses — called every time the tab appears
    /// so the spending shields stay up to date without a full reload.
    func refreshCurrentMonthExpenses() async {
        let calendar = Calendar.current
        let monthComponents = DateComponents(year: currentYear, month: currentMonth)
        let monthStart = calendar.date(from: monthComponents) ?? Date()
        let monthEnd = calendar.date(
            byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? Date()
        let monthFilter = ExpenseFilter(
            dateRange: .custom,
            customStartDate: monthStart,
            customEndDate: monthEnd
        )
        guard let result = try? await getExpensesUseCase
            .executePaginated(page: 0, filter: monthFilter),
              let rules = try? await recurringRepository.fetchAll()
        else { return }
        repartir(ExpenseSanitizer.sanitize(expenses: result.expenses, rules: rules))
    }

    /// Los gastos del mes por un lado (sin las aportaciones a huchas: no son
    /// gasto ni cuentan en los límites, ver `Expense.esAhorro`) y lo apartado
    /// por otro.
    private func repartir(_ movimientos: [Expense]) {
        currentMonthExpenses = movimientos.filter { !$0.esAhorro }
        apartadoDelMes = movimientos.filter(\.esAhorro).reduce(0) { $0 + $1.amount }
    }

    /// Pone al día gastos, huchas y presupuesto sin pasar por la pantalla de
    /// carga. Al volver de la Home (donde se puede borrar una aportación) o al
    /// tirar hacia abajo: `load()` no hace nada después de la primera vez.
    func refrescar() async {
        await refreshCurrentMonthExpenses()
        if let metas = try? await service.fetchGoals() { goals = metas }
        if let presupuesto = try? await service.fetchMonthlyBudget(year: currentYear, month: currentMonth) {
            currentBudget = presupuesto
        }
    }

    /// Force reload (e.g. after adding/archiving a goal)
    func reload() async {
        hasLoaded = false
        await load()
    }

    /// Clear error state (for UI bindings)
    func clearError() {
        error = nil
    }
}
