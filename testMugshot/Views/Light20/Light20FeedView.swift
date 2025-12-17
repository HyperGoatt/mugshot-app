//
//  Light20FeedView.swift
//  testMugshot
//
//  Light 2.0 feed with clean cards and mint pill filters
//  Curated social coffee experience
//

import SwiftUI

struct Light20FeedView: View {
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
            return []
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DS.Colors.light20Background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        light20Header
                            .padding(.bottom, DS.Spacing.lg)
                        
                        if selectedScope == .discover {
                            DiscoverContentView(
                                dataManager: dataManager,
                                onCafeTap: { cafe in
                                    selectedCafe = cafe
                                },
                                onVisitTap: { visit in
                                    selectedVisit = visit
                                }
                            )
                            .padding(.bottom, 100)
                        } else {
                            feedContent
                                .padding(.bottom, 100)
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
                Light20NotificationsView(dataManager: dataManager)
            }
            .sheet(item: $selectedCafe) { cafe in
                Light20CafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: nil
                )
            }
            .task {
                await refreshFeed()
            }
            .onChange(of: tabCoordinator.navigationTarget) { _, newTarget in
                handleNavigationTarget(newTarget)
            }
        }
    }
    
    // MARK: - Header
    
    private var light20Header: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack {
                Text("Feed")
                    .light20Heading()
                
                Spacer()
                
                Button(action: { showNotifications = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(DS.Colors.light20CharcoalBlack)
                        
                        if unreadNotificationCount > 0 {
                            Circle()
                                .fill(DS.Colors.light20MintPrimary)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(Light20IconButtonStyle())
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.lg)
            
            Text("Sips from the community")
                .light20Label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            filterPills
        }
    }
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FeedScope.allCases, id: \.self) { scope in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hapticsManager.lightTap()
                            selectedScope = scope
                        }
                    }) {
                        Text(scope.displayName)
                    }
                    .buttonStyle(Light20PillChipStyle(isSelected: selectedScope == scope))
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    // MARK: - Feed Content
    
    private var feedContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            if visits.isEmpty {
                emptyState
            } else {
                ForEach(visits) { visit in
                    Light20SipCard(
                        visit: visit,
                        dataManager: dataManager,
                        onCafeTap: {
                            selectedCafe = dataManager.appData.cafes.first { $0.id == visit.cafeId }
                        },
                        onVisitTap: { selectedVisit = visit },
                        onUserTap: { userId in
                            profileNavigator.openProfile(
                                handle: .supabase(id: userId),
                                source: .feedAuthor,
                                triggerHaptic: false
                            )
                        }
                    )
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.light20TextTertiary)
            
            Text("No sips yet")
                .light20Subheading()
            
            Text("Follow friends to see their coffee adventures")
                .light20Label()
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Actions
    
    private func refreshFeed() async {
        isRefreshing = true
        await dataManager.refreshFeed(scope: selectedScope)
        isRefreshing = false
    }
    
    private func handleNavigationTarget(_ target: TabCoordinator.NavigationTarget?) {
        guard let target = target else { return }
        
        switch target {
        case .visitDetail(let visitId):
            if let visit = dataManager.appData.visits.first(where: { $0.id == visitId }) {
                selectedVisit = visit
            }
        case .friendProfile(let userId):
            profileNavigator.openProfile(
                handle: .supabase(id: userId),
                source: .feedAuthor,
                triggerHaptic: false
            )
        case .friendsFeed:
            selectedScope = .friends
        case .notifications:
            showNotifications = true
        default:
            break
        }
        
        tabCoordinator.clearNavigationTarget()
    }
}


