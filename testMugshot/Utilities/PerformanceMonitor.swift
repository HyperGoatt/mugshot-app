import Foundation
import OSLog

enum PerformanceMonitor {
    private static let logger = Logger(subsystem: "co.mugshot.app", category: "Performance")
    private static let signposter = OSSignposter(logger: logger)

    static func mark(_ name: StaticString) {
        signposter.emitEvent(name)
        logger.info("event=\(String(describing: name), privacy: .public)")
    }

    static func measure<T>(
        _ name: StaticString,
        minimumLogMilliseconds: Double = 0,
        operation: () async throws -> T
    ) async rethrows -> T {
        let state = signposter.beginInterval(name)
        let clock = ContinuousClock()
        let start = clock.now
        defer {
            signposter.endInterval(name, state)
            let duration = start.duration(to: clock.now)
            let components = duration.components
            let milliseconds = Double(components.seconds) * 1_000
                + Double(components.attoseconds) / 1_000_000_000_000_000
            if milliseconds >= minimumLogMilliseconds {
                logger.info(
                    "metric=\(String(describing: name), privacy: .public) duration_ms=\(milliseconds, format: .fixed(precision: 1))"
                )
            }
        }
        return try await operation()
    }
}
