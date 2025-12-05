//
//  CafeDetailView.swift
//  testMugshot
//
//  ⚠️ DEPRECATED: This view has been superseded by UnifiedCafeView.swift
//  located at Views/Cafe/UnifiedCafeView.swift
//
//  UnifiedCafeView provides a unified café experience with:
//  - Preview state (medium detent) for quick info over the map
//  - Full state (expanded) for complete café profile
//  - Consistent experience from Map, Feed, Saved, and all other entry points
//
//  This file is kept for reference but should not be used for new development.
//  All usages have been migrated to UnifiedCafeView.
//
//  Original description:
//  Cafe Profile - the main view when a user taps a cafe anywhere in the app.
//  Flagship experience: social, visual, data-rich.
//
//  REVAMPED: Photo-first hero, social proof, sticky CTA

import SwiftUI
import MapKit

@available(*, deprecated, message: "Use UnifiedCafeView instead for the unified café experience")
struct CafeDetailView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    
    // State
    @State private var showLogVisit = false
    @State private var selectedVisit: Visit?
    @State private var currentPhotoIndex: Int = 0
    @State private var selectedPhotoIndex: Int?
    @State private var showPhotoGallery = false
    @State private var showAllVisits = false
    
    // App-wide aggregate stats
    @State private var aggregateStats: CafeAggregateStats?
    @State private var isLoadingStats = true
    
    init(cafe: Cafe, dataManager: DataManager) {
        self.cafe = cafe
        self.dataManager = dataManager
    }
    
    // MARK: - Computed Data
    
    private var allVisits: [Visit] {
        dataManager.getVisitsForCafe(cafe.id).sorted { $0.createdAt > $1.createdAt }
    }
    
    private var userVisits: [Visit] {
        allVisits.filter { $0.userId == dataManager.appData.currentUser?.id }
    }
    
    private var userAverageRating: Double {
        guard !userVisits.isEmpty else { return 0 }
        return userVisits.reduce(0.0) { $0 + $1.overallScore } / Double(userVisits.count)
    }
    
    private var lastVisitDate: Date? {
        userVisits.first?.createdAt
    }
    
    private var friendVisits: [Visit] {
        allVisits.filter { $0.userId != dataManager.appData.currentUser?.id }
    }
    
    private var uniqueFriendVisitors: [Visit] {
        var seen = Set<String>()
        return friendVisits.filter { visit in
            guard let id = visit.supabaseUserId else { return false }
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
    }
    
    private var allPhotos: [(visit: Visit, photoPath: String)] {
        allVisits.filter { !$0.photos.isEmpty }.flatMap { visit in
            visit.photos.map { (visit: visit, photoPath: $0) }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // ZONE 1: Hero Photo + Identity
                        heroSection
                        
                        // ZONE 2: Action Bar
                        actionBar
                            .padding(.top, DS.Spacing.lg)
                        
                        // ZONE 3 & 4: Content Sections
                        VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                            socialProofCard
                            photoGridSection
                            popularDrinksSection
                            recentActivitySection
                            
                            // Footer
                            Text("Café data powered by Mugshot visits")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, DS.Spacing.lg)
                        }
                        .padding(.top, DS.Spacing.sectionVerticalGap)
                        
                        // Bottom padding for sticky CTA
                        Color.clear.frame(height: 100)
                    }
                }
                .background(DS.Colors.screenBackground)
                
                // STICKY: Log a Visit CTA
                stickyLogVisitButton
            }
            .navigationTitle(cafe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
            .sheet(isPresented: $showLogVisit) {
                LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
            }
            .sheet(isPresented: $showPhotoGallery) {
                PhotoGallerySheet(
                    photos: allPhotos,
                    initialIndex: selectedPhotoIndex ?? 0
                )
            }
            .sheet(isPresented: $showAllVisits) {
                AllVisitsSheet(visits: allVisits, onVisitTap: { visit in
                    showAllVisits = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedVisit = visit
                    }
                })
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .task {
                await fetchAggregateStats()
            }
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchAggregateStats() async {
        isLoadingStats = true
        aggregateStats = await dataManager.getCafeAggregateStats(for: cafe.supabaseId ?? cafe.id)
        isLoadingStats = false
    }
    
    // MARK: - ZONE 1: Hero Photo + Identity
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Photo Carousel Hero
            ZStack(alignment: .bottom) {
                if allPhotos.isEmpty {
                    // Mugshot-styled map fallback with cafe pin
                    if let location = cafe.location {
                        CafeHeroMapView(
                            coordinate: location,
                            cafeName: cafe.name
                        )
                        .frame(height: 280)
                        .allowsHitTesting(false)
                    } else {
                        // No location fallback - mint gradient
                        LinearGradient(
                            colors: [DS.Colors.mintLight, DS.Colors.mintMain, DS.Colors.mintDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 280)
                        .overlay(
                            VStack(spacing: DS.Spacing.md) {
                                Image(systemName: "mappin.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Location unavailable")
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        )
                    }
                } else {
                    // Photo carousel
                    TabView(selection: $currentPhotoIndex) {
                        ForEach(Array(allPhotos.prefix(6).enumerated()), id: \.offset) { index, photoData in
                            PhotoImageView(
                                photoPath: photoData.photoPath,
                                remoteURL: photoData.visit.remoteURL(for: photoData.photoPath)
                            )
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 280)
                            .clipped()
                            .tag(index)
                            .onTapGesture {
                                selectedPhotoIndex = index
                                showPhotoGallery = true
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 280)
                }
                
                // Gradient overlay for text readability
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.3)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .allowsHitTesting(false)
            }
            
            // Cafe Identity
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(cafe.name)
                    .font(DS.Typography.title1())
                    .foregroundColor(DS.Colors.textPrimary)
                
                // Address (tappable)
                if !cafe.address.isEmpty {
                    Button {
                        openInMaps()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "mappin")
                                .font(.system(size: 12))
                            Text(cafe.address)
                                .font(DS.Typography.caption1())
                        }
                        .foregroundColor(DS.Colors.textSecondary)
                    }
                }
                
                // Key Stats Row (App-Wide Data)
                HStack(spacing: DS.Spacing.md) {
                    // Rating (app-wide)
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DS.Colors.yellowAccent)
                        
                        if isLoadingStats {
                            Text("—")
                                .font(DS.Typography.subheadline(.semibold))
                                .foregroundColor(DS.Colors.textTertiary)
                        } else {
                            Text(String(format: "%.1f", aggregateStats?.averageRating ?? cafe.averageRating))
                                .font(DS.Typography.subheadline(.semibold))
                                .foregroundColor(DS.Colors.textPrimary)
                        }
                    }
                    
                    Text("•")
                        .foregroundColor(DS.Colors.textTertiary)
                    
                    // Visit count (app-wide)
                    if isLoadingStats {
                        Text("— visits")
                            .font(DS.Typography.subheadline())
                            .foregroundColor(DS.Colors.textTertiary)
                    } else {
                        Text("\(aggregateStats?.totalVisits ?? allVisits.count) visits")
                            .font(DS.Typography.subheadline())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    if !uniqueFriendVisitors.isEmpty {
                        Text("•")
                            .foregroundColor(DS.Colors.textTertiary)
                        
                        // Friend count
                        Text("\(uniqueFriendVisitors.count) friends")
                            .font(DS.Typography.subheadline())
                            .foregroundColor(DS.Colors.primaryAccent)
                    }
                }
                .padding(.top, DS.Spacing.xs)
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    // MARK: - ZONE 2: Action Bar
    
    private var actionBar: some View {
        HStack(spacing: DS.Spacing.md) {
            // Favorite Button
            ActionBarButton(
                icon: cafe.isFavorite ? "heart.fill" : "heart",
                label: "Favorite",
                isActive: cafe.isFavorite,
                activeColor: DS.Colors.redAccent
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    dataManager.toggleCafeFavorite(cafe.id)
                }
            }
            
            // Save Button
            ActionBarButton(
                icon: cafe.wantToTry ? "bookmark.fill" : "bookmark",
                label: "Save",
                isActive: cafe.wantToTry,
                activeColor: DS.Colors.yellowAccent
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    dataManager.toggleCafeWantToTry(cafe: cafe)
                }
            }
            
            // Get There Button
            if cafe.location != nil {
                ActionBarButton(
                    icon: "arrow.triangle.turn.up.right.diamond.fill",
                    label: "Get There",
                    isActive: false,
                    activeColor: DS.Colors.secondaryAccent
                ) {
                    openInMaps()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .dsCardShadow()
    }
    
    // MARK: - ZONE 3: Social Proof Card
    
    private var socialProofCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Friends Who've Been Section
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Friends Who've Been")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                if uniqueFriendVisitors.isEmpty {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "person.2")
                            .font(.system(size: 24))
                            .foregroundColor(DS.Colors.iconSubtle)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("None of your friends have visited yet")
                                .font(DS.Typography.subheadline())
                                .foregroundColor(DS.Colors.textSecondary)
                            Text("Be the pioneer! ☕️")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                    }
                } else {
                    // Overlapping Avatar Stack
                    HStack(spacing: -12) {
                        ForEach(Array(uniqueFriendVisitors.prefix(4).enumerated()), id: \.element.id) { index, visit in
                            FriendAvatarCircle(visit: visit) {
                                if let userId = visit.supabaseUserId {
                                    profileNavigator.openProfile(
                                        handle: .supabase(
                                            id: userId,
                                            username: visit.authorUsername
                                        ),
                                        source: .savedCafeVisitors,
                                        triggerHaptic: false
                                    )
                                } else if let username = visit.authorUsername {
                                    profileNavigator.openProfile(
                                        handle: .mention(username: username),
                                        source: .savedCafeVisitors,
                                        triggerHaptic: false
                                    )
                                }
                            }
                            .zIndex(Double(4 - index))
                        }
                        
                        if uniqueFriendVisitors.count > 4 {
                            Circle()
                                .fill(DS.Colors.mintSoftFill)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Text("+\(uniqueFriendVisitors.count - 4)")
                                        .font(DS.Typography.caption1(.semibold))
                                        .foregroundColor(DS.Colors.primaryAccent)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(DS.Colors.cardBackground, lineWidth: 3)
                                )
                        }
                    }
                    
                    // Friend names
                    Text(friendNamesList)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            // Divider
            Rectangle()
                .fill(DS.Colors.dividerSubtle)
                .frame(height: 1)
            
            // Your Journey Section
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Your Journey")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                HStack(spacing: DS.Spacing.md) {
                    // Your Visits
                    JourneyStatTile(
                        value: "\(userVisits.count)",
                        label: "visits",
                        isEmpty: userVisits.isEmpty
                    )
                    
                    // Your Average
                    JourneyStatTile(
                        value: userVisits.isEmpty ? "—" : String(format: "%.1f", userAverageRating),
                        label: "your avg",
                        isEmpty: userVisits.isEmpty
                    )
                    
                    // Last Visit
                    JourneyStatTile(
                        value: lastVisitDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "Never",
                        label: "last visit",
                        isEmpty: lastVisitDate == nil
                    )
                }
            }
        }
        .padding(DS.Spacing.cardPadding)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.card)
        .dsCardShadow()
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var friendNamesList: String {
        let names = uniqueFriendVisitors.prefix(3).compactMap { visit -> String? in
            visit.authorDisplayNameOrUsername.split(separator: " ").first.map(String.init)
        }
        
        if names.isEmpty { return "" }
        if uniqueFriendVisitors.count <= 3 {
            return names.joined(separator: ", ")
        }
        return names.joined(separator: ", ") + " and \(uniqueFriendVisitors.count - 3) more"
    }
    
    // MARK: - ZONE 4A: Photo Grid
    
    private var photoGridSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Photos")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                if allPhotos.count > 4 {
                    Button {
                        selectedPhotoIndex = 0
                        showPhotoGallery = true
                    } label: {
                        Text("See All")
                            .font(DS.Typography.subheadline(.medium))
                            .foregroundColor(DS.Colors.secondaryAccent)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            if allPhotos.isEmpty {
                // Empty state card
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    Text("Add the first photo!")
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                // 2x2 Photo Grid
                let gridPhotos = Array(allPhotos.prefix(4))
                let columns = [
                    GridItem(.flexible(), spacing: DS.Spacing.sm),
                    GridItem(.flexible(), spacing: DS.Spacing.sm)
                ]
                
                LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                    ForEach(Array(gridPhotos.enumerated()), id: \.offset) { index, photoData in
                        ZStack(alignment: .bottomTrailing) {
                            Button {
                                selectedPhotoIndex = index
                                showPhotoGallery = true
                            } label: {
                                PhotoImageView(
                                    photoPath: photoData.photoPath,
                                    remoteURL: photoData.visit.remoteURL(for: photoData.photoPath)
                                )
                                .aspectRatio(1, contentMode: .fill)
                                .frame(minHeight: 160)
                                .clipped()
                                .cornerRadius(DS.Radius.md)
                            }
                            
                            // Show +N on last photo if there are more
                            if index == 3 && allPhotos.count > 4 {
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .fill(Color.black.opacity(0.5))
                                    .overlay(
                                        Text("+\(allPhotos.count - 4)")
                                            .font(DS.Typography.title2())
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    // MARK: - ZONE 4B: Popular Drinks (App-Wide Top 5)
    
    private var popularDrinksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("What People Order")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                // Badge showing app-wide data
                if !isLoadingStats && aggregateStats != nil {
                    Text("App-wide")
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(DS.Colors.mintSoftFill)
                        .cornerRadius(DS.Radius.pill)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            if isLoadingStats {
                // Loading state
                VStack(spacing: DS.Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: DS.Spacing.md) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DS.Colors.mintSoftFill)
                                .frame(width: 32, height: 24)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DS.Colors.neutralCardAlt)
                                .frame(height: 16)
                            
                            Spacer()
                        }
                    }
                }
                .padding(DS.Spacing.cardPadding)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            } else if let stats = aggregateStats, !stats.topDrinks.isEmpty {
                // Show top 5 drinks from app-wide data
                VStack(spacing: DS.Spacing.md) {
                    ForEach(stats.topDrinks.prefix(5)) { drink in
                        DrinkPopularityRow(
                            emoji: drinkEmojiForName(drink.name),
                            name: drink.name,
                            percentage: drink.percentage
                        )
                    }
                }
                .padding(DS.Spacing.cardPadding)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                // Empty state
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 24))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    Text("No orders logged yet. What will you try?")
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    /// Maps drink name to emoji - handles both standard drink types and custom names
    private func drinkEmojiForName(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        // Standard drink types
        if lowercased == "coffee" || lowercased.contains("espresso") || lowercased.contains("americano") {
            return "☕️"
        } else if lowercased == "matcha" || lowercased.contains("matcha") {
            return "🍵"
        } else if lowercased == "hojicha" || lowercased.contains("hojicha") {
            return "🍂"
        } else if lowercased == "tea" || lowercased.contains("tea") {
            return "🫖"
        } else if lowercased == "chai" || lowercased.contains("chai") {
            return "🔥"
        } else if lowercased == "hot chocolate" || lowercased.contains("chocolate") || lowercased.contains("mocha") {
            return "🍫"
        }
        
        // Common custom drink patterns
        if lowercased.contains("latte") || lowercased.contains("cappuccino") || lowercased.contains("cortado") {
            return "☕️"
        } else if lowercased.contains("cold brew") || lowercased.contains("iced") {
            return "🧊"
        } else if lowercased.contains("smoothie") || lowercased.contains("frappe") {
            return "🥤"
        }
        
        // Default
        return "☕️"
    }
    
    // MARK: - ZONE 4C: Recent Activity
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                if allVisits.count > 3 {
                    Button {
                        showAllVisits = true
                    } label: {
                        Text("See All")
                            .font(DS.Typography.subheadline(.medium))
                            .foregroundColor(DS.Colors.secondaryAccent)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            if allVisits.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 36))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    VStack(spacing: DS.Spacing.xs) {
                        Text("This cafe is waiting for its first review!")
                            .font(DS.Typography.subheadline())
                            .foregroundColor(DS.Colors.textSecondary)
                        Text("Be the first to share your experience")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allVisits.prefix(3).enumerated()), id: \.element.id) { index, visit in
                        Button {
                            selectedVisit = visit
                        } label: {
                            ActivityRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                        
                        if index < min(2, allVisits.count - 1) {
                            Divider()
                                .padding(.leading, 70)
                        }
                    }
                }
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    // MARK: - Sticky CTA
    
    private var stickyLogVisitButton: some View {
        VStack(spacing: 0) {
            // Shadow line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 8)
            
            VStack {
                Button {
                    showLogVisit = true
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 18))
                        Text("Log a Visit")
                            .font(DS.Typography.buttonLabel)
                    }
                    .foregroundColor(DS.Colors.textOnMint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.primaryButton)
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.cardBackground)
        }
    }
    
    // MARK: - Helpers
    
    private func openInMaps() {
        guard let location = cafe.location else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location))
        mapItem.name = cafe.name
        mapItem.openInMaps()
    }
}

