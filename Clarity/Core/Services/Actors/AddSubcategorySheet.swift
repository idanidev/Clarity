// AddSubcategorySheet.swift
// Sheet para añadir una nueva subcategoría a una categoría existente

import SwiftUI

struct AddSubcategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let category: Category
    let onSuccess: () -> Void
    
    @State private var subcategoryName = ""
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Capsule()
                            .fill(category.uiColor.opacity(0.8))
                            .frame(width: 4, height: 36)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.name)
                                .font(.headline)
                                .foregroundStyle(category.uiColor)
                            Text("Nueva subcategoría")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Categoría")
                }
                
                Section {
                    TextField("Nombre de la subcategoría", text: $subcategoryName)
                        .font(.body)
                        .autocorrectionDisabled()
                } header: {
                    Text("Nombre")
                } footer: {
                    Text("La nueva subcategoría se añadirá a '\(category.name)'")
                        .font(.caption)
                }
                
                // Subcategorías existentes
                Section {
                    ForEach(category.subcategories, id: \.self) { subcategory in
                        HStack {
                            Capsule()
                                .fill(category.uiColor.opacity(0.3))
                                .frame(width: 4, height: 16)
                            Text(subcategory)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Subcategorías existentes")
                }
            }
            .navigationTitle("Nueva Subcategoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") {
                        Task {
                            await addSubcategory()
                        }
                    }
                    .disabled(subcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addSubcategory() async {
        let trimmedName = subcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Verificar si ya existe
        if category.subcategories.contains(trimmedName) {
            errorMessage = "Esta subcategoría ya existe en '\(category.name)'"
            showError = true
            return
        }
        
        isAdding = true
        
        guard let categoryId = category.id else {
            errorMessage = "Error: Categoría sin ID"
            showError = true
            isAdding = false
            return
        }
        
        await UserDataManager.shared.addSubcategory(trimmedName, toCategoryId: categoryId)
        
        // Verificar si hubo error
        if let error = UserDataManager.shared.error {
            errorMessage = error
            showError = true
            isAdding = false
            return
        }
        
        HapticManager.shared.notification(.success)
        onSuccess()
        dismiss()
        isAdding = false
    }
}

#Preview {
    AddSubcategorySheet(
        category: Category(
            id: "transporte",
            name: "Transporte 🚗",
            color: "#3B82F6",
            subcategories: ["Gasolina", "Parking", "Taxi"],
            order: 0,
            createdAt: Date(),
            updatedAt: Date()
        ),
        onSuccess: {}
    )
}
