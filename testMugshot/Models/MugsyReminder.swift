import Foundation

enum MugsyReminderPace: String, Codable, CaseIterable, Identifiable {
    case standard, light, off
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var weeklyLimit: Int { self == .standard ? 3 : self == .light ? 1 : 0 }
}

struct MugsyReminderPreferences: Codable, Equatable {
    var mugsyEnabled = false
    var pace: MugsyReminderPace = .standard
    var preferredMinute = 660
    var windowStartMinute = 540
    var windowEndMinute = 1140
    var timezoneName: String?
    var pausedUntil: Date?
    var pausedIndefinitely = false
    var revision = 0
    var consentVersion = 1
    var holdout = false
    var deliveryMode = "off"

    enum CodingKeys: String, CodingKey {
        case mugsyEnabled = "mugsy_enabled", pace
        case preferredMinute = "preferred_minute"
        case windowStartMinute = "window_start_minute"
        case windowEndMinute = "window_end_minute"
        case timezoneName = "timezone_name"
        case pausedUntil = "paused_until"
        case pausedIndefinitely = "paused_indefinitely"
        case revision
        case consentVersion = "consent_version", holdout
        case deliveryMode = "delivery_mode"
    }

    func isPaused(at date: Date) -> Bool {
        pausedIndefinitely || (pausedUntil.map { $0 > date } ?? false)
    }

    var timingIsValid: Bool {
        (0..<1440).contains(windowStartMinute)
            && (1...1440).contains(windowEndMinute)
            && windowStartMinute < windowEndMinute
            && (windowStartMinute..<windowEndMinute).contains(preferredMinute)
    }
}

enum MugsyMemoryOrigin: String, Codable { case home, canonical }

struct MugsyCompletedMemorySignal: Codable, Equatable, Identifiable {
    let accountID: UUID
    let memoryID: UUID
    let origin: MugsyMemoryOrigin
    let completedAt: Date
    let linkedVisitID: UUID?
    var id: String { "\(accountID)|\(memoryID)|\(origin.rawValue)|\(linkedVisitID?.uuidString ?? "")" }
}

struct MugsyNearbyPermit: Decodable {
    let allowed: Bool
    let reason: String
    let permitID: UUID?
    let expiresAt: Date?
    enum CodingKeys: String, CodingKey {
        case allowed, reason
        case permitID = "permit_id", expiresAt = "expires_at"
    }
}

/// A stable, account-bound opportunity. Raw payloads never authorize content.
struct MugsyNotificationIntent: Codable, Equatable, Identifiable {
    let accountID: UUID
    let occurrenceID: UUID
    let destination: Destination
    let expiresAt: Date
    var id: UUID { occurrenceID }

    enum Destination: Codable, Equatable {
        case log, home, repeatSip, journal, activity
        case weekly(Date), memory(UUID)

        static func resolve(_ url: URL) -> Self? {
            guard url.scheme == "mugshot", url.host == "mugsy",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            let path = url.pathComponents.filter { $0 != "/" }
            if path == ["log"] { return .log }
            if path == ["home"] { return .home }
            if path == ["repeat"] { return .repeatSip }
            if path == ["journal"] { return .journal }
            if path == ["activity"] { return .activity }
            if path == ["weekly"],
               let value = components.queryItems?.first(where: { $0.name == "end" })?.value,
               let end = MugsyNotificationIntent.parseDate(value) { return .weekly(end) }
            if path.count == 2, path[0] == "memory", let id = UUID(uuidString: path[1]) { return .memory(id) }
            return nil
        }
    }

    static func resolve(userInfo: [AnyHashable: Any], now: Date = .now) -> Self? {
        guard let payload = userInfo["mugshot_mugsy"] as? [String: Any],
              (payload["version"] as? Int) == 1,
              let owner = payload["recipient_id"] as? String, let ownerID = UUID(uuidString: owner),
              let occurrence = payload["occurrence_id"] as? String, let occurrenceID = UUID(uuidString: occurrence),
              let expiry = payload["expires_at"] as? String, let expiresAt = parseDate(expiry), expiresAt > now,
              let link = payload["deep_link"] as? String, let url = URL(string: link),
              let destination = Destination.resolve(url) else { return nil }
        return Self(accountID: ownerID, occurrenceID: occurrenceID, destination: destination, expiresAt: expiresAt)
    }

    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}
