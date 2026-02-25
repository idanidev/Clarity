import Foundation

let selectedMonth = Date()
let calendar2 = Calendar.current
let monthComponents = calendar2.dateComponents([.year, .month], from: selectedMonth)
let monthStart = calendar2.date(from: monthComponents) ?? selectedMonth
let monthEnd = calendar2.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? selectedMonth

let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"

print("customStartDate: \(formatter.string(from: monthStart))")
print("customEndDate: \(formatter.string(from: monthEnd))")

// Let's see what "thisMonth" does:
let thisMonthStart = calendar2.date(from: calendar2.dateComponents([.year, .month], from: Date()))!
let thisMonthEnd = calendar2.date(byAdding: DateComponents(month: 1, day: -1), to: thisMonthStart)!
print("thisMonthStartDate: \(formatter.string(from: thisMonthStart))")
print("thisMonthEndDate: \(formatter.string(from: thisMonthEnd))")

