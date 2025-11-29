//
//  MainTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var dataManager: DataManager
    @StateObject private var tabCoordinator = TabCoordinator()
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var preselectedCafeForLogVisit: Cafe?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content area
            Group {
                switch tabCoordinator.selectedTab {
                case 0:
                    MapTabView(dataManager: dataManager, onLogVisitRequested: { cafe in
                        preselectedCafeForLogVisit = cafe
                        switchToTab(2)
                    })
                case 1:
                    FeedTabView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                case 2:
                    AddTabView(dataManager: dataManager, preselectedCafe: preselectedCafeForLogVisit)
                        .onAppear {
                            // Clear preselected cafe after it's been used
                            if preselectedCafeForLogVisit != nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    preselectedCafeForLogVisit = nil
                                }
                            }
                        }
                case 3:
                    SavedTabView(dataManager: dataManager)
                case 4:
                    ProfileTabView(dataManager: dataManager, tabCoordinator: tabCoordinator)
                default:
                    MapTabView(dataManager: dataManager, onLogVisitRequested: { cafe in
                        preselectedCafeForLogVisit = cafe
                        switchToTab(2)
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom animated tab bar
            MugshotTabBar(
                selectedTab: $tabCoordinator.selectedTab,
                onTabSelected: { newTab in
                    switchToTab(newTab)
                }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(tabCoordinator)
        .onAppear {
            // Hide the default tab bar
            UITabBar.appearance().isHidden = true
            
            // Set up push notification navigation listeners
            setupPushNotificationListeners()
        }
    }
    
    private func switchToTab(_ newTab: Int) {
        guard newTab != tabCoordinator.selectedTab else { return }
        
        // Haptic: confirm tab switch
        hapticsManager.selectionChanged()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            tabCoordinator.selectedTab = newTab
        }
    }
    
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

// MARK: - Custom Tab Bar

struct MugshotTabBar: View {
    @Binding var selectedTab: Int
    let onTabSelected: (Int) -> Void
    
    @Namespace private var tabAnimation
    
    private let tabs: [(icon: String, selectedIcon: String, label: String)] = [
        ("map", "map.fill", "Map"),
        ("square.grid.2x2", "square.grid.2x2.fill", "Feed"),
        ("plus.circle", "plus.circle.fill", "Add"),
        ("bookmark", "bookmark.fill", "Saved"),
        ("person", "person.fill", "Profile")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(tabs.count)
            
            ZStack(alignment: .top) {
                // Sliding indicator (behind everything)
                if selectedTab != 2 { // Don't show for Add button
                    HStack {
                        Spacer()
                            .frame(width: tabWidth * CGFloat(selectedTab) + (tabWidth - 56) / 2)
                        
                        Capsule()
                            .fill(DS.Colors.primaryAccent.opacity(0.12))
                            .frame(width: 56, height: 32)
                        
                        Spacer()
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedTab)
                }
                
                // Tab items
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        TabBarItem(
                            icon: tabs[index].icon,
                            selectedIcon: tabs[index].selectedIcon,
                            label: tabs[index].label,
                            isSelected: selectedTab == index,
                            isAddButton: index == 2
                        ) {
                            onTabSelected(index)
                        }
                    }
                }
            }
        }
        .frame(height: 70)
        .padding(.horizontal, DS.Spacing.sm)
        .background(
            TabBarBackground()
        )
    }
}

// MARK: - Tab Bar Item

struct TabBarItem: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool
    let isAddButton: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Icon
                    if isAddButton {
                        // Special styling for Add button
                        ZStack {
                            // Outer glow
                            Circle()
                                .fill(DS.Colors.primaryAccent.opacity(0.15))
                                .frame(width: 56, height: 56)
                                .scaleEffect(isSelected ? 1.0 : 0.0)
                                .opacity(isSelected ? 1.0 : 0.0)
                            
                            // Main circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DS.Colors.primaryAccent,
                                            DS.Colors.primaryAccent.opacity(0.85)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .shadow(
                                    color: DS.Colors.primaryAccent.opacity(isSelected ? 0.35 : 0.2),
                                    radius: isSelected ? 10 : 6,
                                    x: 0,
                                    y: isSelected ? 5 : 3
                                )
                            
                            // Plus icon
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(DS.Colors.textOnMint)
                                .rotationEffect(.degrees(isPressed ? 90 : 0))
                        }
                        .scaleEffect(isPressed ? 0.88 : (isSelected ? 1.08 : 1.0))
                        .offset(y: isSelected ? -8 : -4)
                    } else {
                        // Regular tab icon with smooth transitions
                        ZStack {
                            // Unselected icon (fades out)
                            Image(systemName: icon)
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(DS.Colors.textSecondary)
                                .opacity(isSelected ? 0.0 : 1.0)
                                .scaleEffect(isSelected ? 0.8 : 1.0)
                            
                            // Selected icon (fades in)
                            Image(systemName: selectedIcon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(DS.Colors.primaryAccent)
                                .opacity(isSelected ? 1.0 : 0.0)
                                .scaleEffect(isSelected ? 1.0 : 0.8)
                        }
                        .scaleEffect(isPressed ? 0.85 : 1.0)
                    }
                }
                .frame(height: 36)
                
                // Label (hidden for Add button)
                if !isAddButton {
                    Text(label)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? DS.Colors.primaryAccent : DS.Colors.textSecondary)
                        .opacity(isSelected ? 1.0 : 0.7)
                        .scaleEffect(isSelected ? 1.0 : 0.95)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(TabBarButtonStyle(isPressed: $isPressed))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isPressed)
    }
}

// MARK: - Tab Bar Button Style

struct TabBarButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Tab Bar Background

struct TabBarBackground: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top separator line with subtle gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            DS.Colors.borderSubtle.opacity(0),
                            DS.Colors.borderSubtle.opacity(0.4),
                            DS.Colors.borderSubtle.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
            
            // Main background with glass effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    DS.Colors.cardBackground.opacity(0.92)
                )
        }
        .background(DS.Colors.cardBackground)
    }
}

