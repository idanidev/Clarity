// CategoriesManagementView.swift
// CRUD completo de categorías del usuario - Rediseño iOS-Native

import SwiftUI

struct CategoriesManagementView: View {
    private var userDataManager = UserDataManager.shared
    @State private var showAddCategory = false
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: Category?

    var body: some View {
        List {
            Section {
                ForEach(userDataManager.categories, id: \.name) { category in
                    NavigationLink {
                        CategoryDetailView(category: category) {
                            Task {
                                await userDataManager.refreshCategories()
                            }
                        }
                    } label: {
                        CategoryRow(
                            category: category,
                            colorBinding: colorBinding(for: category)
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .onDelete(perform: deleteCategories)
                .onMove(perform: moveCategories)
            } header: {
                HStack {
                    Text("\(userDataManager.categories.count) categorías")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    Spacer()
                    let totalSubs = userDataManager.categories.reduce(0) { $0 + $1.subcategories.count }
                    Text("\(totalSubs) subcategorías")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            } footer: {
                Text("Mantén pulsado para reordenar. Desliza para eliminar.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "categories.navigationTitle", defaultValue: "Categorías"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView { newCategory in
                Task {
                    await userDataManager.addCategory(newCategory)
                    HapticManager.shared.notification(.success)
                }
            }
        }
        .alert(String(localized: "categories.delete.title", defaultValue: "Eliminar Categoría"), isPresented: $showDeleteAlert) {
            Button(String(localized: "common.cancel", defaultValue: "Cancelar"), role: .cancel) {}
            Button(String(localized: "common.delete", defaultValue: "Eliminar"), role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text(String(localized: "categories.delete.message", defaultValue: "Esta acción no se puede deshacer. Los gastos existentes mantendrán esta categoría."))
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        categoryToDelete = userDataManager.categories[index]
        showDeleteAlert = true
    }

    private func confirmDelete() {
        guard let category = categoryToDelete, let id = category.id else { return }

        Task {
            await userDataManager.deleteCategory(id: id)
            HapticManager.shared.notification(.success)
        }
        categoryToDelete = nil
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        // Local reorder only for now - Firebase persist on save
        HapticManager.shared.impact(.light)
    }

    /// Binding<Color> que persiste el cambio de color a la categoría en Firestore.
    private func colorBinding(for category: Category) -> Binding<Color> {
        Binding(
            get: { Color(hex: category.color) },
            set: { newColor in
                var updated = category
                updated.color = newColor.hexString
                updated.updatedAt = Date()
                Task {
                    await userDataManager.updateCategory(updated)
                    HapticManager.shared.selection()
                }
            }
        )
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: Category
    @Binding var colorBinding: Color

    /// Separa emoji(s) embebidos al final del nombre.
    /// Camina por character-clusters desde el final, recogiendo todos los emoji.
    private var parsed: (name: String, emoji: String?) {
        let trimmed = category.name.trimmingCharacters(in: .whitespaces)
        var nameChars = Array(trimmed)
        var emojiChars: [Character] = []
        while let last = nameChars.last, last.isEmojiCluster {
            emojiChars.insert(last, at: 0)
            nameChars.removeLast()
        }
        let cleanName = String(nameChars).trimmingCharacters(in: .whitespaces)
        let emoji = emojiChars.isEmpty ? nil : String(emojiChars)
        return (cleanName.isEmpty ? trimmed : cleanName, emoji)
    }

    private var color: Color { Color(hex: category.color) }

    var body: some View {
        HStack(spacing: 14) {
            // Tile con color + emoji
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.18))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(color.opacity(0.4), lineWidth: 1)
                if let emoji = parsed.emoji {
                    // Solo el PRIMER emoji-cluster: si la categoría tenía varios
                    // (ej. "Coche-Moto🚗🏍️"), evita overflow + "..." en el tile 44pt.
                    Text(String(emoji.first.map(String.init) ?? emoji))
                        .font(.system(size: 22))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                } else {
                    // Fallback consistente: inicial del nombre en color de la categoría
                    Text(parsed.name.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(parsed.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    Text("\(category.subcategories.count) \(category.subcategories.count == 1 ? "subcategoría" : "subcategorías")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            // Native ColorPicker — anillo arcoíris al tocar abre selector iOS
            ColorPicker("", selection: $colorBinding, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.1)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Emoji detection

private extension Character {
    /// True si el cluster de caracteres es un emoji presentable (incluye VS16, ZWJ sequences, modifiers).
    var isEmojiCluster: Bool {
        guard let first = unicodeScalars.first else { return false }
        // Emoji presentation por defecto, o emoji + variation selector U+FE0F, o secuencias ZWJ
        if first.properties.isEmojiPresentation { return true }
        if unicodeScalars.contains(where: { $0.value == 0xFE0F }) { return true }
        if unicodeScalars.count > 1 && first.properties.isEmoji { return true }
        return false
    }
}

#Preview {
    NavigationStack {
        CategoriesManagementView()
    }
}
