//
//  UnifiedCafeView.swift
//  testMugshot
//
//  Unified Café Experience - combines preview and full profile states
//  into a single, Apple Maps-quality bottom sheet experience.
//
//  Can be presented as:
//  - Bottom sheet over map (preview → full with drag)
//  - Full-screen from Feed/Saved (full state only)
//

import SwiftUI
import MapKit

// MARK: - Presentation Mode

enum CafePresentationMode {
    case mapSheet      // Bottom sheet over map (supports preview → full)
    case fullScreen    // Full-screen presentation (no map visible)
}

// MARK: - Unified Cafe View

struct UnifiedCafeView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let presentationMode: CafePresentationMode
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @StateObject private var hapticsManager = HapticsManager.shared
    
    // Sheet state
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var isExpanded: Bool = false
    
    // Navigation state
    @State private var showLogVisit = false
    @State private var selectedVisit: Visit?
    @State private var selectedPhotoIndex: Int?
    @State private var showPhotoGallery = false
    @State private var showAllVisits = false
    @State private var currentPhotoIndex: Int = 0
    
    // App-wide aggregate stats
    @State private var aggregateStats: CafeAggregateStats?
    @State private var isLoadingStats = true
    
    // MARK: - Computed Properties
    
    private var currentCafe: Cafe {
        dataManager.getCafe(id: cafe.id) ?? cafe
    }
    
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
    
    /// Get friends who have visited this cafe with their ratings (for preview)
    private func getFriendVisitors() -> [CafePreviewFriendsRow.FriendVisitor] {
        let friendIds = dataManager.appData.friendsSupabaseUserIds
        guard !friendIds.isEmpty else { return [] }
        
        let cafeVisits = dataManager.appData.visits.filter { $0.cafeId == cafe.id }
        
        var seenIds = Set<String>()
        var visitors: [CafePreviewFriendsRow.FriendVisitor] = []
        
        for visit in cafeVisits {
            guard let visitorId = visit.supabaseUserId,
                  friendIds.contains(visitorId),
                  !seenIds.contains(visitorId) else { continue }
            
            seenIds.insert(visitorId)
            
            visitors.append(CafePreviewFriendsRow.FriendVisitor(
                id: visitorId,
                displayName: visit.authorDisplayNameOrUsername,
                avatarURL: visit.authorAvatarURL,
                rating: visit.overallScore
            ))
        }
        
        return visitors.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            switch presentationMode {
            case .mapSheet:
                mapSheetContent
            case .fullScreen:
                fullScreenContent
            }
        }
        .task {
            await fetchAggregateStats()
        }
    }
    
    // MARK: - Map Sheet Presentation (Preview → Full)
    
    private var mapSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if isExpanded {
                        fullProfileContent
                    } else {
                        previewContent
                    }
                }
            }
            .background(DS.Colors.screenBackground)
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        hapticsManager.lightTap()
                        onDismiss?()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DS.Colors.iconSubtle)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationCornerRadius(DS.Radius.xxl)
        .onChange(of: sheetDetent) { _, newDetent in
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = (newDetent == .large)
            }
            if newDetent == .large {
                hapticsManager.lightTap()
            }
        }
        .onTapGesture {
            // Tapping on preview expands to full
            if !isExpanded {
                hapticsManager.lightTap()
                sheetDetent = .large
            }
        }
        .sheet(isPresented: $showLogVisit) {
            LogVisitView(dataManager: dataManager, preselectedCafe: currentCafe)
        }
        .sheet(isPresented: $showPhotoGallery) {
            CafePhotoGallerySheet(
                photos: allPhotos,
                initialIndex: selectedPhotoIndex ?? 0
            )
        }
        .sheet(isPresented: $showAllVisits) {
            CafeAllVisitsSheet(visits: allVisits, onVisitTap: { visit in
                showAllVisits = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedVisit = visit
                }
            })
        }
        .navigationDestination(item: $selectedVisit) { visit in
            VisitDetailView(dataManager: dataManager, visit: visit)
        }
    }
    
    // MARK: - Full Screen Presentation (From Feed/Saved)
    
    private var fullScreenContent: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        fullProfileContent
                        
                        // Bottom padding for sticky CTA
                        Color.clear.frame(height: 100)
                    }
                }
                .background(DS.Colors.screenBackground)
                
                // Sticky Log a Visit button
                stickyLogVisitButton
            }
            .navigationTitle(currentCafe.name)
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
                LogVisitView(dataManager: dataManager, preselectedCafe: currentCafe)
            }
            .sheet(isPresented: $showPhotoGallery) {
                CafePhotoGallerySheet(
                    photos: allPhotos,
                    initialIndex: selectedPhotoIndex ?? 0
                )
            }
            .sheet(isPresented: $showAllVisits) {
                CafeAllVisitsSheet(visits: allVisits, onVisitTap: { visit in
                    showAllVisits = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedVisit = visit
                    }
                })
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchAggregateStats() async {
        isLoadingStats = true
        aggregateStats = await dataManager.getCafeAggregateStats(for: cafe.supabaseId ?? cafe.id)
        isLoadingStats = false
    }
}

