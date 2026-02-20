// ExpenseFilterTests.swift
// Tests completos para el sistema de filtros de gastos

import Testing
import Foundation
@testable import Clarity

@Suite("Filtros de Gastos - Tests Completos")
struct ExpenseFilterTests {
    
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
    
    @Test("Filtrar por una sola categoría")
    func filterBySingleCategory() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        
        let filtered = filter.apply(to: expenses)
        
        // Verificar que solo hay gastos de Comida
        #expect(filtered.count == 3)
        #expect(filtered.allSatisfy { $0.category.contains("Comida") })
        
        // Verificar los nombres
        let names = filtered.map { $0.name }.sorted()
        #expect(names == ["Café", "Mercadona", "Restaurante"])
    }
    
    @Test("Filtrar por múltiples categorías")
    func filterByMultipleCategories() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔", "Transporte 🚗"]
        
        let filtered = filter.apply(to: expenses)
        
        // Debería tener 3 de Comida + 2 de Transporte = 5
        #expect(filtered.count == 5)
        
        let categories = Set(filtered.map { $0.category })
        #expect(categories.count == 2)
        #expect(categories.contains { $0.contains("Comida") })
        #expect(categories.contains { $0.contains("Transporte") })
    }
    
    @Test("Sin filtro de categoría devuelve todos")
    func noCategoryFilterReturnsAll() {
        let expenses = createSampleExpenses()
        let filter = ExpenseFilter()
        
        let filtered = filter.apply(to: expenses)
        
        #expect(filtered.count == expenses.count)
    }
    
    // MARK: - Tests de Filtrado por Método de Pago
    
    @Test("Filtrar por método de pago - Tarjeta")
    func filterByPaymentMethod() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedPaymentMethods = ["Tarjeta"]
        
        let filtered = filter.apply(to: expenses)
        
        // Verificar que solo hay gastos con Tarjeta
        #expect(filtered.allSatisfy { $0.paymentMethod == "Tarjeta" })
        #expect(filtered.count == 5) // Mercadona, Gasolina, Metro, Cine, Café con Efectivo no
    }
    
    @Test("Filtrar por múltiples métodos de pago")
    func filterByMultiplePaymentMethods() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedPaymentMethods = ["Efectivo", "Transferencia"]
        
        let filtered = filter.apply(to: expenses)
        
        // Efectivo: Restaurante, Farmacia, Café (3)
        // Transferencia: Alquiler (1)
        #expect(filtered.count == 4)
    }
    
    // MARK: - Tests de Filtrado por Importe
    
    @Test("Filtrar por importe mínimo")
    func filterByMinAmount() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.minAmount = 50.0
        
        let filtered = filter.apply(to: expenses)
        
        // Gasolina (60), Alquiler (800)
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.amount >= 50.0 })
    }
    
    @Test("Filtrar por importe máximo")
    func filterByMaxAmount() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.maxAmount = 20.0
        
        let filtered = filter.apply(to: expenses)
        
        // Metro (12.50), Cine (15), Café (2.50)
        #expect(filtered.count == 3)
        #expect(filtered.allSatisfy { $0.amount <= 20.0 })
    }
    
    @Test("Filtrar por rango de importe")
    func filterByAmountRange() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.minAmount = 10.0
        filter.maxAmount = 50.0
        
        let filtered = filter.apply(to: expenses)
        
        // Mercadona (45.50), Restaurante (35), Metro (12.50), Cine (15), Farmacia (25.80)
        #expect(filtered.count == 5)
        #expect(filtered.allSatisfy { $0.amount >= 10.0 && $0.amount <= 50.0 })
    }
    
    // MARK: - Tests de Filtrado por Fecha
    
    @Test("Filtrar por Este Mes")
    func filterByThisMonth() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.dateRange = .thisMonth
        
        let filtered = filter.apply(to: expenses)
        
        // Todos excepto Farmacia (hace 35 días)
        #expect(filtered.count == 7)
        
        // Verificar que Farmacia no está
        #expect(!filtered.contains { $0.name == "Farmacia" })
    }
    
    @Test("Filtrar por Hoy")
    func filterByToday() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.dateRange = .today
        
        let filtered = filter.apply(to: expenses)
        
        // Solo Café
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Café")
    }
    
    // MARK: - Tests de Filtrado por Recurrentes
    
    @Test("Filtrar solo recurrentes")
    func filterOnlyRecurring() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.showOnlyRecurring = true
        
        let filtered = filter.apply(to: expenses)
        
        // Metro y Alquiler
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.isRecurring == true })
        
        let names = Set(filtered.map { $0.name })
        #expect(names == ["Metro", "Alquiler"])
    }
    
    // MARK: - Tests de Ordenación
    
    @Test("Ordenar por fecha descendente (más recientes)")
    func sortByDateDescending() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.sortBy = .dateDesc
        
        let filtered = filter.apply(to: expenses)
        
        // Verificar que el primer gasto es el más reciente
        #expect(filtered.first?.name == "Café") // Hoy
        #expect(filtered.last?.name == "Farmacia") // Hace 35 días
        
        // Verificar orden descendente
        for i in 0..<(filtered.count - 1) {
            #expect(filtered[i].date >= filtered[i + 1].date)
        }
    }
    
    @Test("Ordenar por importe descendente")
    func sortByAmountDescending() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.sortBy = .amountDesc
        
        let filtered = filter.apply(to: expenses)
        
        #expect(filtered.first?.name == "Alquiler") // 800
        #expect(filtered.last?.name == "Café") // 2.50
        
        // Verificar orden descendente
        for i in 0..<(filtered.count - 1) {
            #expect(filtered[i].amount >= filtered[i + 1].amount)
        }
    }
    
    @Test("Ordenar por importe ascendente")
    func sortByAmountAscending() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.sortBy = .amountAsc
        
        let filtered = filter.apply(to: expenses)
        
        #expect(filtered.first?.name == "Café") // 2.50
        #expect(filtered.last?.name == "Alquiler") // 800
        
        // Verificar orden ascendente
        for i in 0..<(filtered.count - 1) {
            #expect(filtered[i].amount <= filtered[i + 1].amount)
        }
    }
    
    @Test("Ordenar por nombre A-Z")
    func sortByNameAscending() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.sortBy = .nameAsc
        
        let filtered = filter.apply(to: expenses)
        
        #expect(filtered.first?.name == "Alquiler")
        #expect(filtered.last?.name == "Restaurante")
    }
    
    // MARK: - Tests de Filtros Combinados
    
    @Test("Combinar categoría + método de pago")
    func combineCategoryAndPaymentMethod() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        filter.selectedPaymentMethods = ["Tarjeta"]
        
        let filtered = filter.apply(to: expenses)
        
        // Solo Mercadona (Comida + Tarjeta)
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Mercadona")
    }
    
    @Test("Combinar categoría + rango de importe")
    func combineCategoryAndAmountRange() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        filter.minAmount = 10.0
        filter.maxAmount = 50.0
        
        let filtered = filter.apply(to: expenses)
        
        // Mercadona (45.50) y Restaurante (35.00)
        #expect(filtered.count == 2)
        let names = Set(filtered.map { $0.name })
        #expect(names == ["Mercadona", "Restaurante"])
    }
    
    @Test("Filtro complejo: categoría + método + importe + recurrente")
    func complexFilterCombination() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Transporte 🚗"]
        filter.selectedPaymentMethods = ["Tarjeta"]
        filter.maxAmount = 20.0
        filter.showOnlyRecurring = true
        
        let filtered = filter.apply(to: expenses)
        
        // Solo Metro (Transporte + Tarjeta + 12.50 < 20 + recurrente)
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Metro")
    }
    
    @Test("Sin ningún resultado - filtros muy restrictivos")
    func noResultsWithRestrictiveFilters() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        filter.minAmount = 1000.0 // Muy alto
        
        let filtered = filter.apply(to: expenses)
        
        #expect(filtered.isEmpty)
    }
    
    // MARK: - Tests de hasActiveFilters
    
    @Test("hasActiveFilters - sin filtros activos")
    func hasActiveFiltersDefault() {
        let filter = ExpenseFilter()
        
        #expect(!filter.hasActiveFilters)
    }
    
    @Test("hasActiveFilters - con categoría seleccionada")
    func hasActiveFiltersWithCategory() {
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        
        #expect(filter.hasActiveFilters)
    }
    
    @Test("hasActiveFilters - con rango de fecha no predeterminado")
    func hasActiveFiltersWithDateRange() {
        var filter = ExpenseFilter()
        filter.dateRange = .lastMonth
        
        #expect(filter.hasActiveFilters)
    }
    
    // MARK: - Tests Edge Cases
    
    @Test("Filtrar lista vacía")
    func filterEmptyList() {
        let expenses: [Expense] = []
        var filter = ExpenseFilter()
        filter.selectedCategories = ["Comida 🍔"]
        
        let filtered = filter.apply(to: expenses)
        
        #expect(filtered.isEmpty)
    }
    
    @Test("Categoría con nombre parcial")
    func filterByCategoryPartialMatch() {
        let expenses = createSampleExpenses()
        var filter = ExpenseFilter()
        // El filtro busca "Comida" en "Comida 🍔"
        filter.selectedCategories = ["Comida"]
        
        let filtered = filter.apply(to: expenses)
        
        // Debería encontrar los 3 gastos de Comida
        #expect(filtered.count == 3)
    }
    
    @Test("Preservar gastos tras aplicar filtro vacío")
    func emptyFilterDoesNotModifyExpenses() {
        let expenses = createSampleExpenses()
        let filter = ExpenseFilter()
        
        let filtered = filter.apply(to: expenses)
        
        // Verificar que devuelve todos los gastos
        #expect(filtered.count == expenses.count)
        
        // Verificar que son los mismos IDs
        let originalIds = Set(expenses.map { $0.id })
        let filteredIds = Set(filtered.map { $0.id })
        #expect(originalIds == filteredIds)
    }
}

// MARK: - Tests de Rendimiento

@Suite("Filtros de Gastos - Rendimiento")
struct ExpenseFilterPerformanceTests {
    
    @Test("Rendimiento con 1000 gastos")
    func performanceWith1000Expenses() {
        // Crear 1000 gastos de prueba
        let expenses = (1...1000).map { i in
            Expense(
                id: "\(i)",
                userId: "test",
                name: "Gasto \(i)",
                amount: Double.random(in: 1...1000),
                category: ["Comida 🍔", "Transporte 🚗", "Ocio 🎮", "Casa 🏠"].randomElement()!,
                subcategory: "Sub",
                date: Date().addingTimeInterval(-Double.random(in: 0...2_592_000)), // Últimos 30 días
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
        
        // Ejecutar el filtro
        let filtered = filter.apply(to: expenses)
        
        // Verificar que se ejecutó y devuelve resultados
        #expect(filtered.count > 0)
        #expect(filtered.count < expenses.count)
        
        print("✅ Filtrado 1000 gastos → \(filtered.count) resultados")
    }
}
