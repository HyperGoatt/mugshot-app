//
//  MapTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct MapTabView: View {
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = MapSearchService()
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var region: MKCoordinateRegion?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var isSearchActive = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hasRequestedLocation = false
    @State private var hasInitializedLocation = false
    @State private var showLocationMessage = false
    @State private var showNotifications = false
    @State private var selectedVisit: Visit?
    @State private var recenterOnUserRequest = false
    @State private var showFriendsHub = false
    @State private var lastSearchRegion: MKCoordinateRegion?
    @State private var searchScope: SearchScope = .cafes
    
    enum SearchScope: String, CaseIterable {
        case cafes = "Cafes"
        case people = "People"
    }
    
    private var referenceLocation: CLLocation {
        let activeRegion = region ?? defaultRegion
        return CLLocation(latitude: activeRegion.center.latitude, longitude: activeRegion.center.longitude)
    }
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    // Simplified Sip Squad mode state (bound to persisted AppData)
    private var isSipSquadMode: Bool {
        dataManager.appData.isSipSquadModeEnabled
    }
    
    private var hasFriends: Bool {
        !dataManager.appData.friendsSupabaseUserIds.isEmpty
    }
    
    private var friendVisitedCafeCount: Int {
        dataManager.getFriendVisitedCafeCount()
    }
    
    // Feature flag for simplified Sip Squad style (mint pins, no legend)
    // When Sip Squad Mode is active, always use mint pins
    private var useSipSquadSimplifiedStyle: Bool {
        isSipSquadMode
    }
    
    // Default fallback region (SF) - only used if location unavailable
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    private var searchFieldFocusBinding: Binding<Bool> {
        Binding(
            get: { isSearchFieldFocused },
            set: { isSearchFieldFocused = $0 }
        )
    }
    
    private var shouldShowRecentSearches: Bool {
        isSearchFieldFocused && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var shouldShowSearchThisArea: Bool {
        guard let last = lastSearchRegion, let current = region else { return false }
        
        let lastLoc = CLLocation(latitude: last.center.latitude, longitude: last.center.longitude)
        let currentLoc = CLLocation(latitude: current.center.latitude, longitude: current.center.longitude)
        
        // Show if moved more than 2km from last search center
        return lastLoc.distance(from: currentLoc) > 2000
    }
    
    private func handleSearchThisArea() {
        guard let currentRegion = region else { return }
        
        HapticsManager.shared.lightTap()
        
        // Use current search text or default to "Café" if empty
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveQuery = query.isEmpty ? "Café" : query
        
        if query.isEmpty {
            searchText = "Café" // Auto-fill search text
        }
        
        // Update last search region
        lastSearchRegion = currentRegion
        
        // Trigger search
        isSearchActive = true
        searchService.search(
            query: effectiveQuery,
            region: currentRegion,
            mode: dataManager.appData.mapSearchMode
        )
    }
    
    var body: some View {
        NavigationStack {
        ZStack {
            // Map with POIs hidden
            MapViewRepresentable(
                region: Binding(
                    get: { region ?? defaultRegion },
                    set: { region = $0 }
                ),
                cafes: cafesWithLocations,
                useSipSquadSimplifiedStyle: useSipSquadSimplifiedStyle,
                onCafeTap: { cafe in
                    // Haptic: confirm map pin tap
                    hapticsManager.lightTap()
                    selectedCafe = cafe
                    showCafeDetail = true
                    isSearchActive = false
                }
            )
            .ignoresSafeArea()
            .onAppear {
                // Request location permission on first appearance
                if !hasRequestedLocation {
                    locationManager.requestLocationPermission()
                    hasRequestedLocation = true
                }
                
                // Initialize location if we already have permission
                initializeLocationIfNeeded()
            }
            .onChange(of: locationManager.location) { oldValue, newLocation in
                guard let location = newLocation else { return }
                let isAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
                guard isAuthorized else { return }
                
                // First time we get a good location, auto-center
                if !hasInitializedLocation || oldValue == nil {
                    hasInitializedLocation = true
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                    return
                }
                
                // If user tapped the My Location button, recenter on the next update
                if recenterOnUserRequest {
                    recenterOnUserRequest = false
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }
            .onChange(of: locationManager.authorizationStatus) { oldValue, status in
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    // Permission granted - start updating location
                    locationManager.startUpdatingLocation()
                    showLocationMessage = false
                    // Reset initialization flag to allow centering on new location
                    if !hasInitializedLocation {
                        initializeLocationIfNeeded()
                    }
                case .denied, .restricted:
                    // Permission denied - show message and use fallback
                    showLocationMessage = true
                    locationManager.stopUpdatingLocation()
                    if region == nil {
                        region = defaultRegion
                    }
                case .notDetermined:
                    // Will request when needed
                    break
                @unknown default:
                    break
                }
            }
            
            VStack(spacing: 0) {
                // Location message banner
                if showLocationMessage {
                    LocationBanner()
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Sip Squad banner
                if isSipSquadMode {
                    SipSquadBanner(
                        hasFriends: hasFriends,
                        friendCafeCount: friendVisitedCafeCount,
                        onDismiss: {
                            hapticsManager.lightTap()
                            dataManager.toggleSipSquadMode()
                        },
                        onFindFriends: {
                            hapticsManager.lightTap()
                            showFriendsHub = true
                        }
                    )
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.top, DS.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Inline search bar
                VStack(spacing: 0) {
                    HStack(spacing: DS.Spacing.lg) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(DS.Colors.textSecondary)
                            
                            TextField(searchScope == .cafes ? "Search cafes..." : "Search people...", text: $searchText)
                                .foregroundColor(DS.Colors.textPrimary)
                                .tint(DS.Colors.primaryAccent)
                                .accentColor(DS.Colors.primaryAccent)
                                .textFieldStyle(.plain)
                                .focused($isSearchFieldFocused)
                                .onChange(of: searchText) { _, newValue in
                                    guard searchScope == .cafes else { return } // Only auto-search map for cafes
                                    
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        if !isSearchActive {
                                            withAnimation {
                                                isSearchActive = true
                                            }
                                        }
                                        searchService.search(
                                            query: trimmed,
                                            region: region ?? defaultRegion,
                                            mode: dataManager.appData.mapSearchMode
                                        )
                                        if let currentRegion = region {
                                            lastSearchRegion = currentRegion
                                        }
                                    } else {
                                        searchService.cancelSearch()
                                        // If cleared, fetch suggestions again
                                        searchService.searchNearby(region: region ?? defaultRegion)
                                        
                                        if !isSearchFieldFocused {
                                            withAnimation {
                                                isSearchActive = false
                                            }
                                        }
                                    }
                                }
                                .onChange(of: isSearchFieldFocused) { _, isFocused in
                                    if isFocused {
                                        // Fetch suggestions immediately on focus
                                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            searchService.searchNearby(region: region ?? defaultRegion)
                                        }
                                        
                                        withAnimation {
                                            isSearchActive = true
                                        }
                                    } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        withAnimation {
                                            isSearchActive = false
                                        }
                                    }
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    searchService.cancelSearch()
                                    // Don't close search, just clear text
                                    // isSearchActive = false 
                                    // isSearchFieldFocused = false
                                    lastSearchRegion = nil 
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(DS.Colors.iconSubtle)
                                }
                            }
                        }
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.card)
                        .dsCardShadow()
                        
                        if isSearchActive {
                            Button("Cancel") {
                                searchText = ""
                                searchService.cancelSearch()
                                isSearchActive = false
                                isSearchFieldFocused = false
                                lastSearchRegion = nil
                                searchScope = .cafes // Reset scope
                            }
                            .foregroundColor(DS.Colors.textPrimary)
                            .transition(.opacity)
                        }
                        
                        // Notifications bell icon (Hidden when searching to save space)
                        if !isSearchActive {
                            Button(action: { showNotifications = true }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell")
                                        .font(.system(size: 20))
                                        .foregroundColor(DS.Colors.iconDefault)
                                        .frame(width: 44, height: 44)
                                    
                                    if unreadNotificationCount > 0 {
                                        Text("\(unreadNotificationCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(DS.Colors.textOnMint)
                                            .padding(4)
                                            .background(
                                                Circle()
                                                    .fill(DS.Colors.primaryAccent)
                                            )
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Scope Picker (Visible when searching)
                    if isSearchActive {
                        Picker("Scope", selection: $searchScope) {
                            ForEach(SearchScope.allCases, id: \.self) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, DS.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(DS.Spacing.pagePadding)
                .background(DS.Colors.screenBackground.opacity(isSearchActive ? 0.95 : 0))
                .animation(.easeInOut(duration: 0.2), value: isSearchActive)
                
                // Search This Area Button (Only for Cafe mode)
                if shouldShowSearchThisArea && searchScope == .cafes {
                    SearchThisAreaButton(
                        action: handleSearchThisArea,
                        isSearching: searchService.isSearching
                    )
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(100)
                }
                
                // Search results list
                if isSearchActive {
                    if searchScope == .cafes {
                        CafeSearchResultsPanel(
                            searchText: $searchText,
                            searchService: searchService,
                            recentSearches: dataManager.appData.recentSearches,
                            showRecentSearches: shouldShowRecentSearches,
                            nearbySuggestions: searchService.nearbySuggestions,
                            referenceLocation: referenceLocation,
                            onMapItemSelected: { mapItem in
                                print("[Search] User selected nearby suggestion: \(mapItem.name ?? "Unknown")")
                                handleSearchResult(mapItem)
                            },
                            onRecentSelected: { entry in
                                handleRecentSearch(entry)
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        PeopleSearchResultsPanel(
                            searchText: $searchText,
                            dataManager: dataManager
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                Spacer()
            }
            
            // Bottom UI elements: Location button, Sip Squad toggle, and Ratings Legend
            VStack(spacing: DS.Spacing.sm) {
                Spacer()
                
                if !showCafeDetail {
                    // Stack buttons just above the legend, both sitting above the custom tab bar
                    HStack {
                        Spacer()
                        
                        // Sip Squad toggle button
                        SipSquadToggleButton(
                            isActive: isSipSquadMode,
                            onTap: {
                                hapticsManager.lightTap()
                                
                                // If turning on but no friends, show the friends hub instead
                                if !isSipSquadMode && !hasFriends {
                                    showFriendsHub = true
                                } else {
                                    // toggleSipSquadMode() handles fetch internally when enabling
                                    dataManager.toggleSipSquadMode()
                                }
                            }
                        )
                        
                        MyLocationButton(
                            locationManager: locationManager,
                            region: Binding(
                                get: { region ?? defaultRegion },
                                set: { region = $0 }
                            ),
                            recenterOnUserRequest: $recenterOnUserRequest
                        )
                        .padding(.trailing, DS.Spacing.pagePadding)
                    }
                    
                    // Only show legend if not using simplified Sip Squad style
                    if !useSipSquadSimplifiedStyle {
                        RatingsLegend(isSipSquadMode: isSipSquadMode)
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .transition(.opacity)
                    }
                }
            }
            // Keep these elements pinned visually even when the keyboard appears
            .padding(.bottom, 80) // Reserve space for custom tab bar (≈70pt) + a bit of breathing room
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            // Unified café sheet (preview → full)
            // Presented via .sheet modifier below

        }
        .sheet(isPresented: $showNotifications) {
            NotificationsCenterView(dataManager: dataManager)
        }
        .sheet(isPresented: $showFriendsHub) {
            FriendsHubView(dataManager: dataManager)
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                UnifiedCafeView(
                    cafe: cafe,
                    dataManager: dataManager,
                    presentationMode: .mapSheet,
                    onLogVisitRequested: onLogVisitRequested,
                    onDismiss: {
                        showCafeDetail = false
                    }
                )
            }
        }
        .navigationDestination(item: $selectedVisit) { visit in
            VisitDetailView(dataManager: dataManager, visit: visit)
        }
        }
    }
    
    private func initializeLocationIfNeeded() {
        // Only initialize once, and only if we have permission
        guard !hasInitializedLocation else { return }
        
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Check if we already have a location
            if let location = locationManager.getCurrentLocation() {
                hasInitializedLocation = true
                withAnimation {
                    region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }
            } else {
                // Start updating to get location
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            // Use fallback only if truly no location available
            showLocationMessage = true
            if region == nil {
                region = defaultRegion
            }
        case .notDetermined:
            // Will request permission
            break
        @unknown default:
            break
        }
    }
    
    private func handleSearchResult(_ mapItem: MKMapItem, recordRecent: Bool = true) {
        guard let location = mapItem.placemark.location?.coordinate else { return }
        
        HapticsManager.shared.lightTap()
        
        withAnimation {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            isSearchActive = false
        }
        
        let cafe = dataManager.findOrCreateCafe(from: mapItem)
        selectedCafe = cafe
        showCafeDetail = true
        isSearchFieldFocused = false
        
        let queryText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchText = ""
        searchService.cancelSearch()
        lastSearchRegion = nil // Reset context after selecting
        
        if recordRecent {
            dataManager.addRecentSearch(from: mapItem, query: queryText.isEmpty ? (mapItem.name ?? "") : queryText)
        }
    }
    
    private func handleRecentSearch(_ entry: RecentSearchEntry) {
        dataManager.promoteRecentSearch(entry)
        if let mapItem = entry.asMapItem() {
            handleSearchResult(mapItem, recordRecent: false)
        } else {
            searchText = entry.query
            searchService.search(
                query: entry.query,
                region: region ?? defaultRegion,
                mode: dataManager.appData.mapSearchMode
            )
            isSearchFieldFocused = true
        }
    }
    
    // MARK: - Map Pin Data Sources (Strict Separation)
    
    /// Cafes for SOLO mode - only current user's visits
    /// Friends' visits NEVER appear in solo mode
    private var currentUserCafesForMap: [Cafe] {
        dataManager.getCurrentUserCafesForMap()
    }
    
    /// Cafes for SIP SQUAD mode - combined user + friends visits with aggregated ratings
    private var sipSquadCombinedCafesForMap: [Cafe] {
        dataManager.getSipSquadCafes()
    }
    
    /// Final computed property used by the map view
    /// Strictly separated: solo mode uses ONLY current user data, Sip Squad uses combined data
    private var cafesWithLocations: [Cafe] {
        #if DEBUG
        let mode = isSipSquadMode ? "sipSquad" : "solo"
        print("[Map] Building pins - mode: \(mode)")
        #endif
        
        if isSipSquadMode {
            // SIP SQUAD MODE: Show aggregated cafes from user + friends
            let sipSquadCafes = sipSquadCombinedCafesForMap
            let filtered = filterCafesWithValidLocations(sipSquadCafes)
            
            #if DEBUG
            print("[Map:SipSquad] Total SipSquad cafes: \(sipSquadCafes.count), with valid locations: \(filtered.count)")
            #endif
            
            return filtered
        }
        
        // SOLO MODE: Show ONLY current user's cafes
        // This MUST NOT include any friends' visits
        let soloCafes = currentUserCafesForMap
        let filtered = filterCafesWithValidLocations(soloCafes)
        
        #if DEBUG
        print("[Map:Solo] Total solo cafes: \(soloCafes.count), with valid locations: \(filtered.count)")
        if let userId = dataManager.appData.supabaseUserId {
            print("[Map:Solo] Current user ID: \(userId.prefix(8))...")
        }
        #endif
        
        return filtered
    }
    
    // PERFORMANCE: Extracted filtering logic to reduce code duplication and enable optimization
    private func filterCafesWithValidLocations(_ cafes: [Cafe]) -> [Cafe] {
        let filtered = cafes.filter { cafe in
            // Check location first (fast rejection)
            guard let location = cafe.location else { return false }
            
            // Ensure coordinates are valid
            guard abs(location.latitude) <= 90 && abs(location.longitude) <= 180 else { return false }
            
            // Check if cafe qualifies (has visits, favorite, or wantToTry)
            return cafe.visitCount > 0 || cafe.isFavorite || cafe.wantToTry
        }
        
        // PERFORMANCE: Only log summary in debug builds, not per-cafe details
        #if DEBUG
        if filtered.isEmpty && !cafes.isEmpty {
            print("⚠️ [Map] No cafes passed filter from \(cafes.count) total - check locations and flags")
        }
        #endif
        
        return filtered
    }
    
    /// Debug helper to verify map data integrity
    /// Call this in debug builds to check if friend data is leaking into solo mode
    #if DEBUG
    private func debugVerifyMapPinIsolation() {
        guard !isSipSquadMode else { return } // Only check in solo mode
        
        guard let supabaseUserId = dataManager.appData.supabaseUserId else { return }
        let friendIds = dataManager.appData.friendsSupabaseUserIds
        
        // Check each cafe shown on the map
        for cafe in cafesWithLocations {
            // Get all visits for this cafe
            let cafeVisits = dataManager.appData.visits.filter { visit in
                visit.cafeId == cafe.id || visit.supabaseCafeId == cafe.id
            }
            
            // Check if any visits are from friends (not current user)
            let friendVisitsForCafe = cafeVisits.filter { visit in
                guard let authorId = visit.supabaseUserId else { return false }
                return friendIds.contains(authorId) && authorId != supabaseUserId
            }
            
            let userVisitsForCafe = cafeVisits.filter { visit in
                visit.supabaseUserId == supabaseUserId
            }
            
            // If cafe has only friend visits and no user visits, it shouldn't be on solo map
            if !friendVisitsForCafe.isEmpty && userVisitsForCafe.isEmpty && !cafe.isFavorite && !cafe.wantToTry {
                print("🚨 [Map:Solo] DATA LEAK DETECTED: Cafe '\(cafe.name)' has \(friendVisitsForCafe.count) friend visits but 0 user visits and appears in solo mode!")
            }
        }
    }
    #endif
}

// MARK: - Map View Representable (to hide POIs)

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let cafes: [Cafe]
    let useSipSquadSimplifiedStyle: Bool
    let onCafeTap: (Cafe) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        
        // Show current user location (blue dot)
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Hide points of interest
        mapView.pointOfInterestFilter = .excludingAll
        
        // Keep roads and basic geography
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        
        // Add initial annotations
        let initialAnnotations = cafes.map { CafeAnnotation(cafe: $0) }
        if !initialAnnotations.isEmpty {
            mapView.addAnnotations(initialAnnotations)
        }
        
        // Register default cluster view
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        
        return mapView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(useSipSquadSimplifiedStyle: useSipSquadSimplifiedStyle, onCafeTap: onCafeTap)
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update the coordinator's style flag
        context.coordinator.useSipSquadSimplifiedStyle = useSipSquadSimplifiedStyle
        
        // Check if Sip Squad style flag changed - if so, force refresh all annotations
        let styleChanged = context.coordinator.previousUseSipSquadSimplifiedStyle != useSipSquadSimplifiedStyle
        if styleChanged {
            // Force refresh all existing cafe annotations when style changes
            let existingAnnotations = mapView.annotations.compactMap { $0 as? CafeAnnotation }
            if !existingAnnotations.isEmpty {
                // Remove all existing cafe annotations
                mapView.removeAnnotations(existingAnnotations)
                
                // Build updated cafe list (deduplicated)
                var cafesById: [UUID: Cafe] = [:]
                for cafe in cafes {
                    if cafesById[cafe.id] == nil {
                        cafesById[cafe.id] = cafe
                    }
                }
                
                // Re-add annotations with updated cafe data
                // This will trigger mapView(_:viewFor:) to be called with the new style flag
                let refreshedAnnotations = cafesById.values.map { CafeAnnotation(cafe: $0) }
                mapView.addAnnotations(refreshedAnnotations)
            }
        }
        // Record the current style flag for the next update cycle
        context.coordinator.previousUseSipSquadSimplifiedStyle = useSipSquadSimplifiedStyle
        
        // Update region if needed
        if abs(mapView.region.center.latitude - region.center.latitude) > 0.001 ||
           abs(mapView.region.center.longitude - region.center.longitude) > 0.001 {
            mapView.setRegion(region, animated: true)
        }
        
        // Skip normal update logic if we already refreshed due to style change
        guard !styleChanged else { return }
        
        // PERFORMANCE: Build lookup structures once instead of repeated searches
        let existingAnnotations = mapView.annotations.compactMap { $0 as? CafeAnnotation }
        let existingCafeIds = Set(existingAnnotations.map { $0.cafe.id })
        let currentCafeIds = Set(cafes.map { $0.id })
        
        // BUGFIX: Handle duplicate cafe IDs safely - keep only the first occurrence
        // This prevents crashes if getSipSquadCafes() returns duplicates
        var cafesById: [UUID: Cafe] = [:]
        for cafe in cafes {
            if cafesById[cafe.id] == nil {
                cafesById[cafe.id] = cafe
            }
        }
        let currentCafesById = cafesById
        
        // Remove annotations for cafes that no longer exist
        let toRemove = existingAnnotations.filter { !currentCafeIds.contains($0.cafe.id) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
        }
        
        // PERFORMANCE: Batch annotation updates to minimize map view operations
        var annotationsToRemove: [CafeAnnotation] = []
        var annotationsToAdd: [CafeAnnotation] = []
        
        // Check existing annotations for state changes
        for existingAnnotation in existingAnnotations {
            guard let updatedCafe = currentCafesById[existingAnnotation.cafe.id] else { continue }
            
            // Check if Favorite/Want to Try state changed
            if existingAnnotation.cafe.isFavorite != updatedCafe.isFavorite ||
               existingAnnotation.cafe.wantToTry != updatedCafe.wantToTry ||
               existingAnnotation.cafe.averageRating != updatedCafe.averageRating {
                annotationsToRemove.append(existingAnnotation)
                annotationsToAdd.append(CafeAnnotation(cafe: updatedCafe))
            }
        }
        
        // Add new annotations for cafes not already shown
        let toAdd = cafes.filter { !existingCafeIds.contains($0.id) }
        annotationsToAdd.append(contentsOf: toAdd.map { CafeAnnotation(cafe: $0) })
        
        // PERFORMANCE: Batch operations
        if !annotationsToRemove.isEmpty {
            mapView.removeAnnotations(annotationsToRemove)
        }
        if !annotationsToAdd.isEmpty {
            mapView.addAnnotations(annotationsToAdd)
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var useSipSquadSimplifiedStyle: Bool
        var previousUseSipSquadSimplifiedStyle: Bool
        let onCafeTap: (Cafe) -> Void
        
        init(useSipSquadSimplifiedStyle: Bool, onCafeTap: @escaping (Cafe) -> Void) {
            self.useSipSquadSimplifiedStyle = useSipSquadSimplifiedStyle
            self.previousUseSipSquadSimplifiedStyle = useSipSquadSimplifiedStyle
            self.onCafeTap = onCafeTap
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            // Handle cluster annotations with mint color
            if annotation is MKClusterAnnotation {
                var clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? MKMarkerAnnotationView
                
                if clusterView == nil {
                    clusterView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
                } else {
                    clusterView?.annotation = annotation
                }
                
                // Set mint color for cluster pins
                let mintColor = UIColor(red: 183/255, green: 226/255, blue: 181/255, alpha: 1.0) // #B7E2B5 (mintMain)
                clusterView?.markerTintColor = mintColor
                clusterView?.glyphTintColor = UIColor(red: 5/255, green: 46/255, blue: 22/255, alpha: 1.0) // #052E16 (textOnMint)
                
                return clusterView
            }
            
            guard let cafeAnnotation = annotation as? CafeAnnotation else {
                return nil
            }
            
            let cafe = cafeAnnotation.cafe
            // Include style flag in identifier to force new views when style changes
            let baseIdentifier = cafe.isFavorite ? "FavoritePin" : (cafe.wantToTry ? "WantToTryPin" : "CafePin")
            let identifier = "\(baseIdentifier)_\(useSipSquadSimplifiedStyle ? "mint" : "rating")"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                annotationView?.isEnabled = true
                annotationView?.isUserInteractionEnabled = true
                // Enable Clustering
                annotationView?.clusteringIdentifier = "cafeCluster"
            } else {
                annotationView?.annotation = annotation
            }
            
            // Determine pin style based on mode and Favorite/Want to Try
            let pinSize: CGFloat = 36
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: pinSize, height: pinSize))
            containerView.backgroundColor = .clear
            
            // Use simplified mint style if flag is enabled
            if useSipSquadSimplifiedStyle {
                // Sip Squad simplified: All pins are Mugshot Mint with rating
                let mintPin = createMintPin(size: pinSize, rating: cafe.averageRating)
                containerView.addSubview(mintPin)
            } else {
                // Standard mode: Priority: Want to Try > Favorite > Default
                if cafe.wantToTry {
                    // Want to Try: Blue bookmark icon
                    let bookmarkView = createBookmarkPin(size: pinSize, rating: cafe.averageRating)
                    containerView.addSubview(bookmarkView)
                } else if cafe.isFavorite {
                    // Favorite: Heart icon with rating color
                    let heartView = createHeartPin(size: pinSize, rating: cafe.averageRating)
                    containerView.addSubview(heartView)
                } else {
                    // Default: Rating-colored circle
                    let circleView = createDefaultPin(size: pinSize, rating: cafe.averageRating)
                    containerView.addSubview(circleView)
                }
            }
            
            // Clear existing subviews
            annotationView?.subviews.forEach { $0.removeFromSuperview() }
            annotationView?.addSubview(containerView)
            annotationView?.frame = CGRect(x: 0, y: 0, width: pinSize, height: pinSize)
            annotationView?.centerOffset = CGPoint(x: 0, y: -pinSize / 2)
            
            return annotationView
        }
        
        private func createDefaultPin(size: CGFloat, rating: Double) -> UIView {
            let pinColor: UIColor = {
                if rating >= 4.0 {
                    return .systemGreen
                } else if rating >= 3.0 {
                    return .systemYellow
                } else {
                    return .systemRed
                }
            }()
            
            let pinView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            pinView.backgroundColor = pinColor
            pinView.layer.cornerRadius = size / 2
            pinView.layer.borderWidth = 2
            pinView.layer.borderColor = UIColor.white.cgColor
            
            let scoreLabel = UILabel()
            scoreLabel.text = rating > 0 ? String(format: "%.1f", rating) : "–"
            scoreLabel.font = .systemFont(ofSize: 11, weight: .bold)
            scoreLabel.textColor = .white
            scoreLabel.textAlignment = .center
            scoreLabel.frame = pinView.bounds
            
            pinView.addSubview(scoreLabel)
            return pinView
        }
        
        /// Simplified Sip Squad pin style: Mugshot Mint color with rating displayed
        private func createMintPin(size: CGFloat, rating: Double) -> UIView {
            // Mugshot Mint color (from DS.Colors.primaryAccent)
            let mintColor = UIColor(red: 183/255, green: 226/255, blue: 181/255, alpha: 1.0) // #B7E2B5
            let textColor = UIColor(red: 5/255, green: 46/255, blue: 22/255, alpha: 1.0) // #052E16 (textOnMint)
            
            let pinView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            pinView.backgroundColor = mintColor
            pinView.layer.cornerRadius = size / 2
            pinView.layer.borderWidth = 2
            pinView.layer.borderColor = UIColor.white.cgColor
            
            // Add subtle shadow for depth
            pinView.layer.shadowColor = UIColor.black.cgColor
            pinView.layer.shadowOffset = CGSize(width: 0, height: 2)
            pinView.layer.shadowOpacity = 0.15
            pinView.layer.shadowRadius = 4
            
            let scoreLabel = UILabel()
            scoreLabel.text = rating > 0 ? String(format: "%.1f", rating) : "–"
            scoreLabel.font = .systemFont(ofSize: 11, weight: .bold)
            scoreLabel.textColor = textColor
            scoreLabel.textAlignment = .center
            scoreLabel.frame = pinView.bounds
            
            pinView.addSubview(scoreLabel)
            return pinView
        }
        
        private func createHeartPin(size: CGFloat, rating: Double) -> UIView {
            let pinColor: UIColor = {
                if rating >= 4.0 {
                    return .systemGreen
                } else if rating >= 3.0 {
                    return .systemYellow
                } else {
                    return .systemRed
                }
            }()
            
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            containerView.backgroundColor = .clear
            
            // Heart shape using SF Symbol
            let heartImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            let heartImage = UIImage(systemName: "heart.fill")
            heartImageView.image = heartImage
            heartImageView.tintColor = pinColor
            heartImageView.contentMode = .scaleAspectFit
            
            // Score label centered on heart
            let scoreLabel = UILabel()
            if rating > 0 {
                scoreLabel.text = String(format: "%.1f", rating)
            } else {
                scoreLabel.text = "–"
            }
            scoreLabel.font = .systemFont(ofSize: 10, weight: .bold)
            scoreLabel.textColor = .white
            scoreLabel.textAlignment = .center
            scoreLabel.frame = CGRect(x: 0, y: size * 0.3, width: size, height: size * 0.4)
            
            containerView.addSubview(heartImageView)
            containerView.addSubview(scoreLabel)
            
            return containerView
        }
        
        private func createBookmarkPin(size: CGFloat, rating: Double) -> UIView {
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            containerView.backgroundColor = .clear
            
            // Bookmark shape using SF Symbol (blue for Want to Try)
            let bookmarkImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            let bookmarkImage = UIImage(systemName: "bookmark.fill")
            bookmarkImageView.image = bookmarkImage
            bookmarkImageView.tintColor = .systemBlue
            bookmarkImageView.contentMode = .scaleAspectFit
            
            // Score label if rating exists
            if rating > 0 {
                let scoreLabel = UILabel()
                scoreLabel.text = String(format: "%.1f", rating)
                scoreLabel.font = .systemFont(ofSize: 10, weight: .bold)
                scoreLabel.textColor = .white
                scoreLabel.textAlignment = .center
                scoreLabel.frame = CGRect(x: 0, y: size * 0.25, width: size, height: size * 0.4)
                containerView.addSubview(scoreLabel)
            }
            
            containerView.addSubview(bookmarkImageView)
            
            return containerView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let cafeAnnotation = view.annotation as? CafeAnnotation else { return }
            onCafeTap(cafeAnnotation.cafe)
        }
    }
}

// MARK: - Cafe Annotation

class CafeAnnotation: NSObject, MKAnnotation {
    let cafe: Cafe
    var coordinate: CLLocationCoordinate2D {
        // PERFORMANCE: Return location directly without debug logging in hot path
        return cafe.location ?? CLLocationCoordinate2D()
    }
    
    init(cafe: Cafe) {
        self.cafe = cafe
        super.init()
    }
}


// MARK: - Ratings Legend

struct RatingsLegend: View {
    var isSipSquadMode: Bool = false
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(isSipSquadMode ? "SIP SQUAD RATINGS" : "YOUR RATINGS")
                .font(DS.Typography.metaLabel)
                .foregroundColor(DS.Colors.textSecondary)
                .tracking(0.5)
            
            HStack(spacing: DS.Spacing.section) {
                LegendItem(color: DS.Colors.positiveChange, text: "≥ 4.0")
                LegendItem(color: DS.Colors.neutralChange, text: "3.0–3.9")
                LegendItem(color: DS.Colors.negativeChange, text: "< 3.0")
                LegendItem(icon: "bookmark.fill", color: DS.Colors.secondaryAccent, text: "Want to try")
            }
            
            Text("Tap pins for details.")
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.cardBackground.opacity(0.95))
        .cornerRadius(DS.Radius.card)
        .dsCardShadow()
    }
}

struct LegendItem: View {
    var icon: String? = nil
    var color: Color
    var text: String
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(DS.Typography.caption2())
                    .foregroundColor(color)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            Text(text)
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

// MARK: - Location Banner

struct LocationBanner: View {
    @State private var showSettings = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash")
                .foregroundColor(DS.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Location access is off")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text("You can still use Mugshot, but the map won't follow you.")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
            
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        .font(DS.Typography.caption1())
            .foregroundColor(DS.Colors.primaryAccent)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.card)
    }
}

// MARK: - Sip Squad Banner

struct SipSquadBanner: View {
    let hasFriends: Bool
    let friendCafeCount: Int
    let onDismiss: () -> Void
    let onFindFriends: () -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if !hasFriends {
                // No friends - show CTA to add friends
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 20))
                        .foregroundColor(DS.Colors.textOnMint)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Add friends to unlock Sip Squad Mode!")
                            .font(DS.Typography.caption1(.semibold))
                            .foregroundColor(DS.Colors.textOnMint)
                    }
                    
                    Spacer()
                    
                    Button(action: onFindFriends) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text("Find Friends")
                                .font(DS.Typography.caption1(.semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(DS.Colors.primaryAccent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.lg)
                    }
                }
            } else if friendCafeCount == 0 {
                // Has friends but no friend visits
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DS.Colors.textOnMint)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Sip Squad Mode")
                            .font(DS.Typography.caption1(.semibold))
                            .foregroundColor(DS.Colors.textOnMint)
                        
                        Text("Your Sip Squad hasn't logged any cafés yet.")
                            .font(DS.Typography.caption2())
                            .foregroundColor(DS.Colors.textOnMint.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DS.Colors.textOnMint)
                            .frame(width: 28, height: 28)
                    }
                }
            } else {
                // Active Sip Squad mode with data
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DS.Colors.textOnMint)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Sip Squad Mode")
                            .font(DS.Typography.caption1(.semibold))
                            .foregroundColor(DS.Colors.textOnMint)
                        
                        Text("Showing cafés visited by you and your friends.")
                            .font(DS.Typography.caption2())
                            .foregroundColor(DS.Colors.textOnMint.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DS.Colors.textOnMint)
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.primaryAccent)
        .cornerRadius(DS.Radius.card)
        .dsCardShadow()
    }
}

