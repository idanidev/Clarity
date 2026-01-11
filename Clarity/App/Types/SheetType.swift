// SheetType.swift
// Single source of truth for all sheet presentations

import Foundation

enum SheetType: Identifiable, Sendable {
    case voiceRecording
    case voiceConfirmation(Expense, wasFullyDetected: Bool)
    case manualExpense
    case recurringExpenses
    
    var id: String {
        switch self {
        case .voiceRecording: "voice"
        case .voiceConfirmation: "confirmation"
        case .manualExpense: "manual"
        case .recurringExpenses: "recurring"
        }
    }
}

// MARK: - Sendable Conformance
