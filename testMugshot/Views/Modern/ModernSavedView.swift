//
//  ModernSavedView.swift
//  testMugshot
//
//  Modern Saved view with 3 tabs: Favorites, Wishlist, My Cafes
//

import SwiftUI
import CoreLocation

struct ModernSavedView: View {
    @ObservedObject var dataManager: DataManager
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var selectedTab: SavedTab = .favorites
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    private var favoritesCount: Int {
        dataManager.appData.cafes.filter { $0.isFavorite }.count
    }
    
    private var wishlistCount: Int {
        dataManager.appData.cafes.filter { $0.wantToTry }.count
    }
    
    private var currentUserVisitCountsByCafe: [UUID: Int] {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return [:] }
        var counts: [UUID: Int] = [:]
        
        for visit in dataManager.appData.visits where visit.userId == currentUserId {
            counts[visit.cafeId, default: 0] += 1
        }
        
        return counts
    }
    
    private var myCafesCount: Int {
        currentUserVisitCountsByCafe.count
    }
    
    private var favorites: [Cafe] {
        dataManager.appData.cafes.filter { $0.isFavorite }
            .sorted { $0.averageRating > $1.averageRating }
    }
    
    private var wishlist: [Cafe] {
        dataManager.appData.cafes.filter { $0.wantToTry }
            .sorted { $0.name < $1.name }
    }
    
    private var myCafes: [Cafe] {
        dataManager.appData.cafes.filter { currentUserVisitCountsByCafe[$0.id] ?? 0 > 0 }
            .sorted { (currentUserVisitCountsByCafe[$0.id] ?? 0) > (currentUserVisitCountsByCafe[$1.id] ?? 0) }
    }
    
    var body: some View {
        ZStack {
            DS.Colors.dynamicBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Tab selector
                tabSelector
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                // Content
                ScrollView {
                    content
                        .padding(.top, 20)
                        .padding(.bottom, 120) // Space for floating tab bar
                }
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                ModernCafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: nil
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            Text("\(favoritesCount) favorites, \(wishlistCount) on wishlist")
                .font(.system(size: 15))
                .foregroundColor(DS.Colors.dynamicTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SavedTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hapticsManager.lightTap()
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(tab.label)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(selectedTab == tab ? DS.Colors.dynamicTextPrimary : DS.Colors.dynamicTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? DS.Colors.dynamicPrimaryAccent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(DS.Colors.dynamicCardBackgroundAlt)
        .cornerRadius(12)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .favorites:
            favoritesContent
        case .wishlist:
            wishlistContent
        case .library:
            myCafesContent
        }
    }
    
    // MARK: - Favorites (Horizontal Scroll)
    
    private var favoritesContent: some View {
        Group {
            if favorites.isEmpty {
                emptyState(
                    icon: "heart",
                    title: "No favorites yet",
                    subtitle: "Heart cafes to save them here"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(favorites) { cafe in
                            ModernSavedCard(
                                cafe: cafe,
                                userLocation: locationManager.location,
                                visitCount: currentUserVisitCountsByCafe[cafe.id] ?? 0,
                                lastVisitDate: dataManager.lastVisitDate(for: cafe.id),
                                dataManager: dataManager,
                                onTap: {
                                    hapticsManager.lightTap()
                                    selectedCafe = cafe
                                    showCafeDetail = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - Wishlist (Vertical List)
    
    private var wishlistContent: some View {
        Group {
            if wishlist.isEmpty {
                emptyState(
                    icon: "bookmark",
                    title: "No cafes on your wishlist",
                    subtitle: "Bookmark cafes you want to try"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(wishlist) { cafe in
                        wishlistCard(cafe: cafe)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func wishlistCard(cafe: Cafe) -> some View {
        Button(action: {
            hapticsManager.lightTap()
            selectedCafe = cafe
            showCafeDetail = true
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                Rectangle()
                    .fill(DS.Colors.dynamicCardBackgroundAlt)
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DS.Colors.dynamicTextTertiary)
                    )
                
                // Cafe info
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                        .lineLimit(1)
                    
                    Text(cafe.address)
                        .font(.system(size: 14))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
            }
            .padding(12)
            .themeAwareFloatingCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - My Cafes (Grid)
    
    private var myCafesContent: some View {
        Group {
            if myCafes.isEmpty {
                emptyState(
                    icon: "square.grid.2x2",
                    title: "No cafes visited yet",
                    subtitle: "Start exploring and log your first visit"
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(myCafes) { cafe in
                        myCafeCard(cafe: cafe)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func myCafeCard(cafe: Cafe) -> some View {
        Button(action: {
            hapticsManager.lightTap()
            selectedCafe = cafe
            showCafeDetail = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Square image
                Rectangle()
                    .fill(DS.Colors.dynamicCardBackgroundAlt)
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(16)
                    .overlay(
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 32))
                            .foregroundColor(DS.Colors.dynamicTextTertiary)
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                        .lineLimit(1)
                    
                    Text("\(currentUserVisitCountsByCafe[cafe.id] ?? 0) visits")
                        .font(.system(size: 13))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                }
            }
            .padding(12)
            .themeAwareFloatingCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(DS.Colors.dynamicTextSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}


