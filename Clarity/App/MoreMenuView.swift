// MoreMenuView.swift
// Menu with Categories, IA, and Settings

import SwiftUI

struct MoreMenuView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    CategoriesManagementView()
                } label: {
                    Label("Categorías", systemImage: "square.grid.2x2.fill")
                }
                
                NavigationLink {
                    AIAssistantView()
                } label: {
                    Label("IA", systemImage: "sparkles")
                }
                
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
            }
            .navigationTitle("Más")
            .listStyle(.insetGrouped)
        }
    }
}
