//
//  ModernCafeDetailView.swift
//  testMugshot
//
//  Modern Cafe Detail with parallax hero, sticky action bar, and glassmorphism
//

import SwiftUI

struct ModernCafeDetailView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var scrollOffset: CGFloat = 0
    @State private var showLogVisit = false
    @State private var selectedVisit: Visit?
    @State private var selectedPhotoIndex: Int?
    @State private var showPhotoGallery = false
    
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
        let friendIds = dataManager.appData.friendsSupabaseUserIds
        return allVisits.filter { visit in
            guard let visitorId = visit.supabaseUserId else { return false }
            return friendIds.contains(visitorId)
        }
    }
    
    private var uniqueFriends: [(id: String, displayName: String, avatarURL: String?, rating: Double)] {
        var seen = Set<String>()
        var friends: [(id: String, displayName: String, avatarURL: String?, rating: Double)] = []
        
        for visit in friendVisits {
            guard let id = visit.supabaseUserId,
                  !seen.contains(id) else { continue }
            
            seen.insert(id)
            friends.append((
                id: id,
                displayName: visit.authorDisplayNameOrUsername,
                avatarURL: visit.authorAvatarURL,
                rating: visit.overallScore
            ))
        }
        
        return friends.sorted { $0.rating > $1.rating }
    }
    
    private var allPhotos: [(visit: Visit, photoPath: String)] {
        allVisits.filter { !$0.photos.isEmpty }.flatMap { visit in
            visit.photos.map { (visit: visit, photoPath: $0) }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    // Parallax hero
                    GeometryReader { geometry in
                        let offset = geometry.frame(in: .global).minY
                        
                        ModernParallaxHero(
                            title: currentCafe.name,
                            subtitle: currentCafe.address,
                            imageURL: allPhotos.first.map { $0.visit.remoteURL(for: $0.photoPath) ?? "" },
                            scrollOffset: offset
                        )
                        .preference(key: ScrollOffsetKey.self, value: offset)
                    }
                    .frame(height: 300)
                    
                    // Content sections
                    VStack(spacing: DS.Spacing.xl) {
                        // Stats row
                        statsRow
                            .padding(.top, DS.Spacing.lg)
                        
                        // Photos grid
                        if !allPhotos.isEmpty {
                            photosSection
                        }
                        
                        // Recent sips
                        if !allVisits.isEmpty {
                            recentSipsSection
                        }
                        
                        // Friends who visited
                        if !uniqueFriends.isEmpty {
                            friendsSection
                        }
                    }
                    .padding(.bottom, 120) // Space for sticky bar
                }
            }
            .background(DS.Colors.dynamicBackground)
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
            
            // Sticky action bar
            ModernStickyActionBar(
                cafe: currentCafe,
                dataManager: dataManager,
                onLogVisit: {
                    hapticsManager.mediumTap()
                    if let onLogVisit = onLogVisitRequested {
                        dismiss()
                        onLogVisit(cafe)
                    } else {
                        showLogVisit = true
                    }
                },
                onToggleBookmark: {
                    hapticsManager.lightTap()
                    dataManager.toggleCafeWantToTry(currentCafe.id)
                },
                onToggleFavorite: {
                    hapticsManager.lightTap()
                    dataManager.toggleCafeFavorite(currentCafe.id)
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                }
            }
        }
        .navigationDestination(item: $selectedVisit) { visit in
            VisitDetailView(dataManager: dataManager, visit: visit)
        }
        .sheet(isPresented: $showLogVisit) {
            ModernLogVisitView(
                dataManager: dataManager,
                preselectedCafe: currentCafe
            )
        }
        .fullScreenCover(isPresented: $showPhotoGallery) {
            if let index = selectedPhotoIndex {
                PhotoGalleryView(
                    photos: allPhotos.map { $0.visit.remoteURL(for: $0.photoPath) ?? "" },
                    initialIndex: index
                )
            }
        }
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statPill(
                    icon: "cup.and.saucer.fill",
                    value: "\(userVisits.count)",
                    label: userVisits.count == 1 ? "Visit" : "Visits"
                )
                
                if userAverageRating > 0 {
                    statPill(
                        icon: "star.fill",
                        value: String(format: "%.1f", userAverageRating),
                        label: "Avg Rating"
                    )
                }
                
                if let lastDate = lastVisitDate {
                    statPill(
                        icon: "calendar",
                        value: formatDate(lastDate),
                        label: "Last Visit"
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DS.Colors.dynamicPrimaryAccent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.dynamicTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .themeAwareFloatingCard(cornerRadius: 20)
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("PHOTOS")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(DS.Colors.dynamicTextTertiary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            ModernMasonryGrid(
                photos: Array(allPhotos.prefix(12)),
                dataManager: dataManager,
                onPhotoTap: { index in
                    selectedPhotoIndex = index
                    showPhotoGallery = true
                }
            )
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Recent Sips Section
    
    private var recentSipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("RECENT SIPS")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(DS.Colors.dynamicTextTertiary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            VStack(spacing: 12) {
                ForEach(Array(allVisits.prefix(5))) { visit in
                    Button(action: {
                        hapticsManager.lightTap()
                        selectedVisit = visit
                    }) {
                        miniSipCard(visit: visit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    private func miniSipCard(visit: Visit) -> some View {
        HStack(spacing: 12) {
            // User avatar
            Circle()
                .fill(DS.Colors.dynamicCardBackgroundAlt)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DS.Colors.dynamicTextTertiary)
                )
            
            // Visit info
            VStack(alignment: .leading, spacing: 4) {
                Text(visit.authorDisplayNameOrUsername)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                    .lineLimit(1)
                
                let caption = visit.caption
                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 14))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Rating badge (mint pill in light mode)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                Text(String(format: "%.1f", visit.overallScore))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(DS.Colors.dynamicTextOnAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DS.Colors.dynamicPrimaryAccent)
            .cornerRadius(12)
        }
        .padding(12)
        .themeAwareFloatingCard(cornerRadius: 16)
    }
    
    // MARK: - Friends Section
    
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("FRIENDS WHO'VE BEEN HERE")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(DS.Colors.dynamicTextTertiary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(uniqueFriends, id: \.id) { friend in
                        Button(action: {
                            hapticsManager.lightTap()
                            profileNavigator.openProfile(
                                handle: .supabase(id: friend.id),
                                source: .cafeVisitors,
                                triggerHaptic: false
                            )
                        }) {
                            VStack(spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .fill(DS.Colors.dynamicCardBackgroundAlt)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(DS.Colors.dynamicTextTertiary)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(DS.Colors.dynamicPrimaryAccent, lineWidth: 2)
                                        )
                                    
                                    // Rating badge
                                    Text(String(format: "%.1f", friend.rating))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(DS.Colors.dynamicTextOnAccent)
                                        .padding(4)
                                        .background(DS.Colors.dynamicPrimaryAccent)
                                        .cornerRadius(8)
                                        .offset(x: 4, y: -4)
                                }
                                
                                Text(friend.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                                    .lineLimit(1)
                                    .frame(width: 60)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Photo Gallery View

struct PhotoGalleryView: View {
    let photos: [String]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    
    init(photos: [String], initialIndex: Int) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    if let url = URL(string: photo) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            default:
                                Rectangle()
                                    .fill(Color.black.opacity(0.3))
                            }
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .padding()
                }
                
                Spacer()
                
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.bottom, 40)
            }
        }
    }
}
