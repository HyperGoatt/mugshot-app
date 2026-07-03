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
    @State private var preselectedCafeForLogVisit: Cafe?
    
    var body: some View {
        TabView(selection: $tabCoordinator.selectedTab) {
            MapTabView(dataManager: dataManager, onLogVisitRequested: { cafe in
                preselectedCafeForLogVisit = cafe
                tabCoordinator.selectedTab = 2 // Switch to Add tab
            })
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(0)
            
            FeedTabView(dataManager: dataManager)
                .tabItem {
                    Label("Feed", systemImage: "square.grid.2x2")
                }
                .tag(1)
            
            AddTabView(dataManager: dataManager, preselectedCafe: preselectedCafeForLogVisit)
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(2)
                .onAppear {
                    // Clear preselected cafe after it's been used
                    if preselectedCafeForLogVisit != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            preselectedCafeForLogVisit = nil
                        }
                    }
                }
            
            SavedTabView(dataManager: dataManager)
                .tabItem {
                    Label("Saved", systemImage: "bookmark.fill")
                }
                .tag(3)
            
            ProfileTabView(dataManager: dataManager)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .environmentObject(tabCoordinator)
        .accentColor(.mugshotForest)
        .onAppear {
            // Warm cream tab bar with forest selection, per the design system.
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.creamWhite)
            appearance.shadowColor = UIColor(Color.sandBeige)

            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.selected.iconColor = UIColor(Color.mugshotForest)
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.mugshotForest),
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
            ]
            itemAppearance.normal.iconColor = UIColor(Color.espressoBrown.opacity(0.55))
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color.espressoBrown.opacity(0.55)),
                .font: UIFont.systemFont(ofSize: 11, weight: .medium)
            ]
            appearance.stackedLayoutAppearance = itemAppearance
            appearance.inlineLayoutAppearance = itemAppearance
            appearance.compactInlineLayoutAppearance = itemAppearance

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

