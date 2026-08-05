import Foundation

enum SavedCafeCategory: String, CaseIterable, Identifiable {
    case favorites = "Favorites"
    case wantToTry = "Want to Try"
    case all = "All Cafes"

    var id: String { rawValue }
}

enum SavedCafeSort: String, CaseIterable, Identifiable {
    case recentActivity = "Recent activity"
    case highestRated = "Highest rated"
    case name = "Cafe name"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .recentActivity: "arrow.up.arrow.down"
        case .highestRated: "star.fill"
        case .name: "textformat.abc"
        }
    }
}

enum SavedCafeDensity: String, CaseIterable, Identifiable {
    case cards = "Cards"
    case compact = "Compact"

    var id: String { rawValue }
    var systemImage: String { self == .cards ? "line.3.horizontal.decrease" : "list.bullet" }
}

struct SavedCafeLibraryQuery: Equatable {
    var category: SavedCafeCategory = .favorites
    var searchText = ""
    var sort: SavedCafeSort = .recentActivity
    var requiresVisit = false
    var requiresDirections = false
}

enum SavedCafeLibraryProjector {
    static func project(
        cafes: [Cafe],
        visits: [Visit],
        query: SavedCafeLibraryQuery
    ) -> [Cafe] {
        let visitsByCafeID = Dictionary(grouping: visits.filter { $0.context == .cafe }, by: \.cafeId)
        let normalizedQuery = normalized(query.searchText)

        let filtered = cafes.filter { cafe in
            switch query.category {
            case .favorites where !cafe.isFavorite:
                return false
            case .wantToTry where !cafe.wantToTry:
                return false
            case .favorites, .wantToTry, .all:
                break
            }

            if query.requiresVisit, visitsByCafeID[cafe.id, default: []].isEmpty, cafe.visitCount == 0 {
                return false
            }
            if query.requiresDirections, cafe.location == nil {
                return false
            }
            guard !normalizedQuery.isEmpty else { return true }
            return normalized([
                cafe.consumerDisplayName,
                cafe.address,
                cafe.consumerPlaceCategory ?? ""
            ].joined(separator: " ")).contains(normalizedQuery)
        }

        return filtered.sorted { lhs, rhs in
            switch query.sort {
            case .recentActivity:
                let lhsDate = visitsByCafeID[lhs.id]?.map(\.createdAt).max() ?? .distantPast
                let rhsDate = visitsByCafeID[rhs.id]?.map(\.createdAt).max() ?? .distantPast
                if lhsDate == rhsDate {
                    if lhs.visitCount == rhs.visitCount {
                        return lhs.consumerDisplayName.localizedCaseInsensitiveCompare(rhs.consumerDisplayName) == .orderedAscending
                    }
                    return lhs.visitCount > rhs.visitCount
                }
                return lhsDate > rhsDate
            case .highestRated:
                if lhs.averageRating == rhs.averageRating {
                    return lhs.consumerDisplayName.localizedCaseInsensitiveCompare(rhs.consumerDisplayName) == .orderedAscending
                }
                return lhs.averageRating > rhs.averageRating
            case .name:
                return lhs.consumerDisplayName.localizedCaseInsensitiveCompare(rhs.consumerDisplayName) == .orderedAscending
            }
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
