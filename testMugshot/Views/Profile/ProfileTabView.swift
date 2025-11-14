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
                        .fill(
                            LinearGradient(
                                colors: [Color.mugshotMint, Color.sageGray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Spacer()
                                
                                // Avatar
                                Circle()
                                    .fill(Color.creamWhite)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(user?.username.prefix(1).uppercased() ?? "U")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.espressoBrown)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.creamWhite, lineWidth: 4)
                                    )
                                    .offset(y: 40)
                            }
                        )
                    
                    VStack(spacing: 20) {
                        // User info
                        VStack(spacing: 8) {
                            Text("@\(user?.username ?? "user")")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            
                            if let location = user?.location, !location.isEmpty {
                                Text(location)
                                    .font(.system(size: 16))
                                    .foregroundColor(.espressoBrown.opacity(0.7))
                            }
                            
                            if let bio = user?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.system(size: 14))
                                    .foregroundColor(.espressoBrown.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top, 50)
                        
                        // Stats section
                        VStack(spacing: 16) {
                            Text("Stats")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            
                            HStack(spacing: 20) {
                                StatBox(
                                    title: "Visits",
                                    value: "\(stats.totalVisits)"
                                )
                                
                                StatBox(
                                    title: "Cafés",
                                    value: "\(stats.totalCafes)"
                                )
                                
                                StatBox(
                                    title: "Avg Score",
                                    value: String(format: "%.1f", stats.averageScore)
                                )
                                
                                StatBox(
                                    title: "Favorite",
                                    value: stats.favoriteDrinkType?.rawValue ?? "-"
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.sandBeige)
                        .cornerRadius(DesignSystem.cornerRadius)
                        .padding(.horizontal)
                        
                        // Coffee Journey
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Coffee Journey")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            
                            CoffeeJourneyView(stats: stats)
                        }
                        .padding()
                        .background(Color.sandBeige)
                        .cornerRadius(DesignSystem.cornerRadius)
                        .padding(.horizontal)
                        
                        // Content tabs
                        Picker("Content", selection: $selectedTab) {
                            ForEach(ProfileContentTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // Content based on selected tab
                        contentView
                            .padding()
                    }
                }
            }
            .background(Color.creamWhite)
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
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.espressoBrown)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.espressoBrown.opacity(0.7))
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
                        .fill(Color.mugshotMint)
                        .frame(width: 12, height: 12)
                }
                
                if stats.totalCafes > 10 {
                    Text("+\(stats.totalCafes - 10)")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
            }
            
            Text("\(stats.totalVisits) visits across \(stats.totalCafes) cafés")
                .font(.system(size: 14))
                .foregroundColor(.espressoBrown.opacity(0.7))
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
        VStack(alignment: .leading, spacing: 12) {
            if visits.isEmpty {
                Text("No visits yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
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
        VStack(alignment: .leading, spacing: 12) {
            if topCafes.isEmpty {
                Text("No cafés yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
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
        VStack(alignment: .leading, spacing: 12) {
            if favorites.isEmpty {
                Text("No favorites yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
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
        VStack(alignment: .leading, spacing: 12) {
            if wishlist.isEmpty {
                Text("No wishlist items yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
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

