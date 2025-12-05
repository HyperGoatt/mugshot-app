//
//  TabCoordinator.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/15/25.
//

import SwiftUI

class TabCoordinator: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var navigationTarget: NavigationTarget?
    
    enum NavigationTarget: Equatable {
        case visitDetail(UUID)
        case friendProfile(String)
        case friendsFeed
        case notifications
        case friendRequests
        case friendsHub
    }
    
    /// Switches to a tab with optional haptic feedback
    private func switchTab(to tab: Int, withHaptic: Bool = true) {
        guard tab != selectedTab else { return }
        if withHaptic {
            HapticsManager.shared.selectionChanged()
        }
        selectedTab = tab
    }
    
    func switchToFeed() {
        switchTab(to: 1)
    }
    
    func switchToMap() {
        print("[Saved] CTA tapped → Explore the map (navigating to Map)")
        switchTab(to: 0)
    }
    
    func switchToProfile() {
        print("[Saved] CTA tapped → View your visits (navigating to Profile)")
        switchTab(to: 4)
    }
    
    func navigateToVisitDetail(visitId: UUID) {
        switchTab(to: 1) // Switch to Feed tab
        navigationTarget = .visitDetail(visitId)
    }
    
    func navigateToFriendProfile(userId: String) {
        switchTab(to: 4) // Switch to Profile tab
        navigationTarget = .friendProfile(userId)
    }
    
    func navigateToFriendsFeed() {
        switchTab(to: 1) // Switch to Feed tab
        navigationTarget = .friendsFeed
    }
    
    func navigateToNotifications() {
        switchTab(to: 1) // Switch to Feed tab (notifications are shown there)
        navigationTarget = .notifications
    }
    
    func navigateToFriendRequests() {
        print("[TabCoordinator] Navigating to Friend Requests")
        switchTab(to: 4) // Switch to Profile tab
        navigationTarget = .friendRequests
    }
    
    func navigateToFriendsHub() {
        print("[TabCoordinator] Navigating to Friends Hub")
        switchTab(to: 4) // Switch to Profile tab
        navigationTarget = .friendsHub
    }
    
    func clearNavigationTarget() {
        navigationTarget = nil
    }
}

