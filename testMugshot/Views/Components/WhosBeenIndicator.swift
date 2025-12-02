//
//  WhosBeenIndicator.swift
//  testMugshot
//
//  The "Who's Been?" indicator showing friend faces with their rating bubbles.
//  Used in CafeDetailSheet to show social proof for a cafe.
//

import SwiftUI

struct WhosBeenIndicator: View {
    let friendVisitors: [FriendVisitor]
    
    /// Lightweight struct to represent a friend who visited
    struct FriendVisitor: Identifiable {
        let id: String // supabaseUserId
        let displayName: String
        let avatarURL: String?
        let rating: Double?
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section Header
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.primaryAccent)
                Text("Who's Been?")
                    .font(DS.Typography.caption1(.semibold))
                    .foregroundColor(DS.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            if friendVisitors.isEmpty {
                // Empty state
                emptyState
            } else {
                // Friend avatars with floating rating bubbles
                friendAvatarsWithRatings
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.lg)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Placeholder avatar
            Circle()
                .fill(DS.Colors.primaryAccent.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.primaryAccent)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Be the first of your friends!")
                    .font(DS.Typography.subheadline())
                    .foregroundColor(DS.Colors.textSecondary)
                Text("Visit this cafe to show up here")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
    }
    
    // MARK: - Friend Avatars with Ratings
    
    private var friendAvatarsWithRatings: some View {
        HStack(spacing: DS.Spacing.lg) {
            ForEach(friendVisitors.prefix(4)) { friend in
                FriendAvatarWithRating(friend: friend)
            }
            
            // "+N more" indicator if there are more friends
            if friendVisitors.count > 4 {
                VStack(spacing: 4) {
                    Circle()
                        .fill(DS.Colors.cardBackground)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("+\(friendVisitors.count - 4)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DS.Colors.textSecondary)
                        )
                        .overlay(
                            Circle()
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    
                    Text("more")
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Friend Avatar with Floating Rating Bubble

private struct FriendAvatarWithRating: View {
    let friend: WhosBeenIndicator.FriendVisitor
    
    var body: some View {
        VStack(spacing: 4) {
            // Avatar with floating rating bubble
            ZStack(alignment: .bottomTrailing) {
                // Avatar
                avatarImage
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(DS.Colors.cardBackground, lineWidth: 2)
                    )
                    .shadow(color: DS.Colors.textPrimary.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Floating Rating Bubble
                if let rating = friend.rating, rating > 0 {
                    ratingBubble(rating: rating)
                        .offset(x: 6, y: 4)
                }
            }
            
            // Friend's first name
            Text(friend.displayName.split(separator: " ").first.map(String.init) ?? friend.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var avatarImage: some View {
        if let urlString = friend.avatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [DS.Colors.secondaryAccent, DS.Colors.secondaryAccent.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private func ratingBubble(rating: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(DS.Colors.yellowAccent)
            Text(String(format: "%.1f", rating))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(DS.Colors.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(DS.Colors.cardBackground)
                .shadow(color: DS.Colors.textPrimary.opacity(0.15), radius: 3, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(DS.Colors.yellowAccent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("With Friends") {
    VStack(spacing: DS.Spacing.lg) {
        WhosBeenIndicator(friendVisitors: [
            .init(id: "1", displayName: "Alex Chen", avatarURL: nil, rating: 4.8),
            .init(id: "2", displayName: "Jordan Smith", avatarURL: nil, rating: 4.2),
            .init(id: "3", displayName: "Sam Wilson", avatarURL: nil, rating: 3.9)
        ])
        
        WhosBeenIndicator(friendVisitors: [
            .init(id: "1", displayName: "Maya", avatarURL: nil, rating: 4.5)
        ])
        
        WhosBeenIndicator(friendVisitors: [])
    }
    .padding()
    .background(DS.Colors.screenBackground)
}

#Preview("Many Friends") {
    WhosBeenIndicator(friendVisitors: [
        .init(id: "1", displayName: "Chris", avatarURL: nil, rating: 4.0),
        .init(id: "2", displayName: "Pat", avatarURL: nil, rating: 4.3),
        .init(id: "3", displayName: "Taylor", avatarURL: nil, rating: nil),
        .init(id: "4", displayName: "Jamie", avatarURL: nil, rating: 4.7),
        .init(id: "5", displayName: "Morgan", avatarURL: nil, rating: 4.1),
        .init(id: "6", displayName: "Casey", avatarURL: nil, rating: 3.8)
    ])
    .padding()
    .background(DS.Colors.screenBackground)
}

