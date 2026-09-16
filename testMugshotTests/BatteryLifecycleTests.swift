import CoreLocation
import Testing
@testable import testMugshot

struct BatteryLifecycleTests {
    @Test func diagnosticLocationOwnerRegistryIsBalancedAndIdempotent() {
        let first = LocationOwnerToken()
        let second = LocationOwnerToken()
        var registry = BatteryDiagnostics.LocationOwnershipRegistry()

        #expect(registry.acquire(first) == (true, 1))
        #expect(registry.acquire(first) == (false, 1))
        #expect(registry.acquire(second) == (true, 2))
        #expect(registry.release(first) == (true, 1))
        #expect(registry.release(first) == (false, 1))
        #expect(registry.release(second) == (true, 0))
    }

    @Test func authorizedPermissionRequestUsesOneShotLocation() {
        let client = LocationClientFake(authorizationStatus: .authorizedWhenInUse)
        let manager = LocationManager(locationManager: client)

        manager.requestLocationPermission()

        #expect(client.permissionRequestCount == 0)
        #expect(client.locationRequestCount == 1)
        #expect(client.startCount == 0)
        #expect(!manager.isUpdatingContinuously)
    }

    @Test func authorizationChangeDoesNotAcquireContinuousLocation() {
        let client = LocationClientFake(authorizationStatus: .notDetermined)
        let manager = LocationManager(locationManager: client)

        manager.handleAuthorizationChange(.authorizedAlways)

        #expect(client.locationRequestCount == 1)
        #expect(client.startCount == 0)
        #expect(!manager.isUpdatingContinuously)
    }

    @Test func continuousLocationRequiresExplicitBalancedOwnership() {
        let client = LocationClientFake(authorizationStatus: .authorizedWhenInUse)
        let manager = LocationManager(locationManager: client)

        manager.startUpdatingLocation()
        manager.startUpdatingLocation()

        #expect(client.locationRequestCount == 1)
        #expect(client.startCount == 1)
        #expect(manager.isUpdatingContinuously)

        manager.stopUpdatingLocation()

        #expect(client.stopCount == 1)
        #expect(!manager.isUpdatingContinuously)
    }

    @Test func nearbyRegionPlanIsBoundedAndStable() {
        let current = CLLocation(latitude: 40.0, longitude: -75.0)
        let cafes = (0..<25).map { index in
            Cafe(
                id: UUID(),
                name: "Cafe \(index)",
                location: CLLocationCoordinate2D(
                    latitude: 40.0 + Double(index) / 1_000,
                    longitude: -75.0
                ),
                wantToTry: true
            )
        } + [
            Cafe(
                name: "Not saved",
                location: CLLocationCoordinate2D(latitude: 39.0, longitude: -75.0),
                wantToTry: false
            ),
            Cafe(name: "Missing location", wantToTry: true)
        ]

        let desired = NearbyReminderPolicy.regions(
            cafes: cafes,
            currentLocation: current
        )

        #expect(desired.count == NearbyReminderPolicy.monitoredCafeLimit)
        #expect(desired.first?.identifier == "mugshot-nearby-\(cafes[0].id.uuidString.lowercased())")
        #expect(!NearbyReminderPolicy.regionPlanNeedsRefresh(existing: desired, desired: desired))

        let changed = Array(desired.dropLast())
        #expect(NearbyReminderPolicy.regionPlanNeedsRefresh(existing: desired, desired: changed))
    }
}

private final class LocationOwnerToken {}

private final class LocationClientFake: MugshotLocationManaging {
    var delegate: (any CLLocationManagerDelegate)?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers
    var distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    let authorizationStatus: CLAuthorizationStatus
    private(set) var permissionRequestCount = 0
    private(set) var locationRequestCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestWhenInUseAuthorization() { permissionRequestCount += 1 }
    func requestLocation() { locationRequestCount += 1 }
    func startUpdatingLocation() { startCount += 1 }
    func stopUpdatingLocation() { stopCount += 1 }
}
