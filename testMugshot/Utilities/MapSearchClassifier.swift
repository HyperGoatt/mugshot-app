//
//  MapSearchClassifier.swift
//  testMugshot
//
//  Created by Cursor on 11/29/25.
//

import Foundation
import MapKit
import CoreLocation

enum MapSearchClassifier {
    static let nearbyRadiusMeters: CLLocationDistance = 8046.72 // ≈5 miles
    
    private static let alwaysCoffeeCategories: Set<MKPointOfInterestCategory> = [
        .cafe,
        .bakery
    ]
    
    private static let conditionalCoffeeCategories: Set<MKPointOfInterestCategory> = [
        .restaurant
    ]
    
    private static let coffeeCategoryRawValues: Set<String> = [
        "mkpoicategorycafe",
        "mkpoicategorycoffeeshop",
        "mkpoicategorybakery",
        "cafe",
        "coffee",
        "coffee_shop",
        "coffeehouse",
        "bakery"
    ]
    
    private static let coffeeKeywords: [String] = [
        "coffee",
        "cafe",
        "cafe",
        "espresso",
        "latte",
        "americano",
        "mocha",
        "brew",
        "bean",
        "roast",
        "roastery",
        "roaster",
        "macchiato",
        "cold brew",
        "pour over",
        "drip",
        "matcha"
    ]
    
    static func isCoffeeDestination(mapItem: MKMapItem) -> Bool {
        if let category = mapItem.pointOfInterestCategory {
            if alwaysCoffeeCategories.contains(category) {
                return true
            }
            if conditionalCoffeeCategories.contains(category),
               containsCoffeeKeyword(in: mapItem.name) {
                return true
            }
        }
        
        if let rawValue = mapItem.pointOfInterestCategory?.rawValue.lowercased(),
           coffeeCategoryRawValues.contains(rawValue) {
            return true
        }
        
        return containsCoffeeKeyword(in: mapItem.name ?? mapItem.placemark.name)
    }
    
    static func isCoffeeQuery(_ query: String) -> Bool {
        containsCoffeeKeyword(in: query)
    }
    
    static func containsCoffeeKeyword(in text: String?) -> Bool {
        guard let text else { return false }
        let normalized = normalize(text)
        return coffeeKeywords.contains { keyword in
            normalized.contains(normalize(keyword))
        }
    }
    
    static func isExactMatch(itemName: String?, query: String) -> Bool {
        guard let itemName else { return false }
        return normalize(itemName) == normalize(query)
    }
    
    static func subtitle(from placemark: MKPlacemark) -> String? {
        var components: [String] = []
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let neighborhood = placemark.subLocality {
            components.append(neighborhood)
        } else if let city = placemark.locality {
            components.append(city)
        }
        guard !components.isEmpty else {
            return placemark.title
        }
        return components.joined(separator: ", ")
    }
    
    static func cityOrNeighborhood(from placemark: MKPlacemark) -> String? {
        if let neighborhood = placemark.subLocality, !neighborhood.isEmpty {
            return neighborhood
        }
        if let city = placemark.locality, !city.isEmpty {
            return city
        }
        return nil
    }
    
    static func distanceInMeters(from item: MKMapItem, referenceLocation: CLLocation) -> CLLocationDistance? {
        guard let location = item.placemark.location else { return nil }
        return location.distance(from: referenceLocation)
    }
    
    static func formattedDistance(fromMeters meters: CLLocationDistance?) -> String? {
        guard let meters else { return nil }
        let miles = meters * 0.000621371
        if miles < 0.1 {
            return String(format: "%.1f mi", max(miles, 0.1))
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
    
    static func isNearby(distanceInMeters: CLLocationDistance?) -> Bool {
        guard let distance = distanceInMeters else { return false }
        return distance <= nearbyRadiusMeters
    }
    
    private static func normalize(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}


