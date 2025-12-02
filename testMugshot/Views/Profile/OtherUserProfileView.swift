//
//  OtherUserProfileView.swift
//  testMugshot
//
//  Public profile view for viewing other users (not the logged-in user).
//  Similar structure to ProfileTabView but without self-only elements like Share/Edit.
//

import SwiftUI

struct OtherUserProfileView: View {
    @ObservedObject var dataManager: DataManager
    let userId: String
    
    @State private var userProfile: RemoteUserProfile?
    @State private var friendshipStatus: FriendshipStatus = .none
    @State private var mutualFriends: [User] = []
    @State private var friendsCount: Int = 0
    @State private var isLoading = true
    @State private var isLoadingFriendship = false
    @State private var showRemoveFriendAlert = false
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var selectedTab: ProfileContentTab = .posts
    @StateObject private var hapticsManager = HapticsManager.shared
    
    @Environment(\.dismiss) var dismiss
    
    enum ProfileContentTab: String, CaseIterable {
        case posts = "Posts"
        case cafes = "Cafes"
    }
    
    // MARK: - Computed Properties
    
    private var localUser: User? {
        guard let profile = userProfile else { return nil }
        let userUUID = UUID(uuidString: profile.id) ?? UUID()
        return profile.toLocalUser(existing: nil, overridingId: userUUID)
    }
    
    private var userVisits: [Visit] {
        dataManager.appData.visits
            .filter { $0.supabaseUserId == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double) {
        let visits = userVisits
        let uniqueCafes = Set(visits.map { $0.cafeId })
        let avgScore = visits.isEmpty ? 0.0 : visits.reduce(0.0) { $0 + $1.overallScore } / Double(visits.count)
        return (visits.count, uniqueCafes.count, avgScore)
    }
    
    private var topCafes: [(cafe: Cafe, visitCount: Int, avgScore: Double)] {
        let visits = userVisits
        let visitsByCafe = Dictionary(grouping: visits, by: { $0.cafeId })
        
        var cafeStats: [(cafe: Cafe, visitCount: Int, avgScore: Double)] = []
        for (cafeId, cafeVisits) in visitsByCafe {
            guard let cafe = dataManager.getCafe(id: cafeId) else { continue }
            let avgScore = cafeVisits.reduce(0.0) { $0 + $1.overallScore } / Double(cafeVisits.count)
            cafeStats.append((cafe: cafe, visitCount: cafeVisits.count, avgScore: avgScore))
        }
        
        return cafeStats.sorted {
            if $0.avgScore == $1.avgScore {
                return $0.visitCount > $1.visitCount
            }
            return $0.avgScore > $1.avgScore
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, DS.Spacing.xxl)
                    } else if let profile = userProfile {
                        // Profile Header (banner + avatar + name)
                        profileHeaderSection(profile: profile)
                        
                        // Bio Section
                        ProfileBioSection(
                            bio: profile.bio,
                            location: profile.location,
                            favoriteDrink: profile.favoriteDrink
                        )
                        .padding(.top, DS.Spacing.sm)
                        
                        // Friend Action Button (instead of Edit/Share for self-profile)
                        friendActionButtonSection
                            .padding(.top, DS.Spacing.md)
                        
                        // Social Row (friends count + social links)
                        ProfileSocialRow(
                            friendsCount: friendsCount,
                            mutualFriendsCount: mutualFriends.count,
                            instagramHandle: profile.instagramHandle,
                            websiteURL: profile.websiteURL,
                            onFriendsTap: {
                                // Could navigate to friend list in future
                            }
                        )
                        .padding(.top, DS.Spacing.md)
                        
                        // Stats Ribbon
                        CoffeeStatsRibbon(
                            totalVisits: stats.totalVisits,
                            totalCafes: stats.totalCafes,
                            averageRating: stats.averageScore,
                            favoriteDrinkType: nil,
                            topCafe: topCafes.first.map { ($0.cafe.name, $0.avgScore) },
                            onTopCafeTap: {
                                if let topCafe = topCafes.first {
                                    selectedCafe = topCafe.cafe
                                    showCafeDetail = true
                                }
                            }
                        )
                        .padding(.top, DS.Spacing.lg)
                        
                        // Content Tabs (Posts / Cafes)
                        contentTabsSection
                        
                        // Mutual Friends Section
                        if !mutualFriends.isEmpty {
                            MutualFriendsSection(mutualFriends: mutualFriends, dataManager: dataManager)
                                .padding(.horizontal, DS.Spacing.pagePadding)
                                .padding(.top, DS.Spacing.lg)
                        }
                    } else {
                        // User not found state
                        DSBaseCard {
                            VStack(spacing: DS.Spacing.md) {
                                Image(systemName: "person.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(DS.Colors.iconSubtle)
                                Text("User not found")
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xxl)
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.xxl)
                    }
                }
                .padding(.bottom, DS.Spacing.xxl * 2)
            }
            .background(DS.Colors.screenBackground)
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .sheet(isPresented: $showCafeDetail) {
                if let cafe = selectedCafe {
                    CafeDetailView(cafe: cafe, dataManager: dataManager)
                }
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
    
    // MARK: - Profile Header
    
    private func profileHeaderSection(profile: RemoteUserProfile) -> some View {
        ProfileCompactHeader(
            displayName: profile.displayName,
            username: profile.username,
            bio: profile.bio,
            location: profile.location,
            favoriteDrink: profile.favoriteDrink,
            profileImageURL: profile.avatarURL,
            bannerImageURL: profile.bannerURL,
            profileImageId: nil,
            bannerImageId: nil
        )
    }
    
    // MARK: - Friend Action Button
    
    private var friendActionButtonSection: some View {
        HStack {
            if isLoadingFriendship {
                ProgressView()
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
            } else {
                Button(action: handleFriendAction) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: friendButtonIcon)
                            .font(.system(size: 14, weight: .medium))
                        Text(friendButtonText)
                            .font(DS.Typography.buttonLabel)
                    }
                    .foregroundColor(friendButtonTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(friendButtonBackground)
                    .cornerRadius(DS.Radius.lg)
                }
                .disabled(isLoadingFriendship)
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
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
            return "Friends"
        }
    }
    
