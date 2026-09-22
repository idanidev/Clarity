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

    // MARK: - Decodificación tolerante

    /// Un filtro guardado, con los campos que se le digan cambiados.
    private func json(_ cambios: [String: Any]) throws -> Data {
        var campos: [String: Any] = [
            "id": "11111111-2222-3333-4444-555555555555",
            "name": "Mío",
            "selectedCategories": ["Ocio"],
            "selectedPaymentMethods": [],
            "dateRange": "Mes anterior",
            "sortBy": "Mayor importe",
            "showOnlyRecurring": true,
        ]
        for (clave, valor) in cambios { campos[clave] = valor }
        return try JSONSerialization.data(withJSONObject: campos)
    }

    @Test("Un rango de fechas desconocido cae al de por defecto sin tumbar el filtro")
    func rangoDesconocido() throws {
        // P. ej. un rango nuevo guardado desde una versión posterior de la app.
        let filtro = try JSONDecoder().decode(
            ExpenseFilter.self, from: try json(["dateRange": "Últimos 2 años"]))

        #expect(filtro.dateRange == .thisMonth)
        // El resto del filtro sobrevive.
        #expect(filtro.name == "Mío")
        #expect(filtro.selectedCategories == ["Ocio"])
        #expect(filtro.sortBy == .amountDesc)
        #expect(filtro.showOnlyRecurring)
    }

    @Test("Un orden desconocido cae al de por defecto sin tumbar el filtro")
    func ordenDesconocido() throws {
        let filtro = try JSONDecoder().decode(
            ExpenseFilter.self, from: try json(["sortBy": "Por categoría"]))

        #expect(filtro.sortBy == .dateDesc)
        #expect(filtro.dateRange == .lastMonth)
        #expect(filtro.name == "Mío")
    }

    @Test("Los valores conocidos y los ausentes se leen como siempre")
    func valoresConocidos() throws {
        let completo = try JSONDecoder().decode(ExpenseFilter.self, from: try json([:]))
        #expect(completo.dateRange == .lastMonth)
        #expect(completo.sortBy == .amountDesc)

        let sinCampos = try JSONDecoder().decode(
            ExpenseFilter.self, from: Data(#"{"name":"Vacío"}"#.utf8))
        #expect(sinCampos.dateRange == .thisMonth)
        #expect(sinCampos.sortBy == .dateDesc)
    }

    @Test("Un filtro con un valor desconocido ya no se cae de la lista de guardados")
    func listaDeGuardados() throws {
        // `UserDocument` descarta los filtros que no decodifican: con un rango
        // desconocido el filtro desaparecía de «Mis filtros».
        let bueno = try JSONSerialization.jsonObject(with: try json([:]))
        let raro = try JSONSerialization.jsonObject(with: try json(["dateRange": "???", "name": "Raro"]))
        let documento = try JSONSerialization.data(withJSONObject: ["savedFilters": [bueno, raro]])

        let usuario = try JSONDecoder().decode(UserDocument.self, from: documento)

        #expect(usuario.savedFilters?.map(\.name) == ["Mío", "Raro"])
    }

    @Test("Ida y vuelta: lo que se guarda se lee igual")
    func idaYVuelta() throws {
        let filtro = ExpenseFilter(name: "Año", dateRange: .lastYear, sortBy: .nameAsc)
        let vuelta = try JSONDecoder().decode(ExpenseFilter.self, from: try JSONEncoder().encode(filtro))
        #expect(vuelta.dateRange == .lastYear)
        #expect(vuelta.sortBy == .nameAsc)
    }
}
