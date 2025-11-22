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
    
    @State private var region: MKCoordinateRegion?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var hasRequestedLocation = false
    @State private var hasInitializedLocation = false
    @State private var showLocationMessage = false
    @State private var showNotifications = false
    @State private var selectedVisit: Visit?
    @State private var recenterOnUserRequest = false
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    // Default fallback region (SF) - only used if location unavailable
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
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
                onCafeTap: { cafe in
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
                
                // Inline search bar
                HStack(spacing: DS.Spacing.lg) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        TextField("Search cafes...", text: $searchText)
                            .foregroundColor(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                            .accentColor(DS.Colors.primaryAccent)
                            .onChange(of: searchText) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    isSearchActive = true
                                    searchService.search(query: newValue, region: region ?? defaultRegion)
                                } else {
                                    searchService.cancelSearch()
                                    isSearchActive = false
                                }
                            }
                            .onTapGesture {
                                isSearchActive = true
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
                    SearchResultsList(
                        searchText: $searchText,
                        searchService: searchService,
                        dataManager: dataManager,
                        region: Binding(
                            get: { region ?? defaultRegion },
                            set: { region = $0 }
                        ),
                        selectedCafe: $selectedCafe,
                        showCafeDetail: $showCafeDetail,
                        isSearchActive: $isSearchActive
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // My Location button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MyLocationButton(
                            locationManager: locationManager,
                            region: Binding(
                                get: { region ?? defaultRegion },
                                set: { region = $0 }
                            ),
                            recenterOnUserRequest: $recenterOnUserRequest
                        )
                        .padding(.trailing)
                        .padding(.bottom, 100)
                    }
                }
            }
            
            // Ratings Legend - sticky at bottom above tab bar
            VStack {
                Spacer()
                if !showCafeDetail {
                    RatingsLegend()
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.bottom, DS.Spacing.sm)
                        .transition(.opacity)
                }
            }
            
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
    
    private var cafesWithLocations: [Cafe] {
        // Show cafes that have a map location and are either:
        // - Logged at least once (visitCount > 0), or
        // - Marked as favorite, or
        // - Marked as "Want to Try"
        let filtered = dataManager.appData.cafes.filter { cafe in
            guard let location = cafe.location else {
                // Log cafes without location for debugging
                #if DEBUG
                if cafe.visitCount > 0 {
                    print("⚠️ [Map] Cafe '\(cafe.name)' has visitCount=\(cafe.visitCount) but no location")
                }
                #endif
                return false
            }
            // Ensure coordinates are valid
            guard abs(location.latitude) <= 90 && abs(location.longitude) <= 180 else {
                #if DEBUG
                print("⚠️ [Map] Cafe '\(cafe.name)' has invalid coordinates: (\(location.latitude), \(location.longitude))")
                #endif
                return false
            }
            return cafe.visitCount > 0 || cafe.isFavorite || cafe.wantToTry
        }
        #if DEBUG
        print("🗺️ [Map] Showing \(filtered.count) cafes with locations (total cafes: \(dataManager.appData.cafes.count))")
        #endif
        return filtered
    }
}

// MARK: - Map View Representable (to hide POIs)

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let cafes: [Cafe]
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
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed
        if abs(mapView.region.center.latitude - region.center.latitude) > 0.001 ||
           abs(mapView.region.center.longitude - region.center.longitude) > 0.001 {
            mapView.setRegion(region, animated: true)
        }
        
        // Update annotations - refresh all to handle Favorite/Want to Try state changes
        let existingAnnotations = mapView.annotations.compactMap { $0 as? CafeAnnotation }
        let existingCafeIds = Set(existingAnnotations.map { $0.cafe.id })
        let currentCafeIds = Set(cafes.map { $0.id })
        
        // Remove annotations for cafes that no longer exist
        let toRemove = existingAnnotations.filter { !currentCafeIds.contains($0.cafe.id) }
        mapView.removeAnnotations(toRemove)
        
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
        mapView.addAnnotations(newAnnotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCafeTap: onCafeTap)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let onCafeTap: (Cafe) -> Void
        
        init(onCafeTap: @escaping (Cafe) -> Void) {
            self.onCafeTap = onCafeTap
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return nil }
            
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
            
            // Determine pin style based on Favorite/Want to Try
            let pinSize: CGFloat = 36
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: pinSize, height: pinSize))
            containerView.backgroundColor = .clear
            
            // Priority: Want to Try > Favorite > Default
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
        cafe.location ?? CLLocationCoordinate2D()
    }
    
    init(cafe: Cafe) {
        self.cafe = cafe
        super.init()
    }
}


