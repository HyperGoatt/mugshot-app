//
//  DiscoverContentView.swift
//  testMugshot
//
//  The main content view for the "Discover" scope in the Feed tab.
//  Features: Personalized greeting, Spin for a Spot, Friend activity, Nearby cafes.
//

import SwiftUI
import CoreLocation

struct DiscoverContentView: View {
    @ObservedObject var dataManager: DataManager
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject private var themeManager: ThemeManager
    
    // State for Spin feature
    @State private var showSpinResult = false
    
    // State for nearby cafes
    @State private var nearbyCafes: [NearbyCafeData] = []
    @State private var isLoadingCafes = false
    
    // Callbacks
    var onCafeTap: ((Cafe) -> Void)?
    var onVisitTap: ((Visit) -> Void)?
    
    private var textPrimary: Color {
        themeManager.isModernDark ? DS.Colors.modernTextPrimary : DS.Colors.textPrimary
    }
    
    private var textSecondary: Color {
        themeManager.isModernDark ? DS.Colors.modernTextSecondary : DS.Colors.textSecondary
    }
    
    private var cardBackground: Color {
        themeManager.isModernDark ? DS.Colors.modernSurface : DS.Colors.cardBackground
    }
    
    private var accentColor: Color {
        themeManager.isModernDark ? DS.Colors.modernAccent : DS.Colors.primaryAccent
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                
                // 1. Personalized Greeting
                greetingHeader
                
                // 2. Cafes Near You (Top 5)
                nearbyCafesSection
                
                // 3. What Your Friends Are Sipping
                friendsSippingSection
                
                // 4. Spin for a Spot
                spinButtonSection
            }
            .padding(.top, DS.Spacing.md)
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if newLocation != nil {
                loadNearbyCafes()
            }
        }
        .fullScreenCover(isPresented: $showSpinResult) {
            SpinForASpotView(
                isPresented: $showSpinResult,
                locationManager: locationManager,
                dataManager: dataManager,
                onCafeSelected: { cafe in
                    onCafeTap?(cafe)
                }
            )
        }
    }
    
    // MARK: - Greeting Header
    
    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(greeting)
                .font(DS.Typography.title1())
                .foregroundColor(textPrimary)
            
            Text(formattedDate)
                .font(DS.Typography.caption1())
                .foregroundColor(textSecondary)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var greeting: String {
        let firstName = dataManager.appData.currentUser?.displayNameOrUsername
            .split(separator: " ")
            .first
            .map(String.init) ?? "Friend"
        
        return GreetingHelper.getGreeting(userName: firstName)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date()).uppercased()
    }
    
    // MARK: - Spin for a Spot Section
    
    private var spinButtonSection: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            showSpinResult = true
        }) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 20))
                
                Text("Spin for a Spot")
                    .font(DS.Typography.buttonLabel)
            }
            .foregroundColor(themeManager.isModernDark ? .white : DS.Colors.textOnMint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(accentColor)
            .cornerRadius(DS.Radius.primaryButton)
            .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - What Your Friends Are Sipping
    
    private var friendsSippingSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section Header
            Text("What your friends are sipping")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(textPrimary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Horizontal Scroll of Friend Visit Cards
            let recentFriendVisits = dataManager.getRecentFriendVisits(limit: 5)
            
            if recentFriendVisits.isEmpty {
                emptyFriendsPlaceholder
                    .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(recentFriendVisits, id: \.id) { visit in
                            FriendVisitCard(
                                visit: visit,
                                cafeName: dataManager.getCafe(id: visit.cafeId)?.name ?? "Unknown Cafe",
                                onTap: { onVisitTap?(visit) }
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
            }
        }
    }
    
    private var emptyFriendsPlaceholder: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 32))
                .foregroundColor(DS.Colors.textTertiary)
            
            Text("Your Sip Squad is quiet")
                .font(DS.Typography.subheadline(.semibold))
                .foregroundColor(textSecondary)
            
            Text("Be the first to log a sip today!")
                .font(DS.Typography.caption1())
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(cardBackground)
        .cornerRadius(DS.Radius.lg)
        .shadow(color: Color.black.opacity(themeManager.isModernDark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Cafes Near You (Top 5)
    
    private var nearbyCafesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section Header
            Text("Cafes near you")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(textPrimary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            if isLoadingCafes {
                loadingPlaceholder
                    .padding(.horizontal, DS.Spacing.pagePadding)
            } else if nearbyCafes.isEmpty {
                emptyNearbyCafesPlaceholder
                    .padding(.horizontal, DS.Spacing.pagePadding)
            } else {
                // Vertical list of compact cafe cards
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(nearbyCafes, id: \.cafe.id) { item in
                        NearbyCafeCard(
                            cafe: item.cafe,
                            distance: item.distance,
                            averageRating: item.averageRating,
                            totalRatings: item.totalRatings,
                            photoURL: item.photoURL,
                            hasVisits: item.hasVisits,
                            onTap: { onCafeTap?(item.cafe) }
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    private var loadingPlaceholder: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .tint(accentColor)
            Text("Finding cafes nearby...")
                .font(DS.Typography.caption1())
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .background(cardBackground)
        .cornerRadius(DS.Radius.lg)
        .shadow(color: Color.black.opacity(themeManager.isModernDark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
    }
    
    private var emptyNearbyCafesPlaceholder: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: locationManager.location == nil ? "location.slash" : "magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(DS.Colors.textTertiary)
            
            Text(locationManager.location == nil ? "Location unavailable" : "No cafes found nearby")
                .font(DS.Typography.subheadline(.semibold))
                .foregroundColor(textSecondary)
            
            Text(locationManager.location == nil ? "Check location permissions" : "Try again later")
                .font(DS.Typography.caption1())
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .background(cardBackground)
        .cornerRadius(DS.Radius.lg)
        .shadow(color: Color.black.opacity(themeManager.isModernDark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Nearby Cafes Data Structure
    
    struct NearbyCafeData {
        let cafe: Cafe
        let distance: Double?
        let averageRating: Double?
        let totalRatings: Int
        let photoURL: String?
        let hasVisits: Bool
    }
    
    /// Load nearby cafes using Apple Maps search
    private func loadNearbyCafes() {
        guard let userLocation = locationManager.location else {
            isLoadingCafes = false
            return
        }
        
        isLoadingCafes = true
        
        Task {
            let cafes = await dataManager.searchNearbyCafes(near: userLocation, radiusMiles: 3.0, limit: 5)
            
            await MainActor.run {
                nearbyCafes = cafes.map { cafe in
                    let distance = cafe.location.map { location in
                        userLocation.distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
                    }
                    
                    // Get ratings
                    let ratings = dataManager.calculateAverageRating(for: cafe.id)
                    let hasVisits = ratings.count > 0
                    
                    // Get first photo for thumbnail
                    let photoURL = dataManager.getPhotoURLsForCafe(cafe.id, limit: 1).first
                    
                    return NearbyCafeData(
                        cafe: cafe,
                        distance: distance,
                        averageRating: ratings.average > 0 ? ratings.average : nil,
                        totalRatings: ratings.count,
                        photoURL: photoURL,
                        hasVisits: hasVisits
                    )
                }
                isLoadingCafes = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DiscoverContentView(
            dataManager: DataManager.shared,
            onCafeTap: { _ in },
            onVisitTap: { _ in }
        )
    }
    .background(DS.Colors.screenBackground)
}

