import Foundation
import UIKit

struct HomeLibrarySnapshot: Codable, Equatable {
    var bags: [CoffeeBag]
    var equipment: [EquipmentProfile]
    var recentSetups: [HomeBrewSnapshot]
    var updatedAt: Date
    var preferences: HomeLibraryPreferences? = nil

    static let empty = HomeLibrarySnapshot(
        bags: [],
        equipment: [],
        recentSetups: [],
        updatedAt: .distantPast
    )

    var currentBags: [CoffeeBag] {
        bags
            .filter { $0.status.isCurrent }
            .sorted { lhs, rhs in
                if lhs.status == .open, rhs.status != .open { return true }
                if lhs.status != .open, rhs.status == .open { return false }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    var activeEquipment: [EquipmentProfile] {
        equipment
            .filter { $0.archivedAt == nil }
            .sorted {
                if $0.role.rawValue == $1.role.rawValue {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.role.rawValue < $1.role.rawValue
            }
    }
}

/// Account-scoped, local-first storage for the Home workbench. Client-created
/// UUIDs make later remote upserts idempotent and keep offline drafts stable.
final class HomeLibraryStore {
    static let shared = HomeLibraryStore()

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let lock = NSRecursiveLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        rootDirectory = baseDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MugshotHomeLibrary", isDirectory: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid library date")
        }
        self.decoder = decoder
    }

