//
//  LocationManager.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//
//  NOTE: To enable location services, add the following to your Info.plist:
//  - NSLocationWhenInUseUsageDescription: "Mugshot uses your location to show cafes near you on the map."
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // PERF: Increased from 10m to 50m for better battery life
        // Most map use cases don't need sub-50m accuracy
        locationManager.distanceFilter = 50 // Update every 50 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        // Only request if status is not determined
        guard authorizationStatus == .notDetermined else {
            // If already authorized, start updating
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                startUpdatingLocation()
            }
            return
        }
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        // Request a one-time location update for immediate use
        locationManager.requestLocation()
        
        // Also start continuous updates for "my location" button
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.requestLocation()
    }
    
    func getCurrentLocation() -> CLLocation? {
        return location
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if location is reasonably recent (within last 30 seconds)
        let locationAge = -location.timestamp.timeIntervalSinceNow
        if locationAge < 30 {
            self.location = location
            locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "Location access denied"
            case .locationUnknown:
                // Location unknown is not necessarily an error, just keep trying
                break
            default:
                locationError = clError.localizedDescription
            }
        } else {
            locationError = error.localizedDescription
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        authorizationStatus = newStatus
        
        switch newStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Start updating location when permission is granted
            startUpdatingLocation()
            locationError = nil
        case .denied, .restricted:
            locationError = "Location access denied"
            stopUpdatingLocation()
        case .notDetermined:
            // Will request permission when needed
            break
        @unknown default:
            break
        }
    }
}

