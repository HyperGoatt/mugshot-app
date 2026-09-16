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

protocol MugshotLocationManaging: AnyObject {
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var authorizationStatus: CLAuthorizationStatus { get }

    func requestWhenInUseAuthorization()
    func requestLocation()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: MugshotLocationManaging {}

class LocationManager: NSObject, ObservableObject {
    private let locationManager: any MugshotLocationManaging
    private var continuousLocationUpdateCount = 0
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published private(set) var isUpdatingContinuously = false
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        configureLocationManager()
    }

    init(locationManager: any MugshotLocationManaging) {
        self.locationManager = locationManager
        super.init()
        configureLocationManager()
    }

    deinit {
        BatteryDiagnostics.continuousLocationStopped(
            owner: self,
            updateCount: continuousLocationUpdateCount
        )
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }

    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        // Only request if status is not determined
        guard authorizationStatus == .notDetermined else {
            // Existing permission only needs one fresh fix. Continuous updates
            // are owned explicitly by the visible Map lifecycle.
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                requestCurrentLocation()
            }
            return
        }
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }

        guard !isUpdatingContinuously else { return }
        isUpdatingContinuously = true
        continuousLocationUpdateCount = 0
        BatteryDiagnostics.continuousLocationStarted(owner: self)

        // Request a one-time location update for immediate use
        locationManager.requestLocation()

        // Map is the only owner of this continuous mode and stops it whenever
        // the tab or scene becomes inactive.
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        let wasUpdatingContinuously = isUpdatingContinuously
        isUpdatingContinuously = false
        locationManager.stopUpdatingLocation()
        if wasUpdatingContinuously {
            BatteryDiagnostics.continuousLocationStopped(
                owner: self,
                updateCount: continuousLocationUpdateCount
            )
            continuousLocationUpdateCount = 0
        }
    }
    
    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        BatteryDiagnostics.oneShotLocationRequested()
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
            if isUpdatingContinuously {
                continuousLocationUpdateCount &+= locations.count
            }
            self.location = location
            locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            BatteryDiagnostics.locationFailed(code: clError.code.rawValue)
            switch clError.code {
            case .denied:
                locationError = "Location is off. You can still search for a cafe."
            case .locationUnknown:
                // Location unknown is not necessarily an error, just keep trying
                break
            default:
                locationError = "We couldn’t find your location. You can still search for a cafe."
            }
        } else {
            BatteryDiagnostics.locationFailed(code: -1)
            locationError = "We couldn’t find your location. You can still search for a cafe."
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationChange(manager.authorizationStatus)
    }

    func handleAuthorizationChange(_ newStatus: CLAuthorizationStatus) {
        authorizationStatus = newStatus
        BatteryDiagnostics.locationAuthorizationChanged(newStatus)
        
        switch newStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission changes may be observed by several retained views.
            // A one-shot request is bounded; a continuous session must be
            // acquired by the active Map owner.
            requestCurrentLocation()
            locationError = nil
        case .denied, .restricted:
            locationError = "Location is off. You can still search for a cafe."
            stopUpdatingLocation()
        case .notDetermined:
            // Will request permission when needed
            break
        @unknown default:
            break
        }
    }
}
