//
//  Light20ProfileView.swift
//  testMugshot
//
//  Light 2.0 profile with parallax hero and extra-bold KPI numbers
//  Gallery-style posts grid
//

import SwiftUI

struct Light20ProfileView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var tabCoordinator: TabCoordinator
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var selectedTab: ProfileContentTab = .posts
    @State private var showEditProfile = false
    @State private var showNotifications = false
    @State private var showFriendsHub = false
    @State private var showFeedbackBoard = false
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    
    private var displayName: String? { dataManager.appData.currentUserDisplayName }
    private var username: String? { dataManager.appData.currentUserUsername }
    private var bio: String? { dataManager.appData.currentUserBio }
    private var avatarURL: String? { dataManager.appData.currentUserAvatarURL }
    private var bannerURL: String? { dataManager.appData.currentUserBannerURL }
    
    private var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        dataManager.getUserStats()
    }
    
    private var friendsCount: Int {
        dataManager.appData.friendsSupabaseUserIds.count
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
                        Light20ParallaxHero(
                            imageURL: bannerURL,
                            avatarURL: avatarURL,
                            scrollOffset: geometry.frame(in: .global).minY
                        )
                        
                        profileInfo
                            .padding(.top, DS.Spacing.lg)
                        
                        statsKPIs
                            .padding(.top, DS.Spacing.xl)
                        
                        if let bio = bio, !bio.isEmpty {
                            Text(bio)
                                .light20BodyText()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Spacing.pagePadding)
                                .padding(.top, DS.Spacing.lg)
                        }
                        
                        contentTabs
                            .padding(.top, DS.Spacing.xl)
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(DS.Colors.light20Background)
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .sheet(isPresented: $showEditProfile) {
                let user = User(
                    username: username ?? "user",
                    displayName: displayName,
                    location: dataManager.appData.currentUserLocation ?? "",
                    avatarURL: avatarURL,
                    bio: bio ?? ""
                )
                EditProfileView(user: user, dataManager: dataManager)
            }
            .sheet(isPresented: $showNotifications) {
                Light20NotificationsView(dataManager: dataManager)
            }
            .sheet(isPresented: $showFriendsHub) {
                Light20SocialHubView(dataManager: dataManager)
            }
        }
    }
    
    private var profileInfo: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                
                Button(action: { showNotifications = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                        if unreadNotificationCount > 0 {
                            Circle()
                                .fill(DS.Colors.light20MintPrimary)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(Light20IconButtonStyle())
                
                Button(action: { /* Settings */ }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(Light20IconButtonStyle())
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            Text(displayName ?? "User")
                .light20Heading()
            
            if let username = username {
                Text("@\(username)")
                    .light20Label()
            }
            
            HStack(spacing: 20) {
                Button(action: { showEditProfile = true }) {
                    Text("Edit Profile")
                }
                .buttonStyle(Light20OutlineButtonStyle())
                
                Button(action: { /* Share */ }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(DS.Colors.light20CharcoalBlack)
                }
                .buttonStyle(Light20OutlineButtonStyle())
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    private var statsKPIs: some View {
        HStack(spacing: 32) {
            StatKPI(value: "\(friendsCount)", label: "Friends") {
                showFriendsHub = true
            }
            
            Divider()
                .frame(height: 60)
                .overlay(DS.Colors.light20BorderLight)
            
            StatKPI(value: "\(stats.totalVisits)", label: "Visits", isTappable: false)
            
            Divider()
                .frame(height: 60)
                .overlay(DS.Colors.light20BorderLight)
            
            StatKPI(value: "\(stats.totalCafes)", label: "Cafes", isTappable: false)
            
            Divider()
                .frame(height: 60)
                .overlay(DS.Colors.light20BorderLight)
            
            StatKPI(value: String(format: "%.1f", stats.averageScore), label: "Avg", isTappable: false)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var contentTabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ProfileContentTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hapticsManager.lightTap()
                            selectedTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? DS.Colors.light20MintPrimary : DS.Colors.light20CharcoalBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == tab ? DS.Colors.light20MintSoftFill : Color.clear)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            Divider()
                .overlay(DS.Colors.light20Divider)
            
            tabContent
                .padding(.top, DS.Spacing.lg)
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .posts:
            Light20MasonryGrid(
                visits: userVisits,
                onVisitTap: { selectedVisit = $0 }
            )
        case .cafes:
            Light20ProfileCafesView(
                dataManager: dataManager,
                onCafeTap: { selectedCafe = $0 }
            )
        case .journal:
            Light20ProfileJournalView(
                dataManager: dataManager,
                onVisitTap: { selectedVisit = $0 }
            )
        }
    }
}

struct StatKPI: View {
    let value: String
    let label: String
    var isTappable: Bool = true
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            if isTappable {
                action?()
            }
        }) {
            VStack(spacing: 4) {
                Text(value)
                    .light20DisplayNumber()
                
                Text(label)
                    .light20Caption()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isTappable)
    }
}


