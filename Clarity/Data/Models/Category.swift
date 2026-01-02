// Category.swift
// Category data model

import Foundation
import FirebaseFirestore
import SwiftUI

struct Category: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let name: String
    let color: String // Hex color
    let subcategories: [String]
    let order: Int
    let createdAt: Date?
    let updatedAt: Date?
    
    var uiColor: Color {
        Color(hex: color) ?? .gray
    }
}

// MARK: - Default Categories
enum DefaultCategory: String, CaseIterable {
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
    
    var defaultSubcategories: [String] {
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
    
    var defaultColor: String {
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
    
    var color: Color {
        Color(hex: defaultColor) ?? .gray
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
    
    var icon: String {
        switch self {
        case .efectivo: return "banknote"
        case .tarjeta: return "creditcard"
        case .tarjetaCredito: return "creditcard"
        case .tarjetaDebito: return "creditcard.fill"
        case .transferencia: return "arrow.left.arrow.right"
        case .paypal: return "p.circle"
        case .bizum: return "b.circle"
        case .applePay: return "apple.logo"
        case .googlePay: return "g.circle"
        case .otro: return "ellipsis.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .efectivo: return .green
        case .tarjeta: return .purple
        case .tarjetaCredito: return .purple
        case .tarjetaDebito: return .indigo
        case .transferencia: return .blue
        case .paypal: return .yellow
        case .bizum: return .cyan
        case .applePay: return .gray
        case .googlePay: return .red
        case .otro: return .secondary
        }
    }
}
