//
//  MapTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import MapKit
import CoreLocation

enum MapDiscoveryMode: String, CaseIterable {
    case map = "Map"
    case list = "List"

    var icon: String { self == .map ? "map.fill" : "list.bullet" }
}

enum MapDiscoveryRadius {
    static let miles: ClosedRange<Double> = 0...50

    static func kilometers(forMiles miles: Double) -> Double {
        max(miles, 1) * 1.609_344
    }
}

enum MapDiscoveryScope: String, CaseIterable, Identifiable {
    case visited = "Visited"
    case friends = "Friends"
    case favorites = "Favorites"
    case wantToTry = "Want to Try"
    case all = "All"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "map.fill"
        case .favorites: return "heart.fill"
        case .wantToTry: return "bookmark.fill"
        case .visited: return "cup.and.saucer.fill"
        case .friends: return "person.2.fill"
        }
    }

    var explanation: String {
        switch self {
        case .all: return "Nearby, friend, and community cafes together"
        case .favorites: return "Only cafes you marked as favorites"
        case .wantToTry: return "Only cafes you saved to try later"
        case .visited: return "Only cafes where you logged a sip"
        case .friends: return "Only cafes where friends shared a sip"
        }
    }

    func sections(isAuthenticated: Bool) -> [DiscoverySection] {
        switch self {
        case .all:
            return isAuthenticated
                ? [.nearby, .lovedByFriends, .trending]
                : [.nearby, .trending]
        case .favorites, .wantToTry, .visited:
            return []
        case .friends: return isAuthenticated ? [.lovedByFriends] : []
        }
    }

    static func available(isAuthenticated: Bool) -> [MapDiscoveryScope] {
        isAuthenticated ? allCases : [.visited, .favorites, .wantToTry, .all]
    }
}

struct MapTabView: View {
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = MapSearchService()
    
    @State private var region: MKCoordinateRegion?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var isSearchActive = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchPreviewCafes: [Cafe] = []
    @State private var hasRequestedLocation = false
    @State private var hasInitializedLocation = false
    @State private var showLocationMessage = false
    @State private var remoteStateError: String?
    @State private var remoteMapPins: [RemoteMapPin] = []
    @State private var hasLoadedRemoteMapPins = false
    @State private var remoteMapPinUserId: UUID?
    @State private var discoveryScope: MapDiscoveryScope = .visited
    @State private var discoveryMode: MapDiscoveryMode = .map
    @State private var discoveryRadiusMiles = 10.0
    @State private var discoveryMapCafes: [Cafe] = []
    @State private var discoveryCafesByID: [UUID: DiscoveryCafe] = [:]
    @State private var friendCafeSummariesByID: [UUID: RemoteCafeExperienceSummary] = [:]
    @State private var friendSipSummariesByID: [UUID: RemoteFriendMapSipSummary] = [:]
    @State private var friendPreviewCafe: Cafe?
    @State private var userTrackingMode: MKUserTrackingMode = .none
    
