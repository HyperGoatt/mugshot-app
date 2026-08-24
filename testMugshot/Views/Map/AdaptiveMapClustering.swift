//
//  AdaptiveMapClustering.swift
//  testMugshot
//

import Foundation
import MapKit

enum AdaptiveMapDisplayMode: Equatable {
    case cafes
    case places
}

enum AdaptiveMapClusterTapAction: Equatable {
    case zoom
    case showList
}

enum AdaptiveMapClusterTapPolicy {
    static func action(
        cafeCount: Int,
        latitudeDelta: Double,
        longitudeDelta: Double,
        cameraSpan: MKCoordinateSpan
    ) -> AdaptiveMapClusterTapAction {
        let coordinatesOverlap = latitudeDelta < 0.000_01 && longitudeDelta < 0.000_01
        let isAlreadyClose = cameraSpan.latitudeDelta <= 0.015
            && cameraSpan.longitudeDelta <= 0.015
        return coordinatesOverlap && isAlreadyClose && cafeCount > 1
            ? .showList
            : .zoom
    }
}

enum AdaptiveMapCameraPolicy {
    static let maximumCafeFootprintPoints = 60.0
    // MapKit already groups colliding cafe pins. Keep those useful, individual
    // memories visible throughout city and metro views, and reserve the broad
    // place aggregates for genuinely regional camera footprints.
    static let aggregateEntryMeters = 90_000.0
    static let cafeReturnMeters = 70_000.0

    static func groundFootprintMeters(in mapView: MKMapView) -> Double {
        guard mapView.bounds.width > 0 else { return 0 }
        let mapPointsPerPoint = mapView.visibleMapRect.width / mapView.bounds.width
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(mapView.region.center.latitude)
        return mapPointsPerPoint * maximumCafeFootprintPoints * metersPerMapPoint
    }

    static func displayMode(
        current: AdaptiveMapDisplayMode,
        groundFootprintMeters: Double
    ) -> AdaptiveMapDisplayMode {
        switch current {
        case .cafes:
            return groundFootprintMeters >= aggregateEntryMeters
                ? .places
                : .cafes
        case .places:
            return groundFootprintMeters <= cafeReturnMeters
                ? .cafes
                : .places
        }
    }
}

enum AdaptiveMapCafeClusteringPolicy {
    // `groundFootprintMeters` measures the ground covered by one 60-point
    // cafe pin. The Charleston peninsula remains individually readable below
    // this boundary; clustering begins only after the next material zoom-out.
    static let clusteringEntryMeters = 3_200.0
    static let individualReturnMeters = 2_400.0

    static func isEnabled(
        current: Bool,
        groundFootprintMeters: Double
    ) -> Bool {
        current
            ? groundFootprintMeters > individualReturnMeters
            : groundFootprintMeters >= clusteringEntryMeters
    }
}

struct AdaptiveMapAnnotationSnapshot: Equatable {
    let cafesByCanonicalID: [UUID: Cafe]

    init(cafes: [Cafe], highlightedCafe: Cafe?) {
        var canonicalCafes: [UUID: Cafe] = [:]
        for cafe in cafes where cafe.location != nil {
            canonicalCafes[cafe.remoteCafeId ?? cafe.id] = cafe
        }
        if let highlightedCafe, highlightedCafe.location != nil {
            canonicalCafes[highlightedCafe.remoteCafeId ?? highlightedCafe.id] = highlightedCafe
        }

        let highlightedID = highlightedCafe.map { $0.remoteCafeId ?? $0.id }
        var physicalCafes: [Cafe] = []
        for cafe in canonicalCafes
            .sorted(by: { $0.key.uuidString < $1.key.uuidString })
            .map(\.value) {
            guard let duplicateIndex = physicalCafes.firstIndex(where: {
                Self.representsSamePhysicalCafe($0, cafe)
            }) else {
                physicalCafes.append(cafe)
                continue
            }
            physicalCafes[duplicateIndex] = Self.merge(
                physicalCafes[duplicateIndex],
                cafe,
                highlightedID: highlightedID
            )
        }

        cafesByCanonicalID = Dictionary(
            uniqueKeysWithValues: physicalCafes.map {
                ($0.remoteCafeId ?? $0.id, $0)
            }
        )
    }

    var cafes: [Cafe] {
        cafesByCanonicalID
            .sorted { $0.key.uuidString < $1.key.uuidString }
            .map(\.value)
    }

