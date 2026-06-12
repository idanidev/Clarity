// RecurringSchedulerTests.swift
// Tests de regresión para la lógica PURA de gastos recurrentes (RecurringScheduler).
//
// Blinda bugs reales arreglados en jun 2026:
//  - dedupe de cargos por recurringId + prefijo de mes "YYYY-MM"
//  - frecuencias monthly/quarterly/semestral/yearly con billingMonth
//  - clamp de día (31 en meses de 30 / feb) para que alquileres del 31 no se pierdan
//  - "crear cargo del periodo actual" solo si toca, no existe, día llegado y mes correcto

import Testing
import Foundation
@testable import Clarity

@Suite("RecurringScheduler", .serialized)
@MainActor
struct RecurringSchedulerTests {

    // MARK: - Fixtures

    /// Calendario UTC determinista — alinea con `Formatters.isoString` (también UTC).
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func makeRule(
        id: String? = "rule-1",
        amount: Double = 10,
        frequency: RecurringFrequency,
        dayOfMonth: Int,
        billingMonth: Int = 0,
        active: Bool = true,
        endDate: String? = nil
    ) -> RecurringExpense {
        RecurringExpense(
            id: id, amount: amount, name: "Netflix", category: "Suscripciones📺",
            subcategory: "Netflix", paymentMethod: "Tarjeta", frequency: frequency,
            dayOfMonth: dayOfMonth, billingMonth: billingMonth, active: active, icon: nil,
            startDate: nil, endDate: endDate, lastCreated: nil, createdAt: nil, updatedAt: nil
        )
    }

    private func makeExpense(recurringId: String?, date: String) -> Expense {
        Expense(amount: 10, name: "Netflix", category: "Suscripciones📺", date: date,
                isRecurring: true, recurringId: recurringId)
    }

    // MARK: - expenseExists (dedupe)

    @Test("dedupe: mismo recurringId y mes → existe")
    func dedupeMatch() {
        let existing = [makeExpense(recurringId: "rule-1", date: "2026-06-15")]
        #expect(RecurringScheduler.expenseExists(in: existing, recurringId: "rule-1", month: "2026-06"))
    }

    @Test("dedupe: mismo id otro mes → no existe")
    func dedupeOtherMonth() {
        let existing = [makeExpense(recurringId: "rule-1", date: "2026-05-15")]
        #expect(!RecurringScheduler.expenseExists(in: existing, recurringId: "rule-1", month: "2026-06"))
    }

    @Test("dedupe: distinto id → no existe")
    func dedupeOtherId() {
        let existing = [makeExpense(recurringId: "rule-2", date: "2026-06-15")]
        #expect(!RecurringScheduler.expenseExists(in: existing, recurringId: "rule-1", month: "2026-06"))
    }

    @Test("dedupe: recurringId vacío → true (no duplicar por seguridad)")
    func dedupeEmptyIdSafety() {
        #expect(RecurringScheduler.expenseExists(in: [], recurringId: "", month: "2026-06"))
    }

    // MARK: - expectedBillingMonths

