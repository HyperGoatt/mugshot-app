//
//  Light20RootView.swift
//  testMugshot
//
//  Main container for Light 2.0 theme
//  Premium curated experience with floating cards and strategic mint accents
//

import SwiftUI

struct Light20RootView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var tabCoordinator: TabCoordinator
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var selectedTab: Int = 1 // Default to Feed
    @State private var preselectedCafeForLogVisit: Cafe?
    @State private var showLogVisitModal = false
    
    // Timer for periodic notification refresh
    @State private var notificationRefreshTimer: Timer?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Pure white background
            DS.Colors.light20Background
                .ignoresSafeArea()
            
            // Content area
            Group {
                switch selectedTab {
                case 0:
                    // Map
                    Light20MapView(dataManager: dataManager, onLogVisitRequested: { cafe in
                        preselectedCafeForLogVisit = cafe
                        switchToTab(2)
                    })
                    
                case 1:
                    // Feed
                    Light20FeedView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                    
                case 2:
                    // Log Visit (triggers modal)
                    Color.clear
                        .onAppear {
                            if selectedTab == 2 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showLogVisitModal = true
                                }
                            }
                        }
                    
                case 3:
                    // Saved
                    Light20SavedView(dataManager: dataManager)
                    
                case 4:
                    // Profile
                    Light20ProfileView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                    
                default:
                    Light20FeedView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating tab bar
            Light20TabBar(
                selectedTab: $selectedTab,
                onTabSelected: { newTab in
                    switchToTab(newTab)
                }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(tabCoordinator)
        .onAppear {
            setupPushNotificationListeners()
            startNotificationRefreshTimer()
        }
        .onDisappear {
            stopNotificationRefreshTimer()
        }
        .overlay(alignment: .top) {
            // Offline indicator
            if dataManager.isOffline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("You are offline")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(DS.Colors.light20CharcoalBlack.opacity(0.9))
                .cornerRadius(20)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .allowsHitTesting(false)
            }
        }
        .sheet(
            item: Binding(
                get: { profileNavigator.activePresentation },
                set: { if $0 == nil { profileNavigator.dismissPresentation() } }
            )
        ) { presentation in
            ProfileNavigationSheet(
                dataManager: dataManager,
                navigator: profileNavigator,
                presentation: presentation
            )
        }
        .fullScreenCover(isPresented: $showLogVisitModal) {
            Light20LogVisitView(
                dataManager: dataManager,
                preselectedCafe: preselectedCafeForLogVisit
            )
            .onDisappear {
                preselectedCafeForLogVisit = nil
                if selectedTab == 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        switchToTab(1)
                    }
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showLogVisitModal = true
                }
            }
        }
    }
    
    // MARK: - Tab Navigation
    
    private func switchToTab(_ newTab: Int) {
        guard newTab != selectedTab else { return }
        hapticsManager.selectionChanged()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            selectedTab = newTab
        }
    }
    
    // MARK: - Notification Refresh
    
    private func startNotificationRefreshTimer() {
        stopNotificationRefreshTimer()
        notificationRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                guard dataManager.appData.isUserAuthenticated && dataManager.appData.hasEmailVerified else { return }
                await dataManager.refreshNotifications()
            }
        }
    }
    
    private func stopNotificationRefreshTimer() {
        notificationRefreshTimer?.invalidate()
        notificationRefreshTimer = nil
    }
    
    // MARK: - Push Notification Listeners
    
    private func setupPushNotificationListeners() {
        NotificationCenter.default.addObserver(
            forName: .pushNotificationNavigateToVisit,
            object: nil,
            queue: .main
        ) { notification in
            if let visitId = notification.userInfo?["visitId"] as? UUID {
                tabCoordinator.navigateToVisitDetail(visitId: visitId)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .pushNotificationNavigateToProfile,
            object: nil,
            queue: .main
        ) { notification in
            if let userId = notification.userInfo?["userId"] as? String {
                tabCoordinator.navigateToFriendProfile(userId: userId)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .pushNotificationNavigateToFeed,
            object: nil,
            queue: .main
        ) { _ in
            tabCoordinator.navigateToFriendsFeed()
        }
        
        NotificationCenter.default.addObserver(
            forName: .pushNotificationNavigateToNotifications,
            object: nil,
            queue: .main
        ) { _ in
            tabCoordinator.navigateToNotifications()
        }
        
        NotificationCenter.default.addObserver(
            forName: .pushNotificationNavigateToFriendRequests,
            object: nil,
            queue: .main
        ) { _ in
            tabCoordinator.navigateToFriendRequests()
        }
    }
}


