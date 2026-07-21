//
//  BrandColors.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

extension Color {
    // Mugshot Design handoff palette.
    static let mugshotMint = Color(hex: "A8CDB8")
    static let mugshotSage = Color(hex: "6E8F7C")
    static let mugshotMatcha = Color(hex: "8FAF6A")
    static let mugshotLatte = Color(hex: "DCC8A6")
    // Map ratings keep the familiar green/yellow/red meaning while using
    // softened, earthy hues that sit naturally beside the Mugshot palette.
    static let mapPinHigh = Color(hex: "4F8A68")
    static let mapPinMiddle = Color(hex: "D4AD55")
    static let mapPinLow = Color(hex: "C26355")
    static let creamWhite = Color(hex: "FAF6F0")
    static let foamWhite = Color(hex: "FFFFFF")
    static let espressoBrown = Color(hex: "1F1712")
    static let roastBrown = Color(hex: "5B4636")
    static let darkRoast = Color(hex: "2B1F17")
    static let sandBeige = Color(hex: "EEE6D8")
    static let mugshotLine = Color(hex: "E3DED4")
    static let sageGray = Color(hex: "A8CDB8")
    
    // Text colors (explicit, non-adaptive)
    static let primaryText = Color.espressoBrown
    static let secondaryText = Color.roastBrown
    static let tertiaryText = Color.roastBrown.opacity(0.62)
    
    // Input colors
    static let inputBackground = Color.foamWhite
    static let inputBorder = Color.mugshotLine
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
