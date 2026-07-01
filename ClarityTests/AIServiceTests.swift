//
//  AIServiceTests.swift
//  ClarityTests
//
//  Migrado a Swift Testing (convención del proyecto: no XCTest).
//  El test de <financial_principles>/50-30-20 se eliminó: el rediseño del
//  PromptBuilder (2bd698f, abr 2026) movió esa guía al persona del sistema
//  (AIService.defaultPersona, privado) — el bloque ya no existe en el contexto
//  financiero por diseño y no hay superficie pública equivalente que testear.

import Testing
import Foundation
@testable import Clarity

@Suite("PromptBuilder", .serialized)
@MainActor
struct AIServiceTests {

    @Test("contexto con datos vacíos: emite secciones estables y omite las vacías")
    func promptBuilderWithEmptyData() {
        let context = PromptBuilder.buildFinancialContext(
            user: nil,
            expenses: [],
            goals: [],
            monthBudget: nil
        )

        // Secciones que el builder SIEMPRE emite, incluso sin datos.
        #expect(context.contains("<financial_context>"))
        #expect(context.contains("<resumen>"))
        #expect(context.contains("<tendencia_3_meses>"))
        // Secciones que con datos vacíos se omiten por completo (guards de vacío).
        #expect(!context.contains("<categorias>"))
        #expect(!context.contains("<gastos_detalle>"))
    }

    @Test("contexto con gastos: incluye la categoría")
    func promptBuilderWithExpenses() {
        // Fecha del MES ACTUAL: buildFinancialContext filtra gastos al mes en curso,
        // así que un gasto de un mes pasado no aparecería (test dependiente de fecha).
        let expense = Expense(
            amount: 100.0,
            name: "Test Expense",
            category: "Comida",
            date: Formatters.isoString(from: Date()),
            paymentMethod: "Tarjeta"
        )

        let context = PromptBuilder.buildFinancialContext(
            user: nil,
            expenses: [expense],
            goals: [],
            monthBudget: nil
        )

        #expect(context.contains("Comida"))
    }
}
