import Foundation
import Testing
@testable import testMugshot

struct SipDetailPresentationTests {
    @Test func friendHierarchyKeepsFourPrimaryActionsReachable() {
        let capabilities = SipDetailCapabilities.friend(
            hasCafe: true,
            canComment: true,
            canRecommend: true
        )

        #expect(capabilities.isOwner == false)
        #expect(capabilities.dockActions == [.like, .comment, .saveCafe, .recommend])
        #expect(capabilities.dockActions.count == 4)
        #expect(capabilities.menuActions == [.report, .block])
    }

    @Test func ownerHierarchyKeepsDestructiveActionLast() {
        let capabilities = SipDetailCapabilities.owner(
            hasCafe: true,
            canComment: true,
            canRepeat: true
        )

        #expect(capabilities.isOwner)
        #expect(capabilities.dockActions == [.comment, .saveCafe, .share, .more])
        #expect(capabilities.menuActions == [.edit, .correctDrink, .repeatSip, .delete])
        #expect(capabilities.menuActions.last == .delete)
        #expect(capabilities.dockActions.count <= 4)
    }

    @Test func saveCafeCopyIsExplicitAndAscii() {
        #expect(SipDetailAction.saveCafe.title == "Save cafe")
        #expect(SipDetailAction.saveCafe.title.contains("é") == false)
    }

    @Test func sectionVisibilityUsesProgressiveDisclosure() {
        let owner = SipDetailCapabilities.owner(
            hasCafe: true,
            canComment: true,
            canRepeat: false
        )
        let model = makeContent(
            caption: nil,
            privateNote: "Dial the grind finer next time.",
            reactions: [],
            ratings: [SipDetailRatingItem(name: "Taste", score: 4.2)],
            visitFacts: [SipDetailVisitFact(label: "Visited", value: "Jul 15, 2026")]
        )

        #expect(model.visibleSections(capabilities: owner) == [
            .actions,
            .taste,
            .visitDetails,
            .privateNote,
            .conversation
        ])
        #expect(model.visibleSections(capabilities: owner).contains(.friendsNoticed) == false)
        #expect(model.visibleSections(capabilities: owner).contains(.note) == false)
    }

    @Test func populatedReactionsBecomeFriendsNoticed() {
        let model = makeContent(
            reactions: [
                SipDetailReactionSummary(title: "Great find", systemImage: "sparkles", count: 3)
            ]
        )
        let owner = SipDetailCapabilities.owner(
            hasCafe: false,
            canComment: false,
            canRepeat: false
        )

        #expect(model.visibleSections(capabilities: owner).contains(.friendsNoticed))
    }

    private func makeContent(
        caption: String? = "Bright, balanced, and worth another visit.",
        privateNote: String? = nil,
        reactions: [SipDetailReactionSummary] = [],
        ratings: [SipDetailRatingItem] = [],
        visitFacts: [SipDetailVisitFact] = []
    ) -> SipDetailContentModel {
        SipDetailContentModel(
            id: UUID(),
            authorName: "Your sip",
            authorUsername: "@joe",
            authorAvatarURL: nil,
            timestamp: "Jul 15, 2026 at 3:12 PM",
            visibility: "Public",
            drinkName: "Iced Quad Shot Caramel Macchiato",
            locationName: "Babas on Cannon",
            locationSubtitle: "11 Cannon St, Charleston, SC",
            score: ratings.isEmpty ? 0 : 4.2,
            caption: caption,
            privateNote: privateNote,
            photos: [],
            ratings: ratings,
            visitFacts: visitFacts,
            reactions: reactions,
            comments: [],
            isLiked: false,
            likeCount: 0,
            isCafeSaved: false,
            replyingToUsername: nil,
            sharePayload: SipShareCardPayload(
                authorName: "Joe",
                drinkName: "Iced Quad Shot Caramel Macchiato",
                cafeName: "Babas on Cannon",
                rating: 4.2,
                date: Date(timeIntervalSince1970: 1_752_604_320),
                publicCaption: caption,
                remotePhotoURL: nil,
                localPhotoPath: nil
            )
        )
    }
}
