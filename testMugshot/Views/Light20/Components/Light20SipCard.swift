//
//  Light20SipCard.swift
//  testMugshot
//
//  Light 2.0 social feed post card
//  Floating card with user info, cafe, rating, and photo
//

import SwiftUI

struct Light20SipCard: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    let onCafeTap: () -> Void
    let onVisitTap: () -> Void
    let onUserTap: (String) -> Void
    
    private var authorName: String {
        visit.authorDisplayName ?? visit.authorUsername ?? "User"
    }
    
    private var authorAvatarURL: String? {
        visit.authorAvatarURL
    }
    
    private var cafe: Cafe? {
        dataManager.appData.cafes.first { $0.id == visit.cafeId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack(spacing: 12) {
                Button(action: {
                    onUserTap(visit.userId.uuidString)
                }) {
                    if let avatarURL = authorAvatarURL {
                        CachedAvatarImage(
                            imageURL: avatarURL,
                            cacheNamespace: "feed-avatar"
                        ) {
                            avatarPlaceholder
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                            .frame(width: 44, height: 44)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(authorName)
                        .light20Subheading()
                    
                    Text(timeAgoString(from: visit.createdAt))
                        .light20Label()
                }
                
                Spacer()
                
                // Rating badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ratingColor(visit.overallScore))
                    Text(String(format: "%.1f", visit.overallScore))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ratingColor(visit.overallScore))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ratingColor(visit.overallScore).opacity(0.1))
                .cornerRadius(12)
            }
            
            // Cafe attribution
            if let cafe = cafe {
                Button(action: onCafeTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.light20MintPrimary)
                        
                        Text(cafe.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DS.Colors.light20MintPrimary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(DS.Colors.light20MintPrimary)
                    }
                }
            }
            
            // Drink info
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.light20TextSecondary)
                
                Text("\(visit.drinkType.rawValue) · \(specificDrinkDescription)")
                    .light20Label()
            }
            
            // Caption
            if !visit.caption.isEmpty {
                Text(visit.caption)
                    .light20BodyText()
                    .lineLimit(3)
            }
            
            // Photo
            if let posterPhoto = visit.photos.first {
                Button(action: onVisitTap) {
                    PhotoImageView(
                        photoPath: posterPhoto,
                        remoteURL: visit.remotePhotoURLByKey[posterPhoto]
                    )
                    .aspectRatio(4/3, contentMode: .fill)
                    .clipped()
                    .cornerRadius(12)
                }
            }
            
            // Interaction buttons
            HStack(spacing: 24) {
                Button(action: {
                    // TODO: Like action
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .foregroundColor(DS.Colors.light20CharcoalBlack)
                        Text("0")
                            .light20Label()
                    }
                }
                
                Button(action: {
                    // TODO: Comment action
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .foregroundColor(DS.Colors.light20CharcoalBlack)
                        Text("3")
                            .light20Label()
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Save action
                }) {
                    Image(systemName: "bookmark")
                        .foregroundColor(DS.Colors.light20CharcoalBlack)
                }
            }
        }
        .padding(DS.Spacing.cardPadding)
        .light20FloatingCard()
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.light20Surface)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(DS.Colors.light20IconInactive)
            )
    }

    private var specificDrinkDescription: String {
        if let subtype = visit.drinkSubtype, !subtype.isEmpty {
            return subtype
        }
        if let custom = visit.customDrinkType, !custom.isEmpty {
            return custom
        }
        return "Drink"
    }
    
    private func ratingColor(_ rating: Double) -> Color {
        if rating >= 4.0 { return DS.Colors.light20GreenAccent }
        if rating >= 3.0 { return DS.Colors.light20YellowAccent }
        return DS.Colors.light20RedAccent
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}


