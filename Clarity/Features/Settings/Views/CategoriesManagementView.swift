// CategoriesManagementView.swift
// CRUD completo de categorías del usuario - Rediseño iOS-Native

import SwiftUI

struct CategoriesManagementView: View {
    @ObservedObject private var userDataManager = UserDataManager.shared
    @State private var showAddCategory = false
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: Category?
    
    var body: some View {
        List {
            // Prominent add button
            Section {
                Button {
                    showAddCategory = true
                } label: {
                    Label("Agregar Categoría", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.clarityPrimary)
                }
            }
            
            // Categories list
            Section {
                ForEach(userDataManager.categories) { category in
                    NavigationLink {
                        CategoryDetailView(category: category) {
                            Task {
                                await userDataManager.refreshCategories()
                            }
                        }
                    } label: {
                        CategoryRow(category: category)
                    }
                }
                .onDelete(perform: deleteCategories)
                .onMove(perform: moveCategories)
            } header: {
                Text("Mis Categorías")
            } footer: {
                if !userDataManager.categories.isEmpty {
                    Text("Desliza para eliminar • Toca para editar")
                        .font(.caption2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView { newCategory in
                Task {
                    do {
                        try await userDataManager.addCategory(newCategory)
                        HapticManager.notification(.success)
                    } catch {
                        print("Error adding category: \(error)")
                        HapticManager.notification(.error)
                    }
                }
            }
        }
        .alert("Eliminar Categoría", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("Esta acción no se puede deshacer. Los gastos existentes mantendrán esta categoría.")
        }
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        categoryToDelete = userDataManager.categories[index]
        showDeleteAlert = true
    }
    
    private func confirmDelete() {
        guard let category = categoryToDelete, let id = category.id else { return }
        
        Task {
            do {
                try await userDataManager.deleteCategory(id: id)
                HapticManager.notification(.success)
            } catch {
                print("Error deleting category: \(error)")
                HapticManager.notification(.error)
            }
        }
        categoryToDelete = nil
    }
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        // Local reorder only for now - Firebase persist on save
        HapticManager.impact(.light)
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: Category
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(Color(hex: category.color) ?? .gray)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                
                Text("\(category.subcategories.count) subcategoría\(category.subcategories.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        CategoriesManagementView()
    }
}
