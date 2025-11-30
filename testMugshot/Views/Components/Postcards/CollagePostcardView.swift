//
//  CollagePostcardView.swift
//  testMugshot
//
//  A branded 9:16 postcard view with multi-photo collage layout.
//  Always uses 2-column grid pattern regardless of photo count.
//

import SwiftUI
import UIKit

/// Collage postcard view - renders multiple photos in a 2-column grid
struct CollagePostcardView: View {
    let data: PostcardData
    let photos: [UIImage]
    let variant: MugshotPostcardView.PostcardVariant
    
    // Fixed reference resolution (same as MugshotPostcardView)
    private let referenceWidth: CGFloat = 1080
    private let referenceHeight: CGFloat = 1920
    
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
    
    private var drinkIcon: String {
        switch data.drinkType {
        case .coffee: return "cup.and.saucer.fill"
        case .matcha, .tea, .hojicha: return "leaf.fill"
        case .chai: return "flame.fill"
        case .hotChocolate: return "mug.fill"
        case .other: return "drop.fill"
        }
    }
    
    /// Calculate grid dimensions based on photo count
    private var gridRows: Int {
        max(1, (photos.count + 1) / 2) // Round up for odd counts
    }
    
    /// Height available for photo grid (total height minus overlay area)
    private var photoGridHeight: CGFloat {
        // Reserve ~35% of height for the overlay card
        referenceHeight * 0.65
    }
    
    /// Height per row in the grid
    private var rowHeight: CGFloat {
        photoGridHeight / CGFloat(gridRows)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo collage grid
            photoGrid
            
            // Content overlay at bottom
            contentOverlay
        }
        .frame(width: referenceWidth, height: referenceHeight)
        .clipped()
    }
    
    // MARK: - Photo Grid
    
    private var photoGrid: some View {
        VStack(spacing: 4) {
            ForEach(0..<gridRows, id: \.self) { row in
                HStack(spacing: 4) {
                    // Left photo
                    let leftIndex = row * 2
                    if leftIndex < photos.count {
                        Image(uiImage: photos[leftIndex])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: (referenceWidth - 4) / 2, height: rowHeight)
                            .clipped()
                    }
                    
                    // Right photo
                    let rightIndex = row * 2 + 1
                    if rightIndex < photos.count {
                        Image(uiImage: photos[rightIndex])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: (referenceWidth - 4) / 2, height: rowHeight)
                            .clipped()
                    } else if photos.count > 1 {
                        // Empty space for odd photo count (shouldn't happen with even rounding)
                        Color.black.opacity(0.3)
                            .frame(width: (referenceWidth - 4) / 2, height: rowHeight)
                    }
                }
            }
            
            Spacer()
        }
        .frame(width: referenceWidth, height: referenceHeight)
        .background(Color.black)
        .overlay(
            // Gradient overlay for text readability at bottom
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.5), location: 0.7),
                    .init(color: .black.opacity(0.85), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Content Overlay
    
    private var contentOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 40) {
                
                // Row 1: Rating + Drink Type + Photo count badge
                HStack(alignment: .center, spacing: 24) {
                    // Score badge
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(Color(hex: "FFD700"))
                        
                        Text(scoreText)
                            .font(.system(size: 84, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Photo count badge
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 28, weight: .semibold))
                        Text("\(photos.count)")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                    
                    // Drink type pill
                    HStack(spacing: 12) {
                        Image(systemName: drinkIcon)
                            .font(.system(size: 32, weight: .semibold))
                        Text(drinkDisplayText)
                            .font(.system(size: 36, weight: .semibold))
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
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                
                // Row 3: Location & Date
                HStack(spacing: 16) {
                    if let city = data.cafeCity, !city.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32, weight: .medium))
                            Text(city)
                                .font(.system(size: 34, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 34))
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 32, weight: .medium))
                        Text(formattedDate)
                            .font(.system(size: 34, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 2)
                    .padding(.vertical, 10)
                
                // Row 4: Author + Branding
                HStack(alignment: .center, spacing: 0) {
                    authorSection
                    
                    Spacer(minLength: 32)
                    
                    brandingSection
                }
            }
            .padding(60)
            .background(
                RoundedRectangle(cornerRadius: 56)
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
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 3))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(data.authorDisplayName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(data.authorUsername)
                    .font(.system(size: 30, weight: .regular))
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
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(DS.Colors.textOnMint)
            )
    }
    
    // MARK: - Branding Section
    
    private var brandingSection: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // App icon + Mugshot wordmark
            HStack(spacing: 12) {
                // App icon from bundle (uses AppIconView from MugshotPostcardView)
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

// MARK: - Preview

#Preview("4 Photo Collage") {
    GeometryReader { geo in
        CollagePostcardView(
            data: PostcardData(
                cafeName: "Sightglass Coffee",
                cafeCity: "San Francisco",
                visitDate: Date(),
                drinkType: .coffee,
                customDrinkType: "Cortado",
                overallScore: 4.2,
                caption: nil,
                photoImage: nil,
                authorDisplayName: "Joe Rosso",
                authorUsername: "@joerosso",
                authorAvatarImage: nil,
                authorAvatarURL: nil
            ),
            photos: [], // Would need actual images for preview
            variant: .light
        )
        .scaleEffect(geo.size.width / 1080.0)
        .frame(width: geo.size.width, height: geo.size.width * (1920.0/1080.0))
    }
    .frame(width: 270, height: 480)
}

