// EditExpenseViewModelTests.swift
// Editar un gasto no toca lo que el formulario no enseña.

import Testing
import Foundation
@testable import Clarity

@MainActor
struct EditExpenseViewModelTests {

    private func gasto(
        amount: Double = 40,
        category: String = "Ropa",
        subcategory: String? = "Calzado",
        paymentMethod: String = "Tarjeta"
    ) -> Expense {
        Expense(id: "g1", amount: amount, name: "Zapatillas", category: category, subcategory: subcategory,
                date: "2026-09-10", paymentMethod: paymentMethod, isDeductible: true,
                isRecurring: true, recurringId: "regla-1", goalId: "hucha-1")
    }

    /// Una categoría real del usuario que casa con lo que el parser sugiere para
    /// «mercadona» (subcategoría «Supermercado»).
    private let categorias = [
        Category(id: "casa", name: "Casa", color: "#FFFFFF", subcategories: ["Supermercado"], order: 0)
    ]

    // MARK: - Campos ocultos

    @Test("Guardar conserva la hucha, el recurrente y el resto de campos ocultos")
    func conservaCamposOcultos() async {
        let repo = MockExpenseRepository()
        repo.expenses = [gasto()]
        let vm = EditExpenseViewModel(expense: gasto(), repository: repo)

        vm.amountText = "55"
        await vm.save()

        let guardado = repo.expenses.first
        #expect(guardado?.amount == 55)
        #expect(guardado?.goalId == "hucha-1")
        #expect(guardado?.recurringId == "regla-1")
        #expect(guardado?.isRecurring == true)
        #expect(guardado?.isDeductible == true)
    }

    @Test("Un método de pago fuera de la lista se conserva si no se cambia")
    func metodoDePagoDesconocido() async {
        let repo = MockExpenseRepository()
        repo.expenses = [gasto(paymentMethod: "Cheque regalo")]
        let vm = EditExpenseViewModel(expense: gasto(paymentMethod: "Cheque regalo"), repository: repo)

        vm.amountText = "12"
        await vm.save()
        #expect(repo.expenses.first?.paymentMethod == "Cheque regalo")

        vm.paymentMethod = .efectivo
        await vm.save()
        #expect(repo.expenses.first?.paymentMethod == PaymentMethod.efectivo.rawValue)
    }

    // MARK: - Importe como texto

    @Test("El texto inicial sale del importe sin ceros de sobra", arguments: [
        (40.0, "40"), (12.5, "12,5"), (12.50, "12,5"), (9.99, "9,99"),
        (1234.5, "1234,5"), (0.1 + 0.2, "0,3"), (10.0 / 3, "3,33"), (0, "0"),
    ])
    func textoInicial(importe: Double, esperado: String) {
        #expect(EditExpenseViewModel.textoImporte(importe, separador: ",") == esperado)
    }

    @Test("El separador decimal es el del idioma")
    func separadorDelIdioma() {
        #expect(EditExpenseViewModel.textoImporte(12.5, separador: ".") == "12.5")
    }

    @Test("El importe se lee con coma o con punto, como en Añadir", arguments: [
        ("12,5", 12.5), ("12.5", 12.5), ("7", 7.0), (" 3,20 ", 3.2), ("1,50 + 2", 3.5),
    ])
    func parseoDelImporte(texto: String, esperado: Double) {
        let vm = EditExpenseViewModel(expense: gasto(), repository: MockExpenseRepository())
        vm.amountText = texto
        #expect(vm.amount == esperado)
        #expect(vm.isValid)
    }

    @Test("Un importe vacío, ilegible o a cero no se puede guardar", arguments: ["", "abc", "12,5,3", "0", "-4"])
    func importeInvalido(texto: String) async {
        let repo = MockExpenseRepository()
        repo.expenses = [gasto()]
        let vm = EditExpenseViewModel(expense: gasto(), repository: repo)

        vm.amountText = texto
        #expect(!vm.isValid)

        await vm.save()
        #expect(repo.expenses.first?.amount == 40)
    }

    @Test("Sin tocar el importe se guarda el original, con todos sus decimales")
    func importeIntactoConservaDecimales() async {
        let tercio = 10.0 / 3
        let repo = MockExpenseRepository()
        repo.expenses = [gasto(amount: tercio)]
        let vm = EditExpenseViewModel(expense: gasto(amount: tercio), repository: repo)

        // El campo enseña 3,33, pero el gasto sigue valiendo 3,3333…
        #expect(vm.amountText == EditExpenseViewModel.textoImporte(tercio))
        #expect(vm.amount == tercio)

        vm.notes = "Compartido entre tres"
        await vm.save()
        #expect(repo.expenses.first?.amount == tercio)
        #expect(repo.expenses.first?.notes == "Compartido entre tres")
    }

    // MARK: - Descarte

