// SalarySettingsStandaloneView.swift
// NavigationLink-compatible version of salary settings (no NavigationStack wrapper)
// Used from SettingsView and NotificationsView

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

struct SalarySettingsStandaloneView: View {
    @State private var editingIncome: String = ""
    @State private var isRecurring: Bool = false
    @State private var isSaving = false
    @State private var saveSuccess = false

    var body: some View {
        Form {
            // Income Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sueldo Base Mensual")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("€")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        TextField("0.00", text: $editingIncome)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                }
                .padding(.vertical, 8)
            }

            // Nómina Fija Section
            Section {
                Toggle("Nómina Fija", isOn: $isRecurring)
                    .tint(Color.clarityPrimary)
                    .onChange(of: isRecurring) { _, _ in
                        HapticManager.shared.selection()
                    }

                if isRecurring {
                    Text(
                        "Clarity creará el presupuesto mensual automáticamente con este importe. No tendrás que introducirlo cada mes."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(
                        "Si tu sueldo varía cada mes, mantén esto desactivado. Te preguntaremos tus ingresos al inicio de cada mes."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Automatización")
            }

            // Save Section
            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else if saveSuccess {
                            Label("Guardado", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Guardar Cambios")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("Ajustes de Sueldo")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadCurrentValues() }
    }

    private func loadCurrentValues() {
        guard let doc = UserDataManager.shared.userDocument else { return }
        let income = doc.income ?? 0
        editingIncome = income > 0 ? String(format: "%.2f", income) : ""
        isRecurring = doc.settings?.isSalaryRecurring ?? false
    }

    private func save() {
        guard let value = Double(editingIncome.replacingOccurrences(of: ",", with: ".")),
            let userId = Auth.auth().currentUser?.uid
        else { return }
        isSaving = true

        Task {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .updateData([
                        "income": value,
                        "settings.isSalaryRecurring": isRecurring,
                        "updatedAt": Timestamp(date: Date()),
                    ])
                await MainActor.run {
                    isSaving = false
                    saveSuccess = true
                    HapticManager.shared.playSuccess()
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { saveSuccess = false }
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SalarySettingsStandaloneView()
    }
}
