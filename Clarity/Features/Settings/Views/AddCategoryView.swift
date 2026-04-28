// AddCategoryView.swift
// Form to create a new category

import SwiftUI

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Category) -> Void

    @State private var name = ""
    @State private var selectedColor = CategoryColors.indigo
    @State private var subcategories: [String] = []
    @State private var showAddSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var editingSubcategoryIndex: Int?

    private let forbiddenChars: [Character] = ["/", "~", "*", "[", "]"]

    private var nameContainsForbiddenChars: Bool {
        name.contains(where: { forbiddenChars.contains($0) })
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !nameContainsForbiddenChars
            && !subcategories.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name with inline color preview
                Section {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: selectedColor))
                            .frame(width: 44, height: 44)

                        TextField(String(localized: "addCategory.namePlaceholder", defaultValue: "Ej: Transporte, Salud, etc."), text: $name)
                            .font(.body)
                            .autocorrectionDisabled()
                            .onChange(of: name) { _, newValue in
                                let filtered = newValue.filter { !forbiddenChars.contains($0) }
                                if filtered != newValue { name = filtered }
                            }
                    }
                } header: {
                    Text(String(localized: "categoryDetail.name.header", defaultValue: "Nombre"))
                } footer: {
                    if nameContainsForbiddenChars {
                        Label(String(localized: "addCategory.forbiddenChars", defaultValue: "No puedes usar: / ~ * [ ]"), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Color — horizontal scroll picker
                Section(String(localized: "categoryDetail.color.header", defaultValue: "Color")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CategoryColors.allCases, id: \.self) { colorHex in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedColor = colorHex
                                    }
                                    HapticManager.shared.selection()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if selectedColor == colorHex {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .scaleEffect(selectedColor == colorHex ? 1.15 : 1.0)
                                        .animation(
                                            .spring(response: 0.3, dampingFraction: 0.7),
                                            value: selectedColor == colorHex
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                }

                // Subcategories — inline editing, same pattern as CategoryDetailView
                Section(String(localized: "categoryDetail.subcategories.header", defaultValue: "Subcategorías")) {
                    ForEach(subcategories.indices, id: \.self) { index in
                        if editingSubcategoryIndex == index {
                            HStack {
                                TextField("Nombre", text: $subcategories[index])
                                    .font(.body)

                                Button {
                                    withAnimation(.bouncy) {
                                        editingSubcategoryIndex = nil
                                        HapticManager.shared.impact(.light)
                                    }
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title3)
                                }
                            }
                        } else {
                            Button {
                                withAnimation(.bouncy) {
                                    editingSubcategoryIndex = index
                                }
                            } label: {
                                Text(subcategories[index])
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .onDelete { subcategories.remove(atOffsets: $0) }
                    .onMove { subcategories.move(fromOffsets: $0, toOffset: $1) }

                    if showAddSubcategory {
                        HStack {
                            TextField(String(localized: "categoryDetail.newSubcategory", defaultValue: "Nueva subcategoría"), text: $newSubcategoryName)

                            Button {
                                guard !newSubcategoryName.isEmpty else { return }
                                withAnimation(.bouncy) {
                                    subcategories.append(newSubcategoryName)
                                    newSubcategoryName = ""
                                    showAddSubcategory = false
                                    HapticManager.shared.impact(.light)
                                }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                            }
                            .disabled(newSubcategoryName.isEmpty)

                            Button {
                                withAnimation(.bouncy) {
                                    showAddSubcategory = false
                                    newSubcategoryName = ""
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.title3)
                            }
                        }
                    } else {
                        Button {
                            withAnimation(.bouncy) {
                                showAddSubcategory = true
                            }
                        } label: {
                            Label(String(localized: "categoryDetail.addSubcategory", defaultValue: "Añadir Subcategoría"), systemImage: "plus.circle.fill")
                                .foregroundStyle(Color.clarityPrimary)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "addCategory.navigationTitle", defaultValue: "Nueva Categoría"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancelar")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "addCategory.createButton", defaultValue: "Crear")) {
                        let category = Category(
                            name: name,
                            color: selectedColor,
                            subcategories: subcategories,
                            order: 0,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        onSave(category)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    AddCategoryView { _ in }
}
