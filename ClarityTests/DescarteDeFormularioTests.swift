// DescarteDeFormularioTests.swift
// Cuándo pregunta «Nuevo gasto» antes de tirar lo escrito (`confirmarDescarte`).

import Testing
import Foundation
@testable import Clarity

@MainActor
struct DescarteDeFormularioTests {

    private func formulario() -> AddExpenseViewModel {
        AddExpenseViewModel(repository: MockExpenseRepository())
    }

    @Test("Recién abierto no hay nada que perder")
    func vacio() {
        #expect(!formulario().hayCambios)
    }

    @Test("Lo dictado es el punto de partida, no un cambio")
    func descripcionDictada() {
        let vm = formulario()
        vm.descripcionInicial = "Cena con Marta"
        vm.name = "Cena con Marta"
        #expect(!vm.hayCambios)

        vm.name = "Cena con Marta y Luis"
        #expect(vm.hayCambios)
    }

    @Test("La categoría que pone el autocategorizador no cuenta; la que elige el usuario, sí")
    func categoriaAutomatica() {
        let vm = formulario()
        vm.descripcionInicial = "Mercadona"
        vm.name = "Mercadona"
        vm.category = "Casa"
        vm.subcategory = "Supermercado"
        vm.wasAutoCategorized = true
        #expect(!vm.hayCambios)

        // Abrir el selector de categoría la hace suya.
        vm.wasAutoCategorized = false
        #expect(vm.hayCambios)
    }

    @Test("Cualquier campo que toque el usuario es un cambio")
    func cadaCampoCuenta() {
        let cambios: [(AddExpenseViewModel) -> Void] = [
            { $0.amountText = "12" },
            { $0.name = "Pan" },
            { $0.category = "Casa" },
            { $0.date = $0.date.addingTimeInterval(-3 * 24 * 3600) },
            { $0.paymentMethod = .efectivo },
            { $0.notes = "Con ticket" },
            { $0.isShared = true },
            { $0.debtors = [Debtor(name: "Ana", amount: 5)] },
        ]
        for cambio in cambios {
            let vm = formulario()
            cambio(vm)
            #expect(vm.hayCambios)
        }
    }

    @Test("Un importe con solo espacios no es un cambio; borrarlo todo tampoco")
    func importeEnBlanco() {
        let vm = formulario()
        vm.amountText = "  "
        #expect(!vm.hayCambios)

        vm.amountText = "8"
        vm.amountText = ""
        #expect(!vm.hayCambios)
    }
}