// MARK: - Preview Content (Medium Detent)

extension UnifiedCafeView {
    
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header: Name, city/address, distance
            previewHeader
            
            // Primary stats row
            previewStatsRow
            
            // Primary CTAs
            previewCTAs
            
            // Mini friends section
            previewFriendsSection
            
            // "View café details" hint
            viewDetailsHint
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xxl)
    }
    
    private var previewHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Café name
                Text(currentCafe.name)
                    .font(DS.Typography.title2())
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(2)
                
                // City or short address
                if let city = currentCafe.city, !city.isEmpty {
                    Text(city)
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                } else if !currentCafe.address.isEmpty {
                    Text(shortAddress(currentCafe.address))
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Distance (if available) - placeholder for now
            // TODO: Add distance calculation if user location is available
        }
    }
    
    private var previewStatsRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Rating
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.primaryAccent)
                
                if isLoadingStats {
                    Text("—")
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textTertiary)
                } else {
                    Text(String(format: "%.1f", aggregateStats?.averageRating ?? currentCafe.averageRating))
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textPrimary)
                }
            }
            
            Text("·")
                .foregroundColor(DS.Colors.textTertiary)
            
            // Visits
            if isLoadingStats {
                Text("— visits")
                    .font(DS.Typography.subheadline())
                    .foregroundColor(DS.Colors.textTertiary)
            } else {
                Text("\(aggregateStats?.totalVisits ?? currentCafe.visitCount) visits")
                    .font(DS.Typography.subheadline())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            // "You've been" pill if user has visited
            if !userVisits.isEmpty {
                Text("You've been")
                    .font(DS.Typography.caption1(.medium))
                    .foregroundColor(DS.Colors.textOnMint)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.pill)
            }
            
            Spacer()
        }
    }
    
    private var previewCTAs: some View {
        VStack(spacing: DS.Spacing.md) {
            // Primary: Log a Visit
            Button {
                hapticsManager.lightTap()
                if let onLogVisit = onLogVisitRequested {
                    onLogVisit(currentCafe)
                } else {
                    showLogVisit = true
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 16))
                    Text("Log a Visit")
                        .font(DS.Typography.buttonLabel)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSPrimaryButtonStyle())
            
            // Secondary row: Favorite + Want to Try
            HStack(spacing: DS.Spacing.md) {
                // Favorite
                Button {
                    hapticsManager.lightTap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        dataManager.toggleCafeFavorite(cafe: currentCafe)
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: currentCafe.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                        Text("Favorite")
                            .font(DS.Typography.subheadline(.medium))
                    }
                    .foregroundColor(currentCafe.isFavorite ? DS.Colors.redAccent : DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.primaryButton)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.primaryButton)
                            .stroke(currentCafe.isFavorite ? DS.Colors.redAccent.opacity(0.4) : DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Want to Try
                Button {
                    hapticsManager.lightTap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        dataManager.toggleCafeWantToTry(cafe: currentCafe)
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: currentCafe.wantToTry ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 16))
                        Text("Want to Try")
                            .font(DS.Typography.subheadline(.medium))
                    }
                    .foregroundColor(currentCafe.wantToTry ? DS.Colors.primaryAccent : DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.primaryButton)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.primaryButton)
                            .stroke(currentCafe.wantToTry ? DS.Colors.primaryAccent.opacity(0.4) : DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var previewFriendsSection: some View {
        CafePreviewFriendsRow(friendVisitors: getFriendVisitors())
    }
    
    private var viewDetailsHint: some View {
        HStack {
            Spacer()
            
            HStack(spacing: DS.Spacing.xs) {
                Text("View café details")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textTertiary)
                
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            
            Spacer()
        }
        .padding(.top, DS.Spacing.sm)
    }
    
    private func shortAddress(_ address: String) -> String {
        let firstLine = address.components(separatedBy: ",").first ?? address
        if firstLine.count > 35 {
            return String(firstLine.prefix(32)) + "..."
        }
        return firstLine
    }
}

// MARK: - Full Profile Content (Large Detent / Full Screen)

extension UnifiedCafeView {
    
    private var fullProfileContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Photo + Identity
            heroSection
            
            // Action Bar
            actionBar
                .padding(.top, DS.Spacing.lg)
            
            // Content Sections
            VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                // Core Stats
                coreStatsSection
                
