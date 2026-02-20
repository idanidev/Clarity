// BackupSettingsView.swift
// Vista para gestionar backups y restauración de datos

import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    @State private var backupManager = BackupManager.shared
    @State private var showCreateSuccess = false
    @State private var showRestoreConfirm = false
    @State private var selectedBackupId: String?
    @State private var showExportSheet = false
    @State private var exportedFileURL: URL?
    @State private var showImportPicker = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            // Crear Backup Manual
            Section {
                Button {
                    Task {
                        await createBackup()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.icloud")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Crear Copia de Seguridad")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("Guarda todos tus datos en Firebase")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if backupManager.isCreatingBackup {
                            ProgressView()
                        }
                    }
                }
                .disabled(backupManager.isCreatingBackup)
            } header: {
                Text("Backup en la Nube")
            } footer: {
                Text("Se guardan gastos, categorías, presupuestos y configuración.")
            }

            // Lista de Backups Disponibles
            if !backupManager.availableBackups.isEmpty {
                Section("Backups Disponibles") {
                    ForEach(backupManager.availableBackups) { backup in
                        BackupRow(backup: backup) {
                            selectedBackupId = backup.id
                            showRestoreConfirm = true
                        } onDelete: {
                            Task {
                                try? await backupManager.deleteBackup(backupId: backup.id)
                            }
                        }
                    }
                }
            }

            // Exportar/Importar JSON
            Section {
                // Exportar
                Button {
                    Task {
                        await exportToJSON()
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Exportar a JSON")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("Descarga tus datos localmente")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if backupManager.isCreatingBackup {
                            ProgressView()
                        }
                    }
                }
                .disabled(backupManager.isCreatingBackup)

                // Importar
                Button {
                    showImportPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Importar desde JSON")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("Restaura datos desde un archivo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if backupManager.isRestoringBackup {
                            ProgressView()
                        }
                    }
                }
                .disabled(backupManager.isRestoringBackup)
            } header: {
                Text("Exportar/Importar")
            } footer: {
                Text("Exporta tus datos a un archivo JSON para guardarlos localmente o transferirlos a otro dispositivo.")
            }

            // Info
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Los backups automáticos se crean cada 7 días")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Copias de Seguridad")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await backupManager.loadAvailableBackups()
        }
        .alert("Backup Creado", isPresented: $showCreateSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tu copia de seguridad se ha guardado correctamente en Firebase.")
        }
        .alert("Restaurar Backup", isPresented: $showRestoreConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Restaurar", role: .destructive) {
                Task {
                    await restoreBackup()
                }
            }
        } message: {
            Text("¿Estás seguro? Esto sobrescribirá tus datos actuales con los del backup.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await importFromJSON(fileURL: url)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Actions

    private func createBackup() async {
        do {
            _ = try await backupManager.createBackup()
            HapticManager.shared.notification(.success)
            showCreateSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.shared.notification(.error)
        }
    }

    private func restoreBackup() async {
        guard let backupId = selectedBackupId else { return }

        do {
            try await backupManager.restoreBackup(backupId: backupId)
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.shared.notification(.error)
        }
    }

    private func exportToJSON() async {
        do {
            let url = try await backupManager.exportToJSON()
            exportedFileURL = url
            showExportSheet = true
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.shared.notification(.error)
        }
    }

    private func importFromJSON(fileURL: URL) async {
        do {
            // Obtener acceso al archivo
            guard fileURL.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "BackupManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "No se puede acceder al archivo"])
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }

            try await backupManager.importFromJSON(fileURL: fileURL)
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - Backup Row

struct BackupRow: View {
    let backup: BackupManager.BackupMetadata
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.timestamp, style: .date)
                        .font(.body.weight(.medium))

                    Text(backup.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onRestore()
                } label: {
                    Text("Restaurar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                Label("\(backup.expenseCount)", systemImage: "dollarsign.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(backup.categoryCount)", systemImage: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(ByteCountFormatter.string(fromByteCount: Int64(backup.size), countStyle: .file), systemImage: "doc.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        BackupSettingsView()
    }
}
