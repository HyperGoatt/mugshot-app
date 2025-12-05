//
//  SpinForASpotView.swift
//  testMugshot
//
//  A delightful fullscreen "Spin for a Spot" experience with:
//  - Mugshot-branded fortune wheel animation
//  - Apple Maps category-based café search
//  - Chain filtering (excludes Starbucks, Dunkin, Panera, etc.)
//  - Progressive haptics during spin
//  - Distance slider for radius control
//  - Celebratory confetti explosion when result is displayed
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Preference Key for Image Position

struct ImagePositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// MARK: - Main View

struct SpinForASpotView: View {
    @Binding var isPresented: Bool
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var dataManager: DataManager
    var onCafeSelected: ((Cafe) -> Void)?
    
    // State
    @State private var spinPhase: SpinPhase = .ready
    @State private var searchRadiusMiles: Double = 10.0
    @State private var selectedCafe: SpinCafeResult?
    @State private var searchError: String?
    @State private var cafeResults: [SpinCafeResult] = []
    @State private var wheelRotation: Double = 0
    @State private var targetRotation: Double = 0
    @State private var selectedIndex: Int = 0
    @State private var confettiTrigger: Int = 0
    @State private var mugsyImagePosition: CGPoint = .zero
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    // Valid radius values: 0.25, 0.5, 0.75, 1.0, then 1-mile increments to 10
    private let validRadiusValues: [Double] = [0.25, 0.5, 0.75, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    
    // Slider position (0 to count-1) mapped to radius values
    private var sliderPosition: Binding<Double> {
        Binding(
            get: {
                // Find closest valid value index
                let closestIndex = validRadiusValues.enumerated().min { abs($0.element - searchRadiusMiles) < abs($1.element - searchRadiusMiles) }?.offset ?? validRadiusValues.count - 1
                return Double(closestIndex)
            },
            set: { newValue in
                let index = Int(newValue.rounded())
                let clampedIndex = min(max(index, 0), validRadiusValues.count - 1)
                searchRadiusMiles = validRadiusValues[clampedIndex]
            }
        )
    }
    
    enum SpinPhase {
        case ready
        case searching
        case spinning
        case result
    }
    
    // Convert miles to meters for MapKit
    private var searchRadiusMeters: Double {
        searchRadiusMiles * 1609.344
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 0) {
                // Header with close button
                header
                
                Spacer()
                
                // Main content
                mainContent
                
                Spacer()
                
                // Bottom controls
                bottomControls
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xl)
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                DS.Colors.primaryAccent.opacity(0.2),
                DS.Colors.screenBackground,
                DS.Colors.screenBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Spin for a Spot")
                    .font(DS.Typography.title1())
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text("Let Mugsy choose your next cafe")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                hapticsManager.lightTap()
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
        .padding(.top, DS.Spacing.md)
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        switch spinPhase {
        case .ready:
            readyStateView
        case .searching:
            searchingStateView
        case .spinning:
            spinningWheelView
        case .result:
            if let cafe = selectedCafe {
                resultView(cafe: cafe)
            } else {
                readyStateView
            }
        }
    }
    
    // MARK: - Ready State
    
    private var readyStateView: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Decorative wheel preview
            ZStack {
                // Outer glow
                Circle()
                    .fill(DS.Colors.primaryAccent.opacity(0.15))
                    .frame(width: 220, height: 220)
                    .blur(radius: 20)
                
                // Wheel placeholder
                Circle()
                    .fill(DS.Colors.cardBackground)
                    .frame(width: 200, height: 200)
                    .shadow(color: DS.Colors.primaryAccent.opacity(0.3), radius: 20, x: 0, y: 4)
                
                // Inner decoration
                Circle()
                    .stroke(DS.Colors.primaryAccent.opacity(0.3), lineWidth: 3)
                    .frame(width: 180, height: 180)
                
                // Center - Mugsy image
                Image("MugsySpin")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
            }
            .padding(.vertical, DS.Spacing.lg)
            
