//
//  FriendVisitCard.swift
//  testMugshot
//
//  A card showing a friend's recent visit/sip.
//  Used in the "What Your Friends Are Sipping" horizontal carousel.
//

import SwiftUI

struct FriendVisitCard: View {
    let visit: Visit
    let cafeName: String
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Photo Thumbnail
                photoThumbnail
                
                // Friend Info
                HStack(spacing: DS.Spacing.xs) {
                    friendAvatar
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(visit.authorDisplayNameOrUsername)
                            .font(DS.Typography.caption1(.semibold))
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Text(timeAgo)
                            .font(DS.Typography.caption2())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                    
                    Spacer()
                }
                
                // Drink Info
                VStack(alignment: .leading, spacing: 4) {
                    if let subtype = visit.drinkSubtype, !subtype.isEmpty {
                        Text(subtype)
                            .font(DS.Typography.subheadline(.semibold))
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text(visit.drinkType.rawValue)
                            .font(DS.Typography.subheadline(.semibold))
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        Text(cafeName)
                            .font(DS.Typography.caption2())
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.lg)
            .dsCardShadow()
        }
        .buttonStyle(.plain)
        .frame(width: 200)
    }
    
    // MARK: - Subviews
    
    private var photoThumbnail: some View {
        Group {
            if let posterURL = visit.posterPhotoURL, let url = URL(string: posterURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        photoPlaceholder
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var photoPlaceholder: some View {
        ZStack {
            DS.Colors.primaryAccentSoftFill
            
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 32))
                .foregroundColor(DS.Colors.primaryAccent.opacity(0.5))
        }
    }
    
    private var friendAvatar: some View {
        Group {
            if let urlString = visit.authorAvatarURL, let url = URL(string: urlString) {
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
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(Circle().stroke(DS.Colors.borderSubtle, lineWidth: 1))
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.secondaryAccent)
            .overlay(
                Text(visit.authorInitials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: visit.createdAt, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: DS.Spacing.md) {
            FriendVisitCard(
                visit: Visit(
                    cafeId: UUID(),
                    userId: UUID(),
                    createdAt: Date().addingTimeInterval(-3600),
                    drinkType: .coffee,
                    drinkSubtype: "Iced Lavender Latte",
                    authorDisplayName: "Alex Chen",
                    authorAvatarURL: nil
                ),
                cafeName: "Sightglass Coffee"
            )
            
            FriendVisitCard(
                visit: Visit(
                    cafeId: UUID(),
                    userId: UUID(),
                    createdAt: Date().addingTimeInterval(-7200),
                    drinkType: .matcha,
                    drinkSubtype: "Matcha Latte",
                    authorDisplayName: "Jordan Smith",
                    authorAvatarURL: nil
                ),
                cafeName: "Blue Bottle"
            )
        }
        .padding()
    }
    .background(DS.Colors.screenBackground)
}





