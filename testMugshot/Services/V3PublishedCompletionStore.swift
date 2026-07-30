import Foundation

/// Short-lived durable handoff for the post-publish Taste Passport.
///
/// The completed draft remains in `SipDraftStore` until the user leaves the
/// Passport. This marker distinguishes that published memory from an editable
/// draft and lets a force quit restore the completion surface without offering
/// to publish the same visit twice.
struct V3PublishedCompletionRecord: Codable, Equatable {
    let ownerUserID: UUID?
    let visitID: UUID
    let isRemote: Bool
    let updatedAt: Date
}

final class V3PublishedCompletionStore {
    static let shared = V3PublishedCompletionStore()

    private let defaults: UserDefaults
    private let expirationInterval: TimeInterval
    private let keyPrefix = "MugshotV3PublishedCompletion.v1."

    init(
        defaults: UserDefaults = .standard,
        expirationInterval: TimeInterval = 24 * 60 * 60
    ) {
        self.defaults = defaults
        self.expirationInterval = expirationInterval
    }

    func save(_ record: V3PublishedCompletionRecord) throws {
        defaults.set(
            try JSONEncoder().encode(record),
            forKey: storageKey(record.ownerUserID)
        )
    }

    func load(
        ownerUserID: UUID?,
        now: Date = .now,
        onExpired: ((V3PublishedCompletionRecord) -> Void)? = nil
    ) -> V3PublishedCompletionRecord? {
        let key = storageKey(ownerUserID)
        guard let data = defaults.data(forKey: key),
              let record = try? JSONDecoder().decode(
                V3PublishedCompletionRecord.self,
                from: data
              ) else {
            return nil
        }
        guard now.timeIntervalSince(record.updatedAt) <= expirationInterval else {
            defaults.removeObject(forKey: key)
            onExpired?(record)
            return nil
        }
        return record
    }

    func remove(ownerUserID: UUID?) {
        defaults.removeObject(forKey: storageKey(ownerUserID))
    }

#if DEBUG
    func removeAllForTesting() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
#endif

    private func storageKey(_ ownerUserID: UUID?) -> String {
        keyPrefix + (ownerUserID?.uuidString.lowercased() ?? "anonymous")
    }
}
