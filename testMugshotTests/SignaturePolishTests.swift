import Testing
import SwiftUI
@testable import testMugshot

@MainActor
struct SignaturePolishTests {
    @Test func refreshArmsOnceUntilGestureEnds() {
        var state = FeedRefreshPresentationState()
        let result1 = state.pull(to: 0.1)
        #expect(!result1)
        #expect(state.phase == .pulling)
        let result2 = state.pull(to: 1)
        #expect(result2)
        let result3 = state.pull(to: 0.2)
        #expect(!result3)
        let result4 = state.pull(to: 1)
        #expect(!result4)
        state.endPull()
        #expect(state.phase == .idle)
        let result5 = state.pull(to: 1)
        #expect(result5)
    }

    @Test func releaseOnlyCommitsAnArmedGesture() {
        var state = FeedRefreshPresentationState()
        _ = state.pull(to: 0.8)
        let partial = state.release()
        #expect(!partial)
        #expect(state.phase == .idle)
        _ = state.pull(to: 1)
        let armed = state.release()
        #expect(armed)
        let id = state.begin()!
        let duplicate = state.release()
        #expect(!duplicate)
        #expect(state.requestID == id)
    }

    @Test func accessibleRefreshNeverReservesPullSpaceOrDisplaysCoffee() {
        var state = FeedRefreshPresentationState()
        let id = state.begin(origin: .accessibility)!
        #expect(state.isRefreshing)
        #expect(!state.reservesPullSpace)
        #expect(!state.displaysCoffee)
        state.finish(.success, requestID: id)
        #expect(!state.reservesPullSpace)
        #expect(!state.displaysCoffee)
        state.reset()
        _ = state.begin(origin: .pull)
        #expect(state.reservesPullSpace)
        #expect(state.displaysCoffee)
    }

    @Test func partialPullReversesAndCancelsWithoutSuccess() {
        var state = FeedRefreshPresentationState()
        _ = state.pull(to: 0.7)
        _ = state.pull(to: 0.3)
        #expect(state.progress == 0.3)
        state.endPull()
        #expect(!state.isVisible)
        #expect(state.requestID == nil)
    }

    @Test func staleRefreshCannotFinishNewerCycle() {
        var state = FeedRefreshPresentationState()
        let stale = state.begin()!
        let duplicate = state.begin()
        #expect(duplicate == nil)
        state.reset() // scope/account/background invalidation
        let current = state.begin()!
        let result6 = state.finish(.success, requestID: stale)
        #expect(!result6)
        #expect(state.isRefreshing)
        let result7 = state.finish(.failure, requestID: current)
        #expect(result7)
        #expect(state.phase == .finishing(.failure))
        let result8 = state.finish(.success, requestID: current)
        #expect(!result8)
    }

    @Test func onlySuccessfulRefreshFinishesSuccessfully() {
        for outcome in [FeedRefreshOutcome.success, .failure, .cancelled, .skipped] {
            var state = FeedRefreshPresentationState()
            let id = state.begin()!
            let result9 = state.finish(outcome, requestID: id)
            #expect(result9)
            if outcome == .cancelled || outcome == .skipped {
                #expect(state.phase == .idle)
            } else {
                #expect(state.phase == .finishing(outcome))
            }
        }
    }

    @Test func receiptIsConsumedOnceAndScopedToOwner() {
        let id = UUID()
        var ledger = MugshotReceiptLedger()
        let first = MugshotSaveReceipt(id: id, ownerID: UUID(), drinkName: "Latte", isExpressive: true)
        let result10 = ledger.consume(first)
        #expect(result10)
        let result11 = ledger.consume(first)
        #expect(!result11)
        let anotherAccount = MugshotSaveReceipt(id: id, ownerID: UUID(), drinkName: "Latte", isExpressive: true)
        let result12 = ledger.consume(anotherAccount)
        #expect(result12)
        #expect(first.title == "Saved privately")
        var posted = first
        posted.audience = .friends
        #expect(posted.title == "Posted to Friends")
    }

    @Test func unknownActualsStayUnknownAndExplicitZeroIsRecorded() {
        let unknown = HomeAttemptActuals()
        #expect(MugshotHomePreparationPresentation.recordedSummary(unknown, method: .espresso) == nil)
        var actuals = unknown
        actuals.output = 0
        let summary = MugshotHomePreparationPresentation.recordedSummary(actuals, method: .espresso)
        #expect(summary?.contains("0") == true)
        #expect(summary?.contains("18") == false)
        #expect(summary?.contains("28") == false)
        #expect(actuals.dose == nil)
        #expect(actuals.seconds == nil)
    }

    @Test func loadingAndFailureNeverClaimKnownEmptyLibrary() {
        #expect(MugshotLibraryPresentation.resolve(isLoading: true, hasContent: false, hasError: false) == .loading)
        #expect(MugshotLibraryPresentation.resolve(isLoading: false, hasContent: false, hasError: true) == .failure)
        #expect(MugshotLibraryPresentation.resolve(isLoading: false, hasContent: false, hasError: false) == .empty)
        #expect(MugshotLibraryPresentation.resolve(isLoading: true, hasContent: true, hasError: true) == .content)
    }

    @Test func ratingFeedbackRequiresARealValidChange() {
        #expect(MugshotPolishState.ratingText(0) == "Not rated")
        #expect(MugshotPolishState.ratingText(.nan) == "Not rated")
        #expect(!MugshotPolishState.changedRating(from: 4, to: 4))
        #expect(!MugshotPolishState.changedRating(from: 4, to: .nan))
        #expect(!MugshotPolishState.changedRating(from: 4, to: 6))
        #expect(MugshotPolishState.changedRating(from: 4, to: 4.5))
    }

    @Test func anticipationDropIsVisibleBeforeTheRefreshThreshold() {
        for width: CGFloat in [320, 430, 768] {
            let geometry = MugsyRefreshGeometry(size: CGSize(width: width, height: 144))
            for progress: CGFloat in [0.25, 0.30] {
                let drop = geometry.anticipationDrop(from: CGPoint(x: 44, y: 0), progress: progress)
                let revealedGap = progress * MugsyRefreshGeometry.armingDistance - DesignSystem.Space.sm
                #expect(drop.y >= 0)
                #expect(drop.y + 3.5 <= revealedGap)
            }
        }
    }

    @Test func pourRimStaysWithinCanonicalCharacterAtAllWidths() {
        for width: CGFloat in [320, 368, 430, 768] {
            let geometry = MugsyRefreshGeometry(size: CGSize(width: width, height: 144))
            #expect(geometry.rim.x > geometry.characterOrigin.x)
            #expect(geometry.rim.x < geometry.characterOrigin.x + geometry.characterSide)
            #expect(geometry.rim.y > geometry.characterOrigin.y)
            #expect(geometry.characterOrigin.y + geometry.characterSide <= 144)
        }
    }
}
