import Combine
import Foundation
import UIKit

@MainActor
protocol HomeLibrarySyncTransport {
    func fetch(userID: UUID) async throws -> RemoteHomeLibrary
    func upsert(_ bag: CoffeeBag, userID: UUID) async throws -> CoffeeBag
    func upsert(_ equipment: EquipmentProfile, userID: UUID) async throws -> EquipmentProfile
    func uploadBagPhoto(_ image: UIImage, bagID: UUID, userID: UUID) async throws -> String
}

extension HomeLibraryService: HomeLibrarySyncTransport {}

/// One writer per account. Offline edits stay durable and a later sync retries the latest shelf.
@MainActor
final class HomeLibrarySynchronizer: ObservableObject {
    static let shared = HomeLibrarySynchronizer()
    @Published private(set) var messages: [UUID: String] = [:]
    private var tasks: [UUID: Task<Bool, Never>] = [:]
    private var taskIDs: [UUID: UUID] = [:]
    private var requestedAgain: Set<UUID> = []
    private let store: HomeLibraryStore
    private let transport: (UUID) async throws -> any HomeLibrarySyncTransport

    init(store: HomeLibraryStore = .shared,
         transport: @escaping (UUID) async throws -> any HomeLibrarySyncTransport = { owner in
             HomeLibraryService(client: try await SupabaseClientProvider.shared.publicationClient(userID: owner))
         }) {
        self.store = store
        self.transport = transport
    }

    func invalidate(ownerID: UUID) {
        tasks[ownerID]?.cancel()
        tasks[ownerID] = nil
        taskIDs[ownerID] = nil
        requestedAgain.remove(ownerID)
        messages[ownerID] = nil
    }

    @discardableResult
    func synchronize(scope: LocalAccountScope, currentOwner: @escaping () -> UUID?) async -> Bool {
        guard let owner = scope.userID, currentOwner() == owner else { return scope == .guest }
        if let task = tasks[owner] {
            requestedAgain.insert(owner)
            return await task.value
        }
        let operation = UUID()
        taskIDs[owner] = operation
        let task = Task { @MainActor in
            do {
                repeat {
                    requestedAgain.remove(owner)
                    try Task.checkCancellation()
                    guard currentOwner() == owner else { return false }
                    let remote = try await transport(owner)
                    let beforeFetch = store.load(in: scope)
                    let fetched = try await remote.fetch(userID: owner)
                    guard currentOwner() == owner, !Task.isCancelled else { return false }
                    let latest = store.load(in: scope)
                    let editedBags = Set(latest.bags.filter { item in beforeFetch.bags.first(where: { $0.id == item.id }) != item }.map(\.id))
                    let editedGear = Set(latest.equipment.filter { item in beforeFetch.equipment.first(where: { $0.id == item.id }) != item }.map(\.id))
                    _ = try store.mergeRemote(
                        bags: fetched.bags.filter { $0.ownerUserID == owner && !editedBags.contains($0.id) },
                        equipment: fetched.equipment.filter { $0.ownerUserID == owner && !editedGear.contains($0.id) }, in: scope
                    )
                    let remoteBags = Dictionary(fetched.bags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                    let remoteGear = Dictionary(fetched.equipment.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                    for var bag in store.load(in: scope).bags where bag.ownerUserID == owner {
                        guard currentOwner() == owner, !Task.isCancelled else { return false }
                        guard remoteBags[bag.id].map({ !Self.sameContent($0, bag) }) ?? true else { continue }
                        let original = bag
                        if bag.privatePhotoPath == nil, let image = store.bagPhoto(relativePath: bag.localPhotoPath, in: scope) {
                            bag.privatePhotoPath = try await remote.uploadBagPhoto(image, bagID: bag.id, userID: owner)
                        }
                        guard currentOwner() == owner, !Task.isCancelled else { return false }
                        var saved = try await remote.upsert(bag, userID: owner)
                        guard currentOwner() == owner, !Task.isCancelled else { return false }
                        if let latest = store.load(in: scope).bags.first(where: { $0.id == bag.id }), latest == original {
                            saved.localPhotoPath = latest.localPhotoPath
                            _ = try store.upsert(saved, in: scope)
                        } else { requestedAgain.insert(owner) }
                    }
                    for gear in store.load(in: scope).equipment where gear.ownerUserID == owner {
                        guard currentOwner() == owner, !Task.isCancelled else { return false }
                        guard remoteGear[gear.id].map({ !Self.sameContent($0, gear) }) ?? true else { continue }
                        let saved = try await remote.upsert(gear, userID: owner)
                        guard currentOwner() == owner, !Task.isCancelled else { return false }
                        if let latest = store.load(in: scope).equipment.first(where: { $0.id == gear.id }), latest == gear {
                            _ = try store.upsert(saved, in: scope)
                        } else { requestedAgain.insert(owner) }
                    }
                } while requestedAgain.contains(owner)
                messages[owner] = nil
                return true
            } catch {
                if currentOwner() == owner, !Task.isCancelled {
                    messages[owner] = "Saved on this device. Try syncing again when you’re online."
                }
                return false
            }
        }
        tasks[owner] = task
        let success = await task.value
        if taskIDs[owner] == operation {
            tasks[owner] = nil
            taskIDs[owner] = nil
            requestedAgain.remove(owner)
        }
        return success
    }

    private static func sameContent(_ lhs: CoffeeBag, _ rhs: CoffeeBag) -> Bool {
        var copy = lhs
        copy.createdAt = rhs.createdAt; copy.updatedAt = rhs.updatedAt
        copy.localPhotoPath = rhs.localPhotoPath
        return copy == rhs
    }
    private static func sameContent(_ lhs: EquipmentProfile, _ rhs: EquipmentProfile) -> Bool {
        var copy = lhs
        copy.createdAt = rhs.createdAt; copy.updatedAt = rhs.updatedAt
        return copy == rhs
    }
}