// MARK: - My Location Button

struct MyLocationButton: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var region: MKCoordinateRegion
    @Binding var recenterOnUserRequest: Bool
    @State private var showMessage = false
    
    var body: some View {
        VStack(spacing: 8) {
            if showMessage {
                Text("We don't have your location yet")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.md)
                    .dsCardShadow()
            }
            
            Button(action: {
                // Haptic: confirm recenter button tap
                HapticsManager.shared.lightTap()
                
                let status = locationManager.authorizationStatus
                
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    // Try to recenter immediately using the last known location, if available
                    if let location = locationManager.getCurrentLocation() {
                        withAnimation {
                            region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        }
                        // We already recentred, no need to wait for the next update
                        recenterOnUserRequest = false
                        showMessage = false
                    } else {
                        // No current location yet – ask for one and let the onChange handler recenter
                        recenterOnUserRequest = true
                        locationManager.requestCurrentLocation()
                        showMessage = false
                    }
                } else {
                    // No permission - show message
                    recenterOnUserRequest = false
                    showMessage = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showMessage = false
                        }
                    }
                }
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 18))
                    .foregroundColor(DS.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.cardBackground)
                    .clipShape(Circle())
                    .dsCardShadow()
            }
        }
    }
}

// MARK: - Sip Squad Toggle Button

struct SipSquadToggleButton: View {
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: isActive ? "person.2.fill" : "person.2")
                .font(.system(size: 18))
                .foregroundColor(isActive ? DS.Colors.primaryAccent : DS.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(isActive ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isActive ? DS.Colors.primaryAccent : Color.clear, lineWidth: 2)
                )
                .dsCardShadow()
        }
    }
}

// MARK: - Legacy CafeDetailSheet removed
// The unified café experience is now handled by UnifiedCafeView

