// HomeViewModelTests.swift
// Tests for main expense list ViewModel

import Testing
import Foundation
@testable import Clarity

@Suite("HomeViewModel", .serialized)
@MainActor
struct HomeViewModelTests {

    private func makeSUT(expenses: [Expense] = []) -> (HomeViewModel, MockExpenseRepository) {
        let repo = MockExpenseRepository()
        repo.expenses = expenses
        let getUC = GetExpensesUseCase(repository: repo)
        let deleteUC = DeleteExpenseUseCase(repository: repo)
        let addUC = AddExpenseUseCase(repository: repo)
        let vm = HomeViewModel(
            getExpensesUseCase: getUC,
            deleteExpenseUseCase: deleteUC,
            addExpenseUseCase: addUC
        )
        return (vm, repo)
    }

    private func sampleExpense(
        id: String = "1",
        amount: Double = 25.0,
        name: String = "Café",
        category: String = "Ocio",
        date: String? = nil
    ) -> Expense {
        let dateStr = date ?? Formatters.isoString(from: Date())
        return Expense(id: id, amount: amount, name: name, category: category, date: dateStr)
    }

    // MARK: - Initial State

    @Test("Initial state is empty before any load")
    func initialState() {
        let (vm, _) = makeSUT()
        // .empty, NO .idle: bajo @Observable los didSet SÍ disparan dentro de init
        // (la macro convierte la propiedad en computada). El init asigna
        // selectedFilter → didSet → applyFilters() → con allExpenses vacío
        // deja state = .empty. Comportamiento esperado, no bug.
        #expect(vm.state == .empty)
        #expect(vm.hasLoaded == false)
        #expect(vm.allExpenses.isEmpty)
    }

    // MARK: - Filtering

    @Test("totalFilteredAmount sums filtered expenses")
    func totalFilteredAmount() {
        let (vm, _) = makeSUT()
        vm.filteredExpenses = [
            sampleExpense(id: "1", amount: 10),
            sampleExpense(id: "2", amount: 20),
            sampleExpense(id: "3", amount: 30),
        ]
        #expect(vm.totalFilteredAmount == 60.0)
    }

    @Test("totalFilteredAmount is zero with no expenses")
    func totalFilteredAmountEmpty() {
        let (vm, _) = makeSUT()
        #expect(vm.totalFilteredAmount == 0)
    }

    // MARK: - Delete

    @Test("deleteExpense removes from repository")
    func deleteExpense() async {
        let expense = sampleExpense(id: "del-1", amount: 15, name: "Borrar")
        let (vm, repo) = makeSUT(expenses: [expense])
        await vm.deleteExpense(expense)
        #expect(repo.expenses.isEmpty)
    }

    // MARK: - Duplicate

    @Test("duplicateExpense adds a copy")
    func duplicateExpense() async throws {
        let expense = sampleExpense(id: "dup-1", amount: 42, name: "Original")
        let (vm, repo) = makeSUT(expenses: [expense])
        try await vm.duplicateExpense(expense)
        #expect(repo.expenses.count == 2)
        let duplicate = repo.expenses.last
        #expect(duplicate?.name == "Original")
        #expect(duplicate?.amount == 42)
    }

    // MARK: - Remove from state

    @Test("removeExpense removes from allExpenses")
    func removeExpenseFromState() {
        let expense = sampleExpense(id: "rm-1")
        let (vm, _) = makeSUT()
        vm.allExpenses = [expense]
        vm.currentMonthExpenses = [expense]
        vm.removeExpense(id: "rm-1")
        #expect(vm.allExpenses.isEmpty)
        #expect(vm.currentMonthExpenses.isEmpty)
    }

    // MARK: - Prepend

    @Test("prependExpense adds to front of allExpenses")
    func prependExpense() {
        let existing = sampleExpense(id: "old", name: "Viejo")
        let new = sampleExpense(id: "new", name: "Nuevo")
        let (vm, _) = makeSUT()
        vm.allExpenses = [existing]
        vm.prependExpense(new)
        #expect(vm.allExpenses.count == 2)
        #expect(vm.allExpenses.first?.id == "new")
    }

    // MARK: - Search

    // El test de antes solo comprobaba que el setter guardaba el texto. Y, de
    // paso, dejaba suelta la recarga de verdad: 300 ms después, con otros tests
    // ya en marcha, corría `loadExpenses` contra Firestore y el widget reales.
    // Ahora la recarga se sustituye por un apunte y la espera se acorta.

    /// Apunta cada recarga y el texto que había en ese momento.
    @MainActor
    private final class RecargasApuntadas {
        var textos: [String] = []
    }

    private func makeBusqueda(espera: Duration) -> (HomeViewModel, RecargasApuntadas) {
        let (vm, _) = makeSUT()
        let apuntes = RecargasApuntadas()
        vm.esperaBusqueda = espera
        vm.recargaTrasBuscar = { [weak vm] in apuntes.textos.append(vm?.searchText ?? "") }
        return (vm, apuntes)
    }