// MARK: - Supporting Components

private struct ActionBarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isActive ? activeColor : DS.Colors.iconDefault)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                
                Text(label)
                    .font(DS.Typography.caption1())
                    .foregroundColor(isActive ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
    }
}

private struct FriendAvatarCircle: View {
    let visit: Visit
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Group {
                if let avatarURL = visit.authorAvatarURL,
                   let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(DS.Colors.cardBackground, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.mintSoftFill)
            .overlay(
                Text(visit.authorInitials)
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.primaryAccent)
            )
    }
}

private struct JourneyStatTile: View {
    let value: String
    let label: String
    let isEmpty: Bool
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(DS.Typography.numericStat)
                .foregroundColor(isEmpty ? DS.Colors.textTertiary : DS.Colors.primaryAccent)
            
            Text(label)
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textSecondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.mintSoftFill.opacity(isEmpty ? 0.5 : 1))
        .cornerRadius(DS.Radius.md)
    }
}

private struct DrinkPopularityRow: View {
    let emoji: String
    let name: String
    let percentage: Double
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 32)
            
            Text(name)
                .font(DS.Typography.headline())
                .foregroundColor(DS.Colors.textPrimary)
            
            Spacer()
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.Colors.mintSoftFill)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.Colors.primaryAccent)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 8)
                }
            }
            .frame(width: 80, height: 8)
            
            Text("\(Int(percentage))%")
                .font(DS.Typography.caption1(.semibold))
                .foregroundColor(DS.Colors.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

private struct ActivityRow: View {
    let visit: Visit
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Thumbnail
            if let photoPath = visit.posterImagePath {
                PhotoThumbnailView(
                    photoPath: photoPath,
                    remoteURL: visit.remoteURL(for: photoPath),
                    size: 54
                )
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(DS.Colors.mintSoftFill)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "cup.and.saucer")
                            .foregroundColor(DS.Colors.primaryAccent)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(visit.authorDisplayNameOrUsername)
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Spacer()
                    
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.yellowAccent)
                        Text(String(format: "%.1f", visit.overallScore))
                            .font(DS.Typography.subheadline(.semibold))
                            .foregroundColor(DS.Colors.textPrimary)
                    }
                }
                
                if !visit.caption.isEmpty {
                    Text("\"\(visit.caption)\"")
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(1)
                        .italic()
                }
                
                HStack(spacing: DS.Spacing.xs) {
                    Text(visit.drinkType.rawValue)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                    
                    Text("•")
                        .foregroundColor(DS.Colors.textTertiary)
                    
                    Text(visit.createdAt.formatted(.relative(presentation: .named)))
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
        }
        .padding(DS.Spacing.cardPadding)
    }
}

