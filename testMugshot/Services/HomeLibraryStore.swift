import Foundation
import UIKit

struct HomeLibrarySnapshot: Codable, Equatable {
    var bags: [CoffeeBag]
    var equipment: [EquipmentProfile]
    var recentSetups: [HomeBrewSnapshot]
    var updatedAt: Date

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
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
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
        let guest = load(in: guestScope)
        guard !guest.bags.isEmpty || !guest.equipment.isEmpty || !guest.recentSetups.isEmpty else {
            return load(in: destinationScope)
        }

        var destination = load(in: destinationScope)
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
              Set(guest.equipment.map(\.id)).isSubset(of: Set(verified.equipment.map(\.id))) else {
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
        _ mutation: (inout HomeLibrarySnapshot) -> Void
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
        mutation(&snapshot)
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
