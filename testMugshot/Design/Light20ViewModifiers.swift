//
//  Light20ViewModifiers.swift
//  testMugshot
//
//  Light 2.0 view modifiers - Premium tactile interactions
//  Floating cards, pill buttons, parallax effects, and refined animations
//

import SwiftUI

// MARK: - Light 2.0 Card Modifiers

extension View {
    /// Standard floating card for Light 2.0 theme
    /// Pure white background with ultra-subtle long-throw shadow
    func light20FloatingCard(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(DS.Colors.light20Background)
            .cornerRadius(cornerRadius)
            .shadow(
                color: DS.Shadow.light20FloatingCard.color,
                radius: DS.Shadow.light20FloatingCard.radius,
                x: DS.Shadow.light20FloatingCard.x,
                y: DS.Shadow.light20FloatingCard.y
            )
    }
    
    /// Floating card with border for additional emphasis
    func light20FloatingCardWithBorder(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(DS.Colors.light20Background)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.Colors.light20BorderLight, lineWidth: 1)
            )
            .shadow(
                color: DS.Shadow.light20FloatingCard.color,
                radius: DS.Shadow.light20FloatingCard.radius,
                x: DS.Shadow.light20FloatingCard.x,
                y: DS.Shadow.light20FloatingCard.y
            )
    }
    
    /// Elevated card with stronger shadow for modals and sheets
    func light20ElevatedCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(DS.Colors.light20Background)
            .cornerRadius(cornerRadius)
            .shadow(
                color: DS.Shadow.light20Elevated.color,
                radius: DS.Shadow.light20Elevated.radius,
                x: DS.Shadow.light20Elevated.x,
                y: DS.Shadow.light20Elevated.y
            )
    }
}

// MARK: - Light 2.0 Button Styles

/// Primary wide mint pill button for CTAs
struct Light20PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(isEnabled ? DS.Colors.light20TextOnMint : DS.Colors.light20TextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? DS.Colors.light20MintPrimary : DS.Colors.light20Surface)
            .cornerRadius(DS.Radius.pill)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(
                color: isEnabled && !configuration.isPressed ? DS.Shadow.light20MintGlow.color : Color.clear,
                radius: DS.Shadow.light20MintGlow.radius,
                x: DS.Shadow.light20MintGlow.x,
                y: DS.Shadow.light20MintGlow.y
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

/// Outline button (white background, light border, charcoal text)
struct Light20OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(DS.Colors.light20CharcoalBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DS.Colors.light20Background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.Colors.light20BorderLight, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Compact pill chip for filters and categories
struct Light20PillChipStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
            .foregroundColor(isSelected ? DS.Colors.light20TextOnMint : DS.Colors.light20CharcoalBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? DS.Colors.light20MintPrimary : DS.Colors.light20Background)
            .cornerRadius(DS.Radius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.pill)
                    .stroke(isSelected ? Color.clear : DS.Colors.light20BorderLight, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Icon button with subtle background
struct Light20IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(DS.Colors.light20CharcoalBlack)
            .frame(width: 44, height: 44)
            .background(DS.Colors.light20Surface)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Light 2.0 Typography Helpers

extension View {
    /// Apply Light 2.0 hero text style (extra bold, large)
    func light20HeroText() -> some View {
        self
            .font(.system(size: 40, weight: .heavy))
            .foregroundColor(DS.Colors.light20CharcoalBlack)
    }
    
    /// Apply Light 2.0 display numbers style (KPIs - visits, ratings, etc.)
    func light20DisplayNumber() -> some View {
        self
            .font(.system(size: 48, weight: .heavy))
            .foregroundColor(DS.Colors.light20CharcoalBlack)
    }
    
    /// Apply Light 2.0 heading style (section titles)
    func light20Heading() -> some View {
        self
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(DS.Colors.light20CharcoalBlack)
    }
    
    /// Apply Light 2.0 subheading style (card titles)
    func light20Subheading() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(DS.Colors.light20CharcoalBlack)
    }
    
    /// Apply Light 2.0 body text style
    func light20BodyText() -> some View {
        self
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(DS.Colors.light20CharcoalBlack)
    }
    
    /// Apply Light 2.0 label style (secondary metadata)
    func light20Label() -> some View {
        self
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(DS.Colors.light20TextSecondary)
    }
    
    /// Apply Light 2.0 caption style (uppercase, tracked, tertiary)
    func light20Caption() -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .kerning(0.5)
            .foregroundColor(DS.Colors.light20TextSecondary)
    }
}

// MARK: - Light 2.0 Special Effects

extension View {
    /// Parallax scrolling effect for headers
    /// Use with GeometryReader to calculate offset
    func light20ParallaxOffset(offset: CGFloat, multiplier: CGFloat = 0.5) -> some View {
        self.offset(y: offset * multiplier)
    }
    
    /// Mint glow effect for primary elements
    func light20MintGlow() -> some View {
        self.shadow(
            color: DS.Shadow.light20MintGlow.color,
            radius: DS.Shadow.light20MintGlow.radius,
            x: DS.Shadow.light20MintGlow.x,
            y: DS.Shadow.light20MintGlow.y
        )
    }
    
    /// Tactile press effect - subtle scale down
    func light20TactilePress(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
    }
}

// MARK: - Light 2.0 Input Styles

/// Text field style for Light 2.0 theme
struct Light20TextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(DS.Colors.light20CharcoalBlack)
            .padding(14)
            .background(DS.Colors.light20Background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.Colors.light20BorderLight, lineWidth: 1)
            )
    }
}

// MARK: - Conditional Theme Modifiers

extension View {
    /// Apply theme-aware floating card
    func themeAwareFloatingCard(cornerRadius: CGFloat = 12) -> some View {
        Group {
            switch ThemeManager.shared.currentTheme {
            case .legacyLight:
                self
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(cornerRadius)
                    .dsCardShadow()
            case .light20:
                self.light20FloatingCard(cornerRadius: cornerRadius)
            case .modernDark:
                self.modernGlassBackground(cornerRadius: cornerRadius)
            }
        }
    }
}


