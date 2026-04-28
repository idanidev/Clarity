//
//  AISettingsView.swift
//  Clarity
//
//  Configuración de proveedores IA: Gemini 2.0 Flash + Groq
//

import SwiftUI

struct AISettingsView: View {
    // API keys en Keychain (no UserDefaults) — se cargan en onAppear
    @State private var geminiKey: String = ""
    @State private var groqKey: String = ""
    @AppStorage("ai_preferred_provider") private var preferredProvider: String = "gemini"

    @State private var showGeminiKey = false
    @State private var showGroqKey = false

    private var geminiReady: Bool { !geminiKey.isEmpty || !Secrets.geminiAPIKey.isEmpty }
    private var groqReady: Bool { !groqKey.isEmpty || !Secrets.groqAPIKey.isEmpty }

    var body: some View {
        List {
            // MARK: Provider selector
            Section {
                Picker(String(localized: "aiSettings.mainProvider", defaultValue: "Proveedor principal"), selection: $preferredProvider) {
                    Label("Gemini 2.0 Flash", systemImage: "sparkles").tag("gemini")
                    Label("Groq (llama-3.3-70b)", systemImage: "bolt.fill").tag("groq")
                }
                .onChange(of: preferredProvider) { _, newValue in
                    AIServiceManager.shared.preferredProviderKey = newValue
                }
            } header: {
                Text(String(localized: "aiSettings.activeProvider.header", defaultValue: "Proveedor activo"))
            } footer: {
                Text(String(localized: "aiSettings.activeProvider.footer", defaultValue: "El otro proveedor actua de reserva automatica si se agota el limite del principal."))
            }

            // MARK: Gemini
            Section {
                HStack {
                    Group {
                        if showGeminiKey {
                            TextField("AIza...", text: $geminiKey)
                        } else {
                            SecureField("AIza...", text: $geminiKey)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: geminiKey) { _, newValue in
                        GeminiProvider.saveKey(newValue)
                    }

                    Button {
                        showGeminiKey.toggle()
                    } label: {
                        Image(systemName: showGeminiKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }

                if geminiKey.isEmpty && Secrets.geminiAPIKey.isEmpty {
                    Link(
                        String(localized: "aiSettings.gemini.getKey", defaultValue: "Obtener clave gratis en aistudio.google.com"),
                        destination: URL(string: "https://aistudio.google.com/apikey")!
                    )
                    .font(.caption)
                }
            } header: {
                HStack {
                    Text("Gemini API Key")
                    Spacer()
                    statusBadge(ready: geminiReady, isPreferred: preferredProvider == "gemini")
                }
            } footer: {
                Text(String(localized: "aiSettings.gemini.footer", defaultValue: "Gratis: 15 peticiones/min, 1.500 al dia. Mejor razonamiento en espanol."))
            }

            // MARK: Groq
            Section {
                HStack {
                    Group {
                        if showGroqKey {
                            TextField("gsk_...", text: $groqKey)
                        } else {
                            SecureField("gsk_...", text: $groqKey)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: groqKey) { _, newValue in
                        GroqProvider.saveKey(newValue)
                    }

                    Button {
                        showGroqKey.toggle()
                    } label: {
                        Image(systemName: showGroqKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }

                if groqKey.isEmpty && Secrets.groqAPIKey.isEmpty {
                    Link(
                        String(localized: "aiSettings.groq.getKey", defaultValue: "Obtener clave gratis en console.groq.com"),
                        destination: URL(string: "https://console.groq.com/keys")!
                    )
                    .font(.caption)
                }
            } header: {
                HStack {
                    Text("Groq API Key")
                    Spacer()
                    statusBadge(ready: groqReady, isPreferred: preferredProvider == "groq")
                }
            } footer: {
                Text(String(localized: "aiSettings.groq.footer", defaultValue: "Gratis. Actua de reserva cuando Gemini alcanza su limite diario."))
            }

            // MARK: Status
            Section {
                statusRow(
                    label: "Gemini 2.0 Flash",
                    icon: "sparkles",
                    ready: geminiReady,
                    isActive: preferredProvider == "gemini"
                )
                statusRow(
                    label: "Groq llama-3.3-70b",
                    icon: "bolt.fill",
                    ready: groqReady,
                    isActive: preferredProvider == "groq"
                )
            } header: {
                Text(String(localized: "aiSettings.status.header", defaultValue: "Estado"))
            }
        }
        .navigationTitle(String(localized: "aiSettings.navigationTitle", defaultValue: "Configuración IA"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Cargar desde Keychain (migrar desde UserDefaults si es necesario)
            geminiKey = APIKeychain.get("clarity.api.gemini") ?? migrateFromUserDefaults("gemini_api_key", keychainKey: "clarity.api.gemini")
            groqKey   = APIKeychain.get("clarity.api.groq")   ?? migrateFromUserDefaults("groq_api_key",   keychainKey: "clarity.api.groq")
        }
    }

    /// Migra una clave desde UserDefaults a Keychain y elimina el valor de UserDefaults.
    private func migrateFromUserDefaults(_ udKey: String, keychainKey: String) -> String {
        guard let value = UserDefaults.standard.string(forKey: udKey), !value.isEmpty else { return "" }
        APIKeychain.set(value, forKey: keychainKey)
        UserDefaults.standard.removeObject(forKey: udKey)
        return value
    }

    @ViewBuilder
    private func statusBadge(ready: Bool, isPreferred: Bool) -> some View {
        if isPreferred {
            Text(String(localized: "aiSettings.badge.active", defaultValue: "ACTIVO"))
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.clarityPrimary))
        }
    }

    private func statusRow(label: String, icon: String, ready: Bool, isActive: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isActive ? Color.clarityPrimary : .secondary)
                .frame(width: 20)
            Text(label)
            Spacer()
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ready ? .green : .red)
            Text(ready ? (isActive ? String(localized: "aiSettings.status.main", defaultValue: "Principal") : String(localized: "aiSettings.status.backup", defaultValue: "Reserva")) : String(localized: "aiSettings.status.noKey", defaultValue: "Sin clave"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
