// Expense.swift
// Expense data model matching Firestore structure

import Foundation

struct Expense: Identifiable, Hashable, Sendable, Codable {
    var id: String?
    let amount: Double
    let name: String
    let category: String
    let subcategory: String?
    let date: String // "YYYY-MM-DD"
    let paymentMethod: String
    let notes: String?
    let isDeductible: Bool?
    let recurring: Bool?
    let isRecurring: Bool?
    let recurringId: String?
    let goalId: String?
    /// Modo regalo: el gasto lo adelantas tú y hay gente que te lo devuelve (#37).
    let isShared: Bool?
    /// Quién te debe y cuánto. nil/vacío = gasto normal.
    let debtors: [Debtor]?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Equatable/Hashable por campos visibles (excluye createdAt/updatedAt —
    // cambian en cada save sin afectar UI → menos diffs/re-render en listas).
    static func == (lhs: Expense, rhs: Expense) -> Bool {
        lhs.id == rhs.id
            && lhs.amount == rhs.amount
            && lhs.name == rhs.name
            && lhs.category == rhs.category
            && lhs.subcategory == rhs.subcategory
            && lhs.date == rhs.date
            && lhs.paymentMethod == rhs.paymentMethod
            && lhs.notes == rhs.notes
            && lhs.isRecurring == rhs.isRecurring
            && lhs.recurringId == rhs.recurringId
            && lhs.goalId == rhs.goalId
            && lhs.isShared == rhs.isShared
            && lhs.debtors == rhs.debtors
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(amount)
        hasher.combine(name)
        hasher.combine(category)
        hasher.combine(date)
    }

    // Guaranteed unique ID for ForEach (fallback if Firestore ID is nil)
    var stableId: String {
        id ?? "\(name)_\(date)_\(amount)"
    }
    
    /// Gasto en modo regalo con alguien que aún no ha devuelto su parte.
    var hasPendingDebt: Bool {
        (isShared ?? false) && (debtors?.hasPending ?? false)
    }

    /// Lo que te queda por recuperar de este gasto.
    var pendingDebtAmount: Double {
        guard isShared ?? false else { return 0 }
        return debtors?.pendingAmount ?? 0
    }

    /// Lo que realmente te cuesta a ti una vez te devuelvan lo pendiente.
    var netAmount: Double {
        guard isShared ?? false, let debtors else { return amount }
        return max(0, amount - debtors.reduce(0) { $0 + $1.amount })
    }

    // Computed property for Date
    var dateAsDate: Date {
        Formatters.date(from: date) ?? Date.distantPast
    }
    
    nonisolated init(
        id: String? = nil,
        amount: Double,
        name: String,
        category: String,
        subcategory: String? = nil,
        date: String,
        paymentMethod: String = "Tarjeta",
        notes: String? = nil,
        isDeductible: Bool? = nil,
        recurring: Bool? = nil,
        isRecurring: Bool? = nil,
        recurringId: String? = nil,
        goalId: String? = nil,
        isShared: Bool? = nil,
        debtors: [Debtor]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
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
        self.recurring = recurring
        self.isRecurring = isRecurring
        self.recurringId = recurringId
        self.goalId = goalId
        self.isShared = isShared
        self.debtors = debtors
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Helpers
extension Expense {
    static var empty: Expense {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        return Expense(
            amount: 0,
            name: "",
            category: "",
            date: formatter.string(from: Date())
        )
    }
}
    


// MARK: - Sample Data
extension Expense {
    static let sample = Expense(
        id: "1",
        amount: 25.50,
        name: "Café con amigos",
        category: "Alimentacion🫄",
        subcategory: "Cafeterías",
        date: "2026-01-02",
        paymentMethod: "Tarjeta"
    )
    
    static let samples: [Expense] = [
        Expense(id: "1", amount: 45.00, name: "Compra semanal", category: "Alimentacion🫄", subcategory: "Supermercado", date: "2026-01-02", paymentMethod: "Tarjeta"),
        Expense(id: "2", amount: 15.99, name: "Netflix", category: "Suscripciones📺", subcategory: "Netflix", date: "2026-01-01", paymentMethod: "Tarjeta"),
        Expense(id: "3", amount: 8.50, name: "Desayuno", category: "Alimentacion🫄", subcategory: "Cafeterías", date: "2026-01-02", paymentMethod: "Efectivo"),
    ]
}
