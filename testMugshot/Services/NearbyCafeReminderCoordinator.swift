import Combine
import CoreLocation
import Foundation
@preconcurrency import UserNotifications

struct NearbyReminderPolicy {
    static let monitoredCafeLimit = 20
    static let repeatCooldown: TimeInterval = 30 * 24 * 60 * 60

    struct Region: Hashable {
        let identifier: String
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees
        let radius: CLLocationDistance

        init(cafe: Cafe) {
            identifier = "mugshot-nearby-\(cafe.id.uuidString.lowercased())"
            latitude = cafe.location?.latitude ?? 0
            longitude = cafe.location?.longitude ?? 0
            radius = 250
        }

        init?(monitoredRegion: CLRegion) {
            guard monitoredRegion.identifier.hasPrefix("mugshot-nearby-"),
                  let circularRegion = monitoredRegion as? CLCircularRegion else { return nil }
            identifier = circularRegion.identifier
            latitude = circularRegion.center.latitude
            longitude = circularRegion.center.longitude
            radius = circularRegion.radius
        }
    }

    static func regions(cafes: [Cafe], currentLocation: CLLocation?) -> [Region] {
        cafes
            .filter { $0.wantToTry && $0.location != nil }
            .sorted { lhs, rhs in
                guard let currentLocation,
                      let lhsLocation = lhs.location,
                      let rhsLocation = rhs.location else {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return CLLocation(latitude: lhsLocation.latitude, longitude: lhsLocation.longitude)
                    .distance(from: currentLocation)
                    < CLLocation(latitude: rhsLocation.latitude, longitude: rhsLocation.longitude)
                    .distance(from: currentLocation)
            }
            .prefix(monitoredCafeLimit)
            .map(Region.init(cafe:))
    }

    static func regionPlanNeedsRefresh(existing: [Region], desired: [Region]) -> Bool {
        Set(existing) != Set(desired)
    }

    static func canDeliver(
        cafeID: UUID,
        now: Date,
        lastDailyDelivery: Date?,
        lastDeliveryByCafe: [UUID: Date],
        calendar: Calendar = .current
    ) -> Bool {
        let hour = calendar.component(.hour, from: now)
        guard (7 ..< 18).contains(hour) else { return false }
        if let lastDailyDelivery, calendar.isDate(lastDailyDelivery, inSameDayAs: now) {
            return false
        }
        if let lastCafeDelivery = lastDeliveryByCafe[cafeID],
           now.timeIntervalSince(lastCafeDelivery) < repeatCooldown {
            return false
        }
        return true
    }
}

struct NearbyCafeNotificationRoute {
    static let cafeIDKey = "nearby_cafe_id"

    static func resolve(userInfo: [AnyHashable: Any]) -> UUID? {
        (userInfo[cafeIDKey] as? String).flatMap(UUID.init(uuidString:))
    }
}

@MainActor
final class NearbyCafeReminderRouter: ObservableObject {
    static let shared = NearbyCafeReminderRouter()
    @Published private(set) var pendingCafeID: UUID?

    func enqueue(cafeID: UUID) { pendingCafeID = cafeID }
    func consume() { pendingCafeID = nil }
}

final class NearbyCafeReminderCoordinator: NSObject, ObservableObject {
    static let shared = NearbyCafeReminderCoordinator()
    static let enabledKey = "MugshotNearbyReminders.enabled.v1"
    static let educationDismissedKey = "MugshotNearbyReminders.educationDismissed.v1"

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isEnabled: Bool
    @Published private(set) var monitoredCafeCount = 0

    private let manager = CLLocationManager()
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let lastDailyKey = "MugshotNearbyReminders.lastDaily.v1"
    private let lastCafeKey = "MugshotNearbyReminders.lastByCafe.v1"
    private var pendingAlwaysRequest = false
    private var latestCafes: [Cafe] = []
    private var isMonitoringSignificantChanges = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        let existingRegions = manager.monitoredRegions.compactMap(NearbyReminderPolicy.Region.init(monitoredRegion:))
        monitoredCafeCount = existingRegions.count
        if isEnabled, !existingRegions.isEmpty, manager.authorizationStatus == .authorizedAlways {
            manager.startMonitoringSignificantLocationChanges()
            isMonitoringSignificantChanges = true
            BatteryDiagnostics.nearbyMonitoringStarted(regionCount: existingRegions.count)
        } else if !isEnabled || manager.authorizationStatus != .authorizedAlways {
            stopMonitoring()
        }
    }

