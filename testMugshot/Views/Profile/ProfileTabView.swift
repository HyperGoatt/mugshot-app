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
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var selectedTab: ProfileContentTab = .posts
    @State private var showEditProfile = false
    @State private var showShareSheet = false
    @State private var showNotifications = false
    @State private var showFriendRequests = false
    @State private var showFriendsList = false
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    enum ProfileContentTab: String, CaseIterable {
        case posts = "Posts"
        case cafes = "Cafés"
        case saved = "Saved"
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
                        onFriendsTap: { showFriendsList = true }
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
                    
                    // MARK: - Developer Tools (Debug only)
                    #if DEBUG
                    developerToolsSection
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
                    CafeDetailView(cafe: cafe, dataManager: dataManager)
                }
            }
            .sheet(isPresented: $showFriendsList) {
                FriendRequestsView(dataManager: dataManager)
            }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showFriendRequests = true }) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DS.Colors.iconDefault)
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
        .sheet(isPresented: $showFriendRequests) {
            FriendRequestsView(dataManager: dataManager)
        }
        .task {
            do {
                try await dataManager.refreshProfileVisits()
            } catch {
                print("[ProfileTabView] Error refreshing profile visits: \(error.localizedDescription)")
            }
        }
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
            
        case .saved:
            ProfileSavedView(dataManager: dataManager)
                .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    // MARK: - Developer Tools Section
    
    #if DEBUG
    private var developerToolsSection: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("🛠 Developer Tools")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                
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
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, DS.Spacing.lg)
    }
    #endif
    
    private func createShareText(username: String) -> String {
        "Check out my Mugshot coffee profile: @\(username)"
    }
}

// MARK: - Profile Cafés View

struct ProfileCafesView: View {
    @ObservedObject var dataManager: DataManager
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
                CafeDetailView(cafe: cafe, dataManager: dataManager)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 40))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text("No cafés yet")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
            
            Text("Visit your first café to start tracking")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl * 2)
    }
}

// MARK: - Café List Item

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
                // Café image
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
                    
                // Café info
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
                savedCafesList(cafes: favorites, emptyMessage: "No favorite cafés yet", emptyIcon: "heart")
            } else {
                savedCafesList(cafes: wishlist, emptyMessage: "No cafés on your wishlist", emptyIcon: "bookmark")
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                CafeDetailView(cafe: cafe, dataManager: dataManager)
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

// MARK: - Saved Café List Item

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
                // Café image
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
                
                // Café info
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
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var editableUser: User
    @State private var showingProfileImagePicker = false
    @State private var showingBannerImagePicker = false
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var selectedBannerImage: PhotosPickerItem?
    @State private var showLogoutAlert = false
    
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
