// AmountEvaluatorTests.swift
// Regresión del evaluador de importes (sumar fanta + patatas al meter un gasto).
// Es lógica pura y sin NSExpression → a prueba de crashes con entradas raras.

import Testing
import Foundation
@testable import Clarity

@Suite("Evaluador de importes", .serialized)
@MainActor
struct AmountEvaluatorTests {

    @Test("número simple con coma o punto")
    func simpleNumber() {
        #expect(AddExpenseViewModel.evaluateAmount("1,50") == 1.5)
        #expect(AddExpenseViewModel.evaluateAmount("2.30") == 2.3)
        #expect(AddExpenseViewModel.evaluateAmount("10") == 10)
    }

    @Test("suma de importes (fanta + patatas)")
    func sum() {
        #expect(AddExpenseViewModel.evaluateAmount("1,50 + 2") == 3.5)
        #expect(AddExpenseViewModel.evaluateAmount("1 + 2 + 3") == 6)
        #expect(AddExpenseViewModel.evaluateAmount("2,50+2,50") == 5)
    }

    @Test("resta de importes")
    func subtract() {
        #expect(AddExpenseViewModel.evaluateAmount("5 - 1,50") == 3.5)
        #expect(AddExpenseViewModel.evaluateAmount("10 - 2 - 3") == 5)
    }

    @Test("multiplicación y división")
    func multiplyDivide() {
        #expect(AddExpenseViewModel.evaluateAmount("2 × 3") == 6)
        #expect(AddExpenseViewModel.evaluateAmount("6 ÷ 2") == 3)
        // También acepta * y / crudos (por si se pegan desde otro sitio).
        #expect(AddExpenseViewModel.evaluateAmount("2*3") == 6)
        #expect(AddExpenseViewModel.evaluateAmount("6/2") == 3)
    }

    @Test("precedencia: × y ÷ antes que + y −")
    func precedence() {
        #expect(AddExpenseViewModel.evaluateAmount("2 + 3 × 4") == 14)
        #expect(AddExpenseViewModel.evaluateAmount("10 - 6 ÷ 2") == 7)
        #expect(AddExpenseViewModel.evaluateAmount("1,50 × 2 + 1") == 4)
    }

    @Test("mezcla suma y resta")
    func mixed() {
        #expect(AddExpenseViewModel.evaluateAmount("5 + 2 - 1") == 6)
    }

    @Test("entradas inválidas → nil (sin crash)")
    func invalid() {
        #expect(AddExpenseViewModel.evaluateAmount("") == nil)
        #expect(AddExpenseViewModel.evaluateAmount("1 + ") == nil)
        #expect(AddExpenseViewModel.evaluateAmount("1 + + 2") == nil)
        #expect(AddExpenseViewModel.evaluateAmount("abc") == nil)
        #expect(AddExpenseViewModel.evaluateAmount("5 ÷ 0") == nil)  // división por cero
        #expect(AddExpenseViewModel.evaluateAmount("× 2") == nil)    // operador suelto
    }

    @Test("signo inicial se acepta como número (Double lo parsea)")
    func leadingSign() {
        #expect(AddExpenseViewModel.evaluateAmount("+ 2") == 2)
        #expect(AddExpenseViewModel.evaluateAmount("-1,5") == -1.5)
    }

    @Test("espacios irrelevantes")
    func whitespace() {
        #expect(AddExpenseViewModel.evaluateAmount("  1,50   +   2  ") == 3.5)
    }
}