    func requestEnable(cafes: [Cafe]) async -> Bool {
        let allowed = await NotificationDeviceCoordinator.shared.requestAuthorization(
            source: .nearbyReminder
        )
        guard allowed else { return false }
        latestCafes = cafes
        isEnabled = true
        defaults.set(true, forKey: Self.enabledKey)
        pendingAlwaysRequest = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            pendingAlwaysRequest = false
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            pendingAlwaysRequest = false
            configure(cafes: cafes)
        case .denied, .restricted:
            pendingAlwaysRequest = false
            isEnabled = false
            defaults.set(false, forKey: Self.enabledKey)
            return false
        @unknown default:
            return false
        }
        return true
    }

    func setEnabled(_ enabled: Bool, cafes: [Cafe]) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        latestCafes = cafes
        if enabled, manager.authorizationStatus == .authorizedAlways {
            configure(cafes: cafes)
        } else if !enabled {
            stopMonitoring()
        }
    }

    func refresh(cafes: [Cafe]) {
        latestCafes = cafes
        guard isEnabled, manager.authorizationStatus == .authorizedAlways else {
            stopMonitoring()
            return
        }
        configure(cafes: cafes)
    }

    private func configure(cafes: [Cafe]) {
        let desiredRegions = NearbyReminderPolicy.regions(
            cafes: cafes,
            currentLocation: manager.location
        )
        guard !desiredRegions.isEmpty else {
            stopMonitoring()
            return
        }

        let existingRegions = manager.monitoredRegions.compactMap(
            NearbyReminderPolicy.Region.init(monitoredRegion:)
        )
        let needsRefresh = NearbyReminderPolicy.regionPlanNeedsRefresh(
            existing: existingRegions,
            desired: desiredRegions
        )
        if needsRefresh {
            BatteryDiagnostics.nearbyPlanChanged(
                previousCount: existingRegions.count,
                desiredCount: desiredRegions.count
            )
            stopMonitoring()
        }
        let registeredRegions = needsRefresh ? [] : existingRegions

        for desiredRegion in desiredRegions where !registeredRegions.contains(desiredRegion) {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: desiredRegion.latitude,
                    longitude: desiredRegion.longitude
                ),
                radius: desiredRegion.radius,
                identifier: desiredRegion.identifier
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
        if !isMonitoringSignificantChanges {
            manager.startMonitoringSignificantLocationChanges()
            isMonitoringSignificantChanges = true
            BatteryDiagnostics.nearbyMonitoringStarted(regionCount: desiredRegions.count)
        }
        monitoredCafeCount = desiredRegions.count
    }

    private func stopMonitoring() {
        let stoppedRegionCount = manager.monitoredRegions.filter {
            $0.identifier.hasPrefix("mugshot-nearby-")
        }.count
        let stoppedActiveMonitoring = isMonitoringSignificantChanges
        for region in manager.monitoredRegions where region.identifier.hasPrefix("mugshot-nearby-") {
            manager.stopMonitoring(for: region)
        }
        manager.stopMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = false
        monitoredCafeCount = 0
        if stoppedActiveMonitoring || stoppedRegionCount > 0 {
            BatteryDiagnostics.nearbyMonitoringStopped(regionCount: stoppedRegionCount)
        }
    }

    private func deliverIfAllowed(cafeID: UUID) {
        let now = Date()
        let lastDaily = defaults.object(forKey: lastDailyKey) as? Date
        let lastByCafe = storedCafeCooldowns()
        guard NearbyReminderPolicy.canDeliver(
            cafeID: cafeID,
            now: now,
            lastDailyDelivery: lastDaily,
            lastDeliveryByCafe: lastByCafe
        ), let cafe = DataManager.shared.getCafe(id: cafeID) else { return }

        let content = UNMutableNotificationContent()
        content.title = "A saved cafe is nearby"
        content.body = "You saved \(cafe.name)—it’s nearby."
        content.sound = .default
        content.userInfo = [NearbyCafeNotificationRoute.cafeIDKey: cafeID.uuidString.lowercased()]
        center.add(UNNotificationRequest(
            identifier: "nearby-cafe-\(cafeID.uuidString.lowercased())-\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        ))
        BatteryDiagnostics.nearbyNotificationDelivered()

        defaults.set(now, forKey: lastDailyKey)
        var updated = lastByCafe
        updated[cafeID] = now
        storeCafeCooldowns(updated)
    }

    private func storedCafeCooldowns() -> [UUID: Date] {
        guard let data = defaults.data(forKey: lastCafeKey),
              let stored = try? JSONDecoder().decode([String: Date].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
    }

    private func storeCafeCooldowns(_ values: [UUID: Date]) {
        let stored = Dictionary(uniqueKeysWithValues: values.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: lastCafeKey)
        }
    }
}

extension NearbyCafeReminderCoordinator: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        BatteryDiagnostics.locationAuthorizationChanged(manager.authorizationStatus)
        guard isEnabled else { return }
        if manager.authorizationStatus == .authorizedWhenInUse, pendingAlwaysRequest {
            pendingAlwaysRequest = false
            manager.requestAlwaysAuthorization()
        } else if manager.authorizationStatus == .authorizedAlways {
            pendingAlwaysRequest = false
            configure(cafes: latestCafes)
        } else if manager.authorizationStatus == .authorizedWhenInUse {
            stopMonitoring()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            setEnabled(false, cafes: latestCafes)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard isEnabled,
              region.identifier.hasPrefix("mugshot-nearby-"),
              let cafeID = UUID(uuidString: String(region.identifier.dropFirst("mugshot-nearby-".count))) else {
            return
        }
        BatteryDiagnostics.nearbyWake(kind: "region_entry", regionCount: monitoredCafeCount)
        deliverIfAllowed(cafeID: cafeID)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isEnabled else { return }
        BatteryDiagnostics.nearbyWake(
            kind: "significant_change",
            regionCount: monitoredCafeCount
        )
        configure(cafes: latestCafes)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        BatteryDiagnostics.locationFailed(code: (error as? CLError)?.code.rawValue ?? -1)
    }
}
