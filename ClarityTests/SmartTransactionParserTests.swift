// SmartTransactionParserTests.swift
// Tests for voice expense parser

import Foundation
import Testing
@testable import Clarity

@Suite("SmartTransactionParser")
struct SmartTransactionParserTests {

    let parser = SmartTransactionParser()

    // MARK: - Amount Extraction

    @Test("Parse simple euro amount")
    func simpleEuroAmount() async {
        let result = await parser.parse("20 euros en comida", history: [])
        if case .success(let tx) = result {
            #expect(tx.amount == 20)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Parse amount with euro symbol")
    func euroSymbolAmount() async {
        let result = await parser.parse("50€ gasolina", history: [])
        if case .success(let tx) = result {
            #expect(tx.amount == 50)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Parse decimal amount with comma")
    func decimalCommaAmount() async {
        let result = await parser.parse("7,50 euros cafe", history: [])
        if case .success(let tx) = result {
            #expect(tx.amount == Decimal(sign: .plus, exponent: -2, significand: 750))
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Parse composite amount: 'X con Y'")
    func compositeAmountConY() async {
        let result = await parser.parse("7 con 20 euros supermercado", history: [])
        if case .success(let tx) = result {
            #expect(tx.amount == Decimal(sign: .plus, exponent: -2, significand: 720))
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Parse composite amount: 'X coma Y'")
    func compositeAmountComa() async {
        let result = await parser.parse("15 coma 5 euros taxi", history: [])
        if case .success(let tx) = result {
            // "5" left-justified → "50" → 0.50
            #expect(tx.amount == Decimal(sign: .plus, exponent: -1, significand: 155))
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Fail on no amount")
    func noAmountFails() async {
        let result = await parser.parse("cafe con leche", history: [])
        guard case .failure = result else {
            #expect(Bool(false), "Expected failure")
            return
        }
    }

    @Test("Fail on empty input")
    func emptyInputFails() async {
        let result = await parser.parse("", history: [])
        guard case .failure = result else {
            #expect(Bool(false), "Expected failure")
            return
        }
    }

    @Test("Fail on whitespace-only input")
    func whitespaceInputFails() async {
        let result = await parser.parse("   \n  ", history: [])
        guard case .failure = result else {
            #expect(Bool(false), "Expected failure")
            return
        }
    }

    // MARK: - Category Detection

    @Test("Detect supermarket category")
    func detectSupermarket() async {
        let result = await parser.parse("30 euros mercadona", history: [])
        if case .success(let tx) = result {
            #expect(tx.subcategory?.lowercased().contains("supermercado") == true
                    || tx.merchant.lowercased().contains("mercadona"))
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Detect pharmacy category")
    func detectPharmacy() async {
        let result = await parser.parse("12 euros farmacia", history: [])
        if case .success(let tx) = result {
            #expect(tx.category?.contains("Salud") == true)
            #expect(tx.subcategory?.contains("Farmacia") == true)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Detect fuel category")
    func detectFuel() async {
        let result = await parser.parse("45 euros en gasolina", history: [])
        if case .success(let tx) = result {
            // Keywords map gasolina to Transporte🚎 / Gasolina
            let all = [
                tx.category, tx.subcategory, tx.merchant
            ].compactMap { $0?.lowercased() }.joined(separator: " ")
            #expect(all.contains("transporte") || all.contains("gasolina"))
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    // MARK: - Payment Method

    @Test("Detect cash payment")
    func detectCashPayment() async {
        let result = await parser.parse("10 euros en efectivo taxi", history: [])
        if case .success(let tx) = result {
            #expect(tx.paymentMethod == "Efectivo")
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Detect bizum payment")
    func detectBizumPayment() async {
        let result = await parser.parse("25 euros por bizum cena", history: [])
        if case .success(let tx) = result {
            #expect(tx.paymentMethod == "Bizum")
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Default no payment method when not mentioned")
    func noPaymentMethod() async {
        let result = await parser.parse("15 euros cafe", history: [])
        if case .success(let tx) = result {
            #expect(tx.paymentMethod == nil)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    // MARK: - Command Stripping

    @Test("Strip 'añade' command from merchant name")
    func stripAddCommand() async {
        let result = await parser.parse("añade 20 euros en comida", history: [])
        if case .success(let tx) = result {
            let name = tx.merchant.lowercased()
            #expect(!name.contains("añade"))
            #expect(!name.contains("anade"))
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Strip 'he gastado' meta-command")
    func stripMetaCommand() async {
        let result = await parser.parse("me he gastado 50 euros en ropa", history: [])
        if case .success(let tx) = result {
            let name = tx.merchant.lowercased()
            #expect(!name.contains("gastado"))
            #expect(!name.contains("he"))
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    // MARK: - Multi-Expense Parsing

    @Test("Parse two expenses separated by 'y'")
    func parseTwoExpenses() async {
        let results = await parser.parseMultiple(
            "10 euros tabaco y 5 euros cafe",
            history: []
        )
        #expect(results.count == 2)
        if results.count == 2 {
            #expect(results[0].amount == 10)
            #expect(results[1].amount == 5)
        }
    }

    @Test("Single expense without connector stays single")
    func singleExpenseNoSplit() async {
        let results = await parser.parseMultiple(
            "30 euros supermercado",
            history: []
        )
        #expect(results.count == 1)
    }

    @Test("Don't split when second part has no amount")
    func dontSplitWithoutAmount() async {
        let results = await parser.parseMultiple(
            "20 euros y algo mas",
            history: []
        )
        // Should NOT split because "algo mas" has no amount
        #expect(results.count == 1)
    }

    // MARK: - Confidence

    @Test("Higher confidence with known keyword")
    func keywordConfidence() async {
        let result = await parser.parse("30 euros mercadona", history: [])
        if case .success(let tx) = result {
            #expect(tx.confidence >= 0.7)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Lower confidence with unknown merchant")
    func unknownMerchantConfidence() async {
        let result = await parser.parse("30 euros xyzabc", history: [])
        if case .success(let tx) = result {
            #expect(tx.confidence < 0.8)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    // MARK: - History Matching

    @Test("Match from expense history")
    func historyMatch() async {
        let history = [
            Expense(
                id: "1",
                amount: 5.0,
                name: "Starbucks",
                category: "Cafeterias",
                subcategory: "Cafe",
                date: "2026-04-01",
                paymentMethod: "Tarjeta"
            )
        ]
        let result = await parser.parse("4 euros en starbucks", history: history)
        if case .success(let tx) = result {
            // Parser should match from history (exact or contains match)
            #expect(tx.category != nil)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    // MARK: - Suggest Category (Synchronous)

    @Test("Suggest category for known keyword")
    func suggestKnownKeyword() {
        let result = parser.suggestCategory(for: "mercadona")
        #expect(result != nil)
        #expect(result?.subcategory == "Supermercado")
    }

    @Test("Suggest nil for unknown text")
    func suggestUnknown() {
        let result = parser.suggestCategory(for: "xyzabc123")
        #expect(result == nil)
    }

    // MARK: - Number Words

    @Test("Parse Spanish number word: veinte")
    func numberWordVeinte() async {
        let result = await parser.parse("veinte euros cafe", history: [])
        if case .success(let tx) = result {
            #expect(tx.amount == 20)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("Parse Spanish number word: cincuenta")
    func numberWordCincuenta() async {
        let result = await parser.parse("cincuenta euros gasolina", history: [])
        if case .success(let tx) = result {
            #expect(tx.amount == 50)
        } else {
            #expect(Bool(false), "Expected success")
        }
    }
}
