// AnimationPresets.swift
// Standardized animations for Clarity

import SwiftUI

enum AnimationPresets {
    /// Smooth spring for navigation and large transitions
    static let smoothTransition = Animation.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)
    
    /// Bouncy spring for playful interactions (buttons, toggles)
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
    
    /// Quick spring for micro-interactions (checkboxes, selection)
    static let quick = Animation.spring(response: 0.2, dampingFraction: 0.7, blendDuration: 0)
    
    /// Slow ease for loading states or background changes
    static let slowEase = Animation.easeInOut(duration: 0.4)
    
    /// Standard touch down scale effect
    static let touchDownScale: CGFloat = 0.96
}

extension View {
    /// Applies a standard scale animation on press
    func scaleOnPress(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? AnimationPresets.touchDownScale : 1.0)
            .animation(AnimationPresets.quick, value: isPressed)
    }
}
