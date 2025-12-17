//
//  ModernSipCard.swift
//  testMugshot
//
//  Instagram-style visit card for Modern Dark Mode feed
//  Features: 4:5 image, glass overlays, metadata row
//

import SwiftUI

struct ModernSipCard: View {
    let visit: Visit
    let cafeName: String
    let userName: String
    let userAvatarURL: String?
    let onTap: () -> Void
    
    // Photo URLs
    private var posterURL: String? {
        guard let key = visit.posterImagePath else { return nil }
        return visit.remoteURL(for: key)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Main image with overlays
                imageSection
                
                // Metadata row (avatar, username, caption)
                metadataRow
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            // Main poster image (4:5 aspect ratio)
            if let posterURL = posterURL, let url = URL(string: posterURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(4/5, contentMode: .fill)
                            .clipped()
                    case .failure, .empty:
                        imagePlaceholder
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
            
            // Overlays
            VStack {
                HStack {
                    Spacer()
                    
                    // Rating badge (top right)
                    if visit.overallScore > 0 {
                        ratingBadge
                            .padding([.top, .trailing], 12)
                    }
                }
                
                Spacer()
                
                // Location pill (bottom left)
                HStack {
                    locationPill
                        .padding([.bottom, .leading], 12)
                    
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4/5, contentMode: .fit)
        .cornerRadius(16)
        .clipped()
    }
    
    private var imagePlaceholder: some View {
        Rectangle()
            .fill(DS.Colors.dynamicCardBackgroundAlt)
            .aspectRatio(4/5, contentMode: .fit)
            .overlay(
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 40))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
            )
    }
    
    // MARK: - Rating Badge
    
    private var ratingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(String(format: "%.1f", visit.overallScore))
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DS.Colors.dynamicPrimaryAccent)
        .cornerRadius(20)
    }
    
    // MARK: - Location Pill
    
    private var locationPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 12))
            Text(cafeName)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .background(DS.Colors.modernGlass.opacity(0.7))
        .cornerRadius(20)
    }
    
    // MARK: - Metadata Row
    
    private var metadataRow: some View {
        HStack(spacing: 12) {
            // User avatar
            if let avatarURL = userAvatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(DS.Colors.dynamicPrimaryAccent, lineWidth: 2)
                            )
                    default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
            
            // Username and caption
            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                    .lineLimit(1)
                
                let caption = visit.caption
                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.dynamicCardBackgroundAlt)
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
            )
            .overlay(
                Circle()
                    .stroke(DS.Colors.dynamicPrimaryAccent, lineWidth: 2)
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        DS.Colors.dynamicBackground
            .ignoresSafeArea()
        
        VStack {
            ModernSipCard(
                visit: Visit(
                    cafeId: UUID(),
                    userId: UUID(),
                    drinkType: .coffee,
                    drinkSubtype: "Cappuccino",
                    caption: "Amazing coffee with perfect foam art! The barista really knows what they're doing.",
                    ratings: ["flavor": 5.0, "ambiance": 4.0, "service": 4.0],
                    overallScore: 4.5
                ),
                cafeName: "Blue Bottle Coffee",
                userName: "coffeelover",
                userAvatarURL: nil,
                onTap: {}
            )
            .padding()
        }
    }
}


