import Foundation
import CoreLocation
import OSLog
import UIKit

#if DEBUG && canImport(MetricKit)
import MetricKit
#endif

/// Privacy-safe, transition-only diagnostics for physical energy investigations.
/// Release builds keep the call sites but compile every recorder to a no-op.
enum BatteryDiagnostics {
    enum WorkOutcome: String {
        case completed
        case cancelled
        case failed
        case interrupted
    }

    struct LocationOwnershipRegistry {
        private var owners: Set<ObjectIdentifier> = []

        mutating func acquire(_ owner: AnyObject) -> (changed: Bool, count: Int) {
            let changed = owners.insert(ObjectIdentifier(owner)).inserted
            return (changed, owners.count)
        }

        mutating func release(_ owner: AnyObject) -> (changed: Bool, count: Int) {
            let changed = owners.remove(ObjectIdentifier(owner)) != nil
            return (changed, owners.count)
        }
    }

#if DEBUG
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "co.mugshot.app",
        category: "Battery"
    )
    private static let signposter = OSSignposter(logger: logger)
    private static let locationOwners = OSAllocatedUnfairLock(
        initialState: LocationOwnershipRegistry()
    )
    private static let runtimeObserver = BatteryRuntimeObserver()
#endif

    static func start() {
#if DEBUG
        _ = runtimeObserver
#if canImport(MetricKit)
        BatteryMetricKitCollector.start()
#endif
#endif
    }

    static func continuousLocationStarted(owner: AnyObject) {
#if DEBUG
        let snapshot = locationOwners.withLock { $0.acquire(owner) }
        guard snapshot.changed else { return }
        signposter.emitEvent("Location continuous start")
        logger.notice("event=location_continuous_start active_owners=\(snapshot.count, privacy: .public)")
#endif
    }

    static func continuousLocationStopped(owner: AnyObject, updateCount: Int) {
#if DEBUG
        let snapshot = locationOwners.withLock { $0.release(owner) }
        guard snapshot.changed else { return }
        signposter.emitEvent("Location continuous stop")
        logger.notice(
            "event=location_continuous_stop active_owners=\(snapshot.count, privacy: .public) updates=\(updateCount, privacy: .public)"
        )
#endif
    }

    static func oneShotLocationRequested() {
#if DEBUG
        signposter.emitEvent("Location one shot")
        logger.info("event=location_one_shot_requested")
#endif
    }

    static func locationAuthorizationChanged(_ status: CLAuthorizationStatus) {
#if DEBUG
        signposter.emitEvent("Location authorization")
        logger.notice("event=location_authorization status=\(status.rawValue, privacy: .public)")
#endif
    }

    static func locationFailed(code: Int) {
#if DEBUG
        signposter.emitEvent("Location failure")
        logger.notice("event=location_failure code=\(code, privacy: .public)")
#endif
    }

    static func nearbyMonitoringStarted(regionCount: Int) {
#if DEBUG
        signposter.emitEvent("Nearby monitoring start")
        logger.notice("event=nearby_monitoring_start regions=\(regionCount, privacy: .public)")
#endif
    }

    static func nearbyMonitoringStopped(regionCount: Int) {
#if DEBUG
        signposter.emitEvent("Nearby monitoring stop")
        logger.notice("event=nearby_monitoring_stop regions=\(regionCount, privacy: .public)")
#endif
    }

    static func nearbyPlanChanged(previousCount: Int, desiredCount: Int) {
#if DEBUG
        signposter.emitEvent("Nearby region plan change")
        logger.notice(
            "event=nearby_region_plan_change previous=\(previousCount, privacy: .public) desired=\(desiredCount, privacy: .public)"
        )
#endif
    }

    static func nearbyWake(kind: StaticString, regionCount: Int) {
#if DEBUG
        signposter.emitEvent("Nearby wake")
        logger.notice(
            "event=nearby_wake kind=\(String(describing: kind), privacy: .public) regions=\(regionCount, privacy: .public)"
        )
#endif
    }

    static func nearbyNotificationDelivered() {
#if DEBUG
        signposter.emitEvent("Nearby notification")
        logger.notice("event=nearby_notification_delivered")
#endif
    }

    static func visitRecoveryStarted(pendingCount: Int) {
#if DEBUG
        signposter.emitEvent("Visit recovery start")
        logger.notice("event=visit_recovery_start pending=\(pendingCount, privacy: .public)")
#endif
    }

    static func visitRecoveryFinished(_ outcome: WorkOutcome, remainingCount: Int) {
#if DEBUG
        signposter.emitEvent("Visit recovery finish")
        logger.notice(
            "event=visit_recovery_finish outcome=\(outcome.rawValue, privacy: .public) remaining=\(remainingCount, privacy: .public)"
        )
#endif
    }

    static func recoveryCancellationRequested(kind: StaticString) {
#if DEBUG
        signposter.emitEvent("Recovery cancellation")
        logger.notice("event=recovery_cancel_requested kind=\(String(describing: kind), privacy: .public)")
#endif
    }

    static func networkAvailabilityChanged(isAvailable: Bool) {
#if DEBUG
        signposter.emitEvent("Network availability")
        logger.notice("event=network_availability available=\(isAvailable, privacy: .public)")
#endif
    }

    static func homeRecoveryStarted() {
#if DEBUG
        signposter.emitEvent("Home recovery start")
        logger.notice("event=home_recovery_start")
#endif
    }

    static func homeRecoveryFinished(_ outcome: WorkOutcome) {
#if DEBUG
        signposter.emitEvent("Home recovery finish")
        logger.notice("event=home_recovery_finish outcome=\(outcome.rawValue, privacy: .public)")
#endif
    }

    struct HomeSyncSession {
#if DEBUG
        private let startedAt = ProcessInfo.processInfo.systemUptime
        private var uploadedBytes = 0
        private var downloadedBytes = 0
        private var uploadedPhotos = 0
        private var downloadedPhotos = 0
#endif

        init(referencedPhotoCount: Int, hasPendingOperation: Bool) {
#if DEBUG
            signposter.emitEvent("Home sync start")
            logger.notice(
                "event=home_sync_start referenced_photos=\(referencedPhotoCount, privacy: .public) pending_operation=\(hasPendingOperation, privacy: .public)"
            )
#endif
        }

        mutating func recordedUpload(byteCount: Int) {
#if DEBUG
            uploadedBytes += byteCount
            uploadedPhotos += 1
#endif
        }

        mutating func recordedDownload(byteCount: Int) {
#if DEBUG
            downloadedBytes += byteCount
            downloadedPhotos += 1
#endif
        }

        func finish(_ outcome: WorkOutcome) {
#if DEBUG
            let durationMilliseconds = Int(
                (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
            )
            signposter.emitEvent("Home sync finish")
            logger.notice(
                "event=home_sync_finish outcome=\(outcome.rawValue, privacy: .public) duration_ms=\(durationMilliseconds, privacy: .public) uploaded_photos=\(uploadedPhotos, privacy: .public) uploaded_bytes=\(uploadedBytes, privacy: .public) downloaded_photos=\(downloadedPhotos, privacy: .public) downloaded_bytes=\(downloadedBytes, privacy: .public)"
            )
#endif
        }
    }

    struct PhotoUploadSession {
#if DEBUG
        private let startedAt = ProcessInfo.processInfo.systemUptime
        private let plannedPhotoCount: Int
        private var uploadedBytes = 0
        private var uploadedPhotos = 0
#endif

        init(plannedPhotoCount: Int) {
#if DEBUG
            self.plannedPhotoCount = plannedPhotoCount
            signposter.emitEvent("Photo upload start")
            logger.notice("event=photo_upload_start planned_photos=\(plannedPhotoCount, privacy: .public)")
#endif
        }

        mutating func recordedUpload(byteCount: Int) {
#if DEBUG
            uploadedBytes += byteCount
            uploadedPhotos += 1
#endif
        }

        func finish(_ outcome: WorkOutcome) {
#if DEBUG
            let durationMilliseconds = Int(
                (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
            )
            signposter.emitEvent("Photo upload finish")
            logger.notice(
                "event=photo_upload_finish outcome=\(outcome.rawValue, privacy: .public) duration_ms=\(durationMilliseconds, privacy: .public) planned_photos=\(plannedPhotoCount, privacy: .public) uploaded_photos=\(uploadedPhotos, privacy: .public) uploaded_bytes=\(uploadedBytes, privacy: .public)"
            )
#endif
        }
    }

#if DEBUG
    fileprivate static func applicationEvent(_ name: StaticString) {
        signposter.emitEvent("Application lifecycle")
        logger.notice("event=application_lifecycle state=\(String(describing: name), privacy: .public)")
    }

    fileprivate static func recordCurrentThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        signposter.emitEvent("Thermal state")
        logger.notice("event=thermal_state state=\(thermalName(state), privacy: .public)")
    }

    fileprivate static func recordCurrentPowerState() {
        signposter.emitEvent("Power state")
        logger.notice(
            "event=power_state low_power_mode=\(ProcessInfo.processInfo.isLowPowerModeEnabled, privacy: .public)"
        )
    }

    fileprivate static func metricKitPayload(kind: StaticString, count: Int) {
        signposter.emitEvent("MetricKit payload")
        logger.notice(
            "event=metrickit_payload kind=\(String(describing: kind), privacy: .public) count=\(count, privacy: .public)"
        )
    }

    private static func thermalName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
#endif
}

