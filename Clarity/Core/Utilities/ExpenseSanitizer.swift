// ExpenseSanitizer.swift
// Utilities to clean up and validate expense data
import Foundation

struct ExpenseSanitizer {
    
    /// Sanitizes the list of expenses by removing duplicates and fixing recurring anomalies
    static func sanitize(expenses: [Expense], rules: [RecurringExpense]) -> [Expense] {
        var cleanExpenses = expenses
        let rulesMap = Dictionary(uniqueKeysWithValues: rules.map { ($0.id ?? "", $0) })
        
        // 1. Filter out blatant anomalies
    cleanExpenses = cleanExpenses.filter { expense in
            // If it's a recurring expense, validate against its rule
            if let recurringId = expense.recurringId, let rule = rulesMap[recurringId] {
                
                // Rule: Annual expenses should only appear in their billing month (unless manually moved?)
                // We assume auto-generated ones generally stick to the schedule. 
                // If an annual expense appears in a different month, it's likely a generator glitch.
                if rule.frequency == .yearly && rule.billingMonth > 0 {
                    let expenseDate = expense.dateAsDate
                    let expenseMonth = Calendar.current.component(.month, from: expenseDate)
                    
                    if expenseMonth != rule.billingMonth {
                        // print("⚠️ Sanitizer: Removing misplaced annual expense...)
                        return false
                    }
                }
            }
            return true
        }
        
        // 2. Deduplicate by Recurring Period
        // Keep track of seen periods for each recurring rule
        var seenRecurringPeriods: [String: Set<String>] = [:] // RecurringID -> Set("YYYY-MM")
        var expensesToRemoveIndices: Set<Int> = []
        
        // iterate carefully to preserve order (assuming descending date)
        for (index, expense) in cleanExpenses.enumerated() {
            guard let recurringId = expense.recurringId, let rule = rulesMap[recurringId] else { continue }
            
            let periodKey: String
            let date = expense.dateAsDate
            let year = Calendar.current.component(.year, from: date)
            let month = Calendar.current.component(.month, from: date)
            
            // Define what constitutes a "Period" for this rule
            switch rule.frequency {
            case .monthly:
                periodKey = "\(year)-\(month)"
            case .quarterly:
                let quarter = (month - 1) / 3
                periodKey = "\(year)-Q\(quarter)"
            case .semestral:
                let semester = (month - 1) / 6
                periodKey = "\(year)-S\(semester)"
            case .yearly:
                periodKey = "\(year)"
            }
            
            if seenRecurringPeriods[recurringId, default: []].contains(periodKey) {
                // Duplicate found for this period!
                // Since list is descending (newest first), we might want to keep the NEWEST or the OLDEST?
                // Usually keeping the cached/first value is safer, OR if we iterate backwards?
                // `expenses` usually comes sorted by Date Descending.
                // So the first one we verify is the LATEST one. We should keep it and discard OLDER duplicates.
                // Or if they are truly identical, it doesn't matter.
                // But if they are duplicates in the SAME day, we discard subsequent ones.
                
                // print("⚠️ Sanitizer: Removing duplicate recurring expense...)
                expensesToRemoveIndices.insert(index)
            } else {
                seenRecurringPeriods[recurringId, default: []].insert(periodKey)
            }
        }
        
        // Remove marked duplicates
        if !expensesToRemoveIndices.isEmpty {
            cleanExpenses = cleanExpenses.enumerated()
                .filter { !expensesToRemoveIndices.contains($0.offset) }
                .map { $0.element }
        }
        
        // 3. General ID Deduplication (Safety Net)
        var seenIds = Set<String>()
        cleanExpenses = cleanExpenses.filter { expense in
            guard let id = expense.id, !id.isEmpty else { return true }
            if seenIds.contains(id) { return false }
            seenIds.insert(id)
            return true
        }
        
        return cleanExpenses
    }
}
