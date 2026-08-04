import Foundation

enum JournalReflectionPeriod: String, CaseIterable, Identifiable, Hashable {
    case month
    case year

    var id: String { rawValue }
    var title: String { self == .month ? "This month" : "This year" }
}

struct JournalCaffeineEstimate: Equatable {
    let totalMilligrams: Double
    let coveredEntries: Int
    let totalEntries: Int
    let referenceVersions: [String]
    let parserVersions: [String]

    var roundedTotal: Int { Int(totalMilligrams.rounded()) }
    var coverageText: String { "Based on \(coveredEntries) of \(totalEntries) sips" }
}

struct JournalPeopleCount: Decodable, Identifiable, Equatable {
    let accountID: UUID
    let displayName: String?
    let username: String
    let avatarURL: String?
    let sipCount: Int
    let latestSharedSipAt: String

    var id: UUID { accountID }
    var personLabel: String {
        displayName?.remoteTrimmedNonEmpty ?? "@\(username)"
    }

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case displayName = "display_name"
        case username
        case avatarURL = "avatar_url"
        case sipCount = "sip_count"
        case latestSharedSipAt = "latest_shared_sip_at"
    }
}

struct JournalReflectionSummary: Identifiable, Equatable {
    let period: JournalReflectionPeriod
    let startDate: Date
    let endDate: Date
    let entryCount: Int
    let cafeCount: Int
    let homeExperimentCount: Int
    let recipeCount: Int
    let favoriteDrink: String?
    let favoriteCafe: String?
    let neighborhoods: [String]
    let meaningfulMemoryCount: Int
    let photoCount: Int
    let averageRating: Double?
    let ratingChange: Double?
    let caffeine: JournalCaffeineEstimate?
    let people: [JournalPeopleCount]

    var id: String { "\(period.rawValue)-\(startDate.timeIntervalSince1970)" }

    var headline: String {
        guard entryCount > 0 else { return "A fresh page for your coffee memories" }
        if let favoriteDrink { return "\(favoriteDrink) shaped \(period == .month ? "your month" : "your year")" }
        return "\(entryCount) sips worth remembering"
    }
}

struct JournalMilestone: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}

