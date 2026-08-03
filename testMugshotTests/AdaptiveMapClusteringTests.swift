//
//  AdaptiveMapClusteringTests.swift
//  testMugshotTests
//

import CoreLocation
import CoreGraphics
import Testing
@testable import testMugshot

struct AdaptiveMapClusteringTests {
    @Test func cameraPolicyUsesHysteresisAcrossSemanticBoundary() {
        let viewport = CGSize(width: 360, height: 720)
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .cafes,
                groundFootprintMeters: 19_999,
                visibleCafeCount: 24,
                viewportSize: viewport
            ) == .cafes
        )
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .cafes,
                groundFootprintMeters: 20_000,
                visibleCafeCount: 24,
                viewportSize: viewport
            ) == .places
        )
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .places,
                groundFootprintMeters: 14_001,
                visibleCafeCount: 24,
                viewportSize: viewport
            ) == .places
        )
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .places,
                groundFootprintMeters: 14_000,
                visibleCafeCount: 24,
                viewportSize: viewport
            ) == .cafes
        )
    }

    @Test func semanticThresholdRespondsToVisibleDensity() {
        let viewport = CGSize(width: 390, height: 844)
        let denseThreshold = AdaptiveMapCameraPolicy.semanticEntryThreshold(
            visibleCafeCount: 60,
            viewportSize: viewport
        )
        let sparseThreshold = AdaptiveMapCameraPolicy.semanticEntryThreshold(
            visibleCafeCount: 3,
            viewportSize: viewport
        )

        #expect(denseThreshold == 14_000)
        #expect(sparseThreshold == 26_000)
    }

    @Test func clusterSummaryShowsBestScoreOnlyWithUsefulCoverage() {
        let cafes = (0..<4).map { index in
            Cafe(name: "Cafe \(index)")
        }
        let lowCoverage = AdaptiveMapClusterSummary.make(
            cafes: cafes,
            scores: [cafes[0].id: score(4.8)],
            friendCounts: [:]
        )
        #expect(lowCoverage.bestScore == 4.8)
        #expect(lowCoverage.displayedBestScore == nil)

        let usefulCoverage = AdaptiveMapClusterSummary.make(
            cafes: cafes,
            scores: [
                cafes[0].id: score(4.8),
                cafes[1].id: score(3.7)
            ],
            friendCounts: [:]
        )
        #expect(usefulCoverage.displayedBestScore == 4.8)
    }

    @Test func placeAggregatesAreStableAndKeepActivityEvidence() throws {
        let charlestonA = Cafe(
            name: "Cannon",
            location: CLLocationCoordinate2D(latitude: 32.787, longitude: -79.943),
            isFavorite: true
        )
        let charlestonB = Cafe(
            name: "Wentworth",
            location: CLLocationCoordinate2D(latitude: 32.781, longitude: -79.934),
            wantToTry: true
        )
        let brevard = Cafe(
            name: "Main Street",
            location: CLLocationCoordinate2D(latitude: 35.233, longitude: -82.734)
        )

        let aggregates = AdaptiveMapPlaceAggregateBuilder.make(
            cafes: [charlestonA, charlestonB, brevard],
            placeNames: [
                charlestonA.id: "Charleston",
                charlestonB.id: "Charleston",
                brevard.id: "Brevard"
            ],
            scores: [
                charlestonA.id: score(4.2),
                charlestonB.id: score(3.5),
                brevard.id: score(4.0)
            ],
            friendCounts: [charlestonB.id: 2]
        )

        #expect(aggregates.map(\.label) == ["Brevard", "Charleston"])
        let charleston = try #require(aggregates.first { $0.label == "Charleston" })
        #expect(charleston.summary.cafeCount == 2)
        #expect(charleston.summary.bestScore == 4.2)
        #expect(charleston.summary.favoriteCount == 1)
        #expect(charleston.summary.wantToTryCount == 1)
        #expect(charleston.summary.friendCafeCount == 1)
        #expect(charleston.boundingMapRect.width > 0)
        #expect(charleston.boundingMapRect.height > 0)

        let repeated = AdaptiveMapPlaceAggregateBuilder.make(
            cafes: [brevard, charlestonB, charlestonA],
            placeNames: [
                charlestonA.id: "Charleston",
                charlestonB.id: "Charleston",
                brevard.id: "Brevard"
            ],
            scores: [:],
            friendCounts: [:]
        )
        #expect(repeated.map(\.id) == aggregates.map(\.id))
    }

    @Test func localAddressesProvideNamedPlacesWithoutReplacingAuthoritativeNames() {
        let cafe = Cafe(name: "Local", address: "1 Test Street, Oakland, CA")
        let authoritativeCafe = Cafe(name: "Remote", address: "2 Test Street, Berkeley, CA")
        let names = AdaptiveMapPlaceNameResolver.names(
            for: [cafe, authoritativeCafe],
            authoritativeNames: [authoritativeCafe.id: "Emeryville"]
        )

        #expect(names[cafe.id] == "Oakland")
        #expect(names[authoritativeCafe.id] == "Emeryville")
        #expect(AdaptiveMapPlaceNameResolver.city(in: "Charleston, SC") == "Charleston")
        #expect(AdaptiveMapPlaceNameResolver.city(in: "1 King Street, Charleston") == "Charleston")
    }

    @Test func coincidentCafesOpenAListOnlyAfterTheCameraIsClose() {
        #expect(
            AdaptiveMapClusterTapPolicy.action(
                cafeCount: 2,
                latitudeDelta: 0,
                longitudeDelta: 0,
                cameraSpan: .init(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ) == .zoom
        )
        #expect(
            AdaptiveMapClusterTapPolicy.action(
                cafeCount: 2,
                latitudeDelta: 0,
                longitudeDelta: 0,
                cameraSpan: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ) == .showList
        )
    }

    private func score(_ value: Double) -> MapPinScore {
        MapPinScore(
            value: value,
            source: .sip,
            audience: .personal,
            ratedCafeSessionCount: 0,
            physicalSessionCount: 1,
            sipCount: 1,
            contributorCount: 1,
            relationshipStage: .unrated
        )
    }
}
