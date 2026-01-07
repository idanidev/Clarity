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
                
                // Color - compact iOS style
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(CategoryColors.allCases, id: \.self) { colorHex in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedColor = colorHex
                                }
                                HapticManager.selection()
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .gray)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if selectedColor == colorHex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
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
                                    HapticManager.impact(.light)
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
    }
}

#Preview {
    AddCategoryView { category in
        print("Created: \(category.name)")
    }
}
