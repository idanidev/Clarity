// SmartTransactionParser.swift
// Ultimate Parser: Protocol-Based, Context-Aware, Type-Safe
// Architecture: SOLID, Testable, Production-Ready

import Foundation
import NaturalLanguage
import OSLog

// MARK: - Protocol (Testability & DI)

protocol TransactionParserProtocol {
    func parse(_ text: String, history: [Expense]) async -> Result<SmartTransaction, ParserError>
    func suggestCategory(for text: String) -> (category: String, subcategory: String?)?
}

// MARK: - Error Handling

enum ParserError: Error, LocalizedError {
    case noAmountFound
    case emptyInput
    case ambiguousCategory(candidates: [String])
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .noAmountFound:
            return "No se encontró ninguna cantidad en el texto"
        case .emptyInput:
            return "El texto está vacío"
        case .ambiguousCategory(let candidates):
            return "Categoría ambigua: \(candidates.joined(separator: ", "))"
        case .invalidFormat:
            return "Formato de texto no reconocido"
        }
    }
}

// MARK: - Models

struct SmartTransaction: Sendable {
    let amount: Decimal
    let category: String?
    let subcategory: String?
    let merchant: String
    let date: Date
    let confidence: Double
    let detectionSource: DetectionSource
    let paymentMethod: String?  // Detected from keywords: "efectivo", "bizum", "visa"...

    enum DetectionSource: String, Sendable {
        case learning = "Aprendido"
        case keyword = "Palabra clave"
        case ner = "Reconocimiento de entidad"
        case contextual = "Contexto temporal"
        case fallback = "Genérico"
    }
}

// MARK: - Data Source

private struct KeywordDefinition {
    let category: String
    let subcategory: String?
    let keywords: [String]
    let timeContext: ClosedRange<Int>?  // Hour range for context-aware matching
}

