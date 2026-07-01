// AddExpenseViewModel.swift
// Add expense form logic

import Foundation
import Observation

@MainActor
@Observable
class AddExpenseViewModel {
    // MARK: - Form Fields

    /// Texto crudo del TextField. Evita parseo Double↔String del `format: .number`
    /// en cada keystroke (lag visible en input grande monospaced).
    var amountText: String = ""

    var name: String = ""
    var category: String = ""
    var subcategory: String?
    var date: Date = Date()
    var paymentMethod: PaymentMethod = .tarjeta
    var notes: String = ""

    /// Importe parseado del texto. Acepta coma o punto como decimal Y sumas/restas
    /// de importes ("1,50 + 2" = una fanta y unas patatas → 3,50).
    var amount: Double? {
        Self.evaluateAmount(amountText)
    }

    /// ¿El texto es una operación (contiene + − × ÷ entre importes), no un número suelto?
    var amountIsExpression: Bool {
        let s = amountText.replacingOccurrences(of: " ", with: "")
        // Ignora un posible signo inicial (número negativo) — solo cuenta operadores internos.
        return s.dropFirst().contains(where: { "+-×÷*/".contains($0) })
    }

    /// Añade un operador para seguir sumando/restando importes. No hace nada si el
    /// campo está vacío o el último carácter ya es un operador (evita "1 + + 2").
    func appendAmountOperator(_ op: String) {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last, last.isNumber else { return }
        amountText = trimmed + " " + op + " "
    }

    /// Evalúa operaciones de importes (+ − × ÷) SIN NSExpression (a prueba de crashes).
    /// Respeta precedencia: primero × ÷, luego + −. Devuelve nil si algo no cuadra
    /// (operador suelto, división por cero, carácter inválido…).
    static func evaluateAmount(_ text: String) -> Double? {
        let s = text
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: " ", with: "")
        guard !s.isEmpty else { return nil }
        // Número simple (incluye negativos y decimales) → parse directo, sin recorrer.
        if let single = Double(s) { return single }

        // 1) Tokeniza en números y operadores. Permite un signo inicial en el 1er término.
        var numbers: [Double] = []
        var ops: [Character] = []
        var term = ""
        for (i, ch) in s.enumerated() {
            switch ch {
            case "0"..."9", ".":
                term.append(ch)
            case "+", "-", "*", "/":
                if term.isEmpty {
                    // Solo válido como signo del primer término (p.ej. "-1+2").
                    if i == 0 && (ch == "+" || ch == "-") { term.append(ch); continue }
                    return nil
                }
                guard let value = Double(term) else { return nil }
                numbers.append(value)
                ops.append(ch)
                term = ""
            default:
                return nil
            }
        }
        guard !term.isEmpty, let lastValue = Double(term) else { return nil }
        numbers.append(lastValue)
        guard numbers.count == ops.count + 1 else { return nil }

        // 2) Resuelve × y ÷ (izquierda a derecha), acumulando + y − para la 2ª pasada.
        var addTerms = [numbers[0]]
        var addOps: [Character] = []
        for (i, op) in ops.enumerated() {
            let next = numbers[i + 1]
            switch op {
            case "*":
                addTerms[addTerms.count - 1] *= next
            case "/":
                guard next != 0 else { return nil }  // división por cero
                addTerms[addTerms.count - 1] /= next
            default:  // + o −
                addOps.append(op)
                addTerms.append(next)
            }
        }

