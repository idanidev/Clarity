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
        .fondoClarity()
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
        // El JSON exportado lleva todos los gastos en claro y se quedaba en
        // `tmp/` después de compartirlo. Se borra al cerrarse la hoja, que es
        // donde acaban todos los caminos: compartido, cancelado o arrastrada
        // hacia abajo (ese último no pasa por el aviso de `ShareSheet`).
        .sheet(isPresented: $showExportSheet, onDismiss: borrarExportacionTemporal) {
            if let url = exportedFileURL {
                ShareSheet(items: [url]) {
                    showExportSheet = false
                }
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
                Task {
                    await parseCSVForPreview(fileURL: url)
                }
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
                HStack(spacing: Spacing.sm) {
                    CirculoIconoClarity(icono: "arrow.clockwise.icloud", tamano: 36, esSimbolo: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "backup.create.title", defaultValue: "Crear Copia de Seguridad"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "backup.create.subtitle", defaultValue: "Guarda todos tus datos en Firebase"))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
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
                HStack(spacing: Spacing.sm) {
                    CirculoIconoClarity(icono: "square.and.arrow.up", color: Color.success, tamano: 36, esSimbolo: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "backup.export.json.title", defaultValue: "Exportar a JSON"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "backup.export.json.subtitle", defaultValue: "Descarga tus datos localmente"))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
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
                HStack(spacing: Spacing.sm) {
                    CirculoIconoClarity(icono: "square.and.arrow.down", color: Color.warning, tamano: 36, esSimbolo: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "backup.import.json.title", defaultValue: "Importar desde JSON"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "backup.import.json.subtitle", defaultValue: "Restaura datos desde un archivo"))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
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
                HStack(spacing: Spacing.sm) {
                    CirculoIconoClarity(icono: "tablecells", color: Color.info, tamano: 36, esSimbolo: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "backup.import.csv.title", defaultValue: "Importar desde CSV"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "backup.import.csv.subtitle", defaultValue: "Importa gastos desde un archivo CSV"))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
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
                        .foregroundStyle(Color.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "backup.info.lastBackup", defaultValue: "Ultima copia de seguridad"))
                            .font(.caption.bold())
                            .foregroundStyle(Color.textSecondary)
                        Text(lastBackup.timestamp, style: .date) + Text(" a las ") + Text(lastBackup.timestamp, style: .time)
                            .font(.caption)
                    }
                    .font(.caption)
                    .foregroundStyle(.primary)
                }
            }
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.clarityPrimary)
                Text(String(localized: "backup.info.autoBackup", defaultValue: "Los backups automaticos se crean cada 7 dias"))
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
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

    /// Quita de `tmp/` el JSON que se acaba de compartir (o de no compartir).
    private func borrarExportacionTemporal() {
        guard let url = exportedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        exportedFileURL = nil
    }

    private func parseCSVForPreview(fileURL: URL) async {
        // El indicador del botón, y de paso que no se pueda elegir otro
        // archivo mientras se lee este.
        isImportingCSV = true
        defer { isImportingCSV = false }

        do {
            // Leer y parsear fuera del hilo principal: antes iba en el callback
            // del selector de archivos, y un CSV de años congelaba la pantalla.
            // El permiso de acceso se abre y se cierra dentro de la misma tarea
            // que lee, para que cubra la lectura entera.
            let expenses = try await Task.detached(priority: .userInitiated) {
                guard fileURL.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "BackupManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "No se puede acceder al archivo"])
                }
                defer { fileURL.stopAccessingSecurityScopedResource() }
                return try ExportService.shared.parseCSV(from: fileURL)
            }.value
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
                                .monospacedDigit()
                                .foregroundStyle(Color.clarityPrimary)
                        }

                        Divider()

                        HStack {
                            Text("Rango de fechas")
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                            Text(dateRange)
                                .font(.subheadline)
                        }

                        HStack {
                            Text("Categorias")
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                            Text("\(Set(expenses.map(\.category)).count)")
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                    }
                    .padding(20)
                    .glassCard(cornerRadius: CornerRadius.xlarge)

                    // Preview list
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Vista previa")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textSecondary)
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
                                            .foregroundStyle(Color.textSecondary)

                                        Text(Formatters.displayDate(expense.date))
                                            .font(.caption)
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                }

                                Spacer()

                                Text(Formatters.currency(expense.amount))
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                            .padding(Spacing.sm)
                            .background(
                                Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            )
                        }

                        if expenses.count > 10 {
                            Text("y \(expenses.count - 10) gastos mas...")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, Spacing.xxs)
                        }
                    }
                    .padding(20)
                    .glassCard(cornerRadius: CornerRadius.large)

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
                            }
                        }
                        .buttonStyle(.principalClarity)
                        .disabled(isImporting)

                        Button {
                            onCancel()
                        } label: {
                            Text("Cancelar")
                        }
                        .buttonStyle(.secundarioClarity)
                        .disabled(isImporting)
                    }
                }
                .padding(Spacing.md)
            }
            .fondoClarity()
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
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Button {
                    onRestore()
                } label: {
                    Text(String(localized: "backup.restore.button", defaultValue: "Restaurar"))
                }
                .buttonStyle(.secundarioClarity)
            }

            HStack(spacing: 16) {
                Label("\(backup.expenseCount)", systemImage: "dollarsign.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)

                Label("\(backup.categoryCount)", systemImage: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)

                Label(ByteCountFormatter.string(fromByteCount: Int64(backup.size), countStyle: .file), systemImage: "doc.fill")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
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
    /// Se llama cuando la hoja de compartir ha terminado: se compartió, o se
    /// cerró sin elegir nada.
    var onFinish: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            // Cancelar dentro de una actividad (descartar el borrador del
            // correo, p. ej.) devuelve a la hoja, que sigue abierta: eso
            // todavía no es terminar.
            guard completed || activityType == nil else { return }
            onFinish?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        BackupSettingsView()
    }
}
