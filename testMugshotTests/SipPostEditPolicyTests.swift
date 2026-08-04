import Foundation
import Testing
@testable import testMugshot

struct SipPostEditPolicyTests {
    @Test func editNormalizesCaptionCriteriaAndJournalWithoutLosingAuthoredText() throws {
        var draft = makeDraft()
        draft.caption = "  A complete caption  \n"
        draft.sipCriteria = [
            SipRatingCriterionSnapshot(name: "  Sweetness ", score: 4.5, weight: 1.5, sortOrder: 9),
            SipRatingCriterionSnapshot(name: "Balance", score: 4, weight: 1, sortOrder: 3)
        ]
        draft.sipJournalNote = "  Keep the extra shot.  "

        let values = try SipPostEditPolicy.normalize(
            draft,
            context: .cafe,
            hasV3Reflection: true
        )

        #expect(values.caption == "A complete caption")
        #expect(values.sipCriteria.map(\.name) == ["Sweetness", "Balance"])
        #expect(values.sipCriteria.map(\.sortOrder) == [0, 1])
        #expect(values.sipJournalNote == "Keep the extra shot.")
        #expect(values.journalAudience == .friends)
    }

    @Test func journalAudienceCannotExceedPostAudience() {
        var draft = makeDraft()
        draft.postAudience = .friends
        draft.journalAudience = .everyone

        #expect(throws: SipPostEditValidationError.journalAudienceTooBroad) {
            try SipPostEditPolicy.normalize(
                draft,
                context: .cafe,
                hasV3Reflection: true
            )
        }
    }

    @Test func legacyJournalAlwaysRemainsPrivate() throws {
        var draft = makeDraft()
        draft.journalAudience = .friends
        draft.legacyPrivateJournalNote = "Only me"

        let values = try SipPostEditPolicy.normalize(
            draft,
            context: .cafe,
            hasV3Reflection: false
        )

        #expect(values.journalAudience == .private)
        #expect(values.legacyPrivateJournalNote == "Only me")
        #expect(values.sipJournalNote == nil)
    }

    @Test func duplicateOrEmptyCriteriaAreRejected() {
        var duplicate = makeDraft()
        duplicate.sipCriteria = [
            SipRatingCriterionSnapshot(name: "Flavor", score: 4, sortOrder: 0),
            SipRatingCriterionSnapshot(name: " flavor ", score: 3.5, sortOrder: 1)
        ]
        #expect(throws: SipPostEditValidationError.duplicateCriterionName) {
            try SipPostEditPolicy.normalize(duplicate, context: .cafe, hasV3Reflection: true)
        }

        var empty = makeDraft()
        empty.sipCriteria = [
            SipRatingCriterionSnapshot(name: "  ", score: 4, sortOrder: 0)
        ]
        #expect(throws: SipPostEditValidationError.invalidCriterionName) {
            try SipPostEditPolicy.normalize(empty, context: .cafe, hasV3Reflection: true)
        }
    }

    @Test func selectedCoverMovesFirstWithoutChangingTheRemainingOrder() {
        let first = SipPostEditPhoto.legacyExisting(storedValue: "https://example.invalid/first.jpg")
        let second = SipPostEditPhoto.legacyExisting(storedValue: "https://example.invalid/second.jpg")
        let third = SipPostEditPhoto.legacyExisting(storedValue: "https://example.invalid/third.jpg")
        var draft = makeDraft()
        draft.photos = [first, second, third]
        draft.coverPhotoID = second.id

        SipPostEditPolicy.moveCoverFirst(in: &draft)

        #expect(draft.photos.map(\.id) == [second.id, first.id, third.id])
    }

    @Test func tagsAreDeduplicatedAndBounded() throws {
        var draft = makeDraft()
        let person = SipCompanion(
            userID: UUID(),
            displayName: "Amanda",
            username: "amanda",
            avatarURL: nil
        )
        draft.taggedPeople = [person, person]

        let values = try SipPostEditPolicy.normalize(
            draft,
            context: .cafe,
            hasV3Reflection: true
        )
        #expect(values.taggedUserIDs == [person.userID])

        draft.taggedPeople = (0..<13).map { index in
            SipCompanion(
                userID: UUID(),
                displayName: "Person \(index)",
                username: "person\(index)",
                avatarURL: nil
            )
        }
        #expect(throws: SipPostEditValidationError.tooManyTags) {
            try SipPostEditPolicy.normalize(draft, context: .cafe, hasV3Reflection: true)
        }
    }

    private func makeDraft() -> SipPostEditDraft {
        SipPostEditDraft(
            caption: "Caption",
            postAudience: .everyone,
            journalAudience: .friends,
            sipScore: 4,
            sipCriteria: [],
            contextScore: 3.5,
            contextCriteria: [],
            sipJournalNote: "",
            contextJournalNote: "",
            legacyPrivateJournalNote: "",
            taggedPeople: [],
            photos: [],
            coverPhotoID: nil
        )
    }
}
