// DesignTokens.swift
// Centralized Access Point for Strict Design Tokens
// "One Source of Truth"

import SwiftUI

/// DesignTokens centraliza el acceso a todos los tokens de diseño de la app.
/// Úsalo en lugar de acceder a Spacing, Colors o Typography individualmente
/// para asegurar consistencia.
enum DesignTokens {
    // MARK: - Spacing
    /// Tokens de espaciado estricto (4px grid)
    enum Spacing {
        static let xxs = Clarity.Spacing.xxs   // 4
        static let xs  = Clarity.Spacing.xs    // 8
        static let sm  = Clarity.Spacing.sm    // 12
        static let md  = Clarity.Spacing.md    // 16
        static let lg  = Clarity.Spacing.lg    // 24
        static let xl  = Clarity.Spacing.xl    // 32
        static let xxl = Clarity.Spacing.xxl   // 48
    }
    
    // MARK: - Radii
    /// Tokens de radio para bordes
    enum Radius {
        static let small  = CornerRadius.small   // 12
        static let medium = CornerRadius.medium  // 16
        static let large  = CornerRadius.large   // 20
        static let xlarge = CornerRadius.xlarge  // 28
    }
    
    // MARK: - Colors
    /// Tokens de color semánticos
    enum Colors {
        static let primary   = Color.clarityPrimary
        static let secondary = Color.claritySecondary
        static let accent    = Color.clarityAccent
        
        static let textPrimary   = Color.textPrimary
        static let textSecondary = Color.textSecondary
        static let textTertiary  = Color.textTertiary
        
        static let background = Color.bgPrimary
        static let surface    = Color.bgSecondary
        
        static let success = Color.success
        static let error   = Color.error
        static let warning = Color.warning
    }
    
    // MARK: - Fonts
    /// (Placeholder) Futura integración con Typography.swift
    enum Fonts {
        static let header = Font.system(size: 34, weight: .bold)
        static let title  = Font.system(size: 20, weight: .semibold)
        static let body   = Font.system(size: 16, weight: .regular)
    }
}
