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

    @Test func remoteAdapterFallsBackToFeedSafeV3Projection() {
        let visitID = UUID()
        let userID = UUID()
        let staleCafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Stale Cafe",
            address: "123 Private Way",
            city: "Charleston, SC",
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let row = SupabaseVisitRow(
            id: visitID,
            userId: userID,
            cafeId: staleCafe.id,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Cortado",
            caption: "Morning dial-in",
            notes: nil,
            visibility: "friends",
            ratings: ["Taste": 2.5],
            overallScore: 2.5,
            posterPhotoURL: nil,
            contextType: "Home",
            locationName: "Kitchen counter",
            cityState: "Charleston, SC",
            brewMethod: "Espresso",
            createdAt: "2026-07-21T12:00:00Z"
        )
        let summary = RemoteVisitSummary(
            visit: row,
            cafe: staleCafe,
            v3FeedProjection: RemoteVisitV3FeedProjection(
                visitID: visitID,
                mugshotScore: 3.8,
                photoFallbackValue: SipPhotoFallback.mugsyMissedPhoto.rawValue
            )
        )
        let detail = RemoteVisitDetail(
            summary: summary,
            photos: [],
            comments: [],
            likeCount: 0,
            currentUserHasLiked: false
        )

        let presentation = SipDetailPresentationAdapter.remote(
            detail: detail,
            currentUserID: userID,
            reactions: [],
            isCafeSaved: false,
            canRecommend: false,
            canRepeat: false,
            replyingToUsername: nil
        )

        #expect(presentation.content.score == 3.8)
        #expect(presentation.content.sipScore == 2.5)
        #expect(presentation.content.usesMugsyPhotoFallback)
        #expect(presentation.content.locationName == "Kitchen counter")
        #expect(presentation.content.locationSubtitle == nil)
        #expect(presentation.content.locationSystemImage == JournalEntryContext.home.systemImage)
        #expect(!presentation.capabilities.dockActions.contains(.saveCafe))
    }

    @Test func cafeReflectionUsesCafeLanguageInSharedRawNote() {
        let visitID = UUID()
        let userID = UUID()
        let cafe = SupabaseCafeSummary(
            id: UUID(),
            name: "Babas on Cannon",
            address: "11 Cannon St",
            city: "Charleston, SC",
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let row = SupabaseVisitRow(
            id: visitID,
            userId: userID,
            cafeId: cafe.id,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Latte",
            caption: "Worth lingering over.",
            notes: nil,
            visibility: "everyone",
            ratings: [:],
            overallScore: 4,
            posterPhotoURL: nil,
            contextType: "Cafe",
            locationName: cafe.name,
            cityState: cafe.city,
            brewMethod: nil,
            createdAt: "2026-07-21T12:00:00Z"
        )
        let reflection = V3VisitReflection(
            visitID: visitID,
            sipScore: 4,
            contextScore: 3.5,
            contextCriteria: [],
            sipRawNote: "Sweet opening.",
            contextRawNote: "Quiet back room.",
            rawNoteVisibility: .everyone,
            photoFallback: nil,
            homeMakeAgain: nil
        )
        let detail = RemoteVisitDetail(
            summary: RemoteVisitSummary(visit: row, cafe: cafe),
            photos: [],
            comments: [],
            likeCount: 0,
            currentUserHasLiked: false,
            v3Reflection: reflection
        )

        let presentation = SipDetailPresentationAdapter.remote(
            detail: detail,
            currentUserID: userID,
            reactions: [],
            isCafeSaved: false,
            canRecommend: false,
            canRepeat: false,
            replyingToUsername: nil
        )

        #expect(presentation.content.contextRatingLabel == "Cafe")
        #expect(presentation.content.sharedRawNote == "Sip\nSweet opening.\n\nCafe\nQuiet back room.")
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
            locationSystemImage: JournalEntryContext.cafe.systemImage,
            score: ratings.isEmpty ? 0 : 4.2,
            sipScore: ratings.isEmpty ? 0 : 4.2,
            caption: caption,
            sharedRawNote: nil,
            privateNote: privateNote,
            photos: [],
            usesMugsyPhotoFallback: false,
            ratings: ratings,
            contextRatingLabel: nil,
            contextRatings: [],
            sensorySnapshot: nil,
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