    func representedCount(
        mode: AdaptiveMapDisplayMode,
        highlightedCafe: Cafe?,
        placeNames: [UUID: String],
        scores: [UUID: MapPinScore],
        friendCounts: [UUID: Int]
    ) -> Int {
        switch mode {
        case .cafes:
            return cafes.count
        case .places:
            let highlightedID = highlightedCafe.map { $0.remoteCafeId ?? $0.id }
            let aggregateCafes = cafes.filter { ($0.remoteCafeId ?? $0.id) != highlightedID }
            let aggregateCount = AdaptiveMapPlaceAggregateBuilder.make(
                cafes: aggregateCafes,
                placeNames: placeNames,
                scores: scores,
                friendCounts: friendCounts
            )
            .reduce(0) { $0 + $1.cafes.count }
            return aggregateCount + (highlightedID == nil ? 0 : 1)
        }
    }

    private static func representsSamePhysicalCafe(_ lhs: Cafe, _ rhs: Cafe) -> Bool {
        if let lhsAppleID = lhs.appleMapsPlaceID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lhsAppleID.isEmpty,
           let rhsAppleID = rhs.appleMapsPlaceID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rhsAppleID.isEmpty {
            return lhsAppleID.caseInsensitiveCompare(rhsAppleID) == .orderedSame
        }
        guard normalizedName(lhs.name) == normalizedName(rhs.name),
              let lhsLocation = lhs.location,
              let rhsLocation = rhs.location else {
            return false
        }
        return CLLocation(latitude: lhsLocation.latitude, longitude: lhsLocation.longitude)
            .distance(from: CLLocation(latitude: rhsLocation.latitude, longitude: rhsLocation.longitude)) <= 25
    }

    private static func normalizedName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }

    private static func merge(
        _ lhs: Cafe,
        _ rhs: Cafe,
        highlightedID: UUID?
    ) -> Cafe {
        let preferred: Cafe
        if (rhs.remoteCafeId ?? rhs.id) == highlightedID {
            preferred = rhs
        } else if (lhs.remoteCafeId ?? lhs.id) == highlightedID {
            preferred = lhs
        } else {
            preferred = evidenceRank(rhs) > evidenceRank(lhs) ? rhs : lhs
        }

        let alternate = preferred.id == lhs.id ? rhs : lhs
        var merged = preferred
        merged.isFavorite = lhs.isFavorite || rhs.isFavorite
        merged.wantToTry = lhs.wantToTry || rhs.wantToTry
        merged.visitCount = max(lhs.visitCount, rhs.visitCount)
        if merged.averageRating <= 0 {
            merged.averageRating = alternate.averageRating
        }
        if merged.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.address = alternate.address
        }
        if merged.appleMapsPlaceID == nil {
            merged.appleMapsPlaceID = alternate.appleMapsPlaceID
        }
        return merged
    }

    private static func evidenceRank(_ cafe: Cafe) -> Int {
        (cafe.isFavorite ? 10_000 : 0)
            + (cafe.wantToTry ? 5_000 : 0)
            + min(cafe.visitCount, 999) * 10
            + (cafe.averageRating > 0 ? 5 : 0)
            + (cafe.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
    }
}

struct AdaptiveMapClusterSummary: Equatable {
    let cafeCount: Int
    let ratedCount: Int
    let bestScore: Double?
    let favoriteCount: Int
    let wantToTryCount: Int
    let friendCafeCount: Int

    var displayedBestScore: Double? {
        guard let bestScore,
              ratedCount * 2 >= cafeCount || (cafeCount <= 3 && ratedCount > 0) else {
            return nil
        }
        return bestScore
    }

    static func make(
        cafes: [Cafe],
        scores: [UUID: MapPinScore],
        friendCounts: [UUID: Int]
    ) -> AdaptiveMapClusterSummary {
        let resolvedScores = cafes.compactMap { scores[$0.id]?.value }
            .filter { $0 > 0 && $0.isFinite }
        return AdaptiveMapClusterSummary(
            cafeCount: cafes.count,
            ratedCount: resolvedScores.count,
            bestScore: resolvedScores.max(),
            favoriteCount: cafes.filter(\.isFavorite).count,
            wantToTryCount: cafes.filter(\.wantToTry).count,
            friendCafeCount: cafes.filter { (friendCounts[$0.id] ?? 0) > 0 }.count
        )
    }