    @Test("escribir seguido recarga UNA vez, tras la espera y con el texto final")
    func searchDebounceCoalesces() async {
        let (vm, apuntes) = makeBusqueda(espera: .milliseconds(30))

        var tareas: [Task<Void, Never>] = []
        for texto in ["c", "ca", "caf", "café"] {
            vm.searchText = texto
            if let tarea = vm.searchTask { tareas.append(tarea) }
        }
        // Se esperan las tareas de verdad, no un tiempo a ojo.
        for tarea in tareas { await tarea.value }

        #expect(tareas.count == 4)
        // Fuera del `#expect`: dentro, la macro se atraganta con el `rethrows`.
        let anterioresCanceladas = tareas.dropLast().allSatisfy { $0.isCancelled }
        #expect(anterioresCanceladas)
        #expect(tareas.last?.isCancelled == false)
        #expect(apuntes.textos == ["café"])
    }

    @Test("mientras no vence la espera no se recarga, y una tecla nueva la anula")
    func searchDebounceWaits() async {
        // Espera larga a propósito: si el debounce no esperase, la recarga
        // saltaría sola mucho antes de que este test la cancele.
        let (vm, apuntes) = makeBusqueda(espera: .seconds(30))

        vm.searchText = "merca"
        let pendiente = vm.searchTask
        for _ in 0..<20 { await Task.yield() }
        #expect(apuntes.textos.isEmpty)
        #expect(pendiente?.isCancelled == false)

        // Cancelada —que es lo que hace la tecla siguiente— sale sin recargar.
        vm.esperaBusqueda = .zero
        vm.searchText = "mercadona"
        await pendiente?.value
        await vm.searchTask?.value

        #expect(pendiente?.isCancelled == true)
        #expect(apuntes.textos == ["mercadona"])
    }

    @Test("dos búsquedas separadas por más que la espera recargan dos veces")
    func searchDebounceSeparateSearches() async {
        let (vm, apuntes) = makeBusqueda(espera: .zero)

        vm.searchText = "pan"
        await vm.searchTask?.value
        vm.searchText = ""
        await vm.searchTask?.value

        // Borrar el texto también recarga: es lo que devuelve la lista al mes.
        #expect(apuntes.textos == ["pan", ""])
    }

    /// El día 15 de este mes. A mitad de mes para que ni el huso horario ni
    /// correr el test un día 1 de madrugada lo saquen de «este mes».
    private func quinceDeEsteMes() -> String {
        let hoy = Calendar.current.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d-15", hoy.year ?? 2026, hoy.month ?? 1)
    }

    @Test("buscar filtra por nombre, categoría y subcategoría, sin mirar el mes")
    func searchFiltersAcrossMonths() async {
        let (vm, _) = makeBusqueda(espera: .zero)
        let esteMes = quinceDeEsteMes()
        vm.allExpenses = [
            sampleExpense(id: "hoy", name: "Café con leche", category: "Ocio", date: esteMes),
            sampleExpense(id: "viejo", name: "Desayuno", category: "Cafeterías", date: "2020-01-15"),
            Expense(id: "sub", amount: 3, name: "Cruasán", category: "Comida",
                    subcategory: "Cafés", date: "2019-06-02"),
            sampleExpense(id: "otro", name: "Gasolina", category: "Coche", date: esteMes),
        ]

        vm.searchText = "CAF"
        await vm.searchTask?.value
        // Lo último que hace la recarga real es volver a aplicar los filtros;
        // asignar el filtro es la forma de pedirlo desde fuera.
        vm.selectedFilter = ExpenseFilter(dateRange: .thisMonth)

        // Sin búsqueda, «este mes» dejaría fuera los de 2019 y 2020.
        #expect(Set(vm.filteredExpenses.compactMap(\.id)) == ["hoy", "viejo", "sub"])
        #expect(vm.state == .loaded(vm.filteredExpenses))

        vm.searchText = ""
        await vm.searchTask?.value
        vm.selectedFilter = ExpenseFilter(dateRange: .thisMonth)

        #expect(Set(vm.filteredExpenses.compactMap(\.id)) == ["hoy", "otro"])
    }

    @Test("una búsqueda sin resultados deja la lista vacía, no la del mes")
    func searchWithoutMatches() async {
        let (vm, _) = makeBusqueda(espera: .zero)
        vm.allExpenses = [sampleExpense(id: "hoy", name: "Café", category: "Ocio")]

        vm.searchText = "zzz"
        await vm.searchTask?.value
        vm.selectedFilter = ExpenseFilter(dateRange: .thisMonth)

        #expect(vm.filteredExpenses.isEmpty)
        #expect(vm.state == .empty)
    }

    // MARK: - Pagination

    @Test("Initial pagination state")
    func paginationInitial() {
        let (vm, _) = makeSUT()
        #expect(vm.currentPage == 0)
        #expect(vm.hasMorePages == true)
        #expect(vm.isLoadingMore == false)
    }

    // MARK: - Category Groups

    @Test("categoryGroups is empty initially")
    func categoryGroupsEmpty() {
        let (vm, _) = makeSUT()
        #expect(vm.categoryGroups.isEmpty)
    }

    // MARK: - Error State

    @Test("deleteExpense with failure sets error state")
    func deleteExpenseFailure() async {
        let expense = sampleExpense(id: "fail-1")
        let (vm, repo) = makeSUT(expenses: [expense])
        repo.shouldFail = true
        await vm.deleteExpense(expense)
        if case .error = vm.state {
            // Expected error state
        } else {
            #expect(Bool(false), "Expected error state after failed delete")
        }
    }
}
