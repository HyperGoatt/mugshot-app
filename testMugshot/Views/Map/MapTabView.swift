//
//  MapTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapTabView: View {
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
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
    @State private var remoteStateError: String?
    @State private var mapFilter: MapPinFilter = .all

    enum MapPinFilter: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case wantToTry = "Want to Try"
        case visited = "Visited"

        var iconName: String {
            switch self {
            case .all:
                return "map.fill"
            case .favorites:
                return "heart.fill"
            case .wantToTry:
                return "bookmark.fill"
            case .visited:
                return "cup.and.saucer.fill"
            }
        }
    }
    
    // Default fallback region (SF) - only used if location unavailable
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
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
                // When we get a location update and we have permission, center the map
                if let location = newLocation {
                    let isAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
                    
                    if isAuthorized {
                        // If we haven't initialized yet, or if this is a fresh location update
                        if !hasInitializedLocation || (oldValue == nil) {
                            hasInitializedLocation = true
                            withAnimation {
                                region = MKCoordinateRegion(
                                    center: location.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                )
                            }
                        }
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
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Inline search bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.espressoBrown.opacity(0.55))

                        TextField("Search cafes or neighborhoods...", text: $searchText)
                            .foregroundColor(.inputText)
                            .tint(.mugshotForest)
                            .accentColor(.mugshotForest)
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
                                    .foregroundColor(.espressoBrown.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.creamWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.sandBeige.opacity(0.8), lineWidth: 1))
                    .shadow(
                        color: DesignSystem.cardShadow.color,
                        radius: DesignSystem.cardShadow.radius,
                        x: DesignSystem.cardShadow.x,
                        y: DesignSystem.cardShadow.y
                    )

                    if isSearchActive {
                        Button("Cancel") {
                            searchText = ""
                            searchService.cancelSearch()
                            isSearchActive = false
                        }
                        .foregroundColor(.espressoBrown)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, isSearchActive ? 12 : 8)
                .background(Color.mugshotCanvas.opacity(isSearchActive ? 0.97 : 0))
                .animation(.easeInOut(duration: 0.2), value: isSearchActive)

                // Pin filter chips
                if !isSearchActive {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MapPinFilter.allCases, id: \.self) { filter in
                                MugFilterChip(
                                    title: filter.rawValue,
                                    systemImage: filter.iconName,
                                    isSelected: mapFilter == filter
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        mapFilter = filter
                                    }
                                }
                                .shadow(color: Color.espressoBrown.opacity(0.08), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
                
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
                            )
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
                        .padding(.horizontal)
                        .padding(.bottom, 8)
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
                        onLogVisitRequested: onLogVisitRequested // Pass the closure
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: authModel.authenticatedUser?.id) {
            await loadRemoteCafeStates()
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
        // Show visited cafes and durable saved/wishlist cafes with locations,
        // narrowed by the active pin filter.
        dataManager.appData.cafes.filter { cafe in
            guard cafe.location != nil,
                  cafe.visitCount > 0 || cafe.isFavorite || cafe.wantToTry else {
                return false
            }

            switch mapFilter {
            case .all:
                return true
            case .favorites:
                return cafe.isFavorite
            case .wantToTry:
                return cafe.wantToTry
            case .visited:
                return cafe.visitCount > 0
            }
        }
    }

    @MainActor
    private func loadRemoteCafeStates() async {
        guard let userId = authModel.authenticatedUser?.id else {
            remoteStateError = nil
            return
        }

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CafeStateService(client: client)
            let states = try await service.fetchCafeStates(userId: userId)
            dataManager.applyRemoteCafeStates(states)
            remoteStateError = nil
        } catch {
            remoteStateError = "Could not sync saved cafes."
        }
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
        
        private func ratingPinColor(for rating: Double) -> UIColor {
            if rating >= 4.0 {
                return MapPinPalette.forest
            } else if rating >= 3.0 {
                return MapPinPalette.tan
            } else if rating > 0 {
                return MapPinPalette.clay
            } else {
                return MapPinPalette.espresso
            }
        }

        private func createDefaultPin(size: CGFloat, rating: Double) -> UIView {
            let pinView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            pinView.backgroundColor = ratingPinColor(for: rating)
            pinView.layer.cornerRadius = size / 2
            pinView.layer.borderWidth = 2
            pinView.layer.borderColor = MapPinPalette.cream.cgColor
            pinView.layer.shadowColor = UIColor.black.cgColor
            pinView.layer.shadowOpacity = 0.18
            pinView.layer.shadowRadius = 3
            pinView.layer.shadowOffset = CGSize(width: 0, height: 2)

            let scoreLabel = UILabel()
            scoreLabel.text = rating > 0 ? String(format: "%.1f", rating) : "☕︎"
            scoreLabel.font = .systemFont(ofSize: 11, weight: .bold)
            scoreLabel.textColor = MapPinPalette.cream
            scoreLabel.textAlignment = .center
            scoreLabel.frame = pinView.bounds

            pinView.addSubview(scoreLabel)
            return pinView
        }

        private func createHeartPin(size: CGFloat, rating: Double) -> UIView {
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            containerView.backgroundColor = .clear

            // Heart shape using SF Symbol
            let heartImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            let heartImage = UIImage(systemName: "heart.fill")
            heartImageView.image = heartImage
            heartImageView.tintColor = ratingPinColor(for: rating)
            heartImageView.contentMode = .scaleAspectFit

            // Score label centered on heart
            let scoreLabel = UILabel()
            if rating > 0 {
                scoreLabel.text = String(format: "%.1f", rating)
            } else {
                scoreLabel.text = "–"
            }
            scoreLabel.font = .systemFont(ofSize: 10, weight: .bold)
            scoreLabel.textColor = MapPinPalette.cream
            scoreLabel.textAlignment = .center
            scoreLabel.frame = CGRect(x: 0, y: size * 0.3, width: size, height: size * 0.4)

            containerView.addSubview(heartImageView)
            containerView.addSubview(scoreLabel)

            return containerView
        }

        private func createBookmarkPin(size: CGFloat, rating: Double) -> UIView {
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            containerView.backgroundColor = .clear

            // Bookmark shape using SF Symbol (sage for Want to Try)
            let bookmarkImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            let bookmarkImage = UIImage(systemName: "bookmark.fill")
            bookmarkImageView.image = bookmarkImage
            bookmarkImageView.tintColor = MapPinPalette.sage
            bookmarkImageView.contentMode = .scaleAspectFit

            // Score label if rating exists
            if rating > 0 {
                let scoreLabel = UILabel()
                scoreLabel.text = String(format: "%.1f", rating)
                scoreLabel.font = .systemFont(ofSize: 10, weight: .bold)
                scoreLabel.textColor = MapPinPalette.espresso
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

// MARK: - Map Pin Palette

/// UIKit-side mirror of the brand palette for MKAnnotation pins.
enum MapPinPalette {
    static let forest = UIColor(red: 77 / 255, green: 107 / 255, blue: 84 / 255, alpha: 1)   // mugshotForest
    static let sage = UIColor(red: 130 / 255, green: 160 / 255, blue: 132 / 255, alpha: 1)   // deep sage
    static let tan = UIColor(red: 194 / 255, green: 163 / 255, blue: 112 / 255, alpha: 1)    // mugshotTan
    static let clay = UIColor(red: 184 / 255, green: 115 / 255, blue: 97 / 255, alpha: 1)    // mugshotClay
    static let espresso = UIColor(red: 61 / 255, green: 50 / 255, blue: 42 / 255, alpha: 1)  // espressoBrown
    static let cream = UIColor(red: 251 / 255, green: 248 / 255, blue: 242 / 255, alpha: 1)  // creamWhite
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
        VStack(spacing: 8) {
            Text("YOUR RATINGS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.7))
                .tracking(0.5)
            
            HStack(spacing: 16) {
                LegendItem(color: .mugshotForest, text: "≥ 4.0")
                LegendItem(color: .mugshotTan, text: "3.0–3.9")
                LegendItem(color: .mugshotClay, text: "< 3.0")
                LegendItem(icon: "bookmark.fill", color: .mugshotForest, text: "Want to try")
            }
            
            Text("Tap pins for details.")
                .font(.system(size: 10))
                .foregroundColor(.espressoBrown.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.creamWhite.opacity(0.95))
        .cornerRadius(DesignSystem.cornerRadius)
        .shadow(
            color: DesignSystem.cardShadow.color,
            radius: DesignSystem.cardShadow.radius,
            x: DesignSystem.cardShadow.x,
            y: DesignSystem.cardShadow.y
        )
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
                    .font(.system(size: 10))
                    .foregroundColor(color)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.espressoBrown.opacity(0.7))
        }
    }
}

// MARK: - Location Banner

struct LocationBanner: View {
    @State private var showSettings = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash")
                .foregroundColor(.espressoBrown.opacity(0.7))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Location access is off")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.espressoBrown)
                
                Text("You can still use Mugshot, but the map won't follow you.")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.7))
            }
            
            Spacer()
            
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.mugshotForest)
        }
        .padding()
        .background(Color.sandBeige)
        .cornerRadius(DesignSystem.cornerRadius)
    }
}