#if DEBUG
private final class BatteryRuntimeObserver {
    private var observers: [NSObjectProtocol] = []

    init() {
        BatteryDiagnostics.applicationEvent("diagnostics_started")
        BatteryDiagnostics.recordCurrentThermalState()
        BatteryDiagnostics.recordCurrentPowerState()

        let center = NotificationCenter.default
        observe(center, name: UIApplication.didBecomeActiveNotification, event: "active")
        observe(center, name: UIApplication.willResignActiveNotification, event: "inactive")
        observe(center, name: UIApplication.didEnterBackgroundNotification, event: "background")
        observe(center, name: UIApplication.willEnterForegroundNotification, event: "foreground")
        observers.append(center.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in BatteryDiagnostics.recordCurrentThermalState() })
        observers.append(center.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { _ in BatteryDiagnostics.recordCurrentPowerState() })
    }

    private func observe(
        _ center: NotificationCenter,
        name: Notification.Name,
        event: StaticString
    ) {
        observers.append(center.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { _ in BatteryDiagnostics.applicationEvent(event) })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
#endif

#if DEBUG && canImport(MetricKit)
private final class BatteryMetricKitCollector: NSObject, MXMetricManagerSubscriber {
    private static let shared = BatteryMetricKitCollector()
    private let directory: URL

    static func start() {
        _ = shared
    }

    override init() {
        directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MugshotBatteryDiagnostics", isDirectory: true)
        super.init()
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        BatteryDiagnostics.metricKitPayload(kind: "metrics", count: payloads.count)
        persist(payloads.map { $0.jsonRepresentation() }, prefix: "metrics")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        BatteryDiagnostics.metricKitPayload(kind: "diagnostics", count: payloads.count)
        persist(payloads.map { $0.jsonRepresentation() }, prefix: "diagnostics")
    }

    private func persist(_ payloads: [Data], prefix: String) {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            for payload in payloads {
                let filename = "\(prefix)-\(UUID().uuidString.lowercased()).json"
                try payload.write(
                    to: directory.appendingPathComponent(filename),
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
            }
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ).sorted { lhs, rhs in
                let left = try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                let right = try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return (left ?? .distantPast) > (right ?? .distantPast)
            }
            for expired in files.dropFirst(20) {
                try? FileManager.default.removeItem(at: expired)
            }
        } catch {
            BatteryDiagnostics.metricKitPayload(kind: "persistence_failed", count: payloads.count)
        }
    }
}
#endif
