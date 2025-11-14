//
//  MapSearchService.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import MapKit
import Combine

class MapSearchService: ObservableObject {
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false
    @Published var searchError: String?
    
    private var searchRequest: MKLocalSearch.Request?
    private var currentSearch: MKLocalSearch?
    
    func search(query: String, region: MKCoordinateRegion) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Cancel previous search
        currentSearch?.cancel()
        
        isSearching = true
        searchError = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
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
                
                // Sort results by distance to region center
                let centerLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
                let sorted = response.mapItems.sorted { a, b in
                    let la = a.placemark.location ?? centerLocation
                    let lb = b.placemark.location ?? centerLocation
                    return la.distance(from: centerLocation) < lb.distance(from: centerLocation)
                }
                self?.searchResults = sorted
            }
        }
    }
    
    func cancelSearch() {
        currentSearch?.cancel()
        searchResults = []
        isSearching = false
        searchError = nil
    }
}

