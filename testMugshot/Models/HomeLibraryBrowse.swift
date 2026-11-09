import Foundation

enum HomeRecipeShelfSort: String, CaseIterable, Identifiable {
    case recentlyUsed = "Recently used"
    case newest = "Newest"
    case name = "A–Z"

    var id: String { rawValue }
}

enum HomeBagShelfSort: String, CaseIterable, Identifiable {
    case roastDate = "Newest roast"
    case name = "Name A–Z"

    var id: String { rawValue }
}

enum HomeLibraryBrowse {
    static func recipes(
        _ records: [HomeRecipeRecord], archived: Bool = false, query: String = "",
        use: HomeRecipeUse? = nil, method: HomeBrewMethod? = nil, sort: HomeRecipeShelfSort = .recentlyUsed
    ) -> [HomeRecipeRecord] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = records.filter { record in
            guard record.isArchived == archived, let content = record.current?.content else { return false }
            return (search.isEmpty || content.name.localizedCaseInsensitiveContains(search))
                && (use == nil || HomeRecipeUse.suggested(for: content) == use)
                && (method == nil || content.method == method)
        }
        return matches.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if sort == .recentlyUsed {
                let lhsUse = lhs.lastUsedAt ?? .distantPast
                let rhsUse = rhs.lastUsedAt ?? .distantPast
                if lhsUse != rhsUse { return lhsUse > rhsUse }
            }
            if sort != .name {
                let lhsCreated = lhs.versions.first?.createdAt ?? .distantPast
                let rhsCreated = rhs.versions.first?.createdAt ?? .distantPast
                if lhsCreated != rhsCreated { return lhsCreated > rhsCreated }
            }
            return nameBefore(lhs.current?.content.name ?? "", id: lhs.id,
                rhs.current?.content.name ?? "", id: rhs.id)
        }
    }

    static func bags(
        _ records: [CoffeeBag], ownerID: UUID?, showsArchived: Bool = false,
        status: CoffeeBagStatus? = nil, sort: HomeBagShelfSort = .roastDate
    ) -> [CoffeeBag] {
        records.filter { bag in
            bag.ownerUserID == ownerID && (showsArchived || bag.status.isCurrent)
                && (status == nil || bag.status == status)
        }.sorted { lhs, rhs in
            if sort == .roastDate {
                switch (lhs.roastDate, rhs.roastDate) {
                case let (.some(left), .some(right)) where left != right: return left > right
                case (.some, .none): return true
                case (.none, .some): return false
                default: break
                }
            }
            return nameBefore(lhs.displayName, id: lhs.id, rhs.displayName, id: rhs.id)
        }
    }

    static func gear(
        _ records: [EquipmentProfile], ownerID: UUID?, showsArchived: Bool = false,
        role: EquipmentRole? = nil, setup: HomePlaceProfile? = nil
    ) -> [EquipmentProfile] {
        if let setup, setup.ownerUserID != ownerID { return [] }
        return records.filter { item in
            item.ownerUserID == ownerID && (showsArchived || item.archivedAt == nil)
                && (role == nil || item.role == role)
                && (setup?.equipmentIDs.contains(item.id) ?? true)
        }.sorted { lhs, rhs in
            if lhs.role != rhs.role { return lhs.role.rawValue < rhs.role.rawValue }
            return nameBefore(lhs.displayName, id: lhs.id, rhs.displayName, id: rhs.id)
        }
    }

    static func roastDateLabel(_ bag: CoffeeBag) -> String {
        guard let date = bag.roastDate else { return "Roast date unknown" }
        return "Roasted \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private static func nameBefore(_ lhs: String, id lhsID: UUID, _ rhs: String, id rhsID: UUID) -> Bool {
        let order = lhs.localizedCaseInsensitiveCompare(rhs)
        return order == .orderedSame ? lhsID.uuidString < rhsID.uuidString : order == .orderedAscending
    }
}