// MARK: - My Location Button

struct MyLocationButton: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var region: MKCoordinateRegion
    @State private var showMessage = false
    
    var body: some View {
        VStack(spacing: 8) {
            if showMessage {
                Text("We don't have your location yet")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.creamWhite)
                    .cornerRadius(DesignSystem.smallCornerRadius)
                    .shadow(
                        color: DesignSystem.cardShadow.color,
                        radius: DesignSystem.cardShadow.radius,
                        x: DesignSystem.cardShadow.x,
                        y: DesignSystem.cardShadow.y
                    )
            }
            
            Button(action: {
                let status = locationManager.authorizationStatus
                
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    // Request fresh location update
                    locationManager.requestCurrentLocation()
                    
                    // Try to get current location
                    if let location = locationManager.getCurrentLocation() {
                        withAnimation {
                            region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        }
                        showMessage = false
                    } else {
                        // Location not available yet, show message
                        showMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showMessage = false
                            }
                        }
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
                    .foregroundColor(.espressoBrown)
                    .frame(width: 44, height: 44)
                    .background(Color.creamWhite)
                    .clipShape(Circle())
                    .shadow(
                        color: DesignSystem.cardShadow.color,
                        radius: DesignSystem.cardShadow.radius,
                        x: DesignSystem.cardShadow.x,
                        y: DesignSystem.cardShadow.y
                    )
            }
        }
    }
}

