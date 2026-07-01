// UserDataManagerCategoryTests.swift
// Tests del flujo de categorías de UserDataManager con store mockeado.
// Cierra la deuda que quedó abierta en la tanda de regresión anterior:
// el ORDEN reassign→delete de deleteCategory(reassignExpensesTo:) y el
// contrato "persistCategoriesIfMissing antes de cualquier write del map"
// (regla crítica .claude/rules/architecture.md — pérdida de datos jun 2026).

import Testing
import Foundation
@testable import Clarity

@Suite("UserDataManager categorías", .serialized)
@MainActor
struct UserDataManagerCategoryTests {

    private func cat(_ id: String, _ name: String) -> Clarity.Category {
        Clarity.Category(id: id, name: name, color: "#6366F1", subcategories: [],
                         order: 0, createdAt: nil, updatedAt: nil)
    }

    private func makeSUT(categories: [Clarity.Category]) -> (UserDataManager, MockUserDataStore) {
        let store = MockUserDataStore()
        store.storedCategories = categories
        let manager = UserDataManager(service: store, userIdProvider: { "test-uid" })
        manager.categories = categories
        return (manager, store)
    }

    @Test("deleteCategory con reassign: orden seed → reassign → delete → reload")
    func deleteWithReassignOrder() async {
        let a = cat("cat-a", "Ocio")
        let b = cat("cat-b", "Otros")
        let (manager, store) = makeSUT(categories: [a, b])

        await manager.deleteCategory(id: "cat-a", reassignExpensesTo: "Otros")

        // El contrato completo, EN ORDEN:
        // 1. seed (evita delete no-op sobre map no persistido → categoría fantasma)
        // 2. reassign de gastos ANTES del delete (evita huérfanos si el delete falla)
        // 3. delete
        // 4. refresh (loadCategories)
        #expect(store.recordedCalls.first == "persistCategoriesIfMissing(2)")
        let reassignIdx = store.recordedCalls.firstIndex(of: "updateExpensesCategoryName(Ocio→Otros)")
        let deleteIdx = store.recordedCalls.firstIndex(of: "deleteCategory(cat-a)")
        let reloadIdx = store.recordedCalls.firstIndex(of: "loadCategories")
        #expect(reassignIdx != nil && deleteIdx != nil && reloadIdx != nil)
        if let r = reassignIdx, let d = deleteIdx, let l = reloadIdx {
            #expect(r < d)
            #expect(d < l)
        }
        #expect(manager.error == nil)
        // El estado local refleja el store tras el reload.
        #expect(manager.categories.map(\.id) == ["cat-b"])
    }

    @Test("deleteCategory sin reassign: NO migra gastos")
    func deleteWithoutReassign() async {
        let a = cat("cat-a", "Ocio")
        let b = cat("cat-b", "Otros")
        let (manager, store) = makeSUT(categories: [a, b])

        await manager.deleteCategory(id: "cat-a")

        #expect(store.recordedCalls.first == "persistCategoriesIfMissing(2)")
        #expect(!store.recordedCalls.contains(where: { $0.hasPrefix("updateExpensesCategoryName") }))
        #expect(store.recordedCalls.contains("deleteCategory(cat-a)"))
    }

    @Test("deleteCategory: si el nombre destino es el mismo, no migra")
    func deleteReassignSameNameSkipsMigration() async {
        let a = cat("cat-a", "Ocio")
        let (manager, store) = makeSUT(categories: [a])

        await manager.deleteCategory(id: "cat-a", reassignExpensesTo: "Ocio")

        #expect(!store.recordedCalls.contains(where: { $0.hasPrefix("updateExpensesCategoryName") }))
    }

    @Test("deleteCategory: fallo del store → error visible, sin crash")
    func deleteFailureSetsError() async {
        let a = cat("cat-a", "Ocio")
        let (manager, store) = makeSUT(categories: [a])
        store.shouldFailDeleteCategory = true

        await manager.deleteCategory(id: "cat-a")

        #expect(manager.error != nil)
    }

    @Test("addCategory: seed SIEMPRE antes del save (regla anti pérdida de datos)")
    func addCategorySeedsBeforeSave() async {
        let a = cat("cat-a", "Ocio")
        let (manager, store) = makeSUT(categories: [a])

        await manager.addCategory(cat("cat-new", "Mascotas"))

        let seedIdx = store.recordedCalls.firstIndex(where: { $0.hasPrefix("persistCategoriesIfMissing") })
        let saveIdx = store.recordedCalls.firstIndex(of: "saveCategory(Mascotas)")
        #expect(seedIdx != nil && saveIdx != nil)
        if let s = seedIdx, let v = saveIdx {
            #expect(s < v)
        }
    }

    @Test("sin usuario autenticado: deleteCategory no toca el store")
    func noUserNoCalls() async {
        let a = cat("cat-a", "Ocio")
        let store = MockUserDataStore()
        store.storedCategories = [a]
        let manager = UserDataManager(service: store, userIdProvider: { nil })
        manager.categories = [a]

        await manager.deleteCategory(id: "cat-a", reassignExpensesTo: "Otros")

        #expect(store.recordedCalls.isEmpty)
    }
}
