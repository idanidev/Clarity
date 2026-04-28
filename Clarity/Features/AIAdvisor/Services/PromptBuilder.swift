//
//  PromptBuilder.swift
//  Clarity
//
//  Builds a rich, token-efficient financial context for the AI advisor.
//

import Foundation

struct PromptBuilder {

    static func buildFinancialContext(
        user: UserDocument?,
        expenses: [Expense],
        goals: [Goal],
        monthBudget: MonthlyBudget?,
        recurringExpenses: [RecurringExpense] = []
    ) -> String {
        let calendar = Calendar.current
        let now = Date()

        let currentMonthExpenses = expenses.filter {
            guard let d = Formatters.date(from: $0.date) else { return false }
            return calendar.isDate(d, equalTo: now, toGranularity: .month)
        }
        let totalSpentThisMonth = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let income = monthBudget?.income ?? user?.income ?? 0
        let savingsAllocated = monthBudget?.savingsAllocated ?? 0
        let freeCash = income - totalSpentThisMonth - savingsAllocated

        let currentMonthName = Self.monthFmt.string(from: now).capitalized

        // Day-of-month progress (e.g., day 15 of 30 = 50%)
        let dayOfMonth = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let monthProgress = pct(Double(dayOfMonth), of: Double(daysInMonth))

        // Daily average & projected spend
        let dailyAvg = dayOfMonth > 0 ? totalSpentThisMonth / Double(dayOfMonth) : 0
        let projectedSpend = dailyAvg * Double(daysInMonth)

        // Savings rate
        let savingsRate = income > 0 ? pct(income - totalSpentThisMonth - savingsAllocated, of: income) : 0

        // Recurring monthly commitment
        let monthlyCommitments = recurringExpenses
            .filter { $0.active }
            .reduce(0.0) { total, r in
                switch r.frequency {
                case .monthly: return total + r.amount
                case .quarterly: return total + r.amount / 3
                case .semestral: return total + r.amount / 6
                case .yearly: return total + r.amount / 12
                }
            }
        let reallyFree = freeCash - monthlyCommitments

        return """
        <financial_context>

        <resumen>
        Mes: \(currentMonthName) (día \(dayOfMonth)/\(daysInMonth), \(monthProgress)% del mes)
        Ingresos: \(fmt(income))€ | Gastado: \(fmt(totalSpentThisMonth))€ (\(pct(totalSpentThisMonth, of: income))%) | Libre: \(fmt(freeCash))€ | Huchas: \(fmt(savingsAllocated))€
        Media diaria: \(fmt(dailyAvg))€/día | Proyección fin de mes: \(fmt(projectedSpend))€
        Compromisos fijos pendientes: \(fmt(monthlyCommitments))€ | Realmente disponible: \(fmt(reallyFree))€
        Tasa de ahorro: \(savingsRate)%
        </resumen>

        \(buildCategoryBreakdown(expenses: currentMonthExpenses, income: income))

        \(buildSpendingLimits(goals: goals, expenses: currentMonthExpenses))

        \(buildAllExpenses(expenses: currentMonthExpenses))

        \(buildLast3MonthsTrend(expenses: expenses, calendar: calendar, now: now))

        \(buildGoalsSection(goals: goals))

        \(buildRecurringSection(recurring: recurringExpenses))

        \(buildInsights(currentMonth: currentMonthExpenses, allExpenses: expenses, income: income, dayOfMonth: dayOfMonth, daysInMonth: daysInMonth))

        </financial_context>
        """
    }

    // MARK: - Category breakdown

