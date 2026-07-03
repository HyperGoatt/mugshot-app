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
        VStack(spacing: 0) {
            activeTab
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.creamWhite)
                .transition(.opacity)

            MugshotBottomNav(selectedTab: $tabCoordinator.selectedTab)
        }
        .environmentObject(tabCoordinator)
        .tint(.mugshotSage)
        .background(Color.creamWhite.ignoresSafeArea())
        .onAppear {
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.mugshotSage)
        }
    }

    @ViewBuilder
    private var activeTab: some View {
        switch tabCoordinator.selectedTab {
        case 0:
            MapTabView(dataManager: dataManager, onLogVisitRequested: { cafe in
                preselectedCafeForLogVisit = cafe
                withAnimation(DesignSystem.Motion.base) {
                    tabCoordinator.selectedTab = 2
                }
            })
        case 1:
            FeedTabView(dataManager: dataManager)
        case 2:
            AddTabView(dataManager: dataManager, preselectedCafe: preselectedCafeForLogVisit)
                .onAppear {
                    if preselectedCafeForLogVisit != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            preselectedCafeForLogVisit = nil
                        }
                    }
                }
        case 3:
            SavedTabView(dataManager: dataManager)
        default:
            ProfileTabView(dataManager: dataManager)
        }
    }
}

private struct MugshotBottomNav: View {
    @Binding var selectedTab: Int

    private let items: [MugshotTabItem] = [
        MugshotTabItem(index: 0, title: "Map", icon: "map"),
        MugshotTabItem(index: 1, title: "Feed", icon: "square.grid.2x2"),
        MugshotTabItem(index: 2, title: "Add", icon: "plus"),
        MugshotTabItem(index: 3, title: "Saved", icon: "bookmark"),
        MugshotTabItem(index: 4, title: "Profile", icon: "person")
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(items) { item in
                Button {
                    withAnimation(DesignSystem.Motion.base) {
                        selectedTab = item.index
                    }
                } label: {
                    if item.index == 2 {
                        addButton(isSelected: selectedTab == item.index)
                    } else {
                        standardItem(item, isSelected: selectedTab == item.index)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(item.title)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .padding(.bottom, 24)
        .background(Color.foamWhite)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.mugshotLine)
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: -4)
        .ignoresSafeArea(edges: .bottom)
    }

    private func standardItem(_ item: MugshotTabItem, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: isSelected ? selectedIcon(for: item.icon) : item.icon)
                .font(.system(size: 20, weight: .semibold))
            Text(item.title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(isSelected ? .mugshotSage : .tertiaryText)
        .frame(height: 48)
    }

    private func addButton(isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.foamWhite)
                .frame(width: 54, height: 54)
                .background(isSelected ? Color.mugshotMatcha : Color.mugshotSage)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 5)

            Text("Add")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isSelected ? .mugshotSage : .tertiaryText)
        }
        .offset(y: -15)
        .frame(height: 54)
    }

    private func selectedIcon(for icon: String) -> String {
        switch icon {
        case "bookmark":
            return "bookmark.fill"
        case "person":
            return "person.fill"
        case "map":
            return "map.fill"
        default:
            return icon
        }
    }
}

private struct MugshotTabItem: Identifiable {
    let index: Int
    let title: String
    let icon: String

    var id: Int { index }
}