    // Default fallback region (SF) - only used if location unavailable
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        if discoveryMode == .map {
            mapBody
        } else {
            DiscoveryListView(
                dataManager: dataManager,
                locationManager: locationManager,
                discoveryMode: $discoveryMode,
                discoveryScope: $discoveryScope,
                radiusMiles: $discoveryRadiusMiles,
                searchText: $searchText,
                selectedMapCafe: $selectedCafe,
                showMapCafeDetail: $showCafeDetail,
                onLogVisitRequested: onLogVisitRequested,
                onAuthenticationRequired: onAuthenticationRequired
            )
        }
    }

    private var mapBody: some View {
        ZStack {
            // Map with POIs hidden
            MapViewRepresentable(
                region: Binding(
                    get: { region ?? defaultRegion },
                    set: { updatedRegion in
                        region = updatedRegion

                        // A MapKit search should follow the portion of the map
                        // the person is actually looking at, not the last
                        // location that happened to initialize the screen.
                        if isSearchActive,
                           !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            searchService.search(query: searchText, region: updatedRegion)
                        }
                    }
                ),
                cafes: displayedMapCafes,
                highlightedCafe: showCafeDetail || friendPreviewCafe != nil ? selectedCafe : nil,
                friendCounts: friendCountsByCafeID,
                pinScores: displayedPinScoresByCafeID,
                showsFriendContext: discoveryScope == .friends,
                scope: discoveryScope,
                showsUserLocation: locationAccessAuthorized,
                trackingMode: $userTrackingMode,
                onCafeTap: { cafe in
                    selectedCafe = cafe
                    if discoveryScope == .friends {
                        friendPreviewCafe = cafe
                        showCafeDetail = false
                    } else {
                        friendPreviewCafe = nil
                        showCafeDetail = true
                    }
                    isSearchActive = false
                }
            )
            .ignoresSafeArea()
            .onAppear {
                // Opening Map never prompts. Existing permission is honored;
                // new permission is requested only from the location control.
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
            
            if !showCafeDetail && friendPreviewCafe == nil {
                VStack(spacing: 0) {
                    // Location message banner
                    if showLocationMessage {
                        LocationBanner()
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                if let remoteStateError {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.roastBrown)
                        Text(remoteStateError)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondaryText)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        Button("Retry") {
                            Task { await loadRemoteMapPins() }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.mugshotSage)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.espressoBrown.opacity(0.6))
                        
                        TextField("Search places", text: $searchText)
                            .accessibilityIdentifier("map.search.query")
                            .foregroundColor(.inputText)
                            .tint(.mugshotSage)
                            .accentColor(.mugshotSage)
                            .focused($isSearchFieldFocused)
                            .submitLabel(.search)
                            .onChange(of: searchText) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    isSearchActive = true
                                    searchService.search(query: newValue, region: region ?? defaultRegion)
                                } else {
                                    searchService.cancelSearch()
                                }
                            }
                            .onTapGesture {
                                isSearchActive = true
                            }
                            .onSubmit {
                                searchService.search(
                                    query: searchText,
                                    region: region ?? defaultRegion,
                                    immediately: true
                                )
                                isSearchFieldFocused = false
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchService.cancelSearch()
                                isSearchActive = true
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.espressoBrown.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .mugshotGlassSurface(
                        radius: 26,
                        tint: .foamWhite,
                        stroke: Color.foamWhite.opacity(0.62),
                        shadow: DesignSystem.Shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 6),
                        interactive: true
                    )
                    
                    if isSearchActive {
                        Button("Cancel") {
                            searchText = ""
                            searchService.cancelSearch()
                            isSearchActive = false
                            isSearchFieldFocused = false
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .transition(.opacity)
                        .accessibilityIdentifier("map.search.cancel")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, isSearchActive ? 12 : 8)
                .background(Color.creamWhite.opacity(isSearchActive ? 0.92 : 0))
                .animation(DesignSystem.Motion.base, value: isSearchActive)
                .onChange(of: isSearchFieldFocused) { _, isFocused in
                    if isFocused { isSearchActive = true }
                }

                if !isSearchActive {
                    MapDiscoveryFilterBar(
                        selection: $discoveryScope,
                        isAuthenticated: authModel.authenticatedUser != nil
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))

                    HStack {
                        Spacer()
                        MapDiscoveryModeControl(selection: $discoveryMode)
                            .frame(width: 166)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
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
                        isSearchActive: $isSearchActive,
                        isSearchFieldFocused: $isSearchFieldFocused
                    )
                    .accessibilityIdentifier("map.search.results")
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
                            trackingMode: $userTrackingMode,
                            onUseManualSearch: {
                                isSearchActive = true
                                isSearchFieldFocused = true
                            }
                        )
                        .padding(.trailing)
                        .padding(.bottom, 188)
                    }
                }
                }
                .transition(.opacity)
            }
            
            // Ratings Legend - sticky at bottom above tab bar
            VStack {
                Spacer()
                if !showCafeDetail && friendPreviewCafe == nil && !isSearchActive {
                    RatingsLegend(showsFriendContext: discoveryScope == .friends)
                        .padding(.horizontal)
                        .padding(.bottom, 100)
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
                        initialPinScore: pinScoresByCafeID[cafe.id],
                        onLogVisitRequested: onLogVisitRequested,
                        onAuthenticationRequired: onAuthenticationRequired
                    )
                }
                .accessibilityIdentifier("map.cafeDetail.sheet")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let cafe = friendPreviewCafe,
                      let discoveryCafe = discoveryCafesByID[cafe.id] {
                VStack {
                    Spacer()
                    FriendCafePeekSheet(
                        cafe: cafe,
                        pinScore: friendPinScoresByCafeID[cafe.id],
                        friends: discoveryCafe.friends,
                        onDismiss: {
                            friendPreviewCafe = nil
                            selectedCafe = nil
                        },
                        onRevealCafe: {
                            friendPreviewCafe = nil
                            showCafeDetail = true
                        }
                    )
                }
            }
        }
        .task(id: localAccountScope.defaultsComponent) {
            searchService.activate(scope: localAccountScope)
        }
        .task(id: "\(authModel.authenticatedUser?.id.uuidString ?? "signed-out")-\(dataManager.journalRevision)-\(discoveryScope.rawValue)-\(discoveryRadiusMiles)") {
            await loadRemoteMapPins()
        }
        .onChange(of: discoveryScope) { _, _ in
            friendPreviewCafe = nil
            showCafeDetail = false
            selectedCafe = nil
        }
        .onChange(of: showCafeDetail) { _, isPresented in
            guard !isPresented, authModel.authenticatedUser != nil else { return }
            Task {
                await loadRemoteMapPins()
            }
        }
        .onReceive(searchService.$searchResults) { items in
            searchPreviewCafes = items.compactMap(Self.searchPreviewCafe(from:))
        }
    }

    private var locationAccessAuthorized: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways
    }

    private var localAccountScope: LocalAccountScope {
        .forUserID(
            authModel.authenticatedUser?.id
                ?? dataManager.appData.currentUser?.id
        )
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
        // Signed-in maps are deliberately private journal maps. Their source
        // of truth is the current user's completed Supabase logs plus active
        // saved-cafe states, never the public feed or stale local cache.
        let source: [Cafe]
        if authModel.authenticatedUser == nil {
            let localEligibleCafes = dataManager.appData.cafes.filter {
                $0.visitCount > 0 || $0.isFavorite || $0.wantToTry
            }
            switch discoveryScope {
            case .all:
                source = localEligibleCafes + discoveryMapCafes
            case .favorites:
                source = dataManager.appData.cafes.filter(\.isFavorite)
            case .wantToTry:
                source = dataManager.appData.cafes.filter(\.wantToTry)
            case .visited:
                source = dataManager.appData.cafes.filter { $0.visitCount > 0 }
            case .friends:
                source = []
            }
        } else {
            switch discoveryScope {
            case .all:
                source = remoteMapPins.map(\.localCafe) + discoveryMapCafes
            case .favorites:
                source = remoteMapPins.filter(\.isFavorite).map(\.localCafe)
            case .wantToTry:
                source = remoteMapPins.filter(\.wantToTry).map(\.localCafe)
            case .visited:
                source = remoteMapPins.filter { $0.visitCount > 0 }.map(\.localCafe)
            case .friends:
                source = discoveryMapCafes
            }
        }

        return source.reduce(into: [Cafe]()) { cafes, cafe in
            guard cafe.location != nil,
                  !cafes.contains(where: { $0.id == cafe.id }) else { return }
            cafes.append(cafe)
        }
    }

    private var personalPinScoresByCafeID: [UUID: MapPinScore] {
        guard authModel.authenticatedUser != nil else {
            return localPinScoresByCafeID
        }
        return Dictionary(
            uniqueKeysWithValues: remoteMapPins.compactMap { pin in
                pin.score.map { (pin.id, $0) }
            }
        )
    }

    private var localPinScoresByCafeID: [UUID: MapPinScore] {
        let visits = dataManager.appData.visits.filter {
            $0.context == .cafe && $0.overallScore > 0
        }
        return Dictionary(grouping: visits, by: \.cafeId).compactMapValues { cafeVisits in
            MapPinScoreResolver.sessionBalancedSipScore(
                cafeVisits.map {
                    MapSipScoreSeed(
                        overallScore: $0.overallScore,
                        cafeSessionID: $0.cafeSessionID
                    )
                },
                audience: .personal
            )
        }
    }

    private var friendPinScoresByCafeID: [UUID: MapPinScore] {
        discoveryCafesByID.reduce(into: [:]) { result, entry in
            let cafeID = entry.key
            if let summary = friendCafeSummariesByID[cafeID],
               let cafeScore = MapPinScoreResolver.resolve(
                   sips: [],
                   cafeSummary: summary,
                   audience: .friends,
                   contributorCount: summary.contributorCount
               ) {
                result[cafeID] = cafeScore
            } else if let sipScore = friendSipSummariesByID[cafeID]?.mapPinScore {
                result[cafeID] = sipScore
            }
        }
    }

    /// All, Favorites, Want to Try, and Visited are personal map views.
    /// Friend and discovery eligibility can add neutral pins to All, but never
    /// lends those pins somebody else's score.
    private var pinScoresByCafeID: [UUID: MapPinScore] {
        discoveryScope == .friends
            ? friendPinScoresByCafeID
            : personalPinScoresByCafeID
    }

    private var displayedPinScoresByCafeID: [UUID: MapPinScore] {
        let displayedIDs = Set(displayedMapCafes.map(\.id))
        return pinScoresByCafeID.filter { displayedIDs.contains($0.key) }
    }

    private var friendCountsByCafeID: [UUID: Int] {
        guard discoveryScope == .friends || discoveryScope == .all else { return [:] }
        return discoveryCafesByID.mapValues(\.friendCount)
    }

    private var effectiveDiscoveryRadiusKM: Double {
        MapDiscoveryRadius.kilometers(forMiles: discoveryRadiusMiles)
    }

    private var displayedMapCafes: [Cafe] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !query.isEmpty else { return cafesWithLocations }

        let knownMatches = cafesWithLocations.filter { cafe in
            [cafe.name, cafe.address, cafe.consumerPlaceCategory ?? ""]
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(query)
        }

        return (knownMatches + searchPreviewCafes).reduce(into: [Cafe]()) { result, cafe in
            let isDuplicate = result.contains { existing in
                guard let lhs = existing.location, let rhs = cafe.location else {
                    return existing.id == cafe.id
                }
                return abs(lhs.latitude - rhs.latitude) < 0.0001 &&
                    abs(lhs.longitude - rhs.longitude) < 0.0001
            }
            if !isDuplicate { result.append(cafe) }
        }
    }

    private static func searchPreviewCafe(from mapItem: MKMapItem) -> Cafe? {
        guard let location = mapItem.placemark.location?.coordinate else { return nil }
        return Cafe(
            name: mapItem.name ?? "Place",
            location: location,
            address: MapSearchService.subtitle(for: mapItem),
            mapItemURL: mapItem.url?.absoluteString,
            websiteURL: mapItem.url?.absoluteString,
            placeCategory: mapItem.pointOfInterestCategory?.rawValue
        )
    }

    @MainActor
    private func loadRemoteMapPins() async {
        guard let userId = authModel.authenticatedUser?.id else {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = SocialDiscoveryService(client: client)
                let discovery = try await fetchDiscoveryCafes(
                    service: service,
                    isAuthenticated: false
                )
                remoteMapPins = []
                discoveryMapCafes = discovery.map(\.localCafe)
                discoveryCafesByID = Dictionary(uniqueKeysWithValues: discovery.map { ($0.id, $0) })
                friendCafeSummariesByID = [:]
                friendSipSummariesByID = [:]
                remoteStateError = nil
                hasLoadedRemoteMapPins = true
                remoteMapPinUserId = nil
            } catch {
                guard !Task.isCancelled else { return }
                remoteMapPins = []
                discoveryMapCafes = []
                discoveryCafesByID = [:]
                friendCafeSummariesByID = [:]
                friendSipSummariesByID = [:]
                remoteStateError = MugshotUserFacingError.message(for: error, context: .loading)
                hasLoadedRemoteMapPins = false
                remoteMapPinUserId = nil
            }
            return
        }

        if remoteMapPinUserId != userId {
            remoteMapPins = []
            hasLoadedRemoteMapPins = false
        }

        do {
            let client = try SupabaseClientProvider.shared.client()
            let snapshot = try await PerformanceMonitor.measure("Map initial data") {
                try await MapPinService(
                    visitService: VisitService(client: client),
                    cafeStateService: CafeStateService(client: client),
                    cafeSessionService: CafeSessionService(client: client)
                ).fetchSnapshot(userId: userId)
            }

            let discovery = try await fetchDiscoveryCafes(
                service: SocialDiscoveryService(client: client),
                isAuthenticated: true
            )

            let friendCafeIDs = discoveryScope == .friends
                ? discovery.map(\.id)
                : []
            let cafeSessionService = CafeSessionService(client: client)
            async let cafeSummariesRequest: [RemoteCafeExperienceSummary] = cafeSessionService
                .fetchCafeSummaries(cafeIDs: friendCafeIDs, scope: .friends)
            async let sipSummariesRequest: [RemoteFriendMapSipSummary]? = try? cafeSessionService
                .fetchFriendMapSipSummaries(cafeIDs: friendCafeIDs)
            let (friendCafeSummaries, friendSipSummaries) = try await (
                cafeSummariesRequest,
                sipSummariesRequest
            )

            remoteMapPins = snapshot.pins
            discoveryMapCafes = discovery.map(\.localCafe)
            discoveryCafesByID = Dictionary(uniqueKeysWithValues: discovery.map { ($0.id, $0) })
            friendCafeSummariesByID = Dictionary(
                uniqueKeysWithValues: friendCafeSummaries.map { ($0.cafeID, $0) }
            )
            friendSipSummariesByID = Dictionary(
                uniqueKeysWithValues: (friendSipSummaries ?? []).map { ($0.cafeID, $0) }
            )
            // Keep the rest of the personal library in sync without using it
            // as the map's source of truth.
            dataManager.applyRemoteCafeStates(snapshot.cafeStates)
            hasLoadedRemoteMapPins = true
            remoteMapPinUserId = userId
            remoteStateError = nil
        } catch {
            guard !Task.isCancelled else { return }
            remoteStateError = MugshotUserFacingError.message(for: error, context: .loading)
            hasLoadedRemoteMapPins = false
            friendCafeSummariesByID = [:]
            friendSipSummariesByID = [:]
        }
    }

    private func fetchDiscoveryCafes(
        service: SocialDiscoveryService,
        isAuthenticated: Bool
    ) async throws -> [DiscoveryCafe] {
        var result: [DiscoveryCafe] = []
        for section in discoveryScope.sections(isAuthenticated: isAuthenticated) {
            let rows: [DiscoveryCafe]
            if isAuthenticated {
                if section == .lovedByFriends {
                    rows = try await service.friendCafeDiscovery(
                        location: locationManager.location,
                        radiusKM: effectiveDiscoveryRadiusKM,
                        limit: 50
                    )
                } else {
                    rows = try await service.discovery(
                        section: section,
                        location: locationManager.location,
                        radiusKM: effectiveDiscoveryRadiusKM,
                        limit: 50
                    )
                }
            } else {
                rows = try await service.publicDiscovery(
                    section: section,
                    location: locationManager.location,
                    radiusKM: effectiveDiscoveryRadiusKM,
                    limit: 50
                )
            }
            result.append(contentsOf: rows)
        }

        return result.reduce(into: [DiscoveryCafe]()) { cafes, cafe in
            if !cafes.contains(where: { $0.id == cafe.id }) {
                cafes.append(cafe)
            }
        }
    }
}

