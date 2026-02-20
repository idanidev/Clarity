// SalarySettingsSheetWrapper.swift
import SwiftUI

struct SalarySettingsSheetWrapper: View {
    @Bindable var viewModel: FinancialHubViewModel

    // Local state to hold edits before saving
    @State private var tempIncome: Double = 0
    @State private var tempRecurring: Bool = false

    var body: some View {
        SalarySettingsSheet(
            income: $tempIncome,
            isRecurring: $tempRecurring,
            onSave: {
                Task {
                    await viewModel.updateSalarySettings(
                        amount: tempIncome, recurring: tempRecurring)
                }
            }
        )
        .onAppear {
            tempIncome = viewModel.income
            tempRecurring = viewModel.isSalaryRecurring
        }
    }
}
