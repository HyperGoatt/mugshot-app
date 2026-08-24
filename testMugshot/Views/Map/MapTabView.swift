//
//  MapTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import MapKit
import CoreLocation

enum MapDiscoveryRadius {
    static let miles: ClosedRange<Double> = 0...50

    static func kilometers(forMiles miles: Double) -> Double {
        max(miles, 1) * 1.609_344
    }
}

enum MapDiscoveryScope: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case all = "All"
    case wantToTry = "Want to Try"
    case favorites = "Favorites"
    case visited = "Visited"
    case friends = "Friends"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "map.fill"
        case .forYou: return "sparkles"
        case .favorites: return "heart.fill"
        case .wantToTry: return "bookmark.fill"
        case .visited: return "cup.and.saucer.fill"
        case .friends: return "person.2.fill"
        }
    }

    var explanation: String {
        switch self {
        case .all: return "Nearby, friend, and community cafes together"
        case .forYou: return "Nearby cafes ranked with your saves, friends, and Mugshots"
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
        case .forYou:
            return isAuthenticated
                ? [.nearby, .lovedByFriends, .trending]
                : [.nearby, .trending]
        }
    }

    static func available(isAuthenticated: Bool) -> [MapDiscoveryScope] {
        var scopes: [MapDiscoveryScope] = isAuthenticated
            ? [.visited, .favorites, .wantToTry, .friends, .all]
            : [.visited, .favorites, .wantToTry, .all]
        if DiscoveryFeatureFlags.isEnabled(.mapDiscovery) {
            scopes.append(.forYou)
        }
        return scopes
    }
}

enum MapDiscoveryEligibility {
    static func isNetNew(
        isVisited: Bool,
        isSaved: Bool,
        isInPersonalJournal: Bool
    ) -> Bool {
        !isVisited && !isSaved && !isInPersonalJournal
    }

    static func isNetNew(
        _ cafe: DiscoveryCafe,
        excluding personalJournalCafeIDs: Set<UUID>
    ) -> Bool {
        isNetNew(
            isVisited: cafe.isVisited,
            isSaved: cafe.isSaved,
            isInPersonalJournal: personalJournalCafeIDs.contains(cafe.id)
        )
    }

    static func personalJournalCafeIDs(in cafes: [Cafe]) -> Set<UUID> {
        Set(cafes.compactMap { cafe in
            guard cafe.visitCount > 0 || cafe.isFavorite || cafe.wantToTry else { return nil }
            return cafe.remoteCafeId ?? cafe.id
        })
    }
}

