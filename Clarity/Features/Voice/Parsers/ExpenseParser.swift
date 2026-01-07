// ExpenseParser.swift
// Natural language parser for voice expenses with improved detection

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
        print("🔍 Parsing: '\(text)'")
        
        // Normalize text
        let normalized = normalizeText(text)
        print("📝 Normalized: '\(normalized)'")
        
        // 1. Extract amount
        guard let amount = extractAmountImproved(from: normalized) else {
            print("❌ No amount found")
            return nil
        }
        print("✅ Amount: \(amount)")
        
        // 2. Extract category and subcategory
        let (category, subcategory) = extractCategoryImproved(from: normalized, categories: categories)
        print("✅ Category: \(category ?? "nil"), Subcategory: \(subcategory ?? "nil")")
        
        // 3. Extract description
        let description = extractDescriptionImproved(from: text, amount: amount, category: category)
        print("✅ Description: '\(description)'")
        
        // 4. Calculate confidence
        let confidence = calculateConfidence(
            hasAmount: true,
            hasCategory: category != nil,
            hasSubcategory: subcategory != nil,
            descriptionQuality: description.count > 3 ? 0.1 : 0.0
        )
        print("✅ Confidence: \(confidence)")
        
        return ParsedExpense(
            amount: amount,
            category: category,
            subcategory: subcategory,
            name: description,
            confidence: min(confidence, 1.0)
        )
    }
    
    // MARK: - Amount Extraction (Improved)
    
    private static func extractAmountImproved(from text: String) -> Double? {
        // Pattern 1: "X con Y" / "X coma Y" / "X punto Y" -> X.Y
        let compositePatterns = [
            #"(\d+)\s+(?:con|coma|punto)\s+(\d+)"#,
            #"(\d+)\s+y\s+(\d{1,2})\s*(?:céntimos?|centimos?|cents?)?"#
        ]
        
        for pattern in compositePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges >= 3,
               let range1 = Range(match.range(at: 1), in: text),
               let range2 = Range(match.range(at: 2), in: text),
               let euros = Int(text[range1]),
               let cents = Int(text[range2]) {
                return Double(euros) + (Double(cents) / 100.0)
            }
        }
        
        // Pattern 2: Standard number with optional currency
        let simplePatterns = [
            #"(\d+(?:[.,]\d{1,2})?)\s*(?:euros?|€)"#,  // With currency
            #"(\d+[.,]\d{1,2})"#,                       // Decimal number
            #"(\d+)"#                                    // Just digits
        ]
        
        for pattern in simplePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                if let amount = Double(amountStr), amount > 0 {
                    return amount
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Category Extraction (Improved with Fuzzy Matching)
    
    private static func extractCategoryImproved(from text: String, categories: [Category]) -> (String?, String?) {
        let words = Set(text.lowercased().split(separator: " ").map { String($0) })
        
        // 1. Try exact subcategory match first (most specific)
        for category in categories {
            for subcategory in category.subcategories {
                let subLower = subcategory.lowercased()
                if text.lowercased().contains(subLower) {
                    print("📍 Exact subcategory match: \(subcategory) in \(category.name)")
                    return (category.name, subcategory)
                }
            }
        }
        
        // 2. Try partial subcategory match (word-by-word)
        for category in categories {
            for subcategory in category.subcategories {
                let subWords = subcategory.lowercased().split(separator: " ").map { String($0) }
                for subWord in subWords where subWord.count > 3 {
                    if words.contains(where: { $0.contains(subWord) || subWord.contains($0) }) {
                        print("📍 Partial subcategory: \(subcategory) in \(category.name)")
                        return (category.name, subcategory)
                    }
                }
            }
        }
        
        // 3. Try category name match
        for category in categories {
            let catName = category.name
                .replacingOccurrences(of: #"[\p{Emoji}]"#, with: "", options: .regularExpression)
                .lowercased()
                .trimmingCharacters(in: .whitespaces)
            
            if !catName.isEmpty && text.lowercased().contains(catName) {
                print("📍 Category match: \(category.name)")
                return (category.name, nil)
            }
        }
        
        // 4. Keyword-based matching (expanded dictionary)
        let keywords: [String: (category: String, subcategory: String?)] = [
            // Alimentación
            "supermercado": ("Alimentacion", "Supermercado"),
            "mercado": ("Alimentacion", "Supermercado"),
            "mercadona": ("Alimentacion", "Supermercado"),
            "carrefour": ("Alimentacion", "Supermercado"),
            "lidl": ("Alimentacion", "Supermercado"),
            "aldi": ("Alimentacion", "Supermercado"),
            "dia": ("Alimentacion", "Supermercado"),
            "alcampo": ("Alimentacion", "Supermercado"),
            "restaurante": ("Alimentacion", "Restaurantes"),
            "cena": ("Alimentacion", "Restaurantes"),
            "almuerzo": ("Alimentacion", "Restaurantes"),
            "comida": ("Alimentacion", "Restaurantes"),
            "pizza": ("Alimentacion", "Restaurantes"),
            "burguer": ("Alimentacion", "Restaurantes"),
            "hamburguesa": ("Alimentacion", "Restaurantes"),
            "sushi": ("Alimentacion", "Restaurantes"),
            "café": ("Alimentacion", "Cafeterías"),
            "cafetería": ("Alimentacion", "Cafeterías"),
            "starbucks": ("Alimentacion", "Cafeterías"),
            "desayuno": ("Alimentacion", "Cafeterías"),
            
            // Transporte
            "gasolina": ("Transporte", "Gasolina"),
            "combustible": ("Transporte", "Gasolina"),
            "diesel": ("Transporte", "Gasolina"),
            "gasolinera": ("Transporte", "Gasolina"),
            "repsol": ("Transporte", "Gasolina"),
            "cepsa": ("Transporte", "Gasolina"),
            "parking": ("Transporte", "Parking"),
            "aparcamiento": ("Transporte", "Parking"),
            "taxi": ("Transporte", "Taxi"),
            "uber": ("Transporte", "Taxi"),
            "cabify": ("Transporte", "Taxi"),
            "bolt": ("Transporte", "Taxi"),
            "metro": ("Transporte", "Transporte público"),
            "autobús": ("Transporte", "Transporte público"),
            "autobus": ("Transporte", "Transporte público"),
            "bus": ("Transporte", "Transporte público"),
            "tren": ("Transporte", "Transporte público"),
            "renfe": ("Transporte", "Transporte público"),
            "cercanías": ("Transporte", "Transporte público"),
            "peaje": ("Transporte", "Peajes"),
            
            // Ocio
            "cine": ("Ocio", "Cine"),
            "película": ("Ocio", "Cine"),
            "cerveza": ("Ocio", "Bares"),
            "birra": ("Ocio", "Bares"),
            "copas": ("Ocio", "Bares"),
            "bar": ("Ocio", "Bares"),
            "discoteca": ("Ocio", "Bares"),
            "concierto": ("Ocio", "Eventos"),
            "teatro": ("Ocio", "Eventos"),
            "fiesta": ("Ocio", "Eventos"),
            "gimnasio": ("Ocio", "Gimnasio"),
            "gym": ("Ocio", "Gimnasio"),
            "netflix": ("Ocio", "Suscripciones"),
            "spotify": ("Ocio", "Suscripciones"),
            "hbo": ("Ocio", "Suscripciones"),
            "disney": ("Ocio", "Suscripciones"),
            "amazon": ("Ocio", "Suscripciones"),
            
            // Salud
            "farmacia": ("Salud", "Farmacia"),
            "medicinas": ("Salud", "Farmacia"),
            "medicina": ("Salud", "Farmacia"),
            "médico": ("Salud", "Médico"),
            "medico": ("Salud", "Médico"),
            "doctor": ("Salud", "Médico"),
            "dentista": ("Salud", "Dentista"),
            "hospital": ("Salud", "Hospital"),
            
            // Hogar/Vivienda
            "alquiler": ("Vivienda", "Alquiler"),
            "hipoteca": ("Vivienda", "Hipoteca"),
            "luz": ("Vivienda", "Luz"),
            "electricidad": ("Vivienda", "Luz"),
            "agua": ("Vivienda", "Agua"),
            "gas": ("Vivienda", "Gas"),
            "internet": ("Vivienda", "Internet"),
            "wifi": ("Vivienda", "Internet"),
            "teléfono": ("Vivienda", "Teléfono"),
            "telefono": ("Vivienda", "Teléfono"),
            "móvil": ("Vivienda", "Teléfono"),
            "movil": ("Vivienda", "Teléfono"),
            
            // Compras
            "ropa": ("Compras", "Ropa"),
            "zapatos": ("Compras", "Ropa"),
            "zapatillas": ("Compras", "Ropa"),
            "zara": ("Compras", "Ropa"),
            "hm": ("Compras", "Ropa"),
            "primark": ("Compras", "Ropa"),
            
            // Otros
            "tabaco": ("Otros", "Varios"),
            "cigarro": ("Otros", "Varios"),
            "cigarros": ("Otros", "Varios"),
            "regalo": ("Otros", "Regalos"),
        ]
        
        for word in words {
            if let match = keywords[word] {
                // Find matching user category
                if let userCat = categories.first(where: {
                    $0.name.localizedCaseInsensitiveContains(match.category)
                }) {
                    // Find matching subcategory
                    if let subName = match.subcategory,
                       let matchedSub = userCat.subcategories.first(where: {
                           $0.localizedCaseInsensitiveContains(subName)
                       }) {
                        print("📍 Keyword match: \(userCat.name)/\(matchedSub)")
                        return (userCat.name, matchedSub)
                    }
                    print("📍 Keyword category: \(userCat.name)")
                    return (userCat.name, nil)
                }
            }
        }
        
        print("⚠️ No category found")
        return (nil, nil)
    }
    
    // MARK: - Description Extraction (Improved)
    
    private static func extractDescriptionImproved(from text: String, amount: Double, category: String?) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove command words
        let commands = [
            #"^añádeme\s+"#, #"^añade\s+"#, #"^añadir\s+"#,
            #"^gasta\s+"#, #"^gastado\s+"#, #"^he\s+gastado\s+"#,
            #"^compra\s+"#, #"^comprado\s+"#, #"^he\s+comprado\s+"#,
            #"^paga\s+"#, #"^pagado\s+"#, #"^he\s+pagado\s+"#,
            #"^apunta\s+"#, #"^pon\s+"#, #"^registra\s+"#
        ]
        
        for pattern in commands {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // Remove amount and currency
        cleaned = cleaned.replacingOccurrences(
            of: #"\d+(?:[.,]\d+)?\s*(?:euros?|€)?"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove "X con Y" patterns already parsed as amount
        cleaned = cleaned.replacingOccurrences(
            of: #"\d+\s+(?:con|coma|punto)\s+\d+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Extract text after prepositions (en, de, para)
        let prepositions = ["en", "de", "para", "por"]
        for prep in prepositions {
            if let range = cleaned.range(
                of: #"\b\#(prep)\s+(.+)$"#,
                options: [.regularExpression, .caseInsensitive]
            ) {
                let afterPrep = String(cleaned[range])
                    .replacingOccurrences(of: #"^\#(prep)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !afterPrep.isEmpty && afterPrep.count > 2 {
                    cleaned = afterPrep
                    break
                }
            }
        }
        
        // Clean up whitespace
        cleaned = cleaned
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Capitalize first letter
        if cleaned.isEmpty {
            return "Gasto por voz"
        }
        
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
    
    // MARK: - Confidence Calculation
    
    private static func calculateConfidence(
        hasAmount: Bool,
        hasCategory: Bool,
        hasSubcategory: Bool,
        descriptionQuality: Double
    ) -> Double {
        var confidence = 0.0
        
        if hasAmount { confidence += 0.4 }
        if hasCategory { confidence += 0.3 }
        if hasSubcategory { confidence += 0.2 }
        confidence += descriptionQuality
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Text Normalization
    
    private static func normalizeText(_ text: String) -> String {
        var normalized = text.lowercased()
        
        // Convert written numbers to digits
        normalized = convertNumberWords(normalized)
        
        // Normalize spaces
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func convertNumberWords(_ text: String) -> String {
        let numberWords: [String: String] = [
            "cero": "0", "uno": "1", "una": "1", "dos": "2", "tres": "3",
            "cuatro": "4", "cinco": "5", "seis": "6", "siete": "7",
            "ocho": "8", "nueve": "9", "diez": "10", "once": "11",
            "doce": "12", "trece": "13", "catorce": "14", "quince": "15",
            "dieciséis": "16", "dieciseis": "16", "diecisiete": "17",
            "dieciocho": "18", "diecinueve": "19", "veinte": "20",
            "veintiuno": "21", "veintidós": "22", "veintidos": "22",
            "veintitrés": "23", "veintitres": "23", "veinticuatro": "24",
            "veinticinco": "25", "veintiséis": "26", "veintiseis": "26",
            "veintisiete": "27", "veintiocho": "28", "veintinueve": "29",
            "treinta": "30", "cuarenta": "40", "cincuenta": "50",
            "sesenta": "60", "setenta": "70", "ochenta": "80",
            "noventa": "90", "cien": "100", "ciento": "100",
            "doscientos": "200", "trescientos": "300", "cuatrocientos": "400",
            "quinientos": "500", "seiscientos": "600", "setecientos": "700",
            "ochocientos": "800", "novecientos": "900",
        ]
        
        var result = text
        for (word, digit) in numberWords {
            result = result.replacingOccurrences(
                of: #"\b\#(word)\b"#,
                with: digit,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Handle compound numbers: "treinta y cinco" -> "35"
        let compoundPattern = #"(\d0)\s+y\s+(\d)"#
        if let regex = try? NSRegularExpression(pattern: compoundPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range)
            
            // Process matches in reverse order to maintain string indices
            for match in matches.reversed() {
                if let range1 = Range(match.range(at: 1), in: result),
                   let range2 = Range(match.range(at: 2), in: result),
                   let fullRange = Range(match.range, in: result),
                   let tens = Int(result[range1]),
                   let units = Int(result[range2]) {
                    result.replaceSubrange(fullRange, with: String(tens + units))
                }
            }
        }
        
        return result
    }
}

// Helper extension for regex replacement with closure
private extension String {
    func replacingOccurrences(of pattern: String, with replacement: (NSTextCheckingResult) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return self
        }
        
        var result = self
        let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        
        for match in matches.reversed() {
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement(match))
            }
        }
        
        return result
    }
}

