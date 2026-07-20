#if DEBUG
import Testing
@testable import testMugshot

struct LogASipV3LabFixtureTests {
    @Test func overallScoreStaysUserOwnedWhileCriteriaRemainAdvisory() throws {
        let draft = V3LabDraft.fixture

        #expect(try #require(draft.weightedAverage(for: draft.sipCriteria)) == 2.5)
        #expect(draft.sipScore == 2.5)
        #expect(draft.mugshotScore == 3.0)
    }

    @Test func homeDoesNotInventASecondContextScore() {
        var draft = V3LabDraft.fixture
        draft.context = .home
        draft.sipScore = 4.5
        draft.contextScore = 1.0

        #expect(draft.mugshotScore == 4.5)
    }

    @Test func rawNoteVisibilityCannotExceedPostAudience() {
        var draft = V3LabDraft.fixture
        draft.audience = .friends
        draft.rawNoteVisibility = .everyone
        draft.constrainRawNoteVisibility()
        #expect(draft.rawNoteVisibility == .friends)

        draft.audience = .private
        draft.constrainRawNoteVisibility()
        #expect(draft.rawNoteVisibility == .private)
    }

    @Test func humanImportanceLabelsMapToLockedAlphaWeights() {
        #expect(V3LabImportance.less.weight == 0.5)
        #expect(V3LabImportance.normal.weight == 1.0)
        #expect(V3LabImportance.more.weight == 1.5)
        #expect(V3LabImportance.most.weight == 2.25)
    }
}
#endif
