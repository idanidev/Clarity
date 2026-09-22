// UserDataStore.swift
// Protocolo sobre UserDataService para poder inyectar un mock en tests.
//
// Cubre EXACTAMENTE la superficie que consume UserDataManager — ni más ni menos.
// loadUserDocument/initializeDefaultCategories quedan fuera (las usa solo
// FinancialHubViewModel directamente contra el actor concreto).
//
// Notas de diseño (precedente: ExpenseRepositoryProtocol):
//  - Los protocolos no admiten argumentos por defecto → requirements con args
//    explícitos; los call sites pasan `forceServer: false` / `oldName: nil`.
//  - Todos los requirements son `async`: el actor UserDataService los satisface
//    con sus métodos aislados (el hop al actor los hace async para el caller).
//  - La tupla de loadCategories conserva los labels (los callers desestructuran).

import Foundation

protocol UserDataStore: Sendable {
    func createDefaultCategories() async -> [Category]
    func loadCategories(userId: String, forceServer: Bool) async throws -> (categories: [Category], version: String?)
    func loadPaymentMethods(userId: String) async throws -> Set<String>
    func migrateExpenseCategoriesFromSlashToDash(userId: String) async throws
    func persistCategoriesIfMissing(_ categories: [Category], userId: String) async throws
    func saveCategory(_ category: Category, userId: String, oldName: String?) async throws
    func addSubcategory(_ subcategoryName: String, toCategoryId categoryId: String, userId: String) async throws
    func updateExpensesCategoryName(userId: String, oldName: String, newName: String) async throws
    func deleteCategory(id: String, userId: String) async throws
    /// Escritura remota del filtro predeterminado. Está en el protocolo para
    /// que los tests de `saveDefaultFilter` no lleguen al Firestore real: antes
    /// el manager llamaba a `Firestore.firestore()` a pelo y cada pasada de
    /// tests dejaba un «Permission denied» contra `users/test-uid-…`.
    func saveDefaultFilter(_ filter: ExpenseFilter, userId: String) async throws
    /// Escribe SOLO el campo `homeDisposicion` del documento del usuario
    /// (`setData(merge:)`), nunca `categories` ni el documento entero. En el
    /// protocolo por lo mismo que el filtro: que los tests no lleguen a Firestore.
    func saveHomeDisposicion(_ disposicion: HomeDisposicion, userId: String) async throws
}

extension UserDataService: UserDataStore {}
