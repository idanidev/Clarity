// EmojiPickerView.swift
// Emoji picker with search for recurring expenses

import SwiftUI

struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String
    @State private var searchText = ""
    
    // Common expense-related emojis organized by category
    private let emojiCategories: [(name: String, emojis: [String])] = [
        ("Frecuentes", ["💰", "💳", "🏠", "🚗", "📱", "💡", "🍕", "🛒", "✈️", "🎬"]),
        ("Hogar", ["🏠", "🏡", "🔑", "🛋️", "🛏️", "🚿", "🧹", "💡", "🔌", "📺"]),
        ("Transporte", ["🚗", "🚕", "🚌", "🚇", "✈️", "⛽", "🅿️", "🚲", "🛵", "🚁"]),
        ("Comida", ["🍕", "🍔", "🍜", "🥗", "☕", "🍺", "🛒", "🥖", "🍣", "🌮"]),
        ("Entretenimiento", ["🎬", "🎮", "🎵", "📺", "🎭", "🎪", "🎯", "🎲", "🎨", "📚"]),
        ("Tecnología", ["📱", "💻", "🖥️", "⌚", "🎧", "📷", "🔋", "💾", "🖨️", "📡"]),
        ("Salud", ["💊", "🏥", "🩺", "💉", "🧘", "🏋️", "🦷", "👁️", "🩹", "💆"]),
        ("Finanzas", ["💰", "💳", "🏦", "💵", "💶", "📈", "📊", "🧾", "💸", "🪙"]),
        ("Educación", ["📚", "🎓", "✏️", "📝", "🎒", "🔬", "🌐", "🤖", "📖", "🧮"]),
        ("Mascotas", ["🐕", "🐈", "🐠", "🐦", "🦮", "🐾", "🦴", "🐇", "🐹", "🐢"]),
        ("Servicios", ["📧", "📦", "🧾", "📋", "🔧", "🪠", "🧰", "🚚", "📬", "🏪"]),
        ("Otros", ["⭐", "❤️", "🎁", "🎉", "🔔", "⚡", "🌟", "💎", "🏆", "🎯"])
    ]
    
    private var filteredCategories: [(name: String, emojis: [String])] {
        if searchText.isEmpty {
            return emojiCategories
        }
        // Filter by emoji char (for copy/paste search)
        return emojiCategories.compactMap { category in
            let filtered = category.emojis.filter { $0.contains(searchText) }
            return filtered.isEmpty ? nil : (category.name, filtered)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(filteredCategories, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.name)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                                ForEach(category.emojis, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                        HapticManager.shared.impact(.light)
                                        dismiss()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .frame(width: 50, height: 50)
                                            .background(
                                                selectedEmoji == emoji ?
                                                Color.clarityPrimary.opacity(0.2) :
                                                Color.clear
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .searchable(text: $searchText, prompt: "Buscar emoji")
            .navigationTitle("Seleccionar Icono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    EmojiPickerView(selectedEmoji: .constant("💰"))
}
