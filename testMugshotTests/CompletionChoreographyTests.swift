import Foundation
import Testing
@testable import testMugshot

@MainActor
struct CompletionChoreographyTests {
    @Test func completionCannotReplayAfterRelaunchOrBorrowAnotherAccount() throws {
        let name = "CompletionChoreographyTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let owner = UUID()
        let receipt = MugshotSaveReceipt(id: UUID(), ownerID: owner, drinkName: "Latte", isExpressive: true, audience: .friends)
        let first = MugshotCompletionFeedback(defaults: defaults)
        #expect(!first.consume(receipt, activeOwnerID: UUID()))
        #expect(!first.consume(receipt, activeOwnerID: nil))
        #expect(first.consume(receipt, activeOwnerID: owner))
        #expect(!first.consume(receipt, activeOwnerID: owner))
        let relaunched = MugshotCompletionFeedback(defaults: defaults)
        #expect(!relaunched.consume(receipt, activeOwnerID: owner))
        var changedAudience = receipt
        changedAudience.audience = .everyone
        #expect(!relaunched.consume(changedAudience, activeOwnerID: owner))
        let other = MugshotSaveReceipt(id: receipt.id, ownerID: UUID(), drinkName: "Tea", isExpressive: true, audience: .friends)
        #expect(relaunched.consume(other, activeOwnerID: other.ownerID))
    }

    @Test func quickAndReducedMotionCompletionsUseOneImmediateBeat() {
        for plan in [MugshotCompletionPlan.beats(expressive: false, reduceMotion: false),
                     MugshotCompletionPlan.beats(expressive: true, reduceMotion: true)] {
            #expect(plan.count == 1)
            #expect(plan.first?.milliseconds == 0)
            #expect(plan.first?.haptic == .success)
        }
        let expressive = MugshotCompletionPlan.beats(expressive: true, reduceMotion: false)
        #expect(expressive.map(\.milliseconds) == [180, 680])
        #expect(expressive.map(\.haptic) == [.softImpact, .success])
        #expect(MugshotCompletionPlan.duration < 1.5)
    }

    @Test func privateSaveAndPublicationAreDistinctButDeletionPurgesOnlyItsOwner() throws {
        let name = "CompletionPurgeTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = MugshotCompletionFeedback(defaults: defaults)
        let owner = UUID(), otherOwner = UUID(), operation = UUID()
        let saved = MugshotSaveReceipt(id: operation, ownerID: owner, drinkName: "Tea", isExpressive: false)
        var posted = saved
        posted.audience = .friends
        let other = MugshotSaveReceipt(id: operation, ownerID: otherOwner, drinkName: "Tea", isExpressive: false)
        #expect(store.consume(saved, activeOwnerID: owner))
        #expect(store.consume(posted, activeOwnerID: owner))
        #expect(store.consume(other, activeOwnerID: otherOwner))
        store.removeAll(ownerID: owner)
        #expect(!store.consume(saved, activeOwnerID: otherOwner))
        #expect(!store.consume(other, activeOwnerID: otherOwner))
        #expect(store.consume(saved, activeOwnerID: owner))
    }

    @Test func completionBeatSchedulerKeepsOffsetsAndStopsAfterFirstBeatIfHidden() async {
        let plan = MugshotCompletionPlan.beats(expressive: true, reduceMotion: false)
        var waits: [Int] = [], emitted: [MugshotHaptic] = []
        await MugshotCompletionPlan.perform(beats: plan, isCurrent: { true },
            sleep: { waits.append($0) }, emit: { emitted.append($0) })
        #expect(waits == [180, 500])
        #expect(emitted == [.softImpact, .success])
        var visible = true
        emitted = []
        await MugshotCompletionPlan.perform(beats: plan, isCurrent: { visible },
            sleep: { _ in }, emit: { emitted.append($0); visible = false })
        #expect(emitted == [.softImpact])
    }

    @Test func disabledHapticsAndInactiveSceneNeverPlay() {
        #expect(!MugshotFeedbackPolicy.shouldPlay(isEnabled: false, appIsActive: true))
        #expect(!MugshotFeedbackPolicy.shouldPlay(isEnabled: true, appIsActive: false))
        #expect(MugshotFeedbackPolicy.shouldPlay(isEnabled: true, appIsActive: true))
    }

    @Test func accountOrSceneChangeDuringDelaySuppressesEveryLaterBeat() async {
        var current = true
        var emitted: [MugshotHaptic] = []
        await MugshotCompletionPlan.perform(
            beats: MugshotCompletionPlan.beats(expressive: true, reduceMotion: false),
            isCurrent: { current },
            sleep: { _ in current = false },
            emit: { emitted.append($0) }
        )
        #expect(emitted.isEmpty)
    }

    @Test func cancellationCannotEmitASuccessAfterInterruptedPour() async {
        var emitted: [MugshotHaptic] = []
        await MugshotCompletionPlan.perform(
            beats: MugshotCompletionPlan.beats(expressive: true, reduceMotion: false),
            isCurrent: { true },
            sleep: { _ in throw CancellationError() },
            emit: { emitted.append($0) }
        )
        #expect(emitted.isEmpty)
    }

