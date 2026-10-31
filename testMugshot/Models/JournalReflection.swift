import Foundation

enum JournalReflectionPeriod: String, CaseIterable, Identifiable, Hashable {
    case week
    case month
    case year

    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: "Week in review"
        case .month: "This month"
        case .year: "This year"
        }
    }
    var navigationTitle: String {
        switch self {
        case .week: "Week in review"
        case .month: "Monthly reflection"
        case .year: "Yearly reflection"
        }
    }
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
    var privateHomeEntryCount = 0

    var id: String { "\(period.rawValue)-\(startDate.timeIntervalSince1970)" }

    var periodLabel: String {
        switch period {
        case .week:
            return "\(startDate.formatted(.dateTime.month(.abbreviated).day())) – \(endDate.formatted(.dateTime.month(.abbreviated).day().year()))"
        case .month: return startDate.formatted(.dateTime.month(.wide).year())
        case .year: return startDate.formatted(.dateTime.year())
        }
    }

    var headline: String {
        guard entryCount > 0 else {
            return period == .week ? "A quiet week belongs here too" : "A fresh page for your coffee memories"
        }
        if let favoriteDrink { return "\(favoriteDrink) shaped your \(period.rawValue)" }
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
        savedHomeAttempts: [HomeAttemptRecord] = [],
        people: [JournalPeopleCount] = [],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> JournalReflectionSummary {
        let interval = dateInterval(for: period, containing: referenceDate, calendar: calendar)
        let component: Calendar.Component = period == .week ? .weekOfYear : period == .month ? .month : .year
        let previousReference = calendar.date(byAdding: component, value: -1, to: referenceDate) ?? referenceDate
        let previousInterval = dateInterval(for: period, containing: previousReference, calendar: calendar)
        let current = entries.filter { includes($0.date, in: interval) }
        let previous = entries.filter { includes($0.date, in: previousInterval) }
        let canonicalIDs = Set(entries.map(\.id))
        let privateHome = savedHomeAttempts.filter { attempt in
            attempt.savedAt != nil && attempt.publicationStatus != .published
                && !canonicalIDs.contains(attempt.id)
                && !(attempt.publicationDraftID.map(canonicalIDs.contains) ?? false)
        }
        let currentHome = privateHome.filter { $0.savedAt.map { includes($0, in: interval) } ?? false }
        let previousHome = privateHome.filter { $0.savedAt.map { includes($0, in: previousInterval) } ?? false }

        let cafeEntries = current.filter { $0.context == .cafe }
        let homeEntries = current.filter { $0.context == .home }
        let recipes = current.filter { $0.context == .recipe }
        let average = averageRating(current, privateHome: currentHome)
        let previousAverage = averageRating(previous, privateHome: previousHome)
        let caffeineRows = current.compactMap(\.drinkAnalysis)
        let covered = caffeineRows.filter(\.isCoveredEstimate)
        let caffeine: JournalCaffeineEstimate? = covered.isEmpty ? nil : JournalCaffeineEstimate(
            totalMilligrams: covered.compactMap(\.estimatedCaffeineMilligrams).reduce(0, +),
            coveredEntries: covered.count,
            totalEntries: current.count + currentHome.count,
            referenceVersions: Array(Set(covered.map(\.caffeineReferenceVersion))).sorted(),
            parserVersions: Array(Set(covered.map(\.parserVersion))).sorted()
        )

        var result = JournalReflectionSummary(
            period: period,
            startDate: interval.start,
            endDate: interval.end,
            entryCount: current.count + currentHome.count,
            cafeCount: Set(cafeEntries.compactMap { $0.summary.cafe?.id }).count,
            homeExperimentCount: homeEntries.count + currentHome.count,
            recipeCount: recipes.count + currentHome.filter { $0.recipe != nil }.count,
            favoriteDrink: mostFrequent(current.map { $0.summary.visit.drinkDisplayName } + currentHome.map(\.name)),
            favoriteCafe: topCafe(in: cafeEntries),
            neighborhoods: Array(Set(cafeEntries.compactMap {
                $0.summary.cafe?.city?.remoteTrimmedNonEmpty ?? $0.summary.visit.cityState?.remoteTrimmedNonEmpty
            })).sorted(),
            meaningfulMemoryCount: current.filter(isMeaningfulMemory).count + currentHome.filter {
                !$0.privateNote.isEmpty || !$0.nextTimeNote.isEmpty || !$0.reaction.isEmpty || !$0.photoNames.isEmpty
            }.count,
            photoCount: current.filter { $0.summary.visit.posterPhotoURL?.remoteTrimmedNonEmpty != nil }.count
                + currentHome.filter { !$0.photoNames.isEmpty }.count,
            averageRating: average,
            ratingChange: average.flatMap { currentAverage in
                previousAverage.map { currentAverage - $0 }
            },
            caffeine: caffeine,
            people: people
        )
        result.privateHomeEntryCount = currentHome.count
        return result
    }

    static func dateInterval(
        for period: JournalReflectionPeriod,
        containing date: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval {
        if period == .week {
            // Match the existing weekly reminder: the latest Sunday at 6 PM,
            // in the reader's timezone, and the existing UTC 168-hour window.
            let components = DateComponents(hour: 18, minute: 0, second: 0, weekday: 1)
            let end = calendar.nextDate(after: date.addingTimeInterval(1), matching: components,
                                        matchingPolicy: .nextTime, direction: .backward) ?? date
            let start = end.addingTimeInterval(-7 * 24 * 60 * 60)
            return DateInterval(start: start, end: end)
        }
        if period == .month, let interval = calendar.dateInterval(of: .month, for: date) {
            return interval
        }
        if let interval = calendar.dateInterval(of: .year, for: date) { return interval }
        return DateInterval(start: date, duration: 1)
    }

    static func includes(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
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

    private static func averageRating(_ entries: [JournalEntryProjection], privateHome: [HomeAttemptRecord]) -> Double? {
        let values = (entries.map { $0.summary.visit.overallScore } + privateHome.compactMap(\.resolvedRating))
            .filter { $0.isFinite && (0.5...5).contains($0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
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
    var timezoneName: String = "UTC"
    var deliveryActivated: Bool = false
    var deliveryActivatedAt: Date? = nil
    var clientCapabilityVersion: Int = 0

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case monthlyRecaps = "monthly_recaps"
        case yearlyRecaps = "yearly_recaps"
        case onThisSipReminders = "on_this_sip_reminders"
        case reflectionReminders = "reflection_reminders"
        case timezoneName = "timezone_name"
        case deliveryActivated = "delivery_activated"
        case deliveryActivatedAt = "delivery_activated_at"
        case clientCapabilityVersion = "client_capability_version"
    }

    init(
        userID: UUID,
        monthlyRecaps: Bool,
        yearlyRecaps: Bool,
        onThisSipReminders: Bool,
        reflectionReminders: Bool,
        timezoneName: String = "UTC",
        deliveryActivated: Bool = false,
        deliveryActivatedAt: Date? = nil,
        clientCapabilityVersion: Int = 0
    ) {
        self.userID = userID
        self.monthlyRecaps = monthlyRecaps
        self.yearlyRecaps = yearlyRecaps
        self.onThisSipReminders = onThisSipReminders
        self.reflectionReminders = reflectionReminders
        self.timezoneName = timezoneName
        self.deliveryActivated = deliveryActivated
        self.deliveryActivatedAt = deliveryActivatedAt
        self.clientCapabilityVersion = clientCapabilityVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UUID.self, forKey: .userID)
        monthlyRecaps = try container.decode(Bool.self, forKey: .monthlyRecaps)
        yearlyRecaps = try container.decode(Bool.self, forKey: .yearlyRecaps)
        onThisSipReminders = try container.decode(Bool.self, forKey: .onThisSipReminders)
        reflectionReminders = try container.decode(Bool.self, forKey: .reflectionReminders)
        timezoneName = try container.decodeIfPresent(String.self, forKey: .timezoneName) ?? "UTC"
        deliveryActivated = try container.decodeIfPresent(Bool.self, forKey: .deliveryActivated) ?? false
        deliveryActivatedAt = try container.decodeIfPresent(Date.self, forKey: .deliveryActivatedAt)
        clientCapabilityVersion = try container.decodeIfPresent(Int.self, forKey: .clientCapabilityVersion) ?? 0
    }
}
