//
//  MapSearchService.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import MapKit
import Combine
import CoreLocation

class MapSearchService: ObservableObject {
    @Published var searchResults: [MKMapItem] = []
    @Published var nearbySuggestions: [MKMapItem] = []
    @Published var isSearching = false
    @Published var searchError: String?
    
    private var searchRequest: MKLocalSearch.Request?
    private var currentSearch: MKLocalSearch?
    private var nearbySearch: MKLocalSearch? // Separate search instance for suggestions
    
    func search(query: String, region: MKCoordinateRegion, mode: MapSearchMode) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            currentSearch?.cancel()
            searchResults = []
            isSearching = false
            searchError = nil
            return
        }
        
        // Cancel previous search
        currentSearch?.cancel()
        
        isSearching = true
        searchError = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        request.region = region
        
        // Focus on cafes and coffee shops
        request.resultTypes = [.pointOfInterest, .address]
        
        let search = MKLocalSearch(request: request)
        self.currentSearch = search
        
        #if DEBUG
        print("[Search] Mode=\(mode.logLabel) – query=\"\(trimmedQuery)\" – region center=(\(region.center.latitude),\(region.center.longitude))")
        #endif
        
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSearching = false
                
                if let error = error {
                    // MKLocalSearch cancellation typically doesn't call completion handler
                    // If we get an error, it's likely a real network/API error
                    let nsError = error as NSError
                    // Only show error if it's not a cancellation
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        // This is a cancellation, don't show error
                        self.searchResults = []
                        return
                    }
                    // Real error occurred
                    #if DEBUG
                    print("[Search] Mode=\(mode.logLabel) – error=\(error.localizedDescription)")
                    #endif
                    self.searchError = "Can't reach Apple Maps right now. Try again in a bit."
                    self.searchResults = []
                    return
                }
                
                guard let response = response else {
                    self.searchResults = []
                    return
                }
                
                let items: [MKMapItem]
                switch mode {
                case .mugshot:
                    let ranked = self.rankResults(
                        response.mapItems,
                        query: trimmedQuery,
                        region: region
                    )
                    items = ranked
                case .appleMapsNative:
                    // Preserve Apple Maps' native ordering and relevance
                    items = response.mapItems
                }
                
                self.searchResults = items
                
                #if DEBUG
                print("[Search] Mode=\(mode.logLabel) – results=\(items.count)")
                #endif
            }
        }
    }
    
    /// Fetches nearby cafe suggestions for the given region.
    /// Does NOT affect `isSearching` or `searchResults`.
    /// Populates `nearbySuggestions`.
    func searchNearby(region: MKCoordinateRegion) {
        nearbySearch?.cancel()
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Cafe" // Generic query
        request.region = region
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        self.nearbySearch = search
        
        #if DEBUG
        print("[Search] Fetching nearby suggestions for region center=(\(region.center.latitude),\(region.center.longitude))")
        #endif
        
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                
                if let error = error {
                    // Silently fail for suggestions
                    #if DEBUG
                    print("[Search] Nearby suggestions error: \(error.localizedDescription)")
                    #endif
                    return
                }
                
                guard let response = response else { return }
                
                // Sort strictly by distance and take top 3
                let centerLoc = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
                let sorted = response.mapItems.sorted { item1, item2 in
                    let loc1 = item1.placemark.location ?? CLLocation(latitude: 0, longitude: 0)
                    let loc2 = item2.placemark.location ?? CLLocation(latitude: 0, longitude: 0)
                    return loc1.distance(from: centerLoc) < loc2.distance(from: centerLoc)
                }
                
                self.nearbySuggestions = Array(sorted.prefix(3))
                
                #if DEBUG
                print("[Search] Nearby suggestions found: \(self.nearbySuggestions.count)")
                #endif
            }
        }
    }
    
    func cancelSearch() {
        currentSearch?.cancel()
        searchResults = []
        isSearching = false
        searchError = nil
    }
    
    private struct RankedItem {
        let mapItem: MKMapItem
        let bucket: Int
        let distance: CLLocationDistance?
    }
    
    private func rankResults(_ items: [MKMapItem], query: String, region: MKCoordinateRegion) -> [MKMapItem] {
        let centerLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let isCoffeeQuery = MapSearchClassifier.isCoffeeQuery(query)
        
        let ranked = items.map { item -> RankedItem in
            let distance = MapSearchClassifier.distanceInMeters(from: item, referenceLocation: centerLocation)
            let isCoffeeDestination = MapSearchClassifier.isCoffeeDestination(mapItem: item)
            let isNearby = MapSearchClassifier.isNearby(distanceInMeters: distance)
            let isExactMatch = MapSearchClassifier.isExactMatch(itemName: item.name, query: query)
            
            let bucket: Int
            if isCoffeeDestination && isNearby {
                bucket = 0
            } else if isCoffeeDestination {
                bucket = 1
            } else if isNearby && !isCoffeeQuery {
                bucket = 2
            } else if isExactMatch {
                bucket = 3
            } else {
                bucket = 4
            }
            
            return RankedItem(mapItem: item, bucket: bucket, distance: distance)
        }
        
        return ranked.sorted { lhs, rhs in
            if lhs.bucket != rhs.bucket {
                return lhs.bucket < rhs.bucket
            }
            
            switch (lhs.distance, rhs.distance) {
            case let (ld?, rd?):
                if abs(ld - rd) > 10 {
                    return ld < rd
                }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
            
            let lhsName = lhs.mapItem.name ?? ""
            let rhsName = rhs.mapItem.name ?? ""
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }.map(\.mapItem)
    }
}
