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

            // Pre-cargar SOLO el mes actual (el dedupe es por mes — antes bajaba
            // todo el historial con .networkFirst en cada arranque).
            let cachedExpenses = (try? await expenseRepo.getExpenses(
                from: "\(currentMonth)-01", to: "\(currentMonth)-31")) ?? []

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

                // Id determinista → write idempotente (multi-dispositivo no duplica).
                // shouldCreateExpense ya descartó reglas sin id (dedupe trata vacío como existente).
                let detId = (recurring.id?.isEmpty == false)
                    ? RecurringScheduler.chargeDocumentId(ruleId: recurring.id!, month: currentMonth)
                    : nil

                let newExpense = Expense(
                    id: detId,
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

            // Pre-cargar SOLO la ventana de recovery (12 meses) en vez de todo el historial.
            let windowStart = Calendar.current.date(byAdding: .month, value: -11, to: today) ?? today
            let windowStartMonth = String(Formatters.isoString(from: windowStart).prefix(7))
            let cachedExpenses = (try? await expenseRepo.getExpenses(
                from: "\(windowStartMonth)-01", to: "\(currentMonth)-31")) ?? []

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

                    // Id determinista codifica el MES DE COBRO (expectedMonth), no el de
                    // creación — recuperar 3 trimestres perdidos da 3 ids distintos.
                    let detId = (recurring.id?.isEmpty == false)
                        ? RecurringScheduler.chargeDocumentId(ruleId: recurring.id!, month: expectedMonth)
                        : nil

                    let newExpense = Expense(
                        id: detId,
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
        guard let ruleId = rule.id, !ruleId.isEmpty else { return }

        let today = Date()
        let currentMonth = String(Formatters.isoString(from: today).prefix(7))

        // Pre-condiciones puras (activa, mes toca, día ya llegó, no expirada) — RecurringScheduler.
        guard RecurringScheduler.isCurrentPeriodChargeDue(for: rule, today: today) else { return }

        do {
            // Solo el mes actual: el dedupe es por mes, no hace falta el historial entero.
            let existing = (try? await expenseRepo.getExpenses(
                from: "\(currentMonth)-01", to: "\(currentMonth)-31")) ?? []
            guard !RecurringScheduler.expenseExists(in: existing, recurringId: ruleId, month: currentMonth) else { return }

            let newExpense = RecurringScheduler.currentPeriodExpense(for: rule, today: today)
            let effectiveDay = Int(newExpense.date.suffix(2)) ?? rule.dayOfMonth
            _ = try await expenseRepo.addExpense(newExpense)
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            // Feedback estándar de la app (toast), como cualquier alta de gasto.
            FeedbackManager.shared.show(
                .success,
                title: "Gasto añadido",
                message: "\(rule.name) — cobro del día \(effectiveDay) añadido a este mes"
            )
            logger.info("⚡️ Gasto inmediato creado al guardar regla: \(rule.name) (\(newExpense.date))")
        } catch {
            FeedbackManager.shared.show(
                .error,
                title: "Error al crear el gasto",
                message: "No se pudo crear el cobro de \(rule.name). Se reintentará al abrir la app."
            )
            logger.error("❌ Error creando gasto inmediato: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers
    //
    // La lógica pura (frecuencias, billingMonth, dedupe, clamp de día) vive en
    // `RecurringScheduler` para poder testearla sin Firestore/DI. Estos wrappers
    // mantienen las llamadas existentes y delegan sin cambiar el comportamiento.

    private func shouldCreateExpense(
        recurring: RecurringExpense,
        currentDay: Int,
        currentMonth: String,
        today: Date,
        existingExpenses: [Expense]
    ) -> Bool {
        RecurringScheduler.shouldCreateExpense(
            recurring: recurring,
            currentDay: currentDay,
            currentMonth: currentMonth,
            today: today,
            existingExpenses: existingExpenses
        )
    }

    private func expectedBillingMonths(for rule: RecurringExpense, anchor: Date) -> [String] {
        RecurringScheduler.expectedBillingMonths(for: rule, anchor: anchor)
    }

    private func expenseExists(in expenses: [Expense], recurringId: String, month: String) -> Bool {
        RecurringScheduler.expenseExists(in: expenses, recurringId: recurringId, month: month)
    }
}
