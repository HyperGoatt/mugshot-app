//
//  AdaptiveMapClusteringTests.swift
//  testMugshotTests
//

import CoreLocation
import CoreGraphics
import MapKit
import Testing
@testable import testMugshot

struct AdaptiveMapClusteringTests {
    @Test func initialCameraPrefersTheCurrentKnownLocation() {
        let currentLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 32.7765, longitude: -79.9311),
            altitude: 3,
            horizontalAccuracy: 12,
            verticalAccuracy: 8,
            timestamp: .now
        )
        let region = MapInitialCameraPolicy.region(
            knownLocation: currentLocation,
            isLocationAuthorized: true,
            cafeCoordinates: [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ]
        )

        #expect(abs(region.center.latitude - currentLocation.coordinate.latitude) < 0.000_001)
        #expect(abs(region.center.longitude - currentLocation.coordinate.longitude) < 0.000_001)
        #expect(region.span.latitudeDelta == MapInitialCameraPolicy.nearbySpan.latitudeDelta)
    }

    @Test func authorizedCameraDoesNotFlashACityDefaultWhileLocationResolves() {
        let region = MapInitialCameraPolicy.region(
            knownLocation: nil,
            isLocationAuthorized: true,
            cafeCoordinates: [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ]
        )

        #expect(region.center.latitude == MapInitialCameraPolicy.broadFallbackRegion.center.latitude)
        #expect(region.center.longitude == MapInitialCameraPolicy.broadFallbackRegion.center.longitude)
        #expect(region.span.latitudeDelta == MapInitialCameraPolicy.broadFallbackRegion.span.latitudeDelta)
    }

    @Test func unavailableLocationFramesExistingCafeActivity() {
        let region = MapInitialCameraPolicy.region(
            knownLocation: nil,
            isLocationAuthorized: false,
            cafeCoordinates: [
                CLLocationCoordinate2D(latitude: 32.7765, longitude: -79.9311),
                CLLocationCoordinate2D(latitude: 32.7898, longitude: -79.9421)
            ]
        )

        #expect(region.center.latitude > 32.77 && region.center.latitude < 32.80)
        #expect(region.center.longitude > -79.95 && region.center.longitude < -79.92)
        #expect(region.span.latitudeDelta >= 0.08)
    }

    @Test func cameraPolicyUsesHysteresisAcrossSemanticBoundary() {
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .cafes,
                groundFootprintMeters: 89_999
            ) == .cafes
        )
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .cafes,
                groundFootprintMeters: 90_000
            ) == .places
        )
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .places,
                groundFootprintMeters: 70_001
            ) == .places
        )
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .places,
                groundFootprintMeters: 70_000
            ) == .cafes
        )
    }

    @Test func cityAndMetroFootprintsKeepIndividualCafeAnnotations() {
        #expect(
            AdaptiveMapCameraPolicy.displayMode(
                current: .cafes,
                groundFootprintMeters: 50_000
            ) == .cafes
        )
    }

    @Test func cafeClusteringBeginsOnlyAfterTheCharlestonLevelWithHysteresis() {
        #expect(
            AdaptiveMapCafeClusteringPolicy.isEnabled(
                current: false,
                groundFootprintMeters: 3_199
            ) == false
        )
        #expect(
            AdaptiveMapCafeClusteringPolicy.isEnabled(
                current: false,
                groundFootprintMeters: 3_200
            ) == true
        )
        #expect(
            AdaptiveMapCafeClusteringPolicy.isEnabled(
                current: true,
                groundFootprintMeters: 2_401
            ) == true
        )
        #expect(
            AdaptiveMapCafeClusteringPolicy.isEnabled(
                current: true,
                groundFootprintMeters: 2_400
            ) == false
        )
    }

    @Test func canonicalSnapshotDeduplicatesAndConservesRepresentationCount() {
        let canonicalID = UUID()
        let localA = Cafe(
            name: "Cached Cafe",
            location: CLLocationCoordinate2D(latitude: 32.78, longitude: -79.93),
            remoteCafeId: canonicalID
        )
        let localB = Cafe(
            name: "Fresh Cafe",
            location: CLLocationCoordinate2D(latitude: 32.781, longitude: -79.931),
            remoteCafeId: canonicalID
        )
        let other = Cafe(
            name: "Other Cafe",
            location: CLLocationCoordinate2D(latitude: 32.79, longitude: -79.94)
        )
        let snapshot = AdaptiveMapAnnotationSnapshot(
            cafes: [localA, localB, other],
            highlightedCafe: nil
        )

        #expect(snapshot.cafes.count == 2)
        #expect(snapshot.cafes.contains(where: { $0.name == "Fresh Cafe" }))
        #expect(
            snapshot.representedCount(
                mode: .cafes,
                highlightedCafe: nil,
                placeNames: [:],
                scores: [:],
                friendCounts: [:]
            ) == 2
        )
        #expect(
            snapshot.representedCount(
                mode: .places,
                highlightedCafe: nil,
                placeNames: [:],
                scores: [:],
                friendCounts: [:]
            ) == 2
        )
    }

    @Test func mapSnapshotMergesNearbyDuplicatePhysicalCafesButNotDistinctLocations() throws {
        let nookA = Cafe(
            name: "Nook Tiny Cafe & Market",
            location: CLLocationCoordinate2D(latitude: 32.7925791, longitude: -79.9485388),
            isFavorite: true,
            averageRating: 4.2,
            visitCount: 1,
            remoteCafeId: UUID()
        )
        let nookB = Cafe(
            name: "nook tiny cafe & market",
            location: CLLocationCoordinate2D(latitude: 32.7925992, longitude: -79.9486125),
            averageRating: 4.1,
            visitCount: 1,
            remoteCafeId: UUID()
        )
        let distantNook = Cafe(
            name: "Nook Tiny Cafe & Market",
            location: CLLocationCoordinate2D(latitude: 32.8529, longitude: -79.9728),
            remoteCafeId: UUID()
        )
        let sameBuildingDifferentCafe = Cafe(
            name: "Another Cafe",
            location: nookA.location,
            remoteCafeId: UUID()
        )
        let distinctApplePlace = Cafe(
            name: "Nook Tiny Cafe & Market",
            location: nookA.location,
            appleMapsPlaceID: "distinct-apple-place",
            remoteCafeId: UUID()
        )
        var appleIdentifiedNook = nookA
        appleIdentifiedNook.appleMapsPlaceID = "original-apple-place"

        let snapshot = AdaptiveMapAnnotationSnapshot(
            cafes: [
                appleIdentifiedNook,
                nookB,
                distantNook,
                sameBuildingDifferentCafe,
                distinctApplePlace
            ],
            highlightedCafe: nil
        )

        #expect(snapshot.cafes.count == 4)
        let downtownNook = try #require(
            snapshot.cafes.first {
                $0.name.localizedCaseInsensitiveContains("nook") && $0.isFavorite
            }
        )
        #expect(downtownNook.averageRating == 4.2)
        #expect(snapshot.cafes.contains(where: { $0.name == "Another Cafe" }))
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
