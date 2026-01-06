// CategoryDetailView.swift
// Complete category editing view with inline subcategory editing

import SwiftUI

struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let originalCategory: Category
    let onUpdate: () -> Void
    
    @State private var name: String
    @State private var selectedColor: String
    @State private var subcategories: [String]
    @State private var showAddSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var editingSubcategoryIndex: Int?
    @State private var showDeleteConfirm = false
    @State private var hasChanges = false
    @State private var isSaving = false
    
    init(category: Category, onUpdate: @escaping () -> Void) {
        self.originalCategory = category
        self.onUpdate = onUpdate
        _name = State(initialValue: category.name)
        _selectedColor = State(initialValue: category.color)
        _subcategories = State(initialValue: category.subcategories)
    }
    
    var body: some View {
        Form {
            // Preview Section
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
                            .multilineTextAlignment(.center)
                        
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
                TextField("Nombre de la categoría", text: $name)
                    .font(.body)
                    .onChange(of: name) { _, _ in hasChanges = true }
            }
            
            // Color Picker
            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(CategoryColors.allCases, id: \.self) { colorHex in
                        Button {
                            withAnimation(.bouncy) {
                                selectedColor = colorHex
                                hasChanges = true
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
                    if editingSubcategoryIndex == index {
                        HStack {
                            TextField("Nombre", text: $subcategories[index])
                                .font(.body)
                            
                            Button {
                                withAnimation(.bouncy) {
                                    editingSubcategoryIndex = nil
                                    hasChanges = true
                                }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                            }
                        }
                    } else {
                        Button {
                            editingSubcategoryIndex = index
                        } label: {
                            HStack {
                                Text(subcategories[index])
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    withAnimation(.bouncy) {
                        subcategories.remove(atOffsets: indexSet)
                        hasChanges = true
                        HapticManager.notification(.warning)
                    }
                }
                .onMove { from, to in
                    withAnimation(.bouncy) {
                        subcategories.move(fromOffsets: from, toOffset: to)
                        hasChanges = true
                    }
                }
                
                // Add subcategory
                if showAddSubcategory {
                    HStack {
                        TextField("Nueva subcategoría", text: $newSubcategoryName)
                            .font(.body)
                        
                        Button {
                            guard !newSubcategoryName.isEmpty else { return }
                            withAnimation(.bouncy) {
                                subcategories.append(newSubcategoryName)
                                newSubcategoryName = ""
                                showAddSubcategory = false
                                hasChanges = true
                                HapticManager.impact(.light)
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
                        Label("Añadir Subcategoría", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.clarityPrimary)
                    }
                }
            } header: {
                Text("Subcategorías")
            } footer: {
                if !subcategories.isEmpty {
                    Text("Toca para editar • Desliza para eliminar • Arrastra para reordenar")
                        .font(.caption2)
                }
            }
            
            // Delete
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Eliminar Categoría", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Los gastos existentes mantendrán esta categoría.")
                    .font(.caption2)
            }
        }
        .navigationTitle("Editar Categoría")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task {
                        await saveChanges()
                    }
                }
                .disabled(!hasChanges || name.isEmpty || isSaving)
                .fontWeight(.semibold)
            }
        }
        .confirmationDialog(
            "¿Eliminar \"\(originalCategory.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task {
                    await deleteCategory()
                }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    private func saveChanges() async {
        isSaving = true
        
        var updated = originalCategory
        updated.name = name
        updated.color = selectedColor
        updated.subcategories = subcategories
        updated.updatedAt = Date()
        
        do {
            try await UserDataManager.shared.updateCategory(updated)
            HapticManager.notification(.success)
            onUpdate()
            dismiss()
        } catch {
            print("Error: \(error)")
            HapticManager.notification(.error)
            isSaving = false
        }
    }
    
    private func deleteCategory() async {
        guard let id = originalCategory.id else { return }
        
        do {
            try await UserDataManager.shared.deleteCategory(id: id)
            HapticManager.notification(.success)
            onUpdate()
            dismiss()
        } catch {
            print("Error: \(error)")
            HapticManager.notification(.error)
        }
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
