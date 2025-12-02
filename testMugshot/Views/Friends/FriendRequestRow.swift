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
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var isLoading = false
    @State private var showProfile = false
    
    @State private var userProfile: RemoteUserProfile?
    @State private var isLoadingProfile = false
    
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
                
                // User info
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(user?.displayNameOrUsername ?? userProfile?.displayName ?? userProfile?.username ?? "User")
                        .font(DS.Typography.cardTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Text("@\(user?.username ?? userProfile?.username ?? "user")")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                // Actions
                if isLoading {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else if isIncoming {
                    HStack(spacing: DS.Spacing.sm) {
                        Button(action: {
                            // Haptic: confirm accept friend request
                            hapticsManager.lightTap()
                            Task {
                                await acceptRequest()
                            }
                        }) {
                            Text("Accept")
                                .font(DS.Typography.buttonLabel)
                                .foregroundColor(DS.Colors.textOnMint)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(DS.Colors.primaryAccent)
                                .cornerRadius(DS.Radius.lg)
                        }
                        
                        Button(action: {
                            // Haptic: confirm reject friend request
                            hapticsManager.lightTap()
                            Task {
                                await rejectRequest()
                            }
                        }) {
                            Text("Reject")
                                .font(DS.Typography.buttonLabel)
                                .foregroundColor(DS.Colors.textPrimary)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(DS.Colors.cardBackgroundAlt)
                                .cornerRadius(DS.Radius.lg)
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
                showProfile = true
            }
        }
        .sheet(isPresented: $showProfile) {
            if isIncoming {
                OtherUserProfileView(dataManager: dataManager, userId: request.fromUserId)
            } else {
                OtherUserProfileView(dataManager: dataManager, userId: request.toUserId)
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
            // Haptic: friend request accepted successfully
            await MainActor.run {
                hapticsManager.playSuccess()
            }
            // Refresh friends list
            await dataManager.refreshFriendsList()
            // Notify parent to refresh requests list
            onRequestAction?()
        } catch {
            print("[FriendRequestRow] Error accepting request: \(error.localizedDescription)")
            // TODO: Show user-friendly error message
        }
    }
    
    private func rejectRequest() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await dataManager.rejectFriendRequest(requestId: request.id)
            // Notify parent to refresh requests list
            onRequestAction?()
        } catch {
            print("[FriendRequestRow] Error rejecting request: \(error.localizedDescription)")
            // TODO: Show user-friendly error message
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

