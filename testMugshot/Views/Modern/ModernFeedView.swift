//
//  ModernFeedView.swift
//  testMugshot
//
//  Modern Dark Mode feed with Instagram-like vertical scroll
//  Features: Transparent header, filter pills, sip cards
//

import SwiftUI

struct ModernFeedView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var tabCoordinator: TabCoordinator
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var selectedScope: FeedScope = .friends
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    @State private var showNotifications = false
    @State private var isRefreshing = false
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    // Filter visits based on selected scope
    private var visits: [Visit] {
        let allVisits = dataManager.appData.visits.sorted { $0.createdAt > $1.createdAt }
        
        switch selectedScope {
        case .friends:
            let friendIds = dataManager.appData.friendsSupabaseUserIds
            return allVisits.filter { visit in
                friendIds.contains(where: { $0 == visit.userId.uuidString.lowercased() })
            }
        case .everyone:
            return allVisits
        case .discover:
            return [] // Discover has its own content
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Dark background
                DS.Colors.dynamicBackground
                    .ignoresSafeArea()
                
                // Main content
                ScrollView {
                    VStack(spacing: 0) {
                        // Header section
                        modernHeader
                            .padding(.bottom, DS.Spacing.lg)
                        
                        // Feed content
                        if selectedScope == .discover {
                            // Discover content
                            DiscoverContentView(
                                dataManager: dataManager,
                                onCafeTap: { cafe in
                                    selectedCafe = cafe
                                },
                                onVisitTap: { visit in
                                    selectedVisit = visit
                                }
                            )
                            .padding(.bottom, 100) // Extra space for floating tab bar
                        } else {
                            feedContent
                                .padding(.bottom, 100) // Extra space for floating tab bar
                        }
                    }
                }
                .refreshable {
                    await refreshFeed()
                }
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .sheet(isPresented: $showNotifications) {
                ModernNotificationsView(dataManager: dataManager)
            }
            .sheet(item: $selectedCafe) { cafe in
                ModernCafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: nil
                )
            }
            .task {
                // Initial data refresh
                await refreshFeed()
            }
            .onChange(of: tabCoordinator.navigationTarget) { _, newTarget in
                handleNavigationTarget(newTarget)
            }
        }
    }
    
    // MARK: - Header
    
    private var modernHeader: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Top bar (Feed title + notification bell)
            HStack {
                Text("Feed")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                
                Spacer()
                
                Button(action: { showNotifications = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(DS.Colors.dynamicTextPrimary)
                        
                        if unreadNotificationCount > 0 {
                            Circle()
                                .fill(DS.Colors.dynamicPrimaryAccent)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.lg)
            
            // Filter pills
            filterPills
        }
    }
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FeedScope.allCases, id: \.self) { scope in
                    ModernFilterPill(
                        title: scope.displayName,
                        isSelected: selectedScope == scope
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hapticsManager.lightTap()
                            selectedScope = scope
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    // MARK: - Feed Content
    
    @ViewBuilder
    private var feedContent: some View {
        if dataManager.isBootstrapping && visits.isEmpty {
            // Loading state
            VStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { _ in
                    modernSkeletonCard
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.lg)
        } else if visits.isEmpty {
            // Empty state
            modernEmptyState
        } else {
            // Sip cards
            LazyVStack(spacing: 20) {
                ForEach(visits) { visit in
                    if let cafe = dataManager.getCafe(id: visit.cafeId) {
                        ModernSipCard(
                            visit: visit,
                            cafeName: cafe.name,
                            userName: visit.authorDisplayNameOrUsername,
                            userAvatarURL: visit.authorAvatarURL,
                            onTap: {
                                hapticsManager.lightTap()
                                selectedVisit = visit
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.md)
        }
    }
    
    private var modernSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image skeleton
            Rectangle()
                .fill(DS.Colors.dynamicCardBackgroundAlt)
                .aspectRatio(4/5, contentMode: .fit)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DS.Colors.dynamicDivider, lineWidth: 1)
                )
            
            // Metadata skeleton
            HStack(spacing: 12) {
                Circle()
                    .fill(DS.Colors.dynamicCardBackgroundAlt)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(DS.Colors.dynamicCardBackgroundAlt)
                        .frame(width: 100, height: 14)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(DS.Colors.dynamicCardBackgroundAlt)
                        .frame(width: 200, height: 12)
                        .cornerRadius(4)
                }
            }
        }
    }
    
    private var modernEmptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 60))
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            Text(selectedScope == .friends ? "Your friends haven't posted yet" : "No posts yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            Text(selectedScope == .friends ? "Be the first to share a sip!" : "Check back later for new content")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(DS.Colors.dynamicTextSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Actions
    
    private func refreshFeed() async {
        isRefreshing = true
        do {
            await dataManager.refreshFeed(scope: selectedScope)
            await dataManager.refreshNotifications()
        } catch {
            print("[ModernFeedView] Error refreshing feed: \(error)")
        }
        isRefreshing = false
    }
    
    private func handleNavigationTarget(_ target: TabCoordinator.NavigationTarget?) {
        guard let target else { return }
        
        switch target {
        case .visitDetail(let visitId):
            if let visit = dataManager.appData.visits.first(where: { $0.id == visitId }) {
                selectedVisit = visit
                tabCoordinator.clearNavigationTarget()
            }
        default:
            break
        }
    }
}

// MARK: - Modern Filter Pill

struct ModernFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? DS.Colors.dynamicTextPrimary : DS.Colors.dynamicTextSecondary)
                
                // Mint dot indicator for active state
                if isSelected {
                    Circle()
                        .fill(DS.Colors.dynamicPrimaryAccent)
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}


