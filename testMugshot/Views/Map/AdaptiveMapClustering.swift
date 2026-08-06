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

    static func groundFootprintMeters(in mapView: MKMapView) -> Double {
        guard mapView.bounds.width > 0 else { return 0 }
        let mapPointsPerPoint = mapView.visibleMapRect.width / mapView.bounds.width
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(mapView.region.center.latitude)
        return mapPointsPerPoint * maximumCafeFootprintPoints * metersPerMapPoint
    }

    static func displayMode(
        current: AdaptiveMapDisplayMode,
        groundFootprintMeters: Double,
        visibleCafeCount: Int = 12,
        viewportSize: CGSize = CGSize(width: 390, height: 844)
    ) -> AdaptiveMapDisplayMode {
        let entryThreshold = semanticEntryThreshold(
            visibleCafeCount: visibleCafeCount,
            viewportSize: viewportSize
        )
        let exitThreshold = entryThreshold * 0.7
        switch current {
        case .cafes:
            return groundFootprintMeters >= entryThreshold
                ? .places
                : .cafes
        case .places:
            return groundFootprintMeters <= exitThreshold
                ? .cafes
                : .places
        }
    }

    static func semanticEntryThreshold(
        visibleCafeCount: Int,
        viewportSize: CGSize
    ) -> Double {
        let comfortableCellArea = 90.0 * 90.0
        let viewportArea = max(viewportSize.width * viewportSize.height, comfortableCellArea)
        let comfortableCapacity = max(viewportArea / comfortableCellArea, 1)
        let density = Double(max(visibleCafeCount, 0)) / comfortableCapacity

        // Dense maps switch to named places sooner; sparse maps retain cafe
        // precision longer. The bounded range keeps pan-to-pan changes calm.
        if density >= 1.25 { return 14_000 }
        if density <= 0.25 { return 26_000 }
        let progress = (density - 0.25) / 1.0
        return 26_000 - (12_000 * progress)
    }
}

enum AdaptiveMapCafeClusteringPolicy {
    static func isEnabled(
        current: Bool,
        groundFootprintMeters: Double,
        visibleCafeCount: Int,
        viewportSize: CGSize
    ) -> Bool {
        let entryThreshold = clusteringEntryThreshold(
            visibleCafeCount: visibleCafeCount,
            viewportSize: viewportSize
        )
        let exitThreshold = entryThreshold * 0.72
        return current
            ? groundFootprintMeters > exitThreshold
            : groundFootprintMeters >= entryThreshold
    }

    static func clusteringEntryThreshold(
        visibleCafeCount: Int,
        viewportSize: CGSize
    ) -> Double {
        let comfortableCellArea = 90.0 * 90.0
        let viewportArea = max(viewportSize.width * viewportSize.height, comfortableCellArea)
        let comfortableCapacity = max(viewportArea / comfortableCellArea, 1)
        let density = Double(max(visibleCafeCount, 0)) / comfortableCapacity

        // At the close city scale from the July map, sparse cafe sets retain
        // their individual scores. Dense maps consolidate slightly sooner,
        // before the regional place-aggregate transition takes over.
        if density >= 1.25 { return 3_600 }
        if density <= 0.25 { return 5_600 }
        let progress = (density - 0.25) / 1.0
        return 5_600 - (2_000 * progress)
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
