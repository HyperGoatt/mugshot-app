//
//  ProfileTabView.swift
//  testMugshot
//
//  Redesigned profile with compact header and Instagram-style grid
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfileTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var tabCoordinator: TabCoordinator
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    @State private var selectedTab: ProfileContentTab = .posts
    @State private var showEditProfile = false
    @State private var showShareSheet = false
    @State private var showNotifications = false
    @State private var showFriendsHub = false
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var pendingFriendRequestCount: Int = 0
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    enum ProfileContentTab: String, CaseIterable {
        case posts = "Posts"
        case cafes = "Cafes"
        case journal = "Journal"
    }
    
    // MARK: - User Data Properties
    
    private var displayName: String? { dataManager.appData.currentUserDisplayName }
    private var username: String? { dataManager.appData.currentUserUsername }
    private var bio: String? { dataManager.appData.currentUserBio }
    private var location: String? { dataManager.appData.currentUserLocation }
    private var favoriteDrink: String? { dataManager.appData.currentUserFavoriteDrink }
    private var instagramHandle: String? { dataManager.appData.currentUserInstagramHandle }
    private var website: String? { dataManager.appData.currentUserWebsite }
    private var profileImageId: String? { dataManager.appData.currentUserProfileImageId }
    private var bannerImageId: String? { dataManager.appData.currentUserBannerImageId }
    private var avatarURL: String? { dataManager.appData.currentUserAvatarURL }
    private var bannerURL: String? { dataManager.appData.currentUserBannerURL }
    
    private var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        dataManager.getUserStats()
    }
    
    private var friendsCount: Int {
        dataManager.appData.friendsSupabaseUserIds.count
    }
    
    private var topCafe: (name: String, rating: Double)? {
        guard let favorite = dataManager.getFavoriteCafe() else { return nil }
        return (name: favorite.cafe.name, rating: favorite.avgScore)
    }
    
    private var userVisits: [Visit] {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return [] }
        return dataManager.appData.visits
            .filter { $0.userId == currentUserId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 0) {
                    // MARK: - Profile Header Section
                    profileHeaderSection
                    
                    // MARK: - Bio Section
                    ProfileBioSection(
                        bio: bio,
                        location: location,
                        favoriteDrink: favoriteDrink
                    )
                    .padding(.top, DS.Spacing.sm)
                    
                    // MARK: - Action Buttons
                    ProfileActionRow(
                        onEditProfile: { showEditProfile = true },
                        onShareProfile: { showShareSheet = true }
                    )
                    .padding(.top, DS.Spacing.md)
                    
                    // MARK: - Social Row
                    ProfileSocialRow(
                        friendsCount: friendsCount,
                        mutualFriendsCount: nil,
                        instagramHandle: instagramHandle,
                        websiteURL: website,
                        onFriendsTap: { showFriendsHub = true }
                    )
                    .padding(.top, DS.Spacing.md)
                    
                    // MARK: - Stats Ribbon
                    CoffeeStatsRibbon(
                        totalVisits: stats.totalVisits,
                        totalCafes: stats.totalCafes,
                        averageRating: stats.averageScore,
                        favoriteDrinkType: stats.favoriteDrinkType?.rawValue,
                        topCafe: topCafe,
                        onTopCafeTap: {
                        if let favorite = dataManager.getFavoriteCafe() {
                                selectedCafe = favorite.cafe
                                showCafeDetail = true
                            }
                        }
                    )
                    .padding(.top, DS.Spacing.lg)
                    
                    // MARK: - Content Tabs
                    contentTabsSection
                    
                    // MARK: - Developer Tools (Debug only, currently hidden)
                    #if DEBUG
                    // developerToolsSection
                    #endif
                }
                .padding(.bottom, DS.Spacing.xxl * 2)
        }
        .background(DS.Colors.screenBackground)
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
        .sheet(isPresented: $showEditProfile) {
            let user = User(
                username: username ?? "user",
                displayName: displayName,
                location: location ?? "",
                profileImageID: profileImageId,
                bannerImageID: bannerImageId,
                bio: bio ?? "",
                instagramURL: instagramHandle,
                websiteURL: website,
                favoriteDrink: favoriteDrink
            )
            EditProfileView(user: user, dataManager: dataManager)
        }
        .sheet(isPresented: $showShareSheet) {
            if let username = username {
                ShareSheet(items: [createShareText(username: username)])
            }
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
            .sheet(isPresented: $showFriendsHub) {
                FriendsHubView(dataManager: dataManager)
            }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showFriendsHub = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.iconDefault)
                        
                        if pendingFriendRequestCount > 0 {
                            Text("\(pendingFriendRequestCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(DS.Colors.redAccent))
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                Button(action: { showNotifications = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.iconDefault)
                        
                        if unreadNotificationCount > 0 {
                            Text("\(unreadNotificationCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DS.Colors.textOnMint)
                                .padding(4)
                                    .background(Circle().fill(DS.Colors.primaryAccent))
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                    
                    Button(action: { showEditProfile = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.iconDefault)
                    }
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsCenterView(dataManager: dataManager)
        }
        .task {
            do {
                try await dataManager.refreshProfileVisits()
            } catch {
                print("[ProfileTabView] Error refreshing profile visits: \(error.localizedDescription)")
            }
            // Refresh friends list to get accurate count
            await dataManager.refreshFriendsList()
            // Fetch pending friend request count
            await refreshPendingFriendRequestCount()
        }
        .onChange(of: showFriendsHub) { _, isShowing in
            // Refresh badge when returning from Friends hub
            if !isShowing {
                Task {
                    await refreshPendingFriendRequestCount()
                }
            }
        }
        .onChange(of: tabCoordinator.navigationTarget) { _, newTarget in
            handleNavigationTarget(newTarget)
        }
        .onAppear {
            handleNavigationTarget(tabCoordinator.navigationTarget)
        }
        }
    }
    
    // MARK: - Friend Request Badge
    
    private func refreshPendingFriendRequestCount() async {
        let count = await dataManager.getIncomingFriendRequestCount()
        await MainActor.run {
            pendingFriendRequestCount = count
        }
        print("[ProfileTabView] Pending friend request count: \(count)")
    }

    private func handleNavigationTarget(_ target: TabCoordinator.NavigationTarget?) {
        guard let target else { return }
        
        switch target {
        case .friendRequests, .friendsHub:
            print("[ProfileTabView] Deep link navigation to Friends Hub")
            showFriendsHub = true
            tabCoordinator.clearNavigationTarget()
        case .friendProfile(let userId):
            profileNavigator.openProfile(
                handle: .supabase(id: userId),
                source: .notifications,
                triggerHaptic: false
            )
            tabCoordinator.clearNavigationTarget()
        default:
            break
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        ProfileCompactHeader(
            displayName: displayName,
            username: username,
            bio: bio,
            location: location,
            favoriteDrink: favoriteDrink,
            profileImageURL: avatarURL,
            bannerImageURL: bannerURL,
            profileImageId: profileImageId,
            bannerImageId: bannerImageId
        )
    }
    
    // MARK: - Content Tabs Section
    
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
        if dataManager.isBootstrapping && userVisits.isEmpty {
            VStack(spacing: DS.Spacing.lg) {
                ForEach(0..<3) { _ in
                    DSCardSkeleton()
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        } else {
            switch selectedTab {
            case .posts:
                ProfilePostsGrid(
                    visits: userVisits,
                    onSelectVisit: { visit in
                        hapticsManager.lightTap()
                        selectedVisit = visit
                    }
                )
                .padding(.horizontal, 1) // Small padding for grid edges
            
            case .cafes:
                ProfileCafesView(dataManager: dataManager)
                    .padding(.horizontal, DS.Spacing.pagePadding)
            
            case .journal:
                ProfileJournalView(dataManager: dataManager)
                    .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    // MARK: - Developer Tools Section
    
    #if DEBUG
    private var developerToolsSection: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("🛠 Developer Tools")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                
                // Search Mode segmented control
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Search Mode")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Text(dataManager.appData.mapSearchMode.displayName)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    let modes = Array(MapSearchMode.allCases)
                    DSDesignSegmentedControl(
                        options: modes.map { $0.displayName },
                        selectedIndex: Binding(
                            get: {
                                modes.firstIndex(of: dataManager.appData.mapSearchMode) ?? 0
                            },
                            set: { newIndex in
                                guard newIndex >= 0 && newIndex < modes.count else { return }
                                let newMode = modes[newIndex]
                                if newMode != dataManager.appData.mapSearchMode {
                                    hapticsManager.selectionChanged()
                                    dataManager.setMapSearchMode(newMode)
                                }
                            }
                        )
                    )
                }
                
                Divider()
                    .background(DS.Colors.dividerSubtle)
                
                // Post Flow Style Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Post Flow Style")
                            .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        Text(dataManager.appData.useOnboardingStylePostFlow ? "Onboarding-style (new)" : "Classic (current)")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                            Spacer()
                    
                                Button(action: {
                        dataManager.togglePostFlowStyle()
                    }) {
                        Text("Toggle")
                            .font(DS.Typography.buttonLabel)
                            .foregroundColor(DS.Colors.textOnMint)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(DS.Colors.primaryAccent)
                                        .cornerRadius(DS.Radius.lg)
                    }
                }
                
                Divider()
                    .background(DS.Colors.dividerSubtle)
                
                // Sip Squad Simplified Style Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sip Squad Style")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                        Text(dataManager.appData.useSipSquadSimplifiedStyle ? "Simplified (mint pins, no legend)" : "Standard (color-coded, with legend)")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        hapticsManager.lightTap()
                        dataManager.toggleSipSquadSimplifiedStyle()
                    }) {
                        Text("Toggle")
                            .font(DS.Typography.buttonLabel)
                            .foregroundColor(DS.Colors.textOnMint)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(DS.Colors.primaryAccent)
                            .cornerRadius(DS.Radius.lg)
                    }
                }
                
                Divider()
                    .background(DS.Colors.dividerSubtle)
                
                // Force Onboarding Button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Force Onboarding")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                        Text("Reset onboarding state to trigger full flow")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        hapticsManager.mediumTap()
                        dataManager.resetOnboardingState()
                    }) {
                        Text("Reset")
                            .font(DS.Typography.buttonLabel)
                            .foregroundColor(DS.Colors.textOnMint)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(DS.Colors.primaryAccent)
                            .cornerRadius(DS.Radius.lg)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, DS.Spacing.lg)
    }
    #endif
    
    private func createShareText(username: String) -> String {
        "Check out my Mugshot profile: @\(username)"
    }
}

