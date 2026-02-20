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
    @State private var showColorPicker = false

    var isValid: Bool {
        !name.isEmpty && !subcategories.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name with inline preview
                Section("Nombre") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: selectedColor) ?? .gray)
                            .frame(width: 44, height: 44)

                        TextField("Ej: Transporte, Salud, etc.", text: $name)
                            .font(.body)
                    }
                }

                // Color - compact button to open advanced picker
                Section("Color") {
                    Button {
                        showColorPicker = true
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: selectedColor) ?? .gray)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )

                            Text(selectedColor.uppercased())
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Subcategories
                Section {
                    ForEach(subcategories.indices, id: \.self) { index in
                        HStack {
                            Text(subcategories[index])
                            Spacer()
                        }
                    }
                    .onDelete { subcategories.remove(atOffsets: $0) }
                    .onMove { subcategories.move(fromOffsets: $0, toOffset: $1) }

                    if showAddSubcategory {
                        HStack {
                            TextField("Nombre de subcategoría", text: $newSubcategoryName)

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
                            }

                            Button {
                                showAddSubcategory = false
                                newSubcategoryName = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            withAnimation(.bouncy) {
                                showAddSubcategory = true
                            }
                        } label: {
                            Label("Añadir Subcategoría", systemImage: "plus.circle.fill")
                                .foregroundStyle(Color.clarityPrimary)
                        }
                    }
                } header: {
                    Text("Subcategorías")
                } footer: {
                    Text("Añade al menos una subcategoría")
                        .font(.caption2)
                }
            }
            .navigationTitle("Nueva Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
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
        .sheet(isPresented: $showColorPicker) {
            AdvancedColorPickerView(selectedColor: $selectedColor)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    AddCategoryView { category in
        print("Created: \(category.name)")
    }
}