    @Test("monthly: 12 meses, incluye el actual")
    func billingMonthsMonthly() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 1)
        let months = RecurringScheduler.expectedBillingMonths(for: rule, anchor: date(2026, 6, 12), calendar: utc)
        #expect(months.count == 12)
        #expect(months.first == "2026-06")
        #expect(months.contains("2025-07"))
    }

    @Test("quarterly billingMonth=2 → Feb/May/Ago/Nov")
    func billingMonthsQuarterly() {
        let rule = makeRule(frequency: .quarterly, dayOfMonth: 10, billingMonth: 2)
        let months = Set(RecurringScheduler.expectedBillingMonths(for: rule, anchor: date(2026, 6, 12), calendar: utc))
        #expect(months == ["2026-05", "2026-02", "2025-11", "2025-08"])
    }

    @Test("semestral billingMonth=3 → Mar/Sep")
    func billingMonthsSemestral() {
        let rule = makeRule(frequency: .semestral, dayOfMonth: 5, billingMonth: 3)
        let months = Set(RecurringScheduler.expectedBillingMonths(for: rule, anchor: date(2026, 6, 12), calendar: utc))
        #expect(months == ["2026-03", "2025-09"])
    }

    @Test("yearly billingMonth=6 → solo el mes actual en la ventana")
    func billingMonthsYearly() {
        let rule = makeRule(frequency: .yearly, dayOfMonth: 1, billingMonth: 6)
        let months = RecurringScheduler.expectedBillingMonths(for: rule, anchor: date(2026, 6, 12), calendar: utc)
        #expect(months == ["2026-06"])
    }

    // MARK: - shouldCreateExpense por frecuencia

    @Test("monthly: día correcto y sin gasto previo → crea")
    func shouldCreateMonthly() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 15)
        let today = date(2026, 6, 15)
        #expect(RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 15, currentMonth: "2026-06",
            today: today, existingExpenses: [], calendar: utc))
    }

    @Test("monthly: ya existe este mes → NO crea")
    func shouldNotCreateMonthlyDuplicate() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 15)
        let existing = [makeExpense(recurringId: "rule-1", date: "2026-06-15")]
        #expect(!RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 15, currentMonth: "2026-06",
            today: date(2026, 6, 15), existingExpenses: existing, calendar: utc))
    }

    @Test("monthly: día distinto → NO crea")
    func shouldNotCreateWrongDay() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 15)
        #expect(!RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 14, currentMonth: "2026-06",
            today: date(2026, 6, 14), existingExpenses: [], calendar: utc))
    }

    @Test("clamp: día 31 en junio (30 días) → crea el día 30")
    func shouldCreateClampJune() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 31)
        #expect(RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 30, currentMonth: "2026-06",
            today: date(2026, 6, 30), existingExpenses: [], calendar: utc))
    }

    @Test("clamp: día 31 en febrero (28 días) → crea el día 28")
    func shouldCreateClampFeb() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 31)
        #expect(RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 28, currentMonth: "2026-02",
            today: date(2026, 2, 28), existingExpenses: [], calendar: utc))
    }

    @Test("clamp: día 31 en junio pero hoy es 29 → NO crea")
    func shouldNotCreateClampBeforeLastDay() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 31)
        #expect(!RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 29, currentMonth: "2026-06",
            today: date(2026, 6, 29), existingExpenses: [], calendar: utc))
    }

    @Test("quarterly billingMonth=2: en mayo (mes válido) → crea")
    func shouldCreateQuarterlyValidMonth() {
        let rule = makeRule(frequency: .quarterly, dayOfMonth: 10, billingMonth: 2)
        #expect(RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 10, currentMonth: "2026-05",
            today: date(2026, 5, 10), existingExpenses: [], calendar: utc))
    }

    @Test("quarterly billingMonth=2: en junio (mes no válido) → NO crea")
    func shouldNotCreateQuarterlyInvalidMonth() {
        let rule = makeRule(frequency: .quarterly, dayOfMonth: 10, billingMonth: 2)
        #expect(!RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 10, currentMonth: "2026-06",
            today: date(2026, 6, 10), existingExpenses: [], calendar: utc))
    }

    @Test("quarterly billingMonth inválido (0) → NO crea")
    func shouldNotCreateQuarterlyInvalidBilling() {
        let rule = makeRule(frequency: .quarterly, dayOfMonth: 10, billingMonth: 0)
        #expect(!RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 10, currentMonth: "2026-05",
            today: date(2026, 5, 10), existingExpenses: [], calendar: utc))
    }

    @Test("semestral billingMonth=3: en septiembre → crea")
    func shouldCreateSemestralValidMonth() {
        let rule = makeRule(frequency: .semestral, dayOfMonth: 5, billingMonth: 3)
        #expect(RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 5, currentMonth: "2026-09",
            today: date(2026, 9, 5), existingExpenses: [], calendar: utc))
    }

    @Test("semestral billingMonth=3: en junio → NO crea")
    func shouldNotCreateSemestralInvalidMonth() {
        let rule = makeRule(frequency: .semestral, dayOfMonth: 5, billingMonth: 3)
        #expect(!RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 5, currentMonth: "2026-06",
            today: date(2026, 6, 5), existingExpenses: [], calendar: utc))
    }

    @Test("yearly billingMonth=6: en junio → crea")
    func shouldCreateYearlyValidMonth() {
        let rule = makeRule(frequency: .yearly, dayOfMonth: 1, billingMonth: 6)
        #expect(RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 1, currentMonth: "2026-06",
            today: date(2026, 6, 1), existingExpenses: [], calendar: utc))
    }

    @Test("yearly billingMonth=6: en julio → NO crea")
    func shouldNotCreateYearlyInvalidMonth() {
        let rule = makeRule(frequency: .yearly, dayOfMonth: 1, billingMonth: 6)
        #expect(!RecurringScheduler.shouldCreateExpense(
            recurring: rule, currentDay: 1, currentMonth: "2026-07",
            today: date(2026, 7, 1), existingExpenses: [], calendar: utc))
    }

    // MARK: - createCurrentPeriodExpenseIfDue (decisión pura)

    @Test("createIfDue: mensual, día ya pasó → due true")
    func currentDueWhenDayPassed() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 9)
        #expect(RecurringScheduler.isCurrentPeriodChargeDue(for: rule, today: date(2026, 6, 11), calendar: utc))
    }

    @Test("createIfDue: día aún no llegado → NO due")
    func currentNotDueWhenDayNotReached() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 15)
        #expect(!RecurringScheduler.isCurrentPeriodChargeDue(for: rule, today: date(2026, 6, 11), calendar: utc))
    }

    @Test("createIfDue: mes no corresponde a la frecuencia → NO due")
    func currentNotDueWrongMonth() {
        let rule = makeRule(frequency: .yearly, dayOfMonth: 5, billingMonth: 3)
        #expect(!RecurringScheduler.isCurrentPeriodChargeDue(for: rule, today: date(2026, 6, 11), calendar: utc))
    }

    @Test("createIfDue: regla expirada → NO due")
    func currentNotDueExpired() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 9, endDate: "2026-01-01")
        #expect(!RecurringScheduler.isCurrentPeriodChargeDue(for: rule, today: date(2026, 6, 11), calendar: utc))
    }

    @Test("createIfDue: regla inactiva → NO due")
    func currentNotDueInactive() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 9, active: false)
        #expect(!RecurringScheduler.isCurrentPeriodChargeDue(for: rule, today: date(2026, 6, 11), calendar: utc))
    }

    @Test("createIfDue: id nil → NO due")
    func currentNotDueNilId() {
        let rule = makeRule(id: nil, frequency: .monthly, dayOfMonth: 9)
        #expect(!RecurringScheduler.isCurrentPeriodChargeDue(for: rule, today: date(2026, 6, 11), calendar: utc))
    }

    @Test("currentPeriodExpense: gasto correcto con día y recurringId")
    func currentExpenseBuilt() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 9)
        let expense = RecurringScheduler.currentPeriodExpense(for: rule, today: date(2026, 6, 11), calendar: utc)
        #expect(expense.date == "2026-06-09")
        #expect(expense.recurringId == "rule-1")
        #expect(expense.isRecurring == true)
        #expect(expense.amount == 10)
    }

    @Test("currentPeriodExpense: clamp día 31 en junio → 2026-06-30")
    func currentExpenseClamped() {
        let rule = makeRule(frequency: .monthly, dayOfMonth: 31)
        let expense = RecurringScheduler.currentPeriodExpense(for: rule, today: date(2026, 6, 30), calendar: utc)
        #expect(expense.date == "2026-06-30")
    }
}
