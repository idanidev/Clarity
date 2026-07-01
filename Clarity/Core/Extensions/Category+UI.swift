import SwiftUI

// MARK: - String: separar nombre limpio + primer emoji
extension String {
    /// Categorías guardan el emoji embebido al final del nombre
    /// (ej. "Coche-Moto🏎️🏍️"). Devuelve (nombre limpio, primer emoji).
    var categoryNameEmoji: (name: String, emoji: String?) {
        let trimmed = trimmingCharacters(in: .whitespaces)
        var emojiChars: [Character] = []
        var idx = trimmed.endIndex
        while idx > trimmed.startIndex {
            let prev = trimmed.index(before: idx)
            let ch = trimmed[prev]
            if ch.unicodeScalars.contains(where: { $0.properties.isEmoji && $0.value > 0x238C }) {
                emojiChars.insert(ch, at: 0)
                idx = prev
            } else if ch == " " && !emojiChars.isEmpty {
                idx = prev
            } else {
                break
            }
        }
        let cleanName = String(trimmed[trimmed.startIndex..<idx])
            .trimmingCharacters(in: .whitespaces)
        let firstEmoji = emojiChars.first.map(String.init)
        return (cleanName.isEmpty ? trimmed : cleanName, firstEmoji)
    }
}

// MARK: - Category UI Extensions
extension Category {
    var uiColor: Color {
        Color(hex: color)
    }
}

// MARK: - DefaultCategory UI Extensions
extension DefaultCategory {
    var color: Color {
        Color(hex: defaultColor)
    }
}

// MARK: - PaymentMethod UI Extensions
extension PaymentMethod {
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
