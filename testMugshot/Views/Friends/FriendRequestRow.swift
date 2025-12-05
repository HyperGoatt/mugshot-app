//
//  FriendRequestRow.swift
//  testMugshot
//
//  Created as part of Friends system implementation.
//

import SwiftUI

struct FriendRequestRow: View {
    let request: FriendRequest
    let isIncoming: Bool
    let currentUserId: String
    @ObservedObject var dataManager: DataManager
    var onRequestAction: (() -> Void)? = nil
    @EnvironmentObject private var hapticsManager: HapticsManager
    @State private var isLoading = false
    
    @State private var userProfile: RemoteUserProfile?
    @State private var isLoadingProfile = false
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    
    private var user: User? {
        guard let profile = userProfile else { return nil }
        let userUUID = UUID(uuidString: profile.id) ?? UUID()
        return profile.toLocalUser(existing: nil, overridingId: userUUID)
    }
    
    var body: some View {
        DSBaseCard {
            HStack(spacing: DS.Spacing.md) {
                // Avatar
                ProfileAvatarView(
                    profileImageId: user?.effectiveProfileImageID,
                    profileImageURL: userProfile?.avatarURL,
                    username: user?.username ?? userProfile?.username ?? "user",
                    size: 50
                )
                
                // User info - use flexible layout
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(user?.displayNameOrUsername ?? userProfile?.displayName ?? userProfile?.username ?? "User")
                        .font(DS.Typography.cardTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text("@\(user?.username ?? userProfile?.username ?? "user")")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                
                // Actions - fixed width buttons
                if isLoading {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else if isIncoming {
                    HStack(spacing: DS.Spacing.xs) {
                        // Accept button with checkmark icon
                        Button(action: {
                            hapticsManager.lightTap()
                            Task {
                                await acceptRequest()
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DS.Colors.textOnMint)
                                .frame(width: 40, height: 36)
                                .background(DS.Colors.primaryAccent)
                                .cornerRadius(DS.Radius.md)
                        }
                        
                        // Reject button with X icon
                        Button(action: {
                            hapticsManager.lightTap()
                            Task {
                                await rejectRequest()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DS.Colors.textSecondary)
                                .frame(width: 40, height: 36)
                                .background(DS.Colors.cardBackgroundAlt)
                                .cornerRadius(DS.Radius.md)
                        }
                    }
                } else {
                    Text("Pending")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
        .onTapGesture {
            if !isLoading {
                // Haptic: confirm friend request row tap
                hapticsManager.lightTap()
                let otherUserId = isIncoming ? request.fromUserId : request.toUserId
                profileNavigator.openProfile(
                    handle: .supabase(
                        id: otherUserId,
                        username: userProfile?.username,
                        seedProfile: userProfile
                    ),
                    source: .friendRequest,
                    triggerHaptic: false
                )
            }
        }
        .task {
            await loadUserProfile()
        }
    }
    
    private func acceptRequest() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await dataManager.acceptFriendRequest(requestId: request.id)
            // acceptFriendRequest already calls refreshFriendsState internally
            
            // Haptic: friend request accepted successfully
            await MainActor.run {
                hapticsManager.playSuccess()
            }
            
            // Notify parent to refresh requests list
            onRequestAction?()
        } catch {
            print("[FriendRequestRow] Error accepting request: \(error.localizedDescription)")
            await MainActor.run {
                hapticsManager.playError()
            }
        }
    }
    
    private func rejectRequest() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await dataManager.rejectFriendRequest(requestId: request.id)
            // rejectFriendRequest already calls refreshFriendsState internally
            
            // Notify parent to refresh requests list
            onRequestAction?()
        } catch {
            print("[FriendRequestRow] Error rejecting request: \(error.localizedDescription)")
            await MainActor.run {
                hapticsManager.playError()
            }
        }
    }
    
    private func loadUserProfile() async {
        guard userProfile == nil && !isLoadingProfile else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        
        let otherUserId = isIncoming ? request.fromUserId : request.toUserId
            do {
                if let profile = try await dataManager.fetchOtherUserProfile(userId: otherUserId) {
                    await MainActor.run {
                        userProfile = profile
                    }
                }
            } catch {
                print("[FriendRequestRow] Error loading user profile for \(otherUserId): \(error.localizedDescription)")
                // Continue without profile - will show placeholder
            }
    }
}

