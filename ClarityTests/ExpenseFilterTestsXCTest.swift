// ExpenseFilterTests.swift
// Tests completos para el sistema de filtros de gastos usando XCTest

import XCTest
@testable import Clarity

/// Suite completa de tests para ExpenseFilter
final class ExpenseFilterTests: XCTestCase {
    
    // MARK: - Datos de Prueba
    
    /// Crea gastos de ejemplo para las pruebas
    func createSampleExpenses() -> [Expense] {
        return [
            // Comida
            Expense(
                id: "1",
                userId: "test",
                name: "Mercadona",
                amount: 45.50,
                category: "Comida 🍔",
                subcategory: "Supermercado",
                date: Date().addingTimeInterval(-86400 * 2), // Hace 2 días
                paymentMethod: "Tarjeta",
                notes: nil,
                isRecurring: false
            ),
            Expense(
                id: "2",
                userId: "test",
                name: "Restaurante",
                amount: 35.00,
                category: "Comida 🍔",
                subcategory: "Restaurantes",
                date: Date().addingTimeInterval(-86400 * 5), // Hace 5 días
                paymentMethod: "Efectivo",
                notes: "Cena con amigos",
                isRecurring: false
            ),
            
            // Transporte
            Expense(
                id: "3",
                userId: "test",
                name: "Gasolina",
                amount: 60.00,
                category: "Transporte 🚗",
                subcategory: "Gasolina",
                date: Date().addingTimeInterval(-86400 * 1), // Hace 1 día
                paymentMethod: "Tarjeta",
                notes: nil,
                isRecurring: false
            ),
            Expense(
                id: "4",
                userId: "test",
                name: "Metro",
                amount: 12.50,
                category: "Transporte 🚗",
                subcategory: "Transporte público",
                date: Date().addingTimeInterval(-86400 * 3), // Hace 3 días
                paymentMethod: "Tarjeta",
                notes: nil,
                isRecurring: true
            ),
            
            // Ocio
            Expense(
                id: "5",
                userId: "test",
                name: "Cine",
                amount: 15.00,
                category: "Ocio 🎮",
                subcategory: "Cine",
                date: Date().addingTimeInterval(-86400 * 10), // Hace 10 días
                paymentMethod: "Tarjeta",
                notes: nil,
                isRecurring: false
            ),
            
            // Salud (mes pasado)
            Expense(
                id: "6",
                userId: "test",
                name: "Farmacia",
                amount: 25.80,
                category: "Salud 💊",
                subcategory: "Medicamentos",
                date: Date().addingTimeInterval(-86400 * 35), // Hace 35 días
                paymentMethod: "Efectivo",
                notes: nil,
                isRecurring: false
            ),
            
            // Casa (caro)
            Expense(
                id: "7",
                userId: "test",
                name: "Alquiler",
                amount: 800.00,
                category: "Casa 🏠",
                subcategory: "Alquiler",
                date: Date().addingTimeInterval(-86400 * 1), // Hace 1 día
                paymentMethod: "Transferencia",
                notes: "Alquiler mensual",
                isRecurring: true
            ),
            
            // Comida (barato)
            Expense(
                id: "8",
                userId: "test",
                name: "Café",
                amount: 2.50,
                category: "Comida 🍔",
                subcategory: "Cafeterías",
                date: Date(), // Hoy
                paymentMethod: "Efectivo",
                notes: nil,
                isRecurring: false
            )
        ]
    }
    
    // MARK: - Tests de Filtrado por Categoría
    