// MARK: - Photo Gallery Sheet

private struct PhotoGallerySheet: View {
    let photos: [(visit: Visit, photoPath: String)]
    let initialIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int
    
    init(photos: [(visit: Visit, photoPath: String)], initialIndex: Int) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                        PhotoImageView(
                            photoPath: photoData.photoPath,
                            remoteURL: photoData.visit.remoteURL(for: photoData.photoPath)
                        )
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationTitle("\(currentIndex + 1) of \(photos.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - All Visits Sheet

private struct AllVisitsSheet: View {
    let visits: [Visit]
    let onVisitTap: (Visit) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(visits.enumerated()), id: \.element.id) { index, visit in
                        Button {
                            onVisitTap(visit)
                        } label: {
                            ActivityRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                        
                        if index < visits.count - 1 {
                            Divider()
                                .padding(.leading, 70)
                        }
                    }
                }
                .background(DS.Colors.cardBackground)
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("All Visits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
        }
    }
}

// MARK: - Cafe Hero Map View (Mugshot-styled static map)

private struct CafeHeroMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let cafeName: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Mugshot map styling - clean, no distractions
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.showsUserLocation = false
        
        // Set region centered on cafe
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
        mapView.setRegion(region, animated: false)
        
        // Add cafe annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = cafeName
        mapView.addAnnotation(annotation)
        
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Static view, no updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "CafeHeroPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            // Mugshot mint colored pin
            annotationView?.markerTintColor = UIColor(red: 183/255, green: 226/255, blue: 181/255, alpha: 1.0) // mintMain
            annotationView?.glyphImage = UIImage(systemName: "cup.and.saucer.fill")
            annotationView?.glyphTintColor = UIColor(red: 5/255, green: 46/255, blue: 22/255, alpha: 1.0) // textOnMint
            annotationView?.displayPriority = .required
            annotationView?.canShowCallout = false
            
            return annotationView
        }
    }
}
