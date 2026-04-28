// InputValidator.swift
// Capa 1 de seguridad — validación y sanitización de todos los inputs de usuario.

import Foundation

enum InputValidator {

    // MARK: - Strings

    static func requireString(_ value: String?, field: String, maxLength: Int = 500) throws -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.validation("\(field) es obligatorio")
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= maxLength else {
            throw AppError.validation("\(field) no puede superar \(maxLength) caracteres")
        }
        return trimmed
    }

    static func optionalString(_ value: String?, maxLength: Int = 500) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(maxLength))
    }

    // MARK: - Email

    static func requireEmail(_ value: String?, field: String = "Email") throws -> String {
        let email = try requireString(value, field: field, maxLength: 254)
        let regex = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/
        guard email.wholeMatch(of: regex) != nil else {
            throw AppError.validation("Formato de email inválido")
        }
        return email.lowercased()
    }

    // MARK: - Numbers

    static func requireAmount(_ value: Double?, field: String = "Importe", max: Double = 999_999) throws -> Double {
        guard let value, value > 0 else {
            throw AppError.validation("\(field) debe ser mayor que 0")
        }
        guard value <= max else {
            throw AppError.validation("\(field) no puede superar \(max)€")
        }
        return value
    }

    // MARK: - Dates

    static func requireDateRange(start: Date, end: Date) throws {
        guard end > start else {
            throw AppError.validation("La fecha fin debe ser posterior a la fecha inicio")
        }
        let maxRange: TimeInterval = 10 * 365.25 * 24 * 3600
        guard end.timeIntervalSince(start) <= maxRange else {
            throw AppError.validation("El rango máximo es 10 años")
        }
    }

    // MARK: - Search sanitization

    /// Whitelist approach — solo permite alfanuméricos, espacios y acentos españoles.
    /// Previene inyecciones en queries de Firestore.
    static func sanitizeSearch(_ query: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸ"))
        return query.unicodeScalars
            .filter { allowed.contains($0) }
            .reduce(into: "") { $0.append(Character($1)) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - File validation (magic bytes, no MIME spoofing)

    enum FileType: String {
        case pdf, jpeg, png, heic
        var mimeType: String {
            switch self {
            case .pdf:  "application/pdf"
            case .jpeg: "image/jpeg"
            case .png:  "image/png"
            case .heic: "image/heic"
            }
        }
    }

    static func validateFile(data: Data, maxSizeMB: Int = 10) throws -> FileType {
        let maxBytes = maxSizeMB * 1_024 * 1_024
        guard data.count <= maxBytes else {
            throw AppError.validation("El archivo no puede superar \(maxSizeMB) MB")
        }
        guard data.count >= 12 else {
            throw AppError.validation("Archivo inválido")
        }
        let header = [UInt8](data.prefix(12))
        if header.starts(with: [0x25, 0x50, 0x44, 0x46]) { return .pdf }
        if header.starts(with: [0xFF, 0xD8, 0xFF])       { return .jpeg }
        if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return .png }
        let ftyp = Array(header[4..<12])
        if ftyp.starts(with: [0x66, 0x74, 0x79, 0x70])   { return .heic }
        throw AppError.validation("Tipo de archivo no permitido. Usa PDF, JPEG, PNG o HEIC")
    }
}
