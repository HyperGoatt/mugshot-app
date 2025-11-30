//
//  CafeDetailView.swift
//  testMugshot
//
//  Cafe Profile - the main view when a user taps a cafe anywhere in the app.
//  Flagship experience: social, visual, data-rich.
//

import SwiftUI
import MapKit

struct CafeDetailView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    // State
    @State private var showLogVisit = false
    @State private var selectedVisit: Visit?
    @State private var selectedUserId: String?
    @State private var whosBeenScope: WhosBeenScope = .friends
    @State private var selectedPhotoIndex: Int?
    @State private var showPhotoGallery = false
    
    enum WhosBeenScope: String, CaseIterable {
        case friends = "Friends"
        case everyone = "Everyone"
    }
    
    init(cafe: Cafe, dataManager: DataManager) {
        self.cafe = cafe
        self.dataManager = dataManager
        print("🏪 [CafeDetailView] INIT - Cafe: '\(cafe.name)' ID: \(cafe.id)")
    }
    
    // MARK: - Computed Data
    
    private var allVisits: [Visit] {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        return visits.sorted { $0.createdAt > $1.createdAt }
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
    
    private var visitsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allVisits.filter { $0.createdAt >= weekAgo }.count
    }
    
    private var visitsThisMonth: Int {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return allVisits.filter { $0.createdAt >= monthAgo }.count
    }
    
    private var friendVisits: [Visit] {
        allVisits.filter { $0.userId != dataManager.appData.currentUser?.id }
    }
    
    private var photoVisits: [Visit] {
        allVisits.filter { !$0.photos.isEmpty }
    }
    
    private var allPhotos: [(visit: Visit, photoPath: String)] {
        photoVisits.flatMap { visit in
            visit.photos.map { (visit: visit, photoPath: $0) }
        }
    }
    
    // Popular drinks calculation
    private var popularDrinks: [(drink: DrinkType, count: Int, percentage: Double)] {
        var drinkCounts: [DrinkType: Int] = [:]
        for visit in allVisits {
            drinkCounts[visit.drinkType, default: 0] += 1
        }
        let total = Double(allVisits.count)
        guard total > 0 else { return [] }
        
        return drinkCounts
            .map { (drink: $0.key, count: $0.value, percentage: Double($0.value) / total * 100) }
            .sorted { $0.count > $1.count }
            .prefix(4)
            .map { $0 }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with Map
                    headerSection
                    
                    // Content
                    VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                        quickActionsSection
                        statsSection
                        whosBeenSection
                        photosSection
                        popularDrinksSection
                        recentVisitsSection
                        
                        // Footer
                        Text("Café data powered by Mugshot visits")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.xxl * 2)
                    }
                    .padding(.top, DS.Spacing.xl)
                }
            }
            .background(DS.Colors.screenBackground)
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
            .sheet(isPresented: Binding(
                get: { selectedUserId != nil },
                set: { if !$0 { selectedUserId = nil } }
            )) {
                if let userId = selectedUserId {
                    OtherUserProfileView(dataManager: dataManager, userId: userId)
                }
            }
            .sheet(isPresented: $showPhotoGallery) {
                PhotoGalleryView(
                    photos: allPhotos,
                    initialIndex: selectedPhotoIndex ?? 0
                )
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .onAppear {
                print("🏪 [CafeDetailView] onAppear - Cafe: \(cafe.name), Visits: \(allVisits.count)")
            }
        }
    }
    
    // MARK: - Header Section with Map
    
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Map thumbnail
            if let location = cafe.location {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))) {
                    Marker(cafe.name, coordinate: location)
                        .tint(DS.Colors.primaryAccent)
                }
                .frame(height: 200)
                .allowsHitTesting(false) // Static, non-interactive
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.5)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
            } else {
                // Fallback gradient when no location
                LinearGradient(
                    colors: [DS.Colors.mintLight, DS.Colors.mintMain],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 200)
                .overlay(
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                )
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.4)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
            }
            
            // Cafe info overlay
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(cafe.name)
                    .font(DS.Typography.title1())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                if !cafe.address.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(DS.Typography.caption1())
                        Text(cafe.address)
                            .font(DS.Typography.subheadline())
                    }
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                
                // Average Rating + Visit count
                HStack(spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .foregroundColor(DS.Colors.yellowAccent)
                        Text(String(format: "%.1f", cafe.averageRating))
                            .fontWeight(.bold)
                        Text("avg")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(allVisits.count) visits")
                        .foregroundColor(.white.opacity(0.9))
                }
                .font(DS.Typography.subheadline())
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .padding(.top, DS.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.pagePadding)
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Quick Actions")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    // Favorite
                    QuickActionButton(
                        icon: cafe.isFavorite ? "heart.fill" : "heart",
                        label: "Favorite",
                        isActive: cafe.isFavorite,
                        activeColor: DS.Colors.redAccent
                    ) {
                        dataManager.toggleCafeFavorite(cafe.id)
                    }
                    
                    // Want to Try
                    QuickActionButton(
                        icon: cafe.wantToTry ? "bookmark.fill" : "bookmark",
                        label: "Want to Try",
                        isActive: cafe.wantToTry,
                        activeColor: DS.Colors.yellowAccent
                    ) {
                        dataManager.toggleCafeWantToTry(cafe: cafe)
                    }
                    
                    // Directions
                    if cafe.location != nil {
                        QuickActionButton(
                            icon: "arrow.triangle.turn.up.right.circle.fill",
                            label: "Directions",
                            isActive: false,
                            activeColor: DS.Colors.secondaryAccent
                        ) {
                            openDirections()
                        }
                    }
                    
                    // Website
                    if let url = cafe.websiteURL, !url.isEmpty {
                        QuickActionButton(
                            icon: "globe",
                            label: "Website",
                            isActive: false,
                            activeColor: DS.Colors.secondaryAccent
                        ) {
                            openWebsite()
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    private func openDirections() {
        guard let location = cafe.location else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location))
        mapItem.name = cafe.name
        mapItem.openInMaps()
    }
    
    private func openWebsite() {
        guard let urlString = cafe.websiteURL,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Insights")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Global stats row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    StatTile(value: "\(allVisits.count)", label: "Total Visits", icon: "cup.and.saucer.fill")
                    StatTile(value: "\(visitsThisWeek)", label: "This Week", icon: "calendar")
                    StatTile(value: "\(visitsThisMonth)", label: "This Month", icon: "calendar.badge.clock")
                    StatTile(value: String(format: "%.1f", cafe.averageRating), label: "Avg Rating", icon: "star.fill")
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
            
            // Your stats card
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Your Stats")
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
                
                HStack(spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(userVisits.count)")
                            .font(DS.Typography.numericStat)
                            .foregroundColor(DS.Colors.primaryAccent)
                        Text("Your Visits")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(userVisits.isEmpty ? "—" : String(format: "%.1f", userAverageRating))
                            .font(DS.Typography.numericStat)
                            .foregroundColor(DS.Colors.primaryAccent)
                        Text("Your Avg")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let lastDate = lastVisitDate {
                            Text(lastDate.formatted(.dateTime.month(.abbreviated).day()))
                                .font(DS.Typography.headline())
                                .foregroundColor(DS.Colors.primaryAccent)
                        } else {
                            Text("Never")
                                .font(DS.Typography.headline())
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                        Text("Last Visit")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(DS.Spacing.cardPadding)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.card)
            .dsCardShadow()
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    // MARK: - Who's Been Section
    
    private var whosBeenSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Who's Been?")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                // Friends/Everyone toggle
                Picker("Scope", selection: $whosBeenScope) {
                    ForEach(WhosBeenScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            let visitsToShow = whosBeenScope == .friends ? uniqueFriendVisits : uniqueAllVisits
            
            if visitsToShow.isEmpty {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "person.2.slash")
                        .font(.title2)
                        .foregroundColor(DS.Colors.iconSubtle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(whosBeenScope == .friends 
                             ? "No friends have logged a sip here yet."
                             : "No one has logged a sip here yet.")
                            .font(DS.Typography.subheadline())
                            .foregroundColor(DS.Colors.textSecondary)
                        Text("Be the first! ☕️")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }
                .padding(DS.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.lg) {
                        ForEach(visitsToShow.prefix(12)) { visit in
                            FriendAvatarBubble(visit: visit) {
                                if let userId = visit.supabaseUserId {
                                    selectedUserId = userId
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
    }
    
    private var uniqueFriendVisits: [Visit] {
        var seen = Set<String>()
        return friendVisits.filter { visit in
            guard let id = visit.supabaseUserId else { return false }
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
    }
    
    private var uniqueAllVisits: [Visit] {
        var seen = Set<String>()
        return allVisits.filter { visit in
            guard let id = visit.supabaseUserId else { return false }
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Photos")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                if !allPhotos.isEmpty {
                    Text("\(allPhotos.count) photos")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            if photoVisits.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(DS.Colors.iconSubtle)
                    Text("No photos yet")
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textSecondary)
                    Text("Be the first to post a sip from here!")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                // Photo collage grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(Array(allPhotos.prefix(8).enumerated()), id: \.offset) { index, photoData in
                            Button {
                                selectedPhotoIndex = index
                                showPhotoGallery = true
                            } label: {
                                PhotoImageView(
                                    photoPath: photoData.photoPath,
                                    remoteURL: photoData.visit.remoteURL(for: photoData.photoPath)
                                )
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 130, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
            }
        }
    }
    
    // MARK: - Popular Drinks Section
    
    private var popularDrinksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Popular Drinks")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            if popularDrinks.isEmpty {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "mug")
                        .font(.title2)
                        .foregroundColor(DS.Colors.iconSubtle)
                    Text("No drink data yet. Log a visit to start tracking!")
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(popularDrinks, id: \.drink) { item in
                        HStack(spacing: DS.Spacing.md) {
                            // Drink icon
                            Image(systemName: drinkIcon(for: item.drink))
                                .font(.system(size: 20))
                                .foregroundColor(DS.Colors.primaryAccent)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.drink.rawValue)
                                    .font(DS.Typography.headline())
                                    .foregroundColor(DS.Colors.textPrimary)
                                Text("\(item.count) orders")
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Percentage bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.Colors.mintSoftFill)
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.Colors.primaryAccent)
                                        .frame(width: geometry.size.width * CGFloat(item.percentage / 100), height: 8)
                                }
                            }
                            .frame(width: 80, height: 8)
                            
                            Text("\(Int(item.percentage))%")
                                .font(DS.Typography.caption1(.semibold))
                                .foregroundColor(DS.Colors.textSecondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.vertical, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.cardPadding)
                    }
                }
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    private func drinkIcon(for drink: DrinkType) -> String {
        switch drink {
        case .coffee: return "cup.and.saucer.fill"
        case .matcha: return "leaf.fill"
        case .hojicha: return "leaf"
        case .tea: return "cup.and.saucer"
        case .chai: return "flame"
        case .hotChocolate: return "mug.fill"
        case .other: return "wineglass"
        }
    }
    
    // MARK: - Recent Visits Section
    
    private var recentVisitsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Recent Visits")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    showLogVisit = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("Log a Visit")
                    }
                    .font(DS.Typography.subheadline(.medium))
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            if allVisits.isEmpty {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "text.bubble")
                        .font(.title2)
                        .foregroundColor(DS.Colors.iconSubtle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No visits yet")
                            .font(DS.Typography.headline())
                            .foregroundColor(DS.Colors.textSecondary)
                        Text("Be the first to share your experience!")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }
                .padding(DS.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.card)
                .dsCardShadow()
                .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allVisits.prefix(5).enumerated()), id: \.element.id) { index, visit in
                        Button {
                            selectedVisit = visit
                        } label: {
                            VisitRowView(visit: visit)
                        }
                        .buttonStyle(.plain)
                        
                        if index < min(4, allVisits.count - 1) {
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
}

// MARK: - Supporting Views

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? activeColor : DS.Colors.iconDefault)
                Text(label)
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textPrimary)
            }
            .frame(width: 80)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.md)
            .dsCardShadow()
        }
        .buttonStyle(.plain)
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(DS.Colors.primaryAccent)
            
            Text(value)
                .font(DS.Typography.title2())
                .foregroundColor(DS.Colors.textPrimary)
            
            Text(label)
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(width: 90)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.md)
        .dsCardShadow()
    }
}

private struct FriendAvatarBubble: View {
    let visit: Visit
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xs) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar
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
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                            .frame(width: 56, height: 56)
                    }
                    
                    // Rating badge
                    Text(String(format: "%.1f", visit.overallScore))
                        .font(DS.Typography.caption2(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DS.Colors.primaryAccent)
                        .cornerRadius(DS.Radius.pill)
                        .offset(x: 6, y: 6)
                }
                
                Text(visit.authorDisplayNameOrUsername.split(separator: " ").first.map(String.init) ?? "User")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textSecondary)
                    .lineLimit(1)
            }
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

private struct VisitRowView: View {
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
                Text(visit.authorDisplayNameOrUsername)
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
                
                HStack(spacing: DS.Spacing.xs) {
                    Text(visit.drinkType.rawValue)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    Text("•")
                        .foregroundColor(DS.Colors.textTertiary)
                    
                    Text(visit.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                }
                
                if !visit.caption.isEmpty {
                    Text(visit.caption)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Rating
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.yellowAccent)
                Text(String(format: "%.1f", visit.overallScore))
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
            }
        }
        .padding(DS.Spacing.cardPadding)
    }
}

// MARK: - Photo Gallery View

private struct PhotoGalleryView: View {
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
