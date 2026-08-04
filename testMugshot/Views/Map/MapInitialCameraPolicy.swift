//
//  MapInitialCameraPolicy.swift
//  testMugshot
//

import CoreLocation
import MapKit

enum MapInitialCameraPolicy {
    static let nearbySpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)

    // This intentionally avoids a city-specific default. When location access
    // is authorized but Core Location has not produced a value yet, a broad
    // camera is more honest than briefly implying the person is in San Francisco.
    static let broadFallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 300)
    )

    static func region(
        knownLocation: CLLocation?,
        isLocationAuthorized: Bool,
        cafeCoordinates: [CLLocationCoordinate2D]
    ) -> MKCoordinateRegion {
        if let knownLocation,
           CLLocationCoordinate2DIsValid(knownLocation.coordinate),
           knownLocation.horizontalAccuracy >= 0 {
            return MKCoordinateRegion(
                center: knownLocation.coordinate,
                span: nearbySpan
            )
        }

        // An authorized location request is expected to resolve quickly. Do
        // not flash a cafe-data default while that request is in flight.
        if isLocationAuthorized {
            return broadFallbackRegion
        }

        let validCoordinates = cafeCoordinates.filter(CLLocationCoordinate2DIsValid)
        guard let first = validCoordinates.first else {
            return broadFallbackRegion
        }

        let latitudes = validCoordinates.map(\.latitude)
        let longitudes = validCoordinates.map(\.longitude)
        let minimumLatitude = latitudes.min() ?? first.latitude
        let maximumLatitude = latitudes.max() ?? first.latitude
        let minimumLongitude = longitudes.min() ?? first.longitude
        let maximumLongitude = longitudes.max() ?? first.longitude

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minimumLatitude + maximumLatitude) / 2,
                longitude: (minimumLongitude + maximumLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: min(max((maximumLatitude - minimumLatitude) * 1.5, 0.08), 120),
                longitudeDelta: min(max((maximumLongitude - minimumLongitude) * 1.5, 0.08), 300)
            )
        )
    }
}
