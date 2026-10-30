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
    }

    @Test func weeklyReflectionUsesSundaySixPMAndExclusiveEndAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let formatter = ISO8601DateFormatter()
        let afterDST = try #require(formatter.date(from: "2026-11-02T12:00:00Z"))
        let range = JournalReflectionEngine.dateInterval(for: .week, containing: afterDST, calendar: calendar)
        #expect(formatter.string(from: range.end) == "2026-11-01T23:00:00Z")
        #expect(formatter.string(from: range.start) == "2026-10-25T22:00:00Z")
        #expect(JournalReflectionEngine.includes(range.start, in: range))
        #expect(!JournalReflectionEngine.includes(range.end, in: range))
        let beforeSundayDelivery = try #require(formatter.date(from: "2026-11-01T22:59:59Z"))
        let prior = JournalReflectionEngine.dateInterval(for: .week, containing: beforeSundayDelivery, calendar: calendar)
        #expect(prior.end == range.start)
    }

    @Test func quietWeekHasNoInventedNumbersOrPressure() {
        let summary = JournalReflectionEngine.summary(for: .week, entries: [])
        #expect(summary.entryCount == 0)
        #expect(summary.averageRating == nil)
        #expect(summary.caffeine == nil)
        #expect(summary.headline == "A quiet week belongs here too")
    }
}