                // Social Proof: Friends Who've Been + Your Journey
                socialProofCard
                
                // Photos
                photoGridSection
                
                // What People Order
                popularDrinksSection
                
                // Recent Activity
                recentActivitySection
                
                // Footer
                Text("Café data powered by Mugshot visits")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.Spacing.lg)
            }
            .padding(.top, DS.Spacing.sectionVerticalGap)
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Photo Carousel Hero
            ZStack(alignment: .bottom) {
                if allPhotos.isEmpty {
                    // Map fallback or placeholder
                    if let location = currentCafe.location {
                        CafeHeroMapPlaceholder(
                            coordinate: location,
                            cafeName: currentCafe.name
                        )
                        .frame(height: 240)
                        .allowsHitTesting(false)
                    } else {
                        // Mint gradient placeholder
                        LinearGradient(
                            colors: [DS.Colors.mintLight, DS.Colors.mintMain, DS.Colors.mintDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 240)
                        .overlay(
                            VStack(spacing: DS.Spacing.md) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("No photos yet — be the first!")
                                    .font(DS.Typography.subheadline())
                                    .foregroundColor(.white.opacity(0.8))
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
                            .frame(height: 240)
                            .clipped()
                            .tag(index)
                            .onTapGesture {
                                selectedPhotoIndex = index
                                showPhotoGallery = true
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 240)
                }
                
                // Gradient overlay
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.2)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 80)
                .allowsHitTesting(false)
            }
            
            // Café Identity
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(currentCafe.name)
                    .font(DS.Typography.title1())
                    .foregroundColor(DS.Colors.textPrimary)
                
                // Tappable address
                if !currentCafe.address.isEmpty {
                    Button {
                        openInMaps()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "mappin")
                                .font(.system(size: 12))
                            Text(currentCafe.address)
                                .font(DS.Typography.caption1())
                        }
                        .foregroundColor(DS.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: DS.Spacing.md) {
            // Favorite
            CafeActionBarButton(
                icon: currentCafe.isFavorite ? "heart.fill" : "heart",
                label: "Favorite",
                isActive: currentCafe.isFavorite,
                activeColor: DS.Colors.redAccent
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    dataManager.toggleCafeFavorite(cafe: currentCafe)
                }
            }
            
            // Save / Bookmark
            CafeActionBarButton(
                icon: currentCafe.wantToTry ? "bookmark.fill" : "bookmark",
                label: "Save",
                isActive: currentCafe.wantToTry,
                activeColor: DS.Colors.primaryAccent
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    dataManager.toggleCafeWantToTry(cafe: currentCafe)
                }
            }
            
            // Get There
            if currentCafe.location != nil {
                CafeActionBarButton(
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
    
    // MARK: - Core Stats Section (3-card row)
    
    private var coreStatsSection: some View {
        HStack(spacing: DS.Spacing.md) {
            // Global visits
            CafeStatTile(
                value: isLoadingStats ? "—" : "\(aggregateStats?.totalVisits ?? currentCafe.visitCount)",
                label: "visits",
                isEmpty: (aggregateStats?.totalVisits ?? currentCafe.visitCount) == 0
            )
            
            // Global average rating
            CafeStatTile(
                value: isLoadingStats ? "—" : String(format: "★ %.1f", aggregateStats?.averageRating ?? currentCafe.averageRating),
                label: "avg rating",
                isEmpty: (aggregateStats?.averageRating ?? currentCafe.averageRating) == 0
            )
            
            // User's last visit
            CafeStatTile(
                value: lastVisitDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "—",
                label: userVisits.isEmpty ? "not visited" : "last visit",
                isEmpty: userVisits.isEmpty
            )
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Social Proof Card
    
    private var socialProofCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Friends Who've Been
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
                            CafeFriendAvatarCircle(visit: visit) {
                                if let userId = visit.supabaseUserId {
                                    profileNavigator.openProfile(
                                        handle: .supabase(
                                            id: userId,
                                            username: visit.authorUsername
                                        ),
                                        source: .cafeVisitors,
                                        triggerHaptic: false
                                    )
                                } else if let username = visit.authorUsername {
                                    profileNavigator.openProfile(
                                        handle: .mention(username: username),
                                        source: .cafeVisitors,
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
            
            // Your Journey
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Your Journey")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                HStack(spacing: DS.Spacing.md) {
                    CafeJourneyStatTile(
                        value: "\(userVisits.count)",
                        label: "visits",
                        isEmpty: userVisits.isEmpty
                    )
                    
                    CafeJourneyStatTile(
                        value: userVisits.isEmpty ? "—" : String(format: "%.1f", userAverageRating),
                        label: "your avg",
                        isEmpty: userVisits.isEmpty
                    )
                    
                    CafeJourneyStatTile(
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
    
    // MARK: - Photo Grid Section
    
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
                // Empty state
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    Text("Add the first photo!")
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
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
                                .frame(minHeight: 150)
                                .clipped()
                                .cornerRadius(DS.Radius.md)
                            }
                            
                            // +N overlay on last photo
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
    
    // MARK: - Popular Drinks Section
    
    private var popularDrinksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("What People Order")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
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
                VStack(spacing: DS.Spacing.md) {
                    ForEach(stats.topDrinks.prefix(5)) { drink in
                        CafeDrinkPopularityRow(
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
    
    private func drinkEmojiForName(_ name: String) -> String {
        let lowercased = name.lowercased()
        
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
        } else if lowercased.contains("latte") || lowercased.contains("cappuccino") || lowercased.contains("cortado") {
            return "☕️"
        } else if lowercased.contains("cold brew") || lowercased.contains("iced") {
            return "🧊"
        } else if lowercased.contains("smoothie") || lowercased.contains("frappe") {
            return "🥤"
        }
        
        return "☕️"
    }
    
    // MARK: - Recent Activity Section
    
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
                        Text("This café is waiting for its first review!")
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
                            CafeActivityRow(visit: visit)
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
        guard let location = currentCafe.location else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location))
        mapItem.name = currentCafe.name
        mapItem.openInMaps()
    }
}

// MARK: - Supporting Components

/// Preview Friends Row (compact for preview state)
struct CafePreviewFriendsRow: View {
    let friendVisitors: [FriendVisitor]
    
    struct FriendVisitor: Identifiable {
        let id: String
        let displayName: String
        let avatarURL: String?
        let rating: Double?
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if friendVisitors.isEmpty {
                // Empty state
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "person.2")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.primaryAccent)
                    
                    Text("Be the first of your Sip Squad ☕️")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.mintSoftFill)
                .cornerRadius(DS.Radius.md)
            } else {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Friends who've been")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    Spacer()
                }
                
                HStack(spacing: -8) {
                    ForEach(Array(friendVisitors.prefix(5).enumerated()), id: \.element.id) { index, friend in
                        if let urlString = friend.avatarURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                default:
                                    avatarPlaceholder(for: friend)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DS.Colors.cardBackground, lineWidth: 2))
                            .zIndex(Double(5 - index))
                        } else {
                            avatarPlaceholder(for: friend)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(DS.Colors.cardBackground, lineWidth: 2))
                                .zIndex(Double(5 - index))
                        }
                    }
                    
                    if friendVisitors.count > 5 {
                        Circle()
                            .fill(DS.Colors.mintSoftFill)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("+\(friendVisitors.count - 5)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(DS.Colors.primaryAccent)
                            )
                            .overlay(Circle().stroke(DS.Colors.cardBackground, lineWidth: 2))
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private func avatarPlaceholder(for friend: FriendVisitor) -> some View {
        Circle()
            .fill(DS.Colors.mintSoftFill)
            .overlay(
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Colors.primaryAccent)
            )
    }
}

