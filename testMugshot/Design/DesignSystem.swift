//
//  DesignSystem.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

// Design system components for consistent styling
struct DesignSystem {
    // Corner radius
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let largeCornerRadius: CGFloat = 22

    // Spacing
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    static let largePadding: CGFloat = 24

    // Shadows
    static let cardShadow = Shadow(color: Color.espressoBrown.opacity(0.07), radius: 10, x: 0, y: 3)

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// Card style modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.creamWhite)
            .cornerRadius(DesignSystem.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .stroke(Color.sandBeige.opacity(0.6), lineWidth: 1)
            )
            .shadow(
                color: DesignSystem.cardShadow.color,
                radius: DesignSystem.cardShadow.radius,
                x: DesignSystem.cardShadow.x,
                y: DesignSystem.cardShadow.y
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// Button styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, DesignSystem.largePadding)
            .frame(minHeight: 54)
            .background(Color.mugshotMint)
            .foregroundColor(Color.espressoBrown)
            .cornerRadius(DesignSystem.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, DesignSystem.largePadding)
            .frame(minHeight: 54)
            .background(Color.creamWhite)
            .foregroundColor(Color.espressoBrown)
            .cornerRadius(DesignSystem.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .stroke(Color.sandBeige, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Deep forest filled button for high-emphasis CTAs (per design system).
struct ForestButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, DesignSystem.largePadding)
            .frame(minHeight: 54)
            .background(Color.mugshotForest)
            .foregroundColor(Color.creamWhite)
            .cornerRadius(DesignSystem.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Custom text field style for Mugshot
struct MugshotTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.inputText)
            .tint(.mugshotForest) // Cursor color
    }
}

extension TextField {
    func mugshotStyle() -> some View {
        self
            .foregroundColor(.inputText)
            .tint(.mugshotForest)
            .accentColor(.mugshotForest)
    }
}