    private static func buildCategoryBreakdown(expenses: [Expense], income: Double) -> String {
        guard !expenses.isEmpty else { return "" }

        let byCategory = Dictionary(grouping: expenses, by: { $0.category })
        let sorted = byCategory
            .map { (cat, exps) in (cat, exps.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }

        var lines = ["<categorias>"]
        for (category, amount) in sorted {
            let pctStr = income > 0 ? " (\(pct(amount, of: income))%)" : ""
            lines.append("- \(category): \(fmt(amount))€\(pctStr)")

            // Subcategorías solo si hay más de una
            let bySubcat = Dictionary(grouping: byCategory[category] ?? [], by: { $0.subcategory ?? "" })
                .filter { !$0.key.isEmpty }
            if bySubcat.count > 1 {
                let subcats = bySubcat
                    .map { (sub, exps) in "  · \(sub): \(fmt(exps.reduce(0) { $0 + $1.amount }))€" }
                    .sorted()
                subcats.forEach { lines.append($0) }
            }
        }
        lines.append("</categorias>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Spending limits (shields) vs actual spend

    private static func buildSpendingLimits(goals: [Goal], expenses: [Expense]) -> String {
        let shields = goals.filter { $0.type == .spendingLimit && !$0.isArchived }
        guard !shields.isEmpty else { return "" }

        var lines = ["<limites_gasto>"]
        for shield in shields {
            let catId = shield.linkedCategoryId ?? ""
            let target = normalizeCategory(catId)
            let spent = expenses
                .filter {
                    let catPart = $0.category.components(separatedBy: " / ").first ?? $0.category
                    return normalizeCategory(catPart) == target
                }
                .reduce(0) { $0 + $1.amount }
            let limit = shield.targetAmount
            let usage = pct(spent, of: limit)
            let status = spent > limit ? "EXCEDIDO +\(fmt(spent - limit))€" :
                         usage >= 80 ? "ALERTA" : "OK"
            lines.append("- \(escapeXML(shield.name)): \(fmt(spent))€ / \(fmt(limit))€ (\(usage)%) [\(status)]")
        }
        lines.append("</limites_gasto>")
        return lines.joined(separator: "\n")
    }

    private static func normalizeCategory(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .unicodeScalars
            .filter { CharacterSet.letters.union(.whitespaces).contains($0) }
            .reduce("") { $0 + String($1) }
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - ALL expenses this month (not just top 5)

    private static func buildAllExpenses(expenses: [Expense]) -> String {
        guard !expenses.isEmpty else { return "" }

        let sorted = expenses.sorted { $0.amount > $1.amount }
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "d MMM"
        dayFmt.locale = Locale(identifier: "es_ES")

        var lines = ["<gastos_detalle count=\"\(sorted.count)\">"]
        for exp in sorted.prefix(80) {  // cap at 80 to stay within token budget
            let date = Formatters.date(from: exp.date).map { dayFmt.string(from: $0) } ?? exp.date
            let sub = exp.subcategory.map { "/\(escapeXML($0))" } ?? ""
            lines.append("- \(date) | \(escapeXML(exp.name)) [\(escapeXML(exp.category))\(sub)]: \(fmt(exp.amount))€")
        }
        if sorted.count > 80 {
            let rest = sorted.dropFirst(80).reduce(0) { $0 + $1.amount }
            lines.append("- ... y \(sorted.count - 80) gastos más: \(fmt(rest))€")
        }
        lines.append("</gastos_detalle>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Last 3 months trend with category breakdown

    private static func buildLast3MonthsTrend(
        expenses: [Expense], calendar: Calendar, now: Date
    ) -> String {
        var lines = ["<tendencia_3_meses>"]

        for offset in stride(from: -2, through: 0, by: 1) {
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: now) else { continue }
            let monthExpenses = expenses.filter {
                calendar.isDate($0.dateAsDate, equalTo: monthDate, toGranularity: .month)
            }
            let total = monthExpenses.reduce(0) { $0 + $1.amount }
            let name = Self.shortMonthFmt.string(from: monthDate).capitalized
            let label = offset == 0 ? " (en curso)" : ""

            // Top 3 categories for this month
            let topCats = Dictionary(grouping: monthExpenses, by: { $0.category })
                .map { (cat, exps) in (cat, exps.reduce(0) { $0 + $1.amount }) }
                .sorted { $0.1 > $1.1 }
                .prefix(3)
                .map { "\($0.0): \(fmt($0.1))€" }
                .joined(separator: ", ")

            lines.append("- \(name)\(label): \(fmt(total))€ (\(monthExpenses.count) gastos)\(topCats.isEmpty ? "" : " | \(topCats)")")
        }

        lines.append("</tendencia_3_meses>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Goals

    private static func buildGoalsSection(goals: [Goal]) -> String {
        let active = goals.filter { !$0.isArchived }
        guard !active.isEmpty else { return "" }

        var lines = ["<metas>"]
        for goal in active {
            let progress = goal.targetAmount > 0
                ? Int((goal.currentAmount / goal.targetAmount) * 100) : 0
            let tipo = goal.type == .savingsTarget ? "Hucha" : "Límite"
            lines.append(
                "- [\(tipo)] \(escapeXML(goal.name)): \(fmt(goal.currentAmount))€ / \(fmt(goal.targetAmount))€ (\(progress)%)"
            )
        }
        lines.append("</metas>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Recurring expenses

    private static func buildRecurringSection(recurring: [RecurringExpense]) -> String {
        let active = recurring.filter { $0.active }
        guard !active.isEmpty else { return "" }

        let total = active.reduce(0) { $0 + $1.amount }
        var lines = ["<compromisos_fijos total=\"\(fmt(total))€/mes\">"]
        for r in active.sorted(by: { $0.amount > $1.amount }) {
            let freq: String
            switch r.frequency {
            case .monthly:    freq = "mensual"
            case .quarterly:  freq = "trimestral"
            case .semestral:  freq = "semestral"
            case .yearly:     freq = "anual"
            }
            lines.append("- \(escapeXML(r.name)) [\(escapeXML(r.category))]: \(fmt(r.amount))€ (\(freq))")
        }
        lines.append("</compromisos_fijos>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Quick insights

    private static func buildInsights(
        currentMonth: [Expense], allExpenses: [Expense], income: Double,
        dayOfMonth: Int, daysInMonth: Int
    ) -> String {
        guard !currentMonth.isEmpty else { return "" }

        var lines = ["<insights>"]

        // Biggest expense this month
        if let biggest = currentMonth.max(by: { $0.amount < $1.amount }) {
            lines.append("Gasto más grande: \(escapeXML(biggest.name)) — \(fmt(biggest.amount))€ [\(escapeXML(biggest.category))]")
        }

        // Day-of-week analysis: which weekday do they spend the most?
        let calendar = Calendar.current
        let byWeekday = Dictionary(grouping: currentMonth) {
            calendar.component(.weekday, from: $0.dateAsDate)
        }
        if let (weekday, exps) = byWeekday.max(by: { $0.value.reduce(0) { $0 + $1.amount } < $1.value.reduce(0) { $0 + $1.amount } }) {
            let dayName = calendar.weekdaySymbols[weekday - 1].capitalized
            let total = exps.reduce(0) { $0 + $1.amount }
            lines.append("Día de mayor gasto: \(dayName) (\(fmt(total))€ en \(exps.count) gastos)")
        }

        // Spending pace indicator
        if income > 0 && dayOfMonth > 0 {
            let pctMonth = Double(dayOfMonth) / Double(daysInMonth) * 100
            let totalSpent = currentMonth.reduce(0) { $0 + $1.amount }
            let pctIncome = totalSpent / income * 100
            let pace = pctIncome - pctMonth
            if pace > 10 {
                lines.append("Ritmo: gasto va +\(Int(pace))pp por encima del ritmo uniforme")
            } else if pace < -10 {
                lines.append("Ritmo: gasto va \(Int(pace))pp por debajo — buen control")
            } else {
                lines.append("Ritmo: gasto alineado con el avance del mes")
            }
        }

        // Count of expenses
        lines.append("Total operaciones: \(currentMonth.count) gastos este mes")

        lines.append("</insights>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Shared formatters (static, created once)

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    private static let shortMonthFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    // MARK: - Helpers

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Sanitiza texto del usuario para que no rompa la estructura XML del prompt
    /// (mitigación básica de prompt-injection vía nombres/notas de gastos).
    private static func escapeXML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func pct(_ value: Double, of total: Double) -> Int {
        guard total > 0 else { return 0 }
        return Int((value / total) * 100)
    }
}
