// ExportService.swift
import Foundation
import OSLog
import UIKit

class ExportService: @unchecked Sendable {
    static let shared = ExportService()
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "ExportService")

    private init() {}

    // MARK: - CSV Import (parse only, no persistence)

    /// Parses a CSV file into an array of Expense without saving anything.
    func parseCSV(from url: URL) throws -> [Expense] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Skip header row
        guard rows.count > 1 else { return [] }

        var expenses: [Expense] = []
        for row in rows.dropFirst() {
            let columns = parseCSVRow(row)
            guard columns.count >= 5 else { continue }

            let date = columns[0].trimmingCharacters(in: .whitespaces)
            let name = columns[1].trimmingCharacters(in: .whitespaces)
            let category = columns[2].trimmingCharacters(in: .whitespaces)
            let subcategory = columns.count > 3 ? columns[3].trimmingCharacters(in: .whitespaces) : nil
            let amountString = columns[4].trimmingCharacters(in: .whitespaces)
            let paymentMethod = columns.count > 5 ? columns[5].trimmingCharacters(in: .whitespaces) : "Tarjeta"
            let notes = columns.count > 6 ? columns[6].trimmingCharacters(in: .whitespaces) : nil

            guard let amount = Double(amountString), !name.isEmpty, !date.isEmpty else { continue }

            let expense = Expense(
                amount: amount,
                name: name,
                category: category,
                subcategory: subcategory?.isEmpty == true ? nil : subcategory,
                date: date,
                paymentMethod: paymentMethod.isEmpty ? "Tarjeta" : paymentMethod,
                notes: notes?.isEmpty == true ? nil : notes
            )
            expenses.append(expense)
        }

        return expenses
    }

    /// Parses a single CSV row handling quoted fields with commas.
    private func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - CSV Export

    func generateCSV(from expenses: [Expense]) -> URL? {
        // RFC 4180: cada campo entre comillas, comillas internas duplicadas.
        func quote(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var csvString = ["Fecha","Nombre","Categoría","Subcategoría","Cantidad","Método de Pago","Notas"]
            .map(quote).joined(separator: ",") + "\r\n"

        for expense in expenses {
            let row = [
                expense.date,
                expense.name,
                expense.category,
                expense.subcategory ?? "",
                String(format: "%.2f", expense.amount),
                expense.paymentMethod,
                expense.notes ?? ""
            ].map(quote).joined(separator: ",")

            csvString.append(row + "\r\n")
        }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let fileName = "Clarity_Gastos_\(Formatters.isoString(from: Date())).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            logger.error("Error generating CSV: \(error)")
            return nil
        }
    }
}