    private var friendButtonIcon: String {
        switch friendshipStatus {
        case .none:
            return "person.badge.plus"
        case .outgoingRequest:
            return "clock"
        case .incomingRequest:
            return "person.badge.plus"
        case .friends:
            return "checkmark"
        }
    }
    
    private var friendButtonTextColor: Color {
        switch friendshipStatus {
        case .none, .incomingRequest:
            return DS.Colors.textOnMint
        case .outgoingRequest, .friends:
            return DS.Colors.textPrimary
        }
    }
    
    private var friendButtonBackground: Color {
        switch friendshipStatus {
        case .none, .incomingRequest:
            return DS.Colors.primaryAccent
        case .outgoingRequest, .friends:
            return DS.Colors.cardBackgroundAlt
        }
    }
    
    // MARK: - Content Tabs
    
    private var contentTabsSection: some View {
        VStack(spacing: 0) {
            // Tab selector
            DSDesignSegmentedControl(
                options: ProfileContentTab.allCases.map { $0.rawValue },
                selectedIndex: Binding(
                    get: { ProfileContentTab.allCases.firstIndex(of: selectedTab) ?? 0 },
                    set: { newIndex in
                        let newTab = ProfileContentTab.allCases[newIndex]
                        if newTab != selectedTab {
                            hapticsManager.selectionChanged()
                        }
                        selectedTab = newTab
                    }
                )
            )
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
            
            // Tab content
            contentView
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .posts:
            ProfilePostsGrid(
                visits: Array(userVisits.prefix(50)),
                onSelectVisit: { visit in
                    hapticsManager.lightTap()
                    selectedVisit = visit
                }
            )
            .padding(.horizontal, 1)
            
        case .cafes:
            otherUserCafesView
                .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    @ViewBuilder
    private var otherUserCafesView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if topCafes.isEmpty {
                // Empty state
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 40))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    Text("No cafes yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl * 2)
            } else {
                ForEach(topCafes, id: \.cafe.id) { item in
                    CafeListItem(
                        cafe: item.cafe,
                        visitCount: item.visitCount,
                        avgScore: item.avgScore,
                        dataManager: dataManager,
                        onTap: {
                            selectedCafe = item.cafe
                            showCafeDetail = true
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
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
                
                // Load friends count for this user
                await loadFriendsCount()
                
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
    
    private func loadFriendsCount() async {
        do {
            let friends = try await dataManager.fetchFriends(for: userId)
            await MainActor.run {
                friendsCount = friends.count
            }
        } catch {
            print("[OtherUserProfileView] Error loading friends count: \(error.localizedDescription)")
        }
    }
    
    private func handleFriendAction() {
        hapticsManager.mediumTap()
        
        Task {
            isLoadingFriendship = true
            defer { isLoadingFriendship = false }
            
            do {
                switch friendshipStatus {
                case .none:
                    try await dataManager.sendFriendRequest(to: userId)
                    await loadFriendshipStatus()
                    hapticsManager.playSuccess()
                    
                case .incomingRequest(let requestId):
                    try await dataManager.acceptFriendRequest(requestId: requestId)
                    await MainActor.run {
                        friendshipStatus = .friends
                        friendsCount += 1
                    }
                    await dataManager.refreshFriendsList()
                    hapticsManager.playSuccess()
                    
                case .outgoingRequest:
                    // Do nothing - request already sent
                    break
                    
                case .friends:
                    showRemoveFriendAlert = true
                }
            } catch {
                print("[OtherUserProfileView] Error handling friend action: \(error.localizedDescription)")
                hapticsManager.playError()
            }
        }
    }
}
