//
//  MapSearchService.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import MapKit
import Combine

/// A single, cancellable MapKit search pipeline used everywhere Mugshot asks a
/// person to choose a cafe. Keeping the request generation here prevents a
/// slow, cancelled search from replacing a newer set of results while typing.
@MainActor
final class MapSearchService: ObservableObject {
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false
    @Published var searchError: String?

    private var currentSearch: MKLocalSearch?
    private var pendingSearchTask: Task<Void, Never>?
    private var activeSearchID = UUID()

    func search(query: String, region: MKCoordinateRegion) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            cancelSearch()
            return
        }

        activeSearchID = UUID()
        let searchID = activeSearchID
        currentSearch?.cancel()
        pendingSearchTask?.cancel()

        isSearching = true
        searchError = nil

        // MapKit already coalesces work internally; this small debounce keeps
        // each keystroke from starting a network request and lets cancellation
        // feel immediate.
        pendingSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.beginSearch(
                query: normalizedQuery,
                region: region,
                searchID: searchID
            )
        }
    }

    private func beginSearch(query: String, region: MKCoordinateRegion, searchID: UUID) {
        guard searchID == activeSearchID else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        // A person searching from the map expects the answer to come from the
        // area they are viewing. `region` alone is only a hint to MapKit.
        request.regionPriority = .required
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(
            including: [.cafe, .restaurant, .bakery]
        )

        let search = MKLocalSearch(request: request)
        currentSearch = search

        search.start { [weak self] response, error in
            Task { @MainActor [weak self] in
                guard let self, searchID == self.activeSearchID else { return }

                self.isSearching = false
                self.currentSearch = nil

                if let error {
                    let nsError = error as NSError
                    guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else {
                        return
                    }

                    // MapKit reports an empty, tightly scoped search as an
                    // error rather than an empty response. That is a normal
                    // outcome, not a connectivity problem.
                    if let mapError = error as? MKError,
                       mapError.code == .placemarkNotFound {
                        self.searchResults = []
                        return
                    }

                    self.searchResults = []
                    self.searchError = "We couldn’t search Apple Maps right now. Check your connection and try again, or add the cafe name yourself."
                    return
                }

                guard let response else {
                    self.searchResults = []
                    return
                }

                let centerLocation = CLLocation(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude
                )
                let sorted = response.mapItems
                    .sorted { first, second in
                        let firstLocation = first.placemark.location ?? centerLocation
                        let secondLocation = second.placemark.location ?? centerLocation
                        return firstLocation.distance(from: centerLocation) < secondLocation.distance(from: centerLocation)
                    }
                    .reduce(into: [MKMapItem]()) { results, item in
                        let isDuplicate = results.contains { existing in
                            guard existing.name == item.name,
                                  let existingCoordinate = existing.placemark.location?.coordinate,
                                  let itemCoordinate = item.placemark.location?.coordinate else {
                                return false
                            }
                            return abs(existingCoordinate.latitude - itemCoordinate.latitude) < 0.0001 &&
                                abs(existingCoordinate.longitude - itemCoordinate.longitude) < 0.0001
                        }

                        if !isDuplicate {
                            results.append(item)
                        }
                    }

                self.searchResults = Array(sorted.prefix(12))
            }
        }
    }

    func cancelSearch() {
        activeSearchID = UUID()
        pendingSearchTask?.cancel()
        pendingSearchTask = nil
        currentSearch?.cancel()
        currentSearch = nil
        searchResults = []
        isSearching = false
        searchError = nil
    }
}
