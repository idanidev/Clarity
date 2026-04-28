// UserDataService.swift
// Clarity
// Created by Clarity Team on 2026-01-12.

import FirebaseAuth
@preconcurrency import FirebaseFirestore
import Foundation
import OSLog

/// Actor responsable for thread-safe data operations
/// Maneja toda la lógica de persistencia y comunicación con Firebase
actor UserDataService {

    // MARK: - Singleton
    static let shared = UserDataService()

    // MARK: - Visualización y Logs
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "UserDataService")
    private let db = Firestore.firestore()

    // MARK: - State (Isolated)
    private var categoriesVersion: String?
    private var lastCategoriesUpdate: Date?

    private init() {}

    // MARK: - Public API

    /// Carga las categorías del usuario desde Firestore.
    /// Fase 1 (esta release): MAP FIELD = source of truth (compat 2.0.x).
    /// Subcolección se mantiene espejo via dual-write para usar en futuro v3.
    /// Esto evita que un delete desde 2.0.2 deje categoría "fantasma" en 2.0.3.
    func loadCategories(userId: String) async throws -> (categories: [Category], version: String?) {
        let docRef = db.collection("users").document(userId)

        let doc: DocumentSnapshot
        do {
            let cached = try await docRef.getDocument(source: .cache)
            doc = cached.exists ? cached : try await docRef.getDocument(source: .server)
        } catch {
            doc = try await docRef.getDocument(source: .server)
        }

        guard let data = doc.data(),
            let categoriesMap = data["categories"] as? [String: [String: Any]]
        else {
            logger.info("No categories map found. Returning defaults.")
            return (createDefaultCategories(), nil)
        }

        var loaded: [Category] = []
        var order = 0
        for (key, categoryData) in categoriesMap {
            let name = categoryData["name"] as? String ?? key
            let color = categoryData["color"] as? String ?? "#6366F1"
            let subcategories = categoryData["subcategories"] as? [String] ?? []
            loaded.append(Category(
                id: key, name: name, color: color,
                subcategories: subcategories, order: order,
                createdAt: nil, updatedAt: nil
            ))
            order += 1
        }

        // Espejar a subcolección en background (preparación futura v3, no afecta lectura)
        Task { try? await mirrorCategoriesToSubcollection(userId: userId, map: categoriesMap) }

        let sorted = loaded.sorted { $0.name < $1.name }
        return (sorted, doc.data()?["categoriesVersion"] as? String)
    }

    /// Espejo Fase 1: replica el map field a la subcolección + borra docs huérfanos.
    /// Mantiene la subcolección como espejo exacto del map (source of truth).
    /// Cuando todos los users estén en v2.0.3+, en v3 podemos invertir y leer de subcolección.
    private func mirrorCategoriesToSubcollection(userId: String, map: [String: [String: Any]]) async throws {
        let subRef = db.collection("users").document(userId).collection("categories")
        let mapKeys = Set(map.keys)

        // 1) Upsert entradas del map a subcolección
        for (key, data) in map {
            try await subRef.document(key).setData([
                "name": data["name"] as? String ?? key,
                "color": data["color"] as? String ?? "#6366F1",
                "subcategories": data["subcategories"] as? [String] ?? [],
                "order": data["order"] as? Int ?? 0,
                "mirroredAt": FieldValue.serverTimestamp(),
            ], merge: true)
        }

        // 2) Borrar docs huérfanos en subcolección (si user borró desde 2.0.2)
        let snap = try await subRef.getDocuments()
        for doc in snap.documents where !mapKeys.contains(doc.documentID) {
            try? await doc.reference.delete()
        }
    }

    /// Carga métodos de pago únicos basados en el historial de gastos
    func loadPaymentMethods(userId: String) async throws -> Set<String> {
        let ref = db.collection("users").document(userId).collection("expenses").limit(to: 100)
        let snapshot: QuerySnapshot
        do {
            let cached = try await ref.getDocuments(source: .cache)
            snapshot = cached.isEmpty ? try await ref.getDocuments(source: .server) : cached
        } catch {
            snapshot = try await ref.getDocuments(source: .server)
        }
        var methods = Set<String>()
        for doc in snapshot.documents {
            if let method = doc.data()["paymentMethod"] as? String {
                methods.insert(method)
            }
        }
        return methods
    }

    /// Guarda o actualiza una categoría.
    /// Fase 1 dual-write: escribe a map field (compat 2.0.x) Y a subcolección (futuro).
    func saveCategory(_ category: Category, userId: String, oldName: String? = nil) async throws {
        let categoryData: [String: Any] = [
            "name": category.name,  // El nombre puede tener /, ~, etc. ¡No importa!
            "color": category.color,
            "subcategories": category.subcategories,
        ]
        let docRef = db.collection("users").document(userId)
        let subRef = docRef.collection("categories")

        if let existingId = category.id, !existingId.isEmpty {
            // ACTUALIZACIÓN - verificar si el ID tiene caracteres prohibidos
            if containsForbiddenChars(existingId) {
                // Migrar a UUID nuevo
                let newId = UUID().uuidString
                logger.warning(
                    "⚠️ Migrando categoría '\(category.name)' de ID antiguo '\(existingId)' a nuevo UUID '\(newId)'"
                )

                // Atómico: add-new + delete-old en un solo updateData (antes eran 2 ops
                // separadas; si la 2a fallaba el usuario veía la categoría duplicada).
                try await docRef.updateData([
                    "categories.\(newId)": categoryData,
                    FieldPath(["categories", existingId]): FieldValue.delete(),
                    "categoriesVersion": UUID().uuidString,
                    "categoriesUpdatedAt": FieldValue.serverTimestamp(),
                ])
                // Subcolección: nuevo doc, borra viejo
                try await subRef.document(newId).setData(categoryData, merge: true)
                try? await subRef.document(existingId).delete()
            } else {
                // ID seguro - actualizar map + subcolección
                try await docRef.updateData([
                    "categories.\(existingId)": categoryData,
                    "categoriesVersion": UUID().uuidString,
                    "categoriesUpdatedAt": FieldValue.serverTimestamp(),
                ])
                try await subRef.document(existingId).setData(categoryData, merge: true)
            }

            // ✅ Si el nombre cambió, actualizar TODOS los gastos con el nombre antiguo
            if let oldName = oldName, oldName != category.name {
                try await updateExpensesCategoryName(
                    userId: userId, oldName: oldName, newName: category.name)
            }
        } else {
            // NUEVA - crear UUID único
            let newId = UUID().uuidString
            try await docRef.updateData([
                "categories.\(newId)": categoryData,
                "categoriesVersion": UUID().uuidString,
                "categoriesUpdatedAt": FieldValue.serverTimestamp(),
            ])
            try await subRef.document(newId).setData(categoryData, merge: true)
        }
    }

    /// Actualiza el nombre de categoría en todos los gastos existentes
    private func updateExpensesCategoryName(userId: String, oldName: String, newName: String)
        async throws
    {
        logger.info("🔄 Actualizando gastos de '\(oldName)' a '\(newName)'...")

        // Buscar todos los gastos con el nombre antiguo (case-insensitive)
        let expensesRef = db.collection("users").document(userId).collection("expenses")
        let snapshot = try await expensesRef.whereField("category", isEqualTo: oldName)
            .getDocuments()

        logger.info("📦 Encontrados \(snapshot.documents.count) gastos con categoría '\(oldName)'")

        // Actualizar cada gasto
        for doc in snapshot.documents {
            try await doc.reference.updateData([
                "category": newName,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
        }

        logger.info(
            "✅ Actualizados \(snapshot.documents.count) gastos a la nueva categoría '\(newName)'")
    }

    /// Verifica si un string contiene caracteres prohibidos por Firestore
    private func containsForbiddenChars(_ string: String) -> Bool {
        let forbidden: Set<Character> = ["/", "~", "*", "[", "]"]
        return string.contains(where: { forbidden.contains($0) })
    }

    /// Elimina una categoría (dual-delete: map field + subcolección)
    func deleteCategory(id: String, userId: String) async throws {
        let docRef = db.collection("users").document(userId)
        try await docRef.updateData([
            FieldPath(["categories", id]): FieldValue.delete(),
            "categoriesVersion": UUID().uuidString,
            "categoriesUpdatedAt": FieldValue.serverTimestamp(),
        ])
        try? await docRef.collection("categories").document(id).delete()
    }

    /// Añade una subcategoría a una categoría existente
    func addSubcategory(_ subcategoryName: String, toCategoryId categoryId: String, userId: String)
        async throws
    {
        // Obtener la categoría actual
        let docRef = db.collection("users").document(userId)
        let doc = try await docRef.getDocument()

        guard let data = doc.data(),
            let categoriesMap = data["categories"] as? [String: [String: Any]],
            let categoryData = categoriesMap[categoryId]
        else {
            throw NSError(
                domain: "UserDataService", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Categoría no encontrada"])
        }

        // Obtener subcategorías actuales
        var subcategories = categoryData["subcategories"] as? [String] ?? []

        // Verificar que no exista ya
        guard !subcategories.contains(subcategoryName) else {
            throw NSError(
                domain: "UserDataService", code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Esta subcategoría ya existe"])
        }

        // Añadir la nueva subcategoría
        subcategories.append(subcategoryName)

        // Actualizar en Firestore - usar FieldPath para manejar IDs con caracteres especiales
        let updatedCategoryData: [String: Any] = [
            "name": categoryData["name"] ?? categoryId,
            "color": categoryData["color"] ?? "#6366F1",
            "subcategories": subcategories,
        ]

        // Dual-write: map field + subcolección
        try await docRef.updateData([
            FieldPath(["categories", categoryId]): updatedCategoryData,
            "categoriesVersion": UUID().uuidString,
            "categoriesUpdatedAt": FieldValue.serverTimestamp(),
        ])
        try await docRef.collection("categories").document(categoryId).setData(updatedCategoryData, merge: true)
    }

    /// Inicializa categorías por defecto
    func initializeDefaultCategories(userId: String) async throws {
        let defaults = createDefaultCategories()
        var categoriesMap: [String: [String: Any]] = [:]

        for category in defaults {
            // Usar UUID para garantizar unicidad
            let safeKey = UUID().uuidString
            categoriesMap[safeKey] = [
                "name": category.name,  // Guardar el nombre real
                "color": category.color,
                "subcategories": category.subcategories,
            ]
        }

        try await db.collection("users").document(userId).setData(
            [
                "categories": categoriesMap
            ], merge: true)
    }

    /// Carga el documento completo del usuario (para ajustes, info personal, etc)
    func loadUserDocument(userId: String) async throws -> UserDocument? {
        let doc = try await db.collection("users").document(userId).getDocument()
        return try doc.data(as: UserDocument.self)
    }

    // MARK: - Helpers

    func createDefaultCategories() -> [Category] {
        DefaultCategory.allCases.enumerated().map { index, cat in
            Category(
                id: cat.rawValue,  // ← never nil: ForEach Identifiable necesita id único estable
                name: cat.rawValue,
                color: cat.defaultColor,
                subcategories: cat.defaultSubcategories,
                order: index,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }

    // MARK: - Migration

    /// Migra todas las categorías de gastos que contienen "/" a "-"
    func migrateExpenseCategoriesFromSlashToDash(userId: String) async throws {
        let migrationKey = "didMigrateCategoriesSlashToDash_v2"  // v2 para forzar re-ejecución

        // Verificar si ya se ejecutó esta migración
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            logger.info("✅ Category migration already completed")
            return
        }

        logger.info("🔄 Starting category migration from '/' to '-'...")

        var totalUpdated = 0

        do {
            // Obtener TODOS los gastos del usuario
            let expensesRef = db.collection("users").document(userId).collection("expenses")
            let snapshot = try await expensesRef.getDocuments()

            logger.info(
                "📦 Checking \(snapshot.documents.count) expenses for '/' in category names...")

            // Filtrar y actualizar solo los que tienen "/" en la categoría
            for doc in snapshot.documents {
                guard let categoryName = doc.data()["category"] as? String else { continue }

                // Si contiene "/", reemplazarlo por "-"
                if categoryName.contains("/") {
                    let newName = categoryName.replacingOccurrences(of: "/", with: "-")
                        .replacingOccurrences(of: "  ", with: " ")  // Limpiar dobles espacios si había " / "
                        .trimmingCharacters(in: .whitespaces)

                    logger.info("   ✏️ Updating '\(categoryName)' → '\(newName)'")

                    try await doc.reference.updateData([
                        "category": newName,
                        "updatedAt": FieldValue.serverTimestamp(),
                    ])

                    totalUpdated += 1
                }
            }

            // Marcar migración como completada
            UserDefaults.standard.set(true, forKey: migrationKey)
            logger.info("✅ Category migration completed! Updated \(totalUpdated) expenses")

        } catch {
            logger.error("❌ Error during migration: \(error.localizedDescription)")
            throw error
        }
    }
}