            // Distance slider
            distanceSlider
        }
    }
    
    // MARK: - Searching State
    
    private var searchingStateView: some View {
        VStack(spacing: DS.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(DS.Colors.primaryAccent.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(DS.Colors.primaryAccent)
            }
            
            VStack(spacing: DS.Spacing.xs) {
                Text("Finding cafés nearby...")
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text("Excluding chains, keeping it local")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Spinning Wheel View
    
    private var spinningWheelView: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Fortune wheel
            MugshotFortuneWheel(
                cafes: cafeResults,
                rotation: wheelRotation,
                selectedIndex: selectedIndex
            )
            .frame(width: 300, height: 300)
            
            Text("Spinning...")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
    
    // MARK: - Distance Slider
    
    private var distanceSlider: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "location.circle")
                    .foregroundColor(DS.Colors.primaryAccent)
                
                Text("Search radius")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
                
                Spacer()
                
                // Format display: show decimals for fractional values, integer for whole numbers
                Text(formatRadiusDisplay(searchRadiusMiles))
                    .font(DS.Typography.caption1(.semibold))
                    .foregroundColor(DS.Colors.primaryAccent)
            }
            
            Slider(value: sliderPosition, in: 0...Double(validRadiusValues.count - 1), step: 1)
                .tint(DS.Colors.primaryAccent)
            
            HStack {
                Text("0.25 mi")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textTertiary)
                
                Spacer()
                
                Text("10 mi")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.lg)
        .dsCardShadow()
    }
    
    // MARK: - Result View
    
    private func resultView(cafe: SpinCafeResult) -> some View {
        GeometryReader { geometry in
            let confettiSourcePoint = CGPoint(
                x: geometry.size.width / 2,
                y: 150
            )
            
            return ZStack {
                VStack(spacing: DS.Spacing.xl) {
                    // Victory animation
                    VStack(spacing: DS.Spacing.sm) {
                        Image("MugsySpinCelebrate")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .background(
                                GeometryReader { imageGeometry in
                                    Color.clear
                                        .preference(
                                            key: ImagePositionPreferenceKey.self,
                                            value: CGPoint(
                                                x: imageGeometry.frame(in: .named("resultView")).midX,
                                                y: imageGeometry.frame(in: .named("resultView")).midY
                                            )
                                        )
                                        .onAppear {
                                            // Also set position immediately for debugging
                                            let position = CGPoint(
                                                x: imageGeometry.frame(in: .named("resultView")).midX,
                                                y: imageGeometry.frame(in: .named("resultView")).midY
                                            )
                                            print("📍 Image position set: \(position)")
                                            DispatchQueue.main.async {
                                                self.mugsyImagePosition = position
                                            }
                                        }
                                }
                            )
                        
                        Text("Mugsy chose...")
                            .font(DS.Typography.caption1(.semibold))
                            .foregroundColor(DS.Colors.textSecondary)
                            .tracking(2)
                    }
                    
                    // Result card
                    VStack(spacing: DS.Spacing.md) {
                        Text(cafe.name)
                            .font(DS.Typography.title1())
                            .foregroundColor(DS.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        // Distance badge
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                            Text(cafe.formattedDistance)
                        }
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.primaryAccent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.primaryAccentSoftFill)
                        .cornerRadius(DS.Radius.pill)
                        
                        // Address
                        if let address = cafe.address {
                            Text(address)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        
                        // Mini map
                        if let coordinate = cafe.coordinate {
                            MiniMapPreview(coordinate: coordinate, name: cafe.name)
                                .frame(height: 100)
                                .cornerRadius(DS.Radius.md)
                        }
                    }
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.xl)
                    .dsCardShadow()
                }
                .transition(.scale.combined(with: .opacity))
                .coordinateSpace(name: "resultView")
                .onPreferenceChange(ImagePositionPreferenceKey.self) { position in
                    print("📍 Preference changed - new position: \(position)")
                    if position != .zero {
                        self.mugsyImagePosition = position
                        print("📍 Mugsy position updated: \(self.mugsyImagePosition)")
                    }
                }
                
                // Confetti overlay - positioned to shoot from Mugsy image
                if confettiTrigger > 0 {
                    MugshotConfettiCannon(
                        trigger: $confettiTrigger,
                        sourcePoint: confettiSourcePoint,
                        num: 60,
                        colors: [
                            Color(hex: "B7E2B5"),  // Mugshot mint
                            Color(hex: "FAF8F6"),  // Cream white
                            Color(hex: "2563EB"),  // Blue accent
                            Color(hex: "FACC15"),  // Yellow accent
                            Color(hex: "ECF8EC"),  // Mint soft fill
                            Color(hex: "8AC28E"),  // Mint dark
                        ],
                        confettiSize: 10.0,
                        openingAngle: .degrees(0),
                        closingAngle: .degrees(360),
                        radius: 350.0
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - Bottom Controls
    
    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let error = searchError {
                // Error state
                Text(error)
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.negativeChange)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, DS.Spacing.sm)
                
                Button(action: resetSpin) {
                    Text("Try Again")
                        .font(DS.Typography.buttonLabel)
                        .foregroundColor(DS.Colors.primaryAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.primaryAccentSoftFill)
                        .cornerRadius(DS.Radius.primaryButton)
                }
            } else if spinPhase == .ready {
                // Ready state - Search button
                Button(action: startSearch) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                        Text("Find Cafes")
                            .font(DS.Typography.buttonLabel)
                    }
                    .foregroundColor(DS.Colors.textOnMint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.primaryButton)
                    .dsCardShadow()
                }
            } else if spinPhase == .result, let cafe = selectedCafe {
                // Result state - Action buttons
                resultActionButtons(cafe: cafe)
            }
        }
    }
    
    private func resultActionButtons(cafe: SpinCafeResult) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            // View Cafe button
            if let mappedCafe = cafe.mappedCafe {
                Button(action: {
                    hapticsManager.mediumTap()
                    isPresented = false
                    onCafeSelected?(mappedCafe)
                }) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 16))
                        Text("View Café")
                            .font(DS.Typography.buttonLabel)
                    }
                    .foregroundColor(DS.Colors.textOnMint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.primaryButton)
                }
            }
            
            HStack(spacing: DS.Spacing.sm) {
                // Open in Maps
                Button(action: {
                    hapticsManager.lightTap()
                    cafe.openInMaps()
                }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14))
                        Text("Open in Maps")
                            .font(DS.Typography.caption1(.semibold))
                    }
                    .foregroundColor(DS.Colors.primaryAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.primaryAccentSoftFill)
                    .cornerRadius(DS.Radius.primaryButton)
                }
                
                // Spin Again
                Button(action: resetAndSearch) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                        Text("Spin Again")
                            .font(DS.Typography.caption1(.semibold))
                    }
                    .foregroundColor(DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.cardBackgroundAlt)
                    .cornerRadius(DS.Radius.primaryButton)
                }
            }
        }
    }
    
    // MARK: - Search Logic
    
    private func startSearch() {
        guard let location = locationManager.location else {
            searchError = "Unable to get your location. Please enable location services."
            return
        }
        
        hapticsManager.mediumTap()
        searchError = nil
        spinPhase = .searching
        
        searchForIndependentCafes(near: location.coordinate)
    }
    
    private func searchForIndependentCafes(near coordinate: CLLocationCoordinate2D) {
        print("\n========== SPIN FOR A SPOT: SEARCH STARTING ==========")
        print("📍 Search Location: (\(coordinate.latitude), \(coordinate.longitude))")
        print("📏 Search Radius: \(String(format: "%.1f", searchRadiusMiles)) miles (\(String(format: "%.0f", searchRadiusMeters)) meters)")
        print("🔍 Primary Search: Apple Maps POI categories (.cafe, .bakery)")
        print("🔍 Secondary Search: Keyword 'coffee' (captures additional cafes)")
        print("🚫 Excluding: chains + dessert shops after results merge")
        
        performHybridSearch(center: coordinate)
    }
    
    /// Performs a hybrid search (POI categories + keyword) to capture as many cafes as Apple exposes in one spin
    private func performHybridSearch(center: CLLocationCoordinate2D) {
        let userLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let radiusMiles = searchRadiusMiles
        let radiusMeters = searchRadiusMeters
        
        let dispatchGroup = DispatchGroup()
        var poiResults: [MKMapItem] = []
        var keywordResults: [MKMapItem] = []
        var encounteredErrors: [Error] = []
        
        print("\n========== HYBRID SEARCH CONFIGURATION ==========")
        print("📌 Center radius (POI categories): \(String(format: "%.1f", radiusMiles)) miles")
        print("🧭 Keyword search region: \(String(format: "%.1f", radiusMiles)) mile span around user")
        print("📡 Requests this spin: 2 (well under Apple rate limit)")
        
        // 1) POI Category search
        dispatchGroup.enter()
        let poiRequest = MKLocalPointsOfInterestRequest(center: center, radius: radiusMeters)
        poiRequest.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe, .bakery])
        let poiSearch = MKLocalSearch(request: poiRequest)
        poiSearch.start { response, error in
            if let error = error {
                encounteredErrors.append(error)
                print("  ⚠️ POI category search failed: \(error.localizedDescription)")
            } else if let response = response {
                poiResults = response.mapItems
                print("  ✅ POI category search found \(response.mapItems.count) results")
            } else {
                print("  ⚠️ POI category search returned no response")
            }
            dispatchGroup.leave()
        }
        
        // 2) Keyword search (\"coffee\")
        dispatchGroup.enter()
        let keywordRequest = MKLocalSearch.Request()
        keywordRequest.naturalLanguageQuery = "coffee"
        keywordRequest.resultTypes = [.pointOfInterest]
        keywordRequest.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )
        let keywordSearch = MKLocalSearch(request: keywordRequest)
        keywordSearch.start { response, error in
            if let error = error {
                encounteredErrors.append(error)
                print("  ⚠️ Keyword 'coffee' search failed: \(error.localizedDescription)")
            } else if let response = response {
                keywordResults = response.mapItems
                print("  ✅ Keyword 'coffee' search found \(response.mapItems.count) results")
            } else {
                print("  ⚠️ Keyword 'coffee' search returned no response")
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            let combined = poiResults + keywordResults
            print("📦 Combined raw results before filtering: \(combined.count)")
            
            if combined.isEmpty {
                if let firstError = encounteredErrors.first {
                    self.handleSearchError(firstError)
                } else {
                    self.handleNoResults()
                }
                return
            }
            
            self.processCombinedSearchResults(
                allMapItems: combined,
                userLocation: userLocation,
                coordinate: center,
                radiusMiles: radiusMiles,
                radiusMeters: radiusMeters
            )
        }
    }
    
    /// Processes and filters combined results from the hybrid searches
    private func processCombinedSearchResults(
        allMapItems: [MKMapItem],
        userLocation: CLLocation,
        coordinate: CLLocationCoordinate2D,
        radiusMiles: Double,
        radiusMeters: Double
    ) {
        print("\n========== COMBINING HYBRID SEARCH RESULTS ==========")
        print("📦 Total raw results from hybrid searches: \(allMapItems.count)")
        
        // Deduplicate by name and coordinate (unique identifier)
        var seenItems = Set<String>()
        var uniqueMapItems: [MKMapItem] = []
        
        for item in allMapItems {
            let name = item.name ?? "Unknown"
            let coordinate: String
            if let location = item.placemark.location {
                coordinate = String(format: "%.6f,%.6f", location.coordinate.latitude, location.coordinate.longitude)
            } else {
                coordinate = UUID().uuidString
            }
            let uniqueKey = "\(name)|\(coordinate)"
            
            if !seenItems.contains(uniqueKey) {
                seenItems.insert(uniqueKey)
                uniqueMapItems.append(item)
            }
        }
        
        print("🔄 After deduplication: \(uniqueMapItems.count) unique results")
        
        print("\n========== RAW APPLE MAPS RESULTS (UNIQUE) ==========")
        for (index, item) in uniqueMapItems.enumerated() {
            let name = item.name ?? "Unknown"
            let address = item.placemark.title ?? "No address"
            let category = item.pointOfInterestCategory?.rawValue ?? "none"
            if let itemLocation = item.placemark.location {
                let distanceMeters = itemLocation.distance(from: userLocation)
                let distanceMiles = distanceMeters / 1609.344
                print("  \(index + 1). \(name) - \(address)")
                print("      Category: \(category)")
                print("      Distance: \(String(format: "%.2f", distanceMiles)) mi (\(String(format: "%.0f", distanceMeters)) m)")
            } else {
                print("  \(index + 1). \(name) - \(address)")
                print("      Category: \(category)")
                print("      Distance: No location data")
            }
        }
        
        // Filter out chains and process results
        var filteredResults: [SpinCafeResult] = []
        var chainCount = 0
        var distanceFilteredCount = 0
        var categoryFilteredCount = 0
        var nameFilteredCount = 0
        
        print("\n========== FILTERING RESULTS ==========")
        print("🎯 Filtering for cafes within \(String(format: "%.1f", radiusMiles)) miles (\(String(format: "%.0f", radiusMeters)) meters)")
        
        for item in uniqueMapItems {
            let name = item.name ?? "Unknown"
            let categoryRaw = item.pointOfInterestCategory?.rawValue ?? "none"
            
            // Filter by distance - MUST be within search radius
            guard let itemLocation = item.placemark.location else {
                print("  ⚠️ \(name): Skipped (no location)")
                continue
            }
            let distanceMeters = itemLocation.distance(from: userLocation)
            let distanceMiles = distanceMeters / 1609.344
            
            // Strict distance check: must be <= radiusMeters
            // This ensures we only include cafes within the user-specified radius
            if distanceMeters > radiusMeters {
                distanceFilteredCount += 1
                print("  📏 \(name): Skipped - \(String(format: "%.2f", distanceMiles)) mi is OUTSIDE \(String(format: "%.1f", radiusMiles)) mi radius")
                continue
            }
                    
                    // Filter by category - only allow .cafe (covers coffee shops)
                    // Exclude bakery unless it has coffee-related keywords in name
                    let isCafeCategory = item.pointOfInterestCategory == .cafe
                    let isBakeryCategory = item.pointOfInterestCategory == .bakery
                    let hasCoffeeKeyword = Self.hasCoffeeKeyword(in: name)
                    
                    if !isCafeCategory && !isBakeryCategory {
                        categoryFilteredCount += 1
                        print("  🚫 \(name): Skipped - Category '\(categoryRaw)' not cafe or bakery")
                        continue
                    }
                    
                    // For bakery category, require coffee-related keyword
                    if isBakeryCategory && !hasCoffeeKeyword {
                        categoryFilteredCount += 1
                        print("  🥐 \(name): Skipped - Bakery without coffee keywords")
                        continue
                    }
                    
                    // Filter out dessert/candy/ice cream shops by name
                    if Self.isDessertShop(name: name) {
                        nameFilteredCount += 1
                        print("  🍰 \(name): Skipped - Detected as dessert/candy shop by name")
                        continue
                    }
                    
                    // Filter out chains
                    if CafeChainFilter.isChain(mapItem: item) {
                        chainCount += 1
                        print("  🏢 \(name): Skipped - Detected as chain")
                        continue
                    }
                    
            // ALL FILTERS PASSED - Create result
            let mappedCafe = dataManager.findOrCreateCafe(from: item)
            
            var result = SpinCafeResult(mapItem: item, distanceMeters: distanceMeters)
            result.mappedCafe = mappedCafe
            filteredResults.append(result)
            
            print("  ✅ \(name): \(String(format: "%.2f", distanceMiles)) mi - Category: \(categoryRaw) - PASSED ALL FILTERS")
        }
        
        print("\n========== FILTER SUMMARY ==========")
        print("📦 Raw results (hybrid search total): \(allMapItems.count)")
        print("🔄 Unique results (after deduplication): \(uniqueMapItems.count)")
        print("📏 Filtered by distance: \(distanceFilteredCount)")
        print("🚫 Filtered by category: \(categoryFilteredCount)")
        print("🍰 Filtered by name (dessert/candy): \(nameFilteredCount)")
        print("🏢 Filtered as chains: \(chainCount)")
        print("✅ Passed all filters: \(filteredResults.count)")
        
        // Sort by distance
        filteredResults.sort { $0.distanceMeters < $1.distanceMeters }
        
        if filteredResults.isEmpty {
            print("❌ No independent cafes found after filtering")
            handleNoIndependentCafes()
            return
        }
        
        print("\n========== ALL POSSIBLE CAFES (SORTED BY DISTANCE) ==========")
        
        // Calculate distance statistics
        let distancesMiles = filteredResults.map { $0.distanceMeters / 1609.344 }
        let minDistance = distancesMiles.min() ?? 0
        let maxDistance = distancesMiles.max() ?? 0
        let avgDistance = distancesMiles.reduce(0, +) / Double(max(distancesMiles.count, 1))
        
        print("📊 Distance Statistics:")
        print("   Requested radius: \(String(format: "%.1f", radiusMiles)) miles")
        print("   Closest cafe: \(String(format: "%.2f", minDistance)) miles")
        print("   Farthest cafe: \(String(format: "%.2f", maxDistance)) miles")
        print("   Average distance: \(String(format: "%.2f", avgDistance)) miles")
        print("   Total cafes: \(filteredResults.count)")
        
        for (index, result) in filteredResults.enumerated() {
            let distanceMiles = result.distanceMeters / 1609.344
            let address = result.address ?? "No address"
            print("  \(index + 1). \(result.name) - \(String(format: "%.2f", distanceMiles)) mi")
            print("     📍 \(address)")
        }
        
        // Randomly sample up to 20 cafes for this spin to keep things fresh
        let sampleCount = min(20, filteredResults.count)
        let sampledResults = Array(filteredResults.shuffled().prefix(sampleCount))
        
        print("\n========== RANDOM SAMPLE FOR THIS SPIN ==========")
        print("🎲 Sample size: \(sampleCount) of \(filteredResults.count) eligible cafes")
        for (index, result) in sampledResults.enumerated() {
            let distanceMiles = result.distanceMeters / 1609.344
            print("  [sample \(index)] \(result.name) - \(String(format: "%.2f", distanceMiles)) mi")
        }
        print("=======================================================\n")
        
        cafeResults = sampledResults
        
        startWheelSpin()
    }
    
    // MARK: - Wheel Animation
    
    private func startWheelSpin() {
        spinPhase = .spinning
        
        print("\n========== WHEEL SPIN STARTING ==========")
        print("🎰 Total cafes in wheel: \(cafeResults.count)")
        print("🎲 Random selection range: 0 to \(cafeResults.count - 1)")
        print("⚖️  Each cafe has equal probability: 1/\(cafeResults.count) = \(String(format: "%.2f%%", 100.0 / Double(cafeResults.count)))")
        
        // Pick random winner - 100% random with equal probability for all results
        let winnerIndex = Int.random(in: 0..<cafeResults.count)
        selectedIndex = winnerIndex
        
        let winner = cafeResults[winnerIndex]
        let winnerDistanceMiles = winner.distanceMeters / 1609.344
        
        print("🎯 RANDOMLY SELECTED WINNER:")
        print("   Random Index: \(winnerIndex) (out of \(cafeResults.count) options)")
        print("   Name: \(winner.name)")
        print("   Distance: \(String(format: "%.2f", winnerDistanceMiles)) miles")
        print("   Address: \(winner.address ?? "No address")")
        print("   Probability: \(String(format: "%.2f%%", 100.0 / Double(cafeResults.count))) - Equal chance with all others")
        print("=========================================\n")
        
        // Calculate rotation to land on winner
        // The pointer is at the top. Segments are drawn starting from the top (segment 0 at top).
        // After rotation, segment 'winnerIndex' should be at the top where the pointer is.
        let sliceAngle = 360.0 / Double(cafeResults.count)
        let baseRotation = Double.random(in: 5...8) * 360 // 5-8 full rotations
        
        // Segment 'winnerIndex' starts at 'winnerIndex * sliceAngle' degrees from the top.
        // To move it to the top (align with pointer), we rotate so:
        //   winnerIndex * sliceAngle + targetRotation = 0 (mod 360)
        // Therefore: targetRotation = -winnerIndex * sliceAngle (mod 360)
        // Or equivalently: targetRotation = 360 - (winnerIndex * sliceAngle) (mod 360)
        let segmentStartAngle = Double(winnerIndex) * sliceAngle
        let alignmentNeeded = (360 - segmentStartAngle).truncatingRemainder(dividingBy: 360)
        targetRotation = baseRotation + alignmentNeeded
        
        // Start progressive haptics
        startProgressiveHaptics()
        
        // Animate wheel
        withAnimation(.easeOut(duration: 5.0)) {
            wheelRotation = targetRotation
        }
        
        // Show result after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
            self.selectedCafe = self.cafeResults[winnerIndex]
            print("✅ Result displayed: \(self.cafeResults[winnerIndex].name)")
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.spinPhase = .result
            }
            self.hapticsManager.playSuccess()
            
            // Trigger confetti explosion after a brief delay to allow position to be set
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🎉 Triggering confetti! Position: \(self.mugsyImagePosition), Trigger: \(self.confettiTrigger)")
                self.confettiTrigger += 1
                print("🎉 Confetti trigger set to: \(self.confettiTrigger)")
            }
        }
    }
    
    private func startProgressiveHaptics() {
        // Fast haptics during fast spin (first 2 seconds)
        for i in 0..<20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                guard self.spinPhase == .spinning else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        
        // Medium haptics during medium spin (2-3.5 seconds)
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + Double(i) * 0.2) {
                guard self.spinPhase == .spinning else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        
        // Heavy haptics during slow deceleration (3.5-5 seconds)
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5 + Double(i) * 0.4) {
                guard self.spinPhase == .spinning else { return }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleSearchError(_ error: Error) {
        withAnimation {
            spinPhase = .ready
            searchError = "Couldn't search for cafés. Please try again."
        }
        hapticsManager.playError()
    }
    
    private func handleNoResults() {
        withAnimation {
            spinPhase = .ready
            searchError = "No cafés found within \(formatRadiusDisplay(searchRadiusMiles)). Try increasing the search radius."
        }
        hapticsManager.lightTap()
    }
    
    private func handleNoIndependentCafes() {
        withAnimation {
            spinPhase = .ready
            searchError = "No independent cafés found nearby. All results were chains. Try a larger radius."
        }
        hapticsManager.lightTap()
    }
    
    private func resetSpin() {
        withAnimation {
            spinPhase = .ready
            selectedCafe = nil
            searchError = nil
            cafeResults = []
            wheelRotation = 0
            targetRotation = 0
            confettiTrigger = 0
            mugsyImagePosition = .zero
        }
    }
    
    private func resetAndSearch() {
        resetSpin()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            startSearch()
        }
    }
    
    // MARK: - Display Helpers
    
    /// Format radius display: show decimals for fractional values, integer for whole numbers
    private func formatRadiusDisplay(_ miles: Double) -> String {
        if miles.truncatingRemainder(dividingBy: 1.0) == 0 {
            // Whole number - show as integer
            return "\(Int(miles)) mi"
        } else {
            // Fractional - always show with leading zero and 2 decimal places (0.25, 0.5, 0.75)
            return String(format: "%.2f mi", miles)
        }
    }
    
    // MARK: - Filtering Helpers
    
    /// Check if name contains coffee-related keywords
    private static func hasCoffeeKeyword(in name: String) -> Bool {
        let lowercaseName = name.lowercased()
        let coffeeKeywords = [
            "coffee", "café", "cafe", "espresso", "latte", "cappuccino",
            "brew", "roast", "roaster", "roastery", "bean", "beans",
            "mocha", "americano", "macchiato", "pour over", "cold brew",
            "drip", "barista", "coffeehouse", "coffee house"
        ]
        return coffeeKeywords.contains { lowercaseName.contains($0) }
    }
    
    /// Check if name indicates a dessert/candy/ice cream shop (not a cafe)
    private static func isDessertShop(name: String) -> Bool {
        let lowercaseName = name.lowercased()
        let dessertKeywords = [
            "candy", "sweet", "dessert", "ice cream", "icecream", "gelato",
            "frozen yogurt", "froyo", "cupcake", "cookie", "donut", "doughnut",
            "pastry", "cake shop", "cake house", "chocolat", "chocolate shop",
            "confection", "sweets", "treats", "sugar", "fudge", "taffy",
            "praline", "macarons", "macaron"
        ]
        return dessertKeywords.contains { lowercaseName.contains($0) }
    }
}

