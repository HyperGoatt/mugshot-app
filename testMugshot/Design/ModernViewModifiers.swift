//
//  ModernViewModifiers.swift
//  testMugshot
//
//  Reusable view modifiers for Modern Dark Mode glassmorphism effects
//

import SwiftUI

// MARK: - Glassmorphism Modifiers

extension View {
    /// Standard glass background for cards and containers
    /// Combines ultraThinMaterial blur with tinted glass overlay
    func modernGlassBackground(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(DS.Colors.modernGlass.opacity(0.6))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
            )
    }
    
    /// Floating glass effect with stronger elevation
    /// Used for tab bar, floating buttons, and prominent UI elements
    func modernFloatingGlass(cornerRadius: CGFloat = 30) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(DS.Colors.modernSurface.opacity(0.8))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
            )
            .shadow(
                color: DS.Shadow.modernGlassCard.color,
                radius: DS.Shadow.modernGlassCard.radius,
                x: DS.Shadow.modernGlassCard.x,
                y: DS.Shadow.modernGlassCard.y
            )
    }
    
    /// Complete modern card style with glass background and shadow
    func modernCardStyle(cornerRadius: CGFloat = 20, withShadow: Bool = true) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(DS.Colors.modernGlass.opacity(0.6))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
            )
            .modifier(ConditionalShadow(apply: withShadow))
    }
    
    /// Mint glow effect for FAB and primary actions
    func modernMintGlow() -> some View {
        self.shadow(
            color: DS.Shadow.modernMintGlow.color,
            radius: DS.Shadow.modernMintGlow.radius,
            x: DS.Shadow.modernMintGlow.x,
            y: DS.Shadow.modernMintGlow.y
        )
    }
}

// MARK: - Helper Modifiers

private struct ConditionalShadow: ViewModifier {
    let apply: Bool
    
    func body(content: Content) -> some View {
        if apply {
            content.shadow(
                color: DS.Shadow.modernGlassCard.color,
                radius: DS.Shadow.modernGlassCard.radius / 2,
                x: DS.Shadow.modernGlassCard.x,
                y: DS.Shadow.modernGlassCard.y / 2
            )
        } else {
            content
        }
    }
}

// MARK: - Modern Typography Styles

extension View {
    /// Apply modern hero text style (white, bold, large)
    func modernHeroText() -> some View {
        self
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(DS.Colors.modernTextPrimary)
    }
    
    /// Apply modern heading text style
    func modernHeadingText() -> some View {
        self
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(DS.Colors.modernTextPrimary)
    }
    
    /// Apply modern body text style
    func modernBodyText() -> some View {
        self
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(DS.Colors.modernTextSecondary)
    }
    
    /// Apply modern caption text style (uppercase, tracked)
    func modernCaptionText() -> some View {
        self
            .font(.system(size: 13, weight: .medium))
            .textCase(.uppercase)
            .kerning(0.5)
            .foregroundColor(DS.Colors.modernTextTertiary)
    }
}

// MARK: - Modern Button Styles

struct ModernPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(isEnabled ? DS.Colors.modernTextOnMint : DS.Colors.modernTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? DS.Colors.modernAccent : DS.Colors.modernSurface)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

struct ModernGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .modernGlassBackground(cornerRadius: 20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}


