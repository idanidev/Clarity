// SettingsView.swift
// Settings screen

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var showLogoutConfirm = false
    @AppStorage("app.theme") private var selectedTheme: String = "system"

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
                            Text(
                                authViewModel.userDocument?.subscription?.plan.capitalized ?? "Free"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // Preferences Section
                Section("Preferencias") {
                    NavigationLink("Categorías") {
                        CategoriesManagementView()
                    }

                    NavigationLink("Historial de Nóminas") {
                        MonthlyBudgetsView()
                    }

                    NavigationLink("Ajustes de Sueldo") {
                        SalarySettingsStandaloneView()
                    }

                    NavigationLink("Gastos Recurrentes") {
                        RecurringExpensesView()
                    }

                    NavigationLink("Notificaciones") {
                        NotificationsView()
                    }

                    // Theme Picker
                    Picker("Tema", selection: $selectedTheme) {
                        Label("Claro", systemImage: "sun.max.fill").tag("light")
                        Label("Oscuro", systemImage: "moon.fill").tag("dark")
                        Label("Sistema", systemImage: "iphone").tag("system")
                    }
                    .onChange(of: selectedTheme) { _, newTheme in
                        saveThemeToFirebase(newTheme)
                    }
                }

                // Data Section
                Section("Datos") {
                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        Label("Copias de Seguridad", systemImage: "arrow.clockwise.icloud")
                    }

                    Button {
                        exportCSV()
                    } label: {
                        Label("Exportar a CSV", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink {
                        ImportFlowView()
                    } label: {
                        Label("Importar CSV", systemImage: "square.and.arrow.down")
                    }

                    if let fileURL = exportedFileURL {
                        ShareLink(item: fileURL) {
                            Label("Compartir CSV", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button {
                        // PDF export - complex feature for future
                        HapticManager.shared.notification(.warning)
                    } label: {
                        Label("Generar Informe PDF", systemImage: "doc.richtext")
                    }
                    .disabled(true)
                    .opacity(0.5)
                }

                // About Section
                Section("Información") {
                    LabeledContent("Versión", value: appVersion)

                    if let privacyURL = URL(string: "https://clarity-gastos.web.app/privacy") {
                        Link(destination: privacyURL) {
                            Text("Política de Privacidad")
                        }
                    }

                    if let termsURL = URL(string: "https://clarity-gastos.web.app/terms") {
                        Link(destination: termsURL) {
                            Text("Términos de Servicio")
                        }
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
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false

    private func exportCSV() {
        Task {
            do {
                let expenses = try await DependencyContainer.shared.expenseRepository.getExpenses()
                if let url = ExportService.shared.generateCSV(from: expenses) {
                    exportedFileURL = url
                    showingShareSheet = true
                }
            }
        }
    }
    // MARK: - Theme Functions

    private func saveThemeToFirebase(_ theme: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        Task {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .updateData(["settings.theme": theme])
            } catch {
                print("❌ Error saving theme: \(error)")
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
        .environment(AuthViewModel())
}
