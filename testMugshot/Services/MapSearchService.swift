//
//  MapSearchService.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Combine
import CoreLocation
import Foundation
import MapKit

struct MapSearchRecent: Codable, Identifiable, Equatable {
    let title: String
    let subtitle: String
    let query: String

    var id: String { "\(title)|\(subtitle)" }
}

/// A cancellable MapKit search pipeline shared by Mugshot's map surfaces.
///
/// The completer provides immediate type-ahead while local search resolves
/// concrete places. Results preserve Apple Maps relevance and only use
/// proximity as one ranking signal, rather than replacing relevance with a
/// distance-only sort.
@MainActor
final class MapSearchService: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published private(set) var searchResults: [MKMapItem] = []
    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    @Published private(set) var recents: [MapSearchRecent] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isUpdatingSuggestions = false
    @Published private(set) var searchError: String?
    @Published private(set) var completedQuery = ""
    @Published private(set) var correctedQuery: String?
    @Published private(set) var searchedExpandedArea = false
    @Published private(set) var nearbyCafeResults: [MKMapItem] = []
    @Published private(set) var isLoadingNearbyCafes = false
    @Published private(set) var nearbyCafeError: String?

    private let completer = MKLocalSearchCompleter()
    private let defaults: UserDefaults
    private var scope: LocalAccountScope
    private var currentSearch: MKLocalSearch?
    private var currentNearbySearch: MKLocalSearch?
    private var pendingSearchTask: Task<Void, Never>?
    private var activeSearchID = UUID()
    private var activeNearbySearchID = UUID()
    private var lastRegion: MKCoordinateRegion?
    private var lastNearbyCenter: CLLocation?
    private var lastRawQuery = ""

    init(defaults: UserDefaults = .standard, scope: LocalAccountScope = .guest) {
        self.defaults = defaults
        self.scope = scope
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
        loadRecents()
    }

    func activate(scope: LocalAccountScope) {
        guard self.scope != scope else { return }
        cancelSearch()
        self.scope = scope
        recents = []
        loadRecents()
    }

    func search(query: String, region: MKCoordinateRegion, immediately: Bool = false) {
        let rawQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawQuery.isEmpty else {
            cancelSearch()
            return
        }

        let normalizedQuery = Self.correctedSearchQuery(rawQuery)
        let queryChanged = rawQuery != lastRawQuery
        lastRawQuery = rawQuery
        lastRegion = region
        completer.region = region
        completer.queryFragment = rawQuery

        activeSearchID = UUID()
        let searchID = activeSearchID
        currentSearch?.cancel()
        pendingSearchTask?.cancel()
        searchError = nil
        searchedExpandedArea = false

        guard immediately else {
            // Partial place names are served best by MapKit completions. Keep
            // suggestions primary while typing and reserve broad place search
            // for Submit or a selected completion.
            if queryChanged { completions = [] }
            searchResults = []
            completedQuery = ""
            correctedQuery = nil
            isSearching = false
            isUpdatingSuggestions = true
            return
        }

        correctedQuery = normalizedQuery.compare(rawQuery, options: .caseInsensitive) == .orderedSame
            ? nil
            : normalizedQuery
        isUpdatingSuggestions = false

        isSearching = true
        pendingSearchTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            self?.beginSearch(
                query: normalizedQuery,
                region: region,
                searchID: searchID,
                requiresVisibleRegion: false
            )
        }
    }

    func search(completion: MKLocalSearchCompletion, region: MKCoordinateRegion) {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = region
        run(
            request: request,
            query: completion.title,
            region: region,
            searchID: beginImmediateSearch(rawQuery: completion.title, region: region),
            allowsExpandedRetry: true
        )
    }

    /// Resolves a type-ahead suggestion to its best concrete place in one tap.
    /// Callers can immediately attach or open the returned cafe instead of
    /// forcing the person through a second "Places" selection.
    func resolve(
        completion: MKLocalSearchCompletion,
        region: MKCoordinateRegion
    ) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = region
        return await resolve(
            request: request,
            query: completion.title,
            region: region
        )
    }

    /// Resolves a previously selected place directly instead of replaying its
    /// query and asking the person to choose the same suggestion again.
    func resolve(
        recent: MapSearchRecent,
        region: MKCoordinateRegion
    ) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = recent.query
        request.region = region
        request.resultTypes = [.address, .pointOfInterest]
        return await resolve(
            request: request,
            query: recent.query,
            region: region
        )
    }

    private func resolve(
        request: MKLocalSearch.Request,
        query: String,
        region: MKCoordinateRegion
    ) async -> MKMapItem? {
        let searchID = beginImmediateSearch(rawQuery: query, region: region)
        let search = MKLocalSearch(request: request)
        currentSearch = search

        do {
            let response = try await search.start()
            guard searchID == activeSearchID else { return nil }
            let rankedItems = Array(
                Self.ranked(
                    Self.credibleResults(response.mapItems, query: query, region: region),
                    query: query,
                    region: region
                ).prefix(15)
            )
            finish(items: rankedItems, query: query, region: region)
            if let first = rankedItems.first { recordRecent(first) }
            return rankedItems.first
        } catch is CancellationError {
            return nil
        } catch {
            guard searchID == activeSearchID else { return nil }
            finishWithError()
            return nil
        }
    }

    func retry() {
        guard let lastRegion, !lastRawQuery.isEmpty else { return }
        search(query: lastRawQuery, region: lastRegion, immediately: true)
    }

    /// Loads the five closest cafes for the composer before a person types.
    /// This search stays separate from type-ahead so clearing a query restores
    /// the nearby choices immediately instead of starting another request.
    func loadNearbyCafes(region: MKCoordinateRegion, force: Bool = false) {
        let center = CLLocation(
            latitude: region.center.latitude,
            longitude: region.center.longitude
        )
        if !force,
           let lastNearbyCenter,
           center.distance(from: lastNearbyCenter) < 50,
           (isLoadingNearbyCafes || !nearbyCafeResults.isEmpty) {
            return
        }

        lastNearbyCenter = center
        activeNearbySearchID = UUID()
        let searchID = activeNearbySearchID
        currentNearbySearch?.cancel()
        nearbyCafeError = nil
        isLoadingNearbyCafes = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "coffee"
        request.region = region
        request.regionPriority = .required
        request.resultTypes = [.pointOfInterest]
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])

        let search = MKLocalSearch(request: request)
        currentNearbySearch = search
        search.start { [weak self] response, error in
            Task { @MainActor [weak self] in
                guard let self, searchID == self.activeNearbySearchID else { return }
                self.currentNearbySearch = nil
                self.isLoadingNearbyCafes = false

                if let error {
                    let nsError = error as NSError
                    guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else {
                        return
                    }
                    self.nearbyCafeResults = []
                    self.nearbyCafeError = "Nearby cafes could not load. Search by name or try again."
                    return
                }

                self.nearbyCafeResults = Self.nearest(
                    response?.mapItems ?? [],
                    to: region.center,
                    limit: 5
                )
            }
        }
    }

    func cancelNearbyCafeSearch() {
        activeNearbySearchID = UUID()
        currentNearbySearch?.cancel()
        currentNearbySearch = nil
        isLoadingNearbyCafes = false
    }

    func recordRecent(_ item: MKMapItem) {
        let title = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return }
        let recent = MapSearchRecent(
            title: title,
            subtitle: Self.subtitle(for: item),
            query: [title, Self.subtitle(for: item)].filter { !$0.isEmpty }.joined(separator: ", ")
        )
        recents.removeAll { $0.id == recent.id }
        recents.insert(recent, at: 0)
        recents = Array(recents.prefix(6))
        persistRecents()
    }

    func removeAllRecents() {
        recents = []
        persistRecents()
    }

    func cancelSearch() {
        activeSearchID = UUID()
        pendingSearchTask?.cancel()
        pendingSearchTask = nil
        currentSearch?.cancel()
        currentSearch = nil
        completer.queryFragment = ""
        completions = []
        searchResults = []
        isSearching = false
        isUpdatingSuggestions = false
        searchError = nil
        completedQuery = ""
        correctedQuery = nil
        searchedExpandedArea = false
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = Array(completer.results.prefix(6))
        isUpdatingSuggestions = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Type-ahead is supplemental. The concrete local search can still
        // complete, so a completer failure should not replace real results.
        completions = []
        isUpdatingSuggestions = false
    }

    private func beginImmediateSearch(rawQuery: String, region: MKCoordinateRegion) -> UUID {
        activeSearchID = UUID()
        currentSearch?.cancel()
        pendingSearchTask?.cancel()
        lastRawQuery = rawQuery
        lastRegion = region
        isSearching = true
        isUpdatingSuggestions = false
        searchError = nil
        searchedExpandedArea = false
        return activeSearchID
    }

    private func beginSearch(
        query: String,
        region: MKCoordinateRegion,
        searchID: UUID,
        requiresVisibleRegion: Bool
    ) {
        guard searchID == activeSearchID else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.regionPriority = requiresVisibleRegion ? .required : .default
        request.resultTypes = [.address, .pointOfInterest]
        run(
            request: request,
            query: query,
            region: region,
            searchID: searchID,
            allowsExpandedRetry: !requiresVisibleRegion
        )
    }

    private func run(
        request: MKLocalSearch.Request,
        query: String,
        region: MKCoordinateRegion,
        searchID: UUID,
        allowsExpandedRetry: Bool
    ) {
        guard searchID == activeSearchID else { return }
        let search = MKLocalSearch(request: request)
        currentSearch = search
        search.start { [weak self] response, error in
            Task { @MainActor [weak self] in
                guard let self, searchID == self.activeSearchID else { return }

                if let error {
                    let nsError = error as NSError
                    guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else {
                        return
                    }

                    if allowsExpandedRetry,
                       (error as? MKError)?.code == .placemarkNotFound {
                        self.retryExpanded(query: query, region: region, searchID: searchID)
                        return
                    }

                    self.finishWithError()
                    return
                }

                let items = response?.mapItems ?? []
                if items.isEmpty, allowsExpandedRetry {
                    self.retryExpanded(query: query, region: region, searchID: searchID)
                    return
                }

                self.finish(items: items, query: query, region: region)
            }
        }
    }

    private func retryExpanded(query: String, region: MKCoordinateRegion, searchID: UUID) {
        searchedExpandedArea = true
        let expanded = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: max(region.span.latitudeDelta * 8, 0.5),
                longitudeDelta: max(region.span.longitudeDelta * 8, 0.5)
            )
        )
        beginSearch(
            query: query,
            region: expanded,
            searchID: searchID,
            requiresVisibleRegion: true
        )
    }

    private func finish(items: [MKMapItem], query: String, region: MKCoordinateRegion) {
        currentSearch = nil
        isSearching = false
        searchError = nil
        completedQuery = query
        searchResults = Array(
            Self.ranked(
                Self.credibleResults(items, query: query, region: region),
                query: query,
                region: region
            ).prefix(15)
        )
    }

    private func finishWithError() {
        currentSearch = nil
        isSearching = false
        searchResults = []
        searchError = "Search is taking a coffee break. Check your connection and try again."
    }

    private func loadRecents() {
        guard let data = defaults.data(forKey: Self.recentsKey(for: scope)),
              let decoded = try? JSONDecoder().decode([MapSearchRecent].self, from: data) else {
            return
        }
        recents = Array(decoded.prefix(6))
    }

    private func persistRecents() {
        if let encoded = try? JSONEncoder().encode(recents) {
            defaults.set(encoded, forKey: Self.recentsKey(for: scope))
        }
    }

    nonisolated static func recentsKey(for scope: LocalAccountScope) -> String {
        "MugshotMapSearchRecents.v2.\(scope.defaultsComponent)"
    }

    nonisolated static func removeRecents(
        ownerUserID: UUID,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: recentsKey(for: .user(ownerUserID)))
    }

    static func correctedSearchQuery(_ query: String) -> String {
        let corrections = [
            "cofee": "coffee",
            "coffe": "coffee",
            "expresso": "espresso",
            "bakry": "bakery",
            "restaraunt": "restaurant"
        ]
        return query
            .split(separator: " ")
            .map { token in corrections[token.lowercased()] ?? String(token) }
            .joined(separator: " ")
    }

    static func ranked(
        _ items: [MKMapItem],
        query: String,
        region: MKCoordinateRegion
    ) -> [MKMapItem] {
        let normalizedQuery = normalized(query)
        let queryTokens = Set(normalizedQuery.split(separator: " ").map(String.init))
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)

        return items.enumerated().sorted { lhs, rhs in
            score(lhs.element, originalIndex: lhs.offset) > score(rhs.element, originalIndex: rhs.offset)
        }.map(\.element)

        func score(_ item: MKMapItem, originalIndex: Int) -> Double {
            let name = normalized(item.name ?? "")
            let subtitle = normalized(subtitle(for: item))
            let searchable = "\(name) \(subtitle)"
            let itemTokens = Set(searchable.split(separator: " ").map(String.init))
            var value = Double(max(0, 20 - originalIndex))

            if name == normalizedQuery { value += 140 }
            else if name.hasPrefix(normalizedQuery) { value += 100 }
            else if name.contains(normalizedQuery) { value += 72 }

            if !queryTokens.isEmpty && queryTokens.isSubset(of: itemTokens) { value += 55 }
            else { value += Double(queryTokens.intersection(itemTokens).count * 14) }

            if let location = item.placemark.location {
                let meters = location.distance(from: center)
                if meters < 2_000 { value += 22 }
                else if meters < 10_000 { value += 14 }
                else if meters < 50_000 { value += 6 }
            }
            return value
        }
    }

    static func nearest(
        _ items: [MKMapItem],
        to coordinate: CLLocationCoordinate2D,
        limit: Int
    ) -> [MKMapItem] {
        guard limit > 0 else { return [] }
        let center = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var seen = Set<String>()

        return items
            .compactMap { item -> (item: MKMapItem, location: CLLocation, key: String)? in
                guard let location = item.placemark.location,
                      let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { return nil }
                let key = "\(normalized(name))|\(String(format: "%.5f", location.coordinate.latitude))|\(String(format: "%.5f", location.coordinate.longitude))"
                return (item, location, key)
            }
            .sorted { $0.location.distance(from: center) < $1.location.distance(from: center) }
            .compactMap { candidate in
                guard seen.insert(candidate.key).inserted else { return nil }
                return candidate.item
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Keeps generic discovery local while allowing a named place plus city
    /// to resolve beyond the visible map for trip and cafe-list planning.
    static func credibleResults(
        _ items: [MKMapItem],
        query: String,
        region: MKCoordinateRegion
    ) -> [MKMapItem] {
        let normalizedQuery = normalized(query)
        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        let genericDiscoveryTerms: Set<String> = [
            "bakery", "brunch", "cafe", "coffee", "restaurant", "roaster", "tea"
        ]
        let isGenericDiscovery = !queryTokens.isEmpty &&
            queryTokens.allSatisfy(genericDiscoveryTerms.contains)
        let allowsRemotePlanning = queryTokens.count >= 3 || query.contains(",")
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)

        return items.filter { item in
            // Generic searches such as "coffee" should remain local. A named
            // place plus a city is intentionally allowed outside the visible
            // region so a list can be planned before a trip.
            if let location = item.placemark.location,
               location.distance(from: center) > 100_000,
               (isGenericDiscovery || !allowsRemotePlanning) {
                return false
            }

            guard !isGenericDiscovery else { return true }
            let searchable = normalized("\(item.name ?? "") \(subtitle(for: item))")
            let itemTokens = searchable.split(separator: " ").map(String.init)
            let matchedTokenCount = queryTokens.filter { queryToken in
                itemTokens.contains { itemToken in
                    itemToken.hasPrefix(queryToken) || queryToken.hasPrefix(itemToken)
                }
            }.count
            let requiredMatches = allowsRemotePlanning
                ? max(2, queryTokens.count - 1)
                : queryTokens.count
            return !queryTokens.isEmpty && matchedTokenCount >= requiredMatches
        }
    }

    static func subtitle(for item: MKMapItem) -> String {
        let placemark = item.placemark
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        return [street, placemark.locality ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