/// Action Bar Button
private struct CafeActionBarButton: View {
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

/// Core Stat Tile (for 3-card stats row)
private struct CafeStatTile: View {
    let value: String
    let label: String
    let isEmpty: Bool
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(DS.Typography.headline(.semibold))
                .foregroundColor(isEmpty ? DS.Colors.textTertiary : DS.Colors.textPrimary)
            
            Text(label)
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.md)
        .dsCardShadow()
    }
}

/// Journey Stat Tile (for Your Journey section)
private struct CafeJourneyStatTile: View {
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

/// Friend Avatar Circle
private struct CafeFriendAvatarCircle: View {
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

/// Drink Popularity Row
private struct CafeDrinkPopularityRow: View {
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

/// Activity Row
private struct CafeActivityRow: View {
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

/// Hero Map Placeholder
private struct CafeHeroMapPlaceholder: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let cafeName: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.showsUserLocation = false
        
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
        mapView.setRegion(region, animated: false)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = cafeName
        mapView.addAnnotation(annotation)
        
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {}
    
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
            
            annotationView?.markerTintColor = UIColor(red: 183/255, green: 226/255, blue: 181/255, alpha: 1.0)
            annotationView?.glyphImage = UIImage(systemName: "cup.and.saucer.fill")
            annotationView?.glyphTintColor = UIColor(red: 5/255, green: 46/255, blue: 22/255, alpha: 1.0)
            annotationView?.displayPriority = .required
            annotationView?.canShowCallout = false
            
            return annotationView
        }
    }
}

/// Photo Gallery Sheet
struct CafePhotoGallerySheet: View {
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

/// All Visits Sheet
struct CafeAllVisitsSheet: View {
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
                            CafeActivityRow(visit: visit)
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

