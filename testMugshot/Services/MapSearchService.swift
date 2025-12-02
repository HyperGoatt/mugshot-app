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
    @Published var isSearching = false
    @Published var searchError: String?
    
    private var searchRequest: MKLocalSearch.Request?
    private var currentSearch: MKLocalSearch?
    
    func search(query: String, region: MKCoordinateRegion) {
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
        
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                
                if let error = error {
                    // MKLocalSearch cancellation typically doesn't call completion handler
                    // If we get an error, it's likely a real network/API error
                    let nsError = error as NSError
                    // Only show error if it's not a cancellation
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        // This is a cancellation, don't show error
                        self?.searchResults = []
                        return
                    }
                    // Real error occurred
                    self?.searchError = "Can't reach Apple Maps right now. Try again in a bit."
                    self?.searchResults = []
                    return
                }
                
                guard let response = response else {
                    self?.searchResults = []
                    return
                }
                
                let ranked = self?.rankResults(
                    response.mapItems,
                    query: trimmedQuery,
                    region: region
                ) ?? []
                self?.searchResults = ranked
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

