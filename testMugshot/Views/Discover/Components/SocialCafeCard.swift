//
//  SocialCafeCard.swift
//  testMugshot
//
//  A cafe card that emphasizes social proof ("Who's been here?").
//  Used in the "Friends are Visiting" horizontal scroll in Discover.
//

import SwiftUI

struct SocialCafeCard: View {
    let cafe: Cafe
    let friendVisitors: [FriendVisitor]
    var onTap: (() -> Void)? = nil
    
    /// Lightweight struct to represent a friend who visited
    struct FriendVisitor: Identifiable {
        let id: String // supabaseUserId
        let displayName: String
        let avatarURL: String?
        let rating: Double?
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Top: Cafe Info
                cafeInfoSection
                
                Divider()
                    .background(DS.Colors.borderSubtle)
                
                // Bottom: "Who's Been" Section
                socialProofSection
            }
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.lg)
            .dsCardShadow()
        }
        .buttonStyle(.plain)
        .frame(width: 260)
    }
    
    // MARK: - Subviews
    
    private var cafeInfoSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(cafe.name)
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(cafe.city ?? "Nearby")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
            
            // Rating Badge
            if cafe.averageRating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text(String(format: "%.1f", cafe.averageRating))
                        .font(DS.Typography.subheadline(.bold))
                }
                .foregroundColor(DS.Colors.textOnMint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DS.Colors.primaryAccent)
                .cornerRadius(DS.Radius.sm)
            }
        }
        .padding(DS.Spacing.md)
    }
    
    private var socialProofSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Face Pile
            facePile
            
            // Social Proof Text
            Text(socialProofText)
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textSecondary)
                .lineLimit(1)
            
            Spacer()
            
            // Friend's Rating Bubble (if available)
            if let firstRating = friendVisitors.first?.rating, firstRating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(DS.Colors.yellowAccent)
                    Text(String(format: "%.1f", firstRating))
                        .font(DS.Typography.caption2(.semibold))
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(DS.Colors.cardBackgroundAlt)
                .cornerRadius(DS.Radius.pill)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.screenBackground.opacity(0.5))
    }
    
    private var facePile: some View {
        HStack(spacing: -10) {
            if friendVisitors.isEmpty {
                // Placeholder when no friends have visited
                Circle()
                    .fill(DS.Colors.primaryAccent.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.primaryAccent)
                    )
            } else {
                ForEach(friendVisitors.prefix(3)) { friend in
                    friendAvatar(for: friend)
                }
            }
        }
    }
    
    private func friendAvatar(for friend: FriendVisitor) -> some View {
        Group {
            if let urlString = friend.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        avatarPlaceholder(for: friend)
                    }
                }
            } else {
                avatarPlaceholder(for: friend)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(DS.Colors.cardBackground, lineWidth: 2))
    }
    
    private func avatarPlaceholder(for friend: FriendVisitor) -> some View {
        Circle()
            .fill(DS.Colors.secondaryAccent)
            .overlay(
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private var socialProofText: String {
        let count = friendVisitors.count
        if count == 0 {
            return "Be the first of your friends!"
        } else if count == 1 {
            return "\(friendVisitors[0].displayName) visited"
        } else {
            return "\(friendVisitors[0].displayName) + \(count - 1) more"
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: DS.Spacing.md) {
            SocialCafeCard(
                cafe: Cafe(
                    name: "Sightglass Coffee",
                    address: "270 7th St",
                    city: "San Francisco",
                    averageRating: 4.5
                ),
                friendVisitors: [
                    .init(id: "1", displayName: "Alex", avatarURL: nil, rating: 4.2),
                    .init(id: "2", displayName: "Jordan", avatarURL: nil, rating: nil)
                ]
            )
            
            SocialCafeCard(
                cafe: Cafe(
                    name: "Blue Bottle",
                    address: "123 Main St",
                    city: "Oakland",
                    averageRating: 4.2
                ),
                friendVisitors: []
            )
        }
        .padding()
    }
    .background(DS.Colors.screenBackground)
}

