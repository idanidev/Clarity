// Extensions.swift
// Useful Swift extensions

import Foundation
import SwiftUI

// MARK: - App Notifications
extension Notification.Name {
    /// Posted whenever an expense is added, edited, or deleted.
    static let expenseDidChange = Notification.Name("expenseDidChange")
}

// MARK: - Error Security Extensions
extension Error {
    /// Devuelve un mensaje seguro para mostrar al usuario.
    /// Nunca expone detalles internos, stack traces ni mensajes del servidor.
    var safeUserMessage: String {
        if let appError = self as? AppError {
            return appError.errorDescription ?? "Ha ocurrido un error"
        }
        return "Ha ocurrido un error inesperado. Inténtalo de nuevo."
    }

    /// Detecta si el error es una cancelación legítima (no debe mostrarse al usuario).
    var isCancellation: Bool {
        self is CancellationError
            || (self as? URLError)?.code == .cancelled
            || (self as? URLError)?.code == .timedOut
    }
}

// MARK: - Date Extensions
extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }
    
    var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
    }
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: self)
    }
    
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: self)
    }
    
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Double Extensions
extension Double {

    
    var compactCurrencyString: String {
        if self >= 1000 {
            return String(format: "€%.1fk", self / 1000)
        }
        return String(format: "€%.0f", self)
    }
}

// MARK: - String Extensions
extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: self)
    }
}

// MARK: - View Extensions
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

/// Applies `.toolbarBackgroundVisibility(_:for:)` only on iOS 18+; no-op on iOS 17.
struct ToolbarVisibilityModifier: ViewModifier {
    let visibility: Visibility

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarBackgroundVisibility(visibility, for: .navigationBar)
        } else {
            content
        }
    }
}

// MARK: - Array Extensions
extension Array where Element: Identifiable {
    mutating func update(_ element: Element) {
        if let index = firstIndex(where: { $0.id == element.id }) {
            self[index] = element
        }
    }
    
    mutating func remove(_ element: Element) {
        removeAll { $0.id == element.id }
    }
}


