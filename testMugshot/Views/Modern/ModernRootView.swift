//
//  ModernRootView.swift
//  testMugshot
//
//  Main container for Modern themes (Light and Dark)
//  Manages tab navigation and renders modern UI components
//

import SwiftUI

struct ModernRootView: View {
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
            // Dynamic background (adapts to theme)
            DS.Colors.dynamicBackground
                .ignoresSafeArea()
            
            // Content area
            Group {
                switch selectedTab {
                case 0:
                    // Modern Map
                    ModernMapView(dataManager: dataManager, onLogVisitRequested: { cafe in
                        preselectedCafeForLogVisit = cafe
                        switchToTab(2)
                    })
                    
                case 1:
                    // Modern Feed
                    ModernFeedView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                    
                case 2:
                    // Modern Log Visit
                    // Show transparent placeholder that triggers modal
                    Color.clear
                        .onAppear {
                            // Trigger the log visit modal when this tab is selected
                            if selectedTab == 2 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showLogVisitModal = true
                                }
                            }
                        }
                    
                case 3:
                    // Modern Saved
                    ModernSavedView(dataManager: dataManager)
                    
                case 4:
                    // Modern Profile
                    ModernProfileView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                    
                default:
                    ModernFeedView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Modern floating tab bar
            ModernTabBar(
                selectedTab: $selectedTab,
                onTabSelected: { newTab in
                    switchToTab(newTab)
                }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(tabCoordinator)
        .onAppear {
            // Set up push notification navigation listeners
            setupPushNotificationListeners()
            
            // Start periodic notification refresh (every 60 seconds)
            startNotificationRefreshTimer()
        }
        .onDisappear {
            // Clean up timer
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
                .background(DS.Colors.dynamicCardBackgroundAlt.opacity(0.9))
                .cornerRadius(20)
                .padding(.top, 60) // Below dynamic island/notch
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
            ModernLogVisitView(
                dataManager: dataManager,
                preselectedCafe: preselectedCafeForLogVisit
            )
            .onDisappear {
                // Clear preselected cafe and navigate back to previous tab
                preselectedCafeForLogVisit = nil
                if selectedTab == 2 {
                    // Navigate back to Feed after logging visit
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        switchToTab(1)
                    }
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Trigger log visit modal when Add tab is selected
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
        
        // Haptic: confirm tab switch
        hapticsManager.selectionChanged()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            selectedTab = newTab
        }
    }
    
    // MARK: - Notification Refresh
    
    private func startNotificationRefreshTimer() {
        // Invalidate any existing timer
        stopNotificationRefreshTimer()
        
        // Create a new timer that fires every 60 seconds
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
        // Listen for push notification navigation events
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
