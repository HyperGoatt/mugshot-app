//
//  Light20SavedView.swift
//  testMugshot
//
//  Light 2.0 saved cafes with clean cards and pill tabs
//  Edge-to-edge list layout
//

import SwiftUI

struct Light20SavedView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var selectedTab: SavedTab = .favorites
    @State private var selectedSortOption: SavedSortOption = .bestRated
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    private var favoriteCafes: [Cafe] {
        dataManager.appData.cafes
            .filter { $0.isFavorite }
            .sorted(by: sortComparator)
    }
    
    private var wishlistCafes: [Cafe] {
        dataManager.appData.cafes
            .filter { $0.wantToTry }
            .sorted(by: sortComparator)
    }
    
    private var libraryCafes: [Cafe] {
        let visitedCafeIds = Set(dataManager.appData.visits.map { $0.cafeId })
        return dataManager.appData.cafes
            .filter { visitedCafeIds.contains($0.id) }
            .sorted(by: sortComparator)
    }
    
    private var displayedCafes: [Cafe] {
        switch selectedTab {
        case .favorites: return favoriteCafes
        case .wishlist: return wishlistCafes
        case .library: return libraryCafes
        @unknown default: return favoriteCafes
        }
    }
    
    private func sortComparator(cafe1: Cafe, cafe2: Cafe) -> Bool {
        switch selectedSortOption {
        case .bestRated:
            let rating1 = averageRating(for: cafe1)
            let rating2 = averageRating(for: cafe2)
            return rating1 > rating2
        case .worstRated:
            let rating1 = averageRating(for: cafe1)
            let rating2 = averageRating(for: cafe2)
            return rating1 < rating2
        case .mostVisited:
            let visits1 = dataManager.appData.visits.filter { $0.cafeId == cafe1.id }.count
            let visits2 = dataManager.appData.visits.filter { $0.cafeId == cafe2.id }.count
            return visits1 > visits2
        case .recentlyVisited:
            let lastVisit1 = dataManager.appData.visits.filter { $0.cafeId == cafe1.id }.max { $0.createdAt < $1.createdAt }
            let lastVisit2 = dataManager.appData.visits.filter { $0.cafeId == cafe2.id }.max { $0.createdAt < $1.createdAt }
            return (lastVisit1?.createdAt ?? .distantPast) > (lastVisit2?.createdAt ?? .distantPast)
        case .recentlyAdded:
            return cafe1.name.localizedCaseInsensitiveCompare(cafe2.name) == .orderedDescending
        case .closestToMe:
            // No distance info available here; keep stable order
            return cafe1.name.localizedCaseInsensitiveCompare(cafe2.name) == .orderedAscending
        case .alphabetical:
            return cafe1.name.localizedCaseInsensitiveCompare(cafe2.name) == .orderedAscending
        @unknown default:
            return cafe1.name < cafe2.name
        }
    }
    
    private func averageRating(for cafe: Cafe) -> Double {
        let visits = dataManager.appData.visits.filter { $0.cafeId == cafe.id }
        guard !visits.isEmpty else { return 0 }
        return visits.reduce(0.0, { $0 + $1.overallScore }) / Double(visits.count)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DS.Colors.light20Background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) {
                            if displayedCafes.isEmpty {
                                emptyState
                            } else {
                                ForEach(displayedCafes) { cafe in
                                    Light20SavedCard(
                                        cafe: cafe,
                                        dataManager: dataManager,
                                        onTap: {
                                            selectedCafe = cafe
                                            showCafeDetail = true
                                        }
                                    )
                                    .padding(.horizontal, DS.Spacing.pagePadding)
                                }
                            }
                        }
                        .padding(.top, DS.Spacing.lg)
                        .padding(.bottom, 100)
                    }
                }
            }
            .sheet(isPresented: $showCafeDetail) {
                if let cafe = selectedCafe {
                    Light20CafeDetailView(
                        cafe: cafe,
                        dataManager: dataManager,
                        onLogVisitRequested: nil
                    )
                }
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Saved")
                .light20Heading()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.lg)
            
            tabPills
            
            sortDropdown
        }
        .background(DS.Colors.light20Background)
    }
    
    private var tabPills: some View {
        HStack(spacing: 12) {
            ForEach(SavedTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hapticsManager.lightTap()
                        selectedTab = tab
                        selectedSortOption = tab.defaultSort
                    }
                }) {
                    VStack(spacing: 4) {
                        Text("\(countForTab(tab))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(selectedTab == tab ? DS.Colors.light20MintPrimary : DS.Colors.light20CharcoalBlack)
                        
                        Text(tab.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedTab == tab ? DS.Colors.light20MintPrimary : DS.Colors.light20TextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab ? DS.Colors.light20MintSoftFill : Color.clear)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedTab == tab ? DS.Colors.light20MintPrimary : DS.Colors.light20BorderLight, lineWidth: selectedTab == tab ? 2 : 1)
                    )
                }
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var sortDropdown: some View {
        DSFilterSortBar(
            availableOptions: selectedTab.sortOptions,
            selectedOption: $selectedSortOption,
            showSearch: false
        )
        .padding(.horizontal, DS.Spacing.pagePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab == .wishlist ? "star" : "bookmark")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.light20TextTertiary)
            
            Text(emptyStateTitle)
                .light20Subheading()
            
            Text(emptyStateMessage)
                .light20Label()
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var emptyStateTitle: String {
        switch selectedTab {
        case .favorites: return "No favorites yet"
        case .wishlist: return "No wishlist items"
        case .library: return "No cafes visited"
        @unknown default: return "No items"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedTab {
        case .favorites: return "Favorite cafes you love to visit again"
        case .wishlist: return "Save cafes you want to try"
        case .library: return "Log a visit to start your coffee journey"
        @unknown default: return ""
        }
    }
    
    private func countForTab(_ tab: SavedTab) -> Int {
        switch tab {
        case .favorites: return favoriteCafes.count
        case .wishlist: return wishlistCafes.count
        case .library: return libraryCafes.count
        @unknown default: return 0
        }
    }
}


