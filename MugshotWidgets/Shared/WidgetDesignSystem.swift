//
//  WidgetDesignSystem.swift
//  MugshotWidgets
//
//  Design system tokens for Mugshot widgets, mirroring the main app's DSTheme
//

import SwiftUI
import WidgetKit

// MARK: - Widget Design System

enum WidgetDS {
    // MARK: - Colors
    
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
        static let iconDefault = Color(hex: "6B7280")
        static let iconSubtle = Color(hex: "9CA3AF")
        
        // Roles
        static let widgetBackground = neutralBackground
        static let cardBackground = neutralCard
        static let primaryAccent = mintMain
        static let secondaryAccent = blueAccent
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let title = Font.system(size: 17, weight: .semibold)
        static let headline = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 11, weight: .regular)
        static let statNumber = Font.system(size: 28, weight: .bold)
        static let smallStat = Font.system(size: 20, weight: .semibold)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let pill: CGFloat = 999
    }
}

// MARK: - Color Hex Extension

extension Color {
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

// MARK: - Star Rating View for Widgets

struct WidgetStarRating: View {
    let rating: Double
    let maxRating: Int = 5
    let size: CGFloat
    let color: Color
    
    init(rating: Double, size: CGFloat = 10, color: Color = WidgetDS.Colors.yellowAccent) {
        self.rating = rating
        self.size = size
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<maxRating, id: \.self) { index in
                starImage(for: index)
                    .font(.system(size: size))
                    .foregroundColor(starColor(for: index))
            }
        }
    }
    
    private func starImage(for index: Int) -> some View {
        let fillLevel = rating - Double(index)
        if fillLevel >= 1 {
            return Image(systemName: "star.fill")
        } else if fillLevel >= 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }
    
    private func starColor(for index: Int) -> Color {
        let fillLevel = rating - Double(index)
        if fillLevel >= 0.5 {
            return color
        } else {
            return WidgetDS.Colors.textTertiary.opacity(0.3)
        }
    }
}

// MARK: - Avatar View for Widgets

struct WidgetAvatar: View {
    let imageURL: String?
    let initials: String
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(WidgetDS.Colors.mintSoftFill)
            
            if let urlString = imageURL, let url = URL(string: urlString) {
                // Note: Widgets have limited network access; AsyncImage may not work reliably
                // For production, consider caching images in the App Group container
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        initialsView
                    case .empty:
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
    }
    
    private var initialsView: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundColor(WidgetDS.Colors.textOnMint)
    }
}

// MARK: - Empty State View for Widgets

struct WidgetEmptyState: View {
    let icon: String
    let message: String
    let ctaText: String?
    
    var body: some View {
        VStack(spacing: WidgetDS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(WidgetDS.Colors.primaryAccent)
            
            Text(message)
                .font(WidgetDS.Typography.caption)
                .foregroundColor(WidgetDS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            if let cta = ctaText {
                Text(cta)
                    .font(WidgetDS.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(WidgetDS.Colors.primaryAccent)
            }
        }
        .padding(WidgetDS.Spacing.lg)
    }
}

// MARK: - Mugsy Mascot View

struct WidgetMugsyIcon: View {
    let size: CGFloat
    
    var body: some View {
        // Use a coffee cup SF Symbol as placeholder for Mugsy mascot
        Image(systemName: "cup.and.saucer.fill")
            .font(.system(size: size))
            .foregroundColor(WidgetDS.Colors.primaryAccent)
    }
}

