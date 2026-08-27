import Foundation

/// Remembers only the user's reusable criterion choices. Scores remain tied
/// to a visit; importance preferences are owned separately below.
final class PinnedCriterionStore {
    static let shared = PinnedCriterionStore()

    private struct Record: Codable, Equatable {
        let scope: String
        let name: String
    }

    private let defaults: UserDefaults
    private let key = "Mugshot.PinnedCriteria.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func applyPins(to criteria: inout [SipRatingCriterionSnapshot], scope: String) {
        let pinned = records
            .filter { $0.scope == normalized(scope) }
            .map(\.name)
        let names = Set(pinned)
        for index in criteria.indices {
            criteria[index].isPinned = names.contains(normalized(criteria[index].name))
        }
        for pinnedName in pinned where !criteria.contains(where: {
            normalized($0.name) == pinnedName
        }) {
            criteria.append(SipRatingCriterionSnapshot(
                name: pinnedName.capitalized,
                score: 0,
                weight: 1,
                sortOrder: criteria.count,
                isPinned: true
            ))
        }
    }

    func synchronize(_ criteria: [SipRatingCriterionSnapshot], scope: String) {
        let resolvedScope = normalized(scope)
        var retained = records.filter { $0.scope != resolvedScope }
        retained.append(contentsOf: criteria.compactMap { criterion in
            guard criterion.isPinned == true,
                  let name = criterion.name.remoteTrimmedNonEmpty else { return nil }
            return Record(scope: resolvedScope, name: normalized(name))
        })
        save(Array(Set(retained.map { "\($0.scope)|\($0.name)" })).compactMap { value in
            let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return Record(scope: parts[0], name: parts[1])
        })
    }

    func pinnedNames(scope: String) -> [String] {
        records
            .filter { $0.scope == normalized(scope) }
            .map(\.name)
            .sorted()
    }

    func removeAll(ownerUserID: UUID) {
        let prefix = ownerUserID.uuidString.lowercased() + "."
        save(records.filter { !$0.scope.hasPrefix(prefix) })
    }

#if DEBUG
    func removeAllForTesting() {
        defaults.removeObject(forKey: key)
    }
#endif

    private var records: [Record] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Record].self, from: data) else {
            return []
        }
        return decoded
    }

    private func save(_ records: [Record]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Keeps a person's preferred importance for each criterion without carrying
/// a visit's rating forward. Preferences are account- and criterion-scope-bound.
final class CriterionImportanceStore {
    static let shared = CriterionImportanceStore()

    private struct Record: Codable, Equatable {
        let scope: String
        let name: String
        let weight: Double
    }

    private let defaults: UserDefaults
    private let key = "Mugshot.CriterionImportance.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func apply(to criteria: inout [SipRatingCriterionSnapshot], scope: String) {
        let resolvedScope = normalized(scope)
        var preferredWeights: [String: Double] = [:]
        for record in records where record.scope == resolvedScope {
            preferredWeights[record.name] = record.weight
        }
        for index in criteria.indices {
            let name = normalized(criteria[index].name)
            guard let weight = preferredWeights[name] else { continue }
            criteria[index].weight = SipCriterionImportance(weight: weight).weight
        }
    }

    func synchronize(_ criteria: [SipRatingCriterionSnapshot], scope: String) {
        let resolvedScope = normalized(scope)
        var updated = records.filter { $0.scope != resolvedScope }
        updated.append(contentsOf: criteria.compactMap { criterion in
            guard let name = criterion.name.remoteTrimmedNonEmpty else { return nil }
            return Record(
                scope: resolvedScope,
                name: normalized(name),
                weight: criterion.importance.weight
            )
        })
        save(updated)
    }

    func removeAll(ownerUserID: UUID) {
        let prefix = ownerUserID.uuidString.lowercased() + "."
        save(records.filter { !$0.scope.hasPrefix(prefix) })
    }

#if DEBUG
    func removeAllForTesting() {
        defaults.removeObject(forKey: key)
    }
#endif

    private var records: [Record] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Record].self, from: data) else {
            return []
        }
        return decoded
    }

    private func save(_ records: [Record]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Remembers the names from the most recently published setup. Ratings remain
/// blank; the separate importance store reapplies personal preferences.
final class RecentCriterionSetupStore {
    static let shared = RecentCriterionSetupStore()

    private struct Record: Codable, Equatable {
        let scope: String
        let names: [String]
    }

    private let defaults: UserDefaults
    private let key = "Mugshot.RecentCriterionSetup.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func remember(_ criteria: [SipRatingCriterionSnapshot], scope: String) {
        let resolvedScope = normalized(scope)
        var seen = Set<String>()
        let names = criteria
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { criterion -> String? in
                guard let name = criterion.name.remoteTrimmedNonEmpty else { return nil }
                let key = normalized(name)
                guard seen.insert(key).inserted else { return nil }
                return name
            }
        var updated = records.filter { $0.scope != resolvedScope }
        if !names.isEmpty {
            updated.append(Record(scope: resolvedScope, names: Array(names.prefix(40))))
        }
        save(updated)
    }

    func names(scope: String) -> [String] {
        records.first { $0.scope == normalized(scope) }?.names ?? []
    }

    func apply(to criteria: inout [SipRatingCriterionSnapshot], scope: String) {
        for name in names(scope: scope) where !criteria.contains(where: {
            normalized($0.name) == normalized(name)
        }) {
            criteria.append(SipRatingCriterionSnapshot(
                name: name,
                score: 0,
                weight: 1,
                sortOrder: criteria.count,
                isPinned: false
            ))
        }
    }

    func removeAll(ownerUserID: UUID) {
        let prefix = ownerUserID.uuidString.lowercased() + "."
        save(records.filter { !$0.scope.hasPrefix(prefix) })
    }

#if DEBUG
    func removeAllForTesting() {
        defaults.removeObject(forKey: key)
    }
#endif

    private var records: [Record] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Record].self, from: data) else {
            return []
        }
        return decoded
    }

    private func save(_ records: [Record]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
