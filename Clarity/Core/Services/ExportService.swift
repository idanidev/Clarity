// ExportService.swift
import Foundation
import UIKit

class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    func generateCSV(from expenses: [Expense]) -> URL? {
        var csvString = "Fecha,Nombre,Categoría,Subcategoría,Cantidad,Método de Pago,Notas\n"
        
        for expense in expenses {
            let row = [
                expense.date,
                expense.name.replacingOccurrences(of: ",", with: " "),
                expense.category.replacingOccurrences(of: ",", with: " "),
                expense.subcategory?.replacingOccurrences(of: ",", with: " ") ?? "",
                String(format: "%.2f", expense.amount),
                expense.paymentMethod,
                expense.notes?.replacingOccurrences(of: ",", with: " ") ?? ""
            ].joined(separator: ",")
            
            csvString.append(row + "\n")
        }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let fileName = "Clarity_Gastos_\(Formatters.isoString(from: Date())).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error generating CSV: \(error)")
            return nil
        }
    }
}
