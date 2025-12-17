//
//  NearbyCafeCard.swift
//  testMugshot
//
//  A compact cafe card for the "Cafes Near You" section.
//  Matches the Saved tab aesthetic with thumbnail on left, info on right.
//

import SwiftUI
import CoreLocation

struct NearbyCafeCard: View {
    let cafe: Cafe
    let distance: Double? // in meters
    let averageRating: Double?
    let totalRatings: Int
    let photoURL: String? // Single thumbnail photo
    let hasVisits: Bool
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: DS.Spacing.md) {
                // Thumbnail
                thumbnail
                
                // Info
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Cafe Name
                    Text(cafe.name)
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    // Distance + Rating
                    HStack(spacing: DS.Spacing.sm) {
                        // Distance
                        if let distance = distance {
                            Text(formatDistance(distance))
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                        
                        // Rating (if exists)
                        if let rating = averageRating, rating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(DS.Colors.yellowAccent)
                                
                                Text(String(format: "%.1f", rating))
                                    .font(DS.Typography.caption1(.semibold))
                                    .foregroundColor(DS.Colors.textPrimary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.lg)
            .dsCardShadow()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Thumbnail
    
    private var thumbnail: some View {
        Group {
            if let urlString = photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var thumbnailPlaceholder: some View {
        ZStack {
            DS.Colors.primaryAccentSoftFill
            
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 20))
                .foregroundColor(DS.Colors.primaryAccent.opacity(0.6))
        }
    }
    
    // MARK: - Helpers
    
    private func formatDistance(_ meters: Double) -> String {
        let miles = meters * 0.000621371
        if miles < 0.1 {
            return String(format: "%.0f ft", meters * 3.28084)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.md) {
        NearbyCafeCard(
            cafe: Cafe(
                name: "Sightglass Coffee",
                address: "270 7th St",
                city: "San Francisco"
            ),
            distance: 250,
            averageRating: 4.5,
            totalRatings: 28,
            photoURL: nil,
            hasVisits: true
        )
        
        NearbyCafeCard(
            cafe: Cafe(
                name: "Blue Bottle Coffee on Market Street",
                address: "123 Main St",
                city: "Oakland"
            ),
            distance: 1200,
            averageRating: 4.2,
            totalRatings: 15,
            photoURL: nil,
            hasVisits: true
        )
        
        NearbyCafeCard(
            cafe: Cafe(
                name: "Philz Coffee",
                address: "456 Oak St",
                city: "Berkeley"
            ),
            distance: 3500,
            averageRating: nil,
            totalRatings: 0,
            photoURL: nil,
            hasVisits: false
        )
    }
    .padding()
    .background(DS.Colors.screenBackground)
}



