// CategorySeedingTests.swift
// Tests de regresión para el fix de PÉRDIDA DE DATOS en categorías (CategorySeeding).
//
// Bug histórico (jun 2026): los defaults vivían SOLO en memoria; el primer write dot-path
// "categories.X" creaba el map en Firestore con UNA entrada → el resto desaparecía.
// Estos tests blindan la lógica pura del fix:
//  - NO sobrescribir un map existente (solo sembrar si ausente/vacío)
//  - sembrar TODAS las categorías (no una sola)
//  - conservar ids seguros / reasignar UUID a ids con caracteres prohibidos

import Testing
import Foundation
@testable import Clarity

@Suite("CategorySeeding", .serialized)
@MainActor
struct CategorySeedingTests {

    // MARK: - Fixtures

    private func cat(id: String?, name: String, color: String = "#6366F1",
                     subs: [String] = []) -> Clarity.Category {
        Clarity.Category(id: id, name: name, color: color, subcategories: subs,
                         order: 0, createdAt: nil, updatedAt: nil)
    }

    /// Réplica en memoria de los defaults (igual que `UserDataService.createDefaultCategories`):
    /// id = rawValue de cada DefaultCategory.
    private func defaultsInMemory() -> [Clarity.Category] {
        DefaultCategory.allCases.map {
            cat(id: $0.rawValue, name: $0.rawValue, color: $0.defaultColor, subs: $0.defaultSubcategories)
        }
    }

    // MARK: - containsForbiddenChars

    @Test("forbidden chars: id limpio → false")
    func forbiddenClean() {
        #expect(!CategorySeeding.containsForbiddenChars("abc-123"))
    }

    @Test("forbidden chars: emoji permitido → false")
    func forbiddenEmojiAllowed() {
        #expect(!CategorySeeding.containsForbiddenChars("Suscripciones📺"))
    }

    @Test("forbidden chars: / ~ * [ ] → true")
    func forbiddenSet() {
        #expect(CategorySeeding.containsForbiddenChars("a/b"))
        #expect(CategorySeeding.containsForbiddenChars("a~b"))
        #expect(CategorySeeding.containsForbiddenChars("a*b"))
        #expect(CategorySeeding.containsForbiddenChars("a[b"))
        #expect(CategorySeeding.containsForbiddenChars("a]b"))
    }

    // MARK: - shouldSeed (no sobrescribir)

    @Test("shouldSeed: map nil → siembra")
    func shouldSeedNil() {
        #expect(CategorySeeding.shouldSeed(existingMap: nil))
    }

    @Test("shouldSeed: map vacío → siembra")
    func shouldSeedEmpty() {
        #expect(CategorySeeding.shouldSeed(existingMap: [:]))
    }

    @Test("shouldSeed: map con entradas → NO sobrescribe")
    func shouldNotSeedExisting() {
        let existing: [String: [String: Any]] = ["id1": ["name": "X", "color": "#fff", "subcategories": []]]
        #expect(!CategorySeeding.shouldSeed(existingMap: existing))
    }

    // MARK: - buildSeedMap

    @Test("buildSeedMap: siembra TODAS las categorías, no una sola")
    func buildSeedsAll() {
        let defaults = defaultsInMemory()
        let map = CategorySeeding.buildSeedMap(from: defaults)
        // El bug producía 1 entrada; el fix debe producir las 10.
        #expect(map.count == defaults.count)
        #expect(map.count == 10)
    }

    @Test("buildSeedMap: conserva los ids seguros (defaults usan rawValue)")
    func buildPreservesSafeIds() {
        let defaults = defaultsInMemory()
        let map = CategorySeeding.buildSeedMap(from: defaults)
        let expectedKeys = Set(DefaultCategory.allCases.map { $0.rawValue })
        #expect(Set(map.keys) == expectedKeys)
    }

    @Test("buildSeedMap: id con carácter prohibido → reasigna UUID, conserva nombre")
    func buildReassignsForbiddenId() {
        let bad = cat(id: "Comida/Bebida", name: "Comida/Bebida")
        let map = CategorySeeding.buildSeedMap(from: [bad])
        #expect(map.count == 1)
        let key = map.keys.first!
        // La clave NO es el id prohibido; es un UUID (36 chars).
        #expect(key != "Comida/Bebida")
        #expect(key.count == 36)
        // El nombre real se conserva.
        #expect(map[key]?["name"] as? String == "Comida/Bebida")
    }

    @Test("buildSeedMap: id nil → clave UUID")
    func buildNilIdUsesUUID() {
        let c = cat(id: nil, name: "Nueva")
        let map = CategorySeeding.buildSeedMap(from: [c])
        #expect(map.count == 1)
        #expect(map.keys.first!.count == 36)
        #expect(map[map.keys.first!]?["name"] as? String == "Nueva")
    }

    // MARK: - Escenario del bug (regresión completa)

    @Test("bug: defaults en memoria → addCategory NO pierde el resto")
    func bugScenarioNoDataLoss() {
        // 1. Servidor SIN map persistido → debe sembrar.
        let serverMap: [String: [String: Any]]? = nil
        #expect(CategorySeeding.shouldSeed(existingMap: serverMap))

        // 2. Sembrar defaults (en memoria) ANTES de añadir la nueva.
        let defaults = defaultsInMemory()
        var seeded = CategorySeeding.buildSeedMap(from: defaults)
        #expect(seeded.count == 10) // todas, no una

        // 3. addCategory: el saveCategory hace merge de UNA entrada nueva en el map ya sembrado.
        let newId = UUID().uuidString
        seeded[newId] = ["name": "Mascotas🐶", "color": "#10B981", "subcategories": []]

        // 4. Resultado: defaults + nueva = 11, ninguna perdida.
        #expect(seeded.count == 11)
        for raw in DefaultCategory.allCases.map({ $0.rawValue }) {
            #expect(seeded[raw] != nil)
        }
        #expect(seeded[newId]?["name"] as? String == "Mascotas🐶")
    }
}
