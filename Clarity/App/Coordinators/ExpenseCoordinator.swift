// ExpenseCoordinator.swift
// Protocol-oriented coordinator for expense actions (Swift 6)

import Foundation
import Observation

// MARK: - Protocol

@MainActor
protocol ExpenseActionHandling: Sendable {
    func handleVoiceInput() async
    func handleManualInput()
    func handleRecurringInput()
    func dismissSheet()
}

// MARK: - Implementation

@MainActor
@Observable
final class ExpenseCoordinator: ExpenseActionHandling {
    
    // MARK: - State
    var activeSheet: SheetType?
    
    // MARK: - Dependencies
    private let speechManager: SpeechRecognitionManager
    private let voiceCoordinator: VoiceExpenseCoordinator
    
    // MARK: - Init
    init(
        speechManager: SpeechRecognitionManager,
        voiceCoordinator: VoiceExpenseCoordinator
    ) {
        self.speechManager = speechManager
        self.voiceCoordinator = voiceCoordinator
    }
    
    // MARK: - Actions
    
    func handleVoiceInput() async {
        voiceCoordinator.handleButtonTap(speechManager: speechManager)
        activeSheet = .voiceRecording
    }
    
    func handleManualInput() {
        activeSheet = .manualExpense
    }
    
    func handleRecurringInput() {
        activeSheet = .recurringExpenses
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
}
