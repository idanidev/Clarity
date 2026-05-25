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

    /// Importe parseado del texto. Acepta coma o punto como decimal.
    var amount: Double? {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
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
