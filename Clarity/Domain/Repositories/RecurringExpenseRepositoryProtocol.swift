// RecurringExpenseRepositoryProtocol.swift
// Protocolo sobre RecurringExpenseRepository para poder inyectar un doble en
// los tests de LocalRecurringExpenseManager.
//
// Ese manager es lo que sustituye a las Cloud Functions: crea gastos DE VERDAD
// al abrir la app. Con el repositorio como clase concreta cableada a Firestore
// no había forma de probar ni `checkAndCreatePendingExpenses()` ni
// `recoverMissedExpenses()`.
//
// Mismo criterio que `UserDataStore`: cubre EXACTAMENTE lo que consume el
// manager (`fetchAll` y `update`), ni más ni menos. El resto de la clase
// (`add`, `delete`, `toggleActive`, `vaciarCache`) lo siguen
// usando las vistas contra el tipo concreto. La caché de 60 s es un detalle de
// la clase real y se queda dentro de ella: quien pide `fetchAll()` no la ve.

import Foundation

protocol RecurringExpenseRepositoryProtocol {
    func fetchAll() async throws -> [RecurringExpense]
    func update(_ expense: RecurringExpense) async throws
}

// La clase ya tiene los dos métodos con esta misma firma; no cambia nada en ella.
extension RecurringExpenseRepository: RecurringExpenseRepositoryProtocol {}
