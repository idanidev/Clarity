// CategoryDetailView.swift
// Edición de categoría: nombre + subcategorías inline. El color se gestiona en la lista.

import SwiftUI

struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let originalCategory: Category
    let onUpdate: () -> Void

    @State private var name: String
    @State private var subcategories: [String]
    @State private var newSubcategoryName = ""
    @FocusState private var addFieldFocused: Bool
    @State private var showDeleteConfirm = false
    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var showNameChangeWarning = false

    // Caracteres prohibidos por Firestore en el path del documento
    private let forbiddenChars: [Character] = ["/", "~", "*", "[", "]"]

    private var nameContainsForbiddenChars: Bool {
        name.contains(where: { forbiddenChars.contains($0) })
    }

    private var forbiddenCharsInName: [Character] {
        name.filter { forbiddenChars.contains($0) }
    }

    private var isValidName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !nameContainsForbiddenChars
    }

    private var nameHasChanged: Bool {
        name != originalCategory.name
    }

    private var color: Color { Color(hex: originalCategory.color) }

    init(category: Category, onUpdate: @escaping () -> Void) {
        self.originalCategory = category
        self.onUpdate = onUpdate
        _name = State(initialValue: category.name)
        _subcategories = State(initialValue: category.subcategories)
    }

    var body: some View {
        Form {
            // ── Nombre ──
            Section {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(color.opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)

                    TextField(
                        String(localized: "categoryDetail.namePlaceholder", defaultValue: "Nombre"),
                        text: $name
                    )
                    .font(.body)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onChange(of: name) { _, newValue in
                        let filtered = newValue.filter { !forbiddenChars.contains($0) }
                        if filtered != newValue { name = filtered }
                        hasChanges = true
                    }
                }
            } footer: {
                if nameContainsForbiddenChars {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Caracteres no permitidos: \(forbiddenCharsInName.map { String($0) }.joined(separator: " "))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else if nameHasChanged {
                    Text(String(localized: "categoryDetail.nameChanged.info", defaultValue: "Los gastos existentes se actualizarán al nuevo nombre."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Subcategorías ──
            Section {
                if subcategories.isEmpty {
                    Text("Sin subcategorías. Añade la primera abajo ↓")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(subcategories.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(color)
                                .frame(width: 7, height: 7)

                            TextField("Nombre", text: $subcategories[index])
                                .font(.body)
                                .submitLabel(.done)
                                .onChange(of: subcategories[index]) { _, _ in
                                    hasChanges = true
                                }
                        }
                    }
                    .onDelete { indexSet in
                        withAnimation(.bouncy) {
                            subcategories.remove(atOffsets: indexSet)
                            hasChanges = true
                            HapticManager.shared.notification(.warning)
                        }
                    }
                    .onMove { from, to in
                        withAnimation(.bouncy) {
                            subcategories.move(fromOffsets: from, toOffset: to)
                            hasChanges = true
                        }
                    }
                }

                // Inline add: TextField siempre visible, submit Return añade y mantiene foco.
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.clarityPrimary)
                        .font(.title3)

                    TextField(
                        String(localized: "categoryDetail.addSubcategory", defaultValue: "Añadir subcategoría"),
                        text: $newSubcategoryName
                    )
                    .font(.body)
                    .submitLabel(.done)
                    .focused($addFieldFocused)
                    .onSubmit { addSubcategory() }

                    if !newSubcategoryName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            addSubcategory()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(Color.clarityPrimary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.bouncy, value: newSubcategoryName.isEmpty)
            } header: {
                HStack {
                    Text(String(localized: "categoryDetail.subcategories.header", defaultValue: "Subcategorías"))
                    Spacer()
                    Text("\(subcategories.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                if !subcategories.isEmpty {
                    Text("Desliza para eliminar. Pulsa Editar para reordenar.")
                        .font(.caption2)
                }
            }

            // ── Eliminar ──
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(
                        String(localized: "categoryDetail.deleteCategory", defaultValue: "Eliminar Categoría"),
                        systemImage: "trash"
                    )
                    .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(String(localized: "categoryDetail.deleteCategory.footer", defaultValue: "Los gastos existentes mantendrán esta categoría."))
                    .font(.caption2)
            }
        }
        .navigationTitle(String(localized: "categoryDetail.navigationTitle", defaultValue: "Editar Categoría"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel", defaultValue: "Cancelar")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save", defaultValue: "Guardar")) {
                    if nameHasChanged {
                        showNameChangeWarning = true
                    } else {
                        Task { await saveChanges() }
                    }
                }
                .disabled(!hasChanges || !isValidName || isSaving)
                .fontWeight(.semibold)
            }
            // Reordenar subcategorías
            ToolbarItem(placement: .topBarTrailing) {
                if !subcategories.isEmpty {
                    EditButton()
                }
            }
            // Toolbar teclado: cerrar
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    addFieldFocused = false
                }
                .fontWeight(.semibold)
            }
        }
        .confirmationDialog(
            "¿Eliminar \"\(originalCategory.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete", defaultValue: "Eliminar"), role: .destructive) {
                Task { await deleteCategory() }
            }
        } message: {
            Text(String(localized: "categoryDetail.deleteConfirm.message", defaultValue: "Esta acción no se puede deshacer."))
        }
        .alert(
            String(localized: "categoryDetail.nameChange.title", defaultValue: "Cambio de nombre"),
            isPresented: $showNameChangeWarning
        ) {
            Button(String(localized: "common.cancel", defaultValue: "Cancelar"), role: .cancel) {}
            Button(String(localized: "categoryDetail.nameChange.save", defaultValue: "Guardar cambios")) {
                Task { await saveChanges() }
            }
        } message: {
            Text("Al cambiar '\(originalCategory.name)' a '\(name)', los gastos existentes adoptarán el nuevo nombre.")
        }
    }

    // MARK: - Actions

    private func addSubcategory() {
        let trimmed = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !subcategories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            HapticManager.shared.notification(.warning)
            return
        }
        withAnimation(.bouncy) {
            subcategories.append(trimmed)
            newSubcategoryName = ""
            hasChanges = true
        }
        HapticManager.shared.impact(.light)
        addFieldFocused = true
    }

    private func saveChanges() async {
        isSaving = true
        var updated = originalCategory
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.subcategories = subcategories.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        updated.updatedAt = Date()
        await UserDataManager.shared.updateCategory(updated)
        HapticManager.shared.notification(.success)
        onUpdate()
        dismiss()
        isSaving = false
    }

    private func deleteCategory() async {
        guard let id = originalCategory.id else { return }
        await UserDataManager.shared.deleteCategory(id: id)
        HapticManager.shared.notification(.success)
        onUpdate()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(
            category: Category(
                name: "Transporte 🚎",
                color: "#3B82F6",
                subcategories: ["Gasolina", "Transporte público", "Taxi"],
                order: 0,
                createdAt: Date(),
                updatedAt: Date()
            ),
            onUpdate: {}
        )
    }
}
