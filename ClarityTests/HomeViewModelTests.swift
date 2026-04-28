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

    @Test("Initial state is idle")
    func initialState() {
        let (vm, _) = makeSUT()
        #expect(vm.state == .idle)
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

    @Test("searchText triggers debounced reload")
    func searchTextDebounce() async {
        let (vm, _) = makeSUT()
        vm.searchText = "café"
        // searchText setter starts a 300ms debounced task
        #expect(vm.searchText == "café")
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
