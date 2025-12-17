//
//  ModernColors.swift
//  testMugshot
//
//  Modern Dark Mode color palette extension for DS.Colors
//  Implements glassmorphism-ready colors for premium dark theme
//

import SwiftUI

extension DS.Colors {
    // MARK: - Modern Dark Palette
    
    /// Deep Charcoal - Main background (NOT pure black)
    static let modernBackground = Color(hex: "121212")
    
    /// Elevated dark grey - For cards and surfaces
    static let modernSurface = Color(hex: "1C1C1C")
    
    /// Glass base color - Used with .ultraThinMaterial for glassmorphism
    static let modernGlass = Color(hex: "1E1E1E")
    
    /// Mugshot Mint - Primary accent for Modern theme
    static let modernAccent = Color(hex: "A5CBA1")
    
    /// Pure white - Primary text on dark backgrounds
    static let modernTextPrimary = Color.white
    
    /// Light grey - Secondary text on dark backgrounds
    static let modernTextSecondary = Color(hex: "B0B0B0")
    
    /// Dark grey - Tertiary text on dark backgrounds
    static let modernTextTertiary = Color(hex: "6E6E6E")
    
    /// Text color for content on mint backgrounds
    static let modernTextOnMint = Color(hex: "052E16")
    
    /// Icon color for inactive states in modern theme
    static let modernIconInactive = Color(hex: "808080")
    
    /// Divider color for modern theme
    static let modernDivider = Color.white.opacity(0.1)
    
    /// Border color for glass elements
    static let modernGlassBorder = Color.white.opacity(0.1)
}

// MARK: - Modern Shadow Specs

extension DS.Shadow {
    /// Subtle glow for glass cards in modern theme
    static let modernGlassCard = Spec(
        color: Color.black.opacity(0.3),
        radius: 20,
        x: 0,
        y: 8
    )
    
    /// Mint glow for FAB and primary elements
    static let modernMintGlow = Spec(
        color: DS.Colors.modernAccent.opacity(0.4),
        radius: 10,
        x: 0,
        y: 5
    )
    
    /// Strong shadow for elevated sheets and modals
    static let modernElevated = Spec(
        color: Color.black.opacity(0.5),
        radius: 30,
        x: 0,
        y: 12
    )
}


