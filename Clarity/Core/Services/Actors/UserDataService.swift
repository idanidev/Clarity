// UserDataService.swift
// Clarity
// Created by Clarity Team on 2026-01-12.

import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

/// Actor responsable for thread-safe data operations
/// Maneja toda la lógica de persistencia y comunicación con Firebase
actor UserDataService {
    
    // MARK: - Singleton
    static let shared = UserDataService()
    
    // MARK: - Visualización y Logs
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "UserDataService")
    private let db = Firestore.firestore()
    
    // MARK: - State (Isolated)
    private var categoriesVersion: String?
    private var lastCategoriesUpdate: Date?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Carga las categorías del usuario desde Firestore
    func loadCategories(userId: String) async throws -> (categories: [Category], version: String?) {
        let docRef = db.collection("users").document(userId)
        let doc = try await docRef.getDocument()
        
        // Cache Check Logic
        if let data = doc.data(),
           let _ = data["categoriesVersion"] as? String,
           let _ = (data["categoriesUpdatedAt"] as? Timestamp)?.dateValue() {
           
             // Check if we have a valid in-memory cache status (although actual data storage is in Manager for UI)
             // The manager might decide not to call this if it has valid data, but here we fetch fresh.
             // For strict correctness, the service just fetches. The Manager handles the "should I call service?" logic or we do it here.
             // Let's return the data and let Manager decide update.
        }
        
        guard let data = doc.data(),
              let categoriesMap = data["categories"] as? [String: [String: Any]] else {
            logger.info("No categories map found. Returning defaults.")
            return (createDefaultCategories(), nil)
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
        
        let sorted = loadedCategories.sorted { $0.name < $1.name }
        return (sorted, doc.data()?["categoriesVersion"] as? String)
    }
    
    /// Carga métodos de pago únicos basados en el historial de gastos
    func loadPaymentMethods(userId: String) async throws -> Set<String> {
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("expenses")
            .limit(to: 100)
            .getDocuments()
        
        var methods = Set<String>()
        for doc in snapshot.documents {
            if let method = doc.data()["paymentMethod"] as? String {
                methods.insert(method)
            }
        }
        return methods
    }
    
    /// Guarda o actualiza una categoría
    func saveCategory(_ category: Category, userId: String) async throws {
        let categoryData: [String: Any] = [
            "color": category.color,
            "subcategories": category.subcategories
        ]
        
        try await db.collection("users").document(userId).updateData([
            "categories.\(category.name)": categoryData,
            "categoriesVersion": UUID().uuidString,
            "categoriesUpdatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    /// Elimina una categoría
    func deleteCategory(id: String, userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "categories.\(id)": FieldValue.delete(),
            "categoriesVersion": UUID().uuidString,
            "categoriesUpdatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    /// Inicializa categorías por defecto
    func initializeDefaultCategories(userId: String) async throws {
        let defaults = createDefaultCategories()
        var categoriesMap: [String: [String: Any]] = [:]
        
        for category in defaults {
            categoriesMap[category.name] = [
                "color": category.color,
                "subcategories": category.subcategories
            ]
        }
        
        try await db.collection("users").document(userId).setData([
            "categories": categoriesMap
        ], merge: true)
    }
    
    // MARK: - Helpers
    
    func createDefaultCategories() -> [Category] {
        DefaultCategory.allCases.enumerated().map { index, cat in
            Category(
                id: nil,
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
