// MockUserDataStore.swift
// Mock de UserDataStore con grabación de llamadas EN ORDEN — el orden es el
// contrato crítico (persistCategoriesIfMissing SIEMPRE antes de cualquier write
// del map; reassign antes de delete). Patrón base: MockExpenseRepository.

import Foundation
@testable import Clarity

final class MockUserDataStore: UserDataStore, @unchecked Sendable {

    /// Llamadas en orden de invocación, con args clave embebidos.
    var recordedCalls: [String] = []

    /// Lo que devuelve loadCategories (estado "persistido" simulado).
    var storedCategories: [Clarity.Category] = []

    var shouldFailDeleteCategory = false

    func createDefaultCategories() async -> [Clarity.Category] {
        recordedCalls.append("createDefaultCategories")
        return storedCategories
    }

    func loadCategories(userId: String, forceServer: Bool) async throws -> (categories: [Clarity.Category], version: String?) {
        recordedCalls.append("loadCategories")
        return (storedCategories, nil)
    }

    func loadPaymentMethods(userId: String) async throws -> Set<String> {
        recordedCalls.append("loadPaymentMethods")
        return []
    }

    func migrateExpenseCategoriesFromSlashToDash(userId: String) async throws {
        recordedCalls.append("migrate")
    }

    func persistCategoriesIfMissing(_ categories: [Clarity.Category], userId: String) async throws {
        recordedCalls.append("persistCategoriesIfMissing(\(categories.count))")
    }

    func saveCategory(_ category: Clarity.Category, userId: String, oldName: String?) async throws {
        recordedCalls.append("saveCategory(\(category.name))")
    }

    func addSubcategory(_ subcategoryName: String, toCategoryId categoryId: String, userId: String) async throws {
        recordedCalls.append("addSubcategory(\(subcategoryName))")
    }

    func updateExpensesCategoryName(userId: String, oldName: String, newName: String) async throws {
        recordedCalls.append("updateExpensesCategoryName(\(oldName)→\(newName))")
    }

    func deleteCategory(id: String, userId: String) async throws {
        if shouldFailDeleteCategory {
            throw UserDataError.categoryNotFound
        }
        recordedCalls.append("deleteCategory(\(id))")
        storedCategories.removeAll { $0.id == id }
    }
}
