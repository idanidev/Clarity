// ExpenseParser.swift
// Natural language parser for voice expenses

import Foundation

struct ParsedExpense {
    let amount: Double
    let category: String?
    let subcategory: String?
    let name: String
    let confidence: Double
}

class ExpenseParser {
    
    // MARK: - Public Methods
    
    static func parse(_ text: String, categories: [Category]) -> ParsedExpense? {
        let converted = convertNumberWords(text)
        let lowerText = converted.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract amount
        guard let amount = extractAmount(from: lowerText) else {
            return nil
        }
        
        // Extract category and subcategory
        let (category, subcategory) = extractCategory(from: lowerText, categories: categories)
        
        // Extract description
        let description = extractDescription(from: text, amount: amount)
        
        // Calculate confidence based on what was detected
        var confidence = 0.5 // Base confidence for having an amount
        if category != nil { confidence += 0.3 }
        if subcategory != nil { confidence += 0.2 }
        
        return ParsedExpense(
            amount: amount,
            category: category,
            subcategory: subcategory,
            name: description,
            confidence: min(confidence, 1.0)
        )
    }
    
    // MARK: - Private Helpers
    
    private static func extractAmount(from text: String) -> Double? {
        // Match patterns like: "25", "25.50", "25,50", "25 euros"
        let patterns = [
            #"(\d+(?:[.,]\d+)?)\s*(?:euros?|€)?"#,
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let amountRange = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[amountRange]).replacingOccurrences(of: ",", with: ".")
                if let amount = Double(amountStr) {
                    return amount
                }
            }
        }
        
        return nil
    }
    
    private static func extractCategory(from text: String, categories: [Category]) -> (String?, String?) {
        // First, try to match user's categories and subcategories
        for category in categories {
            let catNameClean = category.name.replacingOccurrences(of: #"\s*[\p{Emoji}]"#, with: "", options: .regularExpression).lowercased()
            
            // Check subcategories first (more specific)
            for subcategory in category.subcategories {
                if text.contains(subcategory.lowercased()) {
                    return (category.name, subcategory)
                }
            }
            
            // Check category name
            if !catNameClean.isEmpty && text.contains(catNameClean) {
                return (category.name, nil)
            }
        }
        
        // Fallback: keyword matching
        let keywords: [String: [String]] = [
            "Alimentación": ["supermercado", "comida", "mercado", "cena", "desayuno", "almuerzo", "restaurante", "cafetería", "café", "pizza", "burguer"],
            "Transporte": ["gasolina", "combustible", "parking", "taxi", "uber", "transporte", "metro", "bus", "tren", "peaje"],
            "Ocio": ["cine", "teatro", "concierto", "fiesta", "copas", "bar", "cerveza", "birra"],
            "Salud": ["farmacia", "médico", "doctor", "hospital", "dentista"],
            "Hogar": ["casa", "hogar", "alquiler", "luz", "agua", "gas", "internet"],
            "Ropa": ["ropa", "zapatos", "vestir"],
        ]
        
        for (catName, words) in keywords {
            for word in words {
                if text.contains(word) {
                    // Try to find matching user category
                    if let userCat = categories.first(where: { $0.name.localizedCaseInsensitiveContains(catName) }) {
                        return (userCat.name, nil)
                    }
                    return (catName, nil)
                }
            }
        }
        
        return (nil, nil)
    }
    
    private static func extractDescription(from text: String, amount: Double) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove command words
        let commandPatterns = [
            "^añádeme\\s+", "^añade\\s+", "^añadir\\s+",
            "^gasta\\s+", "^gastado\\s+", "^he\\s+gastado\\s+",
            "^compra\\s+", "^comprado\\s+"
        ]
        
        for pattern in commandPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // Try to extract description after "en" or "de"
        if let match = cleaned.range(of: #"(?:en|de)\s+(.+)$"#, options: .regularExpression) {
            let description = String(cleaned[match])
                .replacingOccurrences(of: #"^(?:en|de)\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\d+(?:[.,]\d+)?\s*(?:euros?|€)?"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty {
                return description.prefix(1).uppercased() + description.dropFirst()
            }
        }
        
        // Remove amount from anywhere
        cleaned = cleaned.replacingOccurrences(of: #"\d+(?:[.,]\d+)?\s*(?:euros?|€)?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleaned.isEmpty {
            return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func convertNumberWords(_ text: String) -> String {
        let numberWords: [String: Int] = [
            "cero": 0, "uno": 1, "una": 1, "dos": 2, "tres": 3, "cuatro": 4,
            "cinco": 5, "seis": 6, "siete": 7, "ocho": 8, "nueve": 9,
            "diez": 10, "once": 11, "doce": 12, "trece": 13, "catorce": 14,
            "quince": 15, "dieciséis": 16, "dieciseis": 16, "diecisiete": 17,
            "dieciocho": 18, "diecinueve": 19,
            "veinte": 20, "veintiuno": 21, "veintidós": 22, "veintidos": 22,
            "veintitrés": 23, "veintitres": 23, "veinticuatro": 24, "veinticinco": 25,
            "veintiséis": 26, "veintiseis": 26, "veintisiete": 27, "veintiocho": 28, "veintinueve": 29,
            "treinta": 30, "cuarenta": 40, "cincuenta": 50, "sesenta": 60,
            "setenta": 70, "ochenta": 80, "noventa": 90,
            "cien": 100, "ciento": 100, "doscientos": 200, "trescientos": 300,
            "cuatrocientos": 400, "quinientos": 500, "seiscientos": 600,
            "setecientos": 700, "ochocientos": 800, "novecientos": 900,
        ]
        
        var result = text
        
        for (word, digit) in numberWords {
            result = result.replacingOccurrences(
                of: #"\b\#(word)\b"#,
                with: String(digit),
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Handle "X y Y" patterns (e.g., "30 y 5" -> "35")
        result = result.replacingOccurrences(
            of: #"(\d+)\s+y\s+(\d+)"#,
            with: "$1$2",
            options: .regularExpression
        )
        
        return result
    }
}