// MARK: - Map Pin Presentation

enum MapPinRatingBand: String, Equatable {
    case high
    case middle
    case low
    case unrated

    init(score: Double?) {
        guard let score, score > 0, score.isFinite else {
            self = .unrated
            return
        }
        if score >= 4 {
            self = .high
        } else if score >= 3 {
            self = .middle
        } else {
            self = .low
        }
    }

    var color: Color {
        switch self {
        case .high: .mapPinHigh
        case .middle: .mapPinMiddle
        case .low: .mapPinLow
        case .unrated: .mugshotMint
        }
    }

    var usesDarkForeground: Bool {
        self == .middle || self == .unrated
    }
}

enum MapPinPrimaryKind: String, Equatable {
    case journal
    case friends
    case favorite
    case wantToTry
}

struct MapPinPresentation: Equatable {
    let primaryKind: MapPinPrimaryKind
    let score: Double?
    let friendCount: Int
    let showsFavoriteBadge: Bool
    let showsWantToTryBadge: Bool
    let showsFriendsBadge: Bool

    var ratingBand: MapPinRatingBand {
        MapPinRatingBand(score: score)
    }

    var scoreText: String? {
        score.map { String(format: "%.1f", $0) }
    }

    var hasStateBadges: Bool {
        showsFavoriteBadge || showsWantToTryBadge || showsFriendsBadge
    }

    static func resolve(
        scope: MapDiscoveryScope,
        cafe: Cafe,
        pinScore: MapPinScore?,
        friendCount: Int
    ) -> MapPinPresentation {
        let primaryKind: MapPinPrimaryKind
        switch scope {
        case .friends:
            primaryKind = .friends
        case .favorites:
            primaryKind = .favorite
        case .wantToTry:
            primaryKind = .wantToTry
        case .visited, .all:
            primaryKind = .journal
        }

        return MapPinPresentation(
            primaryKind: primaryKind,
            score: pinScore?.value,
            friendCount: max(friendCount, 0),
            showsFavoriteBadge: scope == .all && cafe.isFavorite,
            showsWantToTryBadge: scope == .all && cafe.wantToTry,
            showsFriendsBadge: scope == .all && friendCount > 0
        )
    }
}

