//
//  MutualFriendsSection.swift
//  testMugshot
//
//  Created as part of Friends system implementation.
//

import SwiftUI

struct MutualFriendsSection: View {
    let mutualFriends: [User]
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader("\(mutualFriends.count) Mutual Friend\(mutualFriends.count == 1 ? "" : "s")")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(mutualFriends.prefix(10)) { friend in
                        Button(action: {
                            if let userId = friend.supabaseUserId {
                                profileNavigator.openProfile(
                                    handle: .supabase(id: userId, username: friend.username),
                                    source: .mutualFriends,
                                    triggerHaptic: false
                                )
                            } else {
                                profileNavigator.openProfile(
                                    handle: .mention(username: friend.username),
                                    source: .mutualFriends,
                                    triggerHaptic: false
                                )
                            }
                        }) {
                            VStack(spacing: DS.Spacing.xs) {
                                ProfileAvatarView(
                                    profileImageId: friend.effectiveProfileImageID,
                                    profileImageURL: nil,
                                    username: friend.username,
                                    size: 60
                                )
                                
                                Text(friend.displayNameOrUsername)
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textPrimary)
                                    .lineLimit(1)
                                    .frame(width: 60)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