enum JournalReflectionEngine {
    static func summary(
        for period: JournalReflectionPeriod,
        entries: [JournalEntryProjection],
        people: [JournalPeopleCount] = [],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> JournalReflectionSummary {
        let interval = dateInterval(for: period, containing: referenceDate, calendar: calendar)
        let previousReference = calendar.date(byAdding: period == .month ? .month : .year, value: -1, to: referenceDate) ?? referenceDate
        let previousInterval = dateInterval(for: period, containing: previousReference, calendar: calendar)
        let current = entries.filter { interval.contains($0.date) }
        let previous = entries.filter { previousInterval.contains($0.date) }

        let cafeEntries = current.filter { $0.context == .cafe }
        let homeEntries = current.filter { $0.context == .home }
        let recipes = current.filter { $0.context == .recipe }
        let average = averageRating(current)
        let previousAverage = averageRating(previous)
        let caffeineRows = current.compactMap(\.drinkAnalysis)
        let covered = caffeineRows.filter(\.isCoveredEstimate)
        let caffeine: JournalCaffeineEstimate? = covered.isEmpty ? nil : JournalCaffeineEstimate(
            totalMilligrams: covered.compactMap(\.estimatedCaffeineMilligrams).reduce(0, +),
            coveredEntries: covered.count,
            totalEntries: current.count,
            referenceVersions: Array(Set(covered.map(\.caffeineReferenceVersion))).sorted(),
            parserVersions: Array(Set(covered.map(\.parserVersion))).sorted()
        )

        return JournalReflectionSummary(
            period: period,
            startDate: interval.start,
            endDate: interval.end,
            entryCount: current.count,
            cafeCount: Set(cafeEntries.compactMap { $0.summary.cafe?.id }).count,
            homeExperimentCount: homeEntries.count,
            recipeCount: recipes.count,
            favoriteDrink: mostFrequent(current.map { $0.summary.visit.drinkDisplayName }),
            favoriteCafe: topCafe(in: cafeEntries),
            neighborhoods: Array(Set(cafeEntries.compactMap {
                $0.summary.cafe?.city?.remoteTrimmedNonEmpty ?? $0.summary.visit.cityState?.remoteTrimmedNonEmpty
            })).sorted(),
            meaningfulMemoryCount: current.filter(isMeaningfulMemory).count,
            photoCount: current.filter { $0.summary.visit.posterPhotoURL?.remoteTrimmedNonEmpty != nil }.count,
            averageRating: average,
            ratingChange: average.flatMap { currentAverage in
                previousAverage.map { currentAverage - $0 }
            },
            caffeine: caffeine,
            people: people
        )
    }

    static func dateInterval(
        for period: JournalReflectionPeriod,
        containing date: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval {
        if period == .month, let interval = calendar.dateInterval(of: .month, for: date) {
            return interval
        }
        if let interval = calendar.dateInterval(of: .year, for: date) { return interval }
        return DateInterval(start: date, duration: 1)
    }

    static func milestones(entries: [JournalEntryProjection]) -> [JournalMilestone] {
        guard !entries.isEmpty else { return [] }
        var result: [JournalMilestone] = []
        let cafeCount = Set(entries.compactMap { $0.summary.cafe?.id }).count
        let thresholds = [5, 10, 25, 50, 100]
        if let threshold = thresholds.last(where: { cafeCount >= $0 }) {
            result.append(JournalMilestone(
                id: "cafes-\(threshold)",
                title: "\(threshold) cafes remembered",
                detail: "A personal map made one memory at a time.",
                systemImage: "map.fill"
            ))
        }
        if entries.contains(where: { $0.context == .home }) {
            result.append(JournalMilestone(
                id: "first-home", title: "Home experimenter",
                detail: "You saved a home brew worth learning from.", systemImage: "house.fill"
            ))
        }
        if entries.contains(where: { $0.context == .recipe }) {
            result.append(JournalMilestone(
                id: "first-recipe", title: "A recipe to return to",
                detail: "Your coffee practice has a repeatable chapter.", systemImage: "book.pages.fill"
            ))
        }
        let meaningfulCount = entries.filter(isMeaningfulMemory).count
        if meaningfulCount >= 5 {
            result.append(JournalMilestone(
                id: "memories-5", title: "Memory keeper",
                detail: "Five sips carry a photo, note, bookmark, or reflection.", systemImage: "sparkles.rectangle.stack.fill"
            ))
        }
        if entries.contains(where: { $0.summary.visit.orderedRatingScores.count >= 3 }) {
            result.append(JournalMilestone(
                id: "taste-language", title: "Your tasting language",
                detail: "You used a detailed lens to name what stood out.", systemImage: "slider.horizontal.3"
            ))
        }
        return result
    }

    private static func averageRating(_ entries: [JournalEntryProjection]) -> Double? {
        guard !entries.isEmpty else { return nil }
        return entries.reduce(0) { $0 + $1.summary.visit.overallScore } / Double(entries.count)
    }

    private static func mostFrequent(_ values: [String]) -> String? {
        let nonempty = values.filter { !$0.isEmpty }
        let grouped = Dictionary(grouping: nonempty, by: { $0 })
        let counts = grouped.mapValues { $0.count }
        let ranked = counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }
        return ranked.first?.key
    }

    private static func topCafe(in entries: [JournalEntryProjection]) -> String? {
        Dictionary(grouping: entries.compactMap { entry -> (UUID, String, Double)? in
            guard let cafe = entry.summary.cafe else { return nil }
            return (cafe.id, cafe.consumerDisplayName, entry.summary.visit.overallScore)
        }, by: { $0.0 })
        .values
        .compactMap { rows -> (String, Double, Int)? in
            guard let first = rows.first else { return nil }
            return (first.1, rows.reduce(0) { $0 + $1.2 } / Double(rows.count), rows.count)
        }
        .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.2 > rhs.2 : lhs.1 > rhs.1 }
        .first?.0
    }

    private static func isMeaningfulMemory(_ entry: JournalEntryProjection) -> Bool {
        entry.isBookmarked
            || entry.privateNote?.remoteTrimmedNonEmpty != nil
            || entry.summary.visit.caption.remoteTrimmedNonEmpty != nil
            || entry.summary.visit.posterPhotoURL?.remoteTrimmedNonEmpty != nil
    }
}

struct UserReflectionPreferences: Codable, Equatable {
    let userID: UUID
    var monthlyRecaps: Bool
    var yearlyRecaps: Bool
    var onThisSipReminders: Bool
    var reflectionReminders: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case monthlyRecaps = "monthly_recaps"
        case yearlyRecaps = "yearly_recaps"
        case onThisSipReminders = "on_this_sip_reminders"
        case reflectionReminders = "reflection_reminders"
    }
}