// MARK: - Profile Cafes View

struct ProfileCafesView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject var tabCoordinator: TabCoordinator
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    private var topCafes: [(cafe: Cafe, visitCount: Int, avgScore: Double)] {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return [] }
        
        let userVisits = dataManager.appData.visits.filter { $0.userId == currentUserId }
        let visitsByCafe = Dictionary(grouping: userVisits, by: { $0.cafeId })
        
        var cafeStats: [(cafe: Cafe, visitCount: Int, avgScore: Double)] = []
        for (cafeId, visits) in visitsByCafe {
            guard let cafe = dataManager.getCafe(id: cafeId) else { continue }
            let avgScore = visits.reduce(0.0) { $0 + $1.overallScore } / Double(visits.count)
            cafeStats.append((cafe: cafe, visitCount: visits.count, avgScore: avgScore))
        }
        
        return cafeStats.sorted {
            if $0.avgScore == $1.avgScore {
                return $0.visitCount > $1.visitCount
            }
            return $0.avgScore > $1.avgScore
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if topCafes.isEmpty {
                emptyState
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
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                UnifiedCafeView(
                    cafe: cafe,
                    dataManager: dataManager,
                    presentationMode: .fullScreen
                )
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 40))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text("No cafes yet")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
            
            Text("Visit your first cafe to start tracking")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textTertiary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                tabCoordinator.switchToMap()
            }) {
                Text("Find a Cafe")
                    .font(DS.Typography.buttonLabel)
                    .foregroundColor(DS.Colors.textOnMint)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.lg)
            }
            .padding(.top, DS.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl * 2)
    }
}

