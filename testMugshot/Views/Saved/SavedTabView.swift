//
//  SavedTabView.swift
//  testMugshot
//
//  Redesigned Saved tab with icon-based navigation, summary stats,
//  rich cafe cards with context, and modern interactions.
//

import SwiftUI
import CoreLocation

struct SavedTabView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject var tabCoordinator: TabCoordinator
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    // MARK: - State
    @State private var selectedTab: SavedTab = .favorites
    @State private var sortOption: SavedSortOption = .bestRated
    @State private var selectedCafe: Cafe?
    @State private var showLogVisit = false
    @State private var showCafeDetail = false
    @State private var showNotifications = false
    @State private var showUndoToast = false
    @State private var recentlyRemovedCafe: (cafe: Cafe, fromTab: SavedTab)?
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    // MARK: - Computed Properties
    
    private var favoritesCount: Int {
        dataManager.appData.cafes.filter { $0.isFavorite }.count
    }
    
    private var wishlistCount: Int {
        dataManager.appData.cafes.filter { $0.wantToTry }.count
    }

    private var currentUserVisitCountsByCafe: [UUID: Int] {
        dataManager.currentUserVisitCountsByCafe()
    }
    
    private var totalCafesCount: Int {
        currentUserVisitCountsByCafe.count
    }
    
    private var statTabs: [DSStatTabs.Tab] {
        [
            .init(id: "favorites", count: favoritesCount, label: "Favorites"),
            .init(id: "wishlist", count: wishlistCount, label: "Wishlist"),
            .init(id: "library", count: totalCafesCount, label: "My Cafes")
        ]
    }
    
    private func filteredCafes(using visitCounts: [UUID: Int]) -> [Cafe] {
        var cafes: [Cafe]
        
        switch selectedTab {
        case .favorites:
            cafes = dataManager.appData.cafes.filter { $0.isFavorite }
        case .wishlist:
            cafes = dataManager.appData.cafes.filter { $0.wantToTry }
        case .library:
            cafes = dataManager.appData.cafes.filter { (visitCounts[$0.id] ?? 0) > 0 }
            logMyCafesDebugInfo(visitCounts: visitCounts, cafes: cafes)
        }
        
        return sortCafes(cafes, visitCounts: visitCounts)
    }
    
    private func sortCafes(_ cafes: [Cafe], visitCounts: [UUID: Int]) -> [Cafe] {
        switch sortOption {
        case .bestRated:
            return cafes.sorted { $0.averageRating > $1.averageRating }
        case .worstRated:
            return cafes.sorted { $0.averageRating < $1.averageRating }
        case .mostVisited:
            return cafes.sorted {
                (visitCounts[$0.id] ?? 0) > (visitCounts[$1.id] ?? 0)
            }
        case .recentlyVisited:
            return cafes.sorted { cafe1, cafe2 in
                let date1 = dataManager.lastVisitDate(for: cafe1.id) ?? Date.distantPast
                let date2 = dataManager.lastVisitDate(for: cafe2.id) ?? Date.distantPast
                return date1 > date2
            }
        case .recentlyAdded:
            return cafes.sorted { cafe1, cafe2 in
                let date1 = dataManager.dateAddedToWishlist(for: cafe1.id)
                let date2 = dataManager.dateAddedToWishlist(for: cafe2.id)
                return date1 > date2
            }
        case .closestToMe:
            guard let userLocation = locationManager.location else {
                return cafes // Fall back to original order if no location
            }
            return cafes.sorted { cafe1, cafe2 in
                let dist1 = dataManager.distance(to: cafe1, from: userLocation) ?? Double.greatestFiniteMagnitude
                let dist2 = dataManager.distance(to: cafe2, from: userLocation) ?? Double.greatestFiniteMagnitude
                return dist1 < dist2
            }
        case .alphabetical:
            return cafes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        let visitCounts = currentUserVisitCountsByCafe
        let cafesForDisplay = filteredCafes(using: visitCounts)
        
        return NavigationStack {
            VStack(spacing: 0) {
                // 1. Mint header with title + Instagram-style stat tabs
                headerSection
                
                // 2. Stat tabs (Instagram-style with counts)
                DSStatTabs(
                    tabs: statTabs,
                    selectedTabId: Binding(
                        get: { selectedTab.id },
                        set: { newId in
                            if let tab = SavedTab(rawValue: newId), tab != selectedTab {
                                    hapticsManager.selectionChanged()
                                selectedTab = tab
                                sortOption = tab.defaultSort
                            }
                        }
                    )
                )
                .background(DS.Colors.appBarBackground)
                
                // 3. Content
                if cafesForDisplay.isEmpty {
                    emptyStateForCurrentTab
                        .transition(.opacity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Filter/Sort bar
                            DSFilterSortBar(
                                availableOptions: selectedTab.sortOptions,
                                selectedOption: $sortOption
                            )
                            
                            // Cafe list with swipe actions
                            LazyVStack(spacing: DS.Spacing.lg) {
                                ForEach(cafesForDisplay) { cafe in
                                    let visitCount = visitCounts[cafe.id] ?? 0
                                    let imageInfo = dataManager.cafeImageInfo(for: cafe.id)
                                    
                                    SavedCafeCard(
                                        cafe: cafe,
                                        mode: selectedTab,
                                        lastVisitDate: dataManager.lastVisitDate(for: cafe.id),
                                        visitCount: visitCount,
                                        favoriteDrink: dataManager.favoriteDrink(for: cafe.id),
                                        cafeImagePath: imageInfo.path,
                                        cafeImageRemoteURL: imageInfo.remoteURL,
                                        dataManager: dataManager,
                                        onLogVisit: {
                                            selectedCafe = cafe
                                            showLogVisit = true
                                        },
                                        onShowDetails: {
                                            selectedCafe = cafe
                                            showCafeDetail = true
                                        }
                                    )
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            hapticsManager.lightTap()
                                            selectedCafe = cafe
                                            showLogVisit = true
                                        } label: {
                                            Label("Log Visit", systemImage: "cup.and.saucer")
                                        }
                                        .tint(DS.Colors.primaryAccent)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            removeCafe(cafe)
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                                    .contextMenu {
                                        cafeContextMenu(for: cafe)
                                    }
                                }
                            }
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .padding(.top, DS.Spacing.md)
                            .padding(.bottom, DS.Spacing.xxl * 2)
                        }
                    }
                    .background(DS.Colors.screenBackground)
                    .transition(.opacity)
                }
            }
            .background(DS.Colors.screenBackground)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    notificationButton
                }
            }
        }
        .sheet(isPresented: $showLogVisit) {
            if let cafe = selectedCafe {
                LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                UnifiedCafeView(
                    cafe: cafe,
                    dataManager: dataManager,
                    presentationMode: .fullScreen
                )
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsCenterView(dataManager: dataManager)
        }
        .overlay(alignment: .bottom) {
            if showUndoToast, let removed = recentlyRemovedCafe {
                undoToast(for: removed.cafe, fromTab: removed.fromTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Saved")
                .font(DS.Typography.screenTitle)
                .foregroundColor(DS.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
        .background(
            // Extend mint background above safe area
            GeometryReader { geometry in
                DS.Colors.appBarBackground
                    .frame(height: geometry.size.height + geometry.safeAreaInsets.top + 100)
                    .offset(y: -geometry.safeAreaInsets.top - 100)
            }
        )
    }
    
    // MARK: - Empty States
    
    @ViewBuilder
    private var emptyStateForCurrentTab: some View {
        switch selectedTab {
        case .favorites:
            EmptyStateView(
                iconName: "MugsyNoFavorites",
                title: "No favorites yet",
                subtitle: "Heart a cafe from your visits to add it here.",
                primaryAction: EmptyStateAction(
                    title: "View Your Visits",
                    icon: "list.bullet",
                    action: {
                        // Navigate to Profile tab
                        tabCoordinator.switchToProfile()
                    }
                )
            )
        case .wishlist:
            EmptyStateView(
                iconName: "MugsyNoWishlist",
                title: "Nothing on your wishlist",
                subtitle: "Bookmark cafes you want to try from the Feed or Map.",
                primaryAction: EmptyStateAction(
                    title: "Explore the Map",
                    icon: "map",
                    action: {
                        // Navigate to Map tab
                        tabCoordinator.switchToMap()
                    }
                )
            )
        case .library:
            EmptyStateView(
                iconName: "MugsyNoCafes",
                title: "No cafes yet",
                subtitle: "Log your first visit to start building your cafe collection.",
                primaryAction: EmptyStateAction(
                    title: "Log a Visit",
                    icon: "plus",
                    action: {
                        showLogVisit = true
                    }
                )
            )
        }
    }
    
    // MARK: - Debug Logging
    
    private func logMyCafesDebugInfo(visitCounts: [UUID: Int], cafes: [Cafe]) {
        #if DEBUG
        let userIdentifier = dataManager.appData.supabaseUserId ??
            dataManager.appData.currentUser?.id.uuidString ??
            "unknown"
        let totalVisits = visitCounts.values.reduce(0, +)
        
        print("[MyCafes] Building list for currentUserId=\(userIdentifier)")
        print("[MyCafes] Total visits for current user: \(totalVisits)")
        print("[MyCafes] Unique cafes for current user: \(cafes.count)")
        
        if cafes.isEmpty {
            print("[MyCafes] No cafes to include for current user.")
        }
        
        for cafe in cafes {
            let visitCount = visitCounts[cafe.id] ?? 0
            print("[MyCafes] Cafe '\(cafe.name)' included with visitCountForCurrentUser=\(visitCount)")
        }
        #endif
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func cafeContextMenu(for cafe: Cafe) -> some View {
        Button {
            hapticsManager.lightTap()
            selectedCafe = cafe
            showLogVisit = true
        } label: {
            Label("Log a Visit", systemImage: "cup.and.saucer")
        }
        
        Button {
            hapticsManager.lightTap()
            selectedCafe = cafe
            showCafeDetail = true
        } label: {
            Label("View Details", systemImage: "info.circle")
        }
        
        Button {
            hapticsManager.lightTap()
            openInMaps(cafe)
        } label: {
            Label("Get Directions", systemImage: "map")
        }
        
        if let websiteURL = cafe.websiteURL, !websiteURL.isEmpty {
            Button {
                hapticsManager.lightTap()
                openWebsite(urlString: websiteURL)
            } label: {
                Label("Visit Website", systemImage: "safari")
            }
        }
        
        Button {
            hapticsManager.lightTap()
            shareCafe(cafe)
        } label: {
            Label("Share Cafe", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        // Toggle actions
        Button {
            hapticsManager.lightTap()
            dataManager.toggleCafeFavorite(cafe.id)
        } label: {
            Label(
                cafe.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: cafe.isFavorite ? "heart.slash" : "heart"
            )
        }
        
        Button {
            hapticsManager.lightTap()
            dataManager.toggleCafeWantToTry(cafe.id)
        } label: {
            Label(
                cafe.wantToTry ? "Remove from Wishlist" : "Add to Wishlist",
                systemImage: cafe.wantToTry ? "bookmark.slash" : "bookmark"
            )
        }
        
        Divider()
        
        Button(role: .destructive) {
            removeCafe(cafe)
        } label: {
            Label("Remove from Saved", systemImage: "trash")
        }
    }
    
    // MARK: - Notification Button
    
    private var notificationButton: some View {
                Button(action: { showNotifications = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.iconDefault)
                        
                        if unreadNotificationCount > 0 {
                            Text("\(unreadNotificationCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DS.Colors.textOnMint)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(DS.Colors.primaryAccent)
                                )
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
    
    // MARK: - Undo Toast
    
    @ViewBuilder
    private func undoToast(for cafe: Cafe, fromTab: SavedTab) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text("Removed \(cafe.name)")
                .font(DS.Typography.subheadline(.medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Button("Undo") {
                undoRemoval()
            }
            .font(DS.Typography.subheadline(.bold))
            .foregroundColor(DS.Colors.primaryAccent)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.textPrimary)
        .cornerRadius(DS.Radius.md)
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.bottom, DS.Spacing.xxl)
    }
    
    // MARK: - Actions
    
    private func removeCafe(_ cafe: Cafe) {
        hapticsManager.playWarning()
        
        // Store for undo
        recentlyRemovedCafe = (cafe, selectedTab)
        
        // Remove based on current tab
        switch selectedTab {
        case .favorites:
            dataManager.toggleCafeFavorite(cafe.id)
        case .wishlist:
            dataManager.toggleCafeWantToTry(cafe.id)
        case .library:
            // For library, remove both flags
            if cafe.isFavorite {
                dataManager.toggleCafeFavorite(cafe.id)
            }
            if cafe.wantToTry {
                dataManager.toggleCafeWantToTry(cafe.id)
            }
        }
        
        // Show undo toast
        withAnimation(.easeInOut(duration: 0.3)) {
            showUndoToast = true
        }
        
        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showUndoToast = false
                recentlyRemovedCafe = nil
            }
        }
    }
    
    private func undoRemoval() {
        guard let removed = recentlyRemovedCafe else { return }
        
        hapticsManager.playSuccess()
        
        // Re-add based on what was removed
        switch removed.fromTab {
        case .favorites:
            dataManager.toggleCafeFavorite(removed.cafe.id)
        case .wishlist:
            dataManager.toggleCafeWantToTry(removed.cafe.id)
        case .library:
            // For library, we can't fully restore without knowing original state
            // Just add back to favorites as a reasonable default
            if !removed.cafe.isFavorite {
                dataManager.toggleCafeFavorite(removed.cafe.id)
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showUndoToast = false
            recentlyRemovedCafe = nil
        }
    }
    
    private func openInMaps(_ cafe: Cafe) {
        guard let location = cafe.location else {
            print("[Cafe] Get directions failed - no location for \(cafe.name)")
            return
        }
        
        print("[Cafe] Get directions tapped for \(cafe.name) at (\(location.latitude), \(location.longitude))")
        
        if let mapURLString = cafe.mapItemURL, let url = URL(string: mapURLString) {
            UIApplication.shared.open(url)
        } else {
            let encodedName = cafe.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(encodedName)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWebsite(urlString: String) {
        // Normalize URL - add https:// if missing
        var normalizedURL = urlString
        if !normalizedURL.lowercased().hasPrefix("http://") && !normalizedURL.lowercased().hasPrefix("https://") {
            normalizedURL = "https://\(normalizedURL)"
        }
        
        print("[Cafe] Open website tapped: \(normalizedURL)")
        
        guard let url = URL(string: normalizedURL) else {
            print("[Cafe] Failed to create URL from: \(normalizedURL)")
            return
        }
        UIApplication.shared.open(url)
    }
    
    private func shareCafe(_ cafe: Cafe) {
        // Create share content
        var shareText = cafe.name
        if !cafe.address.isEmpty {
            shareText += "\n\(cafe.address)"
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // Present share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    SavedTabView(dataManager: DataManager.shared)
}
