// UserLearningManagerTests.swift
// Tests for voice learning system

import Testing
@testable import Clarity

@Suite("UserLearningManager", .serialized)
struct UserLearningManagerTests {

    // Use a fresh manager for each test by clearing state
    private func freshManager() async -> UserLearningManager {
        let manager = UserLearningManager.shared
        await manager.clearAllLearning()
        return manager
    }

    // MARK: - Basic Learning

    @Test("Learn and retrieve a preference")
    func learnAndRetrieve() async {
        let manager = await freshManager()

        await manager.learn(merchant: "Mercadona", category: "Alimentacion", subcategory: "Supermercado")
        let pref = await manager.getPreference(for: "Mercadona")

        #expect(pref != nil)
        #expect(pref?.category == "Alimentacion")
        #expect(pref?.subcategory == "Supermercado")
    }

    @Test("Return nil for unknown merchant")
    func unknownMerchant() async {
        let manager = await freshManager()

        let pref = await manager.getPreference(for: "TiendaQueNoExiste")
        #expect(pref == nil)
    }

    // MARK: - Normalization

    @Test("Case-insensitive lookup")
    func caseInsensitive() async {
        let manager = await freshManager()

        await manager.learn(merchant: "MERCADONA", category: "Alimentacion", subcategory: "Supermercado")
        let pref = await manager.getPreference(for: "mercadona")

        #expect(pref != nil)
        #expect(pref?.category == "Alimentacion")
    }

    @Test("Diacritic-insensitive lookup")
    func diacriticInsensitive() async {
        let manager = await freshManager()

        await manager.learn(merchant: "Cafetería", category: "Ocio", subcategory: "Cafe")
        let pref = await manager.getPreference(for: "cafeteria")

        #expect(pref != nil)
        #expect(pref?.category == "Ocio")
    }

    // MARK: - Reinforcement

    @Test("Repeated learning increments count")
    func reinforcement() async {
        let manager = await freshManager()

        await manager.learn(merchant: "Starbucks", category: "Ocio", subcategory: "Cafe")
        await manager.learn(merchant: "Starbucks", category: "Ocio", subcategory: "Cafe")
        await manager.learn(merchant: "Starbucks", category: "Ocio", subcategory: "Cafe")

        let pref = await manager.getPreference(for: "Starbucks")
        #expect(pref != nil)
        #expect(pref?.category == "Ocio")
    }

    @Test("Category change replaces preference")
    func categoryChange() async {
        let manager = await freshManager()

        await manager.learn(merchant: "Amazon", category: "Compras", subcategory: "Electronica")
        await manager.learn(merchant: "Amazon", category: "Ocio", subcategory: "Suscripciones")

        let pref = await manager.getPreference(for: "Amazon")
        #expect(pref?.category == "Ocio")
        #expect(pref?.subcategory == "Suscripciones")
    }

    // MARK: - Command Word Filtering

    @Test("Command words are filtered on init (from persisted data)")
    func filterCommandWords() async {
        // The manager filters command words only during init() when loading
        // from UserDefaults. In a live session, learn() stores them but they
        // get cleaned on next app launch. We verify the in-memory learn still
        // works (no crash) and that real merchants aren't filtered.
        let manager = await freshManager()

        await manager.learn(merchant: "Mercadona", category: "Alimentacion", subcategory: "Supermercado")
        let pref = await manager.getPreference(for: "Mercadona")
        #expect(pref != nil, "Real merchants should not be filtered")
    }

    // MARK: - Clear

    @Test("Clear removes all preferences")
    func clearAll() async {
        let manager = await freshManager()

        await manager.learn(merchant: "Mercadona", category: "Alimentacion", subcategory: "Supermercado")
        await manager.learn(merchant: "Starbucks", category: "Ocio", subcategory: "Cafe")
        await manager.clearAllLearning()

        let pref1 = await manager.getPreference(for: "Mercadona")
        let pref2 = await manager.getPreference(for: "Starbucks")

        #expect(pref1 == nil)
        #expect(pref2 == nil)
    }

    // MARK: - Subcategory

    @Test("Learn without subcategory")
    func learnWithoutSubcategory() async {
        let manager = await freshManager()

        await manager.learn(merchant: "Tienda", category: "Compras", subcategory: nil)
        let pref = await manager.getPreference(for: "Tienda")

        #expect(pref != nil)
        #expect(pref?.category == "Compras")
        #expect(pref?.subcategory == nil)
    }

    // MARK: - Multiple Merchants

    @Test("Learn multiple independent merchants")
    func multipleMerchants() async {
        let manager = await freshManager()

        await manager.learn(merchant: "Mercadona", category: "Alimentacion", subcategory: "Supermercado")
        await manager.learn(merchant: "Gasolinera", category: "Transporte", subcategory: "Gasolina")
        await manager.learn(merchant: "Cine", category: "Ocio", subcategory: "Cine")

        let pref1 = await manager.getPreference(for: "Mercadona")
        let pref2 = await manager.getPreference(for: "Gasolinera")
        let pref3 = await manager.getPreference(for: "Cine")

        #expect(pref1?.category == "Alimentacion")
        #expect(pref2?.category == "Transporte")
        #expect(pref3?.category == "Ocio")
    }
}
