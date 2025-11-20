//
//  ProfileTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfileTabView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedTab: ProfileContentTab = .recent
    @State private var showEditProfile = false
    @State private var showShareSheet = false
    @State private var showNotifications = false
    @State private var selectedVisit: Visit?
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    enum ProfileContentTab: String, CaseIterable {
        case recent = "Recent"
        case topCafes = "Top Cafes"
        case favorites = "Favorites"
        case wantToTry = "Want to Try"
    }
    
    // Read user data from AppData
    private var displayName: String? {
        dataManager.appData.currentUserDisplayName
    }
    
    private var username: String? {
        dataManager.appData.currentUserUsername
    }
    
    private var bio: String? {
        dataManager.appData.currentUserBio
    }
    
    private var location: String? {
        dataManager.appData.currentUserLocation
    }
    
    private var favoriteDrink: String? {
        dataManager.appData.currentUserFavoriteDrink
    }
    
    private var instagramHandle: String? {
        dataManager.appData.currentUserInstagramHandle
    }
    
    private var website: String? {
        dataManager.appData.currentUserWebsite
    }
    
    private var profileImageId: String? {
        dataManager.appData.currentUserProfileImageId
    }
    
    private var bannerImageId: String? {
        dataManager.appData.currentUserBannerImageId
    }
    
    private var avatarURL: String? {
        dataManager.appData.currentUserAvatarURL
    }
    
    private var bannerURL: String? {
        dataManager.appData.currentUserBannerURL
    }
    
    var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        dataManager.getUserStats()
    }
    
    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 0) {
                    ProfileHeaderBannerView(
                        displayName: displayName,
                        username: username,
                        bio: bio,
                        location: location,
                        favoriteDrink: favoriteDrink,
                        instagramHandle: instagramHandle,
                        website: website,
                        profileImageId: profileImageId,
                        bannerImageId: bannerImageId,
                        profileImageURL: avatarURL,
                        bannerImageURL: bannerURL,
                        onNotifications: { showNotifications = true },
                        onShare: { showShareSheet = true },
                        onSettings: { showEditProfile = true }
                    )
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text("Coffee Journey")
                                .font(DS.Typography.sectionTitle)
                                .foregroundColor(DS.Colors.textPrimary)
                            
                            CoffeeJourneyStatsSection(dataManager: dataManager)
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        if let mostVisited = dataManager.getMostVisitedCafe() {
                            MostVisitedCard(cafe: mostVisited.cafe, visitCount: mostVisited.visitCount)
                                .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                        
                        if let favorite = dataManager.getFavoriteCafe() {
                            FavoriteCafeCard(cafe: favorite.cafe, avgScore: favorite.avgScore)
                                .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                        
                        BeverageBreakdownCard(beverageData: dataManager.getBeverageBreakdown())
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    
                        DSDesignSegmentedControl(
                            options: ProfileContentTab.allCases.map { $0.rawValue },
                            selectedIndex: Binding(
                                get: { ProfileContentTab.allCases.firstIndex(of: selectedTab) ?? 0 },
                                set: { selectedTab = ProfileContentTab.allCases[$0] }
                            )
                        )
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.md)
                        
                        contentView { visit in
                            selectedVisit = visit
                        }
                            .padding(.horizontal, DS.Spacing.pagePadding)
                }
                .padding(.top, DS.Spacing.sectionVerticalGap)
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .background(DS.Colors.screenBackground)
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
        .sheet(isPresented: $showEditProfile) {
            // Create a User object from AppData for EditProfileView compatibility
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
                                .background(
                                    Circle()
                                        .fill(DS.Colors.primaryAccent)
                                )
                                .offset(x: 8, y: -8)
                        }
                    }
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
        }
        }
    }
    
    @ViewBuilder
    private func contentView(onSelectVisit: @escaping (Visit) -> Void) -> some View {
        switch selectedTab {
        case .recent:
            RecentVisitsView(dataManager: dataManager, onSelectVisit: onSelectVisit)
        case .topCafes:
            TopCafesView(dataManager: dataManager)
        case .favorites:
            FavoritesView(dataManager: dataManager)
        case .wantToTry:
            WantToTryView(dataManager: dataManager)
        }
    }
    
    private func createShareText(username: String) -> String {
        "Check out my Mugshot coffee profile: @\(username)"
    }
}

