//
//  MainTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @StateObject private var tabCoordinator = TabCoordinator()
    @State private var preselectedCafeForLogVisit: Cafe?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            activeTab
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.creamWhite)
                .transition(.opacity)

            if tabCoordinator.selectedTab != 2 {
                MugshotBottomNav(selectedTab: $tabCoordinator.selectedTab)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environmentObject(tabCoordinator)
        .tint(.mugshotSage)
        .background(Color.creamWhite.ignoresSafeArea())
        // The dock deliberately extends through the container safe area so it
        // sits with the home indicator instead of hovering a full safe-area
        // height above it.
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.mugshotSage)
        }
        .task(id: authModel.authenticatedUser?.id) {
            guard let userId = authModel.authenticatedUser?.id,
                  let client = try? SupabaseClientProvider.shared.client() else { return }
            if let clearedCount = try? await CafeStateService(client: client)
                .reconcileVisitedWantToTry(userId: userId),
               clearedCount > 0 {
                dataManager.noteJournalMutation()
            }
            await VisitDeletionService(client: client).retryPendingMediaCleanup(userId: userId)
            await DrinkAnalysisService(client: client).retryPendingAnalyses(userId: userId)
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
    @State private var dragPosition: CGFloat?
    @State private var dragPreviewTab: Int?

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
                GlassEffectContainer(spacing: 14) {
                    navItems
                }
            } else {
                navItems
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .mugshotGlassSurface(
            radius: 28,
            tint: Color.creamWhite.opacity(0.94),
            stroke: Color.foamWhite.opacity(0.68),
            shadow: DesignSystem.Shadow(color: .black.opacity(0.11), radius: 20, x: 0, y: -5),
            interactive: false
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var navItems: some View {
        GeometryReader { proxy in
            ZStack {
                if let dragPosition {
                    dragGlassLens(x: clamped(position: dragPosition, width: proxy.size.width))
                        .position(x: clamped(position: dragPosition, width: proxy.size.width), y: proxy.size.height / 2)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                HStack(alignment: .center, spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            withAnimation(DesignSystem.Motion.base) {
                                selectedTab = item.index
                            }
                        } label: {
                            if item.index == 2 {
                                addButton(
                                    isSelected: selectedTab == item.index,
                                    isPreviewing: dragPreviewTab == item.index
                                )
                            } else {
                                standardItem(
                                    item,
                                    isSelected: selectedTab == item.index,
                                    isPreviewing: dragPreviewTab == item.index
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityLabel(item.title)
                    }
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(width: proxy.size.width))
        }
        .frame(height: 54)
    }

    private func standardItem(
        _ item: MugshotTabItem,
        isSelected: Bool,
        isPreviewing: Bool
    ) -> some View {
        let isHighlighted = isSelected || isPreviewing
        let showsRestingSelection = isSelected && dragPosition == nil
        let label = VStack(spacing: 3) {
            Image(systemName: isHighlighted ? selectedIcon(for: item.icon) : item.icon)
                .font(.system(size: 18, weight: .semibold))
            Text(item.title)
                .font(.system(size: 10, weight: isHighlighted ? .bold : .semibold))
        }
        .foregroundColor(isHighlighted ? .mugshotSage : .tertiaryText)
        .frame(width: 56, height: 52)

        return Group {
            if showsRestingSelection {
                label
                    .mugshotGlassSurface(
                        radius: 18,
                        tint: Color.mugshotMint.opacity(0.84),
                        stroke: Color.foamWhite.opacity(0.50),
                        shadow: DesignSystem.Shadow(color: Color.mugshotSage.opacity(0.12), radius: 8, x: 0, y: 3),
                        interactive: true
                    )
            } else {
                label
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func addButton(isSelected: Bool, isPreviewing: Bool) -> some View {
        let isHighlighted = isSelected || isPreviewing
        let fill = isHighlighted ? Color.mugshotMatcha : Color.mugshotSage

        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(fill.opacity(isHighlighted ? 0.96 : 0.90))

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.foamWhite)
            }
            .frame(width: 48, height: 48)
            .mugshotGlassCircle(
                tint: fill,
                stroke: Color.foamWhite.opacity(0.72),
                shadow: DesignSystem.Shadow(color: fill.opacity(0.34), radius: 15, x: 0, y: 6),
                interactive: true
            )
            .scaleEffect(isHighlighted ? 1.05 : 1.0)

            Text("Add")
                .font(.system(size: 10, weight: isHighlighted ? .bold : .semibold))
                .foregroundColor(isHighlighted ? .mugshotSage : .tertiaryText)
        }
        .frame(width: 56, height: 54)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dragGlassLens(x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.mugshotMint.opacity(0.16))
            .frame(width: 58, height: 52)
            .mugshotGlassSurface(
                radius: 18,
                tint: Color.mugshotMint.opacity(0.76),
                stroke: Color.foamWhite.opacity(0.54),
                shadow: DesignSystem.Shadow(color: Color.mugshotSage.opacity(0.12), radius: 8, x: 0, y: 3),
                interactive: true
            )
            .accessibilityHidden(true)
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let position = clamped(position: value.location.x, width: width)
                dragPosition = position
                dragPreviewTab = nearestTab(to: position, width: width)
            }
            .onEnded { value in
                let target = nearestTab(to: value.location.x, width: width)
                withAnimation(DesignSystem.Motion.base) {
                    selectedTab = target
                    dragPosition = nil
                    dragPreviewTab = nil
                }
            }
    }

    private func nearestTab(to position: CGFloat, width: CGFloat) -> Int {
        let itemWidth = width / CGFloat(items.count)
        let index = Int((position / itemWidth).rounded(.down))
        return min(max(index, 0), items.count - 1)
    }

    private func clamped(position: CGFloat, width: CGFloat) -> CGFloat {
        min(max(position, 29), width - 29)
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
