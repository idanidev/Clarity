//
//  CSVParser.swift
//  Clarity
//
//  Created by Clarity AI.
//  Simple CSV Parser for bank exports.
//

import Foundation

struct RawTransaction: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let description: String
    let amount: Double
    var category: String? = nil // To be filled by AI
}

enum CSVError: LocalizedError {
    case invalidFormat
    case emptyFile
    case parsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Formato CSV no reconocido"
        case .emptyFile: return "El archivo está vacío"
        case .parsingError(let msg): return "Error al leer: \(msg)"
        }
    }
}

class CSVParser {
    
    /// Parses a CSV string into RawTransactions
    /// Tries to auto-detect columns: Date, Amount, Description
    static func parse(_ content: String) throws -> [RawTransaction] {
        let rows = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard rows.count > 1 else { throw CSVError.emptyFile } // Header + 1 row minimum
        
        let header = rows[0].lowercased()
        let separator = detectSeparator(header)
        
        // Simple heuristic for column indices
        let columns = header.components(separatedBy: String(separator))
        
        let dateIndex = columns.firstIndex(where: { $0.contains("date") || $0.contains("fecha") || $0.contains("día") })
        let descIndex = columns.firstIndex(where: { $0.contains("concept") || $0.contains("desc") || $0.contains("merchant") })
        let amountIndex = columns.firstIndex(where: { $0.contains("amount") || $0.contains("impor") || $0.contains("cant") })
        
        guard let dIdx = dateIndex, let descIdx = descIndex, let amtIdx = amountIndex else {
            throw CSVError.invalidFormat
        }
        
        var transactions: [RawTransaction] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy" // Default European format, can be improved
        
        // Parse rows (skipping header)
        for (_, row) in rows.dropFirst().enumerated() {
            let values = parseRow(row, separator: separator)
            guard values.count > max(dIdx, descIdx, amtIdx) else { continue }
            
            let dateStr = values[dIdx].trimmingCharacters(in: .whitespacesAndNewlines)
            let descStr = values[descIdx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            let amountStr = values[amtIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: ".", with: "") // European format 1.000,00 -> 1000,00
                .replacingOccurrences(of: ",", with: ".") // 1000,00 -> 1000.00
            
            if let date = dateFormatter.date(from: dateStr),
               let amount = Double(amountStr) {
                // Invert amount if expenses are negative (banks usually export expenses as negative)
                // In Clarity we store expenses as positive doubles
                let finalAmount = abs(amount)
                
                transactions.append(RawTransaction(date: date, description: descStr, amount: finalAmount))
            }
        }
        
        return transactions
    }
    
    // Helpers
    
    private static func detectSeparator(_ header: String) -> Character {
        if header.contains(";") { return ";" }
        return ","
    }
    
    private static func parseRow(_ row: String, separator: Character) -> [String] {
        // Basic split, doesn't handle quoted separators perfectly but suffices for most bank CSVs
        return row.split(separator: separator, omittingEmptySubsequences: false).map { String($0) }
    }
}
