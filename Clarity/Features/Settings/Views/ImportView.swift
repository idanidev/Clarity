//
//  ImportFlowView.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-27.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportFlowView: View {
    @State private var isImporting: Bool = false
    @State private var isLoading: Bool = false
    @State private var importError: String?
    @State private var importedTransactions: [RawTransaction] = []
    @State private var categorizedTransactions: [RawTransaction] = []
    @State private var showReview: Bool = false

    // Dependencies
    private let expenseRepository = DependencyContainer.shared.expenseRepository

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Analizando con IA...")
                        .controlSize(.large)
                } else {
                    Spacer()

                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.clarityPrimary)

                    Text("Importar Extracto Bancario")
                        .font(.title2.bold())

                    Text(
                        "Sube tu archivo CSV y deja que Clarity clasifique tus gastos automáticamente."
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                    Button {
                        isImporting = true
                    } label: {
                        Label("Seleccionar Archivo CSV", systemImage: "folder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clarityPrimary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    if let error = importError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                    }

                    Spacer()
                }
            }
            .navigationTitle("Importar")
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .navigationDestination(isPresented: $showReview) {
                ImportReviewView(transactions: categorizedTransactions)
            }
        }
    }

    // MARK: - Logic

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let selectedFile: URL = try result.get().first else { return }
            if selectedFile.startAccessingSecurityScopedResource() {
                defer { selectedFile.stopAccessingSecurityScopedResource() }

                let fileData = try Data(contentsOf: selectedFile)
                if let content = String(data: fileData, encoding: .utf8) {
                    processCSV(content)
                } else {
                    importError = "No se pudo leer el archivo (encoding)"
                }
            } else {
                importError = "Permiso denegado al archivo"
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    private func processCSV(_ content: String) {
        isLoading = true
        importError = nil

        Task {
            do {
                // 1. Local Parsing
                let raw = try CSVParser.parse(content)
                importedTransactions = raw

                // 2. AI Categorization — usar categorías REALES del user (no hardcoded).
                let userCategories = UserDataManager.shared.categories.map(\.name)
                let categories = userCategories.isEmpty
                    ? ["Otros"]  // user sin cats: AI devolverá "Otros", fallback a primera del user después
                    : userCategories
                let descriptions = raw.map { $0.description }

                let mapping = try await AIServiceManager.shared.categorizeExpenses(
                    descriptions: descriptions, categories: categories)

                // 3. Apply Categories — fallback a primera del user (no string hardcoded)
                let fallbackCat = userCategories.first ?? "Otros"
                categorizedTransactions = raw.map { tx in
                    var newTx = tx
                    let suggested = mapping[tx.description] ?? fallbackCat
                    // Validar que el AI devolvió una categoría que SÍ existe
                    newTx.category = userCategories.contains(suggested) ? suggested : fallbackCat
                    return newTx
                }

                isLoading = false
                showReview = true

            } catch {
                isLoading = false
                importError = error.localizedDescription
            }
        }
    }
}

// MARK: - Review View (Placeholder)

struct ImportReviewView: View {
    let transactions: [RawTransaction]
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false

    // Dependencies
    private let expenseRepository = DependencyContainer.shared.expenseRepository

    var body: some View {
        List {
            ForEach(transactions) { tx in
                HStack {
                    VStack(alignment: .leading) {
                        Text(tx.description).font(.headline)
                        Text(tx.date.formatted(date: .numeric, time: .omitted)).font(.caption)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(tx.amount, format: .currency(code: "EUR"))
                        Text(tx.category ?? "-")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .navigationTitle("Revisar (\(transactions.count))")
        .disabled(isSaving)
        .toolbar {
            Button {
                saveTransactions()
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Guardar Todo")
                }
            }
        }
    }

    private func saveTransactions() {
        isSaving = true
        Task {
            // Bulk save
            // Convert RawTransaction to Expense
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            let expenses = transactions.map { tx in
                // Note: ID will be generated by Model/Repository if needed, or we use UUID()
                let dateStr = formatter.string(from: tx.date)

                let fallbackCat = UserDataManager.shared.categories.first?.name ?? "Otros"
                return Expense(
                    amount: tx.amount,
                    name: tx.description,
                    category: tx.category ?? fallbackCat,
                    date: dateStr,
                    paymentMethod: PaymentMethod.tarjeta.rawValue,
                    notes: "Importado CSV"
                )
            }

            // Loop save (since repo doesn't have bulk add yet, or we assume it handles it fast enough locally)
            // Ideally we'd add `addExpenses(_ expenses: [Expense])` to repo, but loop is fine for <100
            for expense in expenses {
                _ = try? await expenseRepository.addExpense(expense)
            }

            HapticManager.shared.notification(.success)
            isSaving = false
            dismiss()
        }
    }
}
