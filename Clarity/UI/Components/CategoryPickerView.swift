// CategoryPickerView.swift
// Reusable category and subcategory picker

import SwiftUI

struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: String
    @Binding var selectedSubcategory: String?
    
    private var categories: [Category] {
        UserDataManager.shared.categories
    }
    
    var body: some View {
        List {
            ForEach(categories) { category in
                Section {
                    // Main category button
                    Button {
                        selectedCategory = category.name
                        selectedSubcategory = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text(category.name)
                                .foregroundColor(.white)
                            Spacer()
                            if selectedCategory == category.name && selectedSubcategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.clarityPrimary)
                            }
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    
                    // Subcategories
                    ForEach(category.subcategories, id: \.self) { subcategory in
                        Button {
                            selectedCategory = category.name
                            selectedSubcategory = subcategory
                            dismiss()
                        } label: {
                            HStack {
                                Text(subcategory)
                                    .foregroundColor(.textSecondary)
                                    .padding(.leading, Spacing.md)
                                Spacer()
                                if selectedCategory == category.name && selectedSubcategory == subcategory {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.clarityPrimary)
                                }
                            }
                        }
                        .listRowBackground(Color.bgCard)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .navigationTitle("Seleccionar Categoría")
        .navigationBarTitleDisplayMode(.inline)
    }
}