// MARK: - Ratings Legend

struct RatingsLegend: View {
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("YOUR RATINGS")
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
                let status = locationManager.authorizationStatus
                
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    // Request fresh location update and mark that we want to recenter
                    recenterOnUserRequest = true
                    locationManager.requestCurrentLocation()
                    
                    // If we already have a recent location, recenter immediately
                    if let location = locationManager.getCurrentLocation() {
                        withAnimation {
                            region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        }
                        recenterOnUserRequest = false
                        showMessage = false
                    }
                } else {
                    // No permission - show message
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

// MARK: - Search Results List

struct SearchResultsList: View {
    @Binding var searchText: String
    @ObservedObject var searchService: MapSearchService
    @ObservedObject var dataManager: DataManager
    @Binding var region: MKCoordinateRegion
    @Binding var selectedCafe: Cafe?
    @Binding var showCafeDetail: Bool
    @Binding var isSearchActive: Bool
    
    var body: some View {
        ZStack {
            DS.Colors.cardBackground
            
            if searchService.isSearching {
                ProgressView()
                    .padding(DS.Spacing.md)
            } else if let error = searchService.searchError {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    Text(error)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                }
                .padding(DS.Spacing.md)
            } else if searchService.searchResults.isEmpty && !searchService.isSearching && !searchText.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Text("No results found")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.md)
            } else if !searchText.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchService.searchResults, id: \.self) { mapItem in
                            SearchResultRow(
                                mapItem: mapItem,
                                region: region,
                                onTap: {
                                    handleSearchResult(mapItem)
                                }
                            )
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .padding(.vertical, DS.Spacing.sm)
                        }
                    }
                }
            } else {
                // Show local cafes when search is empty
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(dataManager.appData.cafes) { cafe in
                            LocalCafeRow(
                                cafe: cafe,
                                onTap: {
                                    selectedCafe = cafe
                                    showCafeDetail = true
                                    isSearchActive = false
                                    
                                    if let location = cafe.location {
                                        withAnimation {
                                            region = MKCoordinateRegion(
                                                center: location,
                                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                            )
                                        }
                                    }
                                }
                            )
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .padding(.vertical, DS.Spacing.sm)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
        .cornerRadius(DS.Radius.card, corners: [.bottomLeft, .bottomRight] as UIRectCorner)
    }
    
    private func handleSearchResult(_ mapItem: MKMapItem) {
        guard let location = mapItem.placemark.location?.coordinate else { return }
        
        // Center map on result
        withAnimation {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // Find or create cafe
        let cafe = dataManager.findOrCreateCafe(from: mapItem)
        
        // Show pin card
        selectedCafe = cafe
        showCafeDetail = true
        isSearchActive = false
        searchText = ""
        searchService.cancelSearch()
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let mapItem: MKMapItem
    let region: MKCoordinateRegion
    let onTap: () -> Void
    
    var distance: String {
        guard let itemLocation = mapItem.placemark.location else { return "" }
        let regionCenter = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let distanceInMeters = itemLocation.distance(from: regionCenter)
        
        if distanceInMeters < 1000 {
            return String(format: "%.0f m", distanceInMeters)
        } else {
            return String(format: "%.1f km", distanceInMeters / 1000)
        }
    }
    
    var subtitle: String {
        var components: [String] = []
        if let thoroughfare = mapItem.placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = mapItem.placemark.locality {
            components.append(locality)
        }
        return components.joined(separator: ", ")
    }
    
    var body: some View {
        Button(action: onTap) {
            DSBaseCard {
                HStack(spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(mapItem.name ?? "Unknown")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                        
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !distance.isEmpty {
                        Text(distance)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.iconSubtle)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Local Cafe Row

struct LocalCafeRow: View {
    let cafe: Cafe
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            DSBaseCard {
                HStack(spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(cafe.name)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                        
                        if !cafe.address.isEmpty {
                            Text(cafe.address)
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if cafe.averageRating > 0 {
                        DSScoreBadge(score: cafe.averageRating)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.iconSubtle)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
