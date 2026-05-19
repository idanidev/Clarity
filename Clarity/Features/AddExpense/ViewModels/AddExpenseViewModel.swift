// AddExpenseViewModel.swift
// Add expense form logic

import Foundation
import Observation

@MainActor
@Observable
class AddExpenseViewModel {
    // MARK: - Form Fields
    var amount: Double?
    var name: String = ""
    var category: String = ""
    var subcategory: String?
    var date: Date = Date()
    var paymentMethod: PaymentMethod = .tarjeta
    var notes: String = ""

    // MARK: - Auto-Suggest Logic

    private var suggestionTask: Task<Void, Never>?

    func onNameChange(_ newName: String) {
        self.name = newName

        guard !newName.isEmpty && (category.isEmpty || wasAutoCategorized) else { return }
        guard newName.count >= 3 else { return }

        // Cancel previous lookup if user is still typing
        suggestionTask?.cancel()

        suggestionTask = Task {
            // Priority 1: Check learned preferences (UserLearningManager)
            if let learned = await UserLearningManager.shared.getPreference(for: newName) {
                guard !Task.isCancelled else { return }
                self.category = learned.category
                self.subcategory = learned.subcategory
                self.wasAutoCategorized = true
                return
            }

            // Priority 1.5: Match contra subcategorías del usuario.
            // Si el nombre del gasto coincide con una subcategoría existente
            // (ej: subcat "Developer" en categoría "Trabajo"), autocompletar.
            if let subMatch = findCategoryBySubcategoryName(newName) {
                guard !Task.isCancelled else { return }
                self.category = subMatch.category
                self.subcategory = subMatch.subcategory
                self.wasAutoCategorized = true
                return
            }

            // Priority 2: Check expense history (exact/contains match)
            if let historyMatch = await findCategoryInHistory(for: newName) {
                guard !Task.isCancelled else { return }
                self.category = historyMatch.category
                self.subcategory = historyMatch.subcategory
                self.wasAutoCategorized = true
                return
            }

            guard !Task.isCancelled else { return }

            // Priority 3: Fallback to keyword-based suggestion (HARDCODED en parser).
            // Solo aplicar si la categoría/subcategoría EXISTE en las del usuario.
            // Sino crearíamos categorías fantasma al añadir un gasto (bug grave).
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
    /// Si no existe match (ni por nombre ni por subcategoría), devuelve nil → no se aplica.
    private func resolveSuggestionAgainstUserCategories(
        _ suggestion: (category: String, subcategory: String?)
    ) -> (category: String, subcategory: String?)? {
        let userCats = UserDataManager.shared.categories
        let target = suggestion.category
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        // 1) Match por nombre de categoría (ignora tildes/case/emojis)
        if let cat = userCats.first(where: {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(target)
        }) {
            // Solo conservar subcategoría si existe en esa categoría
            let sub = suggestion.subcategory.flatMap { sugSub in
                cat.subcategories.first {
                    $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        == sugSub.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                }
            }
            return (cat.name, sub)
        }

        // 2) Match por subcategoría (puede que la categoría sea distinta pero la sub coincida)
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

    /// Busca una subcategoría existente que coincida (case/diacritic-insensitive)
    /// con el nombre del gasto. Devuelve la categoría padre + esa subcategoría.
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

    private func findCategoryInHistory(for text: String) async -> (category: String, subcategory: String?)? {
        let normalized = text
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let expenses = try await repository.getExpenses()

            // Exact match
            if let exact = expenses.first(where: {
                $0.name.folding(options: .diacriticInsensitive, locale: .current)
                    .lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines) == normalized
            }) {
                return (exact.category, exact.subcategory)
            }

            // Contains match
            if let contains = expenses.first(where: {
                let expNorm = $0.name.folding(options: .diacriticInsensitive, locale: .current)
                    .lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return expNorm.contains(normalized) || normalized.contains(expNorm)
            }) {
                return (contains.category, contains.subcategory)
            }
        } catch {
            // Silently fall through to keyword matching
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

        // DatePicker devuelve Date a midnight LOCAL. Formateamos en LOCAL para que
        // "2026-04-25" represente el día que el usuario eligió, no el día UTC equivalente.
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
            // Teach the learning system this name→category association
            await UserLearningManager.shared.learn(
                merchant: name,
                category: category,
                subcategory: subcategory
            )
            HapticManager.shared.expenseAdded()
            // Notificar para que dashboards/escudos/metas se refresquen.
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
        amount = nil
        name = ""
        category = ""
        subcategory = nil
        date = Date()
        paymentMethod = .tarjeta
        notes = ""
        wasAutoCategorized = false
    }
}
