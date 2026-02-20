// CategoriesManagementView.swift
// CRUD completo de categorías del usuario - Rediseño iOS-Native

import SwiftUI

struct CategoriesManagementView: View {
    private var userDataManager = UserDataManager.shared
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
                    await userDataManager.addCategory(newCategory)
                    HapticManager.shared.notification(.success)
                }
            }
        }
        .alert("Eliminar Categoría", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text(
                "Esta acción no se puede deshacer. Los gastos existentes mantendrán esta categoría."
            )
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
            await userDataManager.deleteCategory(id: id)
            HapticManager.shared.notification(.success)
        }
        categoryToDelete = nil
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        // Local reorder only for now - Firebase persist on save
        HapticManager.shared.impact(.light)
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
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                Text(
                    "\(category.subcategories.count) subcategoría\(category.subcategories.count == 1 ? "" : "s")"
                )
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