// MARK: - Cafe List Item

struct CafeListItem: View {
    let cafe: Cafe
    let visitCount: Int
    let avgScore: Double
    @ObservedObject var dataManager: DataManager
    let onTap: () -> Void
    
    private var featuredVisit: Visit? {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        return visits.sorted { $0.createdAt > $1.createdAt }.first
    }
    
    private var cafeImagePath: String? {
        featuredVisit?.posterImagePath
    }
    
    private var cafeImageRemoteURL: String? {
        guard let visit = featuredVisit,
              let key = visit.posterImagePath else { return nil }
        return visit.remoteURL(for: key)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Cafe image
                    if let imagePath = cafeImagePath {
                        PhotoThumbnailView(
                            photoPath: imagePath,
                            remoteURL: cafeImageRemoteURL,
                        size: 64
                        )
                    } else {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(DS.Colors.cardBackgroundAlt)
                        .frame(width: 64, height: 64)
                            .overlay(
                            Image(systemName: "cup.and.saucer.fill")
                                    .foregroundColor(DS.Colors.iconSubtle)
                            )
                    }
                    
                // Cafe info
                VStack(alignment: .leading, spacing: 4) {
                        Text(cafe.name)
                        .font(DS.Typography.headline())
                            .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                        
                        if !cafe.address.isEmpty {
                            Text(cafe.address)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                    HStack(spacing: DS.Spacing.sm) {
                            DSScoreBadge(score: avgScore)
                        
                        Text("•")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                        
                        Text("\(visitCount) \(visitCount == 1 ? "visit" : "visits")")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.Colors.iconSubtle)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.lg)
            .shadow(
                color: DS.Shadow.cardSoft.color,
                radius: DS.Shadow.cardSoft.radius / 2,
                x: DS.Shadow.cardSoft.x,
                y: DS.Shadow.cardSoft.y / 2
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Saved View

struct ProfileSavedView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject var tabCoordinator: TabCoordinator
    @State private var selectedSegment: SavedSegment = .favorites
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    enum SavedSegment: String, CaseIterable {
        case favorites = "Favorites"
        case wishlist = "Wishlist"
    }
    
    private var favorites: [Cafe] {
        dataManager.appData.cafes.filter { $0.isFavorite }
    }
    
    private var wishlist: [Cafe] {
        dataManager.appData.cafes.filter { $0.wantToTry }
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Segment toggle
            HStack(spacing: 0) {
                ForEach(SavedSegment.allCases, id: \.self) { segment in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSegment = segment
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: segment == .favorites ? "heart.fill" : "bookmark.fill")
                                .font(.system(size: 12))
                            Text(segment.rawValue)
                                .font(DS.Typography.subheadline(.medium))
                        }
                        .foregroundColor(selectedSegment == segment ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            selectedSegment == segment
                                ? DS.Colors.cardBackground
                                : Color.clear
                        )
                        .cornerRadius(DS.Radius.md)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(DS.Colors.cardBackgroundAlt)
            .cornerRadius(DS.Radius.lg)
            
            // Content
            if selectedSegment == .favorites {
                savedCafesList(cafes: favorites, emptyMessage: "No favorite cafes yet", emptyIcon: "heart")
            } else {
                savedCafesList(cafes: wishlist, emptyMessage: "No cafes on your wishlist", emptyIcon: "bookmark")
            }
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
    }
    
    @ViewBuilder
    private func savedCafesList(cafes: [Cafe], emptyMessage: String, emptyIcon: String) -> some View {
        if cafes.isEmpty {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: emptyIcon)
                    .font(.system(size: 40))
                    .foregroundColor(DS.Colors.iconSubtle)
                
                Text(emptyMessage)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                
                Button(action: {
                    tabCoordinator.switchToMap()
                }) {
                    Text("Find a Cafe")
                        .font(DS.Typography.buttonLabel)
                        .foregroundColor(DS.Colors.primaryAccent)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.primaryAccentSoftFill)
                        .cornerRadius(DS.Radius.lg)
                }
                .padding(.top, DS.Spacing.sm)
                }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxl * 2)
            } else {
            ForEach(cafes) { cafe in
                SavedCafeListItem(
                        cafe: cafe,
                        dataManager: dataManager,
                    onTap: {
                            selectedCafe = cafe
                            showCafeDetail = true
                        }
                    )
            }
        }
    }
}

