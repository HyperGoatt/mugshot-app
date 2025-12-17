//
//  ModernProfileView.swift
//  testMugshot
//
//  Modern profile view (supports both Light and Dark themes)
//  Features: Cover photo with parallax, centered avatar, stats block, content tabs
//

import SwiftUI

enum ProfileContentTab: String, CaseIterable {
    case posts = "Posts"
    case cafes = "Cafes"
    case journal = "Journal"
}

struct ModernProfileView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var tabCoordinator: TabCoordinator
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var selectedTab: ProfileContentTab = .posts
    @State private var showEditProfile = false
    @State private var showNotifications = false
    @State private var showFriendsHub = false
    @State private var showFeedbackBoard = false
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    @State private var pendingFriendRequestCount: Int = 0
    
    // User data
    private var displayName: String? { dataManager.appData.currentUserDisplayName }
    private var username: String? { dataManager.appData.currentUserUsername }
    private var bio: String? { dataManager.appData.currentUserBio }
    private var location: String? { dataManager.appData.currentUserLocation }
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
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Immersive header with parallax
                        modernHeader(scrollOffset: geometry.frame(in: .global).minY)
                        
                        // Stats row
                        statsRow
                            .padding(.top, DS.Spacing.lg)
                        
                        // Bio section
                        if let bio = bio, !bio.isEmpty {
                            modernBioSection(bio)
                                .padding(.top, DS.Spacing.lg)
                        }
                        
                        // Coffee stats card
                        modernStatsCard
                            .padding(.top, DS.Spacing.lg)
                        
                        // Content tabs
                        contentTabsSection
                            .padding(.top, DS.Spacing.xl)
                    }
                    .padding(.bottom, 100) // Space for floating tab bar
                }
            }
            .background(DS.Colors.dynamicBackground)
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .sheet(isPresented: $showEditProfile) {
                let user = User(
                    username: username ?? "user",
                    displayName: displayName,
                    location: location ?? "",
                    profileImageID: dataManager.appData.currentUserProfileImageId,
                    bannerImageID: dataManager.appData.currentUserBannerImageId,
                    bio: bio ?? "",
                    instagramURL: dataManager.appData.currentUserInstagramHandle,
                    websiteURL: dataManager.appData.currentUserWebsite,
                    favoriteDrink: dataManager.appData.currentUserFavoriteDrink
                )
                EditProfileView(user: user, dataManager: dataManager)
            }
            .sheet(isPresented: $showNotifications) {
                ModernNotificationsView(dataManager: dataManager)
            }
            .sheet(isPresented: $showFriendsHub) {
                ModernSocialHubView(dataManager: dataManager)
            }
            .sheet(isPresented: $showFeedbackBoard) {
                FeedbackBoardView(dataManager: dataManager)
            }
            .sheet(item: $selectedCafe) { cafe in
                ModernCafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: nil
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Friends button
                    Button(action: { showFriendsHub = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DS.Colors.dynamicTextPrimary)
                            
                            if pendingFriendRequestCount > 0 {
                                Circle()
                                    .fill(DS.Colors.dynamicPrimaryAccent)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    
                    // Notifications button
                    Button(action: { showNotifications = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 20))
                                .foregroundColor(DS.Colors.dynamicTextPrimary)
                            
                            if unreadNotificationCount > 0 {
                                Circle()
                                    .fill(DS.Colors.dynamicPrimaryAccent)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    
                    // Feedback button
                    Button(action: { showFeedbackBoard = true }) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.dynamicTextPrimary)
                    }
                    
                    // Settings button
                    Button(action: { showEditProfile = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.dynamicTextPrimary)
                    }
                }
            }
            .task {
                do {
                    try await dataManager.refreshProfileVisits()
                } catch {
                    print("[ModernProfileView] Error refreshing profile visits: \(error.localizedDescription)")
                }
                await dataManager.refreshFriendsList()
                await refreshPendingFriendRequestCount()
            }
            .onChange(of: showFriendsHub) { _, isShowing in
                if !isShowing {
                    Task {
                        await refreshPendingFriendRequestCount()
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private func modernHeader(scrollOffset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // Cover photo with parallax effect
            Group {
                if let bannerURL = bannerURL, let url = URL(string: bannerURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            coverPlaceholder
                        }
                    }
                } else {
                    coverPlaceholder
                }
            }
            .frame(height: 200 + max(0, scrollOffset))
            .clipped()
            .offset(y: scrollOffset > 0 ? -scrollOffset * 0.5 : 0) // Parallax effect
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        DS.Colors.dynamicBackground.opacity(0.8),
                        DS.Colors.dynamicBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Avatar overlapping cover (Modern Dark only)
            VStack(spacing: DS.Spacing.sm) {
                let avatarSize: CGFloat = 100
                let strokeWidth: CGFloat = 3
                
                if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: avatarSize, height: avatarSize)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            DS.Colors.dynamicPrimaryAccent,
                                            lineWidth: strokeWidth
                                        )
                                )
                        default:
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
                
                // Name
                Text(displayName ?? username ?? "User")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                
                // Username
                if let username = username {
                    Text("@\(username)")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                }
            }
            .offset(y: 60)
        }
        .frame(height: 260)
    }
    
    private var coverPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        DS.Colors.dynamicCardBackgroundAlt,
                        DS.Colors.dynamicBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    private var avatarPlaceholder: some View {
        let avatarSize: CGFloat = 100
        let strokeWidth: CGFloat = 3
        
        return Circle()
            .fill(DS.Colors.dynamicCardBackgroundAlt)
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
            )
            .overlay(
                Circle()
                    .stroke(
                        DS.Colors.dynamicPrimaryAccent,
                        lineWidth: strokeWidth
                    )
            )
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: DS.Spacing.xl) {
            statItem(value: stats.totalVisits, label: "VISITS")
            statItem(value: stats.totalCafes, label: "CAFES")
            statItem(value: friendsCount, label: "FRIENDS")
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(DS.Colors.dynamicTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Bio Section
    
    private func modernBioSection(_ bio: String) -> some View {
        Text(bio)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(DS.Colors.dynamicTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Stats Card
    
    private var modernStatsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("COFFEE JOURNEY")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            HStack(spacing: DS.Spacing.lg) {
                // Average rating
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f", stats.averageScore))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                    Text("Avg Rating")
                        .font(.system(size: 13))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                }
                
                Spacer()
                
                // Top cafe (if available)
                if let topCafe = topCafe {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(topCafe.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DS.Colors.dynamicTextPrimary)
                            .lineLimit(1)
                        Text("Top Spot")
                            .font(.system(size: 13))
                            .foregroundColor(DS.Colors.dynamicTextSecondary)
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .themeAwareFloatingCard(cornerRadius: 20)
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Content Tabs
    
    private var contentTabsSection: some View {
        VStack(spacing: 0) {
            // Modern segmented control
            modernSegmentedControl
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.bottom, DS.Spacing.lg)
            
            // Tab content
            contentView
        }
    }
    
    private var modernSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(ProfileContentTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hapticsManager.lightTap()
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? DS.Colors.dynamicTextPrimary : DS.Colors.dynamicTextSecondary)
                        
                        // Mint indicator
                        Rectangle()
                            .fill(selectedTab == tab ? DS.Colors.dynamicPrimaryAccent : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if dataManager.isBootstrapping && userVisits.isEmpty {
            VStack(spacing: DS.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(DS.Colors.dynamicCardBackgroundAlt)
                        .frame(height: 120)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        } else {
            switch selectedTab {
            case .posts:
                modernPostsGrid
            case .cafes:
                ModernProfileCafesView(dataManager: dataManager)
                    .padding(.horizontal, DS.Spacing.pagePadding)
            case .journal:
                ModernProfileJournalView(dataManager: dataManager)
                    .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    private var modernPostsGrid: some View {
        let gridSpacing: CGFloat = 2
        let imageCornerRadius: CGFloat = 0
        
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: gridSpacing
        ) {
            ForEach(userVisits) { visit in
                Button(action: {
                    hapticsManager.lightTap()
                    selectedVisit = visit
                }) {
                    if let posterURL = visit.posterImagePath,
                       let url = URL(string: visit.remoteURL(for: posterURL) ?? "") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(DS.Colors.dynamicCardBackgroundAlt)
                                    .aspectRatio(1, contentMode: .fill)
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(DS.Colors.dynamicCardBackgroundAlt)
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
                .cornerRadius(imageCornerRadius)
                .clipped()
            }
        }
        .padding(.horizontal, 1)
    }
    
    // MARK: - Helpers
    
    private func refreshPendingFriendRequestCount() async {
        let count = await dataManager.getIncomingFriendRequestCount()
        await MainActor.run {
            pendingFriendRequestCount = count
        }
    }
}