// MARK: - Cafe Detail Sheet

struct CafeDetailSheet: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @Binding var isPresented: Bool
    var onLogVisitRequested: ((Cafe) -> Void)? = nil // Optional closure for navigation
    @State private var showLogVisit = false
    @State private var showFullDetails = false
    @State private var selectedVisit: Visit?
    @State private var isSyncingCafeState = false
    @State private var cafeStateError: String?
    
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

    private var displayedVisitCount: Int {
        max(displayCafe.visitCount, visits.count)
    }

    private var displayedScore: Double {
        displayCafe.averageRating > 0 ? displayCafe.averageRating : 0.0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.espressoBrown.opacity(0.22))
                .frame(width: 54, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 12) {
                cafeIdentityBlock

                Button {
                    withAnimation {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.espressoBrown.opacity(0.48))
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mapSheetStats
                    
                    mapSheetActions

                    if let cafeStateError {
                        Text(cafeStateError)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    mapSheetRecentVisits
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.largeCornerRadius, corners: [.topLeft, .topRight])
        .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
        .sheet(isPresented: $showLogVisit) {
            LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
        }
        .sheet(isPresented: $showFullDetails) {
            CafeDetailView(cafe: cafe, dataManager: dataManager)
        }
        .fullScreenCover(item: $selectedVisit) { visit in
            VisitDetailView(visit: visit, dataManager: dataManager)
        }
    }

    private var cafeIdentityBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(displayCafe.name)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !displayCafe.address.isEmpty {
                Label(displayCafe.address, systemImage: "mappin.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.espressoBrown.opacity(0.65))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if displayCafe.isFavorite {
                    mapSheetPill("Favorite", systemImage: "heart.fill")
                }

                if displayCafe.wantToTry {
                    mapSheetPill("Want to Try", systemImage: "bookmark.fill")
                }

                if let category = displayCafe.placeCategory?.remoteTrimmedNonEmpty {
                    mapSheetPill(category, systemImage: "tag.fill")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mapSheetStats: some View {
        HStack(spacing: 10) {
            mapSheetStatCard(
                title: "Average",
                value: String(format: "%.1f", displayedScore),
                systemImage: "star.fill"
            )

            mapSheetStatCard(
                title: "Visits",
                value: "\(displayedVisitCount)",
                systemImage: "cup.and.saucer.fill"
            )
        }
    }

    private var mapSheetActions: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(spacing: 12) {
            Button {
                if let onLogVisit = onLogVisitRequested {
                    onLogVisit(displayCafe)
                } else {
                    showLogVisit = true
                }
            } label: {
                Label("Log Visit", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            LazyVGrid(columns: columns, spacing: 10) {
                mapSheetActionButton(
                    title: "Favorite",
                    systemImage: displayCafe.isFavorite ? "heart.fill" : "heart",
                    isSelected: displayCafe.isFavorite,
                    action: toggleFavorite
                )
                .disabled(isSyncingCafeState)

                mapSheetActionButton(
                    title: "Want to Try",
                    systemImage: displayCafe.wantToTry ? "bookmark.fill" : "bookmark",
                    isSelected: displayCafe.wantToTry,
                    action: toggleWantToTry
                )
                .disabled(isSyncingCafeState)

                mapSheetActionButton(
                    title: "Details",
                    systemImage: "list.bullet.rectangle",
                    isSelected: false
                ) {
                    showFullDetails = true
                }

                mapSheetActionButton(
                    title: "Directions",
                    systemImage: "location.north.circle",
                    isSelected: false,
                    action: openInMaps
                )
            }
        }
    }

    @ViewBuilder
    private var mapSheetRecentVisits: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Visits")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.espressoBrown)

            if visits.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.34))

                    Text("No visits here yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text("Log this cafe to add it to your taste journal.")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.62))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 14)
                .background(Color.sandBeige.opacity(0.34))
                .cornerRadius(DesignSystem.cornerRadius)
            } else {
                ForEach(visits.prefix(5)) { visit in
                    VisitEntryRow(visit: visit)
                        .onTapGesture {
                            selectedVisit = visit
                        }
                }
            }
        }
        .padding(.top, 2)
    }

    private func mapSheetPill(_ title: String, systemImage: String) -> some View {
        MugTagChip(title: title, systemImage: systemImage)
    }

    private func mapSheetStatCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.58))

            Text(value)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.espressoBrown)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.sandBeige.opacity(0.34))
        .cornerRadius(DesignSystem.cornerRadius)
    }

    private func mapSheetActionButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? Color.mugshotMint.opacity(0.34) : Color.sandBeige.opacity(0.55))
                .cornerRadius(DesignSystem.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(isSelected ? Color.mugshotForest : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func toggleFavorite() {
        let nextFavorite = !displayCafe.isFavorite
        updateCafeState(isFavorite: nextFavorite, wantToTry: displayCafe.wantToTry)
    }

    private func toggleWantToTry() {
        let nextWantToTry = !displayCafe.wantToTry
        updateCafeState(isFavorite: displayCafe.isFavorite, wantToTry: nextWantToTry)
    }

    private func openInMaps() {
        guard let location = displayCafe.location else { return }

        if let mapURLString = displayCafe.mapItemURL, let url = URL(string: mapURLString) {
            UIApplication.shared.open(url)
        } else {
            let encodedName = displayCafe.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(encodedName)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func updateCafeState(isFavorite: Bool, wantToTry: Bool) {
        let previousCafe = displayCafe
        dataManager.setCafeState(
            cafeId: previousCafe.id,
            isFavorite: isFavorite,
            wantToTry: wantToTry
        )

        guard let userId = authModel.authenticatedUser?.id else {
            return
        }

        Task {
            await saveRemoteCafeState(
                previousCafe: previousCafe,
                isFavorite: isFavorite,
                wantToTry: wantToTry,
                userId: userId
            )
        }
    }

    @MainActor
    private func saveRemoteCafeState(
        previousCafe: Cafe,
        isFavorite: Bool,
        wantToTry: Bool,
        userId: UUID
    ) async {
        isSyncingCafeState = true
        cafeStateError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CafeStateService(client: client)
            let summary = try await service.setCafeState(
                userId: userId,
                cafe: previousCafe,
                isFavorite: isFavorite,
                wantToTry: wantToTry
            )
            dataManager.applyRemoteCafeState(summary)
            isSyncingCafeState = false
        } catch {
            dataManager.setCafeState(
                cafeId: previousCafe.id,
                isFavorite: previousCafe.isFavorite,
                wantToTry: previousCafe.wantToTry
            )
            cafeStateError = "Could not save cafe state."
            isSyncingCafeState = false
        }
    }
}

// MARK: - Visit Entry Row

struct VisitEntryRow: View {
    let visit: Visit
    
    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(photoPath: visit.posterImagePath, size: 50)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
            
            VStack(alignment: .leading, spacing: 5) {
                Text(visit.drinkType.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)

                Text(visit.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.58))
                
                if !visit.caption.isEmpty {
                    Text(visit.caption)
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.68))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            MugScoreBadge(score: visit.overallScore, size: .compact)
        }
        .padding(12)
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
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
            Color.creamWhite
            
            if searchService.isSearching {
                ProgressView()
                    .padding()
            } else if let error = searchService.searchError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.espressoBrown.opacity(0.5))
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else if searchService.searchResults.isEmpty && !searchService.isSearching && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Text("No results found")
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
                .padding()
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
                        }
                    }
                }
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
        .cornerRadius(DesignSystem.cornerRadius, corners: [.bottomLeft, .bottomRight])
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mapItem.name ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.espressoBrown)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if !distance.isEmpty {
                    Text(distance)
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.6))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.4))
            }
            .padding()
            .background(Color.creamWhite)
        }
        .buttonStyle(.plain)
        Divider()
            .padding(.leading)
    }
}

// MARK: - Local Cafe Row

struct LocalCafeRow: View {
    let cafe: Cafe
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.espressoBrown)
                    
                    if !cafe.address.isEmpty {
                        Text(cafe.address)
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if cafe.averageRating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.mugshotForest)
                            .font(.system(size: 12))
                        Text(String(format: "%.1f", cafe.averageRating))
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.4))
            }
            .padding()
            .background(Color.creamWhite)
        }
        .buttonStyle(.plain)
        Divider()
            .padding(.leading)
    }
}

// MARK: - Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
