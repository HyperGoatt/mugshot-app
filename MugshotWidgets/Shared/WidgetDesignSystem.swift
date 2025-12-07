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
        
        // Gradient colors
        static let mintTintedBackground = Color(hex: "F0F9F0")  // Subtle mint tint
        static let orangeGradient = Color(hex: "FF6B35")        // For streak flames
        static let yellowGradient = Color(hex: "FFA500")        // For featured content
    }
    
    // MARK: - Gradients
    
    enum Gradients {
        static let mintSubtle = LinearGradient(
            colors: [Colors.mintSoftFill, Colors.neutralCard],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let mintBold = LinearGradient(
            colors: [Colors.mintLight, Colors.mintMain],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let blueSubtle = LinearGradient(
            colors: [Colors.blueSoftFill, Colors.neutralCard],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let flame = LinearGradient(
            colors: [Colors.yellowAccent, Colors.orangeGradient],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let featured = LinearGradient(
            colors: [Colors.yellowAccent.opacity(0.3), Colors.neutralCard],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Hero typography for maximum impact
        static let displayLarge = Font.system(size: 36, weight: .bold)      // Reduced from 48
        static let displayMedium = Font.system(size: 28, weight: .bold)     // Reduced from 36
        static let displaySmall = Font.system(size: 22, weight: .bold)      // Reduced from 28
        
        // Widget titles and content
        static let widgetTitle = Font.system(size: 14, weight: .bold)       // Reduced from 18
        static let contentTitle = Font.system(size: 15, weight: .semibold)  // Reduced from 18
        static let contentBody = Font.system(size: 13, weight: .regular)    // Reduced from 15
        static let badgeText = Font.system(size: 11, weight: .semibold)     // Reduced from 13
        
        // Legacy (kept for compatibility)
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
        static let xxl: CGFloat = 20
        
        // Layout-specific spacing
        static let widgetPadding: CGFloat = 14      // Reduced from 18
        static let contentSpacing: CGFloat = 10     // Reduced from 14
        static let sectionSpacing: CGFloat = 16     // Reduced from 20
        static let rowSpacing: CGFloat = 12         // Reduced from 16
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

// MARK: - Enhanced Icon Frame with Gradient

struct EnhancedIconFrame: View {
    let icon: String
    let size: CGFloat
    let gradient: LinearGradient
    let iconColor: Color
    
    init(
        icon: String,
        size: CGFloat = 48,
        gradient: LinearGradient = WidgetDS.Gradients.mintSubtle,
        iconColor: Color = WidgetDS.Colors.primaryAccent
    ) {
        self.icon = icon
        self.size = size
        self.gradient = gradient
        self.iconColor = iconColor
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WidgetDS.Radius.md)
                .fill(gradient)
            
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(iconColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Enhanced Badge/Pill Component

struct EnhancedBadge: View {
    let text: String
    let icon: String?
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(
        text: String,
        icon: String? = nil,
        backgroundColor: Color = WidgetDS.Colors.blueSoftFill,
        foregroundColor: Color = WidgetDS.Colors.blueAccent
    ) {
        self.text = text
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(WidgetDS.Typography.badgeText)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(WidgetDS.Radius.pill)
    }
}

// MARK: - Enhanced Rating Display

struct EnhancedRatingDisplay: View {
    let rating: Double
    let showStars: Bool
    let size: CGFloat
    
    init(rating: Double, showStars: Bool = true, size: CGFloat = 12) {
        self.rating = rating
        self.showStars = showStars
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if showStars {
                WidgetStarRating(rating: rating, size: size)
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundColor(WidgetDS.Colors.yellowAccent)
            }
            Text(String(format: "%.1f", rating))
                .font(.system(size: size + 2, weight: .semibold))
                .foregroundColor(WidgetDS.Colors.textPrimary)
        }
    }
}

// MARK: - Distance Badge

struct DistanceBadge: View {
    let distance: String
    let isProminent: Bool
    
    init(distance: String, isProminent: Bool = false) {
        self.distance = distance
        self.isProminent = isProminent
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "figure.walk")
                .font(.system(size: isProminent ? 14 : 11, weight: .semibold))
            Text(distance)
                .font(.system(size: isProminent ? 18 : 13, weight: .bold))
        }
        .foregroundColor(WidgetDS.Colors.blueAccent)
        .padding(.horizontal, isProminent ? 12 : 8)
        .padding(.vertical, isProminent ? 8 : 5)
        .background(WidgetDS.Colors.blueSoftFill)
        .cornerRadius(WidgetDS.Radius.pill)
    }
}

// MARK: - Widget Header Component

struct WidgetHeader: View {
    let icon: String
    let title: String
    let iconColor: Color
    
    init(icon: String, title: String, iconColor: Color = WidgetDS.Colors.primaryAccent) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(WidgetDS.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
    }
}