    func load(in scope: LocalAccountScope) -> HomeLibrarySnapshot {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: metadataURL(for: scope)),
              let snapshot = try? decoder.decode(HomeLibrarySnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    @discardableResult
    func savePreferences(_ preferences: HomeLibraryPreferences, in scope: LocalAccountScope) throws -> HomeLibrarySnapshot {
        try mutate(in: scope) { $0.preferences = preferences }
    }

    @discardableResult
    func upsertHomeProfile(_ value: HomePlaceProfile, in scope: LocalAccountScope) throws -> HomeLibrarySnapshot {
        guard value.ownerUserID == nil || value.ownerUserID == scope.userID else {
            throw HomeRecipeWorkspaceError.invalid("This Home setup belongs to another account.")
        }
        if let message = value.validationMessage { throw HomeRecipeWorkspaceError.invalid(message) }
        return try mutate(in: scope) { snapshot in
            var profile = value
            profile.ownerUserID = scope.userID
            profile.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let available = Set(snapshot.activeEquipment.filter { $0.ownerUserID == scope.userID }.map(\.id))
            profile.equipmentIDs.formIntersection(available)
            var preferences = snapshot.preferences ?? HomeLibraryPreferences()
            var profiles = preferences.homeProfiles ?? []
            guard !profiles.contains(where: {
                $0.id != profile.id && $0.ownerUserID == scope.userID &&
                    $0.name.compare(profile.name, options: .caseInsensitive) == .orderedSame
            }) else {
                throw HomeRecipeWorkspaceError.invalid("Choose a different name so your setups are easy to tell apart.")
            }
            profiles.removeAll { $0.id == profile.id }; profiles.append(profile)
            preferences.homeProfiles = profiles; snapshot.preferences = preferences
        }
    }

    @discardableResult
    func removeHomeProfile(id: UUID, in scope: LocalAccountScope) throws -> HomeLibrarySnapshot {
        try mutate(in: scope) { snapshot in
            var preferences = snapshot.preferences ?? HomeLibraryPreferences()
            preferences.homeProfiles?.removeAll { $0.id == id && $0.ownerUserID == scope.userID }
            if preferences.defaultHomeProfileID == id { preferences.defaultHomeProfileID = nil }
            snapshot.preferences = preferences
        }
    }

    @discardableResult
    func upsert(_ bag: CoffeeBag, in scope: LocalAccountScope) throws -> HomeLibrarySnapshot {
        try mutate(in: scope) { snapshot in
            var bag = bag
            bag.ownerUserID = scope.userID
            bag.updatedAt = .now
            snapshot.bags.removeAll { $0.id == bag.id }
            snapshot.bags.append(bag)
        }
    }

    @discardableResult
    func upsert(
        _ equipment: EquipmentProfile,
        in scope: LocalAccountScope
    ) throws -> HomeLibrarySnapshot {
        try mutate(in: scope) { snapshot in
            var equipment = equipment
            equipment.ownerUserID = scope.userID
            equipment.updatedAt = .now
            snapshot.equipment.removeAll { $0.id == equipment.id }
            snapshot.equipment.append(equipment)
        }
    }

    @discardableResult
    func remember(
        _ setup: HomeBrewSnapshot,
        in scope: LocalAccountScope
    ) throws -> HomeLibrarySnapshot {
        try mutate(in: scope) { snapshot in
            snapshot.recentSetups.removeAll { candidate in
                candidate.id == setup.id || (
                    candidate.brewMethod.caseInsensitiveCompare(setup.brewMethod) == .orderedSame &&
                    candidate.brewDetails.coffeeBag == setup.brewDetails.coffeeBag &&
                    candidate.brewDetails.doseGrams == setup.brewDetails.doseGrams &&
                    candidate.brewDetails.yieldGrams == setup.brewDetails.yieldGrams &&
                    candidate.brewDetails.homeMethodDetails?.waterGrams == setup.brewDetails.homeMethodDetails?.waterGrams
                )
            }
            snapshot.recentSetups.insert(setup, at: 0)
            snapshot.recentSetups = Array(snapshot.recentSetups.prefix(12))
        }
    }

    /// Merges remote owner rows without deleting newer local/offline records.
    @discardableResult
    func mergeRemote(
        bags: [CoffeeBag],
        equipment: [EquipmentProfile],
        in scope: LocalAccountScope
    ) throws -> HomeLibrarySnapshot {
        try mutate(in: scope) { snapshot in
            for remoteBag in bags {
                if let index = snapshot.bags.firstIndex(where: { $0.id == remoteBag.id }) {
                    guard remoteBag.updatedAt > snapshot.bags[index].updatedAt else { continue }
                    var merged = remoteBag
                    merged.localPhotoPath = snapshot.bags[index].localPhotoPath
                    snapshot.bags[index] = merged
                } else {
                    snapshot.bags.append(remoteBag)
                }
            }
            for remoteEquipment in equipment {
                if let index = snapshot.equipment.firstIndex(where: { $0.id == remoteEquipment.id }) {
                    if remoteEquipment.updatedAt > snapshot.equipment[index].updatedAt {
                        snapshot.equipment[index] = remoteEquipment
                    }
                } else {
                    snapshot.equipment.append(remoteEquipment)
                }
            }
        }
    }

    func saveBagPhoto(
        _ image: UIImage,
        bagID: UUID,
        in scope: LocalAccountScope
    ) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        let directory = scopeDirectory(for: scope).appendingPathComponent("bag-photos", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(bagID.uuidString.lowercased()).jpg"
        let url = directory.appendingPathComponent(filename)
        let target = image.resizedForVisitUpload(maxDimension: 1_600)
        guard let data = target.jpegData(compressionQuality: 0.84) else {
            throw HomeLibraryStoreError.photoEncodingFailed
        }
        try data.write(to: url, options: .atomic)
        return "bag-photos/\(filename)"
    }

    func bagPhoto(relativePath: String?, in scope: LocalAccountScope) -> UIImage? {
        guard let relativePath = relativePath?.remoteTrimmedNonEmpty else { return nil }
        return UIImage(contentsOfFile: scopeDirectory(for: scope)
            .appendingPathComponent(relativePath).path)
    }

    func removeAll(ownerUserID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        try? fileManager.removeItem(at: scopeDirectory(for: .user(ownerUserID)))
    }

    /// Moves the signed-out coffee shelf into the newly authenticated account.
    /// The guest copy is removed only after the destination JSON and photos can
    /// be read back, matching the draft-adoption durability boundary.
    @discardableResult
    func adoptGuestLibrary(for userID: UUID) throws -> HomeLibrarySnapshot {
        lock.lock()
        defer { lock.unlock() }
        let guestScope = LocalAccountScope.guest
        let destinationScope = LocalAccountScope.user(userID)
        func readableShelf(in scope: LocalAccountScope) throws -> HomeLibrarySnapshot {
            let metadata = metadataURL(for: scope)
            guard fileManager.fileExists(atPath: metadata.path) else { return .empty }
            do { return try decoder.decode(HomeLibrarySnapshot.self, from: Data(contentsOf: metadata)) }
            catch { throw HomeLibraryStoreError.adoptionVerificationFailed }
        }
        let guest = try readableShelf(in: guestScope)
        guard !guest.bags.isEmpty || !guest.equipment.isEmpty || !guest.recentSetups.isEmpty || guest.preferences != nil else {
            return try readableShelf(in: destinationScope)
        }

        var destination = try readableShelf(in: destinationScope)
        let guestProfiles = guest.preferences?.homeProfiles ?? []
        let accountProfiles = destination.preferences?.homeProfiles ?? []
        guard (guestProfiles + accountProfiles).allSatisfy({
            ($0.ownerUserID == nil || $0.ownerUserID == userID) && $0.validationMessage == nil
        }), Set(guestProfiles.map(\.id)).count == guestProfiles.count,
            Set(accountProfiles.map(\.id)).count == accountProfiles.count else {
            throw HomeLibraryStoreError.adoptionVerificationFailed
        }
        for profiles in [accountProfiles, guestProfiles] {
            for (index, profile) in profiles.enumerated() {
                let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !profiles.prefix(index).contains(where: {
                    $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        .compare(name, options: .caseInsensitive) == .orderedSame
                }) else { throw HomeLibraryStoreError.adoptionVerificationFailed }
            }
        }
        var mergedProfiles: [HomePlaceProfile] = []
        // An interrupted adoption can leave the same identity in both scopes.
        // Keep the account version, including any later nickname or gear edits.
        for var profile in accountProfiles + guestProfiles {
            if mergedProfiles.contains(where: { $0.id == profile.id }) { continue }
            profile.ownerUserID = userID
            let originalName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.name = originalName
            var suffixNumber = 1
            // A familiar nickname on each shelf is a normal sign-in case.
            // Keep both identities while making the adopted name unambiguous.
            while mergedProfiles.contains(where: {
                $0.name.compare(profile.name, options: .caseInsensitive) == .orderedSame
            }) {
                let suffix = suffixNumber == 1 ? " (from this device)" : " (from this device \(suffixNumber))"
                profile.name = String(originalName.prefix(60 - suffix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines) + suffix
                suffixNumber += 1
            }
            guard profile.validationMessage == nil else { throw HomeLibraryStoreError.adoptionVerificationFailed }
            mergedProfiles.append(profile)
        }
        if destination.preferences != nil || guest.preferences != nil {
            var preferences = destination.preferences ?? HomeLibraryPreferences()
            if preferences.preferredMethod == nil { preferences.preferredMethod = guest.preferences?.preferredMethod }
            if preferences.defaultBagID == nil { preferences.defaultBagID = guest.preferences?.defaultBagID }
            if preferences.defaultEquipmentIDs.isEmpty {
                preferences.defaultEquipmentIDs = guest.preferences?.defaultEquipmentIDs ?? []
            }
            if preferences.defaultHomeProfileID == nil {
                preferences.defaultHomeProfileID = guest.preferences?.defaultHomeProfileID
            }
            if preferences.homeProfiles != nil || guest.preferences?.homeProfiles != nil {
                preferences.homeProfiles = mergedProfiles
            }
            destination.preferences = preferences
        }
        for var bag in guest.bags {
            bag.ownerUserID = userID
            if let relativePath = bag.localPhotoPath?.remoteTrimmedNonEmpty {
                let source = scopeDirectory(for: guestScope).appendingPathComponent(relativePath)
                let target = scopeDirectory(for: destinationScope).appendingPathComponent(relativePath)
                if let data = try? Data(contentsOf: source) {
                    try fileManager.createDirectory(
                        at: target.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try data.write(to: target, options: .atomic)
                }
            }
            if let index = destination.bags.firstIndex(where: { $0.id == bag.id }) {
                if bag.updatedAt >= destination.bags[index].updatedAt {
                    destination.bags[index] = bag
                }
            } else {
                destination.bags.append(bag)
            }
        }
        for var equipment in guest.equipment {
            equipment.ownerUserID = userID
            if let index = destination.equipment.firstIndex(where: { $0.id == equipment.id }) {
                if equipment.updatedAt >= destination.equipment[index].updatedAt {
                    destination.equipment[index] = equipment
                }
            } else {
                destination.equipment.append(equipment)
            }
        }
        let knownRecentIDs = Set(destination.recentSetups.map(\.id))
        destination.recentSetups.append(
            contentsOf: guest.recentSetups.filter { !knownRecentIDs.contains($0.id) }
        )
        destination.recentSetups.sort { $0.capturedAt > $1.capturedAt }
        destination.recentSetups = Array(destination.recentSetups.prefix(12))
        destination.updatedAt = .now

        let directory = scopeDirectory(for: destinationScope)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(destination).write(
            to: metadataURL(for: destinationScope),
            options: .atomic
        )
        guard let verifiedData = try? Data(contentsOf: metadataURL(for: destinationScope)),
              let verified = try? decoder.decode(HomeLibrarySnapshot.self, from: verifiedData),
              Set(guest.bags.map(\.id)).isSubset(of: Set(verified.bags.map(\.id))),
              Set(guest.equipment.map(\.id)).isSubset(of: Set(verified.equipment.map(\.id))),
              verified.preferences == destination.preferences,
              Set(guestProfiles.map(\.id)).isSubset(of: Set((verified.preferences?.homeProfiles ?? []).map(\.id))),
              (verified.preferences?.homeProfiles ?? []).allSatisfy({ $0.ownerUserID == userID }) else {
            throw HomeLibraryStoreError.adoptionVerificationFailed
        }
        try fileManager.removeItem(at: scopeDirectory(for: guestScope))
        return verified
    }

#if DEBUG
    func removeAllForTesting() {
        lock.lock()
        defer { lock.unlock() }
        try? fileManager.removeItem(at: rootDirectory)
    }
#endif

    private func mutate(
        in scope: LocalAccountScope,
        _ mutation: (inout HomeLibrarySnapshot) throws -> Void
    ) throws -> HomeLibrarySnapshot {
        lock.lock()
        defer { lock.unlock() }
        var snapshot: HomeLibrarySnapshot
        if let data = try? Data(contentsOf: metadataURL(for: scope)),
           let decoded = try? decoder.decode(HomeLibrarySnapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = .empty
        }
        try mutation(&snapshot)
        snapshot.updatedAt = .now
        let directory = scopeDirectory(for: scope)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(snapshot).write(to: metadataURL(for: scope), options: .atomic)
        return snapshot
    }

    private func scopeDirectory(for scope: LocalAccountScope) -> URL {
        rootDirectory.appendingPathComponent(scope.storageComponent, isDirectory: true)
    }

    private func metadataURL(for scope: LocalAccountScope) -> URL {
        scopeDirectory(for: scope).appendingPathComponent("library-v1.json")
    }

}

enum HomeLibraryStoreError: LocalizedError {
    case photoEncodingFailed
    case adoptionVerificationFailed

    var errorDescription: String? {
        switch self {
        case .photoEncodingFailed:
            return "Mugshot couldn’t prepare that bag photo. Try another image."
        case .adoptionVerificationFailed:
            return "Mugshot couldn’t verify the account copy of your coffee shelf. The signed-out copy is still safe on this device."
        }
    }
}