        // 3) Resuelve + y −.
        var total = addTerms[0]
        for (i, op) in addOps.enumerated() {
            let next = addTerms[i + 1]
            total += (op == "-") ? -next : next
        }
        return total.isFinite ? total : nil
    }

    // MARK: - Auto-Suggest Logic

    private var suggestionTask: Task<Void, Never>?

    // MARK: - Cache (warmup al abrir sheet → cero IO al teclear)

    @ObservationIgnored private var cachedExpenses: [Expense] = []
    @ObservationIgnored private var cachedLearned: [String: UserPreference] = [:]
    @ObservationIgnored private var didWarmup = false

    /// Carga snapshot único de expenses + learned. Llamar al abrir el sheet.
    func warmup() async {
        guard !didWarmup else { return }
        didWarmup = true

        async let expensesTask: [Expense] = (try? await repository.getExpenses()) ?? []
        async let learnedTask = UserLearningManager.shared.snapshot()

        // Bias hacia gastos recientes — el autosuggest devuelve el primer match
        // por orden, así que ordenamos desc por fecha ("YYYY-MM-DD" sortable).
        cachedExpenses = await expensesTask.sorted { $0.date > $1.date }
        cachedLearned = await learnedTask
    }

    func onNameChange(_ newName: String) {
        // name ya lo actualiza el binding del TextField — no re-asignar (evita ciclo @Observable extra).

        guard !newName.isEmpty && (category.isEmpty || wasAutoCategorized) else { return }
        guard newName.count >= 3 else { return }

        // Cancel previous lookup if user is still typing
        suggestionTask?.cancel()

        suggestionTask = Task {
            // Debounce: espera a que el usuario pare de escribir antes de tocar el repo.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            // Priority 1: Learned preferences (snapshot cacheado, sin await actor)
            let key = UserLearningManager.normalizeKey(newName)
            if let pref = cachedLearned[key], pref.count >= 1 {
                guard !Task.isCancelled else { return }
                self.category = pref.category
                self.subcategory = pref.subcategory
                self.wasAutoCategorized = true
                return
            }

            // Priority 1.5: Match contra subcategorías del usuario.
            if let subMatch = findCategoryBySubcategoryName(newName) {
                guard !Task.isCancelled else { return }
                self.category = subMatch.category
                self.subcategory = subMatch.subcategory
                self.wasAutoCategorized = true
                return
            }

            // Priority 2: Historial cacheado (en memoria, cero IO)
            if let historyMatch = findCategoryInCachedHistory(for: newName) {
                guard !Task.isCancelled else { return }
                self.category = historyMatch.category
                self.subcategory = historyMatch.subcategory
                self.wasAutoCategorized = true
                return
            }

            guard !Task.isCancelled else { return }

            // Priority 3: Fallback keyword-based (HARDCODED en parser).
            if let suggestion = SmartTransactionParser.suggestCategory(for: newName),
               let resolved = resolveSuggestionAgainstUserCategories(suggestion) {
                guard !Task.isCancelled else { return }
                self.category = resolved.category
                self.subcategory = resolved.subcategory
                self.wasAutoCategorized = true
            }
        }
    }

    /// Mapea una sugerencia hardcoded del parser a las categorías reales del usuario.
    private func resolveSuggestionAgainstUserCategories(
        _ suggestion: (category: String, subcategory: String?)
    ) -> (category: String, subcategory: String?)? {
        let userCats = UserDataManager.shared.categories
        let target = suggestion.category
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if let cat = userCats.first(where: {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(target)
        }) {
            let sub = suggestion.subcategory.flatMap { sugSub in
                cat.subcategories.first {
                    $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        == sugSub.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                }
            }
            return (cat.name, sub)
        }

        if let sugSub = suggestion.subcategory?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current),
           let cat = userCats.first(where: {
               $0.subcategories.contains {
                   $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == sugSub
               }
           }),
           let realSub = cat.subcategories.first(where: {
               $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == sugSub
           })
        {
            return (cat.name, realSub)
        }

        return nil
    }

    private func findCategoryBySubcategoryName(_ text: String) -> (category: String, subcategory: String)? {
        let normalized = text
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        for cat in UserDataManager.shared.categories {
            if let match = cat.subcategories.first(where: {
                $0.folding(options: .diacriticInsensitive, locale: .current)
                    .lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines) == normalized
            }) {
                return (cat.name, match)
            }
        }
        return nil
    }

    /// Busca en el snapshot cacheado de expenses. Síncrono, en memoria.
    private func findCategoryInCachedHistory(for text: String) -> (category: String, subcategory: String?)? {
        let normalized = text
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let exact = cachedExpenses.first(where: {
            $0.name.folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines) == normalized
        }) {
            return (exact.category, exact.subcategory)
        }

        if let contains = cachedExpenses.first(where: {
            let expNorm = $0.name.folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return expNorm.contains(normalized) || normalized.contains(expNorm)
        }) {
            return (contains.category, contains.subcategory)
        }

        return nil
    }

    // MARK: - State
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var wasAutoCategorized = false

    // MARK: - Dependencies
    private let repository = DependencyContainer.shared.expenseRepository

    // MARK: - Validation
    var isValid: Bool {
        guard let amount = amount, amount > 0 else { return false }
        return !name.isEmpty && !category.isEmpty
    }

    // MARK: - Methods
    func save() async {
        guard isValid, let amount = amount else { return }

        isLoading = true

        let dateString = Formatters.localDayString(from: date)

        let expense = Expense(
            amount: amount,
            name: name,
            category: category,
            subcategory: subcategory,
            date: dateString,
            paymentMethod: paymentMethod.rawValue,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            _ = try await repository.addExpense(expense)
            await UserLearningManager.shared.learn(
                merchant: name,
                category: category,
                subcategory: subcategory
            )
            HapticManager.shared.expenseAdded()
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            FeedbackManager.shared.show(.success, title: "Gasto añadido", message: "\(name) guardado correctamente")
        } catch {
            errorMessage = error.safeUserMessage
            showError = true
            FeedbackManager.shared.show(.error, title: "Error al guardar", message: error.safeUserMessage)
        }

        isLoading = false
    }

    func reset() {
        amountText = ""
        name = ""
        category = ""
        subcategory = nil
        date = Date()
        paymentMethod = .tarjeta
        notes = ""
        wasAutoCategorized = false
    }
}
