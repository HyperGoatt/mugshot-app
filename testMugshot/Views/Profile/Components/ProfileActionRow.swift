//
//  ProfileActionRow.swift
//  testMugshot
//
//  Action buttons row for profile (Edit Profile, Share Profile)
//

import SwiftUI

struct ProfileActionRow: View {
    let onEditProfile: () -> Void
    let onShareProfile: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Edit Profile button
            Button(action: onEditProfile) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                    Text("Edit Profile")
                        .font(DS.Typography.subheadline(.semibold))
                }
                .foregroundColor(DS.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Share Profile button
            Button(action: onShareProfile) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                    Text("Share")
                        .font(DS.Typography.subheadline(.semibold))
                }
                .foregroundColor(DS.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
}

// MARK: - For Other User Profiles

struct ProfileActionRowOtherUser: View {
    let isFriend: Bool
    let isPending: Bool
    let onFriendAction: () -> Void
    let onMessage: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Friend/Add Friend button
            Button(action: onFriendAction) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: friendButtonIcon)
                        .font(.system(size: 14, weight: .medium))
                    Text(friendButtonText)
                        .font(DS.Typography.subheadline(.semibold))
                }
                .foregroundColor(friendButtonForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background(friendButtonBackground)
                .cornerRadius(DS.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(friendButtonBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Message button (placeholder for future)
            Button(action: onMessage) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "envelope")
                        .font(.system(size: 14, weight: .medium))
                    Text("Message")
                        .font(DS.Typography.subheadline(.semibold))
                }
                .foregroundColor(DS.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var friendButtonIcon: String {
        if isFriend {
            return "checkmark"
        } else if isPending {
            return "clock"
        } else {
            return "person.badge.plus"
        }
    }
    
    private var friendButtonText: String {
        if isFriend {
            return "Friends"
        } else if isPending {
            return "Pending"
        } else {
            return "Add Friend"
        }
    }
    
    private var friendButtonForeground: Color {
        if isFriend {
            return DS.Colors.textOnMint
        } else if isPending {
            return DS.Colors.textSecondary
        } else {
            return DS.Colors.textOnMint
        }
    }
    
    private var friendButtonBackground: Color {
        if isFriend {
            return DS.Colors.primaryAccent
        } else if isPending {
            return DS.Colors.cardBackgroundAlt
        } else {
            return DS.Colors.primaryAccent
        }
    }
    
    private var friendButtonBorder: Color {
        if isPending {
            return DS.Colors.borderSubtle
        } else {
            return Color.clear
        }
    }
}

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        ProfileActionRow(
            onEditProfile: {},
            onShareProfile: {}
        )
        
        ProfileActionRowOtherUser(
            isFriend: false,
            isPending: false,
            onFriendAction: {},
            onMessage: {}
        )
        
        ProfileActionRowOtherUser(
            isFriend: false,
            isPending: true,
            onFriendAction: {},
            onMessage: {}
        )
        
        ProfileActionRowOtherUser(
            isFriend: true,
            isPending: false,
            onFriendAction: {},
            onMessage: {}
        )
    }
    .padding(.vertical, DS.Spacing.lg)
    .background(DS.Colors.screenBackground)
}

