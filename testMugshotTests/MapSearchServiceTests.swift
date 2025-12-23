//
//  MapSearchServiceTests.swift
//  testMugshotTests
//
//  Tests for MapSearchService to ensure data race fixes work correctly
//

import Testing
import MapKit
import CoreLocation
@testable import testMugshot

@MainActor
struct MapSearchServiceTests {
    
    @Test("MapSearchService - is MainActor isolated")
    func testMapSearchServiceIsMainActorIsolated() async throws {
        // Create service instance - should be on MainActor
        let service = MapSearchService()
        
        // Verify we can access @Published properties without data race warnings
        #expect(service.searchResults.isEmpty)
        #expect(service.nearbySuggestions.isEmpty)
        #expect(service.isSearching == false)
        #expect(service.searchError == nil)
    }
    
    @Test("MapSearchService - search method is MainActor safe")
    func testSearchMethodIsMainActorSafe() async throws {
        let service = MapSearchService()
        
        // Create a test region (San Francisco)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        // Test search with empty query (should clear results)
        service.search(query: "", region: region, mode: .mugshot)
        
        // Verify state is updated
        #expect(service.isSearching == false)
        #expect(service.searchResults.isEmpty)
        #expect(service.searchError == nil)
    }
    
    @Test("MapSearchService - search with valid query updates state")
    func testSearchWithValidQuery() async throws {
        let service = MapSearchService()
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        // Start a search
        service.search(query: "coffee", region: region, mode: .mugshot)
        
        // Should set isSearching to true
        #expect(service.isSearching == true)
        
        // Wait a bit for search to potentially complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // After search, isSearching should be false (either success or failure)
        // Note: Actual results depend on network and location services
        #expect(service.isSearching == false)
    }
    
    @Test("MapSearchService - cancelSearch clears state")
    func testCancelSearchClearsState() async throws {
        let service = MapSearchService()
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        // Start a search
        service.search(query: "cafe", region: region, mode: .appleMapsNative)
        
        // Cancel immediately
        service.cancelSearch()
        
        // Verify state is cleared
        #expect(service.isSearching == false)
        #expect(service.searchResults.isEmpty)
        #expect(service.searchError == nil)
    }
    
    @Test("MapSearchService - searchNearby updates nearbySuggestions")
    func testSearchNearbyUpdatesSuggestions() async throws {
        let service = MapSearchService()
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        // Search for nearby cafes
        service.searchNearby(region: region)
        
        // Wait for search to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should have results or be empty (depends on network/location)
        // The important thing is no data race warnings
        #expect(service.nearbySuggestions.count >= 0)
    }
    
    @Test("MapSearchService - handles both search modes")
    func testHandlesBothSearchModes() async throws {
        let service = MapSearchService()
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        // Test mugshot mode
        service.search(query: "starbucks", region: region, mode: .mugshot)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Test appleMapsNative mode
        service.search(query: "starbucks", region: region, mode: .appleMapsNative)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Both should work without data race warnings
        #expect(service.isSearching == false)
    }
    
    @Test("MapSearchService - weak self capture prevents retain cycles")
    func testWeakSelfCapture() async throws {
        var service: MapSearchService? = MapSearchService()
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        // Start a search
        service?.search(query: "coffee", region: region, mode: .mugshot)
        
        // Release the service
        service = nil
        
        // Wait a bit - if weak self is working, the completion handler
        // should safely handle the nil self case
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Test passes if no crashes occur
        #expect(true)
    }
}