struct MapTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var locationManager: LocationManager
    var hidesUserLocation = false
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @StateObject private var searchService = MapSearchService()
    @StateObject private var appleCafeDiscovery = AppleCafeDiscoveryService()
    
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
    @State private var remoteMapPinUserId: UUID?
    @State private var activeMapLoadID: UUID?
    @AppStorage("MugshotMap.discoveryScope.v1") private var discoveryScope: MapDiscoveryScope = .visited
    @State private var discoveryRadiusMiles = 10.0
    @State private var discoveryMapCafes: [Cafe] = []
    @State private var discoveryCafesByID: [UUID: DiscoveryCafe] = [:]
    @State private var friendCafeSummariesByID: [UUID: RemoteCafeExperienceSummary] = [:]
    @State private var friendSipSummariesByID: [UUID: RemoteFriendMapSipSummary] = [:]
    @State private var friendPreviewCafe: Cafe?
    @State private var clusterSelection: MapClusterSelection?
    @State private var userTrackingMode: MKUserTrackingMode = .none
    @State private var shouldCenterOnNextLocationUpdate = true
    @State private var forYouRecommendations: [ForYouRecommendation] = []
    @State private var enrichedCandidatesByID: [String: DiscoveryPlaceCandidate] = [:]
    @State private var serverForYouEvidenceByCandidateID: [String: [DiscoveryEvidence]] = [:]
    @State private var selectedRecommendationID: String?
    @State private var selectedWalkingMinutes: Int?
    @State private var forYouListPresentation: ForYouListPresentation?
    @State private var hasPendingAreaSearch = false
    @State private var showsNearbyReminderEducation = false
    @State private var nearbyReminderError: String?
    @State private var isPresentingPendingSavedCafe = false
    
    // The deterministic fixture remains city-scale for adaptive-map UI tests.
    // Production never uses this as its unavailable-location fallback.
    private let uiTestingRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    private var effectiveRegion: MKCoordinateRegion {
        if let region {
            return region
        }
        if MugshotLaunchEnvironment.isUITesting {
            return uiTestingRegion
        }
        return MapInitialCameraPolicy.region(
            knownLocation: locationManager.getCurrentLocation(),
            isLocationAuthorized: locationAccessAuthorized,
            cafeCoordinates: displayedMapCafes.compactMap(\.location)
        )
    }
    
    var body: some View {
        mapBody
    }

    private var mapBody: some View {
        ZStack {
            // Map with POIs hidden
            MapViewRepresentable(
                region: Binding(
                    get: { effectiveRegion },
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
                highlightedCafe: showCafeDetail || friendPreviewCafe != nil || discoveryScope == .forYou
                    ? selectedCafe
                    : nil,
                friendCounts: friendCountsByCafeID,
                pinScores: displayedPinScoresByCafeID,
                placeNames: mapPlaceNamesByCafeID,
                showsFriendContext: discoveryScope == .friends,
                scope: discoveryScope,
                showsUserLocation: locationAccessAuthorized && !hidesUserLocation,
                trackingMode: $userTrackingMode,
                onCafeTap: { cafe in
                    handleMapCafeTap(cafe)
                },
                onClusterListRequested: { cafes in
                    clusterSelection = MapClusterSelection(cafes: cafes)
                },
                onUserRegionChange: { updatedRegion in
                    guard discoveryScope == .forYou || discoveryScope == .all else { return }
                    hasPendingAreaSearch = appleCafeDiscovery.shouldSearch(updatedRegion)
                }
            )
            .ignoresSafeArea()
            .onAppear {
                // Opening Map never prompts. Existing permission is honored;
                // new permission is requested only from the location control.
                initializeLocationIfNeeded()
                presentPendingSavedCafeIfNeeded()
            }
            .onChange(of: locationManager.location) { oldValue, newLocation in
                guard !MugshotLaunchEnvironment.isUITesting else { return }
                // When we get a location update and we have permission, center the map
                if let location = newLocation {
                    let isAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
                    
                    if isAuthorized {
                        // If we haven't initialized yet, or if this is a fresh location update
                        if !hasInitializedLocation
                            || oldValue == nil
                            || shouldCenterOnNextLocationUpdate {
                            hasInitializedLocation = true
                            shouldCenterOnNextLocationUpdate = false
                            withAnimation {
                                region = MKCoordinateRegion(
                                    center: location.coordinate,
                                    span: MapInitialCameraPolicy.nearbySpan
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
                    shouldCenterOnNextLocationUpdate = true
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
                        region = effectiveRegion
                    }
                case .notDetermined:
                    // Will request when needed
                    break
                @unknown default:
                    break
                }
            }
            
            if friendPreviewCafe == nil && !showCafeDetail {
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

                mapDiscoveryControls

                if hasPendingAreaSearch,
                   !isSearchActive,
                   DiscoveryFeatureFlags.isEnabled(.mapDiscovery),
                   (discoveryScope == .forYou || discoveryScope == .all) {
                    Button {
                        Task { await refreshAppleCafeDiscovery() }
                    } label: {
                        Label("Search this area", systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .mugshotGlassSurface(radius: 19, tint: .foamWhite, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .accessibilityIdentifier("map.searchThisArea")
                }

                // Search results list (inline below search bar)
                if isSearchActive {
                    SearchResultsList(
                        searchText: $searchText,
                        searchService: searchService,
                        dataManager: dataManager,
                        region: Binding(
                            get: { effectiveRegion },
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
                                get: { effectiveRegion },
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
            
            // For You uses the selected recommendation overlay. Personal and
            // friend scopes retain their familiar score legend.
            VStack {
                Spacer()
                if !showCafeDetail && friendPreviewCafe == nil && !isSearchActive {
                    if DiscoveryFeatureFlags.isEnabled(.mapDiscovery), discoveryScope == .forYou {
                        forYouBottomOverlay
                    } else {
                        RatingsLegend(showsFriendContext: discoveryScope == .friends)
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                            .transition(.opacity)
                    }
                }
            }
            
            if let cafe = friendPreviewCafe,
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
        .task(id: "apple-cafes-\(discoveryScope.rawValue)-\(authModel.authenticatedUser?.id.uuidString ?? "guest")") {
            guard DiscoveryFeatureFlags.isEnabled(.mapDiscovery) else { return }
            guard discoveryScope == .forYou || discoveryScope == .all else { return }
            await refreshAppleCafeDiscovery()
        }
        .task(id: selectedRecommendationID) {
            await refreshWalkingETA()
        }
        .onChange(of: tabCoordinator.pendingMapCafe?.id) { _, _ in
            presentPendingSavedCafeIfNeeded()
        }
        .onChange(of: discoveryScope) { _, _ in
            if isPresentingPendingSavedCafe {
                rebuildForYouRecommendations()
                return
            }
            friendPreviewCafe = nil
            showCafeDetail = false
            selectedCafe = nil
            selectedRecommendationID = nil
            rebuildForYouRecommendations()
        }
        .onChange(of: dataManager.journalRevision) { _, _ in
            appleCafeDiscovery.refreshLocalState(knownCafes: dataManager.appData.cafes)
            rebuildForYouRecommendations()
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
        .sheet(item: $clusterSelection) { selection in
            MapClusterCafeListSheet(
                cafes: selection.cafes,
                pinScores: pinScoresByCafeID,
                onSelect: { cafe in
                    clusterSelection = nil
                    DispatchQueue.main.async {
                        handleMapCafeTap(cafe)
                    }
                }
            )
        }
        .sheet(item: $forYouListPresentation) { _ in
            ForYouListSheet(
                recommendations: forYouRecommendations,
                isStillLearning: isStillLearningTaste,
                onSelect: { recommendation in
                    selectRecommendation(recommendation)
                }
            )
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                let recommendation = selectedForYouRecommendation.flatMap {
                    $0.cafe.id == cafe.id ? $0 : nil
                }
                CafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    initialDetent: .large,
                    discoveryReason: recommendation?.reason,
                    discoveryEvidence: recommendation?.evidence ?? [],
                    discoverySource: recommendation == nil ? .appleSearch : .forYou,
                    applePhoneNumber: recommendation?.candidate.phoneNumber,
                    onLogVisitRequested: onLogVisitRequested,
                    onAuthenticationRequired: onAuthenticationRequired
                )
                .accessibilityIdentifier("map.cafeDetail.sheet")
            }
        }
        .alert("Remember this cafe when you are nearby?", isPresented: $showsNearbyReminderEducation) {
            Button("Not now", role: .cancel) {
                UserDefaults.standard.set(
                    true,
                    forKey: NearbyCafeReminderCoordinator.educationDismissedKey
                )
            }
            Button("Continue") {
                Task {
                    let enabled = await NearbyCafeReminderCoordinator.shared.requestEnable(
                        cafes: dataManager.appData.cafes
                    )
                    if !enabled {
                        nearbyReminderError = "Nearby reminders need notification and Always Location permission. You can change both in iOS Settings."
                    }
                }
            }
        } message: {
            Text("Mugshot can send one tasteful reminder when a cafe you deliberately saved is nearby. It asks for notifications first, then Always Location, and you can turn it off anytime.")
        }
        .alert("Nearby reminders are off", isPresented: Binding(
            get: { nearbyReminderError != nil },
            set: { if !$0 { nearbyReminderError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(nearbyReminderError ?? "Please try again.")
        }
    }

    private var locationAccessAuthorized: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways
    }

    private var mapDiscoveryControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.espressoBrown.opacity(0.6))
                        .accessibilityHidden(true)

                    TextField("Search places", text: $searchText)
                        .accessibilityIdentifier("map.search.query")
                        .foregroundColor(.inputText)
                        .tint(.mugshotSage)
                        .accentColor(.mugshotSage)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .onChange(of: searchText) { _, newValue in
                            if newValue.remoteTrimmedNonEmpty != nil {
                                isSearchActive = true
                                searchService.search(query: newValue, region: effectiveRegion)
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
                                region: effectiveRegion,
                                immediately: true
                            )
                            isSearchFieldFocused = false
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchService.cancelSearch()
                            isSearchActive = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.espressoBrown.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .mugshotGlassSurface(
                    radius: 26,
                    tint: .foamWhite,
                    stroke: Color.foamWhite.opacity(0.62),
                    shadow: DesignSystem.Shadow(
                        color: .black.opacity(0.10),
                        radius: 16,
                        x: 0,
                        y: 6
                    ),
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
                } else {
                    MapDiscoveryScopeMenu(
                        selection: $discoveryScope,
                        isAuthenticated: authModel.authenticatedUser != nil
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, isSearchActive ? 12 : 8)
            .background(Color.creamWhite.opacity(isSearchActive ? 0.92 : 0))
            .animation(DesignSystem.Motion.base, value: isSearchActive)

        }
        .onChange(of: isSearchFieldFocused) { _, isFocused in
            if isFocused { isSearchActive = true }
        }
        .onAppear {
            if !DiscoveryFeatureFlags.isEnabled(.mapDiscovery), discoveryScope == .forYou {
                discoveryScope = .visited
            }
        }
    }

    @ViewBuilder
    private var forYouBottomOverlay: some View {
        VStack(spacing: 10) {
            if let recommendation = selectedForYouRecommendation {
                ForYouRecommendationCard(
                    recommendation: recommendation,
                    walkingMinutes: selectedWalkingMinutes,
                    onOpen: { openRecommendation(recommendation) },
                    onDirections: { openDirections(for: recommendation) },
                    onWantToTry: { toggleWantToTry(for: recommendation) }
                )
                .padding(.horizontal, 16)
            } else if appleCafeDiscovery.isLoading {
                ProgressView("Finding nearby cafes…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .mugshotGlassSurface(radius: 26, tint: .foamWhite)
            } else {
                StillLearningDiscoveryView()
                    .padding(.horizontal, 16)
            }

            Button {
                forYouListPresentation = ForYouListPresentation()
                MugshotAnalytics.shared.capture(.discovery(
                    action: .picksOpened,
                    source: .forYou,
                    surface: .forYouList,
                    rankingVersion: ForYouRankingConfiguration.v1.version,
                    cafeID: nil
                ))
            } label: {
                HStack(spacing: 8) {
                    Text("See all picks")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.mugshotSageText)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .mugshotGlassSurface(radius: 19, tint: .creamWhite, interactive: true)
            }
            .buttonStyle(.plain)
            .disabled(forYouRecommendations.isEmpty)
            .opacity(forYouRecommendations.isEmpty ? 0.55 : 1)
            .accessibilityIdentifier("map.forYou.seeAll")
        }
        .padding(.bottom, 96)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var selectedForYouRecommendation: ForYouRecommendation? {
        if let selectedRecommendationID,
           let selected = forYouRecommendations.first(where: { $0.id == selectedRecommendationID }) {
            return selected
        }
        return forYouRecommendations.first
    }

    private var isStillLearningTaste: Bool {
        ForYouLearningPolicy.isStillLearning(
            mugshotCount: dataManager.appData.visits.filter { $0.context == .cafe }.count
        )
    }

    @MainActor
    private func refreshAppleCafeDiscovery() async {
        if MugshotLaunchEnvironment.isUITesting {
            appleCafeDiscovery.refreshLocalState(knownCafes: dataManager.appData.cafes)
            appleCafeDiscovery.markRegionAsSearched(effectiveRegion)
            hasPendingAreaSearch = false
            rebuildForYouRecommendations()
            return
        }
        await appleCafeDiscovery.search(
            region: effectiveRegion,
            knownCafes: dataManager.appData.cafes,
            limit: 100
        )
        hasPendingAreaSearch = false
        rebuildForYouRecommendations()
        await refreshDiscoveryEnrichment()
    }

    @MainActor
    private func rebuildForYouRecommendations() {
        let sourceCandidates = currentForYouCandidates()

        var evidenceByCandidateID = forYouEvidence(for: sourceCandidates)
        for candidate in sourceCandidates {
            guard let serverEvidence = serverForYouEvidenceByCandidateID[candidate.id] else {
                continue
            }
            var combined = evidenceByCandidateID[candidate.id] ?? []
            for evidence in serverEvidence where !combined.contains(where: {
                $0.kind == evidence.kind
                    && $0.reason == evidence.reason
                    && $0.authorID == evidence.authorID
            }) {
                combined.append(evidence)
            }
            evidenceByCandidateID[candidate.id] = combined
        }

        forYouRecommendations = ForYouRankingService.rank(
            candidates: sourceCandidates,
            evidenceByCandidateID: evidenceByCandidateID,
            userLocation: discoveryRankingLocation,
            limit: 20
        )
        if let selectedRecommendationID,
           forYouRecommendations.contains(where: { $0.id == selectedRecommendationID }) {
            return
        }
        selectedRecommendationID = forYouRecommendations.first?.id
        selectedCafe = forYouRecommendations.first?.cafe
    }

    private func baseForYouCandidates() -> [DiscoveryPlaceCandidate] {
        if appleCafeDiscovery.candidates.isEmpty {
            return dataManager.appData.cafes
                .filter { $0.location != nil }
                .map { DiscoveryPlaceCandidate(cafe: $0) }
        }
        return appleCafeDiscovery.candidates
    }

    private func currentForYouCandidates() -> [DiscoveryPlaceCandidate] {
        baseForYouCandidates().map { candidate in
            guard let enriched = enrichedCandidatesByID[candidate.id] else { return candidate }
            return candidate.applying(
                remoteCafeID: enriched.remoteCafeID,
                isFavorite: enriched.isFavorite,
                isWantToTry: enriched.isWantToTry
            )
        }
    }

    @MainActor
    private func refreshDiscoveryEnrichment() async {
        guard authModel.authenticatedUser != nil else {
            enrichedCandidatesByID = [:]
            serverForYouEvidenceByCandidateID = [:]
            rebuildForYouRecommendations()
            return
        }

        let candidates = baseForYouCandidates()
        let requestedIDs = candidates.map(\.id)
        guard !candidates.isEmpty else {
            enrichedCandidatesByID = [:]
            serverForYouEvidenceByCandidateID = [:]
            return
        }

        do {
            let client = try SupabaseClientProvider.shared.client()
            let snapshot = try await DiscoveryCandidateEnrichmentService(client: client)
                .enrich(candidates)
            guard !Task.isCancelled,
                  baseForYouCandidates().map(\.id) == requestedIDs else { return }
            enrichedCandidatesByID = Dictionary(
                uniqueKeysWithValues: snapshot.candidates.map { ($0.id, $0) }
            )
            serverForYouEvidenceByCandidateID = snapshot.evidenceByCandidateID
            rebuildForYouRecommendations()
        } catch {
            guard !Task.isCancelled else { return }
            // The Map remains useful while the additive RPC rolls out or if
            // enrichment is temporarily unavailable. Never replace honest
            // nearby results with invented evidence.
            enrichedCandidatesByID = [:]
            serverForYouEvidenceByCandidateID = [:]
            rebuildForYouRecommendations()
        }
    }

    private func forYouEvidence(
        for candidates: [DiscoveryPlaceCandidate]
    ) -> [String: [DiscoveryEvidence]] {
        let favoriteDrink = Dictionary(grouping: dataManager.appData.visits, by: \.drinkType)
            .max(by: { $0.value.count < $1.value.count })?
            .key
            .rawValue
            .lowercased()

        return candidates.reduce(into: [:]) { result, candidate in
            var evidence: [DiscoveryEvidence] = []
            if candidate.isWantToTry {
                evidence.append(DiscoveryEvidence(
                    kind: .wantToTry,
                    reason: "Saved in your Want to Try"
                ))
            }

            if let discovery = matchingDiscoveryCafe(for: candidate) {
                if let friend = discovery.friends.first {
                    let topDrink = discovery.topDrinks.first?.name.remoteTrimmedNonEmpty
                    let reason = topDrink.map { "\(friend.displayName) loved the \($0.lowercased())" }
                        ?? "\(friend.displayName) logged a Mugshot here"
                    evidence.append(DiscoveryEvidence(
                        kind: .friendVisit,
                        reason: reason,
                        strength: min(max(friend.averageRating / 5, 0.25), 1),
                        authorID: friend.userID,
                        authorName: friend.displayName
                    ))
                } else if discovery.friendCount > 0 {
                    evidence.append(DiscoveryEvidence(
                        kind: .friendVisit,
                        reason: "\(discovery.friendCount) \(discovery.friendCount == 1 ? "friend was" : "friends were") here",
                        strength: min(Double(discovery.friendCount) / 3, 1)
                    ))
                }

                if let favoriteDrink,
                   let drink = discovery.topDrinks.first(where: {
                       $0.name.lowercased().contains(favoriteDrink)
                           || favoriteDrink.contains($0.name.lowercased())
                   }) {
                    evidence.append(DiscoveryEvidence(
                        kind: .drinkMatch,
                        reason: "Known for \(drink.name.lowercased())",
                        strength: min(Double(drink.count) / 3, 1)
                    ))
                }
            }

            let practicalTags = localPracticalTags(for: candidate.localID)
            if !practicalTags.isEmpty {
                let label = practicalTags.prefix(2)
                    .map { $0.replacingOccurrences(of: "_", with: " ") }
                    .joined(separator: " and ")
                evidence.append(DiscoveryEvidence(
                    kind: .practicalFit,
                    reason: label.prefix(1).uppercased() + label.dropFirst(),
                    strength: 0.8,
                    tags: practicalTags
                ))
            }
            result[candidate.id] = evidence
        }
    }

    private func matchingDiscoveryCafe(for candidate: DiscoveryPlaceCandidate) -> DiscoveryCafe? {
        if let remoteID = candidate.remoteCafeID,
           let exact = discoveryCafesByID[remoteID] {
            return exact
        }
        let candidateLocation = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
        return discoveryCafesByID.values.first { cafe in
            guard cafe.name.compare(
                candidate.name,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame else { return false }
            return candidateLocation.distance(from: CLLocation(
                latitude: cafe.latitude,
                longitude: cafe.longitude
            )) <= 100
        }
    }

    private func localPracticalTags(for cafeID: UUID) -> [String] {
        let mappings: [(String, String)] = [
            ("wi-fi", "wifi"), ("wifi", "wifi"), ("outlet", "outlets"),
            ("quiet", "quiet"), ("work", "work_study"), ("study", "work_study"),
            ("table", "table_space"), ("access", "accessible"),
            ("group", "group_friendly"), ("calm", "calm")
        ]
        let criteria = dataManager.appData.visits
            .filter { $0.cafeId == cafeID && $0.context == .cafe }
            .flatMap { $0.v3Reflection?.contextCriteria ?? [] }
            .filter { $0.isRelevant && $0.score >= 4 }
        return criteria.reduce(into: [String]()) { result, criterion in
            let normalized = criterion.name.lowercased()
            for (needle, tag) in mappings where normalized.contains(needle) {
                if !result.contains(tag) { result.append(tag) }
            }
        }
    }

    private func selectRecommendation(_ recommendation: ForYouRecommendation) {
        selectedRecommendationID = recommendation.id
        selectedCafe = recommendation.cafe
        discoveryScope = .forYou
        if let coordinate = recommendation.cafe.location {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }
    }

    @MainActor
    private func refreshWalkingETA() async {
        selectedWalkingMinutes = nil
        guard let recommendation = selectedForYouRecommendation else { return }
        if MugshotLaunchEnvironment.isUITesting {
            guard let distance = recommendation.distanceMeters else { return }
            selectedWalkingMinutes = max(1, Int((distance / 80).rounded()))
            return
        }
        guard let userLocation = locationManager.getCurrentLocation() else { return }
        let destination = CLLocation(
            latitude: recommendation.candidate.latitude,
            longitude: recommendation.candidate.longitude
        )
        // Remote-city planning should never advertise a days-long walk from
        // the person's current city. In that state, the card keeps the
        // region-relative distance and omits walking time.
        guard userLocation.distance(from: destination) <= 50_000 else { return }
        let request = MKDirections.Request()
        request.source = MKMapItem(
            placemark: MKPlacemark(coordinate: userLocation.coordinate)
        )
        request.destination = recommendation.candidate.mapItem
        request.transportType = .walking
        do {
            let eta = try await MKDirections(request: request).calculateETA()
            guard recommendation.id == selectedForYouRecommendation?.id else { return }
            selectedWalkingMinutes = max(1, Int((eta.expectedTravelTime / 60).rounded()))
        } catch {
            selectedWalkingMinutes = nil
        }
    }

    private var discoveryRankingLocation: CLLocation? {
        let regionLocation = CLLocation(
            latitude: effectiveRegion.center.latitude,
            longitude: effectiveRegion.center.longitude
        )
        guard !MugshotLaunchEnvironment.isUITesting,
              let currentLocation = locationManager.getCurrentLocation(),
              currentLocation.distance(from: regionLocation) <= 50_000 else {
            return regionLocation
        }
        return currentLocation
    }

    private func openRecommendation(_ recommendation: ForYouRecommendation) {
        selectRecommendation(recommendation)
        showCafeDetail = true
        MugshotAnalytics.shared.capture(.discovery(
            action: .recommendationOpened,
            source: .forYou,
            surface: .forYou,
            rankingVersion: recommendation.rankingVersion,
            cafeID: recommendation.candidate.remoteCafeID
        ))
        recordDiscoveryInteraction(
            recommendation,
            kind: .recommendationOpened
        )
    }

    private func openDirections(for recommendation: ForYouRecommendation) {
        recommendation.candidate.mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
        MugshotAnalytics.shared.capture(.discovery(
            action: .directionsRequested,
            source: .forYou,
            surface: .forYou,
            rankingVersion: recommendation.rankingVersion,
            cafeID: recommendation.candidate.remoteCafeID
        ))
        recordDiscoveryInteraction(
            recommendation,
            kind: .directionsRequested
        )
    }

    private func toggleWantToTry(for recommendation: ForYouRecommendation) {
        let targetValue = !recommendation.candidate.isWantToTry
        let cafe: Cafe
        if targetValue {
            cafe = dataManager.saveDiscoveryCandidate(
                recommendation.candidate,
                wantToTry: true,
                note: recommendation.candidate.discoveryNote,
                source: .forYou
            )
        } else {
            dataManager.toggleCafeWantToTry(recommendation.candidate.localID)
            cafe = dataManager.getCafe(id: recommendation.candidate.localID)
                ?? recommendation.cafe
        }

        appleCafeDiscovery.refreshLocalState(knownCafes: dataManager.appData.cafes)
        rebuildForYouRecommendations()
        if targetValue {
            offerNearbyReminderEducationIfUseful(for: cafe)
        }
        MugshotAnalytics.shared.capture(.discovery(
            action: .cafeSaved,
            source: .forYou,
            surface: .forYou,
            rankingVersion: recommendation.rankingVersion,
            cafeID: cafe.remoteCafeId
        ))

        guard let userID = authModel.authenticatedUser?.id else { return }
        Task {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let summary = try await CafeStateService(client: client).setCafeState(
                    userId: userID,
                    cafe: cafe,
                    isFavorite: cafe.isFavorite,
                    wantToTry: targetValue,
                    discoveryNote: cafe.discoveryNote,
                    discoverySource: targetValue ? .forYou : nil,
                    discoveredAt: targetValue ? cafe.discoveredAt ?? .now : nil
                )
                if targetValue {
                    _ = try? await DiscoveryInteractionService(client: client).record(
                        cafeID: summary.cafe.id,
                        appleMapsPlaceID: summary.cafe.appleMapsPlaceID,
                        source: .forYou,
                        kind: .cafeSaved,
                        rankingVersion: recommendation.rankingVersion
                    )
                }
                await MainActor.run {
                    _ = dataManager.applyRemoteCafeState(summary)
                    appleCafeDiscovery.refreshLocalState(knownCafes: dataManager.appData.cafes)
                    rebuildForYouRecommendations()
                }
            } catch {
                await MainActor.run {
                    remoteStateError = MugshotUserFacingError.message(for: error, context: .social)
                }
            }
        }
    }

    private func recordDiscoveryInteraction(
        _ recommendation: ForYouRecommendation,
        kind: DiscoveryInteractionKind
    ) {
        guard authModel.authenticatedUser?.id != nil else { return }
        Task {
            guard let client = try? SupabaseClientProvider.shared.client() else { return }
            _ = try? await DiscoveryInteractionService(client: client).record(
                cafeID: recommendation.candidate.remoteCafeID,
                appleMapsPlaceID: recommendation.candidate.appleMapsPlaceID,
                source: .forYou,
                kind: kind,
                rankingVersion: recommendation.rankingVersion
            )
        }
    }

    private func offerNearbyReminderEducationIfUseful(for cafe: Cafe) {
        guard DiscoveryFeatureFlags.isEnabled(.nearbyReminders),
              cafe.location != nil,
              !NearbyCafeReminderCoordinator.shared.isEnabled,
              !UserDefaults.standard.bool(
                forKey: NearbyCafeReminderCoordinator.educationDismissedKey
              ) else { return }
        showsNearbyReminderEducation = true
    }

    private var localAccountScope: LocalAccountScope {
        .forUserID(
            authModel.authenticatedUser?.id
                ?? dataManager.appData.currentUser?.id
        )
    }

    private var personalMapPins: [RemoteMapPin] {
        guard let userID = authModel.authenticatedUser?.id else {
            return remoteMapPins
        }
        return dataManager.personalMapSnapshot(for: userID)?.pins ?? remoteMapPins
    }

    @MainActor
    private func presentPendingSavedCafeIfNeeded() {
        guard let cafe = tabCoordinator.consumePendingMapCafe() else { return }
        isPresentingPendingSavedCafe = true
        discoveryScope = .all
        isSearchActive = false
        isSearchFieldFocused = false
        searchText = ""
        selectedCafe = cafe
        if let location = cafe.location {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            )
        }
        withAnimation(DesignSystem.Motion.base) {
            showCafeDetail = true
        }
        DispatchQueue.main.async {
            isPresentingPendingSavedCafe = false
        }
    }

    private func initializeLocationIfNeeded() {
        if MugshotLaunchEnvironment.isUITesting {
            region = uiTestingRegion
            hasInitializedLocation = true
            return
        }
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
                        span: MapInitialCameraPolicy.nearbySpan
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
                region = effectiveRegion
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
                source = localEligibleCafes + appleCafeDiscovery.candidates.map(\.cafe) + discoveryMapCafes
            case .forYou:
                source = forYouRecommendations.map(\.cafe)
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
                source = personalMapPins.map(\.localCafe)
                    + appleCafeDiscovery.candidates.map(\.cafe)
                    + discoveryMapCafes
            case .forYou:
                source = forYouRecommendations.map(\.cafe)
            case .favorites:
                source = personalMapPins.filter(\.isFavorite).map(\.localCafe)
            case .wantToTry:
                source = personalMapPins.filter(\.wantToTry).map(\.localCafe)
            case .visited:
                source = personalMapPins.filter { $0.visitCount > 0 }.map(\.localCafe)
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

    private var personalJournalCafeIDs: Set<UUID> {
        let cafes: [Cafe]
        if authModel.authenticatedUser == nil {
            cafes = dataManager.appData.cafes
        } else {
            cafes = personalMapPins.map(\.localCafe)
        }
        return MapDiscoveryEligibility.personalJournalCafeIDs(in: cafes)
    }

    private var netNewDiscoveryMapCafes: [Cafe] {
        discoveryMapCafes.filter { cafe in
            let remoteID = cafe.remoteCafeId ?? cafe.id
            guard let discoveryCafe = discoveryCafesByID[remoteID] else { return false }
            return MapDiscoveryEligibility.isNetNew(
                discoveryCafe,
                excluding: personalJournalCafeIDs
            )
        }
    }

    private var personalPinScoresByCafeID: [UUID: MapPinScore] {
        guard authModel.authenticatedUser != nil else {
            return localPinScoresByCafeID
        }
        return Dictionary(
            uniqueKeysWithValues: personalMapPins.compactMap { pin in
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
        switch discoveryScope {
        case .forYou: [:]
        case .friends: friendPinScoresByCafeID
        default: personalPinScoresByCafeID
        }
    }

    private var displayedPinScoresByCafeID: [UUID: MapPinScore] {
        let displayedIDs = Set(displayedMapCafes.map(\.id))
        return pinScoresByCafeID.filter { displayedIDs.contains($0.key) }
    }

    private var friendCountsByCafeID: [UUID: Int] {
        guard discoveryScope == .friends || discoveryScope == .all else { return [:] }
        return discoveryCafesByID.mapValues(\.friendCount)
    }

    private var mapPlaceNamesByCafeID: [UUID: String] {
        var placeNames = personalMapPins.reduce(into: [UUID: String]()) { result, pin in
            if let city = pin.cafe.city?.trimmingCharacters(in: .whitespacesAndNewlines),
               !city.isEmpty {
                result[pin.id] = city
            }
        }
        for (id, discoveryCafe) in discoveryCafesByID {
            if let city = discoveryCafe.city?.trimmingCharacters(in: .whitespacesAndNewlines),
               !city.isEmpty {
                placeNames[id] = city
            }
        }
        return AdaptiveMapPlaceNameResolver.names(
            for: displayedMapCafes,
            authoritativeNames: placeNames
        )
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
            appleMapsPlaceID: mapItem.identifier?.rawValue,
            websiteURL: mapItem.url?.absoluteString,
            placeCategory: mapItem.pointOfInterestCategory?.rawValue
        )
    }

    @MainActor
    private func loadRemoteMapPins() async {
        let loadID = UUID()
        activeMapLoadID = loadID
        guard let userId = authModel.authenticatedUser?.id else {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = SocialDiscoveryService(client: client)
                let discovery = try await fetchDiscoveryCafes(
                    service: service,
                    isAuthenticated: false
                )
                guard activeMapLoadID == loadID, !Task.isCancelled else { return }
                remoteMapPins = []
                discoveryMapCafes = discovery.map(\.localCafe)
                discoveryCafesByID = Dictionary(uniqueKeysWithValues: discovery.map { ($0.id, $0) })
                friendCafeSummariesByID = [:]
                friendSipSummariesByID = [:]
                remoteStateError = nil
                remoteMapPinUserId = nil
                rebuildForYouRecommendations()
            } catch {
                guard activeMapLoadID == loadID, !Task.isCancelled else { return }
                remoteStateError = MugshotUserFacingError.message(for: error, context: .loading)
            }
            return
        }

        if remoteMapPinUserId != userId {
            remoteMapPins = dataManager.personalMapSnapshot(for: userId)?.pins ?? []
            remoteMapPinUserId = userId
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

            guard activeMapLoadID == loadID, !Task.isCancelled else { return }
            remoteMapPins = snapshot.pins
            discoveryMapCafes = discovery.map(\.localCafe)
            discoveryCafesByID = Dictionary(uniqueKeysWithValues: discovery.map { ($0.id, $0) })
            friendCafeSummariesByID = Dictionary(
                uniqueKeysWithValues: friendCafeSummaries.map { ($0.cafeID, $0) }
            )
            friendSipSummariesByID = Dictionary(
                uniqueKeysWithValues: (friendSipSummaries ?? []).map { ($0.cafeID, $0) }
            )
            dataManager.applyPersonalMapSnapshot(snapshot, for: userId)
            remoteMapPinUserId = userId
            if let selectedID = selectedCafe.map({ $0.remoteCafeId ?? $0.id }),
               let refreshedSelection = snapshot.pins
                .map(\.localCafe)
                .first(where: { ($0.remoteCafeId ?? $0.id) == selectedID }) {
                selectedCafe = refreshedSelection
            }
            remoteStateError = nil
            rebuildForYouRecommendations()
        } catch {
            guard activeMapLoadID == loadID, !Task.isCancelled else { return }
            remoteStateError = MugshotUserFacingError.message(for: error, context: .loading)
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

    private func handleMapCafeTap(_ cafe: Cafe) {
        selectedCafe = cafe
        if discoveryScope == .forYou {
            selectedRecommendationID = forYouRecommendations.first(where: { $0.cafe.id == cafe.id })?.id
            friendPreviewCafe = nil
            showCafeDetail = false
        } else if discoveryScope == .friends {
            friendPreviewCafe = cafe
            showCafeDetail = false
        } else {
            friendPreviewCafe = nil
            showCafeDetail = true
        }
        isSearchActive = false
    }
}

private struct ForYouListPresentation: Identifiable {
    let id = UUID()
}

private struct MapClusterSelection: Identifiable {
    let id = UUID()
    let cafes: [Cafe]
}

private struct MapClusterCafeListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cafes: [Cafe]
    let pinScores: [UUID: MapPinScore]
    let onSelect: (Cafe) -> Void

    private var sortedCafes: [Cafe] {
        cafes.sorted { lhs, rhs in
            let lhsScore = pinScores[lhs.id]?.value ?? -1
            let rhsScore = pinScores[rhs.id]?.value ?? -1
            if lhsScore == rhsScore {
                return lhs.consumerDisplayName.localizedCaseInsensitiveCompare(
                    rhs.consumerDisplayName
                ) == .orderedAscending
            }
            return lhsScore > rhsScore
        }
    }

    var body: some View {
        NavigationStack {
            List(sortedCafes) { cafe in
                Button {
                    dismiss()
                    onSelect(cafe)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(cafe.consumerDisplayName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            if !cafe.address.isEmpty {
                                Text(cafe.address)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 8)
                        if let score = pinScores[cafe.id] {
                            MugshotRatingBadge(score: score.value, label: score.sourceLabel)
                                .accessibilityLabel(score.accessibilityLabel)
                        } else {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundColor(.mugshotSage)
                                .accessibilityLabel("Not rated")
                        }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows cafe details")
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("\(cafes.count) \(cafes.count == 1 ? "cafe" : "cafes")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
    case forYou
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
        case .forYou:
            primaryKind = .forYou
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
    let placeNames: [UUID: String]
    let showsFriendContext: Bool
    var scope: MapDiscoveryScope = .all
    let showsUserLocation: Bool
    @Binding var trackingMode: MKUserTrackingMode
    let onCafeTap: (Cafe) -> Void
    let onClusterListRequested: ([Cafe]) -> Void
    var onUserRegionChange: (MKCoordinateRegion) -> Void = { _ in }

    private var displayedCafes: [Cafe] {
        AdaptiveMapAnnotationSnapshot(
            cafes: cafes,
            highlightedCafe: highlightedCafe
        ).cafes
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // Seed the initial camera before attaching the delegate. Otherwise
        // MapKit reports the broad fallback as an in-flight camera change and
        // can overwrite the first current-location region that SwiftUI sends.
        mapView.region = region
        mapView.delegate = context.coordinator
        mapView.accessibilityIdentifier = "map.surface"

        if MugshotLaunchEnvironment.isUITesting {
            let gestureGuide = UIView()
            gestureGuide.translatesAutoresizingMaskIntoConstraints = false
            gestureGuide.backgroundColor = .clear
            gestureGuide.isUserInteractionEnabled = false
            gestureGuide.isAccessibilityElement = true
            gestureGuide.accessibilityIdentifier = "map.gestureSurface"
            gestureGuide.accessibilityLabel = "Map gesture surface"
            mapView.addSubview(gestureGuide)
            NSLayoutConstraint.activate([
                gestureGuide.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
                gestureGuide.centerYAnchor.constraint(equalTo: mapView.centerYAnchor, constant: -20),
                gestureGuide.widthAnchor.constraint(equalToConstant: 240),
                gestureGuide.heightAnchor.constraint(equalToConstant: 280)
            ])
        }
        
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

        // Update region if needed. If MapKit is still settling an older camera
        // change, retain the newest SwiftUI request and apply it immediately
        // afterward instead of allowing the stale delegate callback to win.
        let needsRegionUpdate =
            abs(mapView.region.center.latitude - region.center.latitude) > 0.001 ||
            abs(mapView.region.center.longitude - region.center.longitude) > 0.001 ||
            abs(mapView.region.span.latitudeDelta - region.span.latitudeDelta) > 0.001 ||
            abs(mapView.region.span.longitudeDelta - region.span.longitudeDelta) > 0.001
        if needsRegionUpdate {
            if context.coordinator.isCameraChanging {
                if MapCameraReconciliationPolicy.shouldQueueExternalRegion(
                    cameraIsChanging: true,
                    cameraSourceRegion: context.coordinator.cameraSourceRegion,
                    requestedRegion: region
                ) {
                    context.coordinator.queuedExternalRegion = region
                }
            } else {
                mapView.setRegion(region, animated: true)
            }
        }

        let dataChanged = context.coordinator.lastDisplayedCafes != displayedCafes
            || context.coordinator.lastPlaceNames != placeNames
            || context.coordinator.lastHighlightedCafeID != highlightedCafe?.id
        let presentationChanged = context.coordinator.lastFriendCounts != friendCounts
            || context.coordinator.lastPinScores != pinScores
            || context.coordinator.lastShowsFriendContext != showsFriendContext
            || context.coordinator.lastScope != scope

        context.coordinator.lastDisplayedCafes = displayedCafes
        context.coordinator.lastPlaceNames = placeNames
        context.coordinator.lastHighlightedCafeID = highlightedCafe?.id
        context.coordinator.lastFriendCounts = friendCounts
        context.coordinator.lastPinScores = pinScores
        context.coordinator.lastShowsFriendContext = showsFriendContext
        context.coordinator.lastScope = scope
        context.coordinator.reconcileAnnotations(
            in: mapView,
            forceRefresh: dataChanged || presentationChanged
        )
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
        var lastDisplayedCafes: [Cafe]
        var lastPlaceNames: [UUID: String]
        var lastHighlightedCafeID: UUID?
        var displayMode: AdaptiveMapDisplayMode = .cafes
        var cafeClusteringEnabled = false
        var isCameraChanging = false
        var queuedExternalRegion: MKCoordinateRegion?
        var cameraSourceRegion: MKCoordinateRegion?
        private var cameraChangeWasUserInitiated = false
        private var cameraSettledWorkItem: DispatchWorkItem?

        init(parent: MapViewRepresentable) {
            self.parent = parent
            lastFriendCounts = parent.friendCounts
            lastPinScores = parent.pinScores
            lastShowsFriendContext = parent.showsFriendContext
            lastScope = parent.scope
            lastDisplayedCafes = parent.displayedCafes
            lastPlaceNames = parent.placeNames
            lastHighlightedCafeID = parent.highlightedCafe?.id
        }

        func reconcileAnnotations(in mapView: MKMapView, forceRefresh: Bool = false) {
            let groundFootprintMeters = AdaptiveMapCameraPolicy.groundFootprintMeters(in: mapView)
            let nextMode = AdaptiveMapCameraPolicy.displayMode(
                current: displayMode,
                groundFootprintMeters: groundFootprintMeters
            )
            let nextClusteringEnabled = AdaptiveMapCafeClusteringPolicy.isEnabled(
                current: cafeClusteringEnabled,
                groundFootprintMeters: groundFootprintMeters
            )
            let modeChanged = nextMode != displayMode
            let clusteringChanged = nextClusteringEnabled != cafeClusteringEnabled
            guard forceRefresh || modeChanged || clusteringChanged
                    || applicationAnnotations(in: mapView).isEmpty else {
                return
            }

            if forceRefresh || modeChanged || clusteringChanged {
                mapView.removeAnnotations(applicationAnnotations(in: mapView))
            }
            displayMode = nextMode
            cafeClusteringEnabled = nextClusteringEnabled

            switch displayMode {
            case .cafes:
                let existingIDs = Set(
                    mapView.annotations.compactMap { ($0 as? CafeAnnotation)?.cafe.id }
                )
                let annotations = parent.displayedCafes
                    .filter { !existingIDs.contains($0.id) }
                    .map(CafeAnnotation.init)
                mapView.addAnnotations(annotations)
            case .places:
                addPlaceAnnotations(to: mapView)
            }
        }

        private func applicationAnnotations(in mapView: MKMapView) -> [MKAnnotation] {
            mapView.annotations.filter {
                $0 is CafeAnnotation || $0 is PlaceAggregateAnnotation
            }
        }

        private func addPlaceAnnotations(to mapView: MKMapView) {
            let highlightedID = parent.highlightedCafe?.id
            let aggregateCafes = parent.displayedCafes.filter { $0.id != highlightedID }
            let aggregates = AdaptiveMapPlaceAggregateBuilder.make(
                cafes: aggregateCafes,
                placeNames: parent.placeNames,
                scores: parent.pinScores,
                friendCounts: parent.friendCounts
            )
            mapView.addAnnotations(aggregates.map(PlaceAggregateAnnotation.init))

            // A selected cafe remains individually identifiable while the
            // surrounding map uses semantic place aggregates.
            if let highlightedCafe = parent.highlightedCafe,
               highlightedCafe.location != nil {
                mapView.addAnnotation(CafeAnnotation(cafe: highlightedCafe))
            }
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

            if let cluster = annotation as? MKClusterAnnotation {
                return clusterView(for: cluster, in: mapView)
            }

            if let placeAnnotation = annotation as? PlaceAggregateAnnotation {
                return placeView(for: placeAnnotation, in: mapView)
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
            annotationView?.clusteringIdentifier = clusteringIdentifier(for: cafe)
            annotationView?.collisionMode = .circle
            annotationView?.displayPriority = .required
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

        private func clusteringIdentifier(for cafe: Cafe) -> String? {
            let highlightedID = parent.highlightedCafe.map { $0.remoteCafeId ?? $0.id }
            guard cafeClusteringEnabled,
                  (cafe.remoteCafeId ?? cafe.id) != highlightedID else {
                return nil
            }
            return "MugshotCafe"
        }

        private func clusterView(
            for cluster: MKClusterAnnotation,
            in mapView: MKMapView
        ) -> MKAnnotationView {
            let identifier = "MugshotCluster"
            let annotationView = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? MugshotAggregateAnnotationView ?? MugshotAggregateAnnotationView(
                annotation: cluster,
                reuseIdentifier: identifier
            )
            let members = aggregateContents(in: cluster)
            let placeMembers = cluster.memberAnnotations.compactMap {
                $0 as? PlaceAggregateAnnotation
            }
            let isPlaceCluster = !placeMembers.isEmpty
            let placeLabels = Array(Set(placeMembers.map { $0.aggregate.label })).sorted()
            annotationView.annotation = cluster
            annotationView.configure(
                title: "\(members.summary.cafeCount) \(members.summary.cafeCount == 1 ? "cafe" : "cafes")",
                subtitle: isPlaceCluster
                    ? "\(placeLabels.count) \(placeLabels.count == 1 ? "area" : "areas")"
                    : members.summary.displayedBestScore.map {
                        "Best \(String(format: "%.1f", $0))"
                    } ?? "Explore area",
                summary: members.summary,
                style: .cluster,
                accessibilityLabel: clusterAccessibilityLabel(
                    summary: members.summary,
                    placeLabel: isPlaceCluster
                        ? "Across " + placeLabels.joined(separator: ", ")
                        : nil,
                    includesScore: !isPlaceCluster
                ),
                onShowList: { [weak self] in
                    self?.parent.onClusterListRequested(members.cafes)
                }
            )
            annotationView.clusteringIdentifier = nil
            annotationView.collisionMode = .circle
            annotationView.displayPriority = .required
            return annotationView
        }

        private func placeView(
            for placeAnnotation: PlaceAggregateAnnotation,
            in mapView: MKMapView
        ) -> MKAnnotationView {
            let identifier = "MugshotPlace"
            let annotationView = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? MugshotAggregateAnnotationView ?? MugshotAggregateAnnotationView(
                annotation: placeAnnotation,
                reuseIdentifier: identifier
            )
            let aggregate = placeAnnotation.aggregate
            annotationView.annotation = placeAnnotation
            annotationView.configure(
                title: aggregate.label,
                subtitle: "\(aggregate.summary.cafeCount) \(aggregate.summary.cafeCount == 1 ? "cafe" : "cafes")",
                summary: aggregate.summary,
                style: .place,
                accessibilityLabel: clusterAccessibilityLabel(
                    summary: aggregate.summary,
                    placeLabel: aggregate.label,
                    includesScore: false
                ),
                onShowList: { [weak self] in
                    self?.parent.onClusterListRequested(aggregate.cafes)
                }
            )
            annotationView.clusteringIdentifier = "MugshotPlace"
            annotationView.collisionMode = .rectangle
            annotationView.displayPriority = .required
            return annotationView
        }

        private func clusterAccessibilityLabel(
            summary: AdaptiveMapClusterSummary,
            placeLabel: String?,
            includesScore: Bool
        ) -> String {
            var components: [String] = []
            if let placeLabel {
                components.append(placeLabel)
            }
            components.append(
                "\(summary.cafeCount) \(summary.cafeCount == 1 ? "cafe" : "cafes")"
            )
            if includesScore, let bestScore = summary.displayedBestScore {
                components.append("best score \(String(format: "%.1f", bestScore))")
            }
            if summary.ratedCount > 0 {
                components.append("\(summary.ratedCount) rated")
            }
            if summary.favoriteCount > 0 {
                components.append(
                    "\(summary.favoriteCount) \(summary.favoriteCount == 1 ? "favorite" : "favorites")"
                )
            }
            if summary.wantToTryCount > 0 {
                components.append("\(summary.wantToTryCount) want to try")
            }
            if summary.friendCafeCount > 0 {
                components.append(
                    "friend activity at \(summary.friendCafeCount) \(summary.friendCafeCount == 1 ? "cafe" : "cafes")"
                )
            }
            return components.joined(separator: ", ")
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
            case .forYou:
                primaryView = createForYouPin(size: primarySize)
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

        private func createForYouPin(size: CGFloat) -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            container.backgroundColor = UIColor(Color.mugshotSage)
            container.layer.cornerRadius = size / 2
            container.layer.borderWidth = 2
            container.layer.borderColor = UIColor(Color.foamWhite).cgColor
            container.layer.shadowColor = UIColor.black.cgColor
            container.layer.shadowOpacity = 0.18
            container.layer.shadowRadius = 5
            container.layer.shadowOffset = CGSize(width: 0, height: 3)

            let imageView = UIImageView(image: UIImage(systemName: "sparkles"))
            imageView.tintColor = UIColor(Color.foamWhite)
            imageView.contentMode = .scaleAspectFit
            imageView.frame = CGRect(x: 10, y: 10, width: size - 20, height: size - 20)
            container.addSubview(imageView)
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

        private func aggregateContents(
            in annotation: MKAnnotation
        ) -> (cafes: [Cafe], summary: AdaptiveMapClusterSummary) {
            let annotations: [MKAnnotation]
            if let cluster = annotation as? MKClusterAnnotation {
                annotations = cluster.memberAnnotations
            } else {
                annotations = [annotation]
            }

            var cafes: [Cafe] = []
            var summaries: [AdaptiveMapClusterSummary] = []
            for member in annotations {
                if let cafeAnnotation = member as? CafeAnnotation {
                    let cafe = cafeAnnotation.cafe
                    cafes.append(cafe)
                    summaries.append(
                        .make(
                            cafes: [cafe],
                            scores: parent.pinScores,
                            friendCounts: parent.friendCounts
                        )
                    )
                } else if let placeAnnotation = member as? PlaceAggregateAnnotation {
                    cafes.append(contentsOf: placeAnnotation.aggregate.cafes)
                    summaries.append(placeAnnotation.aggregate.summary)
                }
            }

            var seenIDs: Set<UUID> = []
            let uniqueCafes = cafes.filter { seenIDs.insert($0.id).inserted }
            return (
                uniqueCafes,
                .merging(summaries)
            )
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation else { return }
            defer { mapView.deselectAnnotation(annotation, animated: false) }

            if let cafeAnnotation = annotation as? CafeAnnotation {
                parent.onCafeTap(cafeAnnotation.cafe)
                return
            }

            if annotation is MKClusterAnnotation || annotation is PlaceAggregateAnnotation {
                let contents = aggregateContents(in: annotation)
                zoomIntoAggregate(
                    cafes: contents.cafes,
                    in: mapView
                )
            }
        }

        private func zoomIntoAggregate(
            cafes: [Cafe],
            in mapView: MKMapView
        ) {
            guard !cafes.isEmpty else { return }
            let validCoordinates = cafes.compactMap(\.location)
            guard let firstCoordinate = validCoordinates.first else { return }

            let latitudeRange = validCoordinates.map(\.latitude)
            let longitudeRange = validCoordinates.map(\.longitude)
            let latitudeDelta = (latitudeRange.max() ?? firstCoordinate.latitude)
                - (latitudeRange.min() ?? firstCoordinate.latitude)
            let longitudeDelta = (longitudeRange.max() ?? firstCoordinate.longitude)
                - (longitudeRange.min() ?? firstCoordinate.longitude)
            let tapAction = AdaptiveMapClusterTapPolicy.action(
                cafeCount: cafes.count,
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta,
                cameraSpan: mapView.region.span
            )

            if tapAction == .showList {
                parent.onClusterListRequested(cafes)
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Showing \(cafes.count) overlapping cafes"
                )
                return
            }

            let center = CLLocationCoordinate2D(
                latitude: ((latitudeRange.min() ?? firstCoordinate.latitude)
                    + (latitudeRange.max() ?? firstCoordinate.latitude)) / 2,
                longitude: ((longitudeRange.min() ?? firstCoordinate.longitude)
                    + (longitudeRange.max() ?? firstCoordinate.longitude)) / 2
            )
            let targetRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(
                    latitudeDelta: min(max(latitudeDelta * 2.4, 0.012), 45),
                    longitudeDelta: min(max(longitudeDelta * 2.4, 0.012), 45)
                )
            )
            mapView.setRegion(targetRegion, animated: true)
            UIAccessibility.post(
                notification: .announcement,
                argument: "Zooming in to explore \(cafes.count) \(cafes.count == 1 ? "cafe" : "cafes")"
            )
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isCameraChanging = true
            cameraSourceRegion = parent.region
            var isUserInitiated = false
            for view in mapView.subviews {
                for gesture in view.gestureRecognizers ?? []
                where gesture.state == .began || gesture.state == .changed {
                    isUserInitiated = true
                    break
                }
                if isUserInitiated { break }
            }
            cameraChangeWasUserInitiated = isUserInitiated
            cameraSettledWorkItem?.cancel()
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let updatedRegion = mapView.region
            let wasUserInitiated = cameraChangeWasUserInitiated
            cameraChangeWasUserInitiated = false
            cameraSettledWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.isCameraChanging = false

                if let queuedRegion = self.queuedExternalRegion {
                    self.queuedExternalRegion = nil
                    self.cameraSourceRegion = nil
                    mapView.setRegion(queuedRegion, animated: true)
                    return
                }

                self.cameraSourceRegion = nil
                self.reconcileAnnotations(in: mapView)
                guard abs(self.parent.region.center.latitude - updatedRegion.center.latitude) > 0.000_001
                        || abs(self.parent.region.center.longitude - updatedRegion.center.longitude) > 0.000_001
                        || abs(self.parent.region.span.latitudeDelta - updatedRegion.span.latitudeDelta) > 0.000_001
                        || abs(self.parent.region.span.longitudeDelta - updatedRegion.span.longitudeDelta) > 0.000_001 else {
                    return
                }

                // MapKit can invoke this delegate while SwiftUI is updating the
                // representable. The debounce also avoids rebuilding semantic
                // aggregates during every frame of a rapid pan or pinch.
                self.parent.region = updatedRegion
                if wasUserInitiated {
                    self.parent.onUserRegionChange(updatedRegion)
                }
            }
            cameraSettledWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
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

// MARK: - Adaptive Map Annotations

final class CafeAnnotation: NSObject, MKAnnotation {
    let cafe: Cafe
    var coordinate: CLLocationCoordinate2D {
        cafe.location ?? CLLocationCoordinate2D()
    }
    
    init(cafe: Cafe) {
        self.cafe = cafe
        super.init()
    }
}

final class PlaceAggregateAnnotation: NSObject, MKAnnotation {
    let aggregate: AdaptiveMapPlaceAggregate
    var coordinate: CLLocationCoordinate2D { aggregate.coordinate }

    init(aggregate: AdaptiveMapPlaceAggregate) {
        self.aggregate = aggregate
        super.init()
    }
}

private enum MugshotAggregateStyle {
    case cluster
    case place
}

private final class MugshotAggregateAnnotationView: MKAnnotationView {
    private let backgroundView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let activityStack = UIStackView()
    private var onShowList: (() -> Void)?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        isEnabled = true
        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .button

        backgroundView.layer.borderWidth = 1.5
        backgroundView.layer.shadowColor = UIColor.black.cgColor
        backgroundView.layer.shadowOpacity = 0.13
        backgroundView.layer.shadowRadius = 5
        backgroundView.layer.shadowOffset = CGSize(width: 0, height: 3)
        addSubview(backgroundView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = UIColor(Color.espressoBrown)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        backgroundView.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        subtitleLabel.textColor = UIColor(Color.secondaryText)
        subtitleLabel.textAlignment = .center
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.75
        backgroundView.addSubview(subtitleLabel)

        activityStack.axis = .horizontal
        activityStack.alignment = .center
        activityStack.spacing = 3
        backgroundView.addSubview(activityStack)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onShowList = nil
        accessibilityCustomActions = nil
        activityStack.arrangedSubviews.forEach {
            activityStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    func configure(
        title: String,
        subtitle: String,
        summary: AdaptiveMapClusterSummary,
        style: MugshotAggregateStyle,
        accessibilityLabel: String,
        onShowList: @escaping () -> Void
    ) {
        self.onShowList = onShowList
        self.accessibilityLabel = accessibilityLabel
        accessibilityHint = "Double tap to zoom in. Use the actions menu to show these cafes in a list."
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: "Show cafes in list",
                actionHandler: { [weak self] _ in
                    self?.onShowList?()
                    return self?.onShowList != nil
                }
            )
        ]

        titleLabel.text = title
        subtitleLabel.text = subtitle
        activityStack.arrangedSubviews.forEach {
            activityStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        addActivityIcon(systemName: "heart.fill", count: summary.favoriteCount)
        addActivityIcon(systemName: "bookmark.fill", count: summary.wantToTryCount)
        addActivityIcon(systemName: "person.2.fill", count: summary.friendCafeCount)

        let size: CGSize
        switch style {
        case .cluster:
            size = CGSize(width: 84, height: 52)
            backgroundView.backgroundColor = UIColor(Color.foamWhite)
            backgroundView.layer.cornerRadius = 26
        case .place:
            size = CGSize(width: 112, height: 52)
            backgroundView.backgroundColor = UIColor(Color.creamWhite)
            backgroundView.layer.cornerRadius = 15
        }
        backgroundView.layer.borderColor = UIColor(Color.mugshotSage.opacity(0.68)).cgColor
        frame = CGRect(origin: .zero, size: size)
        backgroundView.frame = bounds
        centerOffset = CGPoint(x: 0, y: -size.height / 2)

        let hasActivity = !activityStack.arrangedSubviews.isEmpty
        titleLabel.frame = CGRect(x: 8, y: 7, width: size.width - 16, height: 18)
        if hasActivity {
            subtitleLabel.frame = CGRect(x: 8, y: 27, width: size.width * 0.56, height: 14)
            activityStack.frame = CGRect(
                x: size.width * 0.58,
                y: 28,
                width: size.width * 0.34,
                height: 12
            )
        } else {
            subtitleLabel.frame = CGRect(x: 8, y: 28, width: size.width - 16, height: 14)
            activityStack.frame = .zero
        }
        accessibilityIdentifier = style == .cluster ? "map.cluster" : "map.place"
    }

    private func addActivityIcon(systemName: String, count: Int) {
        guard count > 0 else { return }
        let icon = UIImageView(image: UIImage(systemName: systemName))
        icon.tintColor = UIColor(Color.mugshotSage)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 11),
            icon.heightAnchor.constraint(equalToConstant: 11)
        ])
        activityStack.addArrangedSubview(icon)
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
                    MugsyModelView(
                        configuration: MugsySceneResolver.cafePhoto(
                            stableID: displayCafe.id.uuidString,
                            origin: .map,
                            isFavorite: displayCafe.isFavorite,
                            wantToTry: displayCafe.wantToTry,
                            hasVisited: false
                        ).configuration
                    )
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

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
            let urlString = "https://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(encodedName)"
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
            Group {
                if let photoURL = visit.visit.posterPhotoURL?.remoteTrimmedNonEmpty {
                    RemotePhotoImageView(
                        urlString: photoURL,
                        placeholderSystemName: "cup.and.saucer.fill",
                        contentMode: .fill
                    )
                } else {
                    MugsyPhotoPlaceholderView(
                        scene: MugsySceneResolver.scene(
                            for: visit.usesMugsyPhotoFallback ? .missedSipPhoto : .communitySip,
                            stableID: visit.id.uuidString
                        ),
                        style: .thumbnail,
                        photoDescription: "No sip photo"
                    )
                }
            }
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
    var showsNearbyCafeSuggestions = false
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

                if onSelectCafe != nil {
                    closestCafeSection
                } else {
                    exploreNearbySection
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

    private var closestCafeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SearchSectionTitle(
                title: "Closest cafes",
                subtitle: showsNearbyCafeSuggestions
                    ? "Five nearby choices, ready to tap"
                    : "Use your location to see the five closest"
            )

            if showsNearbyCafeSuggestions {
                if searchService.isLoadingNearbyCafes && searchService.nearbyCafeResults.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Finding cafes near you…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.vertical, 12)
                    .accessibilityLabel("Finding nearby cafes")
                } else if let error = searchService.nearbyCafeError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.secondaryText)
                        Button("Try nearby again") {
                            searchService.loadNearbyCafes(region: region, force: true)
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.mugshotSage)
                    }
                    .padding(.vertical, 8)
                } else if searchService.nearbyCafeResults.isEmpty {
                    Text("No cafes appeared nearby. Search by name or neighborhood.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(searchService.nearbyCafeResults, id: \.self) { mapItem in
                            SearchResultRow(mapItem: mapItem, region: region) {
                                handleSearchResult(mapItem)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                Label("Tap Near me above to show nearby cafes.", systemImage: "location")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .padding(.vertical, 10)
            }
        }
    }

    private var exploreNearbySection: some View {
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
