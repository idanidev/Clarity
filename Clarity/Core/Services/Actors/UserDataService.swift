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
    /// Versiones con un espejo en marcha ("" = sin versión). Al cargar, la
    /// lectura de caché y el refresco contra servidor llegan casi a la vez:
    /// sin esto, las dos lanzarían el mismo espejo.
    private var espejosEnCurso: Set<String> = []

    /// Margen antes de dar por perdida una lectura (#32). El mismo que
    /// `ExpenseRepository`.
    private static let remoteReadTimeout: TimeInterval = 8

    private init() {}

    // MARK: - Public API

    /// Carga las categorías del usuario desde Firestore.
    /// Fase 1 (esta release): MAP FIELD = source of truth (compat 2.0.x).
    /// Subcolección se mantiene espejo via dual-write para usar en futuro v3.
    /// Esto evita que un delete desde 2.0.2 deje categoría "fantasma" en 2.0.3.
    func loadCategories(userId: String, forceServer: Bool = false) async throws -> (categories: [Category], version: String?) {
        let docRef = db.collection("users").document(userId)

        // Con tope de espera (#32). CRÍTICO: un tiempo agotado tiene que ser
        // un error de red más, nunca «no hay mapa». Por eso envuelve SOLO la
        // lectura y lanza desde aquí, antes de mirar el mapa: a la siembra de
        // más abajo solo se llega con un documento leído de verdad. Y por eso
        // envuelve el bloque entero y no cada `getDocument`: dentro del `do`,
        // el tiempo agotado caería en el `catch` como un fallo de caché.
        // Quien llama (`UserDataManager`) ante un error se queda con las
        // categorías que tenía y no escribe nada.
        let doc = try await withTimeout(Self.remoteReadTimeout) {
            if forceServer {
                // Refresh multi-device: lectura directa de server (sin cache stale)
                return try await docRef.getDocument(source: .server)
            }
            do {
                let cached = try await docRef.getDocument(source: .cache)
                return cached.exists ? cached : try await docRef.getDocument(source: .server)
            } catch {
                return try await docRef.getDocument(source: .server)
            }
        }

        let categoriesMap = doc.data()?["categories"] as? [String: [String: Any]] ?? [:]

        // Map ausente O vacío → defaults. CRÍTICO: persistirlos YA en Firestore.
        // El estado "defaults solo en memoria" causaba pérdida de datos: el primer
        // write dot-path creaba el map con una única entrada y el resto desaparecía.
        // También auto-recupera a usuarios que se quedaron con el map vacío.
        if categoriesMap.isEmpty {
            logger.info("No categories persisted. Seeding defaults to Firestore.")
            let defaults = createDefaultCategories()
            try? await persistCategoriesIfMissing(defaults, userId: userId)
            return (defaults, nil)
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

        // Espejar a subcolección SOLO si la versión cambió desde el último mirror
        // (antes corría en cada load → N writes Firestore por arranque).
        //
        // La versión se apunta DESPUÉS de espejar, no antes: apuntada antes, un
        // espejo fallido se daba por hecho y no se reintentaba hasta que las
        // categorías volvieran a cambiar. Es solo el espejo; el mapa no se toca.
        let version = doc.data()?["categoriesVersion"] as? String
        let claveDeEspejo = version ?? ""
        if version == nil || version != categoriesVersion, !espejosEnCurso.contains(claveDeEspejo) {
            espejosEnCurso.insert(claveDeEspejo)
            Task {
                defer { espejosEnCurso.remove(claveDeEspejo) }
                do {
                    try await mirrorCategoriesToSubcollection(userId: userId, map: categoriesMap)
                    categoriesVersion = version
                } catch {
                    logger.error("Espejo de categorías a la subcolección fallido; se reintentará en la próxima carga: \(error.localizedDescription)")
                }
            }
        }

        let sorted = loaded.sorted { $0.name < $1.name }
        return (sorted, version)
    }

    /// Espejo Fase 1: replica el map field a la subcolección + borra docs huérfanos.
    /// Mantiene la subcolección como espejo exacto del map (source of truth).
    /// Cuando todos los users estén en v2.0.3+, en v3 podemos invertir y leer de subcolección.
    private func mirrorCategoriesToSubcollection(userId: String, map: [String: [String: Any]]) async throws {
        let subRef = db.collection("users").document(userId).collection("categories")
        let mapKeys = Set(map.keys)

        // Un solo batch: upserts del map + delete de huérfanos. La lectura previa
        // (detectar huérfanos) no es batcheable; los writes sí. Antes: 1 await por categoría.
        let snap = try await subRef.getDocuments()
        let batch = db.batch()

        for (key, data) in map {
            batch.setData([
                "name": data["name"] as? String ?? key,
                "color": data["color"] as? String ?? "#6366F1",
                "subcategories": data["subcategories"] as? [String] ?? [],
                "order": data["order"] as? Int ?? 0,
                "mirroredAt": FieldValue.serverTimestamp(),
            ], forDocument: subRef.document(key), merge: true)
        }

        for doc in snap.documents where !mapKeys.contains(doc.documentID) {
            batch.deleteDocument(doc.reference)
        }

        try await batch.commit()
    }

    /// Carga métodos de pago únicos basados en el historial de gastos.
    ///
    /// Solo como alternativa: `UserDataManager` los saca de los gastos que ya
    /// tiene en SwiftData y llama aquí únicamente con la caché local vacía.
    /// Son hasta 100 lecturas, y antes se hacían en cada `loadUserData()`.
    func loadPaymentMethods(userId: String) async throws -> Set<String> {
        let ref = db.collection("users").document(userId).collection("expenses").limit(to: 100)
        // Con tope de espera (#32), alrededor del bloque entero: ver `loadCategories`.
        let snapshot = try await withTimeout(Self.remoteReadTimeout) {
            do {
                let cached = try await ref.getDocuments(source: .cache)
                return cached.isEmpty ? try await ref.getDocuments(source: .server) : cached
            } catch {
                return try await ref.getDocuments(source: .server)
            }
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
                // ID seguro - actualizar map + subcolección.
                // FieldPath (no dot-path string): los ids de categorías default
                // llevan emoji ("Suscripciones📺") y el parser de dot-paths de
                // Firestore los rechaza — FieldPath acepta cualquier carácter.
                try await docRef.updateData([
                    FieldPath(["categories", existingId]): categoryData,
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

    /// Siembra el map `categories` con las categorías dadas SOLO si el documento
    /// aún no tiene map persistido. Los defaults se devolvían solo en memoria
    /// (initializeDefaultCategories nunca se llamaba), así que el primer
    /// addCategory creaba un map con una única entrada vía dot-path y los
    /// defaults desaparecían. Sembrar primero evita esa pérdida de datos.
    func persistCategoriesIfMissing(_ categories: [Category], userId: String) async throws {
        let docRef = db.collection("users").document(userId)
        // Estado real persistido (cache no tiene los defaults en memoria).
        let doc = try await docRef.getDocument(source: .server)
        let existing = doc.data()?["categories"] as? [String: [String: Any]]
        guard CategorySeeding.shouldSeed(existingMap: existing) else { return }

        // Construcción pura del map (conserva ids seguros, UUID si no) — ver CategorySeeding.
        let map = CategorySeeding.buildSeedMap(from: categories)
        guard !map.isEmpty else { return }
        try await docRef.setData([
            "categories": map,
            "categoriesVersion": UUID().uuidString,
            "categoriesUpdatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
        logger.info("🌱 Sembradas \(map.count) categorías por defecto (no estaban persistidas)")
    }

    /// Actualiza el nombre de categoría en todos los gastos existentes.
    /// Internal: también lo usa el flujo "reasignar gastos al borrar categoría".
    func updateExpensesCategoryName(userId: String, oldName: String, newName: String)
        async throws
    {
        logger.info("🔄 Actualizando gastos de '\(oldName)' a '\(newName)'...")

        // Buscar todos los gastos con el nombre antiguo (case-insensitive)
        let expensesRef = db.collection("users").document(userId).collection("expenses")
        let snapshot = try await expensesRef.whereField("category", isEqualTo: oldName)
            .getDocuments()

        logger.info("📦 Encontrados \(snapshot.documents.count) gastos con categoría '\(oldName)'")

        // Batch write troceado (límite Firestore: 500 ops/batch) — antes era un
        // updateData secuencial por gasto: N round-trips y sin atomicidad por grupo.
        for chunk in snapshot.documents.chunked(into: 450) {
            let batch = db.batch()
            for doc in chunk {
                batch.updateData([
                    "category": newName,
                    "updatedAt": FieldValue.serverTimestamp(),
                ], forDocument: doc.reference)
            }
            try await batch.commit()
        }

        // Estos gastos se han reescrito en Firestore sin pasar por el
        // repositorio, y pueden ser de cualquier año. La sincronización de
        // fondo solo baja una ventana reciente: sin esto, los antiguos
        // seguirían con la categoría vieja en la caché hasta la completa
        // semanal. Olvidar las marcas hace que la próxima lo baje todo.
        if !snapshot.documents.isEmpty { ExpenseSyncPolicy.olvidarMarcas() }

        logger.info(
            "✅ Actualizados \(snapshot.documents.count) gastos a la nueva categoría '\(newName)'")
    }

    /// Verifica si un string contiene caracteres prohibidos por Firestore.
    /// Delega en la lógica pura testeable de `CategorySeeding`.
    private func containsForbiddenChars(_ string: String) -> Bool {
        CategorySeeding.containsForbiddenChars(string)
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
            throw UserDataError.categoryNotFound
        }

        // Obtener subcategorías actuales
        var subcategories = categoryData["subcategories"] as? [String] ?? []

        // Verificar que no exista ya
        guard !subcategories.contains(subcategoryName) else {
            throw UserDataError.subcategoryAlreadyExists
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

            // Mismo motivo que en `updateExpensesCategoryName`: reescritos por
            // fuera del repositorio, la caché necesita una sincronización completa.
            if totalUpdated > 0 { ExpenseSyncPolicy.olvidarMarcas() }

            // Marcar migración como completada
            UserDefaults.standard.set(true, forKey: migrationKey)
            logger.info("✅ Category migration completed! Updated \(totalUpdated) expenses")

        } catch {
            logger.error("❌ Error during migration: \(error.localizedDescription)")
            throw error
        }
    }
}
