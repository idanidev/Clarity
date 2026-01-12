// Category.swift
// Category data model - stored as embedded map in user document

import Foundation
import FirebaseFirestore


struct Category: Codable, Identifiable, Hashable {
    var id: String?  // For embedded map: id = category name
    var name: String
    var color: String // Hex color
    var subcategories: [String]
    var order: Int
    var createdAt: Date?
    var updatedAt: Date?
    

}

// MARK: - Default Categories
enum DefaultCategory: String, CaseIterable, Sendable {
    case alimentacion = "Alimentacion🫄"
    case ocio = "Ocio 🍻"
    case vivienda = "Vivienda🏡"
    case transporte = "Transporte🚎"
    case compras = "Compras 🛒"
    case salud = "Salud🏥"
    case suscripciones = "Suscripciones📺"
    case educacion = "Educacion📖"
    case viajes = "Viajes🗺️"
    case otros = "Otros📦"
    
    nonisolated var defaultSubcategories: [String] {
        switch self {
        case .alimentacion:
            return ["Supermercado", "Restaurantes", "Cafeterías", "Delivery"]
        case .ocio:
            return ["Cine", "Conciertos", "Bares", "Deportes"]
        case .vivienda:
            return ["Alquiler", "Hipoteca", "Luz", "Gas", "Agua", "Internet"]
        case .transporte:
            return ["Gasolina", "Transporte público", "Taxi", "Parking"]
        case .compras:
            return ["Ropa", "Electrónica", "Hogar", "Regalos"]
        case .salud:
            return ["Farmacia", "Médico", "Dentista", "Gimnasio"]
        case .suscripciones:
            return ["Netflix", "Spotify", "HBO", "Amazon Prime", "iCloud"]
        case .educacion:
            return ["Cursos", "Libros", "Material"]
        case .viajes:
            return ["Vuelos", "Hotel", "Actividades"]
        case .otros:
            return ["Varios"]
        }
    }
    
    nonisolated var defaultColor: String {
        switch self {
        case .alimentacion: return "#6366F1"
        case .ocio: return "#F59E0B"
        case .vivienda: return "#10B981"
        case .transporte: return "#3B82F6"
        case .compras: return "#EC4899"
        case .salud: return "#EF4444"
        case .suscripciones: return "#8B5CF6"
        case .educacion: return "#14B8A6"
        case .viajes: return "#F97316"
        case .otros: return "#6B7280"
        }
    }
    

}

// MARK: - Payment Methods
enum PaymentMethod: String, CaseIterable, Identifiable {
    case efectivo = "Efectivo"
    case tarjeta = "Tarjeta"
    case tarjetaCredito = "Tarjeta de Crédito"
    case tarjetaDebito = "Tarjeta de Débito"
    case transferencia = "Transferencia"
    case paypal = "PayPal"
    case bizum = "Bizum"
    case applePay = "Apple Pay"
    case googlePay = "Google Pay"
    case otro = "Otro"
    
    var id: String { rawValue }
    

}
