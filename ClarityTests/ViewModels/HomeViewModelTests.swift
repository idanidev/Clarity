// HomeViewModelTests.swift
import Testing
import Foundation
@testable import Clarity

// MainActor is required because HomeViewModel is @MainActor
@MainActor
struct HomeViewModelTests {
    
    var mockRepository: MockExpenseRepository
    var addUseCase: AddExpenseUseCase
    var getUseCase: GetExpensesUseCase
    var deleteUseCase: DeleteExpenseUseCase
    var viewModel: HomeViewModel
    
    init() {
        self.mockRepository = MockExpenseRepository()
        self.addUseCase = AddExpenseUseCase(repository: mockRepository)
        self.getUseCase = GetExpensesUseCase(repository: mockRepository)
        self.deleteUseCase = DeleteExpenseUseCase(repository: mockRepository)
        
        self.viewModel = HomeViewModel(
            getExpensesUseCase: getUseCase,
            deleteExpenseUseCase: deleteUseCase,
            addExpenseUseCase: addUseCase
        )
    }
    
    @Test func testInitialStateIsIdle() {
        #expect(viewModel.state == .idle)
    }
    
    @Test func testLoadExpensesSuccess() async {
        // Given
        let testExpense = Expense(
            id: "1",
            amount: 50.0,
            name: "Test",
            category: "Comida",
            date: "2026-01-01T12:00:00Z",
            paymentMethod: "Tarjeta"
        )
        mockRepository.expenses = [testExpense]
        
        // When
        await viewModel.loadExpenses()
        
        // Then
        if case .loaded(let expenses) = viewModel.state {
            #expect(expenses.count == 1)
            #expect(expenses.first?.name == "Test")
        } else {
            #expect(Bool(false), "State should be loaded")
        }
        #expect(viewModel.allExpenses.count == 1)
    }
    
    @Test func testLoadExpensesEmpty() async {
        // Given
        mockRepository.expenses = []
        
        // When
        await viewModel.loadExpenses()
        
        // Then
        #expect(viewModel.state == .empty)
        #expect(viewModel.allExpenses.isEmpty)
    }
    
    @Test func testLoadExpensesFailure() async {
        // ... (unchanged)
    }
    
    // ...
    
    @Test func testDeleteExpense() async {
        // Given
        let expense = Expense(id: "1", amount: 10, name: "Delete Me", category: "Test", date: "2026-01-01T12:00:00Z", paymentMethod: "Tarjeta")
        mockRepository.expenses = [expense]
        await viewModel.loadExpenses()
        
        // When
        await viewModel.deleteExpense(expense)
        
        // Then
        #expect(mockRepository.expenses.isEmpty)
        if case .empty = viewModel.state {
            #expect(true)
        } else {
             #expect(Bool(false), "State should be empty after deletion, but was \(viewModel.state)")
        }
    }
}
