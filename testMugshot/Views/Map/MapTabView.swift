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
    @StateObject private var hapticsManager = HapticsManager.shared
    
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
    
    private var referenceLocation: CLLocation {
        let activeRegion = region ?? defaultRegion
        return CLLocation(latitude: activeRegion.center.latitude, longitude: activeRegion.center.longitude)
    }
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    // Sip Squad mode state (bound to persisted AppData)
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
    private var useSipSquadSimplifiedStyle: Bool {
        isSipSquadMode && dataManager.appData.useSipSquadSimplifiedStyle
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
                HStack(spacing: DS.Spacing.lg) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        TextField("Search cafes...", text: $searchText)
                            .foregroundColor(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                            .accentColor(DS.Colors.primaryAccent)
                            .focused($isSearchFieldFocused)
                            .onChange(of: searchText) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    if !isSearchActive {
                                        withAnimation {
                                            isSearchActive = true
                                        }
                                    }
                                    searchService.search(query: trimmed, region: region ?? defaultRegion)
                                } else {
                                    searchService.cancelSearch()
                                    if !isSearchFieldFocused {
                                        withAnimation {
                                            isSearchActive = false
                                        }
                                    }
                                }
                            }
                            .onChange(of: isSearchFieldFocused) { _, isFocused in
                                if isFocused {
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
                                isSearchActive = false
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
                        }
                        .foregroundColor(DS.Colors.textPrimary)
                        .transition(.opacity)
                    }
                    
                    // Notifications bell icon
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
                .padding(DS.Spacing.pagePadding)
                .background(DS.Colors.screenBackground.opacity(isSearchActive ? 0.95 : 0))
                .animation(.easeInOut(duration: 0.2), value: isSearchActive)
                
                // Search results list (inline below search bar)
                if isSearchActive {
                    CafeSearchResultsPanel(
                        searchText: $searchText,
                        searchService: searchService,
                        recentSearches: dataManager.appData.recentSearches,
                        showRecentSearches: shouldShowRecentSearches,
                        referenceLocation: referenceLocation,
                        onMapItemSelected: { mapItem in
                            handleSearchResult(mapItem)
                        },
                        onRecentSelected: { entry in
                            handleRecentSearch(entry)
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
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
            
            // Bottom sheet for cafe details
            if showCafeDetail, let cafe = selectedCafe {
                VStack {
                    Spacer()
                    CafeDetailSheet(
                        cafe: cafe,
                        dataManager: dataManager,
                        isPresented: $showCafeDetail,
                        onLogVisitRequested: onLogVisitRequested,
                        onVisitSelected: { visit in
                            selectedVisit = visit
                        }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsCenterView(dataManager: dataManager)
        }
        .sheet(isPresented: $showFriendsHub) {
            FriendsHubView(dataManager: dataManager)
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
            searchService.search(query: entry.query, region: region ?? defaultRegion)
            isSearchFieldFocused = true
        }
    }
    
    private var cafesWithLocations: [Cafe] {
        // In Sip Squad mode, show aggregated cafes from user + friends (or just user if no friends)
        if isSipSquadMode {
            let sipSquadCafes = dataManager.getSipSquadCafes()
            
            #if DEBUG
            print("🗺️ [Map] Sip Squad Mode - filtering \(sipSquadCafes.count) aggregated cafes")
            #endif
            
            let filtered = sipSquadCafes.filter { cafe in
                guard let location = cafe.location else {
                    #if DEBUG
                    print("  ❌ '\(cafe.name)' - NO LOCATION in Sip Squad mode")
                    #endif
                    return false
                }
                guard abs(location.latitude) <= 90 && abs(location.longitude) <= 180 else {
                    #if DEBUG
                    print("  ❌ '\(cafe.name)' - INVALID COORDS in Sip Squad mode: (\(location.latitude), \(location.longitude))")
                    #endif
                    return false
                }
                let qualifies = cafe.visitCount > 0 || cafe.isFavorite || cafe.wantToTry
                #if DEBUG
                if qualifies {
                    print("  ✅ '\(cafe.name)' - HAS LOCATION in Sip Squad mode at (\(location.latitude), \(location.longitude)), visitCount: \(cafe.visitCount)")
                } else {
                    print("  ⚠️ '\(cafe.name)' - HAS LOCATION but doesn't qualify in Sip Squad mode (visitCount: \(cafe.visitCount))")
                }
                #endif
                return qualifies
            }
            
            #if DEBUG
            print("🗺️ [Map] Sip Squad Mode - \(filtered.count) cafes with valid locations (from \(sipSquadCafes.count) total)")
            #endif
            
            return filtered
        }
        
        // Normal mode: Show cafes that have a map location and are either:
        // - Logged at least once (visitCount > 0), or
        // - Marked as favorite, or
        // - Marked as "Want to Try"
        let totalCafes = dataManager.appData.cafes.count
        #if DEBUG
        print("🗺️ [Map] Filtering cafes - total: \(totalCafes)")
        #endif
        
        let filtered = dataManager.appData.cafes.filter { cafe in
            // Check location first
            guard let location = cafe.location else {
                #if DEBUG
                print("  ❌ '\(cafe.name)' - NO LOCATION (visitCount: \(cafe.visitCount), favorite: \(cafe.isFavorite), wantToTry: \(cafe.wantToTry))")
                #endif
                return false
            }
            
            // Ensure coordinates are valid
            guard abs(location.latitude) <= 90 && abs(location.longitude) <= 180 else {
                #if DEBUG
                print("  ❌ '\(cafe.name)' - INVALID COORDS: (\(location.latitude), \(location.longitude))")
                #endif
                return false
            }
            
            // Check if cafe qualifies (has visits, favorite, or wantToTry)
            let qualifies = cafe.visitCount > 0 || cafe.isFavorite || cafe.wantToTry
            #if DEBUG
            if qualifies {
                print("  ✅ '\(cafe.name)' - HAS LOCATION at (\(location.latitude), \(location.longitude)), visitCount: \(cafe.visitCount), favorite: \(cafe.isFavorite), wantToTry: \(cafe.wantToTry)")
            } else {
                print("  ⚠️ '\(cafe.name)' - HAS LOCATION but doesn't qualify (visitCount: \(cafe.visitCount), favorite: \(cafe.isFavorite), wantToTry: \(cafe.wantToTry))")
            }
            #endif
            return qualifies
        }
        
        #if DEBUG
        print("🗺️ [Map] Filtered result: \(filtered.count) cafes will show pins (from \(totalCafes) total)")
        if filtered.isEmpty && totalCafes > 0 {
            print("⚠️ [Map] WARNING: No cafes passed filter! Check locations and visitCount/favorite/wantToTry flags")
        }
        #endif
        return filtered
    }
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
        
        #if DEBUG
        print("🗺️ [MapView] makeUIView called - initial cafes count: \(cafes.count)")
        #endif
        
        // Add initial annotations
        let initialAnnotations = cafes.map { CafeAnnotation(cafe: $0) }
        if !initialAnnotations.isEmpty {
            #if DEBUG
            print("🗺️ [MapView] Adding \(initialAnnotations.count) initial annotations")
            #endif
            mapView.addAnnotations(initialAnnotations)
        }
        
        return mapView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(useSipSquadSimplifiedStyle: useSipSquadSimplifiedStyle, onCafeTap: onCafeTap)
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update the coordinator's style flag
        context.coordinator.useSipSquadSimplifiedStyle = useSipSquadSimplifiedStyle
        
        // Update region if needed
        if abs(mapView.region.center.latitude - region.center.latitude) > 0.001 ||
           abs(mapView.region.center.longitude - region.center.longitude) > 0.001 {
            mapView.setRegion(region, animated: true)
        }
        
        #if DEBUG
        print("🗺️ [MapView] updateUIView called with \(cafes.count) cafes")
        for (index, cafe) in cafes.enumerated() {
            print("  [\(index)] \(cafe.name) - location: \(cafe.location != nil ? "✅" : "❌"), visitCount: \(cafe.visitCount), favorite: \(cafe.isFavorite), wantToTry: \(cafe.wantToTry)")
        }
        #endif
        
        // Update annotations - refresh all to handle Favorite/Want to Try state changes
        let existingAnnotations = mapView.annotations.compactMap { $0 as? CafeAnnotation }
        let existingCafeIds = Set(existingAnnotations.map { $0.cafe.id })
        let currentCafeIds = Set(cafes.map { $0.id })
        
        #if DEBUG
        print("🗺️ [MapView] Existing annotations: \(existingAnnotations.count), Current cafes: \(cafes.count)")
        #endif
        
        // Remove annotations for cafes that no longer exist
        let toRemove = existingAnnotations.filter { !currentCafeIds.contains($0.cafe.id) }
        if !toRemove.isEmpty {
            #if DEBUG
            print("🗺️ [MapView] Removing \(toRemove.count) annotations")
            #endif
            mapView.removeAnnotations(toRemove)
        }
        
        // Update existing annotations if cafe state changed (Favorite/Want to Try)
        for existingAnnotation in existingAnnotations {
            if let updatedCafe = cafes.first(where: { $0.id == existingAnnotation.cafe.id }) {
                // Check if Favorite/Want to Try state changed
                if existingAnnotation.cafe.isFavorite != updatedCafe.isFavorite ||
                   existingAnnotation.cafe.wantToTry != updatedCafe.wantToTry ||
                   existingAnnotation.cafe.averageRating != updatedCafe.averageRating {
                    // Remove and re-add to trigger view refresh
                    mapView.removeAnnotation(existingAnnotation)
                    let newAnnotation = CafeAnnotation(cafe: updatedCafe)
                    mapView.addAnnotation(newAnnotation)
                }
            }
        }
        
        // Add new annotations
        let toAdd = cafes.filter { !existingCafeIds.contains($0.id) }
        let newAnnotations = toAdd.map { CafeAnnotation(cafe: $0) }
        if !newAnnotations.isEmpty {
            #if DEBUG
            print("🗺️ [MapView] Adding \(newAnnotations.count) new annotations")
            for annotation in newAnnotations {
                print("  ➕ Adding pin for: \(annotation.cafe.name) at (\(annotation.coordinate.latitude), \(annotation.coordinate.longitude))")
            }
            #endif
            mapView.addAnnotations(newAnnotations)
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var useSipSquadSimplifiedStyle: Bool
        let onCafeTap: (Cafe) -> Void
        
        init(useSipSquadSimplifiedStyle: Bool, onCafeTap: @escaping (Cafe) -> Void) {
            self.useSipSquadSimplifiedStyle = useSipSquadSimplifiedStyle
            self.onCafeTap = onCafeTap
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            guard let cafeAnnotation = annotation as? CafeAnnotation else {
                #if DEBUG
                print("⚠️ [MapView] viewFor annotation: Not a CafeAnnotation, type: \(type(of: annotation))")
                #endif
                return nil
            }
            
            #if DEBUG
            print("🗺️ [MapView] Creating view for annotation: \(cafeAnnotation.cafe.name) at (\(cafeAnnotation.coordinate.latitude), \(cafeAnnotation.coordinate.longitude))")
            #endif
            
            let cafe = cafeAnnotation.cafe
            let identifier = cafe.isFavorite ? "FavoritePin" : (cafe.wantToTry ? "WantToTryPin" : "CafePin")
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                annotationView?.isEnabled = true
                annotationView?.isUserInteractionEnabled = true
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
        guard let location = cafe.location else {
            #if DEBUG
            print("⚠️ [CafeAnnotation] Cafe '\(cafe.name)' has nil location, returning (0,0)")
            #endif
            return CLLocationCoordinate2D()
        }
        return location
    }
    
    init(cafe: Cafe) {
        self.cafe = cafe
        super.init()
        #if DEBUG
        if cafe.location == nil {
            print("⚠️ [CafeAnnotation] Created annotation for '\(cafe.name)' but location is nil!")
        } else {
            print("✅ [CafeAnnotation] Created annotation for '\(cafe.name)' at (\(cafe.location!.latitude), \(cafe.location!.longitude))")
        }
        #endif
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

// MARK: - Cafe Detail Sheet

struct CafeDetailSheet: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    @Binding var isPresented: Bool
    var onLogVisitRequested: ((Cafe) -> Void)? = nil // Optional closure for navigation
    let onVisitSelected: (Visit) -> Void
    @State private var showLogVisit = false
    @State private var showFullDetails = false
    
    // Get current cafe state from dataManager to reflect real-time changes
    var currentCafe: Cafe? {
        dataManager.getCafe(id: cafe.id)
    }
    
    var displayCafe: Cafe {
        currentCafe ?? cafe
    }
    
    var visits: [Visit] {
        dataManager.getVisitsForCafe(cafe.id)
    }
    
    /// Get friends who have visited this cafe with their ratings
    private func getFriendVisitors() -> [WhosBeenIndicator.FriendVisitor] {
        let friendIds = dataManager.appData.friendsSupabaseUserIds
        guard !friendIds.isEmpty else { return [] }
        
        // Get all visits to this cafe
        let cafeVisits = dataManager.appData.visits.filter { $0.cafeId == cafe.id }
        
        // Filter to visits by friends and build visitor list
        var seenIds = Set<String>()
        var visitors: [WhosBeenIndicator.FriendVisitor] = []
        
        for visit in cafeVisits {
            guard let visitorId = visit.supabaseUserId,
                  friendIds.contains(visitorId),
                  !seenIds.contains(visitorId) else { continue }
            
            seenIds.insert(visitorId)
            
            visitors.append(WhosBeenIndicator.FriendVisitor(
                id: visitorId,
                displayName: visit.authorDisplayNameOrUsername,
                avatarURL: visit.authorAvatarURL,
                rating: visit.overallScore
            ))
        }
        
        // Sort by rating (highest first)
        return visitors.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    // Cafe name
                    Text(displayCafe.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    
                    // Address with location icon
                    if !displayCafe.address.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.espressoBrown.opacity(0.6))
                            Text(displayCafe.address)
                                .font(.system(size: 14))
                                .foregroundColor(.espressoBrown.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                // Close button
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.espressoBrown.opacity(0.6))
                }
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Rating and meta
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.mugshotMint)
                                .font(.system(size: 14))
                            Text(String(format: "%.1f", displayCafe.averageRating > 0 ? displayCafe.averageRating : 0.0))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                        }
                        
                        Text("·")
                            .foregroundColor(.espressoBrown.opacity(0.5))
                        
                        Text("\(displayCafe.visitCount) visit\(displayCafe.visitCount == 1 ? "" : "s")")
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Primary action - Log a Visit
                    Button(action: {
                        if let onLogVisit = onLogVisitRequested {
                            onLogVisit(displayCafe)
                        } else {
                            showLogVisit = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 16))
                            Text("Log a Visit")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.espressoBrown)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.mugshotMint)
                        .cornerRadius(DesignSystem.cornerRadius)
                    }
                    
                    // Secondary actions
                    HStack(spacing: 12) {
                        Button(action: {
                            // Haptic: confirm favorite toggle
                            HapticsManager.shared.lightTap()
                            dataManager.toggleCafeFavorite(cafe.id)
                        }) {
                            HStack {
                                Image(systemName: displayCafe.isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                Text("Favorite")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(displayCafe.isFavorite ? .espressoBrown : .espressoBrown.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.sandBeige)
                            .cornerRadius(DesignSystem.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                    .stroke(displayCafe.isFavorite ? Color.mugshotMint : Color.clear, lineWidth: 2)
                            )
                        }
                        
                        Button(action: {
                            // Haptic: confirm want-to-try toggle
                            HapticsManager.shared.lightTap()
                            dataManager.toggleCafeWantToTry(cafe.id)
                        }) {
                            HStack {
                                Image(systemName: displayCafe.wantToTry ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 14))
                                Text("Want to Try")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(displayCafe.wantToTry ? .espressoBrown : .espressoBrown.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.sandBeige)
                            .cornerRadius(DesignSystem.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                    .stroke(displayCafe.wantToTry ? Color.mugshotMint : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                    
                    // Details button
                    Button(action: {
                        showFullDetails = true
                    }) {
                        Text("Details")
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    
                    // "Who's Been?" Indicator - shows friends who visited this cafe
                    WhosBeenIndicator(friendVisitors: getFriendVisitors())
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Entries section
                    if visits.isEmpty {
                        Text("No entries yet. Be the first to log a visit!")
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Visits")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            
                            ForEach(visits.prefix(5)) { visit in
                                VisitEntryRow(visit: visit) {
                                    onVisitSelected(visit)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.largeCornerRadius, corners: [.topLeft, .topRight] as UIRectCorner)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
        .sheet(isPresented: $showLogVisit) {
            LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
        }
        .sheet(isPresented: $showFullDetails) {
            CafeDetailView(cafe: cafe, dataManager: dataManager)
        }
    }
}

// MARK: - Visit Entry Row

struct VisitEntryRow: View {
    let visit: Visit
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                PhotoThumbnailView(
                    photoPath: visit.posterImagePath,
                    remoteURL: visit.posterImagePath.flatMap { visit.remoteURL(for: $0) },
                    size: 50
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.date, style: .date)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.espressoBrown)
                    
                    if !visit.caption.isEmpty {
                        Text(visit.caption)
                            .font(.system(size: 12))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.mugshotMint)
                        .font(.system(size: 12))
                    Text(String(format: "%.1f", visit.overallScore))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                }
            }
        }
        .padding()
        .background(Color.sandBeige.opacity(0.5))
        .cornerRadius(DesignSystem.smallCornerRadius)
        .buttonStyle(.plain)
    }
}

