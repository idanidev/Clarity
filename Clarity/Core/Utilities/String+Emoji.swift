// String+Emoji.swift
// Los nombres de categoría llevan el emoji dentro ("Compras🛍️"): es el id que
// se guarda en Firestore. Donde el emoji ya va en su círculo, el nombre se
// enseña limpio para no verlo dos veces.

import Foundation

extension String {
    /// El texto sin emojis ni los espacios que dejan al irse.
    var nombreSinEmoji: String {
        unicodeScalars
            .filter { !$0.properties.isEmojiPresentation && !($0.properties.isEmoji && $0.value > 0x238C) }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    /// Solo los emojis del texto. Para el círculo cuando el emoji viene dentro
    /// del nombre y no en su campo.
    var soloEmoji: String {
        unicodeScalars
            .filter { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C) }
            .map(String.init)
            .joined()
    }
}
