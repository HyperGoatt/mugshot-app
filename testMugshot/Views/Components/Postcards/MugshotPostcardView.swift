//
//  MugshotPostcardView.swift
//  testMugshot
//
//  A branded 9:16 postcard view for sharing visits to Instagram Stories.
//  Designed to be instantly recognizable as Mugshot with polished aesthetics.
//

import SwiftUI
import UIKit

/// Data model containing all info needed to render a postcard
struct PostcardData {
    let cafeName: String
    let cafeCity: String?
    let visitDate: Date
    let drinkType: DrinkType
    let customDrinkType: String?
    let overallScore: Double
    let caption: String? // Public caption text (not private notes)
    let photoImage: UIImage?
    let authorDisplayName: String
    let authorUsername: String
    let authorAvatarImage: UIImage?
    let authorAvatarURL: String?
    
    /// Creates PostcardData from a Visit and related objects
    static func from(
        visit: Visit,
        cafe: Cafe?,
        authorImage: UIImage?,
        avatarURL: String?
    ) -> PostcardData {
        PostcardData(
            cafeName: cafe?.name ?? "Unknown Cafe",
            cafeCity: cafe?.city,
            visitDate: visit.createdAt,
            drinkType: visit.drinkType,
            customDrinkType: visit.customDrinkType,
            overallScore: visit.overallScore,
            caption: visit.caption, // Use public caption, NOT private notes
            photoImage: nil,
            authorDisplayName: visit.authorDisplayNameOrUsername,
            authorUsername: visit.authorUsernameHandle,
            authorAvatarImage: authorImage,
            authorAvatarURL: avatarURL
        )
    }
}

/// The main postcard view - renders at 9:16 aspect ratio (1080x1920)
struct MugshotPostcardView: View {
    let data: PostcardData
    let visitPhoto: UIImage?
    let variant: PostcardVariant
    
    // FORCE fixed reference resolution to ensure consistency between preview and export
    // All layout values are relative to this 1080x1920 canvas
    private let referenceWidth: CGFloat = 1080
    private let referenceHeight: CGFloat = 1920
    
    enum PostcardVariant: Hashable {
        case light
        case dark
        
        var overlayGradient: [Color] {
            switch self {
            case .light:
                return [.clear, .clear, .black.opacity(0.3), .black.opacity(0.75)]
            case .dark:
                return [.clear, .clear, .black.opacity(0.4), .black.opacity(0.85)]
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: data.visitDate)
    }
    
    private var drinkDisplayText: String {
        if let custom = data.customDrinkType, !custom.isEmpty {
            return custom
        }
        return data.drinkType.rawValue
    }
    
    private var scoreText: String {
        String(format: "%.1f", data.overallScore)
    }
    
    private var truncatedCaption: String? {
        guard let caption = data.caption, !caption.isEmpty else { return nil }
        if caption.count <= 100 {
            return caption
        }
        return String(caption.prefix(97)) + "..."
    }
    
    private var drinkIcon: String {
        switch data.drinkType {
        case .coffee: return "cup.and.saucer.fill"
        case .matcha, .tea, .hojicha: return "leaf.fill"
        case .chai: return "flame.fill"
        case .hotChocolate: return "mug.fill"
        case .other: return "drop.fill"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        // We render at 1080x1920 fixed size, then let the caller scale it down for preview
        ZStack(alignment: .bottom) {
            // Background layer - photo or branded gradient
            backgroundLayer
            
            // Content overlay at bottom
            contentOverlay
        }
        .frame(width: referenceWidth, height: referenceHeight)
        .clipped()
        // We do NOT set aspect ratio here, caller handles scaling
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private var backgroundLayer: some View {
        if let photo = visitPhoto {
            // Photo background - FULL BLEED
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: referenceWidth, height: referenceHeight)
                .clipped()
                .overlay(
                    // Gradient overlay for text readability at bottom
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.4),
                            .init(color: .black.opacity(0.4), location: 0.7),
                            .init(color: .black.opacity(0.8), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            // Branded gradient fallback when no photo
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "A8D5BA"),
                        DS.Colors.mintMain,
                        Color(hex: "7CB889")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle decorative circles
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: referenceWidth * 0.8)
                        .offset(x: -referenceWidth * 0.3, y: -referenceHeight * 0.1)
                    
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: referenceWidth * 0.6)
                        .offset(x: referenceWidth * 0.4, y: referenceHeight * 0.2)
                    
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: referenceWidth * 0.5)
                        .offset(x: -referenceWidth * 0.2, y: referenceHeight * 0.5)
                }
                
