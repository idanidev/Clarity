// RepositoriosDemo.swift
// Los repositorios y servicios del modo demo (solo DEBUG): los mismos contratos
// que los de verdad, con los datos de `DatosDemo` en memoria. Nada de aquí
// habla con Firestore, con Auth ni con la red; lo que se escribe se queda en
// memoria y se pierde al cerrar la app.

#if DEBUG
import Foundation

// MARK: - Gastos

@MainActor
final class ExpenseRepositoryDemo: ExpenseRepositoryProtocol {
    private var gastos: [Expense]

    init(gastos: [Expense]) {
        self.gastos = gastos
    }

    /// Como el remoto: por fecha, el más reciente primero.
    private var ordenados: [Expense] { ExpenseSyncPolicy.enOrdenRemoto(gastos) }

    func getExpenses(policy: CachePolicy) async throws -> [Expense] { ordenados }

    func getExpenses() async throws -> [Expense] { ordenados }

    func getExpenses(from startDate: String, to endDate: String) async throws -> [Expense] {
        ordenados.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func addExpense(_ expense: Expense) async throws -> String {
        let id = expense.id ?? "demo-\(UUID().uuidString)"
        var nuevo = expense
        nuevo.id = id
        gastos.append(nuevo)
        return id
    }

    func deleteExpense(id: String) async throws {
        gastos.removeAll { $0.id == id }
    }

    func updateExpense(_ expense: Expense) async throws {
        guard let i = gastos.firstIndex(where: { $0.id == expense.id }) else { return }
        gastos[i] = expense
    }

    /// Igual que `ExpenseRepository`: la primera página lo trae todo y acota
    /// solo por fechas; categorías y métodos de pago los filtra quien llama.
    func getExpensesPaginated(page: Int, filter: ExpenseFilter?) async throws -> PageResult {
        guard page == 0 else { return PageResult(expenses: [], hasMore: false) }
        guard let filter, filter.dateRange != .allTime else {
            return PageResult(expenses: ordenados, hasMore: false)
        }
        let (desde, hasta) = filter.dateRangeForQuery()
        return PageResult(expenses: ordenados.filter { $0.date >= desde && $0.date <= hasta }, hasMore: false)
    }
}

// MARK: - Recurrentes

/// Subclase y no protocolo: las vistas usan el tipo concreto. Todo lo que
/// tocaría Firestore está sobrescrito.
final class RecurringExpenseRepositoryDemo: RecurringExpenseRepository {
    private var reglas: [RecurringExpense]

    init(reglas: [RecurringExpense]) {
        self.reglas = reglas
        super.init()
    }

    override func fetchAll() async throws -> [RecurringExpense] { reglas }

    override func vaciarCache() {}

    override func add(_ expense: RecurringExpense) async throws -> String {
        let id = expense.id ?? "demo-regla-\(UUID().uuidString)"
        var nueva = expense
        nueva.id = id
        reglas.append(nueva)
        return id
    }

    override func update(_ expense: RecurringExpense) async throws {
        guard let i = reglas.firstIndex(where: { $0.id == expense.id }) else { return }
        reglas[i] = expense
    }

    override func toggleActive(id: String, active: Bool) async throws {
        guard let i = reglas.firstIndex(where: { $0.id == id }) else { return }
        reglas[i].active = active
    }

    override func delete(id: String) async throws {
        reglas.removeAll { $0.id == id }
    }
}

// MARK: - Presupuestos y metas

final class FinancialServiceDemo: FinancialService {
    private var presupuestos: [String: MonthlyBudget]
    private var metas: [Goal]

    init(presupuestos: [MonthlyBudget], metas: [Goal]) {
        self.presupuestos = Dictionary(presupuestos.map { (Self.clave($0.year, $0.month), $0) },
                                       uniquingKeysWith: { primero, _ in primero })
        self.metas = metas
        super.init()
    }

    private static func clave(_ anio: Int, _ mes: Int) -> String { "\(anio)-\(mes)" }

    override func fetchMonthlyBudget(year: Int, month: Int) async throws -> MonthlyBudget? {
        presupuestos[Self.clave(year, month)]
    }

    override func saveMonthlyBudget(_ budget: MonthlyBudget) async throws {
        presupuestos[Self.clave(budget.year, budget.month)] = budget
    }

    override func updateExtraIncomes(_ entries: [IncomeEntry], year: Int, month: Int) async throws {
        presupuestos[Self.clave(year, month)]?.extraIncomes = entries
    }

    override func updateSavingsAllocated(year: Int, month: Int, amount: Double) async throws {
        presupuestos[Self.clave(year, month)]?.savingsAllocated += amount
    }

    override func fetchGoals() async throws -> [Goal] {
        metas.filter { !$0.isArchived }
    }

    override func saveGoal(_ goal: Goal) async throws -> String {
        if let i = metas.firstIndex(where: { $0.id == goal.id }) {
            metas[i] = goal
            return goal.id
        }
        var nueva = goal
        let id = goal.documentId ?? "demo-meta-\(UUID().uuidString)"
        nueva.documentId = id
        metas.append(nueva)
        return id
    }

    override func feedPiggyBank(goalId: String, amount: Double, note: String? = nil) async throws {
        guard let i = metas.firstIndex(where: { $0.id == goalId }) else { return }
        metas[i].currentAmount += amount
    }

    override func refundPiggyBank(goalId: String, amount: Double) async throws {
        guard let i = metas.firstIndex(where: { $0.id == goalId }) else { return }
        metas[i].currentAmount -= amount
    }

    override func archiveGoal(_ goalId: String) async throws {
        guard let i = metas.firstIndex(where: { $0.id == goalId }) else { return }
        metas[i].isArchived = true
    }

    override func deleteGoal(_ goalId: String) async throws {
        metas.removeAll { $0.id == goalId }
    }
}

// MARK: - Documento del usuario y categorías

/// Lo que `UserDataManager` pide al almacén: las categorías de fábrica y nada
/// más. Las escrituras no van a ningún sitio.
actor UserDataStoreDemo: UserDataStore {
    private let categorias: [Category]

    init(categorias: [Category]) {
        self.categorias = categorias
    }

    func createDefaultCategories() async -> [Category] { categorias }

    func loadCategories(userId: String, forceServer: Bool) async throws -> (categories: [Category], version: String?) {
        (categorias, nil)
    }

    func loadPaymentMethods(userId: String) async throws -> Set<String> { [] }
    func migrateExpenseCategoriesFromSlashToDash(userId: String) async throws {}
    func persistCategoriesIfMissing(_ categories: [Category], userId: String) async throws {}
    func saveCategory(_ category: Category, userId: String, oldName: String?) async throws {}
    func addSubcategory(_ subcategoryName: String, toCategoryId categoryId: String, userId: String) async throws {}
    func updateExpensesCategoryName(userId: String, oldName: String, newName: String) async throws {}
    func deleteCategory(id: String, userId: String) async throws {}
    func saveDefaultFilter(_ filter: ExpenseFilter, userId: String) async throws {}
    func saveHomeDisposicion(_ disposicion: HomeDisposicion, userId: String) async throws {}
}
#endif
