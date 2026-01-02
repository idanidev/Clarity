// Typography.swift
// App typography styles

import SwiftUI

extension Font {
    // MARK: - Display
    static let clarityLargeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let clarityTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let clarityTitle2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let clarityTitle3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    
    // MARK: - Body
    static let clarityHeadline = Font.system(size: 17, weight: .semibold)
    static let clarityBody = Font.system(size: 17, weight: .regular)
    static let clarityCallout = Font.system(size: 16, weight: .regular)
    static let claritySubheadline = Font.system(size: 15, weight: .regular)
    static let clarityFootnote = Font.system(size: 13, weight: .regular)
    static let clarityCaption = Font.system(size: 12, weight: .regular)
    static let clarityCaption2 = Font.system(size: 11, weight: .regular)
    
    // MARK: - Special
    static let clarityAmount = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let clarityAmountLarge = Font.system(size: 42, weight: .bold, design: .monospaced)
    static let clarityAmountSmall = Font.system(size: 18, weight: .semibold, design: .monospaced)
}

// MARK: - View Modifier for consistent styling
struct ClarityTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.clarityTitle)
            .foregroundStyle(.primary)
    }
}

extension View {
    func clarityTitleStyle() -> some View {
        modifier(ClarityTitleStyle())
    }
}
