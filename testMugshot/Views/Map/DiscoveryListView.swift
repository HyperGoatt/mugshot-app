import CoreLocation
import Foundation
import SwiftUI

struct DiscoveryListView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var locationManager: LocationManager
    @Binding var discoveryMode: MapDiscoveryMode
    @Binding var discoveryScope: MapDiscoveryScope
    @Binding var radiusMiles: Double
    @Binding var searchText: String
    @Binding var selectedMapCafe: Cafe?
    @Binding var showMapCafeDetail: Bool
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var cafesBySection: [DiscoverySection: [DiscoveryCafe]] = [:]
    @State private var libraryCafes: [Cafe] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var presentedCafe: Cafe?
    @State private var refreshPullProgress: CGFloat = 0
    @State private var isRefreshing = false
    @State private var didArmRefresh = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    MugshotPullProgressReader(coordinateSpace: "discovery.refresh", restingOffset: 18)
                    HStack(spacing: 10) {
                        Text("Discover")
                            .mugshotDisplay(size: 30)
                            .foregroundColor(.espressoBrown)
                        Spacer()
                        MapDiscoveryModeControl(selection: $discoveryMode)
                            .frame(width: 166)
                    }

                    MapDiscoveryFilterBar(
                        selection: $discoveryScope,
                        isAuthenticated: authModel.authenticatedUser != nil
                    )
                    .padding(.horizontal, -16)

                    discoveryContext
                    searchField

                    if isLoading && visibleCafeCount == 0 {
                        MugshotLoadingState(layout: .journal, count: 4)
                    } else if let errorMessage, visibleCafeCount == 0 {
                        MugshotRecoveryCard(
                            title: "Discovery is taking a coffee break",
                            message: errorMessage,
                            actionTitle: "Retry"
                        ) { Task { await load() } }
                    } else if visibleCafeCount == 0 {
                        MugsyEmptyStateView(
                            placement: .discoveryEmpty,
                            title: searchText.isEmpty ? "No cafes to show yet" : "No cafes match that search",
                            message: emptyStateMessage
                        )
                    } else {
                        if !filteredLibraryCafes.isEmpty {
                            LibraryCafeSection(scope: discoveryScope, cafes: filteredLibraryCafes) { cafe in
                                select(cafe)
                            }
                        }

                        ForEach(visibleSections) { section in
                            if let cafes = filteredCafesBySection[section], !cafes.isEmpty {
                                DiscoverySectionView(section: section, cafes: cafes) { cafe in
                                    select(cafe.localCafe)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 116)
            }
            .coordinateSpace(name: "discovery.refresh")
            .background(Color.creamWhite)
            .overlay(alignment: .top) {
                MugshotPullRefreshIndicator(
                    progress: refreshPullProgress,
                    isRefreshing: isRefreshing
                )
                .offset(y: 8)
                .allowsHitTesting(false)
            }
            .onPreferenceChange(MugshotPullDistancePreferenceKey.self) { distance in
                refreshPullProgress = MugshotMotion.normalized(distance / 82)
                if refreshPullProgress >= 1, !didArmRefresh {
                    didArmRefresh = true
                    MugshotHaptic.refreshArmed.play()
                } else if refreshPullProgress < 0.35 {
                    didArmRefresh = false
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                isRefreshing = true
                await load()
                isRefreshing = false
            }
            .sheet(item: $presentedCafe) { cafe in
                CafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: onLogVisitRequested,
                    onAuthenticationRequired: onAuthenticationRequired
                )
            }
            .task(id: "\(radiusMiles)-\(locationManager.location?.timestamp.timeIntervalSince1970 ?? 0)-\(discoveryScope.rawValue)-\(authModel.authenticatedUser?.id.uuidString ?? "signed-out")") {
                await load()
            }
        }
    }

    private var discoveryContext: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text(discoveryScope.explanation)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text("\(Int(radiusMiles.rounded())) mi")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mugshotSage)
                    .monospacedDigit()
            }

            Slider(value: $radiusMiles, in: MapDiscoveryRadius.miles, step: 1)
                .tint(.mugshotSage)
                .accessibilityLabel("Discovery radius")
                .accessibilityValue("\(Int(radiusMiles.rounded())) miles")

            HStack {
                Text("0 mi")
                Spacer()
                Text("50 mi")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.tertiaryText)
        }
        .padding(14)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondaryText)
            TextField("Search these cafes", text: $searchText)
                .foregroundColor(.inputText)
                .tint(.mugshotSage)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.tertiaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear cafe search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }

    private var visibleSections: [DiscoverySection] {
        discoveryScope.sections(isAuthenticated: authModel.authenticatedUser != nil)
    }

    private var filteredCafesBySection: [DiscoverySection: [DiscoveryCafe]] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return cafesBySection }

        return cafesBySection.mapValues { cafes in
            cafes.filter { cafe in
                [cafe.name, cafe.address, cafe.city, cafe.rankingReason]
                    .compactMap { $0 }
                    .contains { $0.lowercased().contains(query) }
                    || cafe.topDrinks.contains { $0.name.lowercased().contains(query) }
            }
        }
    }

    private var filteredLibraryCafes: [Cafe] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return libraryCafes }
        return libraryCafes.filter {
            $0.name.lowercased().contains(query) || $0.address.lowercased().contains(query)
        }
    }

    private var visibleCafeCount: Int {
        visibleSections.reduce(filteredLibraryCafes.count) {
            $0 + (filteredCafesBySection[$1]?.count ?? 0)
        }
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try another cafe, neighborhood, or drink name. Your discovery source and radius are unchanged."
        }
        if discoveryScope == .favorites {
            return "Mark a cafe as a favorite and it will appear here."
        }
        if discoveryScope == .wantToTry {
            return "Save a cafe to try later and it will appear here."
        }
        if discoveryScope == .visited {
            return "Log a cafe sip and it will appear here."
        }
        if discoveryScope == .friends {
            return "Friends' shared cafe sips will appear here."
        }
        return "Try the wider radius or pull to refresh. You can also switch discovery sources."
    }

    private func select(_ cafe: Cafe) {
        selectedMapCafe = cafe
        showMapCafeDetail = true
        presentedCafe = cafe
    }

    private var effectiveRadiusKM: Double {
        MapDiscoveryRadius.kilometers(forMiles: radiusMiles)
    }

    private var isLibraryScope: Bool {
        discoveryScope == .favorites || discoveryScope == .wantToTry || discoveryScope == .visited
    }

    private func cafes(for scope: MapDiscoveryScope, from cafes: [Cafe]) -> [Cafe] {
        switch scope {
        case .favorites: return cafes.filter(\.isFavorite)
        case .wantToTry: return cafes.filter(\.wantToTry)
        case .visited: return cafes.filter { $0.visitCount > 0 }
        case .all, .friends, .discovery: return []
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if isLibraryScope {
                cafesBySection = [:]
                if let userID = authModel.authenticatedUser?.id {
                    let client = try SupabaseClientProvider.shared.client()
                    let snapshot = try await MapPinService(
                        visitService: VisitService(client: client),
                        cafeStateService: CafeStateService(client: client),
                        cafeSessionService: CafeSessionService(client: client)
                    ).fetchSnapshot(userId: userID)
                    libraryCafes = cafes(for: discoveryScope, from: snapshot.pins.map(\.localCafe))
                    dataManager.applyPersonalMapSnapshot(snapshot, for: userID)
                } else {
                    libraryCafes = cafes(for: discoveryScope, from: dataManager.appData.cafes)
                }
                errorMessage = nil
                return
            }

#if DEBUG
            // Gives UI automation a deterministic offline path without
            // changing host networking or affecting release builds.
            if ProcessInfo.processInfo.environment["MUGSHOT_DISCOVERY_OFFLINE"] == "1" {
                throw URLError(.notConnectedToInternet)
            }
#endif
            libraryCafes = []
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            var loaded: [DiscoverySection: [DiscoveryCafe]] = [:]
            var seenCafeIDs = Set<UUID>()
            for section in visibleSections {
                let cafes: [DiscoveryCafe]
                if authModel.authenticatedUser == nil {
                    cafes = try await service.publicDiscovery(
                        section: section,
                        location: locationManager.location,
                        radiusKM: effectiveRadiusKM
                    )
                } else if section == .lovedByFriends {
                    cafes = try await service.friendCafeDiscovery(
                        location: locationManager.location,
                        radiusKM: effectiveRadiusKM
                    )
                } else {
                    cafes = try await service.discovery(
                        section: section,
                        location: locationManager.location,
                        radiusKM: effectiveRadiusKM
                    )
                }
                loaded[section] = cafes.filter { seenCafeIDs.insert($0.cafeID).inserted }
            }
            cafesBySection = loaded
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }
}