// MARK: - Map View Representable (to hide POIs)

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let cafes: [Cafe]
    let highlightedCafe: Cafe?
    let friendCounts: [UUID: Int]
    let pinScores: [UUID: MapPinScore]
    let showsFriendContext: Bool
    var scope: MapDiscoveryScope = .all
    let showsUserLocation: Bool
    @Binding var trackingMode: MKUserTrackingMode
    let onCafeTap: (Cafe) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        
        // Keep the standard MapKit blue puck so the map has the same
        // orientation anchor people expect from Apple Maps.
        mapView.showsUserLocation = showsUserLocation
        mapView.userTrackingMode = trackingMode
        
        // Hide points of interest
        mapView.pointOfInterestFilter = .excludingAll
        
        // Keep roads and basic geography
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        if mapView.showsUserLocation != showsUserLocation {
            mapView.showsUserLocation = showsUserLocation
        }

        if mapView.userTrackingMode != trackingMode {
            mapView.setUserTrackingMode(trackingMode, animated: true)
        }

        // Update region if needed
        if abs(mapView.region.center.latitude - region.center.latitude) > 0.001 ||
           abs(mapView.region.center.longitude - region.center.longitude) > 0.001 {
            mapView.setRegion(region, animated: true)
        }
        
        // Update annotations - refresh all to handle Favorite/Want to Try state changes
        let displayedCafes = (cafes + [highlightedCafe].compactMap { $0 }).reduce(into: [Cafe]()) { cafes, cafe in
            if !cafes.contains(where: { $0.id == cafe.id }) {
                cafes.append(cafe)
            }
        }
        let existingAnnotations = mapView.annotations.compactMap { $0 as? CafeAnnotation }
        let existingCafeIds = Set(existingAnnotations.map { $0.cafe.id })
        let currentCafeIds = Set(displayedCafes.map { $0.id })

        let pinPresentationChanged = context.coordinator.lastFriendCounts != friendCounts
            || context.coordinator.lastPinScores != pinScores
            || context.coordinator.lastShowsFriendContext != showsFriendContext
            || context.coordinator.lastScope != scope
        if pinPresentationChanged {
            mapView.removeAnnotations(existingAnnotations)
            mapView.addAnnotations(displayedCafes.map { CafeAnnotation(cafe: $0) })
            context.coordinator.lastFriendCounts = friendCounts
            context.coordinator.lastPinScores = pinScores
            context.coordinator.lastShowsFriendContext = showsFriendContext
            context.coordinator.lastScope = scope
            return
        }
        
        // Remove annotations for cafes that no longer exist
        let toRemove = existingAnnotations.filter { !currentCafeIds.contains($0.cafe.id) }
        mapView.removeAnnotations(toRemove)
        
        // Update existing annotations if cafe state changed (Favorite/Want to Try)
        for existingAnnotation in existingAnnotations {
            if let updatedCafe = displayedCafes.first(where: { $0.id == existingAnnotation.cafe.id }) {
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
        let toAdd = displayedCafes.filter { !existingCafeIds.contains($0.id) }
        let newAnnotations = toAdd.map { CafeAnnotation(cafe: $0) }
        mapView.addAnnotations(newAnnotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        var lastFriendCounts: [UUID: Int]
        var lastPinScores: [UUID: MapPinScore]
        var lastShowsFriendContext: Bool
        var lastScope: MapDiscoveryScope

        init(parent: MapViewRepresentable) {
            self.parent = parent
            lastFriendCounts = parent.friendCounts
            lastPinScores = parent.pinScores
            lastShowsFriendContext = parent.showsFriendContext
            lastScope = parent.scope
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation, parent.showsUserLocation {
                let identifier = "MugshotUserLocation"
                let userLocationView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier
                ) as? MKUserLocationView ?? MKUserLocationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )
                userLocationView.annotation = annotation
                userLocationView.tintColor = .systemBlue
                return userLocationView
            }

            guard let cafeAnnotation = annotation as? CafeAnnotation else { return nil }
            
            let cafe = cafeAnnotation.cafe
            let pinScore = parent.pinScores[cafe.id]
            let presentation = MapPinPresentation.resolve(
                scope: parent.scope,
                cafe: cafe,
                pinScore: pinScore,
                friendCount: parent.friendCounts[cafe.id] ?? 0
            )
            let identifier = "MugshotMapPin-\(presentation.primaryKind.rawValue)-\(presentation.hasStateBadges)"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                annotationView?.isEnabled = true
                annotationView?.isUserInteractionEnabled = true
            } else {
                annotationView?.annotation = annotation
            }
            
            let containerView = createPinContainer(presentation)
            let pinSize = containerView.bounds.width
            
            // Clear existing subviews
            annotationView?.subviews.forEach { $0.removeFromSuperview() }
            annotationView?.addSubview(containerView)
            annotationView?.frame = CGRect(x: 0, y: 0, width: pinSize, height: pinSize)
            annotationView?.centerOffset = CGPoint(x: 0, y: -pinSize / 2)
            annotationView?.isAccessibilityElement = true
            annotationView?.accessibilityTraits = .button
            annotationView?.accessibilityIdentifier = "map.pin.\(cafe.id.uuidString)"
            if parent.showsFriendContext {
                let friendCount = presentation.friendCount
                let scoreDescription = pinScore?.accessibilityLabel ?? "Cafe not rated by friends"
                annotationView?.accessibilityLabel = "\(cafe.name), \(scoreDescription), \(friendCount) \(friendCount == 1 ? "friend" : "friends")"
                annotationView?.accessibilityHint = "Shows the friends who visited"
            } else {
                let scoreDescription = pinScore.map { ", \($0.accessibilityLabel)" } ?? ", Not rated"
                var stateDescriptions: [String] = []
                if cafe.isFavorite { stateDescriptions.append("Favorite") }
                if cafe.wantToTry { stateDescriptions.append("Want to Try") }
                if presentation.showsFriendsBadge {
                    stateDescriptions.append(
                        "\(presentation.friendCount) \(presentation.friendCount == 1 ? "friend visited" : "friends visited")"
                    )
                }
                let stateDescription = stateDescriptions.isEmpty
                    ? ""
                    : ", " + stateDescriptions.joined(separator: ", ")
                annotationView?.accessibilityLabel = cafe.name + scoreDescription + stateDescription
                annotationView?.accessibilityHint = "Shows cafe details"
            }
            
            return annotationView
        }

        private func createPinContainer(_ presentation: MapPinPresentation) -> UIView {
            if presentation.primaryKind == .friends {
                return createFriendPin(size: 48, presentation: presentation)
            }

            let primarySize: CGFloat = 38
            let canvasSize: CGFloat = presentation.hasStateBadges ? 52 : primarySize
            let primaryOrigin = (canvasSize - primarySize) / 2
            let container = UIView(
                frame: CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
            )
            container.backgroundColor = .clear

            let primaryView: UIView
            switch presentation.primaryKind {
            case .journal:
                primaryView = createDefaultPin(size: primarySize, presentation: presentation)
            case .favorite:
                primaryView = createHeartPin(size: primarySize, presentation: presentation)
            case .wantToTry:
                primaryView = createBookmarkPin(size: primarySize, presentation: presentation)
            case .friends:
                preconditionFailure("Friend pins use their dedicated layout")
            }
            primaryView.frame.origin = CGPoint(x: primaryOrigin, y: primaryOrigin)
            container.addSubview(primaryView)

            if presentation.showsFavoriteBadge {
                container.addSubview(
                    createStateBadge(
                        systemName: "heart.fill",
                        frame: CGRect(x: 0, y: 0, width: 18, height: 18)
                    )
                )
            }
            if presentation.showsWantToTryBadge {
                container.addSubview(
                    createStateBadge(
                        systemName: "bookmark.fill",
                        frame: CGRect(x: canvasSize - 18, y: 0, width: 18, height: 18)
                    )
                )
            }
            if presentation.showsFriendsBadge {
                container.addSubview(
                    createStateBadge(
                        systemName: "person.2.fill",
                        frame: CGRect(
                            x: canvasSize - 18,
                            y: canvasSize - 18,
                            width: 18,
                            height: 18
                        )
                    )
                )
            }
            return container
        }

        private func createDefaultPin(
            size: CGFloat,
            presentation: MapPinPresentation
        ) -> UIView {
            let pinView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            pinView.backgroundColor = pinColor(presentation.ratingBand)
            pinView.layer.cornerRadius = size / 2
            pinView.layer.borderWidth = 2
            pinView.layer.borderColor = UIColor.white.cgColor

            if let scoreText = presentation.scoreText {
                pinView.addSubview(
                    createScoreLabel(
                        text: scoreText,
                        frame: pinView.bounds,
                        band: presentation.ratingBand,
                        fontSize: 12
                    )
                )
            } else {
                let imageView = UIImageView(image: UIImage(systemName: "cup.and.saucer.fill"))
                imageView.tintColor = foregroundColor(presentation.ratingBand)
                imageView.contentMode = .scaleAspectFit
                imageView.frame = pinView.bounds.insetBy(dx: 9, dy: 9)
                pinView.addSubview(imageView)
            }
            return pinView
        }

        private func createFriendPin(
            size: CGFloat,
            presentation: MapPinPresentation
        ) -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            let ratingCircle = UIView(frame: CGRect(x: 1, y: 6, width: 40, height: 40))
            ratingCircle.backgroundColor = pinColor(presentation.ratingBand)
            ratingCircle.layer.cornerRadius = 20
            ratingCircle.layer.borderWidth = 2
            ratingCircle.layer.borderColor = UIColor.white.cgColor

            if let scoreText = presentation.scoreText {
                ratingCircle.addSubview(
                    createScoreLabel(
                        text: scoreText,
                        frame: CGRect(x: 0, y: 6, width: 40, height: 22),
                        band: presentation.ratingBand,
                        fontSize: 12
                    )
                )
                let friendsGlyph = UIImageView(image: UIImage(systemName: "person.2.fill"))
                friendsGlyph.tintColor = foregroundColor(presentation.ratingBand)
                friendsGlyph.contentMode = .scaleAspectFit
                friendsGlyph.frame = CGRect(x: 14, y: 28, width: 12, height: 8)
                ratingCircle.addSubview(friendsGlyph)
            } else {
                let friendsGlyph = UIImageView(image: UIImage(systemName: "person.2.fill"))
                friendsGlyph.tintColor = foregroundColor(presentation.ratingBand)
                friendsGlyph.contentMode = .scaleAspectFit
                friendsGlyph.frame = ratingCircle.bounds.insetBy(dx: 10, dy: 12)
                ratingCircle.addSubview(friendsGlyph)
            }

            container.addSubview(ratingCircle)
            if presentation.friendCount > 0 {
                let countBadge = UILabel(frame: CGRect(x: 29, y: 0, width: 19, height: 19))
                countBadge.text = presentation.friendCount > 9
                    ? "9+"
                    : "\(presentation.friendCount)"
                countBadge.font = .systemFont(ofSize: 9, weight: .bold)
                countBadge.textColor = UIColor(Color.espressoBrown)
                countBadge.textAlignment = .center
                countBadge.backgroundColor = UIColor(Color.foamWhite)
                countBadge.layer.cornerRadius = 9.5
                countBadge.layer.masksToBounds = true
                countBadge.layer.borderWidth = 1
                countBadge.layer.borderColor = UIColor(Color.mugshotSage.opacity(0.35)).cgColor
                container.addSubview(countBadge)
            }
            return container
        }
        
        private func createHeartPin(
            size: CGFloat,
            presentation: MapPinPresentation
        ) -> UIView {
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            containerView.backgroundColor = .clear
            let heartImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            heartImageView.image = UIImage(systemName: "heart.fill")
            heartImageView.tintColor = pinColor(presentation.ratingBand)
            heartImageView.contentMode = .scaleAspectFit
            containerView.addSubview(heartImageView)

            if let scoreText = presentation.scoreText {
                containerView.addSubview(
                    createScoreLabel(
                        text: scoreText,
                        frame: CGRect(x: 0, y: size * 0.26, width: size, height: size * 0.42),
                        band: presentation.ratingBand,
                        fontSize: 10
                    )
                )
            }
            return containerView
        }
        
        private func createBookmarkPin(
            size: CGFloat,
            presentation: MapPinPresentation
        ) -> UIView {
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            containerView.backgroundColor = .clear
            let bookmarkImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            bookmarkImageView.image = UIImage(systemName: "bookmark.fill")
            bookmarkImageView.tintColor = pinColor(presentation.ratingBand)
            bookmarkImageView.contentMode = .scaleAspectFit
            containerView.addSubview(bookmarkImageView)

            if let scoreText = presentation.scoreText {
                containerView.addSubview(
                    createScoreLabel(
                        text: scoreText,
                        frame: CGRect(x: 0, y: size * 0.18, width: size, height: size * 0.44),
                        band: presentation.ratingBand,
                        fontSize: 10
                    )
                )
            }
            return containerView
        }

        private func createScoreLabel(
            text: String,
            frame: CGRect,
            band: MapPinRatingBand,
            fontSize: CGFloat
        ) -> UILabel {
            let scoreLabel = UILabel(frame: frame)
            scoreLabel.text = text
            scoreLabel.font = .systemFont(ofSize: fontSize, weight: .bold)
            scoreLabel.textColor = foregroundColor(band)
            scoreLabel.textAlignment = .center
            scoreLabel.adjustsFontSizeToFitWidth = true
            scoreLabel.minimumScaleFactor = 0.82
            return scoreLabel
        }

        private func createStateBadge(systemName: String, frame: CGRect) -> UIView {
            let badge = UIView(frame: frame)
            badge.backgroundColor = UIColor(Color.foamWhite)
            badge.layer.cornerRadius = frame.width / 2
            badge.layer.borderWidth = 1.5
            badge.layer.borderColor = UIColor.white.cgColor
            badge.layer.shadowColor = UIColor.black.cgColor
            badge.layer.shadowOpacity = 0.14
            badge.layer.shadowRadius = 2
            badge.layer.shadowOffset = CGSize(width: 0, height: 1)

            let imageView = UIImageView(image: UIImage(systemName: systemName))
            imageView.tintColor = UIColor(Color.espressoBrown)
            imageView.contentMode = .scaleAspectFit
            imageView.frame = badge.bounds.insetBy(dx: 4, dy: 4)
            badge.addSubview(imageView)
            return badge
        }

        private func pinColor(_ band: MapPinRatingBand) -> UIColor {
            UIColor(band.color)
        }

        private func foregroundColor(_ band: MapPinRatingBand) -> UIColor {
            band.usesDarkForeground
                ? UIColor(Color.espressoBrown)
                : UIColor(Color.foamWhite)
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let cafeAnnotation = view.annotation as? CafeAnnotation else { return }
            parent.onCafeTap(cafeAnnotation.cafe)
            mapView.deselectAnnotation(cafeAnnotation, animated: false)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let updatedRegion = mapView.region
            guard abs(parent.region.center.latitude - updatedRegion.center.latitude) > 0.000_001
                    || abs(parent.region.center.longitude - updatedRegion.center.longitude) > 0.000_001
                    || abs(parent.region.span.latitudeDelta - updatedRegion.span.latitudeDelta) > 0.000_001
                    || abs(parent.region.span.longitudeDelta - updatedRegion.span.longitudeDelta) > 0.000_001 else {
                return
            }

            // MapKit can invoke this delegate while SwiftUI is updating the
            // representable. Defer the binding write to the next main turn.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.region = updatedRegion
            }
        }

        func mapView(
            _ mapView: MKMapView,
            didChange mode: MKUserTrackingMode,
            animated: Bool
        ) {
            guard parent.trackingMode != mode else { return }
            DispatchQueue.main.async {
                self.parent.trackingMode = mode
            }
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
    let showsFriendContext: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(showsFriendContext ? "Friends’ ratings" : "Your ratings")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.roastBrown)

            Text("Cafe average when available · Sip average otherwise")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.tertiaryText)
            
            HStack(spacing: 16) {
                LegendItem(color: .mapPinHigh, text: "≥ 4.0", accessibilityText: "High", accessibilityValueText: "4.0 or higher")
                LegendItem(color: .mapPinMiddle, text: "3.0–3.9", accessibilityText: "Mid", accessibilityValueText: "3.0 to 3.9")
                LegendItem(color: .mapPinLow, text: "< 3.0", accessibilityText: "Low", accessibilityValueText: "Below 3.0")
                LegendItem(icon: "bookmark.fill", color: .mugshotSage, text: "Want to try", accessibilityText: "Want to try")
            }
            
            Text("Tap a pin to see its source and evidence.")
                .font(.system(size: 10))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .mugshotGlassSurface(
            radius: DesignSystem.Radius.card,
            tint: .foamWhite,
            stroke: Color.foamWhite.opacity(0.58),
            shadow: DesignSystem.Shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 6)
        )
    }
}

