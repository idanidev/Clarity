// RepositoryError.swift
// Domain errors for repository operations

import Foundation

enum RepositoryError: LocalizedError {
    case notAuthenticated
    case notFound
    case permissionDenied
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No hay un usuario autenticado."
        case .notFound:
            return "El recurso no fue encontrado."
        case .permissionDenied:
            return "No tienes permisos para realizar esta acción."
        case .unknown(let error):
            return "Error desconocido: \(error.localizedDescription)"
        }
    }
}
