// SettingsView.swift
// Settings screen

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutConfirm = false
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Cuenta") {
                    if let email = authViewModel.currentUser?.email {
                        LabeledContent("Email", value: email)
                    }
                    
                    if let name = authViewModel.userDocument?.displayName {
                        LabeledContent("Nombre", value: name)
                    }
                    
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Text("Suscripción")
                            Spacer()
                            Text(authViewModel.userDocument?.subscription?.plan.capitalized ?? "Free")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Preferences Section
                Section("Preferencias") {
                    NavigationLink("Categorías") {
                        Text("Gestión de categorías") // TODO
                    }
                    
                    NavigationLink("Gastos Recurrentes") {
                        RecurringExpensesView()
                    }
                    
                    NavigationLink("Notificaciones") {
                        Text("Configuración de notificaciones") // TODO
                    }
                }
                
                // Data Section
                Section("Datos") {
                    Button {
                        exportCSV()
                    } label: {
                        Label("Exportar a CSV", systemImage: "square.and.arrow.up")
                    }
                    
                    if let fileURL = exportedFileURL {
                        ShareLink(item: fileURL) {
                            Label("Compartir CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                    
                    Button {
                        // TODO: Export PDF
                    } label: {
                        Label("Generar Informe PDF", systemImage: "doc.richtext")
                    }
                }
                
                // About Section
                Section("Información") {
                    LabeledContent("Versión", value: "1.0.0")
                    
                    Link(destination: URL(string: "https://clarity-gastos.web.app/privacy")!) {
                        Text("Política de Privacidad")
                    }
                    
                    Link(destination: URL(string: "https://clarity-gastos.web.app/terms")!) {
                        Text("Términos de Servicio")
                    }
                }
                
                // Logout Section
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Cerrar Sesión")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Ajustes")
            .confirmationDialog(
                "¿Cerrar sesión?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Cerrar Sesión", role: .destructive) {
                    authViewModel.signOut()
                }
                Button("Cancelar", role: .cancel) { }
            }
        }
    }
    
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    
    private func exportCSV() {
        Task {
            do {
                let expenses = try await ExpenseRepository().fetchExpenses()
                if let url = ExportService.shared.generateCSV(from: expenses) {
                    exportedFileURL = url
                    showingShareSheet = true
                }
            } catch {
                print("Error exporting CSV: \(error)")
            }
        }
    }
}

// MARK: - Subscription View
struct SubscriptionView: View {
    var body: some View {
        List {
            ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text(plan.displayName)
                            .font(.clarityHeadline)
                        
                        Spacer()
                        
                        Text(plan.price)
                            .font(.claritySubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.clarityPrimary)
                    }
                    
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.green)
                            
                            Text(feature)
                                .font(.clarityCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }
        .navigationTitle("Suscripción")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
