//
//  AIServiceTests.swift
//  ClarityTests
//
//  Created by Clarity AI on 2026-01-27.
//

import XCTest
@testable import Clarity

final class AIServiceTests: XCTestCase {

    func testPromptBuilderWithEmptyData() {
        // Given
        let context = PromptBuilder.buildFinancialContext(
            user: nil,
            expenses: [],
            goals: [],
            monthBudget: nil
        )
        
        // Then
        XCTAssertTrue(context.contains("<financial_context>"))
        XCTAssertTrue(context.contains("No hay gastos registrados este mes."))
        XCTAssertTrue(context.contains("Sin datos históricos."))
    }
    
    func testPromptBuilderWithExpenses() {
        // Given
        let expense = Expense(
            id: UUID(),
            name: "Test Expense",
            amount: 100.0,
            date: Date(),
            category: "Comida",
            categoryGroup: "Esenciales",
            type: .expense,
            note: nil
        )
        
        let context = PromptBuilder.buildFinancialContext(
            user: nil,
            expenses: [expense],
            goals: [],
            monthBudget: nil
        )
        
        // Then
        XCTAssertTrue(context.contains("<category name=\"Comida\">100</category>"))
        XCTAssertTrue(context.contains("<expense rank=\"1\" name=\"Test Expense\""))
    }
    func testPromptBuilderIncludesPrinciples() {
        // Given
        let context = PromptBuilder.buildFinancialContext(
            user: nil,
            expenses: [],
            goals: [],
            monthBudget: nil
        )
        
        // Then
        XCTAssertTrue(context.contains("<financial_principles>"))
        XCTAssertTrue(context.contains("50/30/20"))
    }
}