// Enhanced keyword database with temporal context
private let GlobalKeywords: [KeywordDefinition] = [
    // Alimentación - Context Aware
    .init(
        category: "🛒 Compras", subcategory: "Supermercado",
        keywords: [
            "supermercado", "mercado", "mercadona", "carrefour", "lidl", "aldi", "dia", "alcampo",
            "eroski", "consum", "ahorramas",
        ], timeContext: nil),

    // Restaurantes - Almuerzo (12-16h)
    .init(
        category: "🍻 Ocio", subcategory: "Restaurantes",
        keywords: ["restaurante", "cena", "almuerzo", "comida", "menu", "plato"],
        timeContext: 12...16),
    // Restaurantes - Cena (19-23h)
    .init(
        category: "🍻 Ocio", subcategory: "Restaurantes", keywords: ["cena", "cenar"],
        timeContext: 19...23),
    // Fast Food - Any time
    .init(
        category: "🍻 Ocio", subcategory: "Restaurantes",
        keywords: [
            "pizza", "burguer", "hamburguesa", "sushi", "mcdonalds", "burger king", "telepizza",
            "just eat", "glovo", "uber eats",
        ], timeContext: nil),

    // Cafeterías - Desayuno (7-11h) / Merienda (16-19h)
    .init(
        category: "🍻 Ocio", subcategory: "Cafeterías", keywords: ["desayuno", "cafe", "tostada"],
        timeContext: 7...11),
    .init(
        category: "🍻 Ocio", subcategory: "Cafeterías", keywords: ["merienda", "cafe"],
        timeContext: 16...19),
    .init(
        category: "🍻 Ocio", subcategory: "Cafeterías", keywords: ["cafeteria", "starbucks"],
        timeContext: nil),

    // Transporte
    .init(
        category: "🚎 Transporte", subcategory: "Gasolina",
        keywords: [
            "gasolina", "combustible", "diesel", "gasolinera", "repsol", "cepsa", "bp", "shell",
        ], timeContext: nil),
    .init(
        category: "🚎 Transporte", subcategory: "Transporte público",
        keywords: ["metro", "autobus", "bus", "tren", "renfe", "cercanias", "transporte"],
        timeContext: nil),
    .init(
        category: "🚎 Transporte", subcategory: "Taxi",
        keywords: ["taxi", "uber", "cabify", "bolt"], timeContext: nil),
    .init(
        category: "🚎 Transporte", subcategory: "Parking", keywords: ["parking", "aparcamiento"],
        timeContext: nil),
    .init(category: "🚎 Transporte", subcategory: "Peajes", keywords: ["peaje"], timeContext: nil),

    // Ocio
    .init(
        category: "🍻 Ocio", subcategory: "Cine", keywords: ["cine", "pelicula"], timeContext: nil),
    .init(
        category: "🍻 Ocio", subcategory: "Bares",
        keywords: ["cerveza", "birra", "copas", "bar", "discoteca"], timeContext: 18...23),
    .init(
        category: "🍻 Ocio", subcategory: "Eventos", keywords: ["concierto", "teatro", "fiesta"],
        timeContext: nil),

    // Suscripciones
    .init(
        category: "📺 Suscripciones", subcategory: "Streaming",
        keywords: [
            "netflix", "spotify", "hbo", "disney", "prime video", "amazon prime", "dazn",
            "apple music", "youtube",
        ], timeContext: nil),
    .init(
        category: "📺 Suscripciones", subcategory: "Apps", keywords: ["icloud", "chatgpt"],
        timeContext: nil),

    // Salud
    .init(
        category: "🏥 Salud", subcategory: "Farmacia",
        keywords: ["farmacia", "medicina", "medicamento", "medicinas", "pastillas"],
        timeContext: nil),
    .init(
        category: "🏥 Salud", subcategory: "Médico", keywords: ["medico", "doctor"], timeContext: nil
    ),
    .init(category: "🏥 Salud", subcategory: "Dentista", keywords: ["dentista"], timeContext: nil),
    .init(category: "🏥 Salud", subcategory: "Hospital", keywords: ["hospital"], timeContext: nil),
    .init(
        category: "🏥 Salud", subcategory: "Gimnasio", keywords: ["gimnasio", "gym"],
        timeContext: nil),

    // Vivienda
    .init(
        category: "🏡 Vivienda", subcategory: "Alquiler", keywords: ["alquiler"], timeContext: nil),
    .init(
        category: "🏡 Vivienda", subcategory: "Hipoteca", keywords: ["hipoteca"], timeContext: nil),
    .init(
        category: "🏡 Vivienda", subcategory: "Luz",
        keywords: ["luz", "electricidad", "iberdrola", "endesa", "naturgy"], timeContext: nil),
    .init(category: "🏡 Vivienda", subcategory: "Agua", keywords: ["agua"], timeContext: nil),
    .init(category: "🏡 Vivienda", subcategory: "Gas", keywords: ["gas"], timeContext: nil),
    .init(
        category: "🏡 Vivienda", subcategory: "Internet",
        keywords: ["internet", "wifi", "fibra", "movistar", "vodafone", "orange", "pepephone"],
        timeContext: nil),
    .init(
        category: "🏡 Vivienda", subcategory: "Teléfono", keywords: ["telefono", "movil"],
        timeContext: nil),

    // Compras
    .init(
        category: "🛒 Compras", subcategory: "Ropa",
        keywords: [
            "ropa", "zapatos", "zapatillas", "zara", "hm", "h&m", "primark", "mango", "bershka",
            "pull&bear", "decathlon",
        ], timeContext: nil),
    .init(
        category: "🛒 Compras", subcategory: "Tecnología",
        keywords: ["apple store", "mediamarkt", "pccomponentes", "amazon", "electronica"],
        timeContext: nil),

    // Educación
    .init(
        category: "📖 Educación", subcategory: "Cursos", keywords: ["curso", "udemy"],
        timeContext: nil),
    .init(category: "📖 Educación", subcategory: "Libros", keywords: ["libro"], timeContext: nil),

    // Viajes
    .init(
        category: "🗺️ Viajes", subcategory: nil,
        keywords: ["viaje", "vuelo", "hotel", "airbnb", "booking"], timeContext: nil),

    // Otros
    .init(
        category: "🎲 Otros", subcategory: "Varios", keywords: ["tabaco", "cigarro"],
        timeContext: nil),
    .init(category: "🎲 Otros", subcategory: "Regalos", keywords: ["regalo"], timeContext: nil),
]

