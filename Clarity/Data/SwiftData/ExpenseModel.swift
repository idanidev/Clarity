// ExpenseModel.swift
// SwiftData model for Expense entity

import Foundation
import OSLog
import SwiftData

// A nivel de archivo y no dentro de la clase: `@Model` reescribe las
// propiedades almacenadas, y esto no es un dato del gasto.
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "ExpenseModel")

@Model
final class ExpenseModel {
    @Attribute(.unique) var id: String
    var amount: Double
    var name: String
    var category: String
    var subcategory: String?
    var date: Date
    var paymentMethod: String
    var notes: String?
    var isDeductible: Bool
    var recurringId: String?
    var isRecurring: Bool?
    var goalId: String?

    /// Modo regalo (#37). Los deudores se guardan serializados en JSON para que
    /// añadirlos sea una migración ligera sobre el store existente.
    var isShared: Bool?
    var debtorsData: Data?

    // Audit
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        amount: Double,
        name: String,
        category: String,
        subcategory: String? = nil,
        date: Date,
        paymentMethod: String,
        notes: String? = nil,
        isDeductible: Bool = false,
        recurringId: String? = nil,
        isRecurring: Bool? = nil,
        goalId: String? = nil,
        isShared: Bool? = nil,
        debtorsData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.date = date
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.isDeductible = isDeductible
        self.recurringId = recurringId
        self.isRecurring = isRecurring
        self.goalId = goalId
        self.isShared = isShared
        self.debtorsData = debtorsData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Mapping Helpers
extension ExpenseModel {
    convenience init(from domain: Expense) {
        let fechaLeida = Formatters.date(from: domain.date)
        if fechaLeida == nil {
            // Con `distantPast` el gasto se guarda, pero cae fuera de cualquier
            // mes y de cualquier ventana de sincronización: «ha desaparecido».
            logger.error("Gasto \(domain.id ?? "sin id", privacy: .public) con fecha ilegible; se guarda con distantPast")
        }
        let dateObj = fechaLeida ?? Date.distantPast

        self.init(
            id: domain.id ?? UUID().uuidString,
            amount: domain.amount,
            name: domain.name,
            category: domain.category,
            subcategory: domain.subcategory,
            date: dateObj,
            paymentMethod: domain.paymentMethod,
            notes: domain.notes,
            isDeductible: domain.isDeductible ?? false,
            recurringId: domain.recurringId,
            isRecurring: domain.isRecurring,
            goalId: domain.goalId,
            isShared: domain.isShared,
            debtorsData: ExpenseModel.encodeDebtors(domain.debtors)
        )
    }

    /// Copia en el modelo lo que trae el dominio. Devuelve `false` si no había
    /// nada distinto: así una sincronización sin novedades no ensucia el
    /// contexto ni reescribe filas.
    @discardableResult
    func apply(_ domain: Expense) -> Bool {
        let fecha = Formatters.date(from: domain.date) ?? date
        // Sin deudores a ningún lado no hay nada que codificar: ahorra un
        // JSONEncoder por gasto en cada sincronización.
        let hayDeudores = domain.debtors?.isEmpty == false || debtorsData != nil
        let deudores = hayDeudores ? ExpenseModel.encodeDebtors(domain.debtors) : nil
        // Igual que en `init(from:)`: un gasto que llega a una fila que ya
        // existe tiene que quedar como si se insertara de cero. Estos tres no
        // se copiaban, y un gasto marcado como deducible o enlazado a su regla
        // recurrente desde otro dispositivo se quedaba con el valor viejo.
        let deducible = domain.isDeductible ?? false
        guard amount != domain.amount
            || name != domain.name
            || category != domain.category
            || subcategory != domain.subcategory
            || date != fecha
            || paymentMethod != domain.paymentMethod
            || notes != domain.notes
            || goalId != domain.goalId
            || isShared != domain.isShared
            || debtorsData != deudores
            || isDeductible != deducible
            || recurringId != domain.recurringId
            || isRecurring != domain.isRecurring
        else { return false }
        amount = domain.amount
        name = domain.name
        category = domain.category
        subcategory = domain.subcategory
        date = fecha
        paymentMethod = domain.paymentMethod
        notes = domain.notes
        goalId = domain.goalId
        isShared = domain.isShared
        debtorsData = deudores
        isDeductible = deducible
        recurringId = domain.recurringId
        isRecurring = domain.isRecurring
        updatedAt = Date()
        return true
    }

    func toDomain() -> Expense {
        Expense(
            id: self.id,
            amount: self.amount,
            name: self.name,
            category: self.category,
            subcategory: self.subcategory,
            date: Formatters.isoString(from: self.date),
            paymentMethod: self.paymentMethod,
            notes: self.notes,
            isDeductible: self.isDeductible,
            isRecurring: self.isRecurring,
            recurringId: self.recurringId,
            goalId: self.goalId,
            isShared: self.isShared,
            debtors: ExpenseModel.decodeDebtors(self.debtorsData)
        )
    }

    // Si alguno de los dos falla, el gasto pierde a sus deudores en la caché
    // —deja de salir en «Me deben»— y antes no quedaba ni una línea. Sin
    // nombres ni importes en el mensaje: solo cuántos y cuánto ocupan.

    static func encodeDebtors(_ debtors: [Debtor]?) -> Data? {
        guard let debtors, !debtors.isEmpty else { return nil }
        do {
            return try JSONEncoder().encode(debtors)
        } catch {
            logger.error("No se pudieron guardar \(debtors.count) deudores en la caché: \(error.localizedDescription)")
            return nil
        }
    }

    static func decodeDebtors(_ data: Data?) -> [Debtor]? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode([Debtor].self, from: data)
        } catch {
            logger.error("Deudores ilegibles en la caché (\(data.count) bytes): \(error.localizedDescription)")
            return nil
        }
    }
}
