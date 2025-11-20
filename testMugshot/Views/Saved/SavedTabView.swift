//
//  SavedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct SavedTabView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedTab: SavedTab = .favorites
    @State private var sortOption: SortOption = .scoreBestToWorst
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var showLogVisit = false
    @State private var showNotifications = false
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    enum SavedTab: String, CaseIterable {
        case favorites = "Favorites"
        case wantToTry = "Want to Try"
        case allCafes = "All Cafes"
    }
    
    enum SortOption: String, CaseIterable {
        case scoreBestToWorst = "Score: Best → Worst"
        case scoreWorstToBest = "Score: Worst → Best"
        case dateNewestToOldest = "Date: Newest → Oldest"
        case dateOldestToNewest = "Date: Oldest → Newest"
        case alphabetical = "Alphabetical (A→Z)"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mint header band
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Saved")
                        .font(DS.Typography.screenTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    // Segmented control for Favorites / Want to Try / All Cafes
                    DSDesignSegmentedControl(
                        options: SavedTab.allCases.map { $0.rawValue },
                        selectedIndex: Binding(
                            get: { SavedTab.allCases.firstIndex(of: selectedTab) ?? 0 },
                            set: { selectedTab = SavedTab.allCases[$0] }
                        )
                    )
                    .padding(.top, DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.xxl)
                .padding(.bottom, DS.Spacing.md)
                .background(DS.Colors.appBarBackground)
                
                // Cafe list + optional sort control
                if filteredAndSortedCafes.isEmpty {
                    switch selectedTab {
                    case .favorites:
                        EmptyStateView(
                            iconName: "DreamingMug",
                            title: "No favorite cafes… yet.",
                            subtitle: "Go discover a new sip to save."
                        )
                    case .wantToTry:
                        EmptyStateView(
                            iconName: "BookmarkMug",
                            title: "Your wishlist is empty.",
                            subtitle: "Find a cafe to bookmark!"
                        )
                    case .allCafes:
                        VStack {
                            Spacer()
                            Text("No cafes available.")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Spacing.pagePadding * 2)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DS.Colors.screenBackground)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: DS.Spacing.sectionVerticalGap) {
                            if selectedTab == .allCafes {
                                HStack {
                                    Spacer()
                                    Menu {
                                        ForEach(SortOption.allCases, id: \.self) { option in
                                            Button {
                                                sortOption = option
                                            } label: {
                                                Label(option.rawValue, systemImage: sortOption == option ? "checkmark" : "")
                                            }
                                        }
                                    } label: {
                                        Label(sortOption.rawValue, systemImage: "arrow.up.arrow.down")
                                            .font(DS.Typography.bodyText)
                                            .foregroundColor(DS.Colors.textPrimary)
                                            .padding(.horizontal, DS.Spacing.md)
                                            .padding(.vertical, DS.Spacing.sm)
                                            .background(DS.Colors.cardBackground)
                                            .cornerRadius(DS.Radius.md)
                                            .dsCardShadow()
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.pagePadding)
                            }
                            
                            LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
                                ForEach(filteredAndSortedCafes) { cafe in
                                    CafeCard(
                                        cafe: cafe,
                                        dataManager: dataManager,
                                        mode: selectedTab,
                                        onLogVisit: {
                                            selectedCafe = cafe
                                            showLogVisit = true
                                        },
                                        onShowDetails: {
                                            selectedCafe = cafe
                                            showCafeDetail = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .padding(.bottom, DS.Spacing.xxl)
                        }
                    }
                    .background(DS.Colors.screenBackground)
                }
            }
            .background(DS.Colors.screenBackground)
        }
        .sheet(isPresented: $showLogVisit) {
            if let cafe = selectedCafe {
                LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                CafeDetailView(cafe: cafe, dataManager: dataManager)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsCenterView(dataManager: dataManager)
        }
    }
    
    private var filteredAndSortedCafes: [Cafe] {
        var cafes: [Cafe]
        
        switch selectedTab {
        case .favorites:
            cafes = dataManager.appData.cafes.filter { $0.isFavorite }
        case .wantToTry:
            cafes = dataManager.appData.cafes.filter { $0.wantToTry }
        case .allCafes:
            cafes = dataManager.appData.cafes
        }
        
        // Sort
        switch sortOption {
        case .scoreBestToWorst:
            return cafes.sorted { $0.averageRating > $1.averageRating }
        case .scoreWorstToBest:
            return cafes.sorted { $0.averageRating < $1.averageRating }
        case .dateNewestToOldest:
            return cafes.sorted { cafe1, cafe2 in
                let visits1 = dataManager.getVisitsForCafe(cafe1.id)
                let visits2 = dataManager.getVisitsForCafe(cafe2.id)
                let date1 = visits1.first?.date ?? Date.distantPast
                let date2 = visits2.first?.date ?? Date.distantPast
                return date1 > date2
            }
        case .dateOldestToNewest:
            return cafes.sorted { cafe1, cafe2 in
                let visits1 = dataManager.getVisitsForCafe(cafe1.id)
                let visits2 = dataManager.getVisitsForCafe(cafe2.id)
                let date1 = visits1.first?.date ?? Date.distantPast
                let date2 = visits2.first?.date ?? Date.distantPast
                return date1 < date2
            }
        case .alphabetical:
            return cafes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

struct CafeCard: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let mode: SavedTabView.SavedTab
    let onLogVisit: () -> Void
    let onShowDetails: () -> Void
    
    // Get cafe image from most recent visit, or nil if no visits/photos
    var cafeImagePath: String? {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        let sortedVisits = visits.sorted { $0.createdAt > $1.createdAt }
        return sortedVisits.first?.posterImagePath
    }
    
    var cafeImageRemoteURL: String? {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        guard let visit = visits.sorted(by: { $0.createdAt > $1.createdAt }).first,
              let key = visit.posterImagePath else {
            return nil
        }
        return visit.remoteURL(for: key)
    }
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .top, spacing: DS.Spacing.lg) {
                    // Thumbnail
                    if let imagePath = cafeImagePath {
                        PhotoThumbnailView(photoPath: imagePath, remoteURL: cafeImageRemoteURL, size: 72)
                    } else {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(DS.Colors.cardBackgroundAlt)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(DS.Colors.iconSubtle)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(cafe.name)
                            .font(DS.Typography.cardTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(2)
                        
                        if !cafe.address.isEmpty {
                            Text(cafe.address)
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: DS.Spacing.md) {
                            DSScoreBadge(score: cafe.averageRating)
                            Text("\(cafe.visitCount) log\(cafe.visitCount == 1 ? "" : "s")")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Inline favorite / want-to-try toggles
                    VStack(spacing: DS.Spacing.sm) {
                        Button(action: {
                            dataManager.toggleCafeFavorite(cafe.id)
                        }) {
                            Image(systemName: cafe.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundColor(cafe.isFavorite ? DS.Colors.secondaryAccent : DS.Colors.iconDefault)
                        }
                        
                        Button(action: {
                            dataManager.toggleCafeWantToTry(cafe.id)
                        }) {
                            Image(systemName: cafe.wantToTry ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 18))
                                .foregroundColor(cafe.wantToTry ? DS.Colors.primaryAccent : DS.Colors.iconDefault)
                        }
                    }
                }
                
                // Full-width Log a Visit button for Favorites / Want to Try
                if mode == .favorites || mode == .wantToTry {
                    Button(action: onLogVisit) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "cup.and.saucer")
                            Text("Log a Visit")
                        }
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                }
            }
        }
    }
    
    private func openInMaps() {
        guard let location = cafe.location else { return }
        
        if let mapURLString = cafe.mapItemURL, let url = URL(string: mapURLString) {
            UIApplication.shared.open(url)
        } else {
            let urlString = "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(cafe.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWebsite(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

struct CafeDetailView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var showLogVisit = false
    @State private var selectedVisit: Visit?
    
    var visits: [Visit] {
        dataManager.getVisitsForCafe(cafe.id)
    }
    
    // Get hero image from most recent visit, or nil if no visits/photos
    var heroImagePath: String? {
        let sortedVisits = visits.sorted { $0.createdAt > $1.createdAt }
        return sortedVisits.first?.posterImagePath
    }
    
    var heroImageRemoteURL: String? {
        guard let visit = visits.sorted(by: { $0.createdAt > $1.createdAt }).first,
              let key = visit.posterImagePath else {
            return nil
        }
        return visit.remoteURL(for: key)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero image - user photos > placeholder
                    if let imagePath = heroImagePath {
                        PhotoImageView(photoPath: imagePath, remoteURL: heroImageRemoteURL)
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.sandBeige)
                            .frame(height: 250)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.espressoBrown.opacity(0.3))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Cafe name and address
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cafe.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            
                            if !cafe.address.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.mugshotMint)
                                    Text(cafe.address)
                                        .font(.system(size: 14))
                                        .foregroundColor(.espressoBrown.opacity(0.7))
                                }
                            }
                            
                            if let category = cafe.placeCategory {
                                Text(category)
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Stats row
                        HStack(spacing: 24) {
                            VStack(alignment: .leading) {
                                Text("Average Rating")
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.mugshotMint)
                                        .font(.system(size: 14))
                                    Text(String(format: "%.1f", cafe.averageRating))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.espressoBrown)
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Total Visits")
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                Text("\(cafe.visitCount)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.espressoBrown)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button("Log Visit") {
                                showLogVisit = true
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: .infinity)
                            
                            HStack(spacing: 12) {
                                // Get Directions button
                                Button(action: {
                                    openInMaps()
                                }) {
                                    HStack {
                                        Image(systemName: "map")
                                            .font(.system(size: 14))
                                        Text("Get Directions")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.espressoBrown)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.sandBeige)
                                    .cornerRadius(DesignSystem.cornerRadius)
                                }
                                
                                // Visit Website button (only if URL available)
                                if let websiteURL = cafe.websiteURL, !websiteURL.isEmpty {
                                    Button(action: {
                                        openWebsite(urlString: websiteURL)
                                    }) {
                                        HStack {
                                            Image(systemName: "safari")
                                                .font(.system(size: 14))
                                            Text("Website")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(.espressoBrown)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.sandBeige)
                                        .cornerRadius(DesignSystem.cornerRadius)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Recent visits
                        if !visits.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Visits")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                
                                ForEach(visits.prefix(5)) { visit in
                                    VisitRow(visit: visit, dataManager: dataManager) {
                                        selectedVisit = visit
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("Café Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLogVisit) {
                LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
        }
    }
    
    private func openInMaps() {
        guard let location = cafe.location else { return }
        
        // Use mapItemURL if available, otherwise construct Maps URL from coordinates
        if let mapURLString = cafe.mapItemURL, let url = URL(string: mapURLString) {
            UIApplication.shared.open(url)
        } else {
            // Fallback: open Maps with coordinates
            let urlString = "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(cafe.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWebsite(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

struct VisitRow: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                PhotoThumbnailView(
                    photoPath: visit.posterImagePath,
                    remoteURL: visit.posterImagePath.flatMap { visit.remoteURL(for: $0) },
                    size: 60
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.date, style: .date)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    
                    Text(visit.drinkType.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.mugshotMint)
                        .font(.system(size: 12))
                    Text(String(format: "%.1f", visit.overallScore))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                }
            }
            .padding()
            .background(Color.sandBeige)
            .cornerRadius(DesignSystem.smallCornerRadius)
        }
        .buttonStyle(.plain)
    }
}