// Number words dictionary for Spanish
private let NumberWords: [String: String] = [
    "cero": "0", "uno": "1", "una": "1", "dos": "2", "tres": "3",
    "cuatro": "4", "cinco": "5", "seis": "6", "siete": "7",
    "ocho": "8", "nueve": "9", "diez": "10", "once": "11",
    "doce": "12", "trece": "13", "catorce": "14", "quince": "15",
    "dieciseis": "16", "diecisiete": "17", "dieciocho": "18", "diecinueve": "19",
    "veinte": "20", "veintiuno": "21", "veintidos": "22", "veintitres": "23",
    "veinticuatro": "24", "veinticinco": "25", "veintiseis": "26", "veintisiete": "27",
    "veintiocho": "28", "veintinueve": "29", "treinta": "30", "cuarenta": "40",
    "cincuenta": "50", "sesenta": "60", "setenta": "70", "ochenta": "80", "noventa": "90",
    "cien": "100", "ciento": "100",
]

// MARK: - The Parser (Protocol Conformance)

final class SmartTransactionParser: TransactionParserProtocol {

    // Singleton for convenience (can also be instantiated for testing)
    static let shared = SmartTransactionParser()

    // MARK: - Logger
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "VoiceParser")

    // Static Regex for performance
    private enum Patterns {
        static let compositeAmount = try! NSRegularExpression(
            pattern: #"(\d+)\s+(?:con|coma|punto)\s+(\d+)"#, options: .caseInsensitive)
        static let simpleAmount = try! NSRegularExpression(
            pattern: #"(\d+(?:[.,]\d{1,2})?)\s*(?:euros?|€)?\b"#, options: .caseInsensitive)
        static let compoundNumbers = try! NSRegularExpression(
            pattern: #"(\d0)\s+y\s+(\d)"#, options: .caseInsensitive)
        static let commands = try! NSRegularExpression(
            pattern:
                #"^(añademe|añade|añadir|anademe|anade|anadir|gasta|gastado|he gastado|compra|comprado|he comprado|paga|pagado|he pagado|apunta|pon|registra)\s+"#,
            options: .caseInsensitive)
        // Static patterns for cleanDescription (built once, reused on every call)
        static let numberWords: NSRegularExpression = {
            let pattern = NumberWords.keys
                .sorted { $0.count > $1.count }
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "|")
            return try! NSRegularExpression(
                pattern: "\\b(\(pattern))\\b", options: .caseInsensitive)
        }()
        static let decimalConnectors = try! NSRegularExpression(
            pattern: "\\b(coma|punto|y)\\b", options: .caseInsensitive)
        static let euroWord = try! NSRegularExpression(
            pattern: "\\beuros?\\b", options: .caseInsensitive)
        // Payment method detection
        static let paymentMethod = try! NSRegularExpression(
            pattern:
                "\\b(efectivo|metálico|metal|cash|bizum|transferencia|visa|mastercard|tarjeta|débito|debito|crédito|credito|apple pay|google pay|paypal)\\b",
            options: .caseInsensitive
        )
    }

    // MARK: - Stop-Words (Phase 3: Parser Intelligence)

    /// Spanish fillers to remove from transcripts
    private static let fillers: Set<String> = [
        "ehmm", "ehm", "mmm", "esto", "pues", "bueno", "ya", "vale",
        "osea", "o sea", "tipo", "como", "asi", "así", "entonces",
    ]

    /// Meta-commands that don't add value to expense description
    private static let metaCommands: Set<String> = [
        "me he gastado", "me gaste", "apuntame", "apúntame", "registra",
        "pon", "anota", "guarda", "he comprado", "he pagado",
    ]

    // MARK: - Main API (Result Type)

    // MARK: - Main API (Result Type)

    func parse(_ text: String, history: [Expense] = []) async -> Result<
        SmartTransaction, ParserError
    > {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyInput)
        }

        // 1. Date Detection
        let (date, textNoDate) = extractDate(from: text)

        // 2. Normalize
        let normalized = normalize(textNoDate)
        logger.debug("[SmartParser] Original: \"\(text)\"")
        logger.debug("[SmartParser] Normalized: \"\(normalized)\"")

        // 3. Amount Extraction
        guard let amount = extractAmount(from: normalized) else {
            return .failure(.noAmountFound)
        }

        // 4. Payment Method Detection
        let paymentMethod = detectPaymentMethod(from: text)

        // 5. Category & Merchant Detection (Adaptive)
        let (category, subcategory, merchant, source) = await inferMetadata(
            from: textNoDate, normalized: normalized, history: history)

        // 6. Confidence
        let confidence = calculateConfidence(source: source, hasAmount: true)

        let transaction = SmartTransaction(
            amount: amount,
            category: category,
            subcategory: subcategory,
            merchant: merchant.capitalized,
            date: date,
            confidence: confidence,
            detectionSource: source,
            paymentMethod: paymentMethod
        )

        return .success(transaction)
    }

    // MARK: - Quick Suggestion (Synchronous for UI)

    func suggestCategory(for text: String) -> (category: String, subcategory: String?)? {
        let normalized = normalize(text)
        let currentHour = Calendar.current.component(.hour, from: Date())

        // Context-aware matching first
        for def in GlobalKeywords {
            if let timeRange = def.timeContext, timeRange.contains(currentHour) {
                for keyword in def.keywords {
                    if normalized.contains(keyword) {
                        return (def.category, def.subcategory)
                    }
                }
            }
        }

        // Fallback to non-contextual matching
        for def in GlobalKeywords where def.timeContext == nil {
            for keyword in def.keywords {
                if normalized.contains(keyword) {
                    return (def.category, def.subcategory)
                }
            }
        }

        return nil
    }

    // MARK: - Date Detection (NSDataDetector)

    private func extractDate(from text: String) -> (Date, String) {
        guard
            let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.date.rawValue)
        else {
            return (Date(), text)
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        if let match = matches.first, let date = match.date {
            var cleanText = text
            if let range = Range(match.range, in: text) {
                cleanText.removeSubrange(range)
            }
            return (date, cleanText)
        }

        return (Date(), text)
    }

    // MARK: - Amount Extraction (Decimal Precision)

    private func extractAmount(from text: String) -> Decimal? {
        let range = NSRange(text.startIndex..., in: text)

        // Composite: "20 con 50"
        if let match = Patterns.compositeAmount.firstMatch(in: text, options: [], range: range),
            let r1 = Range(match.range(at: 1), in: text),
            let r2 = Range(match.range(at: 2), in: text),
            let whole = Decimal(string: String(text[r1])),
            let fraction = Decimal(string: String(text[r2]))
        {
            return whole + (fraction / 100)
        }

        // Simple: "20.50"
        if let match = Patterns.simpleAmount.firstMatch(in: text, options: [], range: range),
            let r1 = Range(match.range(at: 1), in: text)
        {
            let str = String(text[r1]).replacingOccurrences(of: ",", with: ".")
            return Decimal(string: str)
        }

        return nil
    }

    // MARK: - Metadata Inference (Adaptive Intelligence)

    private func inferMetadata(from original: String, normalized: String, history: [Expense]) async
        -> (String?, String?, String, SmartTransaction.DetectionSource)
    {
        let currentHour = Calendar.current.component(.hour, from: Date())

        // 1. Advanced NLP Cleaning
        let cleanedDescription = cleanDescription(from: original, normalized: normalized)
        let normalizedDescription = normalize(cleanedDescription)

        logger.debug(
            "[Adaptive] Input: '\(normalizedDescription)' | History: \(history.count) items")

        // 1b. Priority 0: UserLearningManager (fastest, O(1) dictionary lookup)
        if let learned = await UserLearningManager.shared.getPreference(for: normalizedDescription)
        {
            logger.debug(
                "[Adaptive] Learned Match: \(normalizedDescription) -> \(learned.category)")
            return (learned.category, learned.subcategory, cleanedDescription, .learning)
        }

        // 2. History Lookup (Priority 1: Exact & Partial Match)
        // Sort history by date (newest first) to prefer recent habits
        // Note: History should already be sorted by caller, but we ensure relevance.

        // 2a. Exact/Strong Match
        if let exactMatch = history.first(where: { normalize($0.name) == normalizedDescription }) {
            logger.debug("[Adaptive] Exact Match: \(exactMatch.name)")
            return (exactMatch.category, exactMatch.subcategory, cleanedDescription, .learning)
        }

        // 2b. Contains Match (e.g. "Tabaco" in "Tabaco de liar")
        if let containsMatch = history.first(where: {
            normalize($0.name).contains(normalizedDescription)
                || normalizedDescription.contains(normalize($0.name))
        }) {
            logger.debug("[Adaptive] Contains Match: \(containsMatch.name)")
            return (
                containsMatch.category, containsMatch.subcategory, cleanedDescription, .learning
            )
        }

        // 2c. Fuzzy Match (Levenshtein) - for typos
        if normalizedDescription.count > 3 {
            var bestFuzzy: Expense?
            var minDistance = Int.max

            // Limit search to recent unique items to improve perf if history is huge?
            // For now, full search (assuming UserDataManager filters or limited size).
            for expense in history.prefix(500) {  // Optimization: Look at last 500
                let dist = levenshteinDistance(normalize(expense.name), normalizedDescription)
                let threshold = normalizedDescription.count > 5 ? 2 : 1

                if dist <= threshold && dist < minDistance {
                    minDistance = dist
                    bestFuzzy = expense
                }
            }

            if let best = bestFuzzy {
                logger.debug("[Adaptive] Fuzzy Match: \(best.name) (dist: \(minDistance))")
                return (best.category, best.subcategory, cleanedDescription, .learning)
            }
        }

        // 3. Context-Aware Keywords (Time-based priority)
        for def in GlobalKeywords {
            if let timeRange = def.timeContext, timeRange.contains(currentHour) {
                for keyword in def.keywords {
                    if normalized.contains(keyword) {
                        return (def.category, def.subcategory, cleanedDescription, .contextual)
                    }
                }
            }
        }

        // 4. Fuzzy Keyword Matching (Static Dictionary)
        let words = normalized.components(separatedBy: " ").filter { $0.count > 2 }
        for def in GlobalKeywords where def.timeContext == nil {
            for keyword in def.keywords {
                // Exact keyword contains
                if normalized.contains(keyword) {
                    return (def.category, def.subcategory, cleanedDescription, .keyword)
                }

                // Fuzzy keyword
                if keyword.count > 4 {
                    for word in words {
                        let distance = levenshteinDistance(word, keyword)
                        let threshold = keyword.count > 6 ? 2 : 1
                        if distance <= threshold {
                            return (def.category, def.subcategory, cleanedDescription, .keyword)
                        }
                    }
                }
            }
        }

        // 5. NER Fallback
        if let entity = extractEntity(from: original) {
            let finalDescription =
                entity.count > cleanedDescription.count ? entity : cleanedDescription
            return ("🛒 Compras", nil, finalDescription, .ner)
        }

        // 6. Generic Fallback
        return (nil, nil, cleanedDescription, .fallback)
    }

    private func extractEntity(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var foundEntity: String?

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            if let tag = tag, tag == .organizationName || tag == .personalName {
                foundEntity = String(text[range])
                return false
            }
            return true
        }

        return foundEntity
    }

    // MARK: - Payment Method Detection

    private func detectPaymentMethod(from text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = Patterns.paymentMethod.firstMatch(in: text, options: [], range: range),
            let matchRange = Range(match.range, in: text)
        else { return nil }
        let keyword = String(text[matchRange]).lowercased()
        // Normalize to canonical names
        switch keyword {
        case "efectivo", "metálico", "metal", "cash": return "Efectivo"
        case "bizum": return "Bizum"
        case "transferencia": return "Transferencia"
        case "paypal": return "PayPal"
        case "apple pay": return "Apple Pay"
        case "google pay": return "Google Pay"
        default: return "Tarjeta"  // visa, mastercard, tarjeta, débito, crédito...
        }
    }

    // MARK: - Helpers

    private func calculateConfidence(source: SmartTransaction.DetectionSource, hasAmount: Bool)
        -> Double
    {
        var score = hasAmount ? 0.5 : 0.0
        switch source {
        case .learning: score += 0.5
        case .contextual: score += 0.45
        case .keyword: score += 0.4
        case .ner: score += 0.3
        case .fallback: score += 0.1
        }
        return Swift.min(score, 1.0)
    }

    private func cleanDescription(from original: String, normalized: String) -> String {
        // Work on the ORIGINAL text (preserve user's capitalization and exact words)
        var clean = original

        // 1. Remove meta-commands (Prefixes)
        for command in Self.metaCommands {
            if let range = clean.range(of: command, options: [.caseInsensitive, .anchored]) {
                clean.removeSubrange(range)
            }
        }

        // 2. Remove commands via Regex (legacy robust)
        clean = Patterns.commands.stringByReplacingMatches(
            in: clean, options: [], range: NSRange(clean.startIndex..., in: clean), withTemplate: ""
        )

        // 3. Remove fillers (STOP WORDS)
        let words = clean.components(separatedBy: .whitespaces)
        let filteredWords = words.filter { !Self.fillers.contains($0.lowercased()) }
        clean = filteredWords.joined(separator: " ")

        // 4. Remove Spanish number words — use static regex (built once at startup)
        clean = Patterns.numberWords.stringByReplacingMatches(
            in: clean, options: [],
            range: NSRange(clean.startIndex..., in: clean),
            withTemplate: ""
        )

        // 4b. Remove orphaned decimal connectors (coma, punto, y) — static regex
        clean = Patterns.decimalConnectors.stringByReplacingMatches(
            in: clean, options: [],
            range: NSRange(clean.startIndex..., in: clean),
            withTemplate: ""
        )

        // 4c. Remove payment method keywords from description ("en efectivo", "con bizum", etc.)
        clean = Patterns.paymentMethod.stringByReplacingMatches(
            in: clean, options: [],
            range: NSRange(clean.startIndex..., in: clean),
            withTemplate: ""
        )

        // 5. Remove "euros" / "euro" — static regex
        clean = Patterns.euroWord.stringByReplacingMatches(
            in: clean, options: [],
            range: NSRange(clean.startIndex..., in: clean),
            withTemplate: ""
        )

        // 6. Remove numeric amounts and euro symbols (digits already handled here)
        clean = Patterns.simpleAmount.stringByReplacingMatches(
            in: clean, options: [], range: NSRange(clean.startIndex..., in: clean), withTemplate: ""
        )
        clean = Patterns.compositeAmount.stringByReplacingMatches(
            in: clean, options: [], range: NSRange(clean.startIndex..., in: clean), withTemplate: ""
        )

        // 7. Remove standalone euro symbols
        clean = clean.replacingOccurrences(of: "€", with: "")

        // 8. Remove prepositions and articles
        let wordsToRemove = [
            " en ", " de ", " para ", " por ", " con ", " el ", " la ", " los ", " las ", " un ",
            " una ", " unos ", " unas ",
        ]
        for word in wordsToRemove {
            clean = clean.replacingOccurrences(of: word, with: " ", options: .caseInsensitive)
        }

        // 9. Clean up multiple spaces
        clean = clean.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // 10. Capitalize first letter
        if !clean.isEmpty {
            clean = clean.prefix(1).uppercased() + clean.dropFirst()
        }

        return clean.isEmpty ? "Gasto General" : clean
    }

    private func normalize(_ text: String) -> String {
        var result =
            text
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        // Convert number words to digits
        for (word, digit) in NumberWords {
            result = result.replacingOccurrences(
                of: "\\b\(word)\\b",
                with: digit,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Handle compound numbers "30 y 5" -> "35"
        let range = NSRange(result.startIndex..., in: result)
        if let matches = Patterns.compoundNumbers.matches(in: result, range: range)
            as [NSTextCheckingResult]?
        {
            for match in matches.reversed() {
                if let r1 = Range(match.range(at: 1), in: result),
                    let r2 = Range(match.range(at: 2), in: result),
                    let fullRange = Range(match.range, in: result),
                    let tens = Int(result[r1]),
                    let units = Int(result[r2])
                {
                    result.replaceSubrange(fullRange, with: String(tens + units))
                }
            }
        }

        return
            result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // Levenshtein Distance (Fuzzy Matching)
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s = Array(s1.utf16)
        let t = Array(s2.utf16)
        let n = s.count
        let m = t.count

        if n == 0 { return m }
        if m == 0 { return n }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)

        for i in 0...n { matrix[i][0] = i }
        for j in 0...m { matrix[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                if s[i - 1] == t[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = Swift.min(
                        matrix[i - 1][j] + 1,
                        matrix[i][j - 1] + 1,
                        matrix[i - 1][j - 1] + 1
                    )
                }
            }
        }

        return matrix[n][m]
    }

    // MARK: - Multi-Transaction Parsing

    /// Splits a transcript into individual expense segments and parses each one.
    /// Example: "10 euros en tabaco y 5 en café" → two transactions
    func parseMultiple(_ text: String, history: [Expense] = []) async -> [SmartTransaction] {
        let segments = splitIntoExpenseSegments(text)
        var results: [SmartTransaction] = []
        for segment in segments {
            if case .success(let tx) = await parse(segment, history: history) {
                results.append(tx)
            }
        }
        return results
    }

    /// Splits text by "y" / "también" / "además" connectors only when BOTH sides contain an amount.
    private func splitIntoExpenseSegments(_ text: String) -> [String] {
        let connectorPattern = try? NSRegularExpression(
            pattern: #"\s+(?:y|también|tambien|además|ademas)\s+"#,
            options: .caseInsensitive
        )
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let matches = connectorPattern?.matches(in: text, range: range), !matches.isEmpty
        else { return [text] }

        // Build segments
        var segments: [String] = []
        var lastEnd = text.startIndex
        for match in matches {
            if let matchRange = Range(match.range, in: text) {
                segments.append(String(text[lastEnd..<matchRange.lowerBound]))
                lastEnd = matchRange.upperBound
            }
        }
        segments.append(String(text[lastEnd...]))

        // Only split if every segment contains an amount
        let allHaveAmount = segments.allSatisfy { hasAmount(normalize($0)) }
        return allHaveAmount && segments.count > 1 ? segments : [text]
    }

    private func hasAmount(_ normalizedText: String) -> Bool {
        let range = NSRange(normalizedText.startIndex..., in: normalizedText)
        return Patterns.simpleAmount.firstMatch(in: normalizedText, options: [], range: range)
            != nil
            || Patterns.compositeAmount.firstMatch(in: normalizedText, options: [], range: range)
                != nil
    }
}

// MARK: - Static Convenience (Backward Compatibility)

extension SmartTransactionParser {
    static func parse(_ text: String, history: [Expense] = []) async -> SmartTransaction? {
        let result = await shared.parse(text, history: history)
        switch result {
        case .success(let transaction):
            return transaction
        case .failure:
            return nil
        }
    }

    static func suggestCategory(for text: String) -> (category: String, subcategory: String?)? {
        return shared.suggestCategory(for: text)
    }
}
