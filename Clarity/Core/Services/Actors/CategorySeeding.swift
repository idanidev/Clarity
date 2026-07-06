// CategorySeeding.swift
// Lógica PURA de siembra de categorías (sin Firestore).
//
// Extraída de UserDataService para poder testear el fix de pérdida de datos sin BBDD.
// Bug histórico (jun 2026): los defaults vivían SOLO en memoria; el primer write dot-path
// "categories.X" creaba el map en Firestore con UNA entrada → el resto de categorías
// desaparecía. El fix: sembrar el map COMPLETO si no existe, antes de cualquier add/update.
//
// Aquí viven las tres decisiones puras de ese fix:
//  - `shouldSeed`     : ¿el map persistido está ausente/vacío? (única condición para sembrar)
//  - `containsForbiddenChars` : ids con caracteres que Firestore prohíbe en field-paths
//  - `buildSeedMap`   : construye el map completo conservando ids seguros, UUID si no.
// El comportamiento es idéntico al previo de UserDataService.

import Foundation

// `nonisolated`: lógica pura sin estado. Se llama desde el actor UserDataService
// (aislamiento no-main); con @MainActor por defecto daría warnings de Swift 6.
nonisolated enum CategorySeeding {

    /// Caracteres prohibidos por Firestore en un id usado como segmento de field-path.
    static let forbiddenCharacters: Set<Character> = ["/", "~", "*", "[", "]"]

    /// Verifica si un string contiene caracteres prohibidos por Firestore.
    static func containsForbiddenChars(_ string: String) -> Bool {
        string.contains(where: { forbiddenCharacters.contains($0) })
    }

    /// Solo se siembran defaults si el map persistido está AUSENTE o VACÍO.
    /// Nunca se sobrescribe un map con entradas (eso causaría la pérdida de datos).
    static func shouldSeed(existingMap: [String: [String: Any]]?) -> Bool {
        existingMap == nil || existingMap?.isEmpty == true
    }

    /// Construye el map `categories` completo a partir de las categorías dadas.
    /// Conserva el id propio si es seguro (así un update posterior por ese id actualiza
    /// la entrada en vez de duplicarla); si el id falta o tiene caracteres prohibidos,
    /// asigna un UUID. Los defaults usan su rawValue como id (sin caracteres prohibidos).
    static func buildSeedMap(from categories: [Category]) -> [String: [String: Any]] {
        var map: [String: [String: Any]] = [:]
        for c in categories {
            let key: String
            if let id = c.id, !id.isEmpty, !containsForbiddenChars(id) {
                key = id
            } else {
                key = UUID().uuidString
            }
            map[key] = [
                "name": c.name,
                "color": c.color,
                "subcategories": c.subcategories,
            ]
        }
        return map
    }
}
