//
//  ShieldCategoryPickerView.swift
//  Clarity
//
//  Simple top-level category picker for spending limit (Shield) goals.
//  Unlike CategoryPickerView, this lets you select a parent category directly.
//

import SwiftUI

struct ShieldCategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: String
    @State private var showNewCategory = false

    private var categories: [Category] {
        UserDataManager.shared.categories
    }

    var body: some View {
        List {
            Section {
                ForEach(categories, id: \.name) { category in
                    Button {
                        selectedCategory = category.name
                        HapticManager.shared.selection()
                        dismiss()
                    } label: {
                        HStack {
                            Text(category.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCategory == category.name {
                                Image(systemName: "checkmark")
                                    .font(.body.bold())
                                    .foregroundStyle(Color.clarityPrimary)
                            }
                        }
                    }
                    .listRowBackground(Color.bgCard)
                }
            }

            Section {
                Button {
                    showNewCategory = true
                    HapticManager.shared.impact(.light)
                } label: {
                    Label("Nueva categoría", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.clarityPrimary)
                }
                .listRowBackground(Color.bgCard)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .navigationTitle("Categoría del Escudo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewCategory) {
            NewCategorySheet()
        }
    }
}
