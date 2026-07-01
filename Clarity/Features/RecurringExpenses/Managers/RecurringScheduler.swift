// RecurringScheduler.swift
// Lógica PURA de planificación de gastos recurrentes.
//
// Extraída de LocalRecurringExpenseManager para poder testearla sin Firestore/DI.
// No tiene estado ni efectos: solo decide QUÉ y CUÁNDO según frecuencia, billingMonth,
// día del mes y los gastos ya existentes. El manager mantiene los efectos (fetch, addExpense,
// notificaciones, toasts). El comportamiento es idéntico al previo.
//
// Fechas: las cadenas "YYYY-MM-DD" se derivan con `Formatters.isoString` (UTC), igual que el
// manager. El `Calendar` se inyecta (default `.current`) solo para contar días del mes y
// recorrer meses hacia atrás; en tests se pasa un calendario UTC para determinismo.

import Foundation

enum RecurringScheduler {

    // MARK: - Deterministic id

    /// Doc id determinista para el cargo de una regla en un mes: "rec_<ruleId>_<YYYY-MM>".
    /// Firestore sobrescribe silenciosamente en colisión → el write es idempotente:
    /// dos dispositivos creando el cargo del mismo mes producen UN doc, no duplicado.
    /// Los cargos legacy tienen auto-id → el scan expenseExists sigue siendo necesario.
    static func chargeDocumentId(ruleId: String, month: String) -> String {
        "rec_\(ruleId)_\(month)"
    }

    // MARK: - Dedupe

    /// Comprueba contra una lista pre-cargada de gastos (evita N fetches).
    /// IMPORTANTE: en caso de duda (recurringId vacío) devuelve `true` para NO duplicar.
    static func expenseExists(in expenses: [Expense], recurringId: String, month: String) -> Bool {
        guard !recurringId.isEmpty else { return true }
        return expenses.contains { $0.recurringId == recurringId && $0.date.hasPrefix(month) }
    }

    // MARK: - Billing months

    /// Devuelve los meses ("YYYY-MM") en los que debería existir un cobro de esta regla
    /// dentro de los últimos 12 meses (incluyendo el actual). Soporta recovery cross-month
    /// para frecuencias trimestrales / semestrales / anuales.
    static func expectedBillingMonths(
        for rule: RecurringExpense,
        anchor: Date,
        calendar: Calendar = .current
    ) -> [String] {
        let cal = calendar
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
        return result
    }

    // MARK: - Daily gate decision (checkAndCreatePendingExpenses)

    /// Decide si HOY corresponde crear el gasto de esta regla, según frecuencia/billingMonth,
    /// día del mes (con clamp al último día) y dedupe contra gastos existentes.
    static func shouldCreateExpense(
        recurring: RecurringExpense,
        currentDay: Int,
        currentMonth: String,
        today: Date,
        existingExpenses: [Expense],
        calendar: Calendar = .current
    ) -> Bool {
        // Verificar que sea el día del mes correcto.
        // Edge case: si dayOfMonth=31 y el mes tiene 30 (o 28/29 en feb), usamos el último día del mes
        // (sin esto, alquileres/suscripciones del 31 nunca se creaban en abril/junio/sept/nov/feb).
        let cal = calendar
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
            return !expenseExists(in: existingExpenses, recurringId: recurring.id ?? "", month: currentMonth)

        case .quarterly:
            // Trimestral: se cobra cada 3 meses desde billingMonth.
            // Ej: billingMonth=2 (Feb) → Feb(2), May(5), Ago(8), Nov(11).
            let billingMonth = recurring.billingMonth
            guard billingMonth >= 1 && billingMonth <= 12 else { return false }
            let monthDiff = (currentMonthNum - billingMonth + 12) % 12
            guard monthDiff % 3 == 0 else { return false }
            return !expenseExists(in: existingExpenses, recurringId: recurring.id ?? "", month: currentMonth)

        case .semestral:
            // Semestral: cada 6 meses desde billingMonth. Ej: billingMonth=3 → Mar(3), Sep(9).
            let billingMonth = recurring.billingMonth
            guard billingMonth >= 1 && billingMonth <= 12 else { return false }
            let monthDiff = (currentMonthNum - billingMonth + 12) % 12
            guard monthDiff % 6 == 0 else { return false }
            return !expenseExists(in: existingExpenses, recurringId: recurring.id ?? "", month: currentMonth)

        case .yearly:
            // Anual: solo en billingMonth. Ej: billingMonth=5 → solo Mayo.
            let billingMonth = recurring.billingMonth
            guard billingMonth >= 1 && billingMonth <= 12 else { return false }
            guard currentMonthNum == billingMonth else { return false }
            return !expenseExists(in: existingExpenses, recurringId: recurring.id ?? "", month: currentMonth)
        }
    }

    // MARK: - Current period (createCurrentPeriodExpenseIfDue)

    /// Pre-condiciones (sin tocar IO) para crear AL MOMENTO el cobro del periodo actual al
    /// guardar/editar una regla: regla activa con id, este mes toca cobro, el día de cobro
    /// (clamp al último del mes) ya llegó, y la regla no ha expirado. El dedupe contra gastos
    /// existentes se comprueba aparte (`expenseExists`) tras el fetch.
    static func isCurrentPeriodChargeDue(
        for rule: RecurringExpense,
        today: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard rule.active, let ruleId = rule.id, !ruleId.isEmpty else { return false }

        let currentDate = Formatters.isoString(from: today)
        let currentDay = Int(currentDate.suffix(2)) ?? 1
        let currentMonth = String(currentDate.prefix(7))

        // ¿Este mes toca cobro según frecuencia/billingMonth?
        guard expectedBillingMonths(for: rule, anchor: today, calendar: calendar).contains(currentMonth) else {
            return false
        }

        // ¿El día de cobro (clamp al último día del mes) ya llegó?
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let effectiveDay = min(rule.dayOfMonth, daysInMonth)
        guard effectiveDay <= currentDay else { return false }

        // ¿Expirada?
        if let endDate = rule.endDate,
           let endObj = Formatters.date(from: endDate),
           today > endObj { return false }

        return true
    }

    /// El gasto a crear para el periodo actual (asumiendo que `isCurrentPeriodChargeDue` es true
    /// y que no existe ya según `expenseExists`). El día se clampa al último del mes.
    static func currentPeriodExpense(
        for rule: RecurringExpense,
        today: Date,
        calendar: Calendar = .current
    ) -> Expense {
        let currentDate = Formatters.isoString(from: today)
        let currentMonth = String(currentDate.prefix(7))
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let effectiveDay = min(rule.dayOfMonth, daysInMonth)
        let dayStr = String(format: "%02d", effectiveDay)
        let deterministicId = (rule.id?.isEmpty == false)
            ? chargeDocumentId(ruleId: rule.id!, month: currentMonth)
            : nil

        return Expense(
            id: deterministicId,
            amount: max(0, rule.amount),
            name: rule.name,
            category: rule.category,
            subcategory: rule.subcategory,
            date: "\(currentMonth)-\(dayStr)",
            paymentMethod: rule.paymentMethod,
            isRecurring: true,
            recurringId: rule.id
        )
    }
}
