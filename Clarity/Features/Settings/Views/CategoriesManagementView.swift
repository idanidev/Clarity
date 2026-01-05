// CategoriesManagementView.swift
// CRUD completo de categorías del usuario

import SwiftUI

struct CategoriesManagementView: View {
    @ObservedObject private var userDataManager = UserDataManager.shared
    @State private var showAddCategory = false
    @State private var editingCategory: Category?
    @State private var showDeleteConfirm = false
    @State private var categoryToDelete: Category?
    @State private var expandedCategories: Set<String> = []
    
    var body: some View {
        mainContent
    }
    
    private var mainContent: some View {
        listView
            .navigationTitle("Mis Categorías")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.clarityPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategorySheet { newCategory in
                    Task {
                        do {
                            try await userDataManager.addCategory(newCategory)
                            HapticManager.notification(.success)
                        } catch {
                            print("Error adding category: \(error)")
                        }
                    }
                }
            }
            .sheet(item: $editingCategory) { category in
                EditCategorySheet(category: category) { updated in
                    Task {
                        do {
                            try await userDataManager.updateCategory(updated)
                            HapticManager.notification(.success)
                        } catch {
                            print("Error updating category: \(error)")
                        }
                    }
                }
            }
            .confirmationDialog(
                "¿Eliminar \(categoryToDelete?.name ?? "categoría")?",
                isPresented: $showDeleteConfirm,
                presenting: categoryToDelete
            ) { category in
                Button("Eliminar", role: .destructive) {
                    Task {
                        do {
                            guard let id = category.id else { return }
                            try await userDataManager.deleteCategory(id: id)
                            HapticManager.notification(.success)
                        } catch {
                            print("Error deleting category: \(error)")
                        }
                    }
                }
            } message: { _ in
                Text("Esta acción no se puede deshacer.")
            }
    }
    
    private var listView: some View {
        List {
            ForEach(userDataManager.categories) { category in
                categorySection(for: category)
            }
            .onMove { indices, newOffset in
                // TODO: Implement reordering
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ViewBuilder
    private func categorySection(for category: Category) -> some View {
        Section {
            if expandedCategories.contains(category.id ?? "") {
                ForEach(category.subcategories, id: \.self) { subcategory in
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                        
                        Text(subcategory)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                }
            }
        } header: {
            CategoryRow(
                category: category,
                isExpanded: expandedCategories.contains(category.id ?? ""),
                onToggle: {
                    if let id = category.id {
                        withAnimation {
                            if expandedCategories.contains(id) {
                                expandedCategories.remove(id)
                            } else {
                                expandedCategories.insert(id)
                            }
                        }
                    }
                }
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    categoryToDelete = category
                    showDeleteConfirm = true
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    editingCategory = category
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                .tint(Color.clarityPrimary)
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                Circle()
                    .fill(Color(hex: category.color) ?? .gray)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if !category.subcategories.isEmpty {
                        Text("\(category.subcategories.count) subcategoría\(category.subcategories.count == 1 ? "" : "s")")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ADD/EDIT sheets would go here but keeping file shorter
struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Category) -> Void
    
    @State private var name = ""
    @State private var selectedColor = CategoryColors.indigo
    @State private var subcategories: [String] = []
    @State private var newSubcategory = ""
    
    // Using centralized DesignSystem colors
    private let availableColors = CategoryColors.allCases
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    TextField("Nombre de categoría", text: $name)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(availableColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .gray)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == colorHex ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    ForEach($subcategories, id: \.self) { $sub in
                        TextField("Subcategoría", text: $sub)
                    }
                    .onDelete { indexSet in
                        subcategories.remove(atOffsets: indexSet)
                    }
                    .onMove { indices, newOffset in
                        subcategories.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    
                    HStack {
                        TextField("Nueva subcategoría", text: $newSubcategory)
                        
                        Button {
                            if !newSubcategory.isEmpty {
                                subcategories.append(newSubcategory)
                                newSubcategory = ""
                                HapticManager.impact(.light)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                        .disabled(newSubcategory.isEmpty)
                    }
                } header: {
                    Text("Subcategorías")
                } footer: {
                    Text("Desliza para eliminar, arrastra para reordenar")
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
                    Button("Guardar") {
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
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category
    let onSave: (Category) -> Void
    
    @State private var name = ""
    @State private var selectedColor = ""
    @State private var subcategories: [String] = []
    @State private var newSubcategory = ""
    
    private let availableColors = [
        "#6366F1", "#F59E0B", "#8B5CF6", "#EC4899",
        "#10B981", "#EF4444", "#14B8A6", "#3B82F6"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    TextField("Nombre de categoría", text: $name)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(availableColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .gray)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == colorHex ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    ForEach($subcategories, id: \.self) { $sub in
                        TextField("Subcategoría", text: $sub)
                    }
                    .onDelete { indexSet in
                        subcategories.remove(atOffsets: indexSet)
                    }
                    .onMove { indices, newOffset in
                        subcategories.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    
                    HStack {
                        TextField("Nueva subcategoría", text: $newSubcategory)
                        
                        Button {
                            if !newSubcategory.isEmpty {
                                subcategories.append(newSubcategory)
                                newSubcategory = ""
                                HapticManager.impact(.light)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                        .disabled(newSubcategory.isEmpty)
                    }
                } header: {
                    Text("Subcategorías")
                } footer: {
                    Text("Desliza para eliminar, arrastra para reordenar")
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
                        var updated = category
                        updated.name = name
                        updated.color = selectedColor
                        updated.subcategories = subcategories
                        updated.updatedAt = Date()
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = category.name
                selectedColor = category.color
                subcategories = category.subcategories
            }
        }
    }
}