// MARK: - Profile Header Banner View

struct ProfileHeaderBannerView: View {
    let displayName: String?
    let username: String?
    let bio: String?
    let location: String?
    let favoriteDrink: String?
    let instagramHandle: String?
    let website: String?
    let profileImageId: String?
    let bannerImageId: String?
    let profileImageURL: String?
    let bannerImageURL: String?
    let onNotifications: () -> Void
    let onShare: () -> Void
    let onSettings: () -> Void
    
    private let avatarSize: CGFloat = 180 // 4x larger (96 * 1.875 ≈ 180, roughly 2x linear = 4x area)
    
    private var displayNameOrUsername: String {
        displayName ?? username ?? "User"
    }
    
    private var usernameText: String {
        username ?? "user"
    }
    
    private var instagramURL: String? {
        guard let handle = instagramHandle, !handle.isEmpty else { return nil }
        return "https://instagram.com/\(handle)"
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
                            case .failure:
                                LinearGradient(
                                    colors: [DS.Colors.mintLight, DS.Colors.mintSoftFill],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            case .empty:
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
                    } else if let bannerID = bannerImageId {
                        BannerImageView(imageID: bannerID)
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
                
                // Top action icons, aligned to the right within safe area
                HStack(spacing: DS.Spacing.lg) {
                    Button(action: onNotifications) {
                        Image(systemName: "bell")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.iconDefault)
                            .frame(width: 44, height: 44)
                    }
                    
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.iconDefault)
                            .frame(width: 44, height: 44)
                    }
                    
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.iconDefault)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.trailing, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.lg)
            }
            
            // Profile card that sits below the banner
            ZStack(alignment: .top) {
                DSBaseCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        // Space for overlapping avatar
                        Spacer()
                            .frame(height: avatarSize / 2 + DS.Spacing.sm)
                        
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
                        
                        // Social icons row
                        HStack(spacing: DS.Spacing.lg) {
                            if let instagramURL = instagramURL {
                                Button(action: {
                                    if let url = URL(string: instagramURL) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 18))
                                        .foregroundColor(DS.Colors.iconDefault)
                                }
                            }
                            
                            if let websiteURL = website, !websiteURL.isEmpty {
                                Button(action: {
                                    if let url = URL(string: websiteURL) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 18))
                                        .foregroundColor(DS.Colors.iconDefault)
                                }
                            }
                        }
                        .padding(.top, DS.Spacing.sm)
                    }
                }
                
                            // Centered avatar overlapping banner and card
                            ProfileAvatarView(
                                profileImageId: profileImageId,
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

struct BannerImageView: View {
    let imageID: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [DS.Colors.mintLight, DS.Colors.mintSoftFill],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .onAppear {
            if let cachedImage = PhotoCache.shared.retrieve(forKey: imageID) {
                image = cachedImage
            }
        }
        .onChange(of: imageID) { _, _ in
            if let cachedImage = PhotoCache.shared.retrieve(forKey: imageID) {
                image = cachedImage
            } else {
                image = nil
            }
        }
    }
}

struct ProfileAvatarView: View {
    let profileImageId: String?
    let profileImageURL: String?
    let username: String
    var size: CGFloat = 80
    @State private var image: UIImage?
    
    var body: some View {
        Circle()
            .fill(DS.Colors.cardBackground)
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if let profileImageURL,
                       let url = URL(string: profileImageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: size, height: size)
                                    .clipShape(Circle())
                            case .failure:
                                localImageContent()
                            case .empty:
                                localImageContent()
                            @unknown default:
                                localImageContent()
                            }
                        }
                    } else {
                        localImageContent()
                    }
                }
            )
            .overlay(
                Circle()
                    .stroke(DS.Colors.cardBackground, lineWidth: 3)
            )
            .shadow(color: DS.Shadow.cardSoft.color, radius: DS.Shadow.cardSoft.radius, x: DS.Shadow.cardSoft.x, y: DS.Shadow.cardSoft.y)
            .onAppear {
                loadLocalImage()
            }
            .onChange(of: profileImageId) { _, _ in
                loadLocalImage()
            }
    }
    
    @ViewBuilder
    private func localImageContent() -> some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(username.prefix(1).uppercased())
                .font(DS.Typography.title2(.bold))
                .foregroundColor(DS.Colors.textPrimary)
        }
    }
    
    private func loadLocalImage() {
        if let imageID = profileImageId,
           let cachedImage = PhotoCache.shared.retrieve(forKey: imageID) {
            image = cachedImage
        } else {
            image = nil
        }
    }
}

