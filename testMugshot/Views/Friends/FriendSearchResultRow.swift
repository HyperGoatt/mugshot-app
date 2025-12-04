//
//  FriendSearchResultRow.swift
//  testMugshot
//
//  Search result row with friendship status actions.
//

import SwiftUI

struct FriendSearchResultRow: View {
    let profile: RemoteUserProfile
    let friendshipStatus: FriendshipStatus
    @ObservedObject var dataManager: DataManager
    var onStatusChanged: (() -> Void)? = nil
    
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var isLoading = false
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    
    var body: some View {
        DSBaseCard {
            HStack(spacing: DS.Spacing.md) {
                // Avatar
                ProfileAvatarView(
                    profileImageId: nil,
                    profileImageURL: profile.avatarURL,
                    username: profile.username,
                    size: 50
                )
                
                // User info
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(profile.displayName)
                        .font(DS.Typography.cardTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text("@\(profile.username)")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Action button based on friendship status
                if isLoading {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    actionButton
                }
            }
        }
        .onTapGesture {
            hapticsManager.lightTap()
            profileNavigator.openProfile(
                handle: .supabase(id: profile.id, username: profile.username, seedProfile: profile),
                source: .friendSearch,
                triggerHaptic: false
            )
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch friendshipStatus {
        case .none:
            // Add Friend button
            Button(action: sendFriendRequest) {
                Text("Add Friend")
                    .font(DS.Typography.buttonLabel)
                    .foregroundColor(DS.Colors.textOnMint)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.lg)
            }
            
        case .outgoingRequest(let requestId):
            // Requested - with cancel option
            Button(action: { cancelRequest(requestId: requestId) }) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Requested")
                        .font(DS.Typography.caption1(.medium))
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.cardBackgroundAlt)
                .cornerRadius(DS.Radius.lg)
            }
            
        case .incomingRequest(let requestId):
            // Accept button
            Button(action: { acceptRequest(requestId: requestId) }) {
                Text("Accept")
                    .font(DS.Typography.buttonLabel)
                    .foregroundColor(DS.Colors.textOnMint)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.lg)
            }
            
        case .friends:
            // Friends pill (non-interactive)
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                Text("Friends")
                    .font(DS.Typography.caption1(.medium))
            }
            .foregroundColor(DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.cardBackgroundAlt)
            .cornerRadius(DS.Radius.lg)
        }
    }
    
    // MARK: - Actions
    
    private func sendFriendRequest() {
        hapticsManager.lightTap()
        isLoading = true
        
        Task {
            defer { isLoading = false }
            do {
                try await dataManager.sendFriendRequest(to: profile.id)
                // Refresh friend requests to update status
                _ = try? await dataManager.fetchFriendRequests()
                hapticsManager.playSuccess()
                onStatusChanged?()
            } catch {
                print("[FriendSearchResultRow] Error sending friend request: \(error.localizedDescription)")
                hapticsManager.playError()
            }
        }
    }
    
    private func cancelRequest(requestId: UUID) {
        hapticsManager.lightTap()
        isLoading = true
        
        Task {
            defer { isLoading = false }
            do {
                try await dataManager.cancelFriendRequest(requestId: requestId)
                // Refresh friend requests to update status
                _ = try? await dataManager.fetchFriendRequests()
                onStatusChanged?()
            } catch {
                print("[FriendSearchResultRow] Error canceling request: \(error.localizedDescription)")
                hapticsManager.playError()
            }
        }
    }
    
    private func acceptRequest(requestId: UUID) {
        hapticsManager.lightTap()
        isLoading = true
        
        Task {
            defer { isLoading = false }
            do {
                try await dataManager.acceptFriendRequest(requestId: requestId)
                await dataManager.refreshFriendsList()
                // Refresh friend requests to update status
                _ = try? await dataManager.fetchFriendRequests()
                hapticsManager.playSuccess()
                onStatusChanged?()
            } catch {
                print("[FriendSearchResultRow] Error accepting request: \(error.localizedDescription)")
                hapticsManager.playError()
            }
        }
    }
}