// MARK: - Café Chain Filter

struct CafeChainFilter {
    /// List of chain café names to exclude
    private static let chainPatterns: [String] = [
        "starbucks",
        "dunkin",
        "panera",
        "peet's coffee",
        "peets coffee",
        "coffee bean & tea leaf",
        "coffee bean and tea leaf",
        "mcdonald's",
        "mcdonalds",
        "burger king",
        "wendy's",
        "wendys",
        "tim hortons",
        "caribou coffee",
        "dutch bros",
        "7-eleven",
        "7 eleven",
        "circle k",
        "wawa",
        "sheetz",
        "krispy kreme",
        "cinnabon",
        "au bon pain",
        "corner bakery",
        "la boulange",
        "noah's bagels",
        "einstein bros",
        "bruegger's",
        "atlanta bread",
        "cosi",
        "paradise bakery",
        "mcalister's deli",
        "jason's deli"
    ]
    
    /// Check if a map item is a known chain
    static func isChain(mapItem: MKMapItem) -> Bool {
        guard let name = mapItem.name?.lowercased() else { return false }
        
        return chainPatterns.contains { pattern in
            name.contains(pattern)
        }
    }
}

// MARK: - Mugshot Fortune Wheel

struct MugshotFortuneWheel: View {
    let cafes: [SpinCafeResult]
    let rotation: Double
    let selectedIndex: Int
    
