//
//  BrandColors.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

extension Color {
    // Mugshot Brand Colors — tuned to the Mugshot design system
    // (warm cream canvas, sage green accents, deep espresso ink).

    /// Soft sage green — primary accent fills (buttons, selected chips).
    static let mugshotMint = Color(hex: "B6CFB8")
    /// Near-white warm cream — card and surface background.
    static let creamWhite = Color(hex: "FBF8F2")
    /// Deep espresso ink — primary text.
    static let espressoBrown = Color(hex: "3D322A")
    /// Warm sand — borders, dividers, secondary fills.
    static let sandBeige = Color(hex: "E8E0D2")
    /// Muted sage gray — tertiary surfaces.
    static let sageGray = Color(hex: "C9CCC3")

    /// Deep forest green — filled CTAs, star ratings, selected states.
    static let mugshotForest = Color(hex: "4D6B54")
    /// Very soft sage — tag chip backgrounds and tinted panels.
    static let mugshotSageSoft = Color(hex: "DFE9DC")
    /// Warm cream canvas — screen background behind cards.
    static let mugshotCanvas = Color(hex: "F4EFE6")
    /// Warm tan — mid-tier rating signal on the map.
    static let mugshotTan = Color(hex: "C2A370")
    /// Muted clay — low-tier rating signal on the map.
    static let mugshotClay = Color(hex: "B87361")

    // Text colors (explicit, non-adaptive)
    static let primaryText = Color.espressoBrown
    static let secondaryText = Color.espressoBrown.opacity(0.7)
    static let tertiaryText = Color.espressoBrown.opacity(0.6)

    // Input colors
    static let inputBackground = Color.creamWhite
    static let inputBorder = Color.sandBeige
    static let inputText = Color.espressoBrown
    static let inputPlaceholder = Color.espressoBrown.opacity(0.5)

    // Helper initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
