// LocalRecurringExpenseManager.swift
// Maneja la creación automática de gastos recurrentes localmente
// Reemplaza las Cloud Functions de Firebase

import Foundation
import OSLog

@MainActor
final class LocalRecurringExpenseManager {
    static let shared = LocalRecurringExpenseManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "RecurringExpenses")
    private let lastCheckKey = "lastRecurringExpensesCheck"
    private let recurringRepo = RecurringExpenseRepository()
    private let expenseRepo = DependencyContainer.shared.expenseRepository

    private init() {}

    /// Verifica y crea gastos recurrentes pendientes
    /// Se debe llamar al abrir la app
    func checkAndCreatePendingExpenses() async {
        logger.info("🔍 Verificando gastos recurrentes pendientes...")

        let today = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: today)
        let currentDate = Formatters.isoString(from: today)
        let currentMonth = String(currentDate.prefix(7)) // YYYY-MM

        // Evitar múltiples ejecuciones el mismo día
        if let lastCheck = UserDefaults.standard.string(forKey: lastCheckKey),
           lastCheck == currentDate {
            logger.info("⏭️ Ya se verificó hoy (\(currentDate))")
            return
        }

        logger.info("📅 Fecha: \(currentDate), Día: \(currentDay)")

        do {
            // Obtener gastos recurrentes activos
            let recurringExpenses = try await recurringRepo.fetchAll()
            let activeExpenses = recurringExpenses.filter { $0.active }

            guard !activeExpenses.isEmpty else {
                logger.info("📋 No hay gastos recurrentes activos")
                UserDefaults.standard.set(currentDate, forKey: lastCheckKey)
                return
            }

            logger.info("📋 Encontrados \(activeExpenses.count) gastos recurrentes activos")

            var created = 0
            var skipped = 0
            var expired = 0

            for recurring in activeExpenses {
                // Verificar si expiró
                if let endDate = recurring.endDate,
                   let endDateObj = Formatters.date(from: endDate),
                   today > endDateObj {
                    logger.warning("⚠️ '\(recurring.name)' expirado. Desactivando...")

                    var updated = recurring
                    updated.active = false
                    try? await recurringRepo.update(updated)

                    expired += 1
                    continue
                }

                // Verificar si corresponde crear según frecuencia y día del mes
                let shouldCreate = await shouldCreateExpense(
                    recurring: recurring,
                    currentDay: currentDay,
                    currentMonth: currentMonth,
                    today: today
                )

                if !shouldCreate {
                    logger.info("⏭️ Se omite '\(recurring.name)' (freq: \(recurring.frequency.rawValue))")
                    skipped += 1
                    continue
                }

                // Crear el gasto
                let amount = max(0, recurring.amount) // Asegurar >= 0

                let newExpense = Expense(
                    amount: amount,
                    name: recurring.name,
                    category: recurring.category,
                    subcategory: recurring.subcategory,
                    date: currentDate,
                    paymentMethod: recurring.paymentMethod,
                    isRecurring: true,
                    recurringId: recurring.id
                )

                _ = try await expenseRepo.addExpense(newExpense)

                logger.info("✅ Creado: \(recurring.name) - €\(recurring.amount)")
                created += 1
            }

            // Guardar fecha de última verificación
            UserDefaults.standard.set(currentDate, forKey: lastCheckKey)

            logger.info("📊 RESUMEN: ✅ \(created) creados, ⏭️ \(skipped) omitidos, ⚠️ \(expired) expirados")

        } catch {
            logger.error("❌ Error verificando gastos recurrentes: \(error.localizedDescription)")
        }
    }

    /// Verifica gastos perdidos de días anteriores (recuperación)
    /// Similar a checkMissedRecurringExpenses de Cloud Functions
    func recoverMissedExpenses() async {
        logger.info("🔧 Recuperando gastos recurrentes perdidos...")

        let today = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: today)
        let currentDate = Formatters.isoString(from: today)
        let currentMonth = String(currentDate.prefix(7))

        do {
            let recurringExpenses = try await recurringRepo.fetchAll()
            let activeExpenses = recurringExpenses.filter {
                $0.active && $0.dayOfMonth <= currentDay
            }

            var recovered = 0

            for recurring in activeExpenses {
                // Verificar si expiró
                if let endDate = recurring.endDate,
                   let endDateObj = Formatters.date(from: endDate),
                   today > endDateObj {
                    continue
                }

                // Verificar si ya existe el gasto de este mes
                let exists = await expenseExistsForMonth(
                    recurringId: recurring.id ?? "",
                    month: currentMonth
                )

                if !exists {
                    // Crear con la fecha correcta del día del mes
                    let dayStr = String(format: "%02d", recurring.dayOfMonth)
                    let expenseDate = "\(currentMonth)-\(dayStr)"

                    let amount = max(0, recurring.amount)

                    let newExpense = Expense(
                        amount: amount,
                        name: recurring.name,
                        category: recurring.category,
                        subcategory: recurring.subcategory,
                        date: expenseDate,
                        paymentMethod: recurring.paymentMethod,
                        isRecurring: true,
                        recurringId: recurring.id
                    )

                    _ = try await expenseRepo.addExpense(newExpense)

                    logger.info("🔧 Recuperado: \(recurring.name) (\(expenseDate))")
                    recovered += 1
                }
            }

            logger.info("📊 Gastos recuperados: \(recovered)")

        } catch {
            logger.error("❌ Error recuperando gastos: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func shouldCreateExpense(
        recurring: RecurringExpense,
        currentDay: Int,
        currentMonth: String,
        today: Date
    ) async -> Bool {
        // Verificar que sea el día del mes correcto
        guard recurring.dayOfMonth == currentDay else {
            return false
        }

        let frequency = recurring.frequency
        let calendar = Calendar.current
        let currentMonthNum = calendar.component(.month, from: today)

        switch frequency {
        case .monthly:
            // Verificar si ya existe este mes
            return await !expenseExistsForMonth(
                recurringId: recurring.id ?? "",
                month: currentMonth
            )

        case .quarterly:
            // Trimestral: se cobra cada 3 meses desde billingMonth
            // Ej: si billingMonth=2 (Feb) → cobra en Feb(2), May(5), Ago(8), Nov(11)
            let billingMonth = recurring.billingMonth
            guard billingMonth >= 1 && billingMonth <= 12 else { return false }

            // Calcular si este mes corresponde (mes - billingMonth) % 3 == 0
            let monthDiff = (currentMonthNum - billingMonth + 12) % 12
            guard monthDiff % 3 == 0 else {
                return false
            }
            return await !expenseExistsForMonth(
                recurringId: recurring.id ?? "",
                month: currentMonth
            )

        case .semestral:
            // Semestral: se cobra cada 6 meses desde billingMonth
            // Ej: si billingMonth=3 (Mar) → cobra en Mar(3), Sep(9)
            let billingMonth = recurring.billingMonth
            guard billingMonth >= 1 && billingMonth <= 12 else { return false }

            // Calcular si este mes corresponde (mes - billingMonth) % 6 == 0
            let monthDiff = (currentMonthNum - billingMonth + 12) % 12
            guard monthDiff % 6 == 0 else {
                return false
            }
            return await !expenseExistsForMonth(
                recurringId: recurring.id ?? "",
                month: currentMonth
            )

        case .yearly:
            // Anual: se cobra solo en el billingMonth
            // Ej: si billingMonth=5 (May) → cobra solo en Mayo
            let billingMonth = recurring.billingMonth
            guard billingMonth >= 1 && billingMonth <= 12 else { return false }

            guard currentMonthNum == billingMonth else {
                return false
            }
            return await !expenseExistsForMonth(
                recurringId: recurring.id ?? "",
                month: currentMonth
            )
        }
    }

    private func expenseExistsForMonth(recurringId: String, month: String) async -> Bool {
        guard !recurringId.isEmpty else { return false }

        do {
            let expenses = try await expenseRepo.getExpenses(policy: .cacheFirst())

            return expenses.contains { expense in
                expense.recurringId == recurringId &&
                expense.date.hasPrefix(month)
            }
        } catch {
            logger.error("❌ Error verificando existencia: \(error.localizedDescription)")
            return false
        }
    }
}
