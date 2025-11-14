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
    static let cornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8
    static let largeCornerRadius: CGFloat = 16
    
    // Spacing
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    static let largePadding: CGFloat = 24
    
    // Shadows
    static let cardShadow = Shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    
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
            .padding(.horizontal, DesignSystem.largePadding)
            .padding(.vertical, DesignSystem.padding)
            .background(Color.mugshotMint)
            .foregroundColor(Color.espressoBrown)
            .cornerRadius(DesignSystem.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignSystem.largePadding)
            .padding(.vertical, DesignSystem.padding)
            .background(Color.sandBeige)
            .foregroundColor(Color.espressoBrown)
            .cornerRadius(DesignSystem.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Custom text field style for Mugshot
struct MugshotTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.inputText)
            .tint(.mugshotMint) // Cursor color
    }
}

extension TextField {
    func mugshotStyle() -> some View {
        self
            .foregroundColor(.inputText)
            .tint(.mugshotMint)
            .accentColor(.mugshotMint)
    }
}