struct LegendItem: View {
    var icon: String? = nil
    var color: Color
    var text: String
    var accessibilityText: String? = nil
    var accessibilityValueText: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                    .accessibilityHidden(true)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.roastBrown)
                .accessibilityLabel(accessibilityText ?? text)
                .accessibilityValue(accessibilityValueText ?? "")
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
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.mugshotSage)
        }
        .padding()
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }
}

// MARK: - My Location Button

struct MyLocationButton: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var region: MKCoordinateRegion
    @Binding var trackingMode: MKUserTrackingMode
    var onUseManualSearch: () -> Void = {}
    @State private var showMessage = false
    @State private var showLocationEducation = false
    
    var body: some View {
        VStack(spacing: 8) {
            if showMessage {
                Text("We don't have your location yet")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.foamWhite)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
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
                            trackingMode = .follow
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
                    if status == .notDetermined {
                        showLocationEducation = true
                        return
                    }
                    showMessage = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showMessage = false
                        }
                    }
                }
            }) {
                Image(systemName: trackingMode == .none ? "location.fill" : "location.north.line.fill")
                    .font(.system(size: 18))
                    .foregroundColor(trackingMode == .none ? .espressoBrown : .mugshotSage)
                    .frame(width: 44, height: 44)
                    .mugshotGlassCircle(
                        tint: .foamWhite,
                        stroke: Color.foamWhite.opacity(0.62),
                        shadow: DesignSystem.Shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6),
                        interactive: true
                    )
            }
            .accessibilityLabel(trackingMode == .none ? "Center on my location" : "Following my location")
        }
        .sheet(isPresented: $showLocationEducation) {
            LocationPermissionEducationSheet(
                onContinue: {
                    showLocationEducation = false
                    locationManager.requestLocationPermission()
                },
                onUseSearch: {
                    showLocationEducation = false
                    onUseManualSearch()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct LocationPermissionEducationSheet: View {
    let onContinue: () -> Void
    let onUseSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.foamWhite)
                    .frame(width: 48, height: 48)
                    .background(Color.mugshotSage, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Find cafes around you")
                        .mugshotDisplay(size: 25)
                        .foregroundColor(.espressoBrown)
                    Text("Location makes Map personal. It is not required to use Mugshot.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                permissionBenefit(
                    icon: "map.fill",
                    title: "See nearby coffee memories",
                    message: "Center Map on the area you are exploring."
                )
                permissionBenefit(
                    icon: "location.north.circle.fill",
                    title: "Return to your position",
                    message: "Use the location control whenever the map drifts away."
                )
                permissionBenefit(
                    icon: "magnifyingglass",
                    title: "Search always works",
                    message: "You can still enter a cafe, neighborhood, or city manually."
                )
            }

            Button("Use my location", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)

            Button("Search manually", action: onUseSearch)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.roastBrown)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(Color.creamWhite)
    }

    private func permissionBenefit(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .frame(width: 30, height: 30)
                .background(Color.mugshotMint.opacity(0.34), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

struct MapDiscoveryModeControl: View {
    @Binding var selection: MapDiscoveryMode

    var body: some View {
        MugshotSegmentedControl(
            options: MapDiscoveryMode.allCases,
            selection: $selection,
            title: { $0.rawValue },
            icon: { $0.icon }
        )
    }
}

struct MapDiscoveryFilterBar: View {
    @Binding var selection: MapDiscoveryScope
    let isAuthenticated: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MapDiscoveryScope.available(isAuthenticated: isAuthenticated)) { scope in
                    MugshotFilterChip(
                        title: scope.rawValue,
                        icon: scope.icon,
                        isSelected: selection == scope
                    ) {
                        selection = scope
                    }
                    .accessibilityHint(scope.explanation)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }
}

private struct FriendCafePeekSheet: View {
    let cafe: Cafe
    let pinScore: MapPinScore?
    let friends: [DiscoveryCafeFriend]
    let onDismiss: () -> Void
    let onRevealCafe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.espressoBrown.opacity(0.20))
                .frame(width: 48, height: 5)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.consumerDisplayName)
                        .mugshotDisplay(size: 23)
                        .foregroundColor(.espressoBrown)
                        .lineLimit(2)
                    Text("Friends who logged a sip here")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 8)

                if let pinScore {
                    MugshotRatingBadge(score: pinScore.value, label: pinScore.sourceLabel)
                        .accessibilityLabel(pinScore.accessibilityLabel)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundColor(.tertiaryText)
                .accessibilityLabel("Close friend cafe preview")
            }

            if let pinScore {
                Label(pinScore.evidenceDescription, systemImage: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .accessibilityLabel(
                        "\(pinScore.accessibilityLabel). \(pinScore.evidenceDescription)"
                    )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(friends) { friend in
                        VStack(spacing: 5) {
                            MugshotAvatar(
                                name: friend.displayName,
                                size: 48,
                                imageURL: friend.avatarURL
                            )
                            Text(friend.displayName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                                .lineLimit(1)
                            Text("\(friend.sipCount) \(friend.sipCount == 1 ? "sip" : "sips")")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                        .frame(width: 76)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .frame(height: 82)

            Button(action: onRevealCafe) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.up")
                    Text("Swipe up or tap for cafe details")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.mugshotSage)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 94)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    if value.translation.height < -50 {
                        onRevealCafe()
                    }
                }
        )
    }
}

