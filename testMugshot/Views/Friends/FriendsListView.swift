//
//  FriendsListView.swift
//  testMugshot
//
//  Displays current friends list with navigation to profiles.
//

import SwiftUI

struct FriendsListView: View {
    @ObservedObject var dataManager: DataManager
    
    @State private var friends: [User] = []
    @State private var isLoading = true
    @State private var selectedUserId: String?
    
    var body: some View {
        Group {
            if isLoading {
                loadingState
            } else if friends.isEmpty {
                emptyState
            } else {
                friendsList
            }
        }
        .task {
            await loadFriends()
        }
        .refreshable {
            await loadFriends()
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
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
            Text("Loading friends...")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl * 2)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        DSBaseCard {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "person.2")
                    .font(.system(size: 48))
                    .foregroundColor(DS.Colors.iconSubtle)
                
                Text("No friends yet")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text("Search by username to add your first coffee friends ☕️")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxl)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Friends List
    
    private var friendsList: some View {
        LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
            ForEach(friends) { friend in
                FriendRow(
                    friend: friend,
                    onTap: {
                        if let supabaseId = friend.supabaseUserId {
                            selectedUserId = supabaseId
                        }
                    }
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
        .onAppear {
            print("[FriendsList] Showing \(friends.count) friends")
        }
    }
    
    // MARK: - Data Loading
    
    private func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let supabaseUserId = dataManager.appData.supabaseUserId else {
            return
        }
        
        do {
            let loadedFriends = try await dataManager.fetchFriends(for: supabaseUserId)
            await MainActor.run {
                friends = loadedFriends.sorted { ($0.displayName ?? $0.username) < ($1.displayName ?? $1.username) }
            }
        } catch {
            print("[FriendsListView] Error loading friends: \(error.localizedDescription)")
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: User
    let onTap: () -> Void
    
    @StateObject private var hapticsManager = HapticsManager.shared
    
    var body: some View {
        Button(action: {
            hapticsManager.lightTap()
            onTap()
        }) {
            DSBaseCard {
                HStack(spacing: DS.Spacing.md) {
                    // Avatar
                    ProfileAvatarView(
                        profileImageId: friend.effectiveProfileImageID,
                        profileImageURL: nil,
                        username: friend.username,
                        size: 50
                    )
                    
                    // User info
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(friend.displayNameOrUsername)
                            .font(DS.Typography.cardTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Text("@\(friend.username)")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.Colors.iconSubtle)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

