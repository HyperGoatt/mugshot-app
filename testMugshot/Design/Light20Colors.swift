//
//  Light20Colors.swift
//  testMugshot
//
//  Light 2.0 color palette - Premium curated design system
//  Elevated contrast, strategic mint accents, and floating card aesthetics
//

import SwiftUI

extension DS.Colors {
    // MARK: - Light 2.0 Palette
    
    /// Pure crisp white - Main canvas background
    static let light20Background = Color(hex: "FFFFFF")
    
    /// Very subtle off-white - For subtle layering and separation
    static let light20Surface = Color(hex: "F8F8F8")
    
    /// Rich charcoal black - Primary text (NOT pure black for premium feel)
    static let light20CharcoalBlack = Color(hex: "1A1A1A")
    
    /// Soft grey - Secondary text and labels
    static let light20TextSecondary = Color(hex: "707070")
    
    /// Very light grey - Tertiary text and subtle metadata
    static let light20TextTertiary = Color(hex: "9CA3AF")
    
    /// Vibrant strategic mint - Primary accent for CTAs and active states ONLY
    static let light20MintPrimary = Color(hex: "3A9D41")
    
    /// Pure white - Text on mint backgrounds
    static let light20TextOnMint = Color.white
    
    /// Darker mint tint for hover/pressed states
    static let light20MintHover = Color(hex: "2F8235")
    
    /// Soft mint fill for subtle backgrounds (rare use)
    static let light20MintSoftFill = Color(hex: "ECF8EC")
    
    /// Light grey - Borders and outlines
    static let light20BorderLight = Color(hex: "E0E0E0")
    
    /// Divider color - Same as border for consistency
    static let light20Divider = Color(hex: "E5E7EB")
    
    /// Icon color for inactive states
    static let light20IconInactive = Color(hex: "9CA3AF")
    
    /// Yellow accent for mid-range ratings (3.0-3.9)
    static let light20YellowAccent = Color(hex: "F59E0B")
    
    /// Red accent for low ratings (<3.0) and negative states
    static let light20RedAccent = Color(hex: "EF4444")
    
    /// Green for high ratings (≥4.0) - matches mint for consistency
    static let light20GreenAccent = Color(hex: "3A9D41")
    
    /// Blue accent for "want to try" markers
    static let light20BlueAccent = Color(hex: "2563EB")
}

// MARK: - Light 2.0 Shadow Specifications

extension DS.Shadow {
    /// Ultra-subtle floating card shadow for Light 2.0 theme
    /// Long-throw shadow with very low opacity for premium depth
    static let light20FloatingCard = Spec(
        color: Color.black.opacity(0.04),
        radius: 24,
        x: 0,
        y: 8
    )
    
    /// Subtle mint glow for primary CTAs
    static let light20MintGlow = Spec(
        color: DS.Colors.light20MintPrimary.opacity(0.2),
        radius: 8,
        x: 0,
        y: 4
    )
    
    /// Stronger shadow for elevated elements (sheets, modals, important overlays)
    static let light20Elevated = Spec(
        color: Color.black.opacity(0.08),
        radius: 32,
        x: 0,
        y: 12
    )
    
    /// Soft shadow for buttons on press (interactive feedback)
    static let light20ButtonPress = Spec(
        color: Color.black.opacity(0.06),
        radius: 16,
        x: 0,
        y: 4
    )
}


