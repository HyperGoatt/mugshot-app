//
//  RecentSearchEntry.swift
//  testMugshot
//
//  Created by Cursor on 11/29/25.
//

import Foundation
import MapKit
import Contacts

struct RecentSearchEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var query: String
    var name: String
    var subtitle: String?
    var street: String?
    var city: String?
    var administrativeArea: String?
    var country: String?
    var postalCode: String?
    var latitude: Double?
    var longitude: Double?
    var placeCategory: String?
    var isCoffeeDestination: Bool
    var urlString: String?
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        query: String,
        name: String,
        subtitle: String? = nil,
        street: String? = nil,
        city: String? = nil,
        administrativeArea: String? = nil,
        country: String? = nil,
        postalCode: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeCategory: String? = nil,
        isCoffeeDestination: Bool,
        urlString: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.name = name
        self.subtitle = subtitle
        self.street = street
        self.city = city
        self.administrativeArea = administrativeArea
        self.country = country
        self.postalCode = postalCode
        self.latitude = latitude
        self.longitude = longitude
        self.placeCategory = placeCategory
        self.isCoffeeDestination = isCoffeeDestination
        self.urlString = urlString
        self.timestamp = timestamp
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isLocationBased: Bool {
        coordinate != nil
    }
    
    func matches(mapItem: MKMapItem) -> Bool {
        guard let otherLocation = mapItem.placemark.location else {
            return mapItem.name?.lowercased() == name.lowercased()
        }
        guard let coordinate else {
            return mapItem.name?.lowercased() == name.lowercased()
        }
        let latDiff = abs(coordinate.latitude - otherLocation.coordinate.latitude)
        let lonDiff = abs(coordinate.longitude - otherLocation.coordinate.longitude)
        // Roughly ~25 meters tolerance
        return latDiff < 0.00025 && lonDiff < 0.00025
    }
    
    func updatingTimestamp() -> RecentSearchEntry {
        var updated = self
        updated.timestamp = Date()
        return updated
    }
    
    func asMapItem() -> MKMapItem? {
        guard let coordinate else { return nil }
        
        let postalAddress: CNMutablePostalAddress? = {
            let hasAddressData = [street, city, administrativeArea, postalCode, country].contains { value in
                guard let value else { return false }
                return !value.isEmpty
            }
            guard hasAddressData else { return nil }
            let address = CNMutablePostalAddress()
            if let street {
                address.street = street
            }
            if let city {
                address.city = city
            }
            if let administrativeArea {
                address.state = administrativeArea
            }
            if let postalCode {
                address.postalCode = postalCode
            }
            if let country {
                address.country = country
            }
            return address
        }()
        
        let placemark: MKPlacemark
        if let postalAddress {
            placemark = MKPlacemark(coordinate: coordinate, postalAddress: postalAddress)
        } else {
            placemark = MKPlacemark(coordinate: coordinate)
        }
        
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        if let urlString, let url = URL(string: urlString) {
            mapItem.url = url
        }
        return mapItem
    }
}


