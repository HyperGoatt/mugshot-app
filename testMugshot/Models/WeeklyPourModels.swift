import Foundation

struct WeeklyPourWindow: Hashable, Sendable, Identifiable {
    static let duration: TimeInterval = 7 * 24 * 60 * 60
    let end: Date
    var start: Date { end.addingTimeInterval(-Self.duration) }
    var id: Date { end }
    var previous: Self { Self(endingAt: start) }

    init(endingAt end: Date) { self.end = end }

    func contains(_ date: Date) -> Bool { date >= start && date < end }

    static func latestCompleted(at date: Date = .now, calendar: Calendar = .current) -> Self {
        let boundary = DateComponents(hour: 18, minute: 0, second: 0, weekday: 1)
        let end = calendar.nextDate(after: date.addingTimeInterval(0.001), matching: boundary,
            matchingPolicy: .nextTime, direction: .backward) ?? date
        return Self(endingAt: end)
    }

    var title: String {
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(start.formatted(format)) – \(end.formatted(format))"
    }

    var yearLabel: String { end.formatted(.dateTime.year()) }
}

enum WeeklyPourPhoto: Equatable, Sendable {
    case remote(String)
    case local(String)
#if DEBUG
    case fixture(String)
#endif
}

/// Deliberately carries no private-note or account-profile fields. A caption is
/// owner-only story content; the separate share projection has no text/media.
struct WeeklyPourMoment: Identifiable, Equatable, Sendable {
    enum Origin: Sendable { case journal, home }
    let id: UUID
    let ownerID: UUID
    let date: Date
    let drink: String
    let location: String
    let cafeID: UUID?
    let isAtHome: Bool
    let rating: Double?
    let caption: String?
    let photo: WeeklyPourPhoto?
    let isPrivate: Bool
    let isComplete: Bool
    let origin: Origin
    let linkedVisitID: UUID?

    var recordedRating: Double? {
        guard let rating, rating.isFinite, rating > 0, rating <= 5 else { return nil }
        return rating
    }
}

enum WeeklyPourChapter: String, Identifiable, Sendable {
    case cover, moments, standout, places, repeatOrder, keepsake
    var id: String { rawValue }
}

struct WeeklyPourPlace: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let moments: [WeeklyPourMoment]
    var count: Int { moments.count }
}

struct WeeklyPourRepeatedDrink: Equatable, Sendable {
    let name: String
    let moments: [WeeklyPourMoment]
}

struct WeeklyPourShareSummary: Equatable, Sendable {
    let window: WeeklyPourWindow
    let momentCount: Int
    let cafeCount: Int
    let homeCount: Int
}

struct WeeklyPourStory: Equatable, Sendable {
    let ownerID: UUID
    let window: WeeklyPourWindow
    let moments: [WeeklyPourMoment]

    init(ownerID: UUID, window: WeeklyPourWindow, candidates: [WeeklyPourMoment]) {
        self.ownerID = ownerID
        self.window = window
        let eligible = candidates.filter {
            $0.ownerID == ownerID && $0.isComplete && window.contains($0.date)
        }
        let publishedIDs = Set(eligible.filter { $0.origin == .journal }.map(\.id))
        var seen = Set<UUID>()
        moments = eligible.sorted(by: Self.chronological).filter { moment in
            if moment.origin == .home, let linked = moment.linkedVisitID, publishedIDs.contains(linked) {
                return false
            }
            return seen.insert(moment.id).inserted
        }
    }

    var homeCount: Int { moments.filter(\.isAtHome).count }
    var privateCount: Int { moments.filter(\.isPrivate).count }
    var photos: [WeeklyPourMoment] { moments.filter { $0.photo != nil } }
    var hasRatedStandout: Bool { standout?.recordedRating != nil }

    var standout: WeeklyPourMoment? {
        let rated = moments.filter { $0.recordedRating != nil }.sorted {
            if $0.recordedRating != $1.recordedRating { return ($0.recordedRating ?? 0) > ($1.recordedRating ?? 0) }
            return Self.chronological($1, $0)
        }
        return rated.first ?? photos.last ?? moments.last
    }

    var places: [WeeklyPourPlace] {
        let groups = Dictionary(grouping: moments.filter { $0.cafeID != nil && !$0.isAtHome }) { $0.cafeID! }
        return groups.map { id, values in
            WeeklyPourPlace(id: id, name: values.last?.location ?? "Cafe", moments: values)
        }.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var repeatedDrink: WeeklyPourRepeatedDrink? {
        let groups = Dictionary(grouping: moments) { Self.normalizedDrink($0.drink) }
        let repeated = groups.filter { !$0.key.isEmpty && $0.value.count >= 2 }.sorted {
            if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
            return $0.key < $1.key
        }.first
        guard let values = repeated?.value else { return nil }
        return WeeklyPourRepeatedDrink(name: values.last?.drink.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                                       moments: values)
    }

    var chapters: [WeeklyPourChapter] {
        guard !moments.isEmpty else { return [.cover] }
        var result: [WeeklyPourChapter] = [.cover]
        if moments.count > 1 { result.append(.moments) }
        result.append(.standout)
        if moments.count > 1 && (!places.isEmpty || homeCount > 0) { result.append(.places) }
        if repeatedDrink != nil { result.append(.repeatOrder) }
        result.append(.keepsake)
        return result
    }

    func shareSummary(includePrivate: Bool) -> WeeklyPourShareSummary {
        let shared = moments.filter { includePrivate || !$0.isPrivate }
        return WeeklyPourShareSummary(window: window, momentCount: shared.count,
            cafeCount: Set(shared.filter { !$0.isAtHome }.compactMap(\.cafeID)).count,
            homeCount: shared.filter(\.isAtHome).count)
    }

    private static func chronological(_ lhs: WeeklyPourMoment, _ rhs: WeeklyPourMoment) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.origin != rhs.origin { return lhs.origin == .journal }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func normalizedDrink(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
