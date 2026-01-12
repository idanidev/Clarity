// AppError.swift
// Standardized error handling for Clarity

import Foundation

enum AppError: LocalizedError, Equatable {
    case dataLoadingFailed(String)
    case savingFailed(String)
    case deletionFailed(String)
    case networkError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .dataLoadingFailed(let reason):
            return "No se pudieron cargar los datos: \(reason)"
        case .savingFailed(let reason):
            return "Error al guardar: \(reason)"
        case .deletionFailed(let reason):
            return "Error al eliminar: \(reason)"
        case .networkError(let reason):
            return "Error de conexión: \(reason)"
        case .unknown(let reason):
            return "Ocurrió un error inesperado: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Comprueba tu conexión a internet e inténtalo de nuevo."
        default:
            return "Inténtalo de nuevo más tarde."
        }
    }
}