    @Test("Recién abierto no hay cambios")
    func sinCambiosAlAbrir() {
        let vm = EditExpenseViewModel(expense: gasto(), repository: MockExpenseRepository())
        #expect(!vm.hayCambios)
    }

    @Test("Un método de pago fuera de la lista no cuenta como cambio al abrir")
    func metodoDesconocidoNoEsCambio() {
        let vm = EditExpenseViewModel(expense: gasto(paymentMethod: "Cheque regalo"),
                                      repository: MockExpenseRepository())
        #expect(!vm.hayCambios)
    }

    @Test("Cambiar un campo es un cambio; dejarlo como estaba, no")
    func cambiosYVueltaAtras() {
        let vm = EditExpenseViewModel(expense: gasto(), repository: MockExpenseRepository())

        vm.name = "Zapatillas de correr"
        #expect(vm.hayCambios)
        vm.name = "Zapatillas"
        #expect(!vm.hayCambios)

        vm.amountText = "41"
        #expect(vm.hayCambios)
        // Otro texto, mismo importe: no hay nada que perder.
        vm.amountText = "40,0"
        #expect(!vm.hayCambios)
        // Borrar el importe sí es un cambio, aunque no haya texto.
        vm.amountText = ""
        #expect(vm.hayCambios)
    }

    @Test("Categoría, fecha, método, notas y modo regalo cuentan como cambio")
    func cadaCampoCuenta() {
        let repo = MockExpenseRepository()
        let cambios: [(EditExpenseViewModel) -> Void] = [
            { $0.category = "Deporte" },
            { $0.subcategory = nil },
            { $0.date = $0.date.addingTimeInterval(3 * 24 * 3600) },
            { $0.paymentMethod = .efectivo },
            { $0.notes = "Rebajas" },
            { $0.isShared = true },
            { $0.debtors = [Debtor(name: "Ana", amount: 20)] },
        ]
        for cambio in cambios {
            let vm = EditExpenseViewModel(expense: gasto(), repository: repo)
            cambio(vm)
            #expect(vm.hayCambios)
        }
    }

    // MARK: - Sugerencia de categoría

    @Test("Sin categoría, la descripción sugiere una de las del usuario")
    func sugiereConCategoriaVacia() async {
        let vm = EditExpenseViewModel(expense: gasto(category: "", subcategory: nil),
                                      repository: MockExpenseRepository(),
                                      categorias: { [categorias] in categorias })
        vm.esperaSugerencia = .zero

        vm.name = "Mercadona"
        vm.onNameChange("Mercadona")
        await vm.tareaSugerencia?.value

        #expect(vm.category == "Casa")
        #expect(vm.subcategory == "Supermercado")
    }

    @Test("Con categoría ya puesta no se sugiere nada")
    func noSugiereConCategoria() async {
        let vm = EditExpenseViewModel(expense: gasto(),
                                      repository: MockExpenseRepository(),
                                      categorias: { [categorias] in categorias })
        vm.esperaSugerencia = .zero

        vm.onNameChange("Mercadona")
        await vm.tareaSugerencia?.value

        #expect(vm.tareaSugerencia == nil)
        #expect(vm.category == "Ropa")
        #expect(vm.subcategory == "Calzado")
    }

    @Test("Una sugerencia que no casa con ninguna categoría del usuario no se aplica")
    func sugerenciaSinCategoriaReal() async {
        let vm = EditExpenseViewModel(expense: gasto(category: "", subcategory: nil),
                                      repository: MockExpenseRepository(),
                                      categorias: { [] })
        vm.esperaSugerencia = .zero

        vm.onNameChange("Mercadona")
        await vm.tareaSugerencia?.value

        #expect(vm.category.isEmpty)
    }

    @Test("Cada tecla cancela la búsqueda anterior")
    func cancelaLaBusquedaAnterior() async {
        let vm = EditExpenseViewModel(expense: gasto(category: "", subcategory: nil),
                                      repository: MockExpenseRepository(),
                                      categorias: { [categorias] in categorias })
        vm.esperaSugerencia = .milliseconds(50)

        vm.onNameChange("Mercadona")
        let primera = vm.tareaSugerencia
        vm.onNameChange("Xyzabc123")
        await primera?.value
        await vm.tareaSugerencia?.value

        // La primera («Mercadona») se canceló; la segunda no sugiere nada.
        #expect(primera?.isCancelled == true)
        #expect(vm.category.isEmpty)
    }

    @Test("Si el usuario elige categoría durante la espera, la sugerencia no la pisa")
    func noPisaLaCategoriaElegida() async {
        let vm = EditExpenseViewModel(expense: gasto(category: "", subcategory: nil),
                                      repository: MockExpenseRepository(),
                                      categorias: { [categorias] in categorias })
        vm.esperaSugerencia = .milliseconds(50)

        vm.onNameChange("Mercadona")
        vm.category = "Ocio"
        await vm.tareaSugerencia?.value

        #expect(vm.category == "Ocio")
    }
}
