import Foundation

enum TastingLensPreferencesStoreError: Error, LocalizedError {
    case accountScopeMismatch

    var errorDescription: String? {
        switch self {
        case .accountScopeMismatch:
            return "Tasting Lens preferences cannot be saved into another account's local scope."
        }
    }
}

final class TastingLensPreferencesStore {
    private static let keyPrefix = "MugshotTastingLensPreferences.v1."

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func load(userID: UUID) -> TastingLensUserPreferences {
        guard let data = defaults.data(forKey: key(for: userID)),
              let decoded = try? decoder.decode(TastingLensUserPreferences.self, from: data),
              decoded.userID == userID else {
            return TastingLensUserPreferences(userID: userID)
        }
        return decoded
    }

    func save(_ preferences: TastingLensUserPreferences, for userID: UUID) throws {
        guard preferences.userID == userID else {
            throw TastingLensPreferencesStoreError.accountScopeMismatch
        }
        defaults.set(try encoder.encode(preferences), forKey: key(for: userID))
    }

    @discardableResult
    func setPinned(
        _ isPinned: Bool,
        criterionID: String,
        scopeID: String,
        userID: UUID,
        now: Date = .now
    ) throws -> TastingLensUserPreferences {
        var preferences = load(userID: userID)
        var pinned = preferences.pinnedCriterionIDsByScope[scopeID] ?? []
        if isPinned {
            if !pinned.contains(criterionID) { pinned.append(criterionID) }
        } else {
            pinned.removeAll { $0 == criterionID }
        }
        preferences.pinnedCriterionIDsByScope[scopeID] = pinned
        preferences.updatedAt = now
        try save(preferences, for: userID)
        return preferences
    }

    @discardableResult
    func recordDismissal(
        targetID: String,
        scopeID: String,
        snapshotID: UUID? = nil,
        reason: SensorySuggestionDismissalReason,
        userID: UUID,
        now: Date = .now
    ) throws -> TastingLensUserPreferences {
        var preferences = load(userID: userID)
        preferences.dismissals.removeAll {
            $0.targetID == targetID &&
                $0.scopeID == scopeID &&
                $0.snapshotID == snapshotID &&
                $0.reason == reason
        }
        preferences.dismissals.append(SensorySuggestionDismissal(
            targetID: targetID,
            scopeID: scopeID,
            snapshotID: snapshotID,
            reason: reason,
            createdAt: now
        ))
        preferences.updatedAt = now
        try save(preferences, for: userID)
        return preferences
    }

    @discardableResult
    func removeDismissal(
        id: UUID,
        userID: UUID,
        now: Date = .now
    ) throws -> TastingLensUserPreferences {
        var preferences = load(userID: userID)
        preferences.dismissals.removeAll { $0.id == id }
        preferences.updatedAt = now
        try save(preferences, for: userID)
        return preferences
    }

    func removeAll(userID: UUID) {
        defaults.removeObject(forKey: key(for: userID))
    }

    private func key(for userID: UUID) -> String {
        Self.keyPrefix + userID.uuidString.lowercased()
    }
}
