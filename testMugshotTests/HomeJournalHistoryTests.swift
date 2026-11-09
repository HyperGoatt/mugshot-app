import Foundation
import Testing
@testable import testMugshot

struct HomeJournalHistoryTests {
    @Test func privateHomeAndPublishedEntriesShareChronologyAndCalendarDates() {
        let remote = entry(id: UUID(), date: "2026-11-03T12:00:00Z")
        let older = HomeAttemptRecord(name: "Tea", savedAt: date("2026-11-02T12:00:00Z"))
        let newer = HomeAttemptRecord(name: "Latte", locationName: "Kitchen counter", savedAt: date("2026-11-04T12:00:00Z"))
        let items = JournalHistoryProjection.ordered(entries: [remote], privateHome: [older, newer])
        #expect(items.map(\.drinkName) == ["Latte", "Cortado", "Tea"])
        #expect(JournalHistoryProjection.onDay(date("2026-11-04T18:00:00Z"), items: items, calendar: utcCalendar).map(\.drinkName) == ["Latte"])
        #expect(items.first?.privateHome?.journalLocationName == "Kitchen counter")
    }

    @Test func aPublishedCounterpartNeverProducesASecondHomeArchiveRow() {
        let remote = entry(id: UUID(), date: "2026-11-03T12:00:00Z")
        let duplicate = HomeAttemptRecord(name: "Private copy", publicationDraftID: remote.id, publicationStatus: .failed)
        let items = JournalHistoryProjection.ordered(entries: [remote], privateHome: [duplicate])
        #expect(items.count == 1)
        #expect(items.first?.published?.id == remote.id)
    }

    @Test func privateSearchIncludesProfileRecipeAndRecordedNotesWithoutInventingValues() {
        var attempt = HomeAttemptRecord(name: "Latte", locationName: "Kitchen counter", privateNote: "A little cocoa")
        attempt.preparation = HomeRecipeContent(name: "Vanilla latte", method: .espresso)
        #expect(HomeJournalSearch.matches(attempt, query: "kitchen"))
        #expect(HomeJournalSearch.matches(attempt, query: "VANILLA"))
        #expect(HomeJournalSearch.matches(attempt, query: "cocoa"))
        #expect(!HomeJournalSearch.matches(attempt, query: "jasmine"))
        #expect(HomeJournalSearch.matches(attempt, query: "  "))
    }

    @Test func coffeeBagFilterUsesRecordedIdentityBeforeLegacySnapshotFallback() {
        let bag = UUID(), other = UUID()
        var preparation = HomeRecipeContent(name: "Filter")
        preparation.coffee = CoffeeBagSnapshot(roaster: "Fixture Roasters", name: "Morning")
        var attempt = HomeAttemptRecord(name: "Filter", preparation: preparation)
        #expect(HomeJournalSearch.matchesCoffee(attempt, id: bag, legacySnapshot: preparation.coffee))
        attempt.homeCoffeeBagID = other
        #expect(!HomeJournalSearch.matchesCoffee(attempt, id: bag, legacySnapshot: preparation.coffee))
        #expect(HomeJournalSearch.matchesCoffee(attempt, id: other, legacySnapshot: nil))
        #expect(!HomeJournalSearch.matchesCoffee(HomeAttemptRecord(name: "Unknown coffee"), id: bag, legacySnapshot: preparation.coffee))
    }

    private func entry(id: UUID, date: String) -> JournalEntryProjection {
        let visit = SupabaseVisitRow(id: id, userId: UUID(), cafeId: nil,
            drinkType: "Coffee", drinkTypeCustom: nil, drinkSubtype: "Cortado", caption: "A coffee break", notes: nil,
            visibility: "Private", ratings: ["Overall": 4], overallScore: 4, posterPhotoURL: nil,
            contextType: "Cafe", locationName: "Maple Cafe", cityState: nil, brewMethod: nil, createdAt: date)
        return JournalEntryProjection(summary: RemoteVisitSummary(visit: visit, cafe: nil), privateNote: nil, isBookmarked: false)
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!; return calendar
    }
}
