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
        ZStack(alignment: .bottom) {
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
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 18) {
                    navItems
                }
            } else {
                navItems
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .mugshotGlassSurface(
            radius: 30,
            tint: .foamWhite,
            stroke: Color.foamWhite.opacity(0.58),
            shadow: DesignSystem.Shadow(color: .black.opacity(0.09), radius: 18, x: 0, y: -3),
            interactive: false
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var navItems: some View {
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
                .contentShape(Rectangle())
                .accessibilityLabel(item.title)
            }
        }
    }

    private func standardItem(_ item: MugshotTabItem, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: isSelected ? selectedIcon(for: item.icon) : item.icon)
                .font(.system(size: 20, weight: .semibold))
            Text(item.title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(isSelected ? .mugshotSage : .tertiaryText)
        .frame(height: 58)
    }

    private func addButton(isSelected: Bool) -> some View {
        let fill = isSelected ? Color.mugshotMatcha : Color.mugshotSage

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(fill.opacity(isSelected ? 0.94 : 0.88))

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.foamWhite)
            }
            .frame(width: 50, height: 50)
            .mugshotGlassCircle(
                tint: fill,
                stroke: Color.foamWhite.opacity(0.62),
                shadow: DesignSystem.Shadow(color: fill.opacity(0.32), radius: 14, x: 0, y: 5),
                interactive: true
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)

            Text("Add")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isSelected ? .mugshotSage : .tertiaryText)
        }
        .frame(height: 58)
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
