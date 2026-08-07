import Foundation

enum ExtensionAppGroup {
    static let identifier = "group.co.mugshot.app.discovery"
    static let pendingImportsKey = "MugshotDiscovery.pendingImports.v1"
    static let eligibleListsKey = "MugshotDiscovery.eligibleLists.v1"
}

enum ExtensionPlaceImportSource: String, Codable {
    case googleMaps = "google_maps"
    case appleMaps = "apple_maps"
    case tiktok
    case instagram
    case generalURL = "general_url"
    case text
}

struct ExtensionPendingPlaceImport: Codable {
    let commandID: UUID
    let appleMapsPlaceID: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let phoneNumber: String?
    let websiteURL: String?
    let source: ExtensionPlaceImportSource
    let wantToTry: Bool
    let destinationListID: UUID?
    let destinationListTitle: String?
    let note: String?
    let accountContext: UUID?
    let retryState: String
    let createdAt: Date
}

struct ExtensionCafeListCacheEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let accountID: UUID
    let canEdit: Bool
}

enum ExtensionImportStore {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: ExtensionAppGroup.identifier) ?? .standard
    }

    static func eligibleLists() -> [ExtensionCafeListCacheEntry] {
        guard let data = defaults.data(forKey: ExtensionAppGroup.eligibleListsKey),
              let lists = try? JSONDecoder().decode([ExtensionCafeListCacheEntry].self, from: data) else {
            return []
        }
        return lists.filter(\.canEdit)
    }

    static func append(_ command: ExtensionPendingPlaceImport) throws {
        let decoder = JSONDecoder()
        var commands: [ExtensionPendingPlaceImport] = []
        if let data = defaults.data(forKey: ExtensionAppGroup.pendingImportsKey) {
            commands = (try? decoder.decode([ExtensionPendingPlaceImport].self, from: data)) ?? []
        }
        guard !commands.contains(where: { $0.commandID == command.commandID }) else { return }
        commands.append(command)
        defaults.set(try JSONEncoder().encode(commands), forKey: ExtensionAppGroup.pendingImportsKey)
    }
}