private struct LibraryCafeSection: View {
    let scope: MapDiscoveryScope
    let cafes: [Cafe]
    let onSelect: (Cafe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(title: scope.rawValue)
            ForEach(cafes) { cafe in
                Button { onSelect(cafe) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: scope.icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundColor(.mugshotSage)
                            .frame(width: 58, height: 58)
                            .background(Color.mugshotMint.opacity(0.32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cafe.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            if !cafe.address.isEmpty {
                                Text(cafe.address)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondaryText)
                                    .lineLimit(1)
                            }
                            Text(detailText(for: cafe))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.mugshotSage)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.tertiaryText)
                    }
                    .padding(12)
                    .cardStyle()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func detailText(for cafe: Cafe) -> String {
        switch scope {
        case .favorites: return "A favorite"
        case .wantToTry: return "Saved to try later"
        case .visited:
            return "\(cafe.visitCount) \(cafe.visitCount == 1 ? "sip" : "sips") logged"
        case .all, .friends, .discovery: return ""
        }
    }
}

private struct DiscoverySectionView: View {
    let section: DiscoverySection
    let cafes: [DiscoveryCafe]
    let onSelect: (DiscoveryCafe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(title: section.title)
            ForEach(cafes) { cafe in
                Button { onSelect(cafe) } label: {
                    DiscoveryCafeRow(cafe: cafe)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: cafe))
                .accessibilityHint("Opens cafe details")
            }
        }
    }

    private func accessibilityLabel(for cafe: DiscoveryCafe) -> String {
        var parts = [cafe.name]
        if let rating = cafe.averageRating {
            parts.append(String(format: "Rated %.1f out of 5", rating))
        }
        parts.append(cafe.rankingReason)
        if cafe.friendCount > 0 {
            parts.append("\(cafe.friendCount) \(cafe.friendCount == 1 ? "friend" : "friends")")
        }
        parts.append("\(cafe.visibleVisitCount) \(cafe.visibleVisitCount == 1 ? "sip" : "sips")")
        return parts.joined(separator: ", ")
    }
}

