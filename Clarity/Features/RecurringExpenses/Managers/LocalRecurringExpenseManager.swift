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
    private let recurringRepo = DependencyContainer.shared.recurringExpenseRepository
    private let expenseRepo = DependencyContainer.shared.expenseRepository

    private init() {}

    /// Verifica y crea gastos recurrentes pendientes
    /// Se debe llamar al abrir la app
    func checkAndCreatePendingExpenses() async {
        logger.info("🔍 Verificando gastos recurrentes pendientes...")

        let today = Date()
        // TZ-safe: extraer día del string ISO (currentDate ya es UTC vía Formatters.isoString).
        // Antes mezclaba Calendar.current (local) con date string (UTC) → discrepancia entre
        // "día actual" y "fecha del expense" en zonas horarias != UTC.
        let currentDate = Formatters.isoString(from: today)
        let currentDay = Int(currentDate.suffix(2)) ?? 1
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

            // Pre-cargar gastos UNA vez (evita N fetches en loop)
            let cachedExpenses = (try? await expenseRepo.getExpenses(policy: .networkFirst)) ?? []

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
                let shouldCreate = shouldCreateExpense(
                    recurring: recurring,
                    currentDay: currentDay,
                    currentMonth: currentMonth,
                    today: today,
                    existingExpenses: cachedExpenses
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
        // TZ-safe: extraer día del string ISO (currentDate ya es UTC vía Formatters.isoString).
        // Antes mezclaba Calendar.current (local) con date string (UTC) → discrepancia entre
        // "día actual" y "fecha del expense" en zonas horarias != UTC.
        let currentDate = Formatters.isoString(from: today)
        let currentDay = Int(currentDate.suffix(2)) ?? 1
        let currentMonth = String(currentDate.prefix(7))

        // Guard: run recovery at most once per day (same key as checkAndCreatePendingExpenses)
        let recoveryKey = "lastRecurringExpensesRecovery"
        if let lastRecovery = UserDefaults.standard.string(forKey: recoveryKey),
           lastRecovery == currentDate {
            logger.info("⏭️ Recovery ya ejecutada hoy (\(currentDate))")
            return
        }

        do {
            let recurringExpenses = try await recurringRepo.fetchAll()
            let activeAll = recurringExpenses.filter { $0.active }

            // Pre-cargar gastos UNA vez
            let cachedExpenses = (try? await expenseRepo.getExpenses(policy: .networkFirst)) ?? []

            var recovered = 0

            // Para cada regla, calcula los meses (de los últimos 12) en los que DEBERÍA haber
            // un gasto y, si falta, créalo. Esto recupera trimestrales/semestrales/anuales perdidos.
            for recurring in activeAll {
                // Verificar si expiró
                if let endDate = recurring.endDate,
                   let endDateObj = Formatters.date(from: endDate),
                   today > endDateObj {
                    continue
                }

                let expectedMonths = expectedBillingMonths(for: recurring, anchor: today)
                for expectedMonth in expectedMonths {
                    // Solo intentar recuperar meses cuyo día de cobro ya haya pasado
                    if expectedMonth == currentMonth && recurring.dayOfMonth > currentDay {
                        continue
                    }

                    let exists = expenseExists(
                        in: cachedExpenses,
                        recurringId: recurring.id ?? "",
                        month: expectedMonth
                    )
                    guard !exists else { continue }

                    // Clamp dayOfMonth a días del mes objetivo (evita "2026-04-31" inválido)
                    let monthDate = Formatters.date(from: "\(expectedMonth)-01") ?? today
                    let daysIn = Calendar.current.range(of: .day, in: .month, for: monthDate)?.count ?? 30
                    let safeDay = min(recurring.dayOfMonth, daysIn)
                    let dayStr = String(format: "%02d", safeDay)
                    let expenseDate = "\(expectedMonth)-\(dayStr)"
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

            UserDefaults.standard.set(currentDate, forKey: recoveryKey)
            logger.info("📊 Gastos recuperados: \(recovered)")

        } catch {
            logger.error("❌ Error recuperando gastos: \(error.localizedDescription)")
        }
    }

    /// Crea AL MOMENTO el gasto del periodo actual para una regla recién creada o
    /// editada, si su día de cobro de este mes ya pasó (o es hoy) y aún no existe.
    /// SIN gate diario — se invoca explícitamente al guardar la regla.
    /// Feedback de usuario: "estamos a 11, el cobro era el día 9 → que lo meta ya,
    /// no esperar al día siguiente" (el presupuesto no reflejaba el gasto).
    func createCurrentPeriodExpenseIfDue(for rule: RecurringExpense) async {
        guard rule.active, let ruleId = rule.id, !ruleId.isEmpty else { return }

        let today = Date()
        let currentDate = Formatters.isoString(from: today)
        let currentDay = Int(currentDate.suffix(2)) ?? 1
        let currentMonth = String(currentDate.prefix(7))

        // ¿Este mes toca cobro según frecuencia/billingMonth?
        guard expectedBillingMonths(for: rule, anchor: today).contains(currentMonth) else { return }

        // ¿El día de cobro (clamp al último día del mes) ya llegó?
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: today)?.count ?? 30
        let effectiveDay = min(rule.dayOfMonth, daysInMonth)
        guard effectiveDay <= currentDay else { return }

        // ¿Expirada?
        if let endDate = rule.endDate,
           let endObj = Formatters.date(from: endDate),
           today > endObj { return }

        do {
            let existing = (try? await expenseRepo.getExpenses(policy: .networkFirst)) ?? []
            guard !expenseExists(in: existing, recurringId: ruleId, month: currentMonth) else { return }

            let dayStr = String(format: "%02d", effectiveDay)
            let newExpense = Expense(
                amount: max(0, rule.amount),
                name: rule.name,
                category: rule.category,
                subcategory: rule.subcategory,
                date: "\(currentMonth)-\(dayStr)",
                paymentMethod: rule.paymentMethod,
                isRecurring: true,
                recurringId: ruleId
            )
            _ = try await expenseRepo.addExpense(newExpense)
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            logger.info("⚡️ Gasto inmediato creado al guardar regla: \(rule.name) (\(currentMonth)-\(dayStr))")
        } catch {
            logger.error("❌ Error creando gasto inmediato: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func shouldCreateExpense(
        recurring: RecurringExpense,
        currentDay: Int,
        currentMonth: String,
        today: Date,
        existingExpenses: [Expense]
    ) -> Bool {
        // Verificar que sea el día del mes correcto.
        // Edge case: si dayOfMonth=31 y el mes tiene 30 (o 28/29 en feb), usamos el último día del mes
        // (sin esto, alquileres/suscripciones del 31 nunca se creaban en abril/junio/sept/nov/feb).
        let cal = Calendar.current
        let daysInMonth = cal.range(of: .day, in: .month, for: today)?.count ?? 30
        let effectiveDay = min(recurring.dayOfMonth, daysInMonth)
        guard effectiveDay == currentDay else {
            return false
        }

        let frequency = recurring.frequency
        // TZ-safe: extraer month del string ISO (currentMonth = "YYYY-MM")
        let currentMonthNum = Int(currentMonth.suffix(2)) ?? 1

        switch frequency {
        case .monthly:
            // Verificar si ya existe este mes
            return !expenseExists(
                in: existingExpenses,
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
            return !expenseExists(
                in: existingExpenses,
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
            return !expenseExists(
                in: existingExpenses,
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
            return !expenseExists(
                in: existingExpenses,
                recurringId: recurring.id ?? "",
                month: currentMonth
            )
        }
    }

    /// Devuelve los meses ("YYYY-MM") en los que debería existir un cobro de esta regla
    /// dentro de los últimos 12 meses (incluyendo el actual). Soporta recovery cross-month
    /// para frecuencias trimestrales / semestrales / anuales.
    private func expectedBillingMonths(for rule: RecurringExpense, anchor: Date) -> [String] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: anchor)
        guard let curYear = comps.year, let curMonth = comps.month else { return [] }

        var result: [String] = []
        // Recorre 12 meses hacia atrás incluyendo el actual
        for offset in 0..<12 {
            guard let date = cal.date(byAdding: .month, value: -offset, to: anchor) else { continue }
            let yc = cal.component(.year, from: date)
            let mc = cal.component(.month, from: date)
            let monthStr = String(format: "%04d-%02d", yc, mc)

            let due: Bool
            switch rule.frequency {
            case .monthly:
                due = true
            case .quarterly:
                guard rule.billingMonth >= 1 else { due = false; break }
                due = (mc - rule.billingMonth + 12) % 3 == 0
            case .semestral:
                guard rule.billingMonth >= 1 else { due = false; break }
                due = (mc - rule.billingMonth + 12) % 6 == 0
            case .yearly:
                due = (mc == rule.billingMonth)
            }
            if due { result.append(monthStr) }
        }
        // Suprime warnings (curYear/curMonth no se usan directamente; mantengo por claridad si en futuro filtramos)
        _ = (curYear, curMonth)
        return result
    }

    /// Comprueba contra una lista pre-cargada de gastos (evita N fetches).
    /// IMPORTANTE: en caso de duda devuelve `true` para NO duplicar.
    private func expenseExists(in expenses: [Expense], recurringId: String, month: String) -> Bool {
        guard !recurringId.isEmpty else { return true }
        return expenses.contains { $0.recurringId == recurringId && $0.date.hasPrefix(month) }
    }
}
