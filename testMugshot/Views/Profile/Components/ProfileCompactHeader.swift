//
//  ProfileCompactHeader.swift
//  testMugshot
//
//  Compact profile header with left-aligned avatar overlapping banner
//

import SwiftUI

struct ProfileCompactHeader: View {
    let displayName: String?
    let username: String?
    let bio: String?
    let location: String?
    let favoriteDrink: String?
    let profileImageURL: String?
    let bannerImageURL: String?
    let profileImageId: String?
    let bannerImageId: String?
    
    private let bannerHeight: CGFloat = 140
    private let avatarSize: CGFloat = 90
    private let avatarOverlap: CGFloat = 45
    
    private var displayNameOrUsername: String {
        displayName ?? username ?? "User"
    }
    
    private var usernameText: String {
        username ?? "user"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner
            bannerView
            
            // Profile info section (avatar overlaps banner)
            profileInfoSection
                .padding(.top, -avatarOverlap)
        }
    }
    
    // MARK: - Banner View
    
    private var bannerView: some View {
        Group {
            if let bannerURL = bannerImageURL,
               let url = URL(string: bannerURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        defaultBannerGradient
                    @unknown default:
                        defaultBannerGradient
                    }
                }
            } else if let bannerID = bannerImageId,
                      let cachedImage = PhotoCache.shared.retrieve(forKey: bannerID) {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                defaultBannerGradient
            }
        }
        .frame(height: bannerHeight)
        .clipped()
    }
    
    private var defaultBannerGradient: some View {
        LinearGradient(
            colors: [DS.Colors.mintLight, DS.Colors.mintSoftFill],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Profile Info Section
    
    private var profileInfoSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            // Left-aligned avatar
            avatarView
            
            // Name and username
            VStack(alignment: .leading, spacing: 2) {
                Text(displayNameOrUsername)
                    .font(DS.Typography.title2(.bold))
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(1)
                
                Text("@\(usernameText)")
                    .font(DS.Typography.subheadline())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding(.top, avatarOverlap + DS.Spacing.sm)
            
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Avatar View
    
    private var avatarView: some View {
        Group {
            if let profileURL = profileImageURL,
               let url = URL(string: profileURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else if let profileID = profileImageId,
                      let cachedImage = PhotoCache.shared.retrieve(forKey: profileID) {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(DS.Colors.cardBackground, lineWidth: 3)
        )
        .shadow(
            color: DS.Shadow.cardSoft.color,
            radius: DS.Shadow.cardSoft.radius,
            x: DS.Shadow.cardSoft.x,
            y: DS.Shadow.cardSoft.y
        )
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.primaryAccent)
            .overlay(
                Text(displayNameOrUsername.prefix(1).uppercased())
                    .font(.system(size: avatarSize * 0.4, weight: .semibold))
                    .foregroundColor(DS.Colors.textOnMint)
            )
    }
}

// MARK: - Profile Bio Section

struct ProfileBioSection: View {
    let bio: String?
    let location: String?
    let favoriteDrink: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Bio
            if let bio = bio, !bio.isEmpty {
                Text(bio)
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Meta row (favorite drink + location)
            if (favoriteDrink != nil && !favoriteDrink!.isEmpty) ||
               (location != nil && !location!.isEmpty) {
                HStack(spacing: DS.Spacing.md) {
                    if let favoriteDrink = favoriteDrink, !favoriteDrink.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DS.Colors.textSecondary)
                            Text(favoriteDrink)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    
                    if let location = location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 12))
                                .foregroundColor(DS.Colors.textSecondary)
                            Text(location)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
}

#Preview {
    VStack(spacing: 0) {
        ProfileCompactHeader(
            displayName: "Joe (Creator)",
            username: "joe",
            bio: "Creator of Mugshot ☕ Coming soon...",
            location: "CHS",
            favoriteDrink: "Latte",
            profileImageURL: nil,
            bannerImageURL: nil,
            profileImageId: nil,
            bannerImageId: nil
        )
        
        ProfileBioSection(
            bio: "Creator of Mugshot ☕ Coming soon...",
            location: "CHS",
            favoriteDrink: "Latte"
        )
        .padding(.top, DS.Spacing.md)
        
        Spacer()
    }
    .background(DS.Colors.screenBackground)
}

