//
//  Light20SavedCard.swift
//  testMugshot
//
//  Light 2.0 saved cafe card
//  Image thumbnail, name, rating, "Log a Visit" CTA
//

import SwiftUI

struct Light20SavedCard: View {
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
    
    private var lastVisit: Visit? {
        userVisits.max { $0.createdAt < $1.createdAt }
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
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(DS.Colors.light20Surface)
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundColor(DS.Colors.light20IconInactive)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Cafe name
                    Text(cafe.name)
                        .light20Subheading()
                        .lineLimit(1)
                    
                    // Address
                    Text(cafe.address)
                        .light20Label()
                        .lineLimit(1)
                    
                    // Rating and visits
                    HStack(spacing: 16) {
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
                        
                        if !userVisits.isEmpty {
                            Text("\(userVisits.count) visit\(userVisits.count == 1 ? "" : "s")")
                                .light20Label()
                        }
                        
                        if let lastVisit = lastVisit {
                            Text("· Last: \(timeAgoString(from: lastVisit.createdAt))")
                                .light20Label()
                        }
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .padding(DS.Spacing.cardPadding)
        .light20FloatingCard()
        
        // Log a Visit button
        Button(action: {
            // TODO: Trigger log visit
        }) {
            HStack {
                Image(systemName: "cup.and.saucer")
                Text("Log a Visit")
            }
        }
        .buttonStyle(Light20PrimaryButtonStyle())
        .padding(.horizontal, DS.Spacing.cardPadding)
        .padding(.top, -8)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 86400 { return "Today" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        if interval < 2592000 { return "\(Int(interval / 604800))w ago" }
        return "1m+ ago"
    }
}


