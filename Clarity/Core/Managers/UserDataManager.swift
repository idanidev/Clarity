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
        // Try to load without ordering first (more reliable)
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("categories")
            .getDocuments()
        
        let userCategories = snapshot.documents.compactMap { doc -> Category? in
            try? doc.data(as: Category.self)
        }
        
        // Return defaults if user has no custom categories
        guard !userCategories.isEmpty else {
            logger.info("No user categories found, using defaults")
            return createDefaultCategories()
        }
        
        // Sort by order field if present
        return userCategories.sorted { ($0.order) < ($1.order) }
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
                id: cat.rawValue,
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
