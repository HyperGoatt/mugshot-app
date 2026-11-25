import Foundation

/// Shared between the native app tests and the isolated service extension.
/// Remote URLs, file paths, user photographs and unreviewed artwork are rejected.
enum MugsyNotificationAttachmentPolicy {
    static let allowedAssets: Set<String> = [
        "MugsyPoseWave", "MugsyPoseJournal", "MugsyPoseCamera", "MugsyPoseCozy", "MugsyPoseBeans"
    ]

    static func assetIdentifier(userInfo: [AnyHashable: Any], now: Date = .now) -> String? {
        guard let payload = userInfo["mugshot_mugsy"] as? [String: Any],
              payload["version"] as? Int == 1,
              let recipient = payload["recipient_id"] as? String, UUID(uuidString: recipient) != nil,
              let occurrence = payload["occurrence_id"] as? String, UUID(uuidString: occurrence) != nil,
              let expires = payload["expires_at"] as? String,
              let expiry = date(from: expires), expiry > now,
              let templateID = payload["template_id"] as? String,
              let assetID = payload["asset_id"] as? String, allowedAssets.contains(assetID),
              expectedAsset(for: templateID) == assetID else { return nil }
        return assetID
    }

    static func fileName(for assetID: String) -> String? {
        allowedAssets.contains(assetID) ? "\(assetID).png" : nil
    }

    private static func expectedAsset(for templateID: String) -> String? {
        guard let separator = templateID.lastIndex(of: "_"),
              ["1", "2", "3", "4"].contains(String(templateID[templateID.index(after: separator)...])) else {
            return nil
        }
        switch String(templateID[..<separator]) {
        case "first_memory", "return_memory": return "MugsyPoseWave"
        case "second_memory", "weekly_pour", "on_this_day": return "MugsyPoseJournal"
        case "photo_memory": return "MugsyPoseCamera"
        case "repeat_memory": return "MugsyPoseCozy"
        case "home_memory": return "MugsyPoseBeans"
        default: return nil
        }
    }

    private static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let result = formatter.date(from: value) { return result }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

/// The extension and expiry callback can race. Whichever completes first owns
/// the handler. No lock is held while invoking system code.
final class MugsyNotificationCompletionGate<Content> {
    private let lock = NSLock()
    private let fallback: Content
    private var handler: ((Content) -> Void)?

    init(fallback: Content, handler: @escaping (Content) -> Void) {
        self.fallback = fallback
        self.handler = handler
    }

    @discardableResult
    func finish(_ content: Content? = nil) -> Bool {
        lock.lock()
        let completion = handler
        handler = nil
        lock.unlock()
        guard let completion else { return false }
        completion(content ?? fallback)
        return true
    }
}
