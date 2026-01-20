// ErrorHandler.swift
// Centralized error handling for the application

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ErrorHandler {
    static let shared = ErrorHandler()
    
    var currentError: AppError?
    var showError = false
    
    private init() {}
    
    func handle(_ error: Error) {
        if let appError = error as? AppError {
            currentError = appError
        } else {
            currentError = .unknown(error.localizedDescription)
        }
        showError = true
    }
    
    func dismiss() {
        showError = false
        currentError = nil
    }
}
