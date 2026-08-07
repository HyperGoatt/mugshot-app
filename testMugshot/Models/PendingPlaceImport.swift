import CoreLocation
import Foundation

enum MugshotAppGroup {
    static let identifier = "group.co.mugshot.app.discovery"
    static let pendingImportsKey = "MugshotDiscovery.pendingImports.v1"
    static let eligibleListsKey = "MugshotDiscovery.eligibleLists.v1"
}

enum PlaceImportSource: String, Codable, CaseIterable {
    case googleMaps = "google_maps"
    case appleMaps = "apple_maps"
    case tiktok
    case instagram
    case generalURL = "general_url"
    case text
}

enum PendingPlaceImportRetryState: String, Codable {
    case queued
    case syncing
    case needsDestinationRecovery = "needs_destination_recovery"
}

struct PendingPlaceImport: Identifiable, Codable, Equatable {
    let commandID: UUID
    let appleMapsPlaceID: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let phoneNumber: String?
    let websiteURL: String?
    let source: PlaceImportSource
    var wantToTry: Bool
    var destinationListID: UUID?
    var destinationListTitle: String?
    var note: String?
    let accountContext: UUID?
    var retryState: PendingPlaceImportRetryState
    let createdAt: Date

    var id: UUID { commandID }

    var cafe: Cafe {
        Cafe(
            name: name,
            location: .init(latitude: latitude, longitude: longitude),
            address: address ?? "",
            wantToTry: wantToTry,
            appleMapsPlaceID: appleMapsPlaceID,
            websiteURL: websiteURL,
            discoveryNote: note,
            discoverySource: .shareImport,
            discoveredAt: createdAt
        )
    }
}

struct ShareExtensionCafeListCacheEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let accountID: UUID
    let canEdit: Bool
}

actor PendingPlaceImportQueue {
    static let shared = PendingPlaceImportQueue(
        defaults: UserDefaults(suiteName: MugshotAppGroup.identifier) ?? .standard
    )

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func imports() -> [PendingPlaceImport] {
        guard let data = defaults.data(forKey: MugshotAppGroup.pendingImportsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingPlaceImport].self, from: data)) ?? []
    }

    func append(_ command: PendingPlaceImport) {
        var commands = imports()
        guard !commands.contains(where: { $0.commandID == command.commandID }) else { return }
        commands.append(command)
        store(commands)
    }

    func remove(_ commandID: UUID) {
        store(imports().filter { $0.commandID != commandID })
    }

    func update(_ command: PendingPlaceImport) {
        var commands = imports()
        guard let index = commands.firstIndex(where: { $0.commandID == command.commandID }) else {
            append(command)
            return
        }
        commands[index] = command
        store(commands)
    }

    func cacheEligibleLists(_ lists: [ShareExtensionCafeListCacheEntry]) {
        guard let data = try? JSONEncoder().encode(lists) else { return }
        defaults.set(data, forKey: MugshotAppGroup.eligibleListsKey)
    }

    func eligibleLists(accountID: UUID?) -> [ShareExtensionCafeListCacheEntry] {
        guard let accountID,
              let data = defaults.data(forKey: MugshotAppGroup.eligibleListsKey),
              let lists = try? JSONDecoder().decode(
                [ShareExtensionCafeListCacheEntry].self,
                from: data
              ) else { return [] }
        return lists.filter { $0.accountID == accountID && $0.canEdit }
    }

    private func store(_ commands: [PendingPlaceImport]) {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        defaults.set(data, forKey: MugshotAppGroup.pendingImportsKey)
    }
}