// MARK: - Coffee Journey Stats Section

struct CoffeeJourneyStatsSection: View {
    @ObservedObject var dataManager: DataManager
    
    var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        dataManager.getUserStats()
    }
    
    var body: some View {
        LazyVGrid(
            columns: [
            GridItem(.flexible(), spacing: DS.Spacing.cardVerticalGap),
            GridItem(.flexible(), spacing: DS.Spacing.cardVerticalGap)
            ],
            spacing: DS.Spacing.cardVerticalGap
        ) {
            StatsCardView(
                title: "Total Visits",
                value: "\(stats.totalVisits)",
                icon: nil,
                accentColor: nil
            )
            
            StatsCardView(
                title: "Cafes Visited",
                value: "\(stats.totalCafes)",
                icon: nil,
                accentColor: nil
            )
            
            StatsCardView(
                title: "Avg Rating",
                value: stats.averageScore > 0 ? String(format: "%.1f", stats.averageScore) : "—",
                icon: "star.fill",
                accentColor: DS.Colors.secondaryAccent
            )
            
            StatsCardView(
                title: "Favorite Drink",
                value: stats.favoriteDrinkType?.rawValue ?? "—",
                icon: nil,
                accentColor: DS.Colors.primaryAccent
            )
        }
    }
}

struct StatsCardView: View {
    let title: String
    let value: String
    let icon: String?
    let accentColor: Color?
    
    var body: some View {
        DSBaseCard {
            VStack(spacing: DS.Spacing.sm) {
                if let icon = icon {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundColor(accentColor ?? DS.Colors.textPrimary)
                        Text(value)
                            .font(DS.Typography.numericStat)
                            .foregroundColor(DS.Colors.textPrimary)
                    }
                } else {
                    Text(value)
                        .font(DS.Typography.numericStat)
                        .foregroundColor(DS.Colors.textPrimary)
                }
                
                Text(title)
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
        }
    }
}

// MARK: - Info Cards

struct MostVisitedCard: View {
    let cafe: Cafe
    let visitCount: Int
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Most Visited")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                
                HStack {
                    Text(cafe.name)
                        .font(DS.Typography.callout())
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Spacer()
                    
                    // Blue pill badge
                    HStack(spacing: 4) {
                        Text("\(visitCount) visits")
                            .font(DS.Typography.metaLabel)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DS.Colors.secondaryAccent)
                    .cornerRadius(DS.Radius.pill)
                }
            }
        }
    }
}

struct FavoriteCafeCard: View {
    let cafe: Cafe
    let avgScore: Double
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Favorite Cafe")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
                
                HStack {
                    Text(cafe.name)
                        .font(DS.Typography.callout())
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Spacer()
                    
                    // Score badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                        Text(String(format: "%.1f", avgScore))
                            .font(DS.Typography.metaLabel)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DS.Colors.secondaryAccent)
                    .cornerRadius(DS.Radius.pill)
                }
            }
        }
    }
}

struct BeverageBreakdownCard: View {
    let beverageData: [(drinkType: DrinkType, count: Int, fraction: Double)]
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Beverage Breakdown")
                    .font(DS.Typography.callout())
                    .foregroundColor(DS.Colors.textPrimary)
                
