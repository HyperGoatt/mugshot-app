#if DEBUG
import Testing
@testable import testMugshot

struct LogASipV3LabFixtureTests {
    @Test func overallScoreStaysUserOwnedWhileCriteriaRemainAdvisory() throws {
        let draft = V3LabDraft.fixture

        #expect(try #require(draft.weightedAverage(for: draft.sipCriteria)) == 2.4)
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
        #expect(V3LabImportance.allCases == [.most, .more, .normal, .less])
    }

    @Test func criteriaSuggestionCanBecomeAnExactOneDecimalScore() throws {
        var draft = V3LabDraft.fixture
        draft.sipCriteria = [
            V3LabCriterion(
                id: "exact-decimal",
                title: "Balance",
                systemImage: "scale.3d",
                rating: 2.4,
                importance: .normal,
                isPinned: false
            )
        ]

        let suggestion = try #require(draft.weightedAverage(for: draft.sipCriteria))
        #expect(suggestion == 2.4)

        draft.sipScore = suggestion
        #expect(draft.sipScore == 2.4)
    }

    @Test func blendedMugshotScoreRoundsToOneDecimal() {
        var draft = V3LabDraft.fixture
        draft.sipScore = 2.4
        draft.contextScore = 3.4

        #expect(draft.mugshotScore == 2.9)
    }

    @Test func prototypeProvidesBroadCriteriaSuggestions() {
        #expect(V3LabSuggestion.sip.count >= 20)
        #expect(V3LabSuggestion.cafe.count >= 20)
    }

    @Test func flavorExplorerSupportsBroadToSpecificDrillDown() throws {
        let flavor = try #require(V3LabFlavorNode.explorerRoots.first(where: { $0.title == "Flavor" }))
        let fruit = try #require(flavor.children.first(where: { $0.title == "Fruit" }))
        let citrus = try #require(fruit.children.first(where: { $0.title == "Citrus" }))

        #expect(citrus.children.contains(where: { $0.title == "Orange" }))
    }

    @Test func publishReadinessRequiresTheLockedMinimums() {
        var draft = V3LabDraft.fixture
        #expect(draft.isReadyToPublish)

        draft.caption = "   "
        #expect(!draft.isReadyToPublish)

        draft.caption = "Still thinking about that creamsicle."
        draft.drinkName = ""
        #expect(!draft.isReadyToPublish)

        draft.drinkName = "Iced Orange Creamsicle"
        draft.sipScore = 0
        #expect(!draft.isReadyToPublish)
    }
}
#endif
