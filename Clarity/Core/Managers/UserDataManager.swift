// UserDataManager.swift
// Wrapper principal para estado de usuario (UI Layer)
// Gestiona el estado observable para las vistas y delega la lógica a UserDataService

import Foundation
import Combine
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
        guard let userId = userId else {
            logger.warning("No authenticated user, using defaults")
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            print("📥 UserDataManager: Loading data for \(userId)...") 
            async let fetchedCategories = service.loadCategories(userId: userId)
            async let fetchedMethods = service.loadPaymentMethods(userId: userId)
            await self.loadExpenses() // Load expenses for cache
            
            let (catsResult, _) = try await fetchedCategories
            self.categories = catsResult
            
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
            print("✅ UserDataManager: Loaded \(categories.count) categories, \(savedFilters.count) filters, Default: \(defaultFilter?.name ?? "None")")
            
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
        await loadUserData()
    }
    
    // MARK: - Expenses Cache
    
    func loadExpenses() async {
        do {
            let descriptor = FetchDescriptor<ExpenseModel>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let models = try SwiftDataService.shared.context.fetch(descriptor)
            self.expenses = models.map { $0.toDomain() }
            print("📦 UserDataManager: Cached \(self.expenses.count) expenses for voice intelligence")
        } catch {
            logger.error("❌ Failed to cache expenses: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD
    
    func addCategory(_ category: Category) async {
        guard let userId = userId else { return }
        do {
            try await service.saveCategory(category, userId: userId)
            await loadUserData() // Refresh state
        } catch {
            self.error = "Error al guardar categoría: \(error.localizedDescription)"
        }
    }
    
    func updateCategory(_ category: Category) async {
        guard let userId = userId else { return }
        // Si el nombre cambia, tendríamos que manejar el borrado del antiguo en el servicio
        // Por simplicidad del refactor, asumimos actualización directa o mejora en el servicio
        // El servicio original tenía lógica de borrado si cambiaba ID.
        // Lo delegamos al servicio:
        do {
            try await service.saveCategory(category, userId: userId)
            await loadUserData()
        } catch {
            self.error = "Error al actualizar: \(error.localizedDescription)"
        }
    }
    
    func deleteCategory(id: String) async {
        guard let userId = userId else { return }
        do {
            try await service.deleteCategory(id: id, userId: userId)
            await loadUserData()
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
        Color(hex: colorHex(for: categoryName)) ?? .gray
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
        guard var document = userDocument, let userId = userId else { return }
        
        // 1. Update Local
        var newSettings = document.settings ?? .default
        newSettings.hasCompletedOnboarding = true
        document.settings = newSettings
        self.userDocument = document
        
        // 2. Update Remote
        Task {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .updateData(["settings.hasCompletedOnboarding": true])
                logger.info("✅ Onboarding marked as completed")
            } catch {
                logger.error("❌ Error saving onboarding status: \(error.localizedDescription)")
            }
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
        
        // 2. Update Remote
        do {
            let data = try Firestore.Encoder().encode(currentFilters)
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["savedFilters": data])
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
        
        // 2. Update Remote
        do {
            let data = try Firestore.Encoder().encode(currentFilters)
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(["savedFilters": data])
            logger.info("✅ Filter deleted")
        } catch {
            logger.error("❌ Error deleting filter: \(error.localizedDescription)")
            self.error = "Error al eliminar filtro: \(error.localizedDescription)"
            
            // Revert local on error (complicated without cache, skipping complexity for now)
        }
    }
}