    // Mugshot brand colors for wheel segments
    private let segmentColors: [Color] = [
        Color(hex: "B7E2B5"),  // Mugshot mint
        Color(hex: "FAF8F6"),  // Cream white
        Color(hex: "E6DED4"),  // Sand beige
        Color(hex: "D6F0D6"),  // Light mint
        Color(hex: "FFFFFF"),  // White
        Color(hex: "ECF8EC"),  // Mint soft fill
        Color(hex: "F9FAFB"),  // Neutral card
        Color(hex: "C8D8C8"),  // Sage mint
    ]
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(DS.Colors.primaryAccent.opacity(0.2))
                .blur(radius: 30)
                .scaleEffect(1.15)
            
            // Wheel shadow
            Circle()
                .fill(Color.black.opacity(0.1))
                .offset(y: 8)
                .blur(radius: 8)
            
            // Main wheel
            ZStack {
                // Segments
                ForEach(0..<cafes.count, id: \.self) { index in
                    WheelSegment(
                        index: index,
                        total: cafes.count,
                        cafeName: cafes[index].shortName,
                        color: segmentColors[index % segmentColors.count]
                    )
                }
            }
            .rotationEffect(.degrees(rotation))
            
            // Center hub
            ZStack {
                Circle()
                    .fill(DS.Colors.cardBackground)
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                
                Circle()
                    .stroke(DS.Colors.primaryAccent, lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                Image("MugsySpin")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 40)
            }
            
