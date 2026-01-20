// FilterPreset.swift
// Model and manager for saved filter presets

import Foundation
import SwiftUI

// MARK: - Filter Preset Model
struct FilterPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var filter: ExpenseFilter
    var icon: String
    var color: String // Hex color string
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, filter: ExpenseFilter, icon: String = "line.3.horizontal.decrease.circle", color: String = "#A78BFA") {
        self.id = id
        self.name = name
        self.filter = filter
        self.icon = icon
        self.color = color
        self.createdAt = Date()
    }
    
    var colorValue: Color {
        Color(hex: color) ?? .clarityPrimary
    }
}

// MARK: - Filter Preset Manager
@MainActor
@Observable
final class FilterPresetManager {
    static let shared = FilterPresetManager()
    
    private(set) var presets: [FilterPreset] = []
    private let storageKey = "clarity_filter_presets"
    
    private init() {
        loadPresets()
    }
    
    // MARK: - CRUD Operations
    
    func savePreset(_ preset: FilterPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        persistPresets()
    }
    
    func deletePreset(_ preset: FilterPreset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
    }
    
    func deletePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        persistPresets()
    }
    
    // MARK: - Persistence
    
    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            // Add default presets if none exist
            createDefaultPresets()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            presets = try decoder.decode([FilterPreset].self, from: data)
        } catch {
            print("Error loading filter presets: \(error)")
            createDefaultPresets()
        }
    }
    
    private func persistPresets() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(presets)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Error saving filter presets: \(error)")
        }
    }
    
    private func createDefaultPresets() {
        let defaults: [FilterPreset] = [
            FilterPreset(
                name: "Este mes",
                filter: ExpenseFilter(dateRange: .thisMonth),
                icon: "calendar",
                color: "#3B82F6"
            ),
            FilterPreset(
                name: "Mes pasado",
                filter: ExpenseFilter(dateRange: .lastMonth),
                icon: "calendar.badge.clock",
                color: "#8B5CF6"
            ),
            FilterPreset(
                name: "Solo tarjeta",
                filter: {
                    var f = ExpenseFilter()
                    f.selectedPaymentMethods = ["Tarjeta"]
                    return f
                }(),
                icon: "creditcard.fill",
                color: "#10B981"
            )
        ]
        presets = defaults
        persistPresets()
    }
}
