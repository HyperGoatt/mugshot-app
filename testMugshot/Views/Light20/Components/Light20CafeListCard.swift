//
//  Light20CafeListCard.swift
//  testMugshot
//
//  Light 2.0 cafe list card (used in map bottom sheet)
//  Horizontal layout with image, name, rating, distance
//

import SwiftUI
import CoreLocation

struct Light20CafeListCard: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let onTap: () -> Void
    
    private var userVisits: [Visit] {
        dataManager.appData.visits.filter { $0.cafeId == cafe.id }
    }
    
    private var averageRating: Double {
        guard !userVisits.isEmpty else { return 0 }
        return userVisits.reduce(0.0, { $0 + $1.overallScore }) / Double(userVisits.count)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                if let firstVisit = userVisits.first,
                   let photo = firstVisit.photos.first {
                    PhotoImageView(
                        photoPath: photo,
                        remoteURL: firstVisit.remotePhotoURLByKey[photo]
                    )
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(DS.Colors.light20Surface)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DS.Colors.light20IconInactive)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .light20Subheading()
                        .lineLimit(1)
                    
                    Text(cafe.address)
                        .light20Label()
                        .lineLimit(1)
                    
                    if averageRating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DS.Colors.light20MintPrimary)
                            Text(String(format: "%.1f", averageRating))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DS.Colors.light20CharcoalBlack)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.light20IconInactive)
            }
            .padding(12)
        }
        .light20FloatingCard()
    }
}


