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
    @State private var showCSVImportPicker = false
    @State private var showCSVPreview = false
    @State private var csvPreviewExpenses: [Expense] = []
    @State private var isImportingCSV = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            createBackupSection
            backupListSection
            exportImportSection
            infoSection
        }
        .navigationTitle(String(localized: "backup.navigationTitle", defaultValue: "Copias de Seguridad"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await backupManager.loadAvailableBackups()
        }
        .alert(String(localized: "backup.created.title", defaultValue: "Backup Creado"), isPresented: $showCreateSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(String(localized: "backup.created.message", defaultValue: "Tu copia de seguridad se ha guardado correctamente en Firebase."))
        }
        .alert(String(localized: "backup.restore.title", defaultValue: "Restaurar Backup"), isPresented: $showRestoreConfirm) {
            Button(String(localized: "common.cancel", defaultValue: "Cancelar"), role: .cancel) {}
            Button(String(localized: "backup.restore.button", defaultValue: "Restaurar"), role: .destructive) {
                Task {
                    await restoreBackup()
                }
            }
        } message: {
            Text(String(localized: "backup.restore.message", defaultValue: "¿Estás seguro? Esto sobrescribirá tus datos actuales con los del backup."))
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
        .fileImporter(
            isPresented: $showCSVImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                parseCSVForPreview(fileURL: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .sheet(isPresented: $showCSVPreview) {
            CSVImportPreviewSheet(
                expenses: csvPreviewExpenses,
                isImporting: $isImportingCSV,
                onConfirm: {
                    Task {
                        await importCSVExpenses(csvPreviewExpenses)
                    }
                },
                onCancel: {
                    csvPreviewExpenses = []
                    showCSVPreview = false
                }
            )
        }
    }

    // MARK: - Body Sections

    private var createBackupSection: some View {
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
                        Text(String(localized: "backup.create.title", defaultValue: "Crear Copia de Seguridad"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "backup.create.subtitle", defaultValue: "Guarda todos tus datos en Firebase"))
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
            Text(String(localized: "backup.cloud.header", defaultValue: "Backup en la Nube"))
        } footer: {
            Text(String(localized: "backup.cloud.footer", defaultValue: "Se guardan gastos, categorias, presupuestos y configuracion."))
        }
    }

    @ViewBuilder
    private var backupListSection: some View {
        if !backupManager.availableBackups.isEmpty {
            Section(String(localized: "backup.available.header", defaultValue: "Backups Disponibles")) {
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
    }

    private var exportImportSection: some View {
        Section {
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
                        Text(String(localized: "backup.export.json.title", defaultValue: "Exportar a JSON"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "backup.export.json.subtitle", defaultValue: "Descarga tus datos localmente"))
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

            Button {
                showImportPicker = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "backup.import.json.title", defaultValue: "Importar desde JSON"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "backup.import.json.subtitle", defaultValue: "Restaura datos desde un archivo"))
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

            Button {
                showCSVImportPicker = true
            } label: {
                HStack {
                    Image(systemName: "tablecells")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "backup.import.csv.title", defaultValue: "Importar desde CSV"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "backup.import.csv.subtitle", defaultValue: "Importa gastos desde un archivo CSV"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isImportingCSV {
                        ProgressView()
                    }
                }
            }
            .disabled(isImportingCSV)
        } header: {
            Text(String(localized: "backup.exportImport.header", defaultValue: "Exportar/Importar"))
        } footer: {
            Text(String(localized: "backup.exportImport.footer", defaultValue: "Exporta tus datos a un archivo JSON o CSV para guardarlos localmente o transferirlos a otro dispositivo."))
        }
    }

    private var infoSection: some View {
        Section {
            if let lastBackup = backupManager.availableBackups.first {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "backup.info.lastBackup", defaultValue: "Ultima copia de seguridad"))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(lastBackup.timestamp, style: .date) + Text(" a las ") + Text(lastBackup.timestamp, style: .time)
                            .font(.caption)
                    }
                    .font(.caption)
                    .foregroundStyle(.primary)
                }
            }
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text(String(localized: "backup.info.autoBackup", defaultValue: "Los backups automaticos se crean cada 7 dias"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private func parseCSVForPreview(fileURL: URL) {
        guard fileURL.startAccessingSecurityScopedResource() else {
            errorMessage = "No se puede acceder al archivo"
            showError = true
            return
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        do {
            let expenses = try ExportService.shared.parseCSV(from: fileURL)
            guard !expenses.isEmpty else {
                errorMessage = "El archivo CSV no contiene gastos válidos"
                showError = true
                return
            }
            csvPreviewExpenses = expenses
            showCSVPreview = true
        } catch {
            errorMessage = "Error al leer el CSV: \(error.localizedDescription)"
            showError = true
        }
    }

    private func importCSVExpenses(_ expenses: [Expense]) async {
        isImportingCSV = true
        defer { isImportingCSV = false }

        let repository = DependencyContainer.shared.expenseRepository
        var importedCount = 0

        for expense in expenses {
            do {
                _ = try await repository.addExpense(expense)
                importedCount += 1
            } catch {
                // Continue importing remaining expenses
            }
        }

        showCSVPreview = false
        csvPreviewExpenses = []

        if importedCount == expenses.count {
            HapticManager.shared.notification(.success)
        } else {
            errorMessage = "Se importaron \(importedCount) de \(expenses.count) gastos"
            showError = true
            HapticManager.shared.notification(.warning)
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

// MARK: - CSV Import Preview Sheet

struct CSVImportPreviewSheet: View {
    let expenses: [Expense]
    @Binding var isImporting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var dateRange: String {
        let dates = expenses.compactMap { Formatters.date(from: $0.date) }
        guard let earliest = dates.min(), let latest = dates.max() else {
            return "Sin fechas"
        }
        return "\(Formatters.isoString(from: earliest)) — \(Formatters.isoString(from: latest))"
    }

    private var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    // Summary card
                    VStack(spacing: Spacing.sm) {
                        HStack {
                            Label("\(expenses.count) gastos", systemImage: "doc.text")
                                .font(.headline)
                            Spacer()
                            Text(Formatters.currency(totalAmount))
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }

                        Divider()

                        HStack {
                            Text("Rango de fechas")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(dateRange)
                                .font(.subheadline)
                        }

                        HStack {
                            Text("Categorias")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Set(expenses.map(\.category)).count)")
                                .font(.subheadline)
                        }
                    }
                    .padding(Spacing.cardPadding)
                    .modernGlassCard()

                    // Preview list
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Vista previa")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Spacing.xxs)

                        ForEach(Array(expenses.prefix(10).enumerated()), id: \.offset) { _, expense in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.name)
                                        .font(.body.weight(.medium))
                                        .lineLimit(1)

                                    HStack(spacing: Spacing.xs) {
                                        Text(expense.category)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text(Formatters.displayDate(expense.date))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                Text(Formatters.currency(expense.amount))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(Spacing.sm)
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        }

                        if expenses.count > 10 {
                            Text("y \(expenses.count - 10) gastos mas...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, Spacing.xxs)
                        }
                    }
                    .padding(Spacing.cardPadding)
                    .modernGlassCard()

                    // Action buttons
                    VStack(spacing: Spacing.sm) {
                        Button {
                            onConfirm()
                        } label: {
                            HStack {
                                if isImporting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                }
                                Text("Importar \(expenses.count) gastos")
                                    .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: Spacing.buttonHeight)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                        }
                        .disabled(isImporting)

                        Button {
                            onCancel()
                        } label: {
                            Text("Cancelar")
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: Spacing.buttonHeight)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(isImporting)
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle("Importar CSV")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isImporting)
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
                    Text(String(localized: "backup.restore.button", defaultValue: "Restaurar"))
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
