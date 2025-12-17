//
//  ModernMapView.swift
//  testMugshot
//
//  Modern Dark Mode map with custom pins, floating search, and glass preview
//

import SwiftUI
import MapKit
import CoreLocation

struct ModernMapView: View {
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)?
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = MapSearchService()
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var region: MKCoordinateRegion?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var lastSearchRegion: MKCoordinateRegion?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var annotations: [ModernCafeAnnotation] = []
    @State private var showSearchResults = false
    @State private var sipSquadMode = false
    
    private var referenceLocation: CLLocation {
        let activeRegion = region ?? defaultRegion
        return CLLocation(latitude: activeRegion.center.latitude, longitude: activeRegion.center.longitude)
    }
    
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    private var shouldShowSearchThisArea: Bool {
        guard let last = lastSearchRegion, let current = region else { return false }
        
        let lastLoc = CLLocation(latitude: last.center.latitude, longitude: last.center.longitude)
        let currentLoc = CLLocation(latitude: current.center.latitude, longitude: current.center.longitude)
        
        // Show if moved more than 2km from last search center
        return lastLoc.distance(from: currentLoc) > 2000
    }
    
    private var searchResults: [Cafe] {
        guard !searchText.isEmpty else { return [] }
        return dataManager.appData.cafes.filter { cafe in
            cafe.name.localizedCaseInsensitiveContains(searchText)
        }.sorted { cafe1, cafe2 in
            // Sort by distance from reference location
            guard let loc1 = cafe1.location, let loc2 = cafe2.location else { return false }
            let dist1 = referenceLocation.distance(from: CLLocation(latitude: loc1.latitude, longitude: loc1.longitude))
            let dist2 = referenceLocation.distance(from: CLLocation(latitude: loc2.latitude, longitude: loc2.longitude))
            return dist1 < dist2
        }
    }
    
    var body: some View {
        ZStack {
            // Dark background
            DS.Colors.dynamicBackground
                .ignoresSafeArea()
            
            // Map with custom style
            Map(position: $cameraPosition) {
                // User location
                if let userLocation = locationManager.location {
                    Annotation("", coordinate: userLocation.coordinate) {
                        Circle()
                            .fill(DS.Colors.dynamicPrimaryAccent)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                    }
                }
                
                // Cafe annotations
                ForEach(annotations) { annotation in
                    Annotation("", coordinate: annotation.coordinate) {
                        Button(action: {
                            hapticsManager.lightTap()
                            selectedCafe = annotation.cafe
                        }) {
                            ModernCafePin(
                                rating: annotation.rating,
                                isSelected: selectedCafe?.id == annotation.cafe.id,
                                isWantToTry: annotation.isWantToTry
                            )
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .preferredColorScheme(.dark)
            .ignoresSafeArea()
            .onMapCameraChange { context in
                region = context.region
            }
            
            // Floating search bar and results
            VStack {
                ModernMapSearchBar(
                    searchText: $searchText,
                    isActive: $isSearchActive,
                    onSubmit: {
                        performSearch()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .onChange(of: searchText) { _, newValue in
                    showSearchResults = !newValue.isEmpty
                }
                
                // Search results list
                if showSearchResults && !searchResults.isEmpty {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(searchResults.prefix(10)) { cafe in
                                Button(action: {
                                    selectSearchResult(cafe)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
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
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(DS.Colors.dynamicCardBackgroundAlt)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .background(DS.Colors.dynamicCardBackgroundAlt)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                // "Search This Area" button
                if shouldShowSearchThisArea && !showSearchResults {
                    Button(action: {
                        hapticsManager.mediumTap()
                        performSearch()
                    }) {
                        Text("Search this area")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(DS.Colors.dynamicPrimaryAccent)
                            .cornerRadius(20)
                            .modernMintGlow()
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
            
            // Control buttons (bottom-right)
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Sip Squad toggle
                        Button(action: {
                            hapticsManager.mediumTap()
                            sipSquadMode.toggle()
                            loadNearbyCafes()
                        }) {
                            Image(systemName: sipSquadMode ? "person.2.fill" : "person.2")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(sipSquadMode ? DS.Colors.dynamicPrimaryAccent : DS.Colors.dynamicTextSecondary)
                                .frame(width: 44, height: 44)
                                .modernFloatingGlass(cornerRadius: 22)
                        }
                        
                        // User location button
                        Button(action: recenterOnUser) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(locationManager.location != nil ? DS.Colors.dynamicPrimaryAccent : DS.Colors.dynamicTextSecondary)
                                .frame(width: 44, height: 44)
                                .modernFloatingGlass(cornerRadius: 22)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 120) // Above tab bar
                }
            }
            
            // Map legend (bottom-left)
            VStack {
                Spacer()
                
                HStack {
                    ModernMapLegend()
                        .padding(.leading, 16)
                        .padding(.bottom, 120) // Above tab bar
                    
                    Spacer()
                }
            }
            
            // Bottom sheet cafe preview
            if let cafe = selectedCafe {
                VStack {
                    Spacer()
                    
                    ModernCafePreviewCard(
                        cafe: cafe,
                        userLocation: locationManager.location,
                        onTap: {
                            hapticsManager.mediumTap()
                            showCafeDetail = true
                        },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCafe = nil
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110) // Above tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                ModernCafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: onLogVisitRequested
                )
            }
        }
        .onAppear {
            setupInitialLocation()
            loadNearbyCafes()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if let location = newLocation, region == nil {
                centerOnLocation(location)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func setupInitialLocation() {
        if let userLocation = locationManager.location {
            centerOnLocation(userLocation)
        } else {
            centerOnRegion(defaultRegion)
        }
    }
    
    private func centerOnLocation(_ location: CLLocation) {
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        withAnimation(.easeInOut(duration: 0.5)) {
            region = newRegion
            cameraPosition = .region(newRegion)
        }
    }
    
    private func centerOnRegion(_ newRegion: MKCoordinateRegion) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region = newRegion
            cameraPosition = .region(newRegion)
        }
    }
    
    private func recenterOnUser() {
        hapticsManager.mediumTap()
        if let userLocation = locationManager.location {
            centerOnLocation(userLocation)
        }
    }
    
    private func performSearch() {
        guard let currentRegion = region else { return }
        lastSearchRegion = currentRegion
        loadNearbyCafes()
    }
    
    private func selectSearchResult(_ cafe: Cafe) {
        hapticsManager.lightTap()
        searchText = ""
        showSearchResults = false
        isSearchActive = false
        
        guard let location = cafe.location else { return }
        
        let newRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        withAnimation(.easeInOut(duration: 0.5)) {
            region = newRegion
            cameraPosition = .region(newRegion)
            selectedCafe = cafe
        }
    }
    
    private func loadNearbyCafes() {
        var cafesInArea = dataManager.appData.cafes.filter { cafe in
            guard let location = cafe.location else { return false }
            let cafeLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = referenceLocation.distance(from: cafeLocation)
            return distance < 10000 // 10km radius
        }
        
        // Filter for Sip Squad mode
        if sipSquadMode {
            let friendIds = dataManager.appData.friendsSupabaseUserIds
            let friendCafeIds = Set(dataManager.appData.visits.filter { visit in
                guard let userId = visit.supabaseUserId else { return false }
                return friendIds.contains(userId)
            }.map { $0.cafeId })
            
            cafesInArea = cafesInArea.filter { friendCafeIds.contains($0.id) }
        }
        
        annotations = cafesInArea.compactMap { cafe in
            guard let location = cafe.location else { return nil }
            
            let rating = dataManager.calculateAverageRating(for: cafe.id)
            let avgRating = rating.average > 0 ? rating.average : cafe.averageRating
            
            return ModernCafeAnnotation(
                id: cafe.id,
                coordinate: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                cafe: cafe,
                rating: avgRating,
                isWantToTry: cafe.wantToTry && rating.count == 0 // Want to try if bookmarked but not visited
            )
        }
    }
}

// MARK: - Modern Cafe Preview Card

struct ModernCafePreviewCard: View {
    let cafe: Cafe
    let userLocation: CLLocation?
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    private var distance: String? {
        guard let userLocation = userLocation,
              let cafeLocation = cafe.location else { return nil }
        
        let cafeCLLocation = CLLocation(latitude: cafeLocation.latitude, longitude: cafeLocation.longitude)
        let distanceInMeters = userLocation.distance(from: cafeCLLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            return "Nearby"
        } else if distanceInMiles < 1.0 {
            return String(format: "%.1f mi", distanceInMiles)
        } else {
            return String(format: "%.0f mi", distanceInMiles)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Cafe thumbnail (placeholder for now)
                RoundedRectangle(cornerRadius: 12)
                    .fill(DS.Colors.dynamicCardBackgroundAlt)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DS.Colors.dynamicTextTertiary)
                    )
                
                // Cafe info
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let distance = distance {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                Text(distance)
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(DS.Colors.dynamicTextSecondary)
                        }
                        
                        if cafe.averageRating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                Text(String(format: "%.1f", cafe.averageRating))
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                        }
                    }
                }
                
                Spacer()
                
                // Arrow button
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextSecondary)
            }
            .padding(16)
            .themeAwareFloatingCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
                    .background(Circle().fill(DS.Colors.dynamicCardBackgroundAlt))
            }
            .offset(x: 8, y: -8)
        }
    }
}


