// SalarySettingsSheetWrapper.swift
// Sheet wrapper sobre el hub unificado de nóminas.

import SwiftUI

struct SalarySettingsSheetWrapper: View {
    @Bindable var viewModel: FinancialHubViewModel

    var body: some View {
        NavigationStack {
            SalarySettingsStandaloneView()
        }
        .presentationDetents([.large])
        .onDisappear {
            // Refrescar settings del Hub al cerrar (por si cambiaron sueldo/recurring)
            Task { await viewModel.reload() }
        }
    }
}
