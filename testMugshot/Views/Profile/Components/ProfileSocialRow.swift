//
//  ProfileSocialRow.swift
//  testMugshot
//
//  Social row showing friends count and social links
//

import SwiftUI

struct ProfileSocialRow: View {
    let friendsCount: Int
    let mutualFriendsCount: Int?
    let instagramHandle: String?
    let websiteURL: String?
    let onFriendsTap: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Friends count (tappable)
            Button(action: onFriendsTap) {
                HStack(spacing: 4) {
                    Text("\(friendsCount)")
                        .font(DS.Typography.subheadline(.semibold))
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("Friends")
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            
            // Mutual friends (if applicable)
            if let mutual = mutualFriendsCount, mutual > 0 {
                Text("•")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textTertiary)
                
                HStack(spacing: 4) {
                    Text("\(mutual)")
                        .font(DS.Typography.subheadline(.semibold))
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("Mutual")
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Social links
            socialLinksRow
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    @ViewBuilder
    private var socialLinksRow: some View {
        HStack(spacing: DS.Spacing.md) {
            if let handle = instagramHandle, !handle.isEmpty {
                Button(action: {
                    let cleanHandle = handle.replacingOccurrences(of: "@", with: "")
                    if let url = URL(string: "https://instagram.com/\(cleanHandle)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DS.Colors.iconDefault)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.cardBackgroundAlt)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            if let website = websiteURL, !website.isEmpty {
                Button(action: {
                    var urlString = website
                    if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                        urlString = "https://\(urlString)"
                    }
                    if let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "globe")
                        .font(.system(size: 18))
                        .foregroundColor(DS.Colors.iconDefault)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.cardBackgroundAlt)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Compact Social Stats (For Profile Header)

struct ProfileSocialStats: View {
    let visitsCount: Int
    let cafesCount: Int
    let friendsCount: Int
    let onFriendsTap: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Spacing.xl) {
            // Visits
            statItem(count: visitsCount, label: "Visits")
            
            // Cafés
            statItem(count: cafesCount, label: "Cafés")
            
            // Friends (tappable)
            Button(action: onFriendsTap) {
                statItem(count: friendsCount, label: "Friends")
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(DS.Typography.headline(.bold))
                .foregroundColor(DS.Colors.textPrimary)
            Text(label)
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        ProfileSocialRow(
            friendsCount: 12,
            mutualFriendsCount: 3,
            instagramHandle: "joe_coffee",
            websiteURL: "https://mugshot.app",
            onFriendsTap: {}
        )
        
        ProfileSocialRow(
            friendsCount: 8,
            mutualFriendsCount: nil,
            instagramHandle: "joe_coffee",
            websiteURL: nil,
            onFriendsTap: {}
        )
        
        Divider()
            .padding(.horizontal, DS.Spacing.pagePadding)
        
        ProfileSocialStats(
            visitsCount: 42,
            cafesCount: 15,
            friendsCount: 12,
            onFriendsTap: {}
        )
    }
    .padding(.vertical, DS.Spacing.lg)
    .background(DS.Colors.screenBackground)
}

