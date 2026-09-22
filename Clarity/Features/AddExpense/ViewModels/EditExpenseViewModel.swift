// EditExpenseViewModel.swift
// ViewModel for editing an existing expense

import Foundation
import Observation

@MainActor
@Observable
class EditExpenseViewModel {
    // MARK: - Form Fields

    /// Texto crudo del campo del importe, como en `AddExpenseViewModel`: con
    /// `value:format:` el campo convertía Double↔String en cada tecla.
    var amountText: String = ""

    /// Importe del formulario. Mismo evaluador que Añadir (coma o punto).
    ///
    /// Mientras el texto sea el de partida vale el importe original TAL CUAL: el
    /// texto enseña dos decimales como mucho, y un gasto de 10 ÷ 3 guardado como
    /// 3,3333… no debe pasar a 3,33 solo por abrir el formulario y cambiar la nota.
    var amount: Double? {
        amountText == textoImporteInicial
            ? original.amount
            : AddExpenseViewModel.evaluateAmount(amountText)
    }

    var name: String = ""
    var category: String = ""
    var subcategory: String?
    var date: Date = Date()
    var paymentMethod: PaymentMethod = .tarjeta
    var notes: String = ""

    // MARK: - Modo regalo (#37)
    var isShared: Bool = false
    var debtors: [Debtor] = []

    // Original Expense ID
    private let expenseId: String
    /// El gasto tal como llegó. El formulario no enseña estos campos, así que
    /// al guardar se copian de aquí: sin ellos la caché local perdía el vínculo
    /// con la hucha y con el recurrente, y borrar el gasto no devolvía el
    /// dinero a la hucha.
    private let original: Expense
    /// Con lo que abre el formulario, para saber si el usuario ha cambiado algo.
    private let textoImporteInicial: String
    private let fechaInicial: Date
    private let metodoInicial: PaymentMethod

    // MARK: - State
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var wasAutoCategorized = false // Usually false for edits, but keeps parity
    
    // MARK: - Dependencies
    private let repository: ExpenseRepositoryProtocol
    /// Las categorías reales del usuario, para casar la sugerencia. Un cierre y
    /// no una copia: pueden terminar de cargarse con la hoja ya abierta.
    private let categorias: () -> [Category]
    /// Espera antes de sugerir categoría. Los tests la ponen a cero.
    @ObservationIgnored var esperaSugerencia: Duration = .milliseconds(400)
    /// La búsqueda en curso; se cancela con cada tecla. Legible desde los tests
    /// para poder esperarla.
    @ObservationIgnored private(set) var tareaSugerencia: Task<Void, Never>?

    // MARK: - Init
    /// `repository` y `categorias` solo se pasan en los tests; la app usa el
    /// repositorio del contenedor y las categorías de `UserDataManager`.
    init(
        expense: Expense,
        repository: ExpenseRepositoryProtocol? = nil,
        categorias: (() -> [Category])? = nil
    ) {
        self.repository = repository ?? DependencyContainer.shared.expenseRepository
        self.categorias = categorias ?? { UserDataManager.shared.categories }
        self.expenseId = expense.id ?? ""
        self.original = expense
        let textoImporte = Self.textoImporte(expense.amount)
        self.textoImporteInicial = textoImporte
        self.amountText = textoImporte
        self.name = expense.name
        self.category = expense.category
        self.subcategory = expense.subcategory
        
        // Parse Date — usar parser UTC compartido (consistente con storage)
        let fecha = Formatters.date(from: expense.date) ?? Date()
        self.date = fecha
        self.fechaInicial = fecha

        // Parse Payment Method
        let metodo = PaymentMethod(rawValue: expense.paymentMethod) ?? .otro // Fallback
        self.paymentMethod = metodo
        self.metodoInicial = metodo

        self.notes = expense.notes ?? ""
        self.isShared = expense.isShared ?? false
        self.debtors = expense.debtors ?? []
    }
    
    // MARK: - Importe

