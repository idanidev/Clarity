// Spacing.swift
// App spacing constants

import SwiftUI

enum Spacing {
    // MARK: - Base Spacing
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    
    // MARK: - Card
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 12
    static let cardShadowRadius: CGFloat = 8
    
    // MARK: - Button
    static let buttonPadding: CGFloat = 16
    static let buttonRadius: CGFloat = 12
    static let buttonHeight: CGFloat = 50
    
    // MARK: - Input
    static let inputPadding: CGFloat = 14
    static let inputRadius: CGFloat = 10
    
    // MARK: - Tab Bar
    static let tabBarHeight: CGFloat = 80
    static let fabSize: CGFloat = 56
    static let fabSmallSize: CGFloat = 44
    static let fabOffset: CGFloat = 20
    
    // MARK: - List Rows
    static let rowPadding: CGFloat = 14
    static let categoryIndent: CGFloat = 0
    static let subcategoryIndent: CGFloat = 24
    static let expenseIndent: CGFloat = 44
    static let leftBorderWidth: CGFloat = 3
}

// MARK: - Card Style Modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
    }
}

// MARK: - Dark Card Style (with border)
struct DarkCardStyle: ViewModifier {
    var isSelected: Bool = false
    var accentColor: Color = .clarityPrimary
    
    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(isSelected ? accentColor : Color.borderDefault, lineWidth: isSelected ? 2 : 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func darkCardStyle(isSelected: Bool = false, accentColor: Color = Color.clarityPrimary) -> some View {
        modifier(DarkCardStyle(isSelected: isSelected, accentColor: accentColor))
    }
}
