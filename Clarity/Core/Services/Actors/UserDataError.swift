// UserDataError.swift
// Errores tipados del dominio de datos de usuario (categorías, subcategorías, filtros).
// Sustituye los NSError ad-hoc (domain "UserDataService" code 404/409) — la UI puede
// distinguir casos sin parsear strings y los mensajes viven en un solo sitio.

import Foundation

enum UserDataError: LocalizedError, Equatable {
    /// La categoría referenciada no existe en el map persistido.
    case categoryNotFound
    /// La subcategoría ya existe en esa categoría.
    case subcategoryAlreadyExists
    /// El filtro guardado no está en la lista local.
    case filterNotFound

    var errorDescription: String? {
        switch self {
        case .categoryNotFound: return "Categoría no encontrada"
        case .subcategoryAlreadyExists: return "Esta subcategoría ya existe"
        case .filterNotFound: return "Filtro no encontrado"
        }
    }
}
