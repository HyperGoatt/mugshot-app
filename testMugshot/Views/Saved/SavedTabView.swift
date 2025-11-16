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
    @State private var sortOption: SortOption = .score
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var showLogVisit = false
    
    enum SavedTab: String, CaseIterable {
        case favorites = "Favorites"
        case wantToTry = "Want to Try"
        case allCafes = "All Cafes"
    }
    
    enum SortOption: String, CaseIterable {
        case score = "By Score"
        case date = "By Date"
        case name = "By Name"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Tab", selection: $selectedTab) {
                    ForEach(SavedTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(DS.Spacing.pagePadding)
                
                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    DSSectionHeader("Your Cafés", subtitle: selectedTab.rawValue)
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.bottom, DS.Spacing.md)
                
                // Sort option (only for All Cafes)
                if selectedTab == .allCafes {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
                
                // Cafe list
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
                        ForEach(filteredAndSortedCafes) { cafe in
                            CafeCard(
                                cafe: cafe,
                                dataManager: dataManager,
                                showWantToTryTag: selectedTab == .wantToTry,
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
                        
                        if filteredAndSortedCafes.isEmpty {
                            DSBaseCard {
                                Text("No cafés yet")
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .padding(DS.Spacing.pagePadding)
                }
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Saved")
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
        case .score:
            return cafes.sorted { $0.averageRating > $1.averageRating }
        case .date:
            // Sort by most recent visit
            return cafes.sorted { cafe1, cafe2 in
                let visits1 = dataManager.getVisitsForCafe(cafe1.id)
                let visits2 = dataManager.getVisitsForCafe(cafe2.id)
                let date1 = visits1.first?.date ?? Date.distantPast
                let date2 = visits2.first?.date ?? Date.distantPast
                return date1 > date2
            }
        case .name:
            return cafes.sorted { $0.name < $1.name }
        }
    }
}

struct CafeCard: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let showWantToTryTag: Bool
    let onLogVisit: () -> Void
    let onShowDetails: () -> Void
    
    // Get cafe image from most recent visit, or nil if no visits/photos
    var cafeImagePath: String? {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        let sortedVisits = visits.sorted { $0.createdAt > $1.createdAt }
        return sortedVisits.first?.posterImagePath
    }
    
    var body: some View {
        DSBaseCard {
            HStack(spacing: DS.Spacing.lg) {
                // Cafe image - user photos > placeholder
                if let imagePath = cafeImagePath {
                    PhotoThumbnailView(photoPath: imagePath, size: 80)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(DS.Colors.cardBackgroundAlt)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(DS.Colors.iconSubtle)
                        )
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        Text(cafe.name)
                            .font(DS.Typography.cardTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                        
                        if showWantToTryTag {
                            DSPillChip(label: "Wish", isSelected: true)
                        }
                    }
                    
                    // Address or neighborhood
                    if !cafe.address.isEmpty {
                        Text(cafe.address)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: DS.Spacing.md) {
                        DSScoreBadge(score: cafe.averageRating)
                        Text("• \(cafe.visitCount) visits")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    // Quick actions
                    HStack(spacing: DS.Spacing.lg) {
                        Button("Log Visit") {
                            onLogVisit()
                        }
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.primaryAccent)
                        
                        Button("Map") {
                            openInMaps()
                        }
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        
                        if cafe.websiteURL != nil {
                            Button(action: {
                                if let url = cafe.websiteURL {
                                    openWebsite(urlString: url)
                                }
                            }) {
                                Image(systemName: "safari")
                                    .font(DS.Typography.caption2)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }
                        
                        Button("Details") {
                            onShowDetails()
                        }
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                    }
                }
                
                Spacer()
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
    
    var visits: [Visit] {
        dataManager.getVisitsForCafe(cafe.id)
    }
    
    // Get hero image from most recent visit, or nil if no visits/photos
    var heroImagePath: String? {
        let sortedVisits = visits.sorted { $0.createdAt > $1.createdAt }
        return sortedVisits.first?.posterImagePath
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero image - user photos > placeholder
                    if let imagePath = heroImagePath {
                        PhotoImageView(photoPath: imagePath)
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
                                    VisitRow(visit: visit, dataManager: dataManager)
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
    @State private var showVisitDetail = false
    
    var body: some View {
        Button(action: {
            showVisitDetail = true
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                PhotoThumbnailView(photoPath: visit.posterImagePath, size: 60)
                
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
        .fullScreenCover(isPresented: $showVisitDetail) {
            VisitDetailView(visit: visit, dataManager: dataManager)
        }
    }
}

