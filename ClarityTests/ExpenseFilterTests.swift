// ExpenseFilterTests.swift
// El filtrado por categorías y el rango de fechas del filtro: se optimizaron
// (primera palabra sacada una vez, formatter estático) sin cambiar el resultado.

import Foundation
import Testing
@testable import Clarity

@Suite("ExpenseFilter")
@MainActor
struct ExpenseFilterTests {

    /// Gregoriano y en la zona del dispositivo: como las fechas guardadas.
    private var calendario: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    private func gasto(_ id: String, categoria: String, metodo: String = "Tarjeta") -> Expense {
        Expense(id: id, amount: 10, name: id, category: categoria, date: "2026-09-10", paymentMethod: metodo)
    }

    /// El emparejado tal y como estaba escrito antes de optimizarlo.
    private func emparejadoOriginal(_ categorias: Set<String>, _ gastos: [Expense]) -> [String] {
        gastos.filter { expense in
            categorias.contains { cat in
                expense.category.localizedCaseInsensitiveContains(cat.components(separatedBy: " ").first ?? cat)
            }
        }.compactMap(\.id).sorted()
    }

    @Test("Las categorías se emparejan por la primera palabra, sin distinguir mayúsculas")
    func categoriasPorPrimeraPalabra() {
        let gastos = [
            gasto("comida", categoria: "Alimentacion🫄"),
            gasto("comida-mayus", categoria: "ALIMENTACION compra"),
            gasto("ocio", categoria: "Ocio 🎉"),
            gasto("ocio-cine", categoria: "Ocio - Cine"),
            gasto("viajes", categoria: "Viajes ✈️"),
            gasto("otros", categoria: "Otros"),
        ]
        let filtro = ExpenseFilter(selectedCategories: ["Alimentacion 🍔", "ocio 🎉"], dateRange: .allTime)

        let ids = filtro.apply(to: gastos).compactMap(\.id).sorted()

        #expect(ids == ["comida", "comida-mayus", "ocio", "ocio-cine"])
        #expect(ids == emparejadoOriginal(filtro.selectedCategories, gastos))
    }

    @Test("Una categoría sin espacios se usa entera, y sin categorías no se filtra")
    func categoriasSinEspacios() {
        let gastos = [gasto("a", categoria: "Suscripciones📺"), gasto("b", categoria: "Hogar")]

        let conEmoji = ExpenseFilter(selectedCategories: ["Suscripciones📺"], dateRange: .allTime)
        #expect(conEmoji.apply(to: gastos).map(\.id) == ["a"])
        #expect(conEmoji.apply(to: gastos).compactMap(\.id) == emparejadoOriginal(conEmoji.selectedCategories, gastos))

        let sinCategorias = ExpenseFilter(dateRange: .allTime)
        #expect(sinCategorias.apply(to: gastos).count == 2)
    }

    @Test("El rango sale como yyyy-MM-dd en la zona del dispositivo")
    func formatoDelRango() throws {
        let cal = calendario
        let inicio = try #require(cal.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        let fin = try #require(cal.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 23, minute: 59)))

        let rango = ExpenseFilter.queryRange(for: .custom, customStart: inicio, customEnd: fin)

        #expect(rango.start == "2026-03-01")
        #expect(rango.end == "2026-03-31")
    }

    @Test("Este mes va del día 1 al último día del mes en curso")
    func rangoDeEsteMes() throws {
        let cal = calendario
        let hoy = Date()
        let inicio = try #require(cal.date(from: cal.dateComponents([.year, .month], from: hoy)))
        let dias = try #require(cal.range(of: .day, in: .month, for: hoy)?.count)
        let prefijo = String(format: "%04d-%02d", cal.component(.year, from: hoy), cal.component(.month, from: hoy))

        let rango = ExpenseFilter.queryRange(for: .thisMonth, customStart: hoy, customEnd: hoy)

        #expect(rango.start == Formatters.localDayString(from: inicio))
        #expect(rango.start == "\(prefijo)-01")
        #expect(rango.end == "\(prefijo)-\(String(format: "%02d", dias))")
    }
}