            // Pointer/indicator at top
            VStack {
                Triangle()
                    .fill(DS.Colors.primaryAccent)
                    .frame(width: 24, height: 20)
                    .shadow(color: DS.Colors.primaryAccent.opacity(0.5), radius: 4, x: 0, y: 2)
                    .offset(y: -135)
                Spacer()
            }
        }
    }
}

// MARK: - Wheel Segment

struct WheelSegment: View {
    let index: Int
    let total: Int
    let cafeName: String
    let color: Color
    
    private var startAngle: Double {
        Double(index) * (360.0 / Double(total))
    }
    
    private var endAngle: Double {
        Double(index + 1) * (360.0 / Double(total))
    }
    
    var body: some View {
        ZStack {
            // Segment shape
            WheelSlice(startAngle: startAngle, endAngle: endAngle)
                .fill(color)
            
            WheelSlice(startAngle: startAngle, endAngle: endAngle)
                .stroke(Color.white, lineWidth: 2)
            
            // Text
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2 * 0.65
                let midAngle = (startAngle + endAngle) / 2
                let radians = midAngle * .pi / 180
                
                Text(cafeName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(width: 60)
                    .rotationEffect(.degrees(midAngle + 90))
                    .position(
                        x: center.x + radius * cos(CGFloat(radians - .pi / 2)),
                        y: center.y + radius * sin(CGFloat(radians - .pi / 2))
                    )
            }
        }
    }
}

