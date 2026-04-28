// Typography.swift
// App typography styles

import SwiftUI

extension Font {
    // MARK: - Display (Dynamic Type scalable)
    static let clarityLargeTitle = Font.largeTitle.weight(.bold).rounded()
    static let clarityTitle = Font.title.weight(.bold).rounded()
    static let clarityTitle2 = Font.title2.weight(.bold).rounded()
    static let clarityTitle3 = Font.title3.weight(.semibold).rounded()

    // MARK: - Body (Dynamic Type scalable)
    static let clarityHeadline = Font.headline
    static let clarityBody = Font.body
    static let clarityCallout = Font.callout
    static let claritySubheadline = Font.subheadline
    static let clarityFootnote = Font.footnote
    static let clarityCaption = Font.caption
    static let clarityCaption2 = Font.caption2

    // MARK: - Special (Dynamic Type scalable with monospaced digits)
    static let clarityAmount = Font.title.weight(.bold).monospaced()
    static let clarityAmountLarge = Font.largeTitle.weight(.bold).monospaced()
    static let clarityAmountSmall = Font.body.weight(.semibold).monospaced()
}

extension Font {
    func rounded() -> Font {
        self.width(.standard)
    }

    func monospaced() -> Font {
        self.monospacedDigit()
    }
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

    /// Applies a system font that scales with Dynamic Type settings.
    /// Use this instead of `.font(.system(size:))` for user-facing content.
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(baseSize: size, weight: weight, design: design))
    }
}

/// ViewModifier that creates a system font scaled via UIFontMetrics.
/// When the user changes their Dynamic Type preference, the font re-renders
/// at the appropriate scaled size while preserving the original proportions.
private struct ScaledFontModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        let scaled = UIFontMetrics.default.scaledValue(for: baseSize)
        content.font(.system(size: scaled, weight: weight, design: design))
    }
}