    @Test func characterHasFiniteArticulatedMotionAndCleanSettle() {
        let start = MugsyCompletionPose.sample(0)
        let peak = MugsyCompletionPose.sample(0.58)
        let end = MugsyCompletionPose.sample(1)
        #expect(start.fill < peak.fill)
        #expect(peak.bend > 0)
        #expect(peak.wave > 0)
        #expect(end.fill == 1)
        #expect(end.bend == 0)
        #expect(end.wave == 0)
        #expect(end.eyeOpenness == 1)
        #expect(MugsyCompletionPose.sample(-1) == start)
        #expect(MugsyCompletionPose.sample(2) == end)
        #expect(MugsyCompletionPose.sample(.nan) == end)
    }

    @Test func weeklyReflectionUsesSundaySixPMAndExclusiveEndAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let formatter = ISO8601DateFormatter()
        let afterDST = try #require(formatter.date(from: "2026-11-02T12:00:00Z"))
        let range = JournalReflectionEngine.dateInterval(for: .week, containing: afterDST, calendar: calendar)
        #expect(formatter.string(from: range.end) == "2026-11-01T23:00:00Z")
        // The existing reminder SQL runs in UTC and subtracts 7 * 24 hours.
        #expect(formatter.string(from: range.start) == "2026-10-25T23:00:00Z")
        #expect(range.duration == 7 * 24 * 60 * 60)
        #expect(JournalReflectionEngine.includes(range.start, in: range))
        #expect(!JournalReflectionEngine.includes(range.end, in: range))
        let beforeSundayDelivery = try #require(formatter.date(from: "2026-11-01T22:59:59Z"))
        let prior = JournalReflectionEngine.dateInterval(for: .week, containing: beforeSundayDelivery, calendar: calendar)
        #expect(formatter.string(from: prior.end) == "2026-10-25T22:00:00Z")
    }

    @Test func quietWeekHasNoInventedNumbersOrPressure() {
        let summary = JournalReflectionEngine.summary(for: .week, entries: [])
        #expect(summary.entryCount == 0)
        #expect(summary.averageRating == nil)
        #expect(summary.caffeine == nil)
        #expect(summary.headline == "A quiet week belongs here too")
    }

    @Test func weeklyReflectionIncludesCompletedPrivateHomeSipsButNeverDraftsOrDuplicatePosts() throws {
        let formatter = ISO8601DateFormatter()
        let now = try #require(formatter.date(from: "2026-10-30T12:00:00Z"))
        let savedAt = try #require(formatter.date(from: "2026-10-22T12:00:00Z"))
        var saved = HomeAttemptRecord(name: "Private filter coffee")
        saved.savedAt = savedAt
        saved.privateNote = "A useful observation"
        var unrated = HomeAttemptRecord(name: "Private tea")
        unrated.savedAt = savedAt
        var draft = HomeAttemptRecord(name: "Unfinished latte")
        draft.createdAt = savedAt
        var published = saved
        published.id = UUID()
        published.publicationStatus = .published
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let summary = JournalReflectionEngine.summary(for: .week, entries: [],
            savedHomeAttempts: [saved, unrated, draft, published], referenceDate: now, calendar: calendar)
        #expect(summary.entryCount == 2)
        #expect(summary.homeExperimentCount == 2)
        #expect(summary.privateHomeEntryCount == 2)
        #expect(summary.averageRating == nil)
        #expect(summary.caffeine == nil)
        #expect(summary.meaningfulMemoryCount == 1)
    }

    @Test func privateHomeRatingUsesRecordedValueAndSaveDateWithinExclusiveWindow() throws {
        let formatter = ISO8601DateFormatter()
        let now = try #require(formatter.date(from: "2026-10-30T12:00:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let range = JournalReflectionEngine.dateInterval(for: .week, containing: now, calendar: calendar)
        var saved = HomeAttemptRecord(name: "Latte")
        saved.createdAt = range.start.addingTimeInterval(-100)
        saved.savedAt = range.start
        saved.rating = 4.5
        var boundary = saved
        boundary.id = UUID()
        boundary.savedAt = range.end
        boundary.rating = 1
        let summary = JournalReflectionEngine.summary(for: .week, entries: [],
            savedHomeAttempts: [saved, boundary], referenceDate: now, calendar: calendar)
        #expect(summary.entryCount == 1)
        #expect(summary.averageRating == 4.5)
    }

    @Test func homeAttemptAlreadyRepresentedByCanonicalPostIsNotCountedTwice() throws {
        let formatter = ISO8601DateFormatter()
        let date = try #require(formatter.date(from: "2026-10-22T12:00:00Z"))
        let visitID = UUID()
        let row = SupabaseVisitRow(id: visitID, userId: UUID(), cafeId: nil,
            drinkType: "Coffee", drinkTypeCustom: nil, drinkSubtype: "Latte",
            caption: "A good make", notes: nil, visibility: "Private",
            ratings: ["Overall": 4], overallScore: 4, posterPhotoURL: nil,
            contextType: "Home", locationName: "Home", cityState: nil,
            brewMethod: nil, createdAt: formatter.string(from: date))
        var saved = HomeAttemptRecord(name: "Latte")
        saved.savedAt = date
        saved.publicationDraftID = visitID
        let entry = JournalEntryProjection(summary: RemoteVisitSummary(visit: row, cafe: nil),
                                           privateNote: nil, isBookmarked: false)
        let summary = JournalReflectionEngine.summary(for: .month, entries: [entry],
            savedHomeAttempts: [saved], referenceDate: date)
        #expect(summary.entryCount == 1)
        #expect(summary.privateHomeEntryCount == 0)
        #expect(summary.averageRating == 4)
    }
}
