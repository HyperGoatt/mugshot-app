import Foundation

/// Edit retries use stable photo IDs and keep acknowledged objects until a
/// canonical edit commits. This is separate from the new-visit outbox: an edit
/// receipt must never make a published visit eligible for creation/recovery.
final class VisitEditMediaProgressStore {
    static let shared = VisitEditMediaProgressStore()
    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func completedPaths(userID: UUID, visitID: UUID, plannedPaths: [String]) -> [String] {
        let completed = Set(allPaths(userID: userID, visitID: visitID))
        return plannedPaths.filter { completed.contains($0) }
    }

    func allPaths(userID: UUID, visitID: UUID) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return (defaults.stringArray(forKey: key(userID, visitID)) ?? []).filter { path in
            (try? VisitPhotoUploadPlan.validate(
                userID: userID, visitID: visitID, imageCount: 1,
                paths: [path], completedPaths: []
            )) != nil
        }
    }

    func record(_ path: String, userID: UUID, visitID: UUID, plannedPaths: [String]) throws {
        lock.lock()
        defer { lock.unlock() }
        try VisitPhotoUploadPlan.validate(
            userID: userID, visitID: visitID, imageCount: plannedPaths.count,
            paths: plannedPaths, completedPaths: [path]
        )
        let updated = Array(Set(allPaths(userID: userID, visitID: visitID) + [path])).sorted()
        defaults.set(updated, forKey: key(userID, visitID))
        guard allPaths(userID: userID, visitID: visitID) == updated else {
            throw PendingVisitSubmissionStoreError.outboxUnreadable
        }
    }

    func remove(userID: UUID, visitID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key(userID, visitID))
    }

    func removeAll(userID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        let prefix = "MugshotEditMedia.v1.\(userID.uuidString.lowercased())."
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func key(_ userID: UUID, _ visitID: UUID) -> String {
        "MugshotEditMedia.v1.\(userID.uuidString.lowercased()).\(visitID.uuidString.lowercased())"
    }
}
