import Foundation

/// Account-local nicknames and gear selections. No address or coordinates.
/// Sips keep the selected display name, independent of later profile edits.
struct HomePlaceProfile: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var ownerUserID: UUID?
    var name: String
    var equipmentIDs: Set<UUID> = []

    var validationMessage: String? {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "Give this Home setup a name." }
        if value.compare("Home", options: .caseInsensitive) == .orderedSame {
            return "Give this setup its own name, like My kitchen."
        }
        if value.count > 60 || value.rangeOfCharacter(from: .controlCharacters) != nil {
            return "Use a name of 60 characters or fewer, on one line."
        }
        return nil
    }
}

extension HomeLibrarySnapshot {
    func selectedHomeProfile(for owner: UUID?, id: UUID? = nil) -> HomePlaceProfile? {
        guard let selected = id ?? preferences?.defaultHomeProfileID else { return nil }
        return preferences?.homeProfiles?.first { $0.id == selected && $0.ownerUserID == owner }
    }
}