// MARK: - Saved Cafe List Item

struct SavedCafeListItem: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let onTap: () -> Void
    
    private var visitCount: Int {
        dataManager.getVisitsForCafe(cafe.id).count
    }
    
    private var featuredVisit: Visit? {
        dataManager.getVisitsForCafe(cafe.id).first
    }
    
    private var cafeImagePath: String? {
        featuredVisit?.posterImagePath
    }
    
    private var cafeImageRemoteURL: String? {
        guard let visit = featuredVisit,
              let key = visit.posterImagePath else { return nil }
        return visit.remoteURL(for: key)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Cafe image
                if let imagePath = cafeImagePath {
                    PhotoThumbnailView(
                        photoPath: imagePath,
                        remoteURL: cafeImageRemoteURL,
                        size: 56
                    )
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(DS.Colors.cardBackgroundAlt)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundColor(DS.Colors.iconSubtle)
                        )
                }
                
                // Cafe info
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    if visitCount > 0 {
                        Text("\(visitCount) \(visitCount == 1 ? "visit" : "visits")")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    } else {
                        Text("Not visited yet")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Status indicators
                HStack(spacing: DS.Spacing.sm) {
                    if cafe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DS.Colors.redAccent)
                    }
                    
                    if cafe.wantToTry {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DS.Colors.primaryAccent)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.lg)
            .shadow(
                color: DS.Shadow.cardSoft.color,
                radius: DS.Shadow.cardSoft.radius / 2,
                x: DS.Shadow.cardSoft.x,
                y: DS.Shadow.cardSoft.y / 2
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var hapticsManager: HapticsManager
    @State private var editableUser: User
    @State private var showingProfileImagePicker = false
    @State private var showingBannerImagePicker = false
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var selectedBannerImage: PhotosPickerItem?
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    
    private var remoteAvatarURL: String? {
        dataManager.appData.currentUserAvatarURL
    }
    
    private var remoteBannerURL: String? {
        dataManager.appData.currentUserBannerURL
    }
    
    init(user: User, dataManager: DataManager) {
        self._editableUser = State(initialValue: user)
        self.dataManager = dataManager
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.sectionVerticalGap) {
                    // Banner Image Section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Banner Image")
                        
                        Button(action: { showingBannerImagePicker = true }) {
                            ZStack {
                                if let bannerID = editableUser.bannerImageID,
                                   let image = PhotoCache.shared.retrieve(forKey: bannerID) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 150)
                                        .cornerRadius(DS.Radius.lg)
                                        .clipped()
                                } else if let remoteURL = remoteBannerURL,
                                          let url = URL(string: remoteURL) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(height: 150)
                                                .cornerRadius(DS.Radius.lg)
                                                .clipped()
                                        default:
                                            bannerPlaceholder
                                        }
                                    }
                                } else {
                                    bannerPlaceholder
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Profile Image Section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Profile Picture")
                        
                        Button(action: { showingProfileImagePicker = true }) {
                            HStack(spacing: DS.Spacing.lg) {
                                profileImageView
                                
                                Text("Tap to change")
                                                            .font(DS.Typography.bodyText)
                                                            .foregroundColor(DS.Colors.textSecondary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Form Fields
                    formFieldsSection
                    
                    // Logout Button
                    Button(action: { showLogoutAlert = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                            Text("Log Out")
                                .font(DS.Typography.buttonLabel)
                        }
                        .foregroundColor(DS.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.cardBackgroundAlt)
                        .cornerRadius(DS.Radius.lg)
                    }
                    .padding(.top, DS.Spacing.lg)
                    
                    // Delete Account Button
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                            Text("Delete Account")
                                .font(DS.Typography.buttonLabel)
                        }
                        .foregroundColor(DS.Colors.negativeChange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.cardBackgroundAlt)
                        .cornerRadius(DS.Radius.lg)
                    }
                    .padding(.top, DS.Spacing.md)
                    
                    // Legal Links
                    VStack(spacing: DS.Spacing.sm) {
                        if let privacyURL = URL(string: AppConfig.privacyPolicyURLString) {
                            Link("Privacy Policy", destination: privacyURL)
                        }
                        Link(
                            "Terms of Service (EULA)",
                            destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
                        ) // Standard Apple EULA
                    }
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xl)
                }
                .padding(DS.Spacing.pagePadding)
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DS.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveProfile() }
                        .foregroundColor(DS.Colors.primaryAccent)
                }
            }
            .photosPicker(isPresented: $showingProfileImagePicker, selection: $selectedProfileImage, matching: .images)
            .photosPicker(isPresented: $showingBannerImagePicker, selection: $selectedBannerImage, matching: .images)
            .onChange(of: selectedProfileImage) { _, newValue in
                handleProfileImageSelection(newValue)
            }
            .onChange(of: selectedBannerImage) { _, newValue in
                handleBannerImageSelection(newValue)
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    dataManager.logout()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to log out? This will clear all your data.")
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        try? await dataManager.deleteAccount()
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure? This will permanently delete your account and all your data. This action cannot be undone.")
            }
        }
    }
    
    private var bannerPlaceholder: some View {
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .fill(DS.Colors.cardBackgroundAlt)
                                        .frame(height: 150)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(DS.Colors.iconDefault)
                                                Text("Add Banner")
                                                    .font(DS.Typography.bodyText)
                                                    .foregroundColor(DS.Colors.textSecondary)
                                            }
                                        )
    }
    
    @ViewBuilder
    private var profileImageView: some View {
        if let profileID = editableUser.profileImageID,
           let image = PhotoCache.shared.retrieve(forKey: profileID) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipShape(Circle())
                                    } else if let remoteURL = remoteAvatarURL,
                                              let url = URL(string: remoteURL) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                            default:
                    profilePlaceholder
                                            }
                                        }
                                    } else {
            profilePlaceholder
        }
    }
    
    private var profilePlaceholder: some View {
                                        Circle()
                                            .fill(DS.Colors.cardBackgroundAlt)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "person.crop.circle.badge.plus")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(DS.Colors.iconDefault)
                                            )
    }
    
    private var formFieldsSection: some View {
        VStack(spacing: DS.Spacing.sectionVerticalGap) {
            formField(title: "Display Name", text: Binding(
                            get: { editableUser.displayName ?? "" },
                            set: { editableUser.displayName = $0.isEmpty ? nil : $0 }
                        ))
            
            formField(title: "Username", text: $editableUser.username)
            
            formField(title: "Bio", text: $editableUser.bio, isMultiline: true)
            
            formField(title: "Favorite Drink", text: Binding(
                            get: { editableUser.favoriteDrink ?? "" },
                            set: { editableUser.favoriteDrink = $0.isEmpty ? nil : $0 }
                        ))
            
            formField(title: "Location", text: $editableUser.location)
            
            formField(title: "Instagram Handle", text: Binding(
                            get: { editableUser.instagramURL ?? "" },
                            set: { editableUser.instagramURL = $0.isEmpty ? nil : $0 }
            ), keyboardType: .twitter)
            
            formField(title: "Website URL", text: Binding(
                get: { editableUser.websiteURL ?? "" },
                set: { editableUser.websiteURL = $0.isEmpty ? nil : $0 }
            ), keyboardType: .URL)
        }
    }
    
    private func formField(
        title: String,
        text: Binding<String>,
        isMultiline: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title)
            
            if isMultiline {
                TextField("", text: text, axis: .vertical)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .tint(DS.Colors.primaryAccent)
                    .lineLimit(3...6)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
            } else {
                TextField("", text: text)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .tint(DS.Colors.primaryAccent)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .URL || keyboardType == .twitter ? .none : .words)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
            }
        }
    }
    
    private func handleProfileImageSelection(_ item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let imageID = UUID().uuidString
                PhotoCache.shared.store(uiImage, forKey: imageID)
                editableUser.profileImageID = imageID
            }
        }
    }
    
    private func handleBannerImageSelection(_ item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let imageID = UUID().uuidString
                PhotoCache.shared.store(uiImage, forKey: imageID)
                editableUser.bannerImageID = imageID
            }
        }
    }
    
    private func saveProfile() {
                        hapticsManager.mediumTap()
                        Task {
                            do {
                                var avatarImage: UIImage? = nil
                                var bannerImage: UIImage? = nil
                                if let profileId = editableUser.profileImageID {
                                    avatarImage = PhotoCache.shared.retrieve(forKey: profileId)
                                }
                                if let bannerId = editableUser.bannerImageID {
                                    bannerImage = PhotoCache.shared.retrieve(forKey: bannerId)
                                }
                                
                                try await dataManager.updateCurrentUserProfile(
                                    displayName: editableUser.displayName,
                                    username: editableUser.username,
                                    bio: editableUser.bio.isEmpty ? nil : editableUser.bio,
                                    location: editableUser.location.isEmpty ? nil : editableUser.location,
                                    favoriteDrink: editableUser.favoriteDrink,
                                    instagramHandle: editableUser.instagramURL,
                                    websiteURL: editableUser.websiteURL,
                                    avatarImage: avatarImage,
                                    bannerImage: bannerImage
                                )
                                
                                await MainActor.run {
                                    hapticsManager.playSuccess()
                                    dismiss()
                                }
                            } catch {
                print("[EditProfileView] Error updating profile: \(error.localizedDescription)")
                                hapticsManager.playError()
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
