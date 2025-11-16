//
//  ProfileTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct ProfileTabView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedTab: ProfileContentTab = .recent
    
    enum ProfileContentTab: String, CaseIterable {
        case recent = "Recent"
        case topCafes = "Top Cafes"
        case favorites = "Favorites"
        case wishlist = "Wishlist"
    }
    
    var user: User? {
        dataManager.appData.currentUser
    }
    
    var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        dataManager.getUserStats()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner
                    Rectangle()
                        .fill(LinearGradient(colors: [DS.Colors.primaryAccent, DS.Colors.cardBackgroundAlt], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Spacer()
                                // Avatar
                                Circle()
                                    .fill(DS.Colors.cardBackground)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(user?.username.prefix(1).uppercased() ?? "U")
                                            .font(DS.Typography.title2(.bold))
                                            .foregroundColor(DS.Colors.textPrimary)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(DS.Colors.cardBackground, lineWidth: 4)
                                    )
                                    .offset(y: 40)
                            }
                        )
                    
                    VStack(spacing: DS.Spacing.section) {
                        // User info
                        DSBaseCard {
                            VStack(spacing: DS.Spacing.sm) {
                                Text("@\(user?.username ?? "user")")
                                    .font(DS.Typography.title2(.semibold))
                                    .foregroundColor(DS.Colors.textPrimary)
                                
                                if let location = user?.location, !location.isEmpty {
                                    Text(location)
                                        .font(DS.Typography.bodyText)
                                        .foregroundColor(DS.Colors.textSecondary)
                                }
                                
                                if let bio = user?.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(DS.Typography.bodyText)
                                        .foregroundColor(DS.Colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(.top, DS.Spacing.section)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        // Stats section
                        DSBaseCard {
                            VStack(spacing: DS.Spacing.md) {
                                DSSectionHeader("Stats")
                                HStack(spacing: DS.Spacing.section) {
                                    StatBox(title: "Visits", value: "\(stats.totalVisits)")
                                    StatBox(title: "Cafés", value: "\(stats.totalCafes)")
                                    StatBox(title: "Avg Score", value: String(format: "%.1f", stats.averageScore))
                                    StatBox(title: "Favorite", value: stats.favoriteDrinkType?.rawValue ?? "-")
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        // Coffee Journey
                        DSBaseCard {
                            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                                DSSectionHeader("Coffee Journey")
                                CoffeeJourneyView(stats: stats)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        // Content tabs
                        Picker("Content", selection: $selectedTab) {
                            ForEach(ProfileContentTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        // Content based on selected tab
                        contentView
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .padding(.bottom, DS.Spacing.xxl)
                    }
                }
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Profile")
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .recent:
            RecentVisitsView(dataManager: dataManager)
        case .topCafes:
            TopCafesView(dataManager: dataManager)
        case .favorites:
            FavoritesView(dataManager: dataManager)
        case .wishlist:
            WishlistView(dataManager: dataManager)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(DS.Typography.numericStat)
                .foregroundColor(DS.Colors.textPrimary)
            
            Text(title)
                .font(DS.Typography.caption2)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CoffeeJourneyView: View {
    let stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Simple progress representation
            HStack(spacing: 8) {
                ForEach(0..<min(stats.totalCafes, 10), id: \.self) { _ in
                    Circle()
                        .fill(DS.Colors.primaryAccent)
                        .frame(width: 12, height: 12)
                }
                
                if stats.totalCafes > 10 {
                    Text("+\(stats.totalCafes - 10)")
                        .font(DS.Typography.caption2)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            
            Text("\(stats.totalVisits) visits across \(stats.totalCafes) cafés")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

struct RecentVisitsView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedVisit: Visit?
    @State private var showVisitDetail = false
    
    var visits: [Visit] {
        dataManager.appData.visits.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if visits.isEmpty {
                DSBaseCard {
                    Text("No visits yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(visits) { visit in
                    if dataManager.getCafe(id: visit.cafeId) != nil {
                        VisitCard(visit: visit, dataManager: dataManager, selectedScope: .friends)
                            .onTapGesture {
                                selectedVisit = visit
                                showVisitDetail = true
                            }
                    }
                }
            }
        }
        .sheet(isPresented: $showVisitDetail) {
            if let visit = selectedVisit {
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
        }
    }
}

struct TopCafesView: View {
    @ObservedObject var dataManager: DataManager
    
    var topCafes: [Cafe] {
        dataManager.appData.cafes
            .filter { $0.averageRating > 0 }
            .sorted { $0.averageRating > $1.averageRating }
            .prefix(10)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if topCafes.isEmpty {
                DSBaseCard {
                    Text("No cafés yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(topCafes) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: false,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var dataManager: DataManager
    
    var favorites: [Cafe] {
        dataManager.appData.cafes.filter { $0.isFavorite }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if favorites.isEmpty {
                DSBaseCard {
                    Text("No favorites yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(favorites) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: false,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}

struct WishlistView: View {
    @ObservedObject var dataManager: DataManager
    
    var wishlist: [Cafe] {
        dataManager.appData.cafes.filter { $0.wantToTry }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if wishlist.isEmpty {
                DSBaseCard {
                    Text("No wishlist items yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(wishlist) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: true,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}