    /// El importe como texto para el campo: sin ceros de sobra (40 y no 40,00;
    /// 12,5 y no 12,50), dos decimales como mucho y con el separador del idioma,
    /// que es el que trae el teclado numérico.
    static func textoImporte(
        _ importe: Double,
        separador: String = Locale.current.decimalSeparator ?? ","
    ) -> String {
        guard importe.isFinite else { return "" }
        var texto = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), importe)
        while texto.hasSuffix("0") { texto.removeLast() }
        if texto.hasSuffix(".") { texto.removeLast() }
        return texto.replacingOccurrences(of: ".", with: separador)
    }

    // MARK: - Descarte

    /// ¿Difiere el formulario del gasto tal como llegó? No basta con que haya
    /// texto —al editar siempre lo hay—: se compara campo a campo con el original.
    var hayCambios: Bool {
        if amount != original.amount { return true }
        if name != original.name { return true }
        if category != original.category || subcategory != original.subcategory { return true }
        if !Calendar.current.isDate(date, inSameDayAs: fechaInicial) { return true }
        if paymentMethod != metodoInicial { return true }
        if notes != (original.notes ?? "") { return true }
        return isShared != (original.isShared ?? false) || debtors != (original.debtors ?? [])
    }

    // MARK: - Sugerencia de categoría

    /// Sugiere categoría a partir de la descripción, SOLO si el gasto no tiene
    /// ninguna: al editar, la categoría que ya hay la eligió el usuario.
    ///
    /// Antes vivía en el `onChange` de la vista y corría entera en cada tecla.
    /// Aquí espera a que el usuario pare de escribir y cancela la búsqueda
    /// anterior, como `AddExpenseViewModel.onNameChange`.
    func onNameChange(_ newName: String) {
        // `name` ya lo actualiza el binding del TextField — no re-asignar.
        guard category.isEmpty, newName.count >= 3 else { return }

        tareaSugerencia?.cancel()
        tareaSugerencia = Task {
            try? await Task.sleep(for: esperaSugerencia)
            // Tras la espera pudo llegar otra tecla, o el usuario elegir categoría.
            guard !Task.isCancelled, category.isEmpty else { return }

            // Solo se aplica si casa con una categoría real del usuario.
            if let sugerencia = SmartTransactionParser.suggestCategory(for: newName),
               let resuelta = AddExpenseViewModel.resolverSugerencia(sugerencia, en: categorias()) {
                category = resuelta.category
                subcategory = resuelta.subcategory
            }
        }
    }

    // MARK: - Validation
    var isValid: Bool {
        guard let amount = amount, amount > 0 else { return false }
        return !name.isEmpty && !category.isEmpty
    }
    
    /// Descarta filas en blanco creadas con el stepper y nunca rellenadas.
    private var cleanedDebtors: [Debtor] {
        debtors.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty || $0.amount > 0 }
    }

    /// Un método de pago que no está en la lista (importado, de otra versión)
    /// se abre como «Otro». Si el usuario no lo cambia, se guarda el original:
    /// antes editar el importe lo reescribía a «Otro» para siempre.
    private var paymentMethodRaw: String {
        let conocido = PaymentMethod(rawValue: original.paymentMethod) != nil
        return (!conocido && paymentMethod == .otro) ? original.paymentMethod : paymentMethod.rawValue
    }

    // MARK: - Methods
    func save() async {
        guard isValid, let amount = amount else { return }
        
        isLoading = true
        
        let dateString = Formatters.localDayString(from: date)
        
        let updatedExpense = Expense(
            id: expenseId,
            amount: amount,
            name: name,
            category: category,
            subcategory: subcategory,
            date: dateString,
            paymentMethod: paymentMethodRaw,
            notes: notes.isEmpty ? nil : notes,
            isDeductible: original.isDeductible,
            recurring: original.recurring,
            isRecurring: original.isRecurring,
            recurringId: original.recurringId,
            goalId: original.goalId,
            isShared: isShared ? true : nil,
            debtors: isShared ? cleanedDebtors : nil,
            createdAt: original.createdAt
        )
        
        do {
            try await repository.updateExpense(updatedExpense)
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            HapticManager.shared.expenseEdited()
            FeedbackManager.shared.show(.success, title: "Gasto actualizado", message: "\(name) guardado correctamente")
        } catch {
            errorMessage = error.safeUserMessage
            showError = true
            FeedbackManager.shared.show(.error, title: "Error al actualizar", message: error.safeUserMessage)
        }

        isLoading = false
    }
}