                // Bottom gradient for text
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.5),
                        .init(color: .black.opacity(0.2), location: 0.75),
                        .init(color: .black.opacity(0.5), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: referenceWidth, height: referenceHeight)
        }
    }
    
    // MARK: - Content Overlay
    
    private var contentOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content card
            VStack(alignment: .leading, spacing: 40) { // Increased spacing for high-res canvas
                
                // Row 1: Rating + Drink Type
                HStack(alignment: .center, spacing: 24) {
                    // Score badge
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 48, weight: .bold)) // Scored up
                            .foregroundColor(Color(hex: "FFD700"))
                        
                        Text(scoreText)
                            .font(.system(size: 84, weight: .bold, design: .rounded)) // Scored up
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Drink type pill
                    HStack(spacing: 12) {
                        Image(systemName: drinkIcon)
                            .font(.system(size: 32, weight: .semibold)) // Scored up
                        Text(drinkDisplayText)
                            .font(.system(size: 36, weight: .semibold)) // Scored up
                            .lineLimit(1)
                    }
                    .foregroundColor(DS.Colors.textOnMint)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .background(DS.Colors.primaryAccent)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                
                // Row 2: Cafe Name
                Text(data.cafeName)
                    .font(.system(size: 72, weight: .bold)) // Scored up
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                
                // Row 3: Location & Date
                HStack(spacing: 16) {
                    if let city = data.cafeCity, !city.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32, weight: .medium)) // Scored up
                            Text(city)
                                .font(.system(size: 34, weight: .medium)) // Scored up
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 34)) // Scored up
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 32, weight: .medium)) // Scored up
                        Text(formattedDate)
                            .font(.system(size: 34, weight: .medium)) // Scored up
                    }
                    .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                
                // Row 4: Caption (if available)
                if let caption = truncatedCaption {
                    Text("\"\(caption)\"")
                        .font(.system(size: 40, weight: .regular, design: .serif)) // Scored up
                        .italic()
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                }
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 2) // Thicker for high-res
                    .padding(.vertical, 10)
                
                // Row 5: Author + Branding
                HStack(alignment: .center, spacing: 0) {
                    // Author info
                    authorSection
                    
                    Spacer(minLength: 32)
                    
                    // Mugshot branding
                    brandingSection
                }
            }
            .padding(60) // Increased padding
            .background(
                // Glassmorphism card
                RoundedRectangle(cornerRadius: 56) // Increased radius
                    .fill(.ultraThinMaterial.opacity(0.85))
                    .background(
                        RoundedRectangle(cornerRadius: 56)
                            .fill(Color.black.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 56)
                            .stroke(Color.white.opacity(0.15), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 48)
            .padding(.bottom, 56)
        }
    }
    
    // MARK: - Author Section
    
    private var authorSection: some View {
        HStack(spacing: 24) {
            // Avatar
            Group {
                if let avatar = data.authorAvatarImage {
                    Image(uiImage: avatar)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let urlString = data.authorAvatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 100, height: 100) // Scored up
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 3))
            
            // Name and username
            VStack(alignment: .leading, spacing: 6) {
                Text(data.authorDisplayName)
                    .font(.system(size: 36, weight: .semibold)) // Scored up
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(data.authorUsername)
                    .font(.system(size: 30, weight: .regular)) // Scored up
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.primaryAccent)
            .overlay(
                Text(String(data.authorDisplayName.prefix(1)).uppercased())
                    .font(.system(size: 42, weight: .semibold)) // Scored up
                    .foregroundColor(DS.Colors.textOnMint)
            )
    }
    
    // MARK: - Branding Section
    
    private var brandingSection: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // App icon + Mugshot wordmark
            HStack(spacing: 12) {
                // App icon from bundle
                AppIconView(size: 48)
                
                Text("Mugshot")
                    .font(.system(size: 42, weight: .bold))
            }
            .foregroundColor(.white)
            .fixedSize(horizontal: true, vertical: false)
            
            // CTA
            Text("Download Now")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - App Icon Helper

/// Loads and displays the app icon from the bundle
struct AppIconView: View {
    let size: CGFloat
    
    var body: some View {
        Group {
            if let icon = Self.loadAppIcon() {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback: recreate the icon design
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(DS.Colors.primaryAccent)
                    .overlay(
                        Image(systemName: "mug.fill")
                            .font(.system(size: size * 0.5, weight: .medium))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
    
    /// Load app icon from bundle
    static func loadAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return UIImage(named: "AppIcon")
    }
}

// MARK: - Preview Wrapper for Xcode
// Scales the huge 1080x1920 view down to fit in preview

struct ScaledPreviewWrapper: View {
    let data: PostcardData
    let visitPhoto: UIImage?
    let variant: MugshotPostcardView.PostcardVariant
    
    var body: some View {
        GeometryReader { geo in
            MugshotPostcardView(data: data, visitPhoto: visitPhoto, variant: variant)
                .scaleEffect(geo.size.width / 1080.0)
                .frame(width: geo.size.width, height: geo.size.width * (1920.0/1080.0))
                .position(x: geo.size.width/2, y: (geo.size.width * (1920.0/1080.0))/2)
        }
        .aspectRatio(9/16, contentMode: .fit)
    }
}

// MARK: - Preview

#Preview("With Photo - Light") {
    ScaledPreviewWrapper(
        data: PostcardData(
            cafeName: "Sightglass Coffee",
            cafeCity: "San Francisco",
            visitDate: Date(),
            drinkType: .coffee,
            customDrinkType: "Cortado",
            overallScore: 4.2,
            caption: "Incredible light roast with notes of citrus and honey. The barista was super knowledgeable!",
            photoImage: nil,
            authorDisplayName: "Joe Rosso",
            authorUsername: "@joerosso",
            authorAvatarImage: nil,
            authorAvatarURL: nil
        ),
        visitPhoto: nil,
        variant: .light
    )
    .frame(width: 300)
}

#Preview("No Photo - Gradient") {
    ScaledPreviewWrapper(
        data: PostcardData(
            cafeName: "Blue Bottle Coffee",
            cafeCity: "Oakland",
            visitDate: Date(),
            drinkType: .matcha,
            customDrinkType: nil,
            overallScore: 3.8,
            caption: nil,
            photoImage: nil,
            authorDisplayName: "Coffee Lover",
            authorUsername: "@coffeelover",
            authorAvatarImage: nil,
            authorAvatarURL: nil
        ),
        visitPhoto: nil,
        variant: .light
    )
    .frame(width: 300)
}
