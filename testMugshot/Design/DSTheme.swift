//
//  DSTheme.swift
//  testMugshot
//
//  Centralized mapping of design-system.json tokens to SwiftUI-friendly types.
//  This file mirrors the JSON spec values as code constants to enforce a single source of truth in UI.
//

import SwiftUI

enum DS {
    enum Colors {
        // Palette
        static let mintLight = Color(hex: "D6F0D6")
        static let mintMain = Color(hex: "B7E2B5")
        static let mintDark = Color(hex: "8AC28E")
        static let mintSoftFill = Color(hex: "ECF8EC")
        static let blueAccent = Color(hex: "2563EB")
        static let blueSoftFill = Color(hex: "E5F0FF")
        static let yellowAccent = Color(hex: "FACC15")
        static let redAccent = Color(hex: "EF4444")
        static let neutralBackground = Color(hex: "F5F5F7")
        static let neutralCard = Color(hex: "FFFFFF")
        static let neutralCardAlt = Color(hex: "F9FAFB")
        static let neutralBorder = Color(hex: "E5E7EB")
        static let neutralDivider = Color(hex: "E5E7EB")
        static let textPrimary = Color(hex: "111827")
        static let textSecondary = Color(hex: "6B7280")
        static let textTertiary = Color(hex: "9CA3AF")
        static let textOnMint = Color(hex: "052E16")
        static let textOnBlue = Color(hex: "0B1120")
        static let iconDefault = Color(hex: "6B7280")
        static let iconSubtle = Color(hex: "9CA3AF")
        
        // Roles
        static let appBarBackground = mintLight
        static let screenBackground = neutralBackground
        static let cardBackground = neutralCard
        static let cardBackgroundAlt = neutralCardAlt
        static let primaryAccent = mintMain
        static let primaryAccentHover = mintDark
        static let primaryAccentSoftFill = mintSoftFill
        static let secondaryAccent = blueAccent
        static let dividerSubtle = neutralDivider
        static let borderSubtle = neutralBorder
        static let positiveChange = mintMain
        static let negativeChange = redAccent
        static let neutralChange = yellowAccent
    }
    
    enum Typography {
        // Scale
        static func display(_ weight: Font.Weight = .bold) -> Font { .system(size: 34, weight: weight) }
        static func title1(_ weight: Font.Weight = .bold) -> Font { .system(size: 28, weight: weight) }
        static func title2(_ weight: Font.Weight = .semibold) -> Font { .system(size: 22, weight: weight) }
        static func headline(_ weight: Font.Weight = .semibold) -> Font { .system(size: 17, weight: weight) }
        static func body(_ weight: Font.Weight = .regular) -> Font { .system(size: 17, weight: weight) }
        static func callout(_ weight: Font.Weight = .regular) -> Font { .system(size: 16, weight: weight) }
        static func subheadline(_ weight: Font.Weight = .regular) -> Font { .system(size: 15, weight: weight) }
        static func caption1(_ weight: Font.Weight = .regular) -> Font { .system(size: 13, weight: weight) }
        static func caption2(_ weight: Font.Weight = .regular) -> Font { .system(size: 11, weight: weight) }
        static func statNumber(_ weight: Font.Weight = .semibold) -> Font { .system(size: 24, weight: weight) }
        
        // Role mapping
        static var screenTitle: Font { title1(.bold) }
        static var sectionTitle: Font { headline(.semibold) }
        static var cardTitle: Font { headline(.semibold) }
        static var cardSubtitle: Font { subheadline(.regular) }
        static var bodyText: Font { body(.regular) }
        static var metaLabel: Font { caption2(.regular) }
        static var pillLabel: Font { caption1(.regular) }
        static var buttonLabel: Font { headline(.semibold) }
        static var numericStat: Font { statNumber(.semibold) }
    }
    
    enum Spacing {
        // Unit = 4
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let section: CGFloat = 32
        static let pagePadding: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let cardPaddingDense: CGFloat = 12
        static let cardVerticalGap: CGFloat = 12
        static let sectionVerticalGap: CGFloat = 24
        static let listItemGap: CGFloat = 10
    }
    
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 999
        
        // Usage shortcuts
        static let card = xl
        static let primaryButton = lg
        static let chip = pill
        static let segmentedContainer = pill
        static let segmentedOption = pill
    }
    
    enum Shadow {
        struct Spec {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        static let cardSoft = Spec(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 6)
        static let cardLifted = Spec(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
    }
}

// MARK: - Convenience View Modifiers

extension View {
    func dsCardShadow() -> some View {
        shadow(color: DS.Shadow.cardSoft.color,
               radius: DS.Shadow.cardSoft.radius,
               x: DS.Shadow.cardSoft.x,
               y: DS.Shadow.cardSoft.y)
    }
    
    func dsLiftedShadow() -> some View {
        shadow(color: DS.Shadow.cardLifted.color,
               radius: DS.Shadow.cardLifted.radius,
               x: DS.Shadow.cardLifted.x,
               y: DS.Shadow.cardLifted.y)
    }
}