// MARK: - Wheel Slice Shape

struct WheelSlice: Shape {
    let startAngle: Double
    let endAngle: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Spin Cafe Result

struct SpinCafeResult {
    let mapItem: MKMapItem
    let distanceMeters: Double
    var mappedCafe: Cafe?
    
    var name: String {
        mapItem.name ?? "Unknown Café"
    }
    
    /// Shortened name for wheel display
    var shortName: String {
        let fullName = name
        if fullName.count > 12 {
            return String(fullName.prefix(10)) + "..."
        }
        return fullName
    }
    
    var address: String? {
        let placemark = mapItem.placemark
        var components: [String] = []
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    var coordinate: CLLocationCoordinate2D? {
        mapItem.placemark.location?.coordinate
    }
    
    var formattedDistance: String {
        let miles = distanceMeters / 1609.344
        if miles < 0.1 {
            return "Nearby"
        } else if miles < 1 {
            return String(format: "%.1f mi away", miles)
        } else {
            return String(format: "%.0f mi away", miles)
        }
    }
    
    func openInMaps() {
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Mini Map Preview

struct MiniMapPreview: View {
    let coordinate: CLLocationCoordinate2D
    let name: String
    
    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    var body: some View {
        Map(position: .constant(.region(mapRegion))) {
            Marker(name, coordinate: coordinate)
                .tint(Color(DS.Colors.primaryAccent))
        }
        .mapStyle(.standard)
        .disabled(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    SpinForASpotView(
        isPresented: .constant(true),
        locationManager: LocationManager(),
        dataManager: DataManager.shared
    )
}