private struct DiscoveryCafeRow: View {
    let cafe: DiscoveryCafe

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let cover = cafe.recentCover {
                    RemotePhotoImageView(urlString: cover, placeholderSystemName: "cup.and.saucer.fill", contentMode: .fill)
                } else {
                    MugsyPhotoPlaceholderView(
                        scene: MugsySceneResolver.cafePhoto(
                            stableID: cafe.id.uuidString,
                            origin: cafe.friendCount > 0 ? .friends : .discovery,
                            isFavorite: cafe.isSaved && cafe.isVisited,
                            wantToTry: cafe.isSaved && !cafe.isVisited,
                            hasVisited: cafe.isVisited
                        ),
                        style: .identity,
                        photoDescription: "No cafe photo yet"
                    )
                }
            }
            .frame(width: 82, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(cafe.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(1)
                    Spacer()
                    if let rating = cafe.averageRating {
                        MugshotRatingBadge(score: rating, label: "Cafe")
                    }
                }
                Text(cafe.rankingReason)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let distance = cafe.distanceKM {
                        Label(
                            MugshotDistanceFormatter.distance(
                                kilometers: distance,
                                preference: DistanceUnitPreference.stored(distanceUnitPreferenceRaw)
                            ),
                            systemImage: "location.fill"
                        )
                    }
                    if cafe.friendCount > 0 {
                        Label(
                            "\(cafe.friendCount) \(cafe.friendCount == 1 ? "friend" : "friends")",
                            systemImage: "person.2.fill"
                        )
                    }
                    Label(
                        "\(cafe.visibleVisitCount) \(cafe.visibleVisitCount == 1 ? "sip" : "sips")",
                        systemImage: "cup.and.saucer"
                    )
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
                if !cafe.topDrinks.isEmpty {
                    Text(cafe.topDrinks.map(\.name).joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.tertiaryText)
        }
        .padding(12)
        .cardStyle()
    }

    @AppStorage(DistanceUnitPreference.storageKey) private var distanceUnitPreferenceRaw = DistanceUnitPreference.automatic.rawValue
}
