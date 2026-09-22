// CategoriaAlimentacionTests.swift
// La categoría de comida de fábrica cambia de nombre en la 2.4.0: de
// «Alimentacion🫄» (sin tilde y con una persona embarazada) a «Alimentación 🍴».
// Solo para las cuentas nuevas; las de antes conservan la suya, y la voz y los
// formularios tienen que seguir casando sus sugerencias con ella.

import Testing
import Foundation
@testable import Clarity

@Suite("Categoría de comida (2.4.0)")
@MainActor
struct CategoriaAlimentacionTests {

    private func cat(_ nombre: String, _ subs: [String] = []) -> Clarity.Category {
        Clarity.Category(id: nombre, name: nombre, color: "#6366F1", subcategories: subs,
                         order: 0, createdAt: nil, updatedAt: nil)
    }

    @Test("una cuenta nueva recibe «Alimentación 🍴», con id igual al nombre")
    func fabricaNueva() throws {
        let categorias = CategorySeeding.categoriasDeFabrica()
        #expect(categorias.count == DefaultCategory.allCases.count)
        let comida = try #require(categorias.first)
        #expect(comida.name == "Alimentación 🍴")
        #expect(comida.id == comida.name)
        #expect(!categorias.map(\.name).contains(CategorySeeding.alimentacionAnterior))
    }

    @Test("una cuenta vieja sin mapa y con gastos de comida recibe el nombre de antes; el resto no cambia")
    func fabricaConNombreAnterior() {
        let nuevas = CategorySeeding.categoriasDeFabrica()
        let viejas = CategorySeeding.categoriasDeFabrica(alimentacionAnterior: true)
        #expect(viejas.first?.name == "Alimentacion🫄")
        #expect(viejas.first?.id == "Alimentacion🫄")
        #expect(Array(viejas.dropFirst()).map(\.name) == Array(nuevas.dropFirst()).map(\.name))
    }

    @Test("el id nuevo se puede usar como segmento de field-path")
    func idSinCaracteresProhibidos() {
        #expect(!CategorySeeding.containsForbiddenChars(DefaultCategory.alimentacion.rawValue))
    }

    @Test("la clave de categoría iguala el nombre viejo y el nuevo, y no mezcla otras")
    func clave() {
        #expect("Alimentacion🫄".claveDeCategoria == "Alimentación 🍴".claveDeCategoria)
        #expect("Alimentación 🍴".claveDeCategoria == "alimentacion")
        #expect("Ocio 🍻".claveDeCategoria != "Alimentación 🍴".claveDeCategoria)
        #expect("Coche-Moto🏎️🏍️".claveDeCategoria == "cochemoto")
    }

    @Test("la sugerencia nueva casa con la categoría de antes de una cuenta vieja")
    func sugerenciaNuevaEnCuentaVieja() throws {
        let propias = [cat("Ocio 🍻", ["Bares"]), cat("Alimentacion🫄", ["Supermercado", "Restaurantes"])]
        let r = try #require(AddExpenseViewModel.resolverSugerencia(("Alimentación 🍴", "Supermercado"), en: propias))
        #expect(r.category == "Alimentacion🫄")
        #expect(r.subcategory == "Supermercado")
    }

    @Test("y la de antes casa con la nueva")
    func sugerenciaViejaEnCuentaNueva() throws {
        let propias = [cat("Alimentación 🍴", ["Cafeterías"])]
        let r = try #require(AddExpenseViewModel.resolverSugerencia(("Alimentacion🫄", "Cafeterías"), en: propias))
        #expect(r.category == "Alimentación 🍴")
        #expect(r.subcategory == "Cafeterías")
    }

    @Test("el parser sugiere la categoría nueva")
    func parserSugiereLaNueva() throws {
        let s = try #require(SmartTransactionParser.suggestCategory(for: "mercadona"))
        #expect(s.category == DefaultCategory.alimentacion.rawValue)
    }

    @Test("sin categoría con ese nombre, sigue valiendo la subcategoría")
    func porSubcategoria() throws {
        let propias = [cat("Comida 🥦", ["Supermercado"])]
        let r = try #require(AddExpenseViewModel.resolverSugerencia(("Alimentación 🍴", "Supermercado"), en: propias))
        #expect(r.category == "Comida 🥦")
    }
}