                if let primary = beverageData.first {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text(primary.drinkType.rawValue)
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textPrimary)
                            Spacer()
                            Text("\(primary.count)")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textPrimary)
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DS.Colors.mintSoftFill)
                                    .frame(height: 6)
                                
                                // Fill
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DS.Colors.primaryAccent)
                                    .frame(width: geometry.size.width * CGFloat(primary.fraction), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                } else {
                    Text("No visits yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Content Views

struct RecentVisitsView: View {
    @ObservedObject var dataManager: DataManager
    let onSelectVisit: (Visit) -> Void
    
    var visits: [Visit] {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return [] }
        return dataManager.appData.visits
            .filter { $0.userId == currentUserId }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(20)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if visits.isEmpty {
                DSBaseCard {
                    Text("No visits yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                // Horizontal media strip of recent photos
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.lg) {
                        ForEach(visits.prefix(10)) { visit in
                            if let posterPath = visit.posterImagePath {
                                Button(action: {
                                    onSelectVisit(visit)
                                }) {
                                    PhotoImageView(
                                        photoPath: posterPath,
                                        remoteURL: visit.remoteURL(for: posterPath)
                                    )
                                        .frame(width: 120, height: 120)
                                        .cornerRadius(DS.Radius.lg)
                                        .clipped()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(height: 120)
                
                // Full visit cards
                ForEach(visits) { visit in
                    if dataManager.getCafe(id: visit.cafeId) != nil {
                        VisitCard(visit: visit, dataManager: dataManager, selectedScope: .friends)
                            .onTapGesture {
                                onSelectVisit(visit)
                            }
                    }
                }
            }
        }
    }
}

struct TopCafesView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    var topCafes: [(cafe: Cafe, visitCount: Int, avgScore: Double)] {
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
                DSBaseCard {
                    Text("No cafés yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                ForEach(topCafes, id: \.cafe.id) { item in
                    TopCafeCard(
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
}

struct TopCafeCard: View {
    let cafe: Cafe
    let visitCount: Int
    let avgScore: Double
    @ObservedObject var dataManager: DataManager
    let onTap: () -> Void
    
    private var featuredVisit: Visit? {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        return visits.sorted { $0.createdAt > $1.createdAt }.first
    }
    
    var cafeImagePath: String? {
        featuredVisit?.posterImagePath
    }
    
    var cafeImageRemoteURL: String? {
        guard let visit = featuredVisit,
              let key = visit.posterImagePath else { return nil }
        return visit.remoteURL(for: key)
    }
    
    var body: some View {
        Button(action: onTap) {
            DSBaseCard {
                HStack(spacing: DS.Spacing.lg) {
                    if let imagePath = cafeImagePath {
                        PhotoThumbnailView(
                            photoPath: imagePath,
                            remoteURL: cafeImageRemoteURL,
                            size: 80
                        )
                    } else {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(DS.Colors.cardBackgroundAlt)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(DS.Colors.iconSubtle)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(cafe.name)
                            .font(DS.Typography.cardTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(2)
                        
                        if !cafe.address.isEmpty {
                            Text(cafe.address)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: DS.Spacing.md) {
                            DSScoreBadge(score: avgScore)
                            Text("• \(visitCount) visits")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct FavoritesView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    var favorites: [Cafe] {
        dataManager.appData.cafes.filter { $0.isFavorite }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if favorites.isEmpty {
                DSBaseCard {
                    Text("No favorites yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                ForEach(favorites) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        mode: .favorites,
                        onLogVisit: {},
                        onShowDetails: {
                            selectedCafe = cafe
                            showCafeDetail = true
                        }
                    )
                    .onTapGesture {
                        selectedCafe = cafe
                        showCafeDetail = true
                    }
                }
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                CafeDetailView(cafe: cafe, dataManager: dataManager)
            }
        }
    }
}

struct WantToTryView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    var wantToTry: [Cafe] {
        dataManager.appData.cafes.filter { $0.wantToTry }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if wantToTry.isEmpty {
                DSBaseCard {
                    Text("No cafés on your wishlist yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                ForEach(wantToTry) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        mode: .wantToTry,
                        onLogVisit: {},
                        onShowDetails: {
                            selectedCafe = cafe
                            showCafeDetail = true
                        }
                    )
                    .onTapGesture {
                        selectedCafe = cafe
                        showCafeDetail = true
                    }
                }
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                CafeDetailView(cafe: cafe, dataManager: dataManager)
            }
        }
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataManager: DataManager
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
                                if let bannerID = editableUser.bannerImageID {
                                    BannerImageView(imageID: bannerID)
                                        .frame(height: 150)
                                        .cornerRadius(DS.Radius.lg)
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
                                        default:
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
                                    }
                                } else {
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
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Profile Image Section
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Profile Picture")
                        
                        Button(action: { showingProfileImagePicker = true }) {
                            HStack(spacing: DS.Spacing.lg) {
                                ZStack {
                                    if let profileID = editableUser.effectiveProfileImageID {
                                        if let image = PhotoCache.shared.retrieve(forKey: profileID) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipShape(Circle())
                                        }
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
                                                Circle()
                                                    .fill(DS.Colors.cardBackgroundAlt)
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Image(systemName: "person.crop.circle.badge.plus")
                                                            .font(.system(size: 32))
                                                            .foregroundColor(DS.Colors.iconDefault)
                                                    )
                                            }
                                        }
                                    } else {
                                        Circle()
                                            .fill(DS.Colors.cardBackgroundAlt)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "person.crop.circle.badge.plus")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(DS.Colors.iconDefault)
                                            )
                                    }
                                }
                                
                                Text("Tap to change")
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textSecondary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Display Name
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Display Name")
                        TextField("Display Name", text: Binding(
                            get: { editableUser.displayName ?? "" },
                            set: { editableUser.displayName = $0.isEmpty ? nil : $0 }
                        ))
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .tint(DS.Colors.primaryAccent)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    
                    // Username
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Username")
                        TextField("Username", text: $editableUser.username)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                            .padding(DS.Spacing.md)
                            .background(DS.Colors.cardBackground)
                            .cornerRadius(DS.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                            )
                    }
                    
                    // Bio
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Bio")
                        TextField("Tell us about yourself", text: $editableUser.bio, axis: .vertical)
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
                    }
                    
                    // Favorite Drink
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Favorite Drink")
                        TextField("Favorite Drink", text: Binding(
                            get: { editableUser.favoriteDrink ?? "" },
                            set: { editableUser.favoriteDrink = $0.isEmpty ? nil : $0 }
                        ))
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .tint(DS.Colors.primaryAccent)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Location")
                        TextField("Location", text: $editableUser.location)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                            .padding(DS.Spacing.md)
                            .background(DS.Colors.cardBackground)
                            .cornerRadius(DS.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                            )
                    }
                    
                    // Instagram URL
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Instagram URL")
                        TextField("https://instagram.com/username", text: Binding(
                            get: { editableUser.instagramURL ?? "" },
                            set: { editableUser.instagramURL = $0.isEmpty ? nil : $0 }
                        ))
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .tint(DS.Colors.primaryAccent)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    
                    // Website URL
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader("Website URL")
                        TextField("https://yourwebsite.com", text: Binding(
                            get: { editableUser.websiteURL ?? "" },
                            set: { editableUser.websiteURL = $0.isEmpty ? nil : $0 }
                        ))
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .tint(DS.Colors.primaryAccent)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    
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
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            do {
                                // Get images if changed
                                var avatarImage: UIImage? = nil
                                var bannerImage: UIImage? = nil
                                if let profileId = editableUser.profileImageID {
                                    avatarImage = PhotoCache.shared.retrieve(forKey: profileId)
                                }
                                if let bannerId = editableUser.bannerImageID {
                                    bannerImage = PhotoCache.shared.retrieve(forKey: bannerId)
                                }
                                
                                // Update profile in Supabase by userId (identity-safe)
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
                                    dismiss()
                                }
                            } catch {
                                print("[ProfileTabView] Error updating profile: \(error.localizedDescription)")
                                // TODO: Show error alert to user
                            }
                        }
                    }
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
            .photosPicker(isPresented: $showingProfileImagePicker, selection: $selectedProfileImage, matching: .images)
            .photosPicker(isPresented: $showingBannerImagePicker, selection: $selectedBannerImage, matching: .images)
            .onChange(of: selectedProfileImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        let imageID = UUID().uuidString
                        PhotoCache.shared.store(uiImage, forKey: imageID)
                        editableUser.profileImageID = imageID
                    }
                }
            }
            .onChange(of: selectedBannerImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        let imageID = UUID().uuidString
                        PhotoCache.shared.store(uiImage, forKey: imageID)
                        editableUser.bannerImageID = imageID
                    }
                }
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
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
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

