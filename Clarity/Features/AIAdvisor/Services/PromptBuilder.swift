//
//  PromptBuilder.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  Optimizes financial data for AI context window (Token Efficient)
//

import Foundation

struct PromptBuilder {

    // MARK: - Core Methods

    static func buildFinancialContext(
        user: UserDocument?, expenses: [Expense], goals: [Goal], monthBudget: MonthlyBudget?
    ) -> String {
        let profileSection = buildProfileSection(user: user, budget: monthBudget, goals: goals)
        let budgetSection = buildBudgetSection(budget: monthBudget, expenses: expenses)  // Monthly focus
        let historicalSection = buildHistoricalSection(expenses: expenses)  // Global focus
        let topExpensesSection = buildTopExpensesSection(expenses: expenses)
        let patternsSection = detectPatterns(expenses: expenses)
        let principlesSection = buildPrinciplesSection()

        // XML-style tagging for better model comprehension
        return """
            <financial_context>
            \(profileSection)

            \(budgetSection)

            \(historicalSection)

            \(topExpensesSection)

            \(patternsSection)

            \(principlesSection)
            </financial_context>
            """
    }

    // MARK: - Sections

    private static func buildProfileSection(
        user: UserDocument?, budget: MonthlyBudget?, goals: [Goal]
    ) -> String {
        let income = budget?.income ?? 0
        let savingsAllocated = budget?.savingsAllocated ?? 0

        // Find top active goal
        let topGoal = goals.filter { !$0.isAchieved && !$0.isArchived }.first
        let goalStatus =
            topGoal != nil
            ? "\(topGoal!.name) (\(Int((topGoal!.currentAmount / topGoal!.targetAmount) * 100))% completada)"
            : "Sin metas activas"

        return """
            <user_profile>
            <income_est>\(Int(income))</income_est>
            <savings_allocated>\(Int(savingsAllocated))</savings_allocated>
            <free_cash>\(Int(income - savingsAllocated))</free_cash>
            <main_goal>\(goalStatus)</main_goal>
            </user_profile>
            """
    }

    private static func buildBudgetSection(budget: MonthlyBudget?, expenses: [Expense]) -> String {
        // Filter for current month only to show CURRENT STATUS
        let currentMonthExpenses = expenses.filter {
            Calendar.current.isDate($0.dateAsDate, equalTo: Date(), toGranularity: .month)
        }

        // Group expenses by category
        let expensesByCategory = Dictionary(grouping: currentMonthExpenses, by: { $0.category })
        let spentByCategory = expensesByCategory.mapValues { $0.reduce(0) { $0 + $1.amount } }

        // Compare with budget limits (if available) - For now just listing top spent categories
        let topCategories = spentByCategory.sorted { $0.value > $1.value }.prefix(3)

        var lines = ["<current_month_status>"]

        if topCategories.isEmpty {
            lines.append("<status>No hay gastos registrados este mes.</status>")
        } else {
            lines.append("<top_categories>")
            for (category, amount) in topCategories {
                lines.append("<category name=\"\(category)\">\(Int(amount))</category>")
            }
            lines.append("</top_categories>")
        }

        // Budget health check
        let totalSpent = currentMonthExpenses.reduce(0) { $0 + $1.amount }

        if let income = budget?.income, income > 0 {
            let ratio = totalSpent / income

            // Contexto de presupuesto
            lines.append(
                "<summary>Estado: \(Int(totalSpent))€ gastados de ~\(Int(income))€ estimados.</summary>"
            )

            if ratio > 1.0 {
                lines.append(
                    "<alert type=\"over_budget\">Has superado tus ingresos estimados este mes.</alert>"
                )
            }
        } else {
            lines.append("<summary>Total gastado este mes: \(Int(totalSpent))€</summary>")
        }

        lines.append("</current_month_status>")

        return lines.joined(separator: "\n")
    }

    private static func buildHistoricalSection(expenses: [Expense]) -> String {
        guard !expenses.isEmpty else {
            return "<historical_data>Sin datos históricos.</historical_data>"
        }

        // 1. Calculate Date Range
        let sortedDates = expenses.map { $0.dateAsDate }.sorted()
        guard let firstDate = sortedDates.first, let lastDate = sortedDates.last else { return "" }

        let components = Calendar.current.dateComponents([.month], from: firstDate, to: lastDate)
        let months = max(1, (components.month ?? 0) + 1)  // Avoid division by zero, min 1 month

        // 2. Calculate Totals
        let totalSpent = expenses.reduce(0) { $0 + $1.amount }
        let averageMonthly = totalSpent / Double(months)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        return """
            <historical_data>
            <range>\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate)) (\(months) meses)</range>
            <total_spent>\(Int(totalSpent))</total_spent>
            <average_monthly>\(Int(averageMonthly))</average_monthly>
            <note>Al analizar "todos los gastos", usa este promedio mensual para evaluar la salud financiera, NO el total histórico acumulado.</note>
            </historical_data>
            """
    }

    private static func buildTopExpensesSection(expenses: [Expense]) -> String {
        // We show global top expenses to help identify big ticket items historically
        let sortedExpenses = expenses.sorted { $0.amount > $1.amount }
        let top5 = sortedExpenses.prefix(5)

        var lines = ["<historical_top_expenses>"]

        for (index, expense) in top5.enumerated() {
            let dateStr = expense.dateAsDate.formatted(.dateTime.day().month().year())
            lines.append(
                "<expense rank=\"\(index + 1)\" name=\"\(expense.name)\" category=\"\(expense.category)\" date=\"\(dateStr)\">\(Int(expense.amount))</expense>"
            )
        }

        lines.append("</historical_top_expenses>")

        return lines.joined(separator: "\n")
    }

    private static func detectPatterns(expenses: [Expense]) -> String {
        // Enhanced pattern detection using global data
        let groupedByName = Dictionary(grouping: expenses, by: { $0.name.lowercased() })
        let recurrences = groupedByName.filter { $0.value.count >= 3 }  // Must happen at least 3 times

        var patterns: [String] = []

        for (name, occurrences) in recurrences {
            let total = occurrences.reduce(0) { $0 + $1.amount }
            let avg = total / Double(occurrences.count)
            if avg > 20 {  // Only significant recurring expenses
                patterns.append(
                    "<pattern name=\"\(name.capitalized)\" count=\"\(occurrences.count)\">~\(Int(avg))€/vez</pattern>"
                )
            }
        }

        if patterns.isEmpty { return "" }

        return """
            <recurring_patterns>
            \(patterns.joined(separator: "\n"))
            </recurring_patterns>
            """
    }

    private static func buildPrinciplesSection() -> String {
        return """
            <financial_principles>
            <rule name="50/30/20">Idealmente: 50% Necesidades, 30% Deseos, 20% Ahorro/Deuda.</rule>
            <rule name="Emergency Fund">Prioridad #1: Tener 3-6 meses de gastos ahorrados.</rule>
            <rule name="High Interest Debt">Si hay deuda >5%, pagarla antes de invertir agresivamente.</rule>
            <rule name="Impulse Buying">Si es un 'Deseo' > 50€, sugiere esperar 24h.</rule>
            </financial_principles>
            """
    }
}
