// Constants.swift
// App-wide constants

import Foundation

enum Constants {
    // Firebase
    static let firebaseProjectId = "clarity-gastos"
    static let firebaseAuthDomain = "clarity-gastos.firebaseapp.com"
    
    // Firestore Collections
    enum Collections {
        static let users = "users"
        static let expenses = "expenses"
        static let budgets = "budgets"
        static let categories = "categories"
        static let recurringExpenses = "recurringExpenses"
    }
    
    // Cloud Functions
    enum Functions {
        static let askDeepSeek = "askDeepSeek"
        static let createRecurringExpenses = "createRecurringExpenses"
    }
    
    // UserDefaults Keys
    enum UserDefaultsKeys {
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let preferredTheme = "preferredTheme"
        static let preferredLanguage = "preferredLanguage"
    }
    
    // Keychain Keys
    enum KeychainKeys {
        static let biometricEnabled = "biometricEnabled"
    }
    
    // UI
    enum UI {
        static let animationDuration: Double = 0.3
        static let hapticFeedbackEnabled = true
    }
    
    // Limits
    enum Limits {
        static let maxExpenseAmount: Double = 999999.99
        static let maxNoteLenth = 500
        static let maxCategoryNameLength = 50
    }
}
