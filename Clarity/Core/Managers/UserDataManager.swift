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
        
        // Load categories
        do {
            let loadedCategories = try await loadCategories(for: userId)
            categories = loadedCategories
            logger.info("Loaded \(self.categories.count) categories")
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
    
    /// Add a new category to Firebase
    func addCategory(_ category: Category) async throws {
        guard let userId = userId else {
            throw NSError(domain: "UserDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let docRef = db.collection("users").document(userId).collection("categories").document()
        var newCategory = category
        newCategory.id = docRef.documentID
        newCategory.createdAt = Date()
        newCategory.updatedAt = Date()
        
        try docRef.setData(from: newCategory)
        logger.info("✅ Category '\(newCategory.name)' added")
        
        await refreshCategories()
    }
    
    /// Update an existing category in Firebase
    func updateCategory(_ category: Category) async throws {
        guard let userId = userId, let catId = category.id else {
            throw NSError(domain: "UserDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid category or user"])
        }
        
        var updatedCategory = category
        updatedCategory.updatedAt = Date()
        
        try db.collection("users").document(userId).collection("categories")
            .document(catId)
            .setData(from: updatedCategory, merge: true)
        
        logger.info("✅ Category '\(updatedCategory.name)' updated")
        
        await refreshCategories()
    }
    
    /// Delete a category from Firebase
    func deleteCategory(id: String) async throws {
        guard let userId = userId else {
            throw NSError(domain: "UserDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // TODO: Validate that no expenses use this category
        
        try await db.collection("users").document(userId).collection("categories")
            .document(id)
            .delete()
        
        logger.info("✅ Category deleted")
        
        await refreshCategories()
    }
    
    /// Clears all cached data (call on logout)
    func clearCache() {
        categories = createDefaultCategories()
        paymentMethods = PaymentMethod.allCases.map { $0.rawValue }
        error = nil
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
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("categories")
            .order(by: "order") // Added order by
            .getDocuments()
        
        let userCategories = snapshot.documents.compactMap { doc -> Category? in
            try? doc.data(as: Category.self)
        }
        
        // If NO categories exist, initialize defaults in Firebase
        if userCategories.isEmpty {
            logger.info("No user categories found. Initializing defaults in Firebase...")
            try await initializeDefaultCategories(for: userId)
            
            // Reload after initialization
            let newSnapshot = try await db
                .collection("users")
                .document(userId)
                .collection("categories")
                .getDocuments()
            
            return newSnapshot.documents.compactMap { try? $0.data(as: Category.self) }
                .sorted { ($0.order) < ($1.order) }
        }
        
        return userCategories.sorted { ($0.order) < ($1.order) }
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
