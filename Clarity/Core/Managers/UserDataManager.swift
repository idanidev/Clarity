// UserDataManager.swift
// Singleton to cache user data after login (categories, settings, etc.)
// Follows iOS best practices: @MainActor, proper error handling, Combine integration

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog
import SwiftUI

/// Manages cached user data loaded on login
/// - Uses singleton pattern for app-wide access
/// - @MainActor ensures thread safety for UI updates
/// - Published properties allow SwiftUI reactivity
@MainActor
final class UserDataManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = UserDataManager()
    
    // MARK: - Published Properties (UI-reactive cache)
    @Published private(set) var categories: [Category] = []
    @Published private(set) var paymentMethods: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    /// Indicates if initial data has been loaded
    var hasLoaded: Bool { !categories.isEmpty }
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "UserData")
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // Cache control
    private var categoriesVersion: String?
    private var lastCategoriesUpdate: Date?
    
    // MARK: - Initialization
    private init() {
        // Initialize with default payment methods and categories
        paymentMethods = PaymentMethod.allCases.map { $0.rawValue }
        categories = createDefaultCategories()
    }
    
    // MARK: - Public API
    
    /// Loads all user data after successful login
    /// Call this once after authentication succeeds
    func loadUserData() async {
        guard let userId = userId else {
            logger.warning("Cannot load user data: no authenticated user")
            // Still load defaults
            categories = createDefaultCategories()
            return
        }
        
        // Prevent duplicate loading while in progress
        guard !isLoading else {
            logger.debug("Data loading already in progress")
            return
        }
        
        isLoading = true
        error = nil
        
        logger.info("Loading user data for \(userId, privacy: .private)")
        
        // Load categories with caching
        do {
            // Check version first
            let doc = try await db.collection("users").document(userId).getDocument()
            
            var shouldReload = true
            
            if let data = doc.data(),
               let version = data["categoriesVersion"] as? String,
               let updated = (data["categoriesUpdatedAt"] as? Timestamp)?.dateValue() {
                
                // If version matches and updated recently (< 1h), skip reload
                if version == categoriesVersion,
                   let lastUpdate = lastCategoriesUpdate,
                   Date().timeIntervalSince(lastUpdate) < 3600 {
                    logger.info("✅ Categories cache hit, skipping reload")
                    shouldReload = false
                } else {
                    categoriesVersion = version
                    lastCategoriesUpdate = Date()
                }
            }
            
            if shouldReload {
                let loadedCategories = try await loadCategories(for: userId)
                categories = loadedCategories
                logger.info("Loaded \(self.categories.count) categories")
            }
        } catch {
            logger.warning("Could not load user categories, using defaults: \(error.localizedDescription)")
            categories = createDefaultCategories()
        }
        
        // Load payment methods (non-critical, use defaults on failure)
        do {
            let customMethods = try await loadPaymentMethods(for: userId)
            var allMethods = Set(PaymentMethod.allCases.map { $0.rawValue })
            allMethods.formUnion(customMethods)
            paymentMethods = allMethods.sorted()
            logger.info("Loaded \(self.paymentMethods.count) payment methods")
        } catch {
            logger.warning("Could not load payment methods, using defaults: \(error.localizedDescription)")
            paymentMethods = PaymentMethod.allCases.map { $0.rawValue }
        }
        
        isLoading = false
    }
    
    /// Force reload categories (can be called when user modifies categories)
    func refreshCategories() async {
        guard let userId = userId else { return }
        
        do {
            categories = try await loadCategories(for: userId)
            logger.info("Refreshed categories: \(self.categories.count)")
        } catch {
            logger.error("Failed to refresh categories: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Category CRUD Operations
    
    /// Add a new category to Firebase (stored in user document map)
    func addCategory(_ category: Category) async throws {
        guard let userId = userId else {
            throw NSError(domain: "UserDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let categoryData: [String: Any] = [
            "color": category.color,
            "subcategories": category.subcategories
        ]
        
        try await db.collection("users").document(userId).updateData([
            "categories.\(category.name)": categoryData,
            "categoriesVersion": UUID().uuidString,
            "categoriesUpdatedAt": FieldValue.serverTimestamp()
        ])
        
        logger.info("✅ Category '\(category.name)' added to user document map")
        await refreshCategories()
    }
    
    /// Update an existing category in Firebase
    func updateCategory(_ category: Category) async throws {
        guard let userId = userId else {
            throw NSError(domain: "UserDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid category or user"])
        }
        
        let categoryData: [String: Any] = [
            "color": category.color,
            "subcategories": category.subcategories
        ]
        
        // If name changed, delete old and add new
        if let oldId = category.id, oldId != category.name {
            try await db.collection("users").document(userId).updateData([
                "categories.\(oldId)": FieldValue.delete()
            ])
        }
        
        try await db.collection("users").document(userId).updateData([
            "categories.\(category.name)": categoryData,
            "categoriesVersion": UUID().uuidString,
            "categoriesUpdatedAt": FieldValue.serverTimestamp()
        ])
        
        logger.info("✅ Category '\(category.name)' updated in user document map")
        await refreshCategories()
    }
    
    /// Delete a category from Firebase
    func deleteCategory(id: String) async throws {
        guard let userId = userId else {
            throw NSError(domain: "UserDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        try await db.collection("users").document(userId).updateData([
            "categories.\(id)": FieldValue.delete(),
            "categoriesVersion": UUID().uuidString,
            "categoriesUpdatedAt": FieldValue.serverTimestamp()
        ])
        
        logger.info("✅ Category '\(id)' deleted from user document map")
        await refreshCategories()
    }
    
    /// Clears all cached data (call on logout)
    func clearCache() {
        categories = createDefaultCategories()
        paymentMethods = PaymentMethod.allCases.map { $0.rawValue }
        error = nil
        categoriesVersion = nil
        lastCategoriesUpdate = nil
        logger.info("User data cache cleared")
    }
    
    // MARK: - Convenience Accessors
    
    /// Returns category names for use in pickers/filters
    var categoryNames: [String] {
        categories.map { $0.name }
    }
    
    /// Returns subcategories for a given category
    func subcategories(for categoryName: String) -> [String] {
        categories
            .first { $0.name.localizedCaseInsensitiveContains(categoryName) }?
            .subcategories ?? []
    }
    
    /// Returns the color hex for a category
    func colorHex(for categoryName: String) -> String {
        categories
            .first { $0.name.localizedCaseInsensitiveContains(categoryName) }?
            .color ?? "#6B7280"
    }
    
    /// Returns a SwiftUI Color for a category
    func color(for categoryName: String) -> Color {
        Color(hex: colorHex(for: categoryName)) ?? .gray
    }
    
    // MARK: - Private Methods
    
    private func loadCategories(for userId: String) async throws -> [Category] {
        // Read categories from the user document (map field, not collection)
        let doc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = doc.data(),
              let categoriesMap = data["categories"] as? [String: [String: Any]] else {
            logger.info("No categories map found in user document. Using defaults.")
            return createDefaultCategories()
        }
        
        var loadedCategories: [Category] = []
        var order = 0
        
        for (name, categoryData) in categoriesMap {
            let color = categoryData["color"] as? String ?? "#6366F1"
            let subcategories = categoryData["subcategories"] as? [String] ?? []
            
            let category = Category(
                id: name,
                name: name,
                color: color,
                subcategories: subcategories,
                order: order,
                createdAt: Date(),
                updatedAt: Date()
            )
            loadedCategories.append(category)
            order += 1
        }
        
        logger.info("✅ Loaded \(loadedCategories.count) categories from user document map")
        return loadedCategories.sorted { $0.name < $1.name }
    }
    
    /// Initializes default categories in Firebase for a new user
    private func initializeDefaultCategories(for userId: String) async throws {
        let defaults = createDefaultCategories()
        
        logger.info("Initializing \(defaults.count) default categories in Firebase for user \(userId, privacy: .private)")
        
        let batch = db.batch()
        let categoriesRef = db.collection("users").document(userId).collection("categories")
        
        for category in defaults {
            let docRef = categoriesRef.document()
            var categoryData = category
            categoryData.id = docRef.documentID
            categoryData.createdAt = Date()
            categoryData.updatedAt = Date()
            
            do {
                try batch.setData(from: categoryData, forDocument: docRef)
            } catch {
                logger.error("Failed to encode category \(category.name): \(error.localizedDescription)")
            }
        }
        
        try await batch.commit()
        logger.info("✅ Default categories created in Firebase")
    }
    
    private func loadPaymentMethods(for userId: String) async throws -> Set<String> {
        // Get unique payment methods from user's expenses (limit query for performance)
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("expenses")
            .limit(to: 100)  // Limit for performance
            .getDocuments()
        
        var methods = Set<String>()
        for doc in snapshot.documents {
            if let method = doc.data()["paymentMethod"] as? String {
                methods.insert(method)
            }
        }
        
        return methods
    }
    
    private func loadDefaultCategories() {
        categories = createDefaultCategories()
    }
    
    private func createDefaultCategories() -> [Category] {
        DefaultCategory.allCases.enumerated().map { index, cat in
            Category(
                id: nil,  // Let Firestore manage the ID
                name: cat.rawValue,
                color: cat.defaultColor,
                subcategories: cat.defaultSubcategories,
                order: index,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }
}

// MARK: - SwiftUI Environment Key
private struct UserDataManagerKey: EnvironmentKey {
    static let defaultValue = UserDataManager.shared
}

extension EnvironmentValues {
    var userDataManager: UserDataManager {
        get { self[UserDataManagerKey.self] }
        set { self[UserDataManagerKey.self] = newValue }
    }
}
