import Combine
import Foundation

/// A local, versioned choice. Permission is never adopted from a guest or another account.
@MainActor
final class CoffeeAssistancePermissionStore: ObservableObject {
    static let shared = CoffeeAssistancePermissionStore()
    @Published private(set) var revision = 0
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func isEnabled(ownerID: UUID?) -> Bool {
        guard let ownerID else { return false }
        return defaults.bool(forKey: key(ownerID))
    }

    func setEnabled(_ enabled: Bool, ownerID: UUID) {
        defaults.set(enabled, forKey: key(ownerID))
        if !enabled { CoffeeAssistanceCache.shared.clear() }
        revision += 1
    }

    func removeAll(ownerID: UUID) {
        defaults.removeObject(forKey: key(ownerID))
        CoffeeAssistanceCache.shared.clear()
        revision += 1
    }

    private func key(_ ownerID: UUID) -> String {
        // The persisted key predates the Mugsy branding and holds the owner's existing choice.
        "Mugshot.Luna.selected-tools.v1.\(ownerID.uuidString.lowercased())"
    }
}
