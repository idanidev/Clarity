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

    /// El mes en que se dio de alta la regla ("YYYY-MM"): de `startDate` y, si
    /// falta, de `createdAt`. `nil` en las reglas antiguas que no guardan ninguno.
    static func mesDeAlta(de rule: RecurringExpense) -> String? {
        for origen in [rule.startDate, rule.createdAt] {
            guard let mes = origen?.prefix(7), mes.count == 7 else { continue }
            let partes = mes.split(separator: "-")
            if partes.count == 2, partes[0].count == 4, Int(partes[0]) != nil,
               let m = Int(partes[1]), (1...12).contains(m) {
                return String(mes)
            }
        }
        return nil
    }

    /// Los meses que la recuperación puede rellenar: los que tocan por frecuencia
    /// Y en los que la regla ya existía. Sin esto, a una regla mensual recién
    /// creada se le «recuperaban» los 11 meses anteriores: gastos que nunca
    /// existieron. El mes del alta sí cuenta entero, como en
    /// `createCurrentPeriodExpenseIfDue`. Una regla antigua sin fechas se queda
    /// con la ventana completa, que es para lo que se hizo la recuperación.
    static func mesesRecuperables(
        for rule: RecurringExpense,
        anchor: Date,
        calendar: Calendar = .current
    ) -> [String] {
        let meses = expectedBillingMonths(for: rule, anchor: anchor, calendar: calendar)
        guard let alta = mesDeAlta(de: rule) else { return meses }
        return meses.filter { $0 >= alta }
    }

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
        // Por día, no por instante: el día del último cargo todavía se cobra.
        if let endDate = rule.endDate, !endDate.isEmpty,
           currentDate > String(endDate.prefix(10)) { return false }

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

    // MARK: - Fecha fin y plazos (#64)

    /// Meses que separan dos cargos de una frecuencia.
    static func mesesEntreCargos(_ frecuencia: RecurringFrequency) -> Int {
        switch frecuencia {
        case .monthly: 1
        case .quarterly: 3
        case .semestral: 6
        case .yearly: 12
        }
    }

    /// Año y mes del primer cargo contando desde `desde`. Mensual: ese mismo mes
    /// —si el día ya pasó se cobra al crear la regla—. El resto: el primer mes
    /// que case con `billingMonth` y la frecuencia, ese mes incluido.
    static func primerMesDeCargo(frecuencia: RecurringFrequency, billingMonth: Int,
                                 desde: Date, calendar: Calendar = .current) -> (anio: Int, mes: Int) {
        let anio = calendar.component(.year, from: desde)
        let mes = calendar.component(.month, from: desde)
        let paso = mesesEntreCargos(frecuencia)
        guard paso > 1, billingMonth >= 1 else { return (anio, mes) }
        for offset in 0..<12 {
            let total = (mes - 1) + offset
            let m = total % 12 + 1
            if ((m - billingMonth) % paso + paso) % paso == 0 {
                return (anio + total / 12, m)
            }
        }
        return (anio, mes)
    }

    /// Los cargos de un plan, en orden, como "yyyy-MM-dd": desde el primero
    /// hasta `hasta` incluido, o `limite` cargos si no hay fecha.
    static func fechasDeCargo(frecuencia: RecurringFrequency, dia: Int, billingMonth: Int,
                              desde: Date, hasta: String? = nil, limite: Int = 600,
                              calendar: Calendar = .current) -> [String] {
        let inicio = primerMesDeCargo(frecuencia: frecuencia, billingMonth: billingMonth, desde: desde, calendar: calendar)
        let paso = mesesEntreCargos(frecuencia)
        var out: [String] = []
        var (anio, mes) = inicio
        while out.count < limite {
            var comps = DateComponents(); comps.year = anio; comps.month = mes; comps.day = 1
            let diasMes = calendar.date(from: comps).flatMap { calendar.range(of: .day, in: .month, for: $0)?.count } ?? 28
            let fecha = String(format: "%04d-%02d-%02d", anio, mes, min(max(dia, 1), diasMes))
            if let hasta, fecha > hasta { break }
            out.append(fecha)
            mes += paso
            while mes > 12 { mes -= 12; anio += 1 }
        }
        return out
    }

    /// Fecha del último cargo de un plan de `plazos` cargos. Se guarda como
    /// `endDate`: el scheduler ya deja de cobrar después de ese día.
    static func fechaFin(plazos: Int, frecuencia: RecurringFrequency, dia: Int, billingMonth: Int,
                         desde: Date, calendar: Calendar = .current) -> String {
        fechasDeCargo(frecuencia: frecuencia, dia: dia, billingMonth: billingMonth,
                      desde: desde, limite: max(plazos, 1), calendar: calendar).last
            ?? Formatters.localDayString(from: desde)
    }

    /// Cargos hechos y totales de una regla con fecha fin. `nil` si no tiene.
    static func plazos(de regla: RecurringExpense, hoy: Date, calendar: Calendar = .current) -> (hechos: Int, total: Int)? {
        guard let fin = regla.endDate, !fin.isEmpty else { return nil }
        let inicio = regla.startDate.flatMap { Formatters.date(from: $0) } ?? hoy
        let todas = fechasDeCargo(frecuencia: regla.frequency, dia: regla.dayOfMonth, billingMonth: regla.billingMonth,
                                  desde: inicio, hasta: String(fin.prefix(10)), calendar: calendar)
        guard !todas.isEmpty else { return nil }
        let hoyStr = Formatters.localDayString(from: hoy)
        return (todas.filter { $0 <= hoyStr }.count, todas.count)
    }
}
