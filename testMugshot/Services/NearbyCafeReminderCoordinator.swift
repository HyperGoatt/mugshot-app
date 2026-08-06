import Combine
import CoreLocation
import Foundation
@preconcurrency import UserNotifications

struct NearbyReminderPolicy {
    static let monitoredCafeLimit = 20
    static let repeatCooldown: TimeInterval = 30 * 24 * 60 * 60

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

    override init() {
        authorizationStatus = manager.authorizationStatus
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        if isEnabled {
            manager.startMonitoringSignificantLocationChanges()
        }
    }

    func requestEnable(cafes: [Cafe]) async -> Bool {
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound])
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
        } catch {
            return false
        }
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
        guard isEnabled, manager.authorizationStatus == .authorizedAlways else { return }
        configure(cafes: cafes)
    }

    private func configure(cafes: [Cafe]) {
        stopMonitoring()
        let current = manager.location
        let eligible = cafes
            .filter { $0.wantToTry && $0.location != nil }
            .sorted { lhs, rhs in
                guard let current,
                      let lhsLocation = lhs.location,
                      let rhsLocation = rhs.location else {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return CLLocation(latitude: lhsLocation.latitude, longitude: lhsLocation.longitude)
                    .distance(from: current)
                    < CLLocation(latitude: rhsLocation.latitude, longitude: rhsLocation.longitude)
                    .distance(from: current)
            }
            .prefix(NearbyReminderPolicy.monitoredCafeLimit)

        for cafe in eligible {
            guard let coordinate = cafe.location else { continue }
            let region = CLCircularRegion(
                center: coordinate,
                radius: 250,
                identifier: "mugshot-nearby-\(cafe.id.uuidString.lowercased())"
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
        manager.startMonitoringSignificantLocationChanges()
        monitoredCafeCount = eligible.count
    }

    private func stopMonitoring() {
        for region in manager.monitoredRegions where region.identifier.hasPrefix("mugshot-nearby-") {
            manager.stopMonitoring(for: region)
        }
        manager.stopMonitoringSignificantLocationChanges()
        monitoredCafeCount = 0
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
        guard isEnabled else { return }
        if manager.authorizationStatus == .authorizedWhenInUse, pendingAlwaysRequest {
            pendingAlwaysRequest = false
            manager.requestAlwaysAuthorization()
        } else if manager.authorizationStatus == .authorizedAlways {
            pendingAlwaysRequest = false
            configure(cafes: latestCafes)
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
        deliverIfAllowed(cafeID: cafeID)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isEnabled else { return }
        configure(cafes: latestCafes)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
