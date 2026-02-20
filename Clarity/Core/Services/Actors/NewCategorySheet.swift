// NewCategorySheet.swift
// Quick sheet to create a new category from expense creation flow

import SwiftUI

struct NewCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedColor: String = CategoryColors.allCases[0]
    @State private var subcategories: [String] = []
    @State private var showAddSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var isSaving = false
    
    // Validación de caracteres prohibidos
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
    
    var body: some View {
        NavigationStack {
            Form {
                // Name with preview
                Section {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: selectedColor) ?? .gray)
                            .frame(width: 44, height: 44)
                        
                        TextField("Ej: Deportes, Mascotas, etc.", text: $name)
                            .font(.body)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Nombre de la Categoría")
                } footer: {
                    if nameContainsForbiddenChars {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No puedes usar estos caracteres:")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.orange)
                                
                                Text(forbiddenCharsInName.map { String($0) }.joined(separator: " "))
                                    .font(.caption.monospaced().weight(.bold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                                
                                Text("Caracteres prohibidos: / ~ * [ ]")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Color Picker
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(CategoryColors.allCases, id: \.self) { colorHex in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedColor = colorHex
                                }
                                HapticManager.shared.selection()
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
                    ForEach(subcategories, id: \.self) { subcategory in
                        HStack {
                            Capsule()
                                .fill(Color(hex: selectedColor)?.opacity(0.8) ?? .gray.opacity(0.8))
                                .frame(width: 4, height: 16)
                            Text(subcategory)
                        }
                    }
                    .onDelete { indexSet in
                        withAnimation(.bouncy) {
                            subcategories.remove(atOffsets: indexSet)
                            HapticManager.shared.notification(.warning)
                        }
                    }
                    
                    // Add subcategory inline
                    if showAddSubcategory {
                        HStack {
                            TextField("Nombre de la subcategoría", text: $newSubcategoryName)
                                .font(.body)
                            
                            Button {
                                guard !newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                withAnimation(.bouncy) {
                                    subcategories.append(newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines))
                                    newSubcategoryName = ""
                                    showAddSubcategory = false
                                    HapticManager.shared.impact(.light)
                                }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                            }
                            .disabled(newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
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
                    Text("Las subcategorías te ayudan a organizar mejor tus gastos. Debes añadir al menos una.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Nueva Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task {
                            await createCategory()
                        }
                    }
                    .disabled(!isValidName || subcategories.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func createCategory() async {
        guard isValidName, !subcategories.isEmpty else {
            return
        }
        
        isSaving = true
        
        let newCategory = Category(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            color: selectedColor,
            subcategories: subcategories,
            order: UserDataManager.shared.categories.count, // Put at the end
            createdAt: Date(),
            updatedAt: Date()
        )
        
        await UserDataManager.shared.addCategory(newCategory)
        
        HapticManager.shared.notification(.success)
        dismiss()
        isSaving = false
    }
}

#Preview {
    NewCategorySheet()
}
