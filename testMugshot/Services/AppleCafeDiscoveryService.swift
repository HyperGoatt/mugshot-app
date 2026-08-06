import CoreLocation
import Foundation
import MapKit

@MainActor
final class AppleCafeDiscoveryService: ObservableObject {
    @Published private(set) var candidates: [DiscoveryPlaceCandidate] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var searchedRegion: MKCoordinateRegion?

    private var activeSearch: MKLocalSearch?
    private var generation = UUID()

    func search(
        region: MKCoordinateRegion,
        knownCafes: [Cafe],
        limit: Int = 100
    ) async {
        generation = UUID()
        let searchGeneration = generation
        activeSearch?.cancel()
        isLoading = true
        errorMessage = nil

        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])
        let search = MKLocalSearch(request: request)
        activeSearch = search

        do {
            let response = try await search.start()
            guard generation == searchGeneration, !Task.isCancelled else { return }
            let matches = response.mapItems.compactMap { item -> DiscoveryPlaceCandidate? in
                guard item.placemark.location != nil else { return nil }
                let existing = Self.match(item, in: knownCafes)
                return DiscoveryPlaceCandidate(mapItem: item, existingCafe: existing)
            }
            candidates = Self.deduplicated(matches, limit: limit)
            searchedRegion = region
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard generation == searchGeneration else { return }
            isLoading = false
            errorMessage = "Apple Maps cafe results are unavailable right now."
        }
    }

    func cancel() {
        generation = UUID()
        activeSearch?.cancel()
        isLoading = false
    }

    func refreshLocalState(knownCafes: [Cafe]) {
        candidates = candidates.map { candidate in
            guard let cafe = Self.match(candidate, in: knownCafes) else { return candidate }
            return candidate.applying(localCafe: cafe)
        }
    }

    func markRegionAsSearched(_ region: MKCoordinateRegion) {
        searchedRegion = region
    }

    func shouldSearch(_ visibleRegion: MKCoordinateRegion) -> Bool {
        guard let searchedRegion else { return true }
        let oldCenter = CLLocation(
            latitude: searchedRegion.center.latitude,
            longitude: searchedRegion.center.longitude
        )
        let newCenter = CLLocation(
            latitude: visibleRegion.center.latitude,
            longitude: visibleRegion.center.longitude
        )
        let horizontalMeters = max(
            searchedRegion.span.longitudeDelta * 85_000,
            searchedRegion.span.latitudeDelta * 111_000
        )
        let movedMeaningfully = oldCenter.distance(from: newCenter) > max(horizontalMeters * 0.28, 800)
        let spanChanged = abs(visibleRegion.span.latitudeDelta - searchedRegion.span.latitudeDelta)
            > max(searchedRegion.span.latitudeDelta * 0.35, 0.01)
        return movedMeaningfully || spanChanged
    }

    private static func match(_ mapItem: MKMapItem, in cafes: [Cafe]) -> Cafe? {
        let appleID = mapItem.identifier?.rawValue.remoteTrimmedNonEmpty
        if let appleID,
           let exact = cafes.first(where: { $0.appleMapsPlaceID == appleID }) {
            return exact
        }

        guard let location = mapItem.placemark.location,
              let name = mapItem.name?.remoteTrimmedNonEmpty else { return nil }
        return cafes.first { cafe in
            guard cafe.name.compare(
                name,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame,
            let coordinate = cafe.location else { return false }
            return location.distance(from: CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )) <= 75
        }
    }

    private static func match(_ candidate: DiscoveryPlaceCandidate, in cafes: [Cafe]) -> Cafe? {
        if let appleID = candidate.appleMapsPlaceID,
           let exact = cafes.first(where: { $0.appleMapsPlaceID == appleID }) {
            return exact
        }
        let location = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
        return cafes.first { cafe in
            guard cafe.name.compare(
                candidate.name,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame,
            let coordinate = cafe.location else { return false }
            return location.distance(from: CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )) <= 75
        }
    }

    private static func deduplicated(
        _ candidates: [DiscoveryPlaceCandidate],
        limit: Int
    ) -> [DiscoveryPlaceCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.id).inserted }
            .prefix(max(limit, 0))
            .map { $0 }
    }
}
