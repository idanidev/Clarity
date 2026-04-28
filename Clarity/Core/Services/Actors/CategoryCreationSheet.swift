// CategoryCreationSheet.swift
// Quick sheet to create a new category OR add subcategories to existing ones

import SwiftUI

struct CategoryCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Modo de creación
    enum CreationMode: String, CaseIterable, Identifiable {
        case newCategory = "Nueva Categoría"
        case addSubcategory = "Añadir Subcategorías"
        
        var id: String { rawValue }
    }
    
    @State private var mode: CreationMode = .newCategory
    
    // Para modo: Nueva Categoría
    @State private var name = ""
    @State private var selectedColor: String = CategoryColors.allCases[0]
    
    // Para modo: Añadir Subcategorías
    @State private var selectedExistingCategory: Category?
    @State private var showCategoryPicker = false
    
    // Compartido
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
    
    private var canSave: Bool {
        switch mode {
        case .newCategory:
            return isValidName && !subcategories.isEmpty
        case .addSubcategory:
            return selectedExistingCategory != nil && !subcategories.isEmpty
        }
    }
    
    private var existingCategories: [Category] {
        UserDataManager.shared.categories
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Selector de modo
                Section {
                    Picker("Modo", selection: $mode) {
                        ForEach(CreationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in
                        // Resetear campos al cambiar modo
                        subcategories = []
                        showAddSubcategory = false
                    }
                }
                
                // Contenido según modo
                if mode == .newCategory {
                    newCategorySection
                } else {
                    existingCategorySection
                }
                
                // Subcategorías (compartido)
                subcategoriesSection
            }
            .navigationTitle(mode == .newCategory ? "Nueva Categoría" : "Añadir Subcategorías")
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
                            await save()
                        }
                    }
                    .disabled(!canSave || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                categoryPickerSheet
            }
        }
    }
    
    // MARK: - Sections
    
    private var newCategorySection: some View {
        Group {
            // Name with preview
            Section {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: selectedColor))
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
                                .fill(Color(hex: colorHex))
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
        }
    }
    
    private var existingCategorySection: some View {
        Section {
            Button {
                showCategoryPicker = true
            } label: {
                HStack {
                    if let category = selectedExistingCategory {
                        Circle()
                            .fill(category.uiColor)
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .foregroundStyle(.primary)
                                .font(.body)
                            
                            Text("\(category.subcategories.count) subcategorías actuales")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        
                        Spacer()
                    } else {
                        Text("Seleccionar categoría")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Categoría")
        } footer: {
            Text("Selecciona la categoría a la que quieres añadir nuevas subcategorías")
                .font(.caption2)
        }
    }
    
    private var subcategoriesSection: some View {
        Section {
            ForEach(subcategories, id: \.self) { subcategory in
                HStack {
                    Capsule()
                        .fill(currentColor.opacity(0.8))
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
            Text(mode == .newCategory ? "Subcategorías" : "Nuevas Subcategorías")
        } footer: {
            if mode == .newCategory {
                Text("Las subcategorías te ayudan a organizar mejor tus gastos. Debes añadir al menos una.")
                    .font(.caption2)
            } else {
                Text("Añade nuevas subcategorías que se agregarán a la categoría seleccionada.")
                    .font(.caption2)
            }
        }
    }
    
    private var categoryPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(existingCategories) { category in
                    Button {
                        selectedExistingCategory = category
                        showCategoryPicker = false
                        HapticManager.shared.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(category.uiColor)
                                .frame(width: 40, height: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text("\(category.subcategories.count) subcategorías")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedExistingCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(category.uiColor)
                                    .font(.body.weight(.semibold))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Seleccionar Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        showCategoryPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var currentColor: Color {
        if mode == .newCategory {
            return Color(hex: selectedColor)
        } else {
            return selectedExistingCategory?.uiColor ?? .gray
        }
    }
    
    // MARK: - Actions
    
    private func save() async {
        guard canSave else { return }
        
        isSaving = true
        
        switch mode {
        case .newCategory:
            await createNewCategory()
        case .addSubcategory:
            await addSubcategoriesToExisting()
        }
        
        HapticManager.shared.notification(.success)
        dismiss()
        isSaving = false
    }
    
    private func createNewCategory() async {
        let newCategory = Category(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            color: selectedColor,
            subcategories: subcategories,
            order: UserDataManager.shared.categories.count,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        await UserDataManager.shared.addCategory(newCategory)
    }
    
    private func addSubcategoriesToExisting() async {
        guard var category = selectedExistingCategory else { return }
        
        // Combinar subcategorías existentes con las nuevas (evitar duplicados)
        var allSubcategories = Set(category.subcategories)
        allSubcategories.formUnion(subcategories)
        
        category.subcategories = Array(allSubcategories).sorted()
        category.updatedAt = Date()
        
        await UserDataManager.shared.updateCategory(category)
    }
}

#Preview {
    CategoryCreationSheet()
}