    static func merging(_ summaries: [AdaptiveMapClusterSummary]) -> AdaptiveMapClusterSummary {
        AdaptiveMapClusterSummary(
            cafeCount: summaries.reduce(0) { $0 + $1.cafeCount },
            ratedCount: summaries.reduce(0) { $0 + $1.ratedCount },
            bestScore: summaries.compactMap(\.bestScore).max(),
            favoriteCount: summaries.reduce(0) { $0 + $1.favoriteCount },
            wantToTryCount: summaries.reduce(0) { $0 + $1.wantToTryCount },
            friendCafeCount: summaries.reduce(0) { $0 + $1.friendCafeCount }
        )
    }
}

struct AdaptiveMapPlaceAggregate: Identifiable {
    let id: String
    let label: String
    let coordinate: CLLocationCoordinate2D
    let cafes: [Cafe]
    let summary: AdaptiveMapClusterSummary
    let boundingMapRect: MKMapRect
}

enum AdaptiveMapPlaceAggregateBuilder {
    static func make(
        cafes: [Cafe],
        placeNames: [UUID: String],
        scores: [UUID: MapPinScore],
        friendCounts: [UUID: Int]
    ) -> [AdaptiveMapPlaceAggregate] {
        let locatedCafes = cafes.filter { $0.location != nil }
        let grouped = Dictionary(grouping: locatedCafes) { cafe in
            groupingKey(for: cafe, placeName: placeNames[cafe.id])
        }

        return grouped.compactMap { key, members in
            guard !members.isEmpty else { return nil }
            let points = members.compactMap(\.location).map(MKMapPoint.init)
            guard !points.isEmpty else { return nil }
            let averagePoint = MKMapPoint(
                x: points.reduce(0) { $0 + $1.x } / Double(points.count),
                y: points.reduce(0) { $0 + $1.y } / Double(points.count)
            )
            let boundingMapRect = bounds(for: points)
            let namedLabel = members.compactMap { member in
                placeNames[member.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .first
            let label = namedLabel ?? "Cafe area"

            return AdaptiveMapPlaceAggregate(
                id: key,
                label: label,
                coordinate: averagePoint.coordinate,
                cafes: members.sorted { $0.consumerDisplayName < $1.consumerDisplayName },
                summary: .make(cafes: members, scores: scores, friendCounts: friendCounts),
                boundingMapRect: boundingMapRect
            )
        }
        .sorted { lhs, rhs in
            lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    private static func groupingKey(for cafe: Cafe, placeName: String?) -> String {
        guard let coordinate = cafe.location else { return "missing:\(cafe.id.uuidString)" }
        let latitudeBucket = Int(floor(coordinate.latitude / 2))
        let longitudeBucket = Int(floor(coordinate.longitude / 2))
        let normalizedName = placeName?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: "-")

        if let normalizedName, !normalizedName.isEmpty {
            return "place:\(normalizedName):\(latitudeBucket):\(longitudeBucket)"
        }
        return "area:\(latitudeBucket):\(longitudeBucket)"
    }

    private static func bounds(for points: [MKMapPoint]) -> MKMapRect {
        guard let first = points.first else { return .null }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return MKMapRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}

enum AdaptiveMapPlaceNameResolver {
    static func names(
        for cafes: [Cafe],
        authoritativeNames: [UUID: String]
    ) -> [UUID: String] {
        cafes.reduce(into: authoritativeNames) { result, cafe in
            guard result[cafe.id] == nil,
                  let inferredCity = city(in: cafe.address) else { return }
            result[cafe.id] = inferredCity
        }
    }

    static func city(in address: String) -> String? {
        let components = address.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard components.count >= 2 else { return nil }
        let lastComponent = components[components.count - 1]
        let firstLastToken = lastComponent.split(separator: " ").first.map(String.init) ?? ""
        let looksLikeStateAndPostalCode = firstLastToken.count == 2
            && firstLastToken == firstLastToken.uppercased()
            && firstLastToken.allSatisfy(\.isLetter)
        let candidate = components.count == 2 && !looksLikeStateAndPostalCode
            ? lastComponent
            : components[components.count - 2]
        guard !candidate.isEmpty,
              candidate.rangeOfCharacter(from: .letters) != nil else { return nil }
        return candidate
    }
}
