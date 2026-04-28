// SettingsView.swift
// Settings screen

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
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

                }

                // Ingresos — sueldo + historial unificados
                Section("Ingresos") {
                    NavigationLink {
                        SalarySettingsStandaloneView()
                    } label: {
                        Label("Nóminas", systemImage: "eurosign.circle")
                    }
                }

                // Gastos — configuración relacionada con gastos
                Section("Gastos") {
                    NavigationLink {
                        CategoriesManagementView()
                    } label: {
                        Label(String(localized: "settings.preferences.categories", defaultValue: "Categorías"), systemImage: "tag")
                    }

                    NavigationLink {
                        RecurringExpensesView()
                    } label: {
                        Label(String(localized: "settings.preferences.recurringExpenses", defaultValue: "Gastos Recurrentes"), systemImage: "arrow.clockwise")
                    }
                }

                // App — preferencias UI puras
                Section("App") {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        Label(String(localized: "settings.preferences.notifications", defaultValue: "Notificaciones"), systemImage: "bell")
                    }

                    Picker(selection: $selectedTheme) {
                        Label(String(localized: "settings.theme.light", defaultValue: "Claro"), systemImage: "sun.max.fill").tag("light")
                        Label(String(localized: "settings.theme.dark", defaultValue: "Oscuro"), systemImage: "moon.fill").tag("dark")
                        Label(String(localized: "settings.theme.system", defaultValue: "Sistema"), systemImage: "iphone").tag("system")
                    } label: {
                        Label(String(localized: "settings.preferences.theme", defaultValue: "Tema"), systemImage: "paintbrush")
                    }
                    .onChange(of: selectedTheme) { _, newTheme in
                        saveThemeToFirebase(newTheme)
                    }
                }

                // Data Section
                Section(String(localized: "settings.data.title", defaultValue: "Datos")) {
                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        Label(String(localized: "settings.data.backups", defaultValue: "Copias de Seguridad"), systemImage: "arrow.clockwise.icloud")
                    }

                    Button {
                        exportCSV()
                    } label: {
                        Label("Exportar a CSV", systemImage: "square.and.arrow.up")
                    }

                    // Temporalmente deshabilitado — pendiente para siguientes versiones
                    // NavigationLink {
                    //     ImportFlowView()
                    // } label: {
                    //     Label("Importar CSV", systemImage: "square.and.arrow.down")
                    // }

                    if let fileURL = exportedFileURL {
                        ShareLink(item: fileURL) {
                            Label("Compartir CSV", systemImage: "square.and.arrow.up")
                        }
                    }

                }

                // About Section
                Section(String(localized: "settings.info.title", defaultValue: "Información")) {
                    LabeledContent(String(localized: "settings.info.version", defaultValue: "Versión"), value: appVersion)

                    if let privacyURL = URL(string: "https://clarity-gastos.web.app/privacy") {
                        Link(destination: privacyURL) {
                            Text(String(localized: "settings.info.privacyPolicy", defaultValue: "Política de Privacidad"))
                        }
                    }

                    if let termsURL = URL(string: "https://clarity-gastos.web.app/terms") {
                        Link(destination: termsURL) {
                            Text(String(localized: "settings.info.termsOfService", defaultValue: "Términos de Servicio"))
                        }
                    }
                }

                #if DEBUG
                // Developer / Preview — solo en builds de desarrollo
                Section(String(localized: "settings.developer.title", defaultValue: "Desarrollador")) {
                    Button {
                        UserDataManager.shared.resetOnboarding()
                    } label: {
                        Label(String(localized: "settings.developer.showOnboarding", defaultValue: "Ver onboarding"), systemImage: "arrow.counterclockwise")
                    }
                }
                #endif

                // Logout Section
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "settings.logout.button", defaultValue: "Cerrar Sesión"))
                            Spacer()
                        }
                    }
                }

                // Delete Account Section — requerido por App Store
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                            } else {
                                Text("Eliminar Cuenta")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("Esta acción es permanente. Se borrarán todos tus gastos, presupuestos y datos asociados.")
                }
            }
            .navigationTitle(String(localized: "settings.navigationTitle", defaultValue: "Ajustes"))
            .alert(
                String(localized: "settings.logout.confirmation", defaultValue: "¿Cerrar sesión?"),
                isPresented: $showLogoutConfirm
            ) {
                Button(String(localized: "common.cancel", defaultValue: "Cancelar"), role: .cancel) {}
                Button(String(localized: "settings.logout.button", defaultValue: "Cerrar Sesión"), role: .destructive) {
                    authViewModel.signOut()
                }
            } message: {
                Text("Tendrás que volver a iniciar sesión para acceder a tus datos.")
            }
            .alert(
                "¿Eliminar cuenta permanentemente?",
                isPresented: $showDeleteConfirm
            ) {
                Button(String(localized: "common.cancel", defaultValue: "Cancelar"), role: .cancel) {}
                Button("Eliminar Cuenta", role: .destructive) {
                    Task { await performDeleteAccount() }
                }
            } message: {
                Text("Se borrarán todos tus datos y no se pueden recuperar.")
            }
            .alert("Error al eliminar cuenta", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func performDeleteAccount() async {
        isDeletingAccount = true
        do {
            try await authViewModel.deleteAccount()
        } catch {
            let nsError = error as NSError
            if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                deleteError = "Por seguridad, vuelve a iniciar sesión y pulsa Eliminar Cuenta otra vez."
                // Cerrar sesión automáticamente para que el usuario re-autentique;
                // tras login el token es reciente y user.delete() funciona.
                authViewModel.signOut()
            } else {
                deleteError = error.localizedDescription
            }
        }
        isDeletingAccount = false
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

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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
                // Theme save errors are non-critical; silently ignore
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthViewModel())
}