// MARK: - Cafe Detail Sheet

struct CafeDetailSheet: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @Binding var isPresented: Bool
    let initialPinScore: MapPinScore?
    var onLogVisitRequested: ((Cafe) -> Void)? = nil // Optional closure for navigation
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    @State private var showLogVisit = false
    @State private var showFullDetails = false
    @State private var selectedVisit: Visit?
    @State private var isSyncingCafeState = false
    @State private var cafeStateError: String?
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteVisits = false
    @State private var remoteVisitError: String?
    @State private var selectedRemoteVisit: RemoteVisitSummary?
    @State private var cafeExperienceSummary: RemoteCafeExperienceSummary?
    
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
        let legacyRemoteCount = remoteVisits.filter { $0.visit.cafeSessionID == nil }.count
        if let cafeExperienceSummary {
            return cafeExperienceSummary.physicalSessionCount + legacyRemoteCount
        }
        return max(displayCafe.visitCount, visits.count, remoteVisits.count)
    }

    private var displayedCafeScore: Double? {
        cafeExperienceSummary?.averageCafeRating
    }

    private var displayedSipScore: Double? {
        if !remoteVisits.isEmpty {
            return MapPinScoreResolver.sessionBalancedSipScore(
                remoteVisits.map {
                    MapSipScoreSeed(
                        overallScore: $0.visit.overallScore,
                        cafeSessionID: $0.visit.cafeSessionID
                    )
                },
                audience: .personal
            )?.value
        }
        return MapPinScoreResolver.sessionBalancedSipScore(
            visits.map {
                MapSipScoreSeed(
                    overallScore: $0.overallScore,
                    cafeSessionID: $0.cafeSessionID
                )
            },
            audience: .personal
        )?.value
    }

    private var displayedPinScore: MapPinScore? {
        let sipSeeds: [MapSipScoreSeed]
        if !remoteVisits.isEmpty {
            sipSeeds = remoteVisits.map {
                MapSipScoreSeed(
                    overallScore: $0.visit.overallScore,
                    cafeSessionID: $0.visit.cafeSessionID
                )
            }
        } else {
            sipSeeds = visits.map {
                MapSipScoreSeed(
                    overallScore: $0.overallScore,
                    cafeSessionID: $0.cafeSessionID
                )
            }
        }
        return MapPinScoreResolver.resolve(
            sips: sipSeeds,
            cafeSummary: cafeExperienceSummary,
            audience: .personal
        ) ?? initialPinScore
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.espressoBrown.opacity(0.2))
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
                .accessibilityIdentifier("map.cafeDetail.close")
                .accessibilityLabel("Close cafe card")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mapSheetPrimaryAction

                    mapSheetRelationship

                    if let cafeStateError {
                        Text(cafeStateError)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    mapSheetRecentVisits

                    mapSheetUtilities
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .background(Color.creamWhite)
        .clipShape(RoundedCorner(radius: DesignSystem.Radius.sheet, corners: [.topLeft, .topRight]))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -6)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
        .sheet(isPresented: $showLogVisit) {
            LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
        }
        .sheet(isPresented: $showFullDetails) {
            CafeDetailView(
                cafe: cafe,
                dataManager: dataManager,
                onLogVisitRequested: onLogVisitRequested,
                onAuthenticationRequired: onAuthenticationRequired
            )
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedVisit != nil },
                set: { if !$0 { selectedVisit = nil } }
            )
        ) {
            if let visit = selectedVisit {
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedRemoteVisit != nil },
                set: { if !$0 { selectedRemoteVisit = nil } }
            )
        ) {
            if let visit = selectedRemoteVisit {
                RemoteVisitDetailView(
                    visitId: visit.id,
                    initialSummary: visit,
                    currentUserId: authModel.authenticatedUser?.id,
                    dataManager: dataManager,
                    onAuthenticationRequired: onAuthenticationRequired
                )
            }
        }
        .task(id: displayCafe.remoteCafeId) {
            await loadRemoteCafeVisits()
        }
    }

    private var cafeIdentityBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(displayCafe.consumerDisplayName)
                .mugshotDisplay(size: 25)
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !displayCafe.address.isEmpty {
                Label(displayCafe.address, systemImage: "mappin.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.tertiaryText)
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

                if let category = displayCafe.consumerPlaceCategory {
                    mapSheetPill(category, systemImage: "tag.fill")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mapSheetStats: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
        return LazyVGrid(columns: columns, spacing: 10) {
            mapSheetStatCard(
                title: "Cafe average",
                value: displayedCafeScore.map { String(format: "%.1f", $0) } ?? "Not rated",
                systemImage: "storefront.fill"
            )

            mapSheetStatCard(
                title: "Cafe visits",
                value: "\(displayedVisitCount)",
                systemImage: "mappin.and.ellipse"
            )

            mapSheetStatCard(
                title: "Sip average",
                value: displayedSipScore.map { String(format: "%.1f", $0) } ?? "Unrated",
                systemImage: "star.fill"
            )

            mapSheetStatCard(
                title: "Sips logged",
                value: "\(max(visits.count, remoteVisits.count))",
                systemImage: "cup.and.saucer.fill"
            )
        }
    }

    private var mapSheetPrimaryAction: some View {
        Button {
            if let onLogVisit = onLogVisitRequested {
                onLogVisit(displayCafe)
            } else {
                showLogVisit = true
            }
        } label: {
            Label("Log a Sip", systemImage: "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var mapSheetRelationship: some View {
        VStack(alignment: .leading, spacing: 12) {
            MugshotSectionTitle(
                title: visits.isEmpty ? "Your relationship" : "Your history",
                subtitle: relationshipSubtitle
            )
            if let displayedPinScore {
                mapSheetPinEvidence(displayedPinScore)
            }
            mapSheetStats
            if displayCafe.isFavorite || displayCafe.wantToTry {
                HStack(spacing: 8) {
                    if displayCafe.isFavorite {
                        mapSheetPill("Favorite", systemImage: "heart.fill")
                    }
                    if displayCafe.wantToTry {
                        mapSheetPill("Want to Try", systemImage: "bookmark.fill")
                    }
                }
            }
        }
        .padding(14)
        .background(Color.sandBeige.opacity(0.4), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
    }

    private func mapSheetPinEvidence(_ score: MapPinScore) -> some View {
        HStack(spacing: 12) {
            MugshotRatingBadge(score: score.value, label: score.sourceLabel)
                .accessibilityLabel(score.accessibilityLabel)

            VStack(alignment: .leading, spacing: 3) {
                Text(score.pinUseTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(score.evidenceDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color.foamWhite.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var relationshipSubtitle: String {
        if let mostRecent = visits.max(by: { $0.createdAt < $1.createdAt }) {
            return "Last remembered \(mostRecent.createdAt.formatted(date: .abbreviated, time: .omitted))"
        }
        if displayCafe.wantToTry {
            return "Saved for a future coffee run"
        }
        if displayCafe.isFavorite {
            return "One of your favorite cafes"
        }
        return "New to you — remember a sip or save it for later"
    }

    private var mapSheetUtilities: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(alignment: .leading, spacing: 12) {
            MugshotSectionTitle(title: "Cafe actions")
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
            Text("Recent sips")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.espressoBrown)

            if isLoadingRemoteVisits && remoteVisits.isEmpty && visits.isEmpty {
                MugshotLoadingState(layout: .journal, count: 2)
            } else if remoteVisits.isEmpty && visits.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.roastBrown.opacity(0.42))

                    Text("No sips here yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text("Log a sip here to add it to your journal.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 14)
                .background(Color.sandBeige.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                if let remoteVisitError {
                    Text(remoteVisitError)
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                }
            } else if !remoteVisits.isEmpty {
                ForEach(remoteVisits.prefix(5)) { visit in
                    Button {
                        selectedRemoteVisit = visit
                    } label: {
                        MapRemoteVisitRow(visit: visit)
                    }
                    .buttonStyle(.plain)
                }
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

    @MainActor
    private func loadRemoteCafeVisits() async {
        guard let remoteCafeID = displayCafe.remoteCafeId else {
            remoteVisits = []
            cafeExperienceSummary = nil
            remoteVisitError = nil
            return
        }

        isLoadingRemoteVisits = true
        remoteVisitError = nil
        do {
            let client = try SupabaseClientProvider.shared.client()
            let visitService = VisitService(client: client)
            if let userID = authModel.authenticatedUser?.id {
                async let visitsRequest = visitService.fetchCafeVisits(
                    cafeId: remoteCafeID,
                    userId: userID,
                    limit: 200
                )
                async let summaryRequest = CafeSessionService(client: client).fetchCafeSummary(
                    cafeID: remoteCafeID,
                    scope: .personal
                )
                let (visits, summary) = try await (visitsRequest, summaryRequest)
                remoteVisits = visits
                cafeExperienceSummary = summary
            } else {
                remoteVisits = try await visitService.fetchVisibleCafeVisits(
                    cafeId: remoteCafeID,
                    currentUserId: nil,
                    limit: 5
                )
                cafeExperienceSummary = nil
            }
            isLoadingRemoteVisits = false
        } catch is CancellationError {
            return
        } catch {
            remoteVisitError = "Community visits are unavailable right now."
            isLoadingRemoteVisits = false
        }
    }

    private func mapSheetPill(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.roastBrown.opacity(0.78))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.sandBeige.opacity(0.58))
        .clipShape(Capsule())
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
        .background(Color.sandBeige.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
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
                .background(isSelected ? Color.mugshotSage.opacity(0.34) : Color.sandBeige.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                        .stroke(isSelected ? Color.mugshotSage : Color.clear, lineWidth: 1.5)
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
        if previousCafe.isFavorite != isFavorite {
            MugshotAnalytics.shared.capture(
                .cafeStateChanged(
                    state: .favorite,
                    action: isFavorite ? .added : .removed,
                    surface: .map
                )
            )
        }
        if previousCafe.wantToTry != wantToTry {
            MugshotAnalytics.shared.capture(
                .cafeStateChanged(
                    state: .wantToTry,
                    action: wantToTry ? .added : .removed,
                    surface: .map
                )
            )
        }

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

private struct MapRemoteVisitRow: View {
    let visit: RemoteVisitSummary

    var body: some View {
        HStack(spacing: 12) {
            RemotePhotoImageView(
                urlString: visit.visit.posterPhotoURL,
                placeholderSystemName: "cup.and.saucer.fill",
                contentMode: .fill
            )
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(visit.visit.drinkDisplayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)
                Text("\(visit.authorDisplayName) · \(visit.visit.createdAtDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
                    .lineLimit(1)
                if let caption = visit.visit.caption.remoteTrimmedNonEmpty {
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Label(String(format: "%.1f", visit.visit.overallScore), systemImage: "star.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.espressoBrown)
        }
        .padding(10)
        .background(Color.sandBeige.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
    }
}

struct VisitEntryRow: View {
    let visit: Visit
    
    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(photoPath: visit.posterImagePath, size: 50)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
            
            VStack(alignment: .leading, spacing: 5) {
                Text(visit.journalDrinkName)
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
            
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(visit.overallScore > 0 ? String(format: "%.1f", visit.overallScore) : "Unrated")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.espressoBrown)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.mugshotSage.opacity(0.36))
            .clipShape(Capsule())
        }
        .padding(12)
        .cardStyle()
    }
}

// MARK: - Search Results List

struct SearchResultsList: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @Binding var searchText: String
    @ObservedObject var searchService: MapSearchService
    @ObservedObject var dataManager: DataManager
    @Binding var region: MKCoordinateRegion
    @Binding var selectedCafe: Cafe?
    @Binding var showCafeDetail: Bool
    @Binding var isSearchActive: Bool
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onSelectCafe: ((Cafe) -> Void)? = nil
    @State private var resolvingRecentID: MapSearchRecent.ID?
    @State private var selectionResolutionTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            Color.creamWhite

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                discoveryLanding
            } else if let error = searchService.searchError {
                searchErrorState(error)
            } else {
                activeSearchResults
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.64)
        .clipShape(RoundedCorner(radius: DesignSystem.Radius.sheet, corners: [.bottomLeft, .bottomRight]))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.mugshotLine)
                .frame(height: 1)
        }
        .onDisappear {
            selectionResolutionTask?.cancel()
            selectionResolutionTask = nil
            resolvingRecentID = nil
            searchService.cancelSearch()
        }
    }

    private var discoveryLanding: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !searchService.recents.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            SearchSectionTitle(title: "Recent", subtitle: "Pick up where you left off")
                            Spacer()
                            Button("Clear") { searchService.removeAllRecents() }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.mugshotSage)
                                .accessibilityLabel("Clear recent searches")
                        }

                        ForEach(searchService.recents) { recent in
                            Button {
                                selectRecent(recent)
                            } label: {
                                SearchLandingRow(
                                    icon: "clock.arrow.circlepath",
                                    title: recent.title,
                                    subtitle: recent.subtitle,
                                    isLoading: resolvingRecentID == recent.id
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(resolvingRecentID != nil)
                            .accessibilityIdentifier(
                                onSelectCafe == nil
                                    ? "map.search.recent.\(recent.id)"
                                    : "logASipV3.cafeSearch.recent.\(recent.id)"
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SearchSectionTitle(
                        title: "Explore nearby",
                        subtitle: "Coffee-first suggestions for this map area"
                    )

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        discoveryButton("Coffee", icon: "cup.and.saucer.fill", query: "coffee")
                        discoveryButton("Roasters", icon: "flame.fill", query: "coffee roaster")
                        discoveryButton("Bakeries", icon: "birthday.cake.fill", query: "bakery")
                        discoveryButton("Brunch", icon: "fork.knife", query: "brunch")
                    }
                }

                let mapCenter = CLLocation(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude
                )
                let savedPlaces = Array(dataManager.appData.cafes
                    .filter { cafe in
                        guard cafe.isFavorite || cafe.wantToTry || cafe.visitCount > 0 else {
                            return false
                        }

                        // A composer can select any saved journal cafe, including
                        // manually created places that do not have coordinates yet.
                        guard onSelectCafe == nil else { return true }
                        guard let location = cafe.location else { return false }
                        return CLLocation(
                            latitude: location.latitude,
                            longitude: location.longitude
                        ).distance(from: mapCenter) < 100_000
                    }
                    .prefix(4))
                if !savedPlaces.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SearchSectionTitle(title: "Your places", subtitle: "From your Mugshot journal")
                        ForEach(savedPlaces) { cafe in
                            LocalCafeRow(
                                cafe: cafe,
                                accessibilityIdentifier: onSelectCafe == nil
                                    ? "map.search.local.\(cafe.id.uuidString)"
                                    : "logASipV3.cafeSearch.local.\(cafe.id.uuidString)",
                                onTap: { selectLocalCafe(cafe) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var activeSearchResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let corrected = searchService.correctedQuery {
                    Label("Searching for “\(corrected)”", systemImage: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .accessibilityLabel("Typo corrected. Searching for \(corrected)")
                }

                if !searchService.completions.isEmpty && searchService.searchResults.isEmpty {
                    SearchSectionTitle(title: "Suggestions", subtitle: nil)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    ForEach(searchService.completions.prefix(4), id: \.self) { completion in
                        SearchCompletionRow(completion: completion) {
                            selectCompletion(completion)
                        }
                    }
                }

                if searchService.isUpdatingSuggestions {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Updating suggestions…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .accessibilityLabel("Updating suggestions")
                }

                if searchService.isSearching {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(searchService.searchResults.isEmpty ? "Finding the best matches…" : "Updating results…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .accessibilityLabel("Searching")
                }

                if !searchService.searchResults.isEmpty {
                    HStack {
                        SearchSectionTitle(
                            title: "Places",
                            subtitle: searchService.searchedExpandedArea ? "Including a wider area" : "Best matches first"
                        )
                        Spacer()
                        Text("\(searchService.searchResults.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.sandBeige, in: Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                    ForEach(searchService.searchResults, id: \.self) { mapItem in
                        SearchResultRow(mapItem: mapItem, region: region) {
                            handleSearchResult(mapItem)
                        }
                    }
                } else if !searchService.isSearching &&
                    !searchService.isUpdatingSuggestions &&
                    searchService.completions.isEmpty {
                    zeroResultsState
                }
            }
            .padding(.bottom, 18)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var zeroResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.mugshotSage)
            Text("No places matched “\(searchText)”")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .multilineTextAlignment(.center)
            Text("Try a place name, street address, neighborhood, or category.")
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            typedCafeButton
            Button("Browse coffee nearby") {
                runDiscoverySearch("coffee")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.espressoBrown)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    private func searchErrorState(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.roastBrown)
            Text("We couldn’t finish that search")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.espressoBrown)
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            Button("Try again") { searchService.retry() }
                .buttonStyle(PrimaryButtonStyle())
            typedCafeButton
        }
        .padding(28)
    }

    private func discoveryButton(_ title: String, icon: String, query: String) -> some View {
        Button { runDiscoverySearch(query) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 30, height: 30)
                    .background(Color.mugshotMint.opacity(0.22), in: Circle())
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Explore nearby \(title)")
    }

    private func runDiscoverySearch(_ query: String) {
        searchText = query
        isSearchFieldFocused.wrappedValue = true
        searchService.search(query: query, region: region, immediately: true)
    }

    private func selectRecent(_ recent: MapSearchRecent) {
        guard resolvingRecentID == nil else { return }
        isSearchFieldFocused.wrappedValue = false

        if let cafe = matchingLocalCafe(for: recent) {
            completeSelection(of: cafe, centeredAt: cafe.location)
            return
        }

        resolvingRecentID = recent.id
        selectionResolutionTask?.cancel()
        selectionResolutionTask = Task { @MainActor in
            let mapItem = await searchService.resolve(recent: recent, region: region)
            guard !Task.isCancelled, resolvingRecentID == recent.id else { return }
            resolvingRecentID = nil
            if let mapItem {
                handleSearchResult(mapItem)
            }
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        resolvingRecentID = nil
        isSearchFieldFocused.wrappedValue = false
        selectionResolutionTask?.cancel()
        selectionResolutionTask = Task { @MainActor in
            guard let mapItem = await searchService.resolve(
                completion: completion,
                region: region
            ), !Task.isCancelled else {
                return
            }
            handleSearchResult(mapItem)
        }
    }

    private func matchingLocalCafe(for recent: MapSearchRecent) -> Cafe? {
        let recentName = normalizedPlaceName(recent.title)
        let nameMatches = dataManager.appData.cafes.filter {
            normalizedPlaceName($0.consumerDisplayName) == recentName
        }
        guard !nameMatches.isEmpty else { return nil }

        let recentAddressTokens = Set(normalizedPlaceText(recent.subtitle).split(separator: " "))
        guard !recentAddressTokens.isEmpty else {
            return nameMatches.count == 1 ? nameMatches[0] : nil
        }

        let rankedMatches = nameMatches
            .map { cafe in
                let cafeAddressTokens = Set(normalizedPlaceText(cafe.address).split(separator: " "))
                return (cafe, cafeAddressTokens.intersection(recentAddressTokens).count)
            }
            .sorted { $0.1 > $1.1 }
        guard let best = rankedMatches.first, best.1 > 0 else { return nil }
        if rankedMatches.count > 1, rankedMatches[1].1 == best.1 { return nil }
        return best.0
    }

    private func normalizedPlaceName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func normalizedPlaceText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }

    private func selectLocalCafe(_ cafe: Cafe) {
        completeSelection(of: cafe, centeredAt: cafe.location)
    }
    
    private func handleSearchResult(_ mapItem: MKMapItem) {
        guard let location = mapItem.placemark.location?.coordinate else { return }
        
        // Find or create cafe
        let cafe = dataManager.findOrCreateCafe(from: mapItem)
        searchService.recordRecent(mapItem)
        completeSelection(of: cafe, centeredAt: location)
    }

    private func completeSelection(
        of cafe: Cafe,
        centeredAt location: CLLocationCoordinate2D?
    ) {
        selectedCafe = cafe
        if let location {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }

        // Clear the discovery surface before presenting the destination. The
        // map then remains the sole background behind its cafe card, while the
        // composer dismisses its picker with the same selected value.
        selectionResolutionTask?.cancel()
        selectionResolutionTask = nil
        resolvingRecentID = nil
        isSearchFieldFocused.wrappedValue = false
        searchText = ""
        searchService.cancelSearch()
        isSearchActive = false
        showCafeDetail = onSelectCafe == nil

        Task { await hydrateSelectedCafe(cafe) }
        onSelectCafe?(cafe)
    }

    @MainActor
    private func hydrateSelectedCafe(_ cafe: Cafe) async {
        guard authModel.authenticatedUser != nil else { return }
        do {
            let client = try SupabaseClientProvider.shared.client()
            guard let summary = try await CafeService(client: client).resolveSummary(for: cafe) else {
                return
            }
            let hydrated = dataManager.applyResolvedCafeSummary(summary, toLocalCafeID: cafe.id)
            if selectedCafe?.id == cafe.id {
                selectedCafe = hydrated
            }
        } catch is CancellationError {
            return
        } catch {
            // MapKit results remain usable when community hydration is unavailable.
        }
    }

    private var typedCafeButton: some View {
        Button("Use \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\" as a cafe") {
            let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let cafe = dataManager.findOrCreateCafe(named: name)
            completeSelection(of: cafe, centeredAt: cafe.location)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.mugshotSage)
    }
}

private struct SearchSectionTitle: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

private struct SearchLandingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isLoading: Bool

    init(icon: String, title: String, subtitle: String, isLoading: Bool = false) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isLoading = isLoading
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.mugshotSage)
                .frame(width: 34, height: 34)
                .background(Color.mugshotMint.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Opening cafe")
            } else {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }
}

private struct SearchCompletionRow: View {
    let completion: MKLocalSearchCompletion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SearchLandingRow(
                icon: completion.subtitle.isEmpty ? "magnifyingglass" : "mappin.and.ellipse",
                title: completion.title,
                subtitle: completion.subtitle
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel([completion.title, completion.subtitle].filter { !$0.isEmpty }.joined(separator: ", "))
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
        MapSearchService.subtitle(for: mapItem)
    }

    private var categoryLabel: String? {
        MugshotCafeCategory.display(mapItem.pointOfInterestCategory?.rawValue)
    }

    private var iconName: String {
        switch mapItem.pointOfInterestCategory {
        case .cafe:
            return "cup.and.saucer.fill"
        case .bakery:
            return "birthday.cake.fill"
        case .restaurant:
            return "fork.knife"
        default:
            return "mappin"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 36, height: 36)
                    .background(Color.mugshotMint.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(mapItem.name ?? "Cafe")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(1)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    }

                    if let categoryLabel {
                        Text(categoryLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.mugshotSage)
                    }
                }
                
                Spacer()
                
                if !distance.isEmpty {
                    Text(distance)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tertiaryText)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.foamWhite)
        }
        .buttonStyle(.plain)
        .accessibilityLabel([
            mapItem.name ?? "Place",
            categoryLabel,
            subtitle,
            distance,
            "Show details"
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "))
        Divider()
            .padding(.leading, 64)
    }
}

// MARK: - Local Cafe Row

struct LocalCafeRow: View {
    let cafe: Cafe
    let accessibilityIdentifier: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.consumerDisplayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    
                    if !cafe.address.isEmpty {
                        Text(cafe.address)
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.mugshotSage)
                        .font(.system(size: 12))
                    Text(cafe.consumerScoreLabel)
                        .font(.system(size: 14))
                        .foregroundColor(.roastBrown)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.foamWhite)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        Divider()
            .padding(.leading)
    }
}
