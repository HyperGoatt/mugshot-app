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
    @State private var friends: [User] = []
    @State private var friendsCount: Int = 0
    @State private var isLoading = true
    @State private var isLoadingFriendship = false
    @State private var showRemoveFriendAlert = false
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var showFriendsSheet = false
    @State private var showMutualFriendsSheet = false
    @State private var selectedTab: ProfileContentTab = .posts
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var refreshTrigger = UUID() // Force view refresh when data loads
    
    @Environment(\.dismiss) var dismiss

    // Custom initializer so we can optionally seed with an initial profile
    // (e.g., when opening from a mention tap) and skip the full-screen skeleton.
    init(
        dataManager: DataManager,
        userId: String,
        initialProfile: RemoteUserProfile? = nil
    ) {
        self.dataManager = dataManager
        self.userId = userId
        _userProfile = State(initialValue: initialProfile)
        _isLoading = State(initialValue: initialProfile == nil)
    }
    
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
        let filtered = dataManager.appData.visits
            .filter { visit in
                // Match by supabaseUserId (String) or userId (UUID converted from String)
                visit.supabaseUserId == userId || 
                (visit.userId == UUID(uuidString: userId))
            }
            .sorted { $0.createdAt > $1.createdAt }
        
        #if DEBUG
        print("[OtherUserProfileView] userVisits count: \(filtered.count) for userId: \(userId)")
        print("[OtherUserProfileView] Total visits in appData: \(dataManager.appData.visits.count)")
        #endif
        
        return filtered
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
                        // Improved loading state with skeleton placeholders
                        ProfileLoadingSkeletonView()
                            .transition(.opacity)
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
                                showFriendsSheet = true
                            },
                            onMutualTap: mutualFriends.isEmpty ? nil : {
                                showMutualFriendsSheet = true
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
                        .id(refreshTrigger) // Force refresh when data loads
                        
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
                    UnifiedCafeView(
                        cafe: cafe,
                        dataManager: dataManager,
                        presentationMode: .fullScreen
                    )
                }
            }
            .sheet(isPresented: $showFriendsSheet) {
                UserListSheet(
                    title: "Friends",
                    users: friends,
                    emptyMessage: "No friends yet",
                    dataManager: dataManager
                )
            }
            .sheet(isPresented: $showMutualFriendsSheet) {
                UserListSheet(
                    title: "Mutual Friends",
                    users: mutualFriends,
                    emptyMessage: "No mutual friends yet",
                    dataManager: dataManager
                )
            }
            .task {
                await loadProfile()
            }
            .onChange(of: dataManager.appData.visits.count) { _, _ in
                // Refresh when visits are loaded/updated
                // This ensures the view updates when fetchOtherUserVisits completes
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
                    await loadFriendsList()
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
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(friendButtonBorder ?? Color.clear, lineWidth: friendshipStatus == .friends ? 1.5 : 0)
                    )
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
        case .outgoingRequest:
            return DS.Colors.textSecondary
        case .friends:
            // Friends state uses mint accent for clear visibility
            return DS.Colors.primaryAccent
        }
    }
    
    private var friendButtonBackground: Color {
        switch friendshipStatus {
        case .none, .incomingRequest:
            return DS.Colors.primaryAccent
        case .outgoingRequest:
            return DS.Colors.cardBackgroundAlt
        case .friends:
            // Friends state uses soft mint fill with border for visibility
            return DS.Colors.mintSoftFill
        }
    }
    
    private var friendButtonBorder: Color? {
        switch friendshipStatus {
        case .friends:
            // Add border for better visibility on gray backgrounds
            return DS.Colors.primaryAccent
        default:
            return nil
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
            .id(refreshTrigger) // Force refresh when visits load
            
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
        // If we already have a seeded profile (e.g., from a mention tap),
        // skip the extra profile fetch and just hydrate secondary data.
        if userProfile != nil {
            isLoading = false
            
            Task {
                await loadFriendshipStatus()
            }
            
            Task {
                await loadMutualFriends()
            }
            
            Task {
                await loadFriendsList()
            }
            
            Task {
                do {
                    try await dataManager.fetchOtherUserVisits(userId: userId)
                    await MainActor.run {
                        refreshTrigger = UUID()
                        #if DEBUG
                        print("[OtherUserProfileView] (Seeded) Visits loaded - userVisits count: \(userVisits.count)")
                        print("[OtherUserProfileView] (Seeded) Stats - visits: \(stats.totalVisits), cafes: \(stats.totalCafes), avg: \(stats.averageScore)")
                        #endif
                    }
                } catch {
                    print("[OtherUserProfileView] Error loading visits: \(error.localizedDescription)")
                }
            }
            
            return
        }
        
        // Normal path: no initial profile, fetch core profile first.
        do {
            await MainActor.run {
                isLoading = true
            }
            
            if let profile = try await dataManager.fetchOtherUserProfile(userId: userId) {
                await MainActor.run {
                    userProfile = profile
                    isLoading = false
                }
                
                Task {
                    await loadFriendshipStatus()
                }
                
                Task {
                    await loadMutualFriends()
                }
                
                Task {
                    await loadFriendsList()
                }
                
                Task {
                    do {
                        try await dataManager.fetchOtherUserVisits(userId: userId)
                        await MainActor.run {
                            refreshTrigger = UUID()
                            #if DEBUG
                            print("[OtherUserProfileView] Visits loaded - userVisits count: \(userVisits.count)")
                            print("[OtherUserProfileView] Stats - visits: \(stats.totalVisits), cafes: \(stats.totalCafes), avg: \(stats.averageScore)")
                            #endif
                        }
                    } catch {
                        print("[OtherUserProfileView] Error loading visits: \(error.localizedDescription)")
                    }
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
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
                    .sorted { $0.displayNameOrUsername.lowercased() < $1.displayNameOrUsername.lowercased() }
            }
        } catch {
            print("[OtherUserProfileView] Error loading mutual friends: \(error.localizedDescription)")
        }
    }
    
    private func loadFriendsList() async {
        do {
            let fetchedFriends = try await dataManager.fetchFriends(for: userId)
                .sorted { $0.displayNameOrUsername.lowercased() < $1.displayNameOrUsername.lowercased() }
            await MainActor.run {
                friends = fetchedFriends
                friendsCount = fetchedFriends.count
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
                    }
                    await dataManager.refreshFriendsList()
                    await loadFriendsList()
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

// MARK: - Profile Loading Skeleton

/// A polished skeleton loading state for profile view
struct ProfileLoadingSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Banner skeleton
            Rectangle()
                .fill(skeletonGradient)
                .frame(height: 120)
            
            // Avatar skeleton
            Circle()
                .fill(skeletonGradient)
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(DS.Colors.cardBackground, lineWidth: 3)
                )
                .offset(y: -40)
                .padding(.bottom, -40)
            
            VStack(spacing: DS.Spacing.md) {
                // Name skeleton
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(skeletonGradient)
                    .frame(width: 140, height: 20)
                
                // Username skeleton
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(skeletonGradient)
                    .frame(width: 100, height: 14)
                
                // Bio skeleton
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(skeletonGradient)
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(skeletonGradient)
                        .frame(width: 200, height: 12)
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Button skeleton
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(skeletonGradient)
                    .frame(height: 44)
                    .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Stats skeleton
                HStack(spacing: DS.Spacing.lg) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .fill(skeletonGradient)
                                .frame(width: 40, height: 20)
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .fill(skeletonGradient)
                                .frame(width: 60, height: 12)
                        }
                    }
                }
                .padding(.top, DS.Spacing.md)
            }
            .padding(.top, DS.Spacing.md)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var skeletonGradient: some ShapeStyle {
        DS.Colors.cardBackgroundAlt.opacity(isAnimating ? 0.6 : 0.3)
    }
}

// MARK: - Friends / Mutual Friends Sheet

private struct UserListSheet: View {
    let title: String
    let users: [User]
    let emptyMessage: String
    @ObservedObject var dataManager: DataManager
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if users.isEmpty {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "person.2")
                            .font(.system(size: 36))
                            .foregroundColor(DS.Colors.iconSubtle)
                        Text(emptyMessage)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(users) { user in
                            if let supabaseId = user.supabaseUserId {
                                NavigationLink {
                                    OtherUserProfileView(dataManager: dataManager, userId: supabaseId)
                                } label: {
                                    userRow(user)
                                }
                            } else {
                                userRow(user)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func userRow(_ user: User) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ProfileAvatarView(
                profileImageId: user.effectiveProfileImageID,
                profileImageURL: user.avatarURL,
                username: user.username,
                size: 48
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayNameOrUsername)
                    .font(DS.Typography.subheadline(.semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                Text("@\(user.username)")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
            
            if user.supabaseUserId != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.iconSubtle)
            }
        }
        .padding(.vertical, 4)
    }
}
