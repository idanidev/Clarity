//
//  AIServiceTests.swift
//  ClarityTests
//

import XCTest
@testable import Clarity

final class AIServiceTests: XCTestCase {

    func testPromptBuilderWithEmptyData() {
        let context = PromptBuilder.buildFinancialContext(
            user: nil,
            expenses: [],
            goals: [],
            monthBudget: nil
        )

        XCTAssertTrue(context.contains("<financial_context>"))
        XCTAssertTrue(context.contains("No hay gastos registrados este mes."))
        XCTAssertTrue(context.contains("Sin datos históricos."))
    }

    func testPromptBuilderWithExpenses() {
        let expense = Expense(
            amount: 100.0,
            name: "Test Expense",
            category: "Comida",
            date: "2026-04-01",
            paymentMethod: "Tarjeta"
        )

        let context = PromptBuilder.buildFinancialContext(
            user: nil,
            expenses: [expense],
            goals: [],
            monthBudget: nil
        )

        XCTAssertTrue(context.contains("Comida"))
    }

    func testPromptBuilderIncludesPrinciples() {
        let context = PromptBuilder.buildFinancialContext(
            user: nil,
            expenses: [],
            goals: [],
            monthBudget: nil
        )

        XCTAssertTrue(context.contains("<financial_principles>"))
        XCTAssertTrue(context.contains("50/30/20"))
    }
}
