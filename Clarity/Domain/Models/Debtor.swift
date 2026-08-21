// Debtor.swift
// Persona que tiene que devolverte parte de un gasto compartido / regalo (#37).

import Foundation

struct Debtor: Identifiable, Hashable, Sendable, Codable {
    var id: String
    var name: String
    var amount: Double
    var isPaid: Bool

    nonisolated init(
        id: String = UUID().uuidString,
        name: String,
        amount: Double,
        isPaid: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isPaid = isPaid
    }

    /// Nombre a mostrar cuando el usuario solo indicó "somos 4" y no puso nombres.
    nonisolated static func placeholderName(index: Int) -> String {
        "Persona \(index + 1)"
    }
}

// MARK: - Helpers de reparto

extension Array where Element == Debtor {
    /// Total que queda por cobrar.
    var pendingAmount: Double {
        filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    /// Total ya devuelto.
    var paidAmount: Double {
        filter(\.isPaid).reduce(0) { $0 + $1.amount }
    }

    var hasPending: Bool {
        contains { !$0.isPaid }
    }

    /// Reparte `total` a partes iguales entre las personas (incluyéndote a ti si
    /// `includingMe`), cuadrando los céntimos sobrantes en la primera persona.
    func splitEvenly(total: Double, includingMe: Bool = true) -> [Debtor] {
        guard !isEmpty else { return self }
        let shares = includingMe ? count + 1 : count
        guard shares > 0 else { return self }

        let share = ((total / Double(shares)) * 100).rounded() / 100
        var result = map { debtor -> Debtor in
            var copy = debtor
            copy.amount = share
            return copy
        }

        // Los céntimos que no cuadran por el redondeo se ajustan en la 1ª fila
        // para que la suma nunca supere el importe del gasto.
        let assigned = share * Double(count)
        let maxOwed = includingMe ? total - share : total
        let drift = ((maxOwed - assigned) * 100).rounded() / 100
        if drift != 0, var first = result.first {
            first.amount = ((first.amount + drift) * 100).rounded() / 100
            result[0] = first
        }
        return result
    }
}
