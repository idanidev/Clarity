// UserDataManager.swift
// Wrapper principal para estado de usuario (UI Layer)
// Gestiona el estado observable para las vistas y delega la lógica a UserDataService

import Foundation

import OSLog
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import TipKit
import SwiftData

@MainActor
@Observable
final class UserDataManager {
    
    // MARK: - Singleton
    static let shared = UserDataManager()
    
    // MARK: - UI State
    var categories: [Category] = []
    var expenses: [Expense] = [] // Cache for Voice Parser
    var paymentMethods: [String] = []
    var isLoading = false
    var error: String? // Simplificado a String para UI directa
    var userDocument: UserDocument?
    
    // MARK: - Dependencies
    private let service = UserDataService.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "UserDataManager")
    
    var hasLoaded: Bool { !categories.isEmpty }
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    private init() {
        // Cargar defaults inmediatos para que la UI no esté vacía
        Task {
            categories = await service.createDefaultCategories()
            paymentMethods = PaymentMethod.allCases.map { $0.rawValue }
        }
    }
    
    // MARK: - Public API
    
    func loadUserData() async {
        // Esperar a Auth con listener (antes polling 5×300ms = hasta 1.5s síncrono en cold launch)
        if userId == nil {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                var resumed = false
                let resume = { if !resumed { resumed = true; cont.resume() } }
                let token = Auth.auth().addStateDidChangeListener { _, user in
                    if user != nil { resume() }
                }
                // Safety net 2s para no colgar indefinido si nadie se loguea
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    resume()
                }
                _ = token  // listener queda activo; el wakeup de safety lo libera ya que solo necesitamos primera señal
            }
        }
        guard let userId = userId else {
            logger.warning("No authenticated user, using defaults")
            return
        }

        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            async let fetchedCategories = service.loadCategories(userId: userId)
            async let fetchedMethods = service.loadPaymentMethods(userId: userId)
            await self.loadExpenses() // Load expenses for cache
            
            let (catsResult, _) = try await fetchedCategories
            self.categories = catsResult

            // Multi-device: la primera lectura puede venir de cache. Refresco
            // contra server en background y actualizo solo si difiere.
            Task { [weak self] in
                guard let self, let uid = self.userId else { return }
                if let (fresh, _) = try? await self.service.loadCategories(userId: uid, forceServer: true),
                   fresh != self.categories {
                    self.categories = fresh
                }
            }
            
            // Load Local Backup Filters
            var localFilters: [ExpenseFilter] = []
            if let data = UserDefaults.standard.data(forKey: "backup_saved_filters"),
               let decoded = try? JSONDecoder().decode([ExpenseFilter].self, from: data) {
                localFilters = decoded
            }
            
            // Ensure filters are present
            if let docFilters = self.userDocument?.savedFilters, !docFilters.isEmpty {
                 // Remote prevails, but maybe sync? For now trust remote if exists.
            } else if !localFilters.isEmpty {
                // If remote is empty but local has data, use local and try to sync up later?
                // Or just inject into local userDocument state
                if self.userDocument == nil {
                    // Create dummy doc if fully offline/empty
                    // self.userDocument = UserDocument(...) // Complexity: UserDocument init might be big
                }
                var doc = self.userDocument
                doc?.savedFilters = localFilters
                self.userDocument = doc
            }
            
            let customMethods = try await fetchedMethods
            var allMethods = Set(PaymentMethod.allCases.map { $0.rawValue })
            allMethods.formUnion(customMethods)
            self.paymentMethods = allMethods.sorted()

            // 🔄 Ejecutar migración de categorías (solo una vez)
            Task {
                try? await service.migrateExpenseCategoriesFromSlashToDash(userId: userId)
            }

            // Sync Tips
            if let settings = self.userDocument?.settings, settings.hasCompletedOnboarding == true {
                // Invalidate all tips if user already completed onboarding
                try? Tips.resetDatastore() // Optional: verify if this is desired behavior or just hiding specific tips
                // Better approach: Since we use TipKit's internal state, we might just want to ensure we don't show them.
                // But TipKit persistence is separate.
                // For this use case, if the user has completed onboarding, we can programmatically invalidate the tips.
                // However, TipKit doesn't have a global "hide all" without resetting.
                // Let's rely on the action: If we have the flag, we just assume they are done.
                // A better way is to invalidate specific tips:
                AddExpenseTip().invalidate(reason: .actionPerformed)
                FilterTip().invalidate(reason: .actionPerformed)
            }
            
        } catch {
            logger.error("Error loading user data: \(error.localizedDescription)")
            self.error = error.localizedDescription
            // Fallback implícito: Mantenemos los defaults si falla
        }
        
        isLoading = false
    }
    
    func refreshCategories() async {
        // Antes: loadUserData() recargaba TODO (categorías + gastos + payment methods + budgets).
        // Ahora: solo categorías (lo único que cambió). 10× más rápido.
        guard let userId = userId else { return }
        do {
            let (cats, _) = try await service.loadCategories(userId: userId)
            self.categories = cats
        } catch {
            logger.error("refreshCategories failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Expenses Cache
    
    func loadExpenses() async {
        do {
            let descriptor = FetchDescriptor<ExpenseModel>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let models = try SwiftDataService.shared.context.fetch(descriptor)
            let all = models.map { $0.toDomain() }
            // Fetch recurring rules (cache-first) so ExpenseSanitizer can deduplicate
            // anomalies and misplaced annual expenses in addition to ID dedup.
            let rules = (try? await DependencyContainer.shared.recurringExpenseRepository.fetchAll()) ?? []
            self.expenses = ExpenseSanitizer.sanitize(expenses: all, rules: rules)
        } catch {
            logger.error("❌ Failed to cache expenses: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD
    
    func addCategory(_ category: Category) async {
        guard let userId = userId else { return }
        do {
            // FIX pérdida de datos: los defaults vivían solo en memoria. Si el map
            // no está persistido, sembrarlo ANTES de añadir la nueva — si no, el
            // updateData dot-path crea el map con una sola entrada y borra el resto.
            try await service.persistCategoriesIfMissing(categories, userId: userId)
            try await service.saveCategory(category, userId: userId)
            await refreshCategories() // Light refresh (solo categorías)
        } catch {
            self.error = "Error al guardar categoría: \(error.localizedDescription)"
        }
    }
    
    func updateCategory(_ category: Category) async {
        guard let userId = userId else { return }

        // Buscar el nombre antiguo de la categoría para actualizar gastos si cambió
        let oldName = categories.first(where: { $0.id == category.id })?.name
        let renamed = oldName != nil && oldName != category.name

        do {
            // Sembrar defaults no persistidos antes de editar (evita que editar
            // una categoría por defecto cree un map con una sola entrada).
            try await service.persistCategoriesIfMissing(categories, userId: userId)
            try await service.saveCategory(category, userId: userId, oldName: oldName)
            // Si renombró, gastos cambiaron de category string → recarga gastos también.
            // Si solo color/orden, refresh ligero de categorías es suficiente.
            if renamed {
                await loadUserData()
            } else {
                await refreshCategories()
            }
        } catch {
            self.error = "Error al actualizar: \(error.localizedDescription)"
        }
    }
    
    func addSubcategory(_ subcategoryName: String, toCategoryId categoryId: String) async {
        guard let userId = userId else { return }
        do {
            try await service.persistCategoriesIfMissing(categories, userId: userId)
            try await service.addSubcategory(subcategoryName, toCategoryId: categoryId, userId: userId)
            await refreshCategories() // Light refresh (solo categorías)
        } catch {
            self.error = "Error al añadir subcategoría: \(error.localizedDescription)"
        }
    }
    
    /// Elimina una categoría. Si `reassignExpensesTo` viene informado, primero
    /// migra TODOS los gastos de esta categoría a la nueva (evita huérfanos
    /// "fantasma" en charts con el string de la categoría borrada).
    func deleteCategory(id: String, reassignExpensesTo newCategoryName: String? = nil) async {
        guard let userId = userId else { return }
        do {
            // Seed previo: si el map no estaba persistido, el delete por id
            // no-opearía y la categoría "fantasma" reaparecería al refrescar.
            try await service.persistCategoriesIfMissing(categories, userId: userId)

            if let newName = newCategoryName,
               let oldName = categories.first(where: { $0.id == id })?.name,
               oldName != newName {
                try await service.updateExpensesCategoryName(
                    userId: userId, oldName: oldName, newName: newName)
            }

            try await service.deleteCategory(id: id, userId: userId)
            await refreshCategories()

            if newCategoryName != nil {
                // Gastos cambiaron de categoría → recargar cache + notificar dashboards
                await loadExpenses()
                NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            }
        } catch {
            self.error = "Error al eliminar: \(error.localizedDescription)"
        }
    }
    
    func clearCache() {
        Task {
            categories = await service.createDefaultCategories()
            paymentMethods = PaymentMethod.allCases.map { $0.rawValue }
            error = nil
        }
    }
    
    // MARK: - Convenience Accessors
    
    var categoryNames: [String] {
        categories.map { $0.name }
    }
    
    func subcategories(for categoryName: String) -> [String] {
        categories
            .first { $0.name.localizedCaseInsensitiveContains(categoryName) }?
            .subcategories ?? []
    }
    
    func colorHex(for categoryName: String) -> String {
        // 1. User Categories
        if let userCat = categories.first(where: { $0.name.localizedCaseInsensitiveContains(categoryName) }) {
            return userCat.color
        }
        
        // 2. Theme Defaults (Fuzzy)
        if let match = Color.categoryColors.keys.first(where: { 
            $0.localizedCaseInsensitiveContains(categoryName) || 
            categoryName.localizedCaseInsensitiveContains($0)
        }), let color = Color.categoryColors[match] {
            return color.hexString
        }
        
        // 3. Fallback
        return "#6B7280"
    }
    
    func color(for categoryName: String) -> Color {
        Color(hex: colorHex(for: categoryName))
    }
    
    // MARK: - User Document Management
    
    func setUserDocument(_ document: UserDocument) {
        self.userDocument = document
    }
    
    var privacyMode: Bool {
        userDocument?.settings?.privacyMode ?? false
    }
    
    func togglePrivacyMode() {
        guard var document = userDocument, let userId = userId else { return }
        
        // 1. Update Local
        var newSettings = document.settings ?? .default
        let newPrivacy = !(newSettings.privacyMode ?? false)
        newSettings.privacyMode = newPrivacy
        document.settings = newSettings
        self.userDocument = document
        
        HapticManager.shared.selection()
        
        // 2. Update Remote
        Task {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .updateData(["settings.privacyMode": newPrivacy])
            } catch {
                logger.error("Error saving privacy mode: \(error.localizedDescription)")
            }
        }
    }
    
    func saveDefaultFilter(_ filter: ExpenseFilter) {
        guard var document = userDocument, let userId = userId else { return }
        
        // 1. Update Local
        var newSettings = document.settings ?? .default
        newSettings.defaultFilter = filter
        document.settings = newSettings
        self.userDocument = document
        
        HapticManager.shared.notification(.success)
        
        // 2. Update Remote
        Task {
            do {
                // Encode filter to dictionary
                let data = try Firestore.Encoder().encode(newSettings)
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .updateData(["settings": data]) // Update full settings object to ensure filter structure matches
                logger.info("✅ Default filter saved")
            } catch {
                logger.error("❌ Error saving default filter: \(error.localizedDescription)")
            }
        }
    }
    
    var defaultFilter: ExpenseFilter? {
        userDocument?.settings?.defaultFilter
    }
    
    // MARK: - Onboarding Sincronization
    var hasCompletedOnboarding: Bool {
        userDocument?.settings?.hasCompletedOnboarding ?? false
    }
    
    func completeOnboarding() {
        guard !hasCompletedOnboarding else { return }
        guard let userId = userId else { return }

        // 1. Update Local — crear documento mínimo si no existe (race con fetchUserDocument)
        if var document = userDocument {
            var newSettings = document.settings ?? .default
            newSettings.hasCompletedOnboarding = true
            document.settings = newSettings
            self.userDocument = document
        } else {
            var stubSettings = UserSettings.default
            stubSettings.hasCompletedOnboarding = true
            self.userDocument = UserDocument(
                email: Auth.auth().currentUser?.email ?? "",
                displayName: Auth.auth().currentUser?.displayName ?? "",
                role: "user",
                createdAt: Date(),
                updatedAt: Date(),
                settings: stubSettings,
                aiQuotas: .free,
                subscription: nil
            )
        }

        // 2. Update Remote — setData con merge para tolerar doc inexistente
        Task {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .setData(["settings": ["hasCompletedOnboarding": true]], merge: true)
                logger.info("✅ Onboarding marked as completed")
            } catch {
                logger.error("❌ Error saving onboarding status: \(error.localizedDescription)")
            }
        }
    }
    
    func resetOnboarding() {
        guard var document = userDocument, let userId = userId else { return }
        var newSettings = document.settings ?? .default
        newSettings.hasCompletedOnboarding = false
        document.settings = newSettings
        self.userDocument = document
        Task {
            try? await Firestore.firestore()
                .collection("users").document(userId)
                .updateData(["settings.hasCompletedOnboarding": false])
        }
    }

    // MARK: - Smart Filters (Filtering 2.0)
    
    var savedFilters: [ExpenseFilter] {
        userDocument?.savedFilters?.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) } ?? []
    }
    
    func saveFilter(_ filter: ExpenseFilter, name: String) async {
        guard var document = userDocument, let userId = userId else { return }
        
        var newFilter = filter
        newFilter.id = UUID() // Always new ID for fresh save
        newFilter.name = name
        newFilter.createdAt = Date()
        
        // 1. Update Local
        var currentFilters = document.savedFilters ?? []
        currentFilters.append(newFilter)
        document.savedFilters = currentFilters
        self.userDocument = document
        
        // 2. Update Remote — Firestore.Encoder NO admite array top-level;
        // hay que serializar cada filtro a [String: Any] y pasar el array de dicts.
        do {
            let dicts = try currentFilters.map { try Firestore.Encoder().encode($0) }
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["savedFilters": dicts])
            logger.info("✅ Filter saved: \(name)")
            
            // Backup to UserDefaults
            if let encoded = try? JSONEncoder().encode(currentFilters) {
                UserDefaults.standard.set(encoded, forKey: "backup_saved_filters")
            }
        } catch {
            logger.error("❌ Error saving filter: \(error.localizedDescription)")
            self.error = "Error al guardar filtro: \(error.localizedDescription)"
            
            // Still save to UserDefaults even if remote fails
            if let encoded = try? JSONEncoder().encode(currentFilters) {
                UserDefaults.standard.set(encoded, forKey: "backup_saved_filters")
            }
            
            // Revert local on error - DISABLED for hybrid approach
            /*
            if var revertedDoc = self.userDocument {
                revertedDoc.savedFilters?.removeAll { $0.id == newFilter.id }
                self.userDocument = revertedDoc
            }
            */
        }
    }
    
    func deleteFilter(_ filter: ExpenseFilter) async {
        guard var document = userDocument, let userId = userId else { return }
        
        // 1. Update Local
        var currentFilters = document.savedFilters ?? []
        currentFilters.removeAll { $0.id == filter.id }
        document.savedFilters = currentFilters
        self.userDocument = document
        
        // 2. Update Remote — array de dicts (Firestore.Encoder no admite top-level array)
        do {
            let dicts = try currentFilters.map { try Firestore.Encoder().encode($0) }
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["savedFilters": dicts])
        } catch {
            self.error = "Error al eliminar filtro: \(error.localizedDescription)"
        }
        
        // 3. Update UserDefaults backup
        if let encoded = try? JSONEncoder().encode(currentFilters) {
            UserDefaults.standard.set(encoded, forKey: "backup_saved_filters")
        }
    }
    
    func updateFilter(_ updatedFilter: ExpenseFilter) async {
        guard var document = userDocument, let userId = userId else { 
            logger.warning("⚠️ No userDocument or userId available")
            return 
        }
        
        logger.info("🔄 Updating filter '\(updatedFilter.name ?? "unnamed")' (ID: \(updatedFilter.id))")
        
        // 1. Update Local
        var currentFilters = document.savedFilters ?? []
        if let index = currentFilters.firstIndex(where: { $0.id == updatedFilter.id }) {
            logger.info("✅ Found filter at index \(index), updating...")
            currentFilters[index] = updatedFilter
            document.savedFilters = currentFilters
            self.userDocument = document
        } else {
            logger.error("❌ Filter not found in local cache")
            self.error = "Filtro no encontrado"
            return
        }
        
        // 2. Update Remote — array de dicts
        do {
            let dicts = try currentFilters.map { try Firestore.Encoder().encode($0) }
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["savedFilters": dicts])
            logger.info("✅ Filter updated in Firestore")
        } catch {
            logger.error("❌ Error updating filter in Firestore: \(error.localizedDescription)")
            self.error = "Error al actualizar filtro: \(error.localizedDescription)"
        }
        
        // 3. Update UserDefaults backup
        if let encoded = try? JSONEncoder().encode(currentFilters) {
            UserDefaults.standard.set(encoded, forKey: "backup_saved_filters")
            logger.info("✅ Filter backed up to UserDefaults")
        }
    }
}

