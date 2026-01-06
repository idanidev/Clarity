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
                // Preview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Circle()
                                .fill(Color(hex: selectedColor) ?? .gray)
                                .frame(width: 100, height: 100)
                                .shadow(color: (Color(hex: selectedColor) ?? .gray).opacity(0.3), radius: 20)
                            
                            Text(name.isEmpty ? "Nueva Categoría" : name)
                                .font(.title2.bold())
                            
                            Text("\(subcategories.count) subcategoría\(subcategories.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                
                // Name
                Section("Nombre") {
                    TextField("Ej: Transporte, Salud, etc.", text: $name)
                        .font(.body)
                }
                
                // Color
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(CategoryColors.allCases, id: \.self) { colorHex in
                            Button {
                                withAnimation(.bouncy) {
                                    selectedColor = colorHex
                                }
                                HapticManager.selection()
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .gray)
                                    .frame(height: 50)
                                    .overlay {
                                        if selectedColor == colorHex {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                            Circle()
                                                .stroke(Color(hex: colorHex) ?? .gray, lineWidth: 6)
                                                .scaleEffect(1.2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
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