    func testFilterBySingleCategory() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 3, "Debe haber 3 gastos de Comida")
        XCTAssertTrue(filtered.allSatisfy { $0.category.contains("Comida") })
        
        let names = filtered.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Café", "Mercadona", "Restaurante"])
    }
    
    func testFilterByMultipleCategories() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔", "Transporte 🚗"]
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 5, "Debe haber 3 de Comida + 2 de Transporte")
        
        let categories = Set(filtered.map { $0.category })
        XCTAssertEqual(categories.count, 2)
        XCTAssertTrue(categories.contains { $0.contains("Comida") })
        XCTAssertTrue(categories.contains { $0.contains("Transporte") })
    }
    
    func testNoCategoryFilterReturnsAll() {
        // Given
        let expenses = createSampleExpenses()
        let filter = ExpenseFilter()
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, expenses.count, "Sin filtro debe devolver todos")
    }
    
    // MARK: - Tests de Filtrado por Método de Pago
    
    func testFilterByPaymentMethod() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedPaymentMethods = ["Tarjeta"]
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertTrue(filtered.allSatisfy { $0.paymentMethod == "Tarjeta" })
        XCTAssertEqual(filtered.count, 5)
    }
    
    func testFilterByMultiplePaymentMethods() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedPaymentMethods = ["Efectivo", "Transferencia"]
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 4, "Efectivo (3) + Transferencia (1)")
    }
    
    // MARK: - Tests de Filtrado por Importe
    
    func testFilterByMinAmount() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.minAmount = 50.0
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 2, "Gasolina (60) + Alquiler (800)")
        XCTAssertTrue(filtered.allSatisfy { $0.amount >= 50.0 })
    }
    
    func testFilterByMaxAmount() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.maxAmount = 20.0
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 3, "Metro (12.50) + Cine (15) + Café (2.50)")
        XCTAssertTrue(filtered.allSatisfy { $0.amount <= 20.0 })
    }
    
    func testFilterByAmountRange() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.minAmount = 10.0
        filter.maxAmount = 50.0
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 5)
        XCTAssertTrue(filtered.allSatisfy { $0.amount >= 10.0 && $0.amount <= 50.0 })
    }
    
    // MARK: - Tests de Filtrado por Fecha
    
    func testFilterByThisMonth() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.dateRange = .thisMonth
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 7, "Todos excepto Farmacia (hace 35 días)")
        XCTAssertFalse(filtered.contains { $0.name == "Farmacia" })
    }
    
    func testFilterByToday() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.dateRange = .today
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 1, "Solo Café")
        XCTAssertEqual(filtered.first?.name, "Café")
    }
    
    // MARK: - Tests de Filtrado por Recurrentes
    
    func testFilterOnlyRecurring() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.showOnlyRecurring = true
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 2, "Metro y Alquiler")
        XCTAssertTrue(filtered.allSatisfy { $0.isRecurring == true })
        
        let names = Set(filtered.map { $0.name })
        XCTAssertEqual(names, ["Metro", "Alquiler"])
    }
    
    // MARK: - Tests de Ordenación
    
    func testSortByDateDescending() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.sortBy = .dateDesc
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.first?.name, "Café", "Más reciente: Hoy")
        XCTAssertEqual(filtered.last?.name, "Farmacia", "Más antiguo: Hace 35 días")
        
        // Verificar orden descendente
        for i in 0..<(filtered.count - 1) {
            XCTAssertTrue(filtered[i].date >= filtered[i + 1].date)
        }
    }
    
    func testSortByAmountDescending() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.sortBy = .amountDesc
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.first?.name, "Alquiler", "Mayor: 800")
        XCTAssertEqual(filtered.last?.name, "Café", "Menor: 2.50")
        
        for i in 0..<(filtered.count - 1) {
            XCTAssertTrue(filtered[i].amount >= filtered[i + 1].amount)
        }
    }
    
    func testSortByAmountAscending() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.sortBy = .amountAsc
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.first?.name, "Café", "Menor: 2.50")
        XCTAssertEqual(filtered.last?.name, "Alquiler", "Mayor: 800")
        
        for i in 0..<(filtered.count - 1) {
            XCTAssertTrue(filtered[i].amount <= filtered[i + 1].amount)
        }
    }
    
    func testSortByNameAscending() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.sortBy = .nameAsc
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.first?.name, "Alquiler")
        XCTAssertEqual(filtered.last?.name, "Restaurante")
    }
    
    // MARK: - Tests de Filtros Combinados
    
    func testCombineCategoryAndPaymentMethod() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        filter.selectedPaymentMethods = ["Tarjeta"]
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 1, "Solo Mercadona")
        XCTAssertEqual(filtered.first?.name, "Mercadona")
    }
    
    func testCombineCategoryAndAmountRange() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        filter.minAmount = 10.0
        filter.maxAmount = 50.0
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 2, "Mercadona + Restaurante")
        let names = Set(filtered.map { $0.name })
        XCTAssertEqual(names, ["Mercadona", "Restaurante"])
    }
    
    func testComplexFilterCombination() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Transporte 🚗"]
        filter.selectedPaymentMethods = ["Tarjeta"]
        filter.maxAmount = 20.0
        filter.showOnlyRecurring = true
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 1, "Solo Metro")
        XCTAssertEqual(filtered.first?.name, "Metro")
    }
    
    func testNoResultsWithRestrictiveFilters() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        filter.minAmount = 1000.0
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertTrue(filtered.isEmpty, "No debe haber resultados")
    }
    
    // MARK: - Tests de hasActiveFilters
    
    func testHasActiveFiltersDefault() {
        // Given
        let filter = ExpenseFilter()
        
        // Then
        XCTAssertFalse(filter.hasActiveFilters)
    }
    
    func testHasActiveFiltersWithCategory() {
        // Given
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        
        // Then
        XCTAssertTrue(filter.hasActiveFilters)
    }
    
    func testHasActiveFiltersWithDateRange() {
        // Given
        var filter = ExpenseFilter()
        filter.dateRange = .lastMonth
        
        // Then
        XCTAssertTrue(filter.hasActiveFilters)
    }
    
    // MARK: - Tests Edge Cases
    
    func testFilterEmptyList() {
        // Given
        let expenses: [Expense] = []
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertTrue(filtered.isEmpty)
    }
    
    func testFilterByCategoryPartialMatch() {
        // Given
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida"]
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, 3, "Debe encontrar Comida 🍔")
    }
    
    func testEmptyFilterDoesNotModifyExpenses() {
        // Given
        let expenses = createSampleExpenses()
        let filter = ExpenseFilter()
        
        // When
        let filtered = filter.apply(to: expenses)
        
        // Then
        XCTAssertEqual(filtered.count, expenses.count)
        
        let originalIds = Set(expenses.map { $0.id })
        let filteredIds = Set(filtered.map { $0.id })
        XCTAssertEqual(originalIds, filteredIds)
    }
    
    // MARK: - Tests de Rendimiento
    
    func testPerformanceWith1000Expenses() {
        // Crear 1000 gastos
        let expenses = (1...1000).map { i in
            Expense(
                id: "\(i)",
                userId: "test",
                name: "Gasto \(i)",
                amount: Double.random(in: 1...1000),
                category: ["Comida 🍔", "Transporte 🚗", "Ocio 🎮", "Casa 🏠"].randomElement()!,
                subcategory: "Sub",
                date: Date().addingTimeInterval(-Double.random(in: 0...2_592_000)),
                paymentMethod: ["Tarjeta", "Efectivo"].randomElement()!,
                notes: nil,
                isRecurring: Bool.random()
            )
        }
        
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔", "Transporte 🚗"]
        filter.minAmount = 50.0
        filter.maxAmount = 500.0
        filter.sortBy = .dateDesc
        
        // Medir performance
        measure {
            let filtered = filter.apply(to: expenses)
            XCTAssertGreaterThan(filtered.count, 0)
        }
    }
}
