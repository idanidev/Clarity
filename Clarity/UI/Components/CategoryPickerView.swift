// CategoryPickerView.swift
// Reusable category and subcategory picker

import SwiftUI

struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: String
    @Binding var selectedSubcategory: String?
    
    @State private var searchText = ""
    
    private var categories: [Category] {
        UserDataManager.shared.categories
    }
    
    private var filteredCategories: [Category] {
        if searchText.isEmpty {
            return categories
        } else {
            return categories.compactMap { category in
                // Check if category name matches
                let categoryMatches = category.name.localizedCaseInsensitiveContains(searchText)
                
                // Check if any subcategory matches
                let matchingSubcategories = category.subcategories.filter {
                    $0.localizedCaseInsensitiveContains(searchText)
                }
                
                // If category matches, show all subcategories (or should we filter? Let's show all if category matches, otherwise only matching subs)
                // Better UX: If category matches, show entry + all subs? Or just filter everything?
                // Let's go with: Include category if name matches OR if it has matching subcategories.
                // If only subcategories match, include category but filter subcategories list.
                
                if categoryMatches {
                    return category
                } else if !matchingSubcategories.isEmpty {
                    var newCategory = category
                    newCategory.subcategories = matchingSubcategories
                    return newCategory
                }
                
                return nil
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredCategories) { category in
                Section {
                    // Option 1: Select just the main category (General)
                    // Only show "General" option if the category name itself matches OR if we are showing the whole category because of a subcategory match
                    // To simplify: Always show "General" if the section is visible, unless user is searching specifically for a subcategory?
                    // Let's keep it simple: Show header + general option + matching subs.
                    
                    Button {
                        select(category: category.name, sub: nil)
                    } label: {
                        HStack {
                            Text("General / Sin subcategoría")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isSelected(cat: category.name, sub: nil) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(category.uiColor)
                            }
                        }
                    }
                    .listRowBackground(Color.bgCard)
                    
                    // Option 2: Select subcategories
                    ForEach(category.subcategories, id: \.self) { subcategory in
                        Button {
                            select(category: category.name, sub: subcategory)
                        } label: {
                            HStack {
                                // Visual indicator of hierarchy using category color
                                Capsule()
                                    .fill(category.uiColor.opacity(0.8))
                                    .frame(width: 4, height: 16)
                                
                                Text(subcategory)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if isSelected(cat: category.name, sub: subcategory) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(category.uiColor)
                                }
                            }
                        }
                        .listRowBackground(Color.bgCard)
                    }
                } header: {
                    // Custom Header with solid color usage
                    HStack {
                        Text(category.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(category.uiColor) 
                            .shadow(color: category.uiColor.opacity(0.3), radius: 5)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .textCase(nil) // Prevent all-caps default
                }
            }
        }
        .listStyle(.insetGrouped) // More modern look than .plain
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .navigationTitle("Seleccionar Categoría")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar categoría...")
    }
    
    private func select(category: String, sub: String?) {
        selectedCategory = category
        selectedSubcategory = sub
        HapticManager.shared.selection()
        dismiss()
    }
    
    private func isSelected(cat: String, sub: String?) -> Bool {
        selectedCategory == cat && selectedSubcategory == sub
    }
}
