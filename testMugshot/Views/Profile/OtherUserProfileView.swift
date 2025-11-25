//
//  OtherUserProfileView.swift
//  testMugshot
//
//  Created as part of Friends system implementation.
//

import SwiftUI

struct OtherUserProfileView: View {
    @ObservedObject var dataManager: DataManager
    let userId: String
    
    @State private var userProfile: RemoteUserProfile?
    @State private var friendshipStatus: FriendshipStatus = .none
    @State private var mutualFriends: [User] = []
    @State private var isLoading = true
    @State private var isLoadingFriendship = false
    @State private var showRemoveFriendAlert = false
    @State private var selectedVisit: Visit?
    
    @Environment(\.dismiss) var dismiss
    
    private var localUser: User? {
        guard let profile = userProfile else { return nil }
        let userUUID = UUID(uuidString: profile.id) ?? UUID()
        return profile.toLocalUser(existing: nil, overridingId: userUUID)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if let profile = userProfile {
                        OtherUserProfileHeaderView(
                            displayName: profile.displayName,
                            username: profile.username,
                            bio: profile.bio,
                            location: profile.location,
                            favoriteDrink: profile.favoriteDrink,
                            instagramHandle: profile.instagramHandle,
                            website: profile.websiteURL,
                            profileImageURL: profile.avatarURL,
                            bannerImageURL: profile.bannerURL,
                            friendButton: friendActionButton
                        )
                        
                        VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                            // Mutual Friends Section
                            if !mutualFriends.isEmpty {
                                MutualFriendsSection(mutualFriends: mutualFriends, dataManager: dataManager)
                                    .padding(.horizontal, DS.Spacing.pagePadding)
                            }
                            
                            // User's Visits
                            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                                DSSectionHeader("Recent Visits")
                                    .padding(.horizontal, DS.Spacing.pagePadding)
                                
                                userVisitsView
                                    .padding(.horizontal, DS.Spacing.pagePadding)
                            }
                        }
                        .padding(.top, DS.Spacing.sectionVerticalGap)
                        .padding(.bottom, DS.Spacing.xxl)
                    } else {
                        DSBaseCard {
                            Text("User not found")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                    }
                }
            }
            .background(DS.Colors.screenBackground)
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .task {
                await loadProfile()
            }
            .alert("Remove Friend", isPresented: $showRemoveFriendAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Task {
                        isLoadingFriendship = true
                        defer { isLoadingFriendship = false }
                        
                        do {
                            try await dataManager.removeFriend(userId: userId)
                            await MainActor.run {
                                friendshipStatus = .none
                            }
                            await dataManager.refreshFriendsList()
                        } catch {
                            print("[OtherUserProfileView] Error removing friend: \(error.localizedDescription)")
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to remove this friend?")
            }
        }
    }
    
    private var friendActionButton: AnyView {
        if isLoadingFriendship {
            return AnyView(
                ProgressView()
                    .frame(width: 120, height: 44)
            )
        } else {
            return AnyView(
                Button(action: handleFriendAction) {
                    Text(friendButtonText)
                        .font(DS.Typography.buttonLabel)
                        .foregroundColor(friendButtonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(friendButtonBackground)
                        .cornerRadius(DS.Radius.primaryButton)
                }
                .frame(width: 120)
                .disabled(isLoadingFriendship)
            )
        }
    }
    
    private var friendButtonText: String {
        switch friendshipStatus {
        case .none:
            return "Add Friend"
        case .outgoingRequest:
            return "Request Sent"
        case .incomingRequest:
            return "Accept Request"
        case .friends:
            return "Friends ✓"
        }
    }
    
    private var friendButtonTextColor: Color {
        switch friendshipStatus {
        case .none, .incomingRequest:
            return DS.Colors.textOnMint
        case .outgoingRequest:
            return DS.Colors.textPrimary
        case .friends:
            return DS.Colors.textPrimary
        }
    }
    
    private var friendButtonBackground: Color {
        switch friendshipStatus {
        case .none, .incomingRequest:
            return DS.Colors.primaryAccent
        case .outgoingRequest:
            return DS.Colors.cardBackgroundAlt
        case .friends:
            return DS.Colors.cardBackgroundAlt
        }
    }
    
    @ViewBuilder
    private var userVisitsView: some View {
        let visits = dataManager.appData.visits
            .filter { $0.supabaseUserId == userId }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(20)
            .map { $0 }
        
        if visits.isEmpty {
            DSBaseCard {
                Text("No visits yet")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        } else {
            ForEach(visits) { visit in
                if dataManager.getCafe(id: visit.cafeId) != nil {
                    VisitCard(visit: visit, dataManager: dataManager, selectedScope: .everyone)
                        .onTapGesture {
                            selectedVisit = visit
                        }
                }
            }
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load user profile
            if let profile = try await dataManager.fetchOtherUserProfile(userId: userId) {
                await MainActor.run {
                    userProfile = profile
                }
                
                // Load friendship status
                await loadFriendshipStatus()
                
                // Load mutual friends
                await loadMutualFriends()
                
                // Load user's visits
                try? await dataManager.fetchOtherUserVisits(userId: userId)
            }
        } catch {
            print("[OtherUserProfileView] Error loading profile: \(error.localizedDescription)")
        }
    }
    
    private func loadFriendshipStatus() async {
        do {
            let status = try await dataManager.checkFriendshipStatus(for: userId)
            await MainActor.run {
                friendshipStatus = status
            }
        } catch {
            print("[OtherUserProfileView] Error loading friendship status: \(error.localizedDescription)")
        }
    }
    
    private func loadMutualFriends() async {
        do {
            let mutuals = try await dataManager.fetchMutualFriends(userId: userId)
            await MainActor.run {
                mutualFriends = mutuals
            }
        } catch {
            print("[OtherUserProfileView] Error loading mutual friends: \(error.localizedDescription)")
        }
    }
    
    private func handleFriendAction() {
        Task {
            isLoadingFriendship = true
            defer { isLoadingFriendship = false }
            
            do {
                switch friendshipStatus {
                case .none:
                    try await dataManager.sendFriendRequest(to: userId)
                    // Reload status to get the actual request ID
                    await loadFriendshipStatus()
                case .incomingRequest(let requestId):
                    try await dataManager.acceptFriendRequest(requestId: requestId)
                    await MainActor.run {
                        friendshipStatus = .friends
                    }
                    // Refresh friends list
                    await dataManager.refreshFriendsList()
                case .outgoingRequest(_):
                    // Do nothing - request already sent (button should be disabled)
                    break
                case .friends:
                    // Show confirmation alert for removing friend
                    showRemoveFriendAlert = true
                }
            } catch {
                print("[OtherUserProfileView] Error handling friend action: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Other User Profile Header

struct OtherUserProfileHeaderView: View {
    let displayName: String?
    let username: String?
    let bio: String?
    let location: String?
    let favoriteDrink: String?
    let instagramHandle: String?
    let website: String?
    let profileImageURL: String?
    let bannerImageURL: String?
    let friendButton: AnyView
    
    private let avatarSize: CGFloat = 180
    
    private var displayNameOrUsername: String {
        displayName ?? username ?? "User"
    }
    
    private var usernameText: String {
        username ?? "user"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Banner strip at the top
            ZStack(alignment: .topTrailing) {
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
                                LinearGradient(
                                    colors: [DS.Colors.mintLight, DS.Colors.mintSoftFill],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            @unknown default:
                                LinearGradient(
                                    colors: [DS.Colors.mintLight, DS.Colors.mintSoftFill],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    } else {
                        LinearGradient(
                            colors: [DS.Colors.mintLight, DS.Colors.mintSoftFill],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(height: 150)
                .cornerRadius(DS.Radius.card, corners: [.topLeft, .topRight])
                .clipped()
            }
            
            // Profile card that sits below the banner
            ZStack(alignment: .top) {
                DSBaseCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        // Space for overlapping avatar
                        Spacer()
                            .frame(height: avatarSize / 2 + DS.Spacing.sm)
                        
                        // Friend button
                        HStack {
                            Spacer()
                            AnyView(friendButton)
                        }
                        .padding(.bottom, DS.Spacing.sm)
                        
                        // Display name
                        Text(displayNameOrUsername)
                            .font(DS.Typography.screenTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                        
                        // Username
                        Text("@\(usernameText)")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        // Bio
                        if let bio = bio, !bio.isEmpty {
                            Text(bio)
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, DS.Spacing.xs)
                        }
                        
                        // Meta row (favorite drink + location)
                        HStack(spacing: DS.Spacing.md) {
                            if let favoriteDrink = favoriteDrink, !favoriteDrink.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "cup.and.saucer")
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
                        .padding(.top, DS.Spacing.sm)
                    }
                }
                
                // Centered avatar overlapping banner and card
                ProfileAvatarView(
                    profileImageId: nil,
                    profileImageURL: profileImageURL,
                    username: usernameText,
                    size: avatarSize
                )
                .frame(width: avatarSize, height: avatarSize)
                .offset(y: -avatarSize / 2)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .offset(y: -avatarSize / 2)
            .padding(.bottom, DS.Spacing.sectionVerticalGap)
        }
    }
}

