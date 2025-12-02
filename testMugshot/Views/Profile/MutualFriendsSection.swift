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
    @State private var selectedUserId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader("\(mutualFriends.count) Mutual Friend\(mutualFriends.count == 1 ? "" : "s")")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(mutualFriends.prefix(10)) { friend in
                        Button(action: {
                            if let userId = friend.supabaseUserId {
                                selectedUserId = userId
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
        .sheet(isPresented: Binding(
            get: { selectedUserId != nil },
            set: { if !$0 { selectedUserId = nil } }
        )) {
            if let userId = selectedUserId {
                OtherUserProfileView(dataManager: dataManager, userId: userId)
            }
        }
    }
}

