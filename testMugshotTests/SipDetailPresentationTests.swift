import Foundation
import Testing
@testable import testMugshot

struct SipDetailPresentationTests {
    @Test func guestSocialActionsRequireAuthenticationBeforeInteraction() {
        let protectedActions: [SipDetailAction] = [
            .like, .comment, .saveCafe, .recommend, .report, .block
        ]
        for action in protectedActions {
            #expect(
                SipDetailInteractionGate.requiresAuthentication(
                    for: action,
                    currentUserID: nil
                )
            )
            #expect(
                !SipDetailInteractionGate.requiresAuthentication(
                    for: action,
                    currentUserID: UUID()
                )
            )
        }

        #expect(
            !SipDetailInteractionGate.requiresAuthentication(
                for: .share,
                currentUserID: nil
            )
        )
    }

    @Test func friendHierarchyKeepsFourPrimaryActionsReachable() {
        let capabilities = SipDetailCapabilities.friend(
            hasCafe: true,
            canComment: true,
            canRecommend: true,
            canShareExternally: true
        )

        #expect(capabilities.isOwner == false)
        #expect(capabilities.dockActions == [.like, .comment, .saveCafe, .recommend])
        #expect(capabilities.dockActions.count == 4)
        #expect(capabilities.menuActions == [.share, .report, .block])
    }

    @Test func friendsOnlyViewerCannotExportSomeoneElsesPost() {
        let capabilities = SipDetailCapabilities.friend(
            hasCafe: false,
            canComment: true,
            canRecommend: false,
            canShareExternally: false
        )

        #expect(!capabilities.dockActions.contains(.share))
        #expect(!capabilities.menuActions.contains(.share))
        #expect(capabilities.dockActions == [.like, .comment, .more])
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
            ratings: [SipDetailRatingItem(name: "Taste", score: 4.2)]
        )

        #expect(model.visibleSections(capabilities: owner) == [
            .actions,
            .taste,
            .privateNote,
            .conversation
        ])
        #expect(model.visibleSections(capabilities: owner).contains(.friendsNoticed) == false)
        #expect(model.visibleSections(capabilities: owner).contains(.note) == false)
        #expect(!SipDetailSection.allCases.map(\.rawValue).contains("visitDetails"))
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
        #expect(presentation.content.contextScore == 3.5)
        #expect(presentation.content.sharedRawNote == "Sip\nSweet opening.\n\nCafe\nQuiet back room.")
        #expect(presentation.content.locationName == "Babas on Cannon")
        #expect(presentation.content.locationSubtitle == "Charleston")
    }

    @Test func authorizedRecipeProjectionDrivesBlueprintAndReusableAction() {
        let postOwnerID = UUID()
        let recipeOwnerID = UUID()
        let viewerID = UUID()
        let recipeIdentityID = UUID()
        let recipeVersionID = UUID()
        let taggedFriendID = UUID()
        let row = SupabaseVisitRow(
            id: UUID(),
            userId: postOwnerID,
            cafeId: nil,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "V60",
            caption: "Dialed in.",
            notes: nil,
            visibility: "everyone",
            ratings: ["Taste": 4.6],
            overallScore: 4.6,
            posterPhotoURL: nil,
            contextType: "Recipe",
            locationName: "Home",
            cityState: nil,
            brewMethod: "Untrusted visit method",
            createdAt: "2026-07-21T12:00:00Z",
            equipment: "Untrusted visit equipment",
            brewDetails: BrewDetails(
                beans: "Untrusted visit beans",
                steps: [BrewRecipeStep(instruction: "Untrusted visit step")]
            ),
            recipeVersionID: recipeVersionID
        )
        let projection = RemoteVisitRecipeProjection(
            recipeIdentityID: recipeIdentityID,
            recipeVersionID: recipeVersionID,
            recipeName: "Summer V60",
            versionNumber: 4,
            versionLabel: "v4",
            visibilityValue: "everyone",
            sourceKindValue: "adapted",
            sourceRecipeVersionID: UUID(),
            owner: RemoteRecipeOwnerProjection(
                id: recipeOwnerID,
                displayName: "Recipe Maker",
                username: "maker",
                avatarURL: nil
            ),
            brewMethod: "Projected V60",
            equipment: "Projected dripper",
            brewDetails: BrewDetails(
                beans: "Projected beans",
                doseGrams: 18,
                yieldGrams: 300,
                steps: [BrewRecipeStep(instruction: "Bloom for 45 seconds")]
            ),
            canSaveAndAdapt: true
        )
        let detail = RemoteVisitDetail(
            summary: RemoteVisitSummary(visit: row, cafe: nil),
            photos: [],
            comments: [],
            likeCount: 0,
            currentUserHasLiked: false,
            recipeProjection: projection,
            taggedAccounts: [
                RemoteVisitTag(
                    userID: viewerID,
                    displayName: "Viewer",
                    username: "viewer",
                    avatarURL: nil,
                    taggedAt: "2026-07-21T12:01:00Z"
                ),
                RemoteVisitTag(
                    userID: taggedFriendID,
                    displayName: nil,
                    username: "friend",
                    avatarURL: nil,
                    taggedAt: "2026-07-21T12:02:00Z"
                )
            ]
        )

        let presentation = SipDetailPresentationAdapter.remote(
            detail: detail,
            currentUserID: viewerID,
            reactions: [],
            isCafeSaved: false,
            canRecommend: false,
            canRepeat: false,
            replyingToUsername: nil
        )

        #expect(presentation.content.recipe?.accessState == .available)
        #expect(presentation.content.recipe?.name == "Summer V60")
        #expect(presentation.content.recipe?.creatorUsername == "@maker")
        #expect(presentation.content.recipe?.brewMethod == "Projected V60")
        #expect(presentation.content.recipe?.equipment == "Projected dripper")
        #expect(presentation.content.recipe?.details?.beans == "Projected beans")
        #expect(presentation.content.recipe?.details?.steps?.first?.instruction == "Bloom for 45 seconds")
        #expect(presentation.content.recipe?.canSaveAndAdapt == true)
        #expect(presentation.content.recipe?.canBrewAgain == false)
        #expect(presentation.content.taggedAccounts.count == 2)
        #expect(presentation.content.taggedAccounts.first?.isCurrentUser == true)
        #expect(presentation.content.visibleSections(capabilities: presentation.capabilities).contains(.recipe))
        #expect(presentation.content.visibleSections(capabilities: presentation.capabilities).contains(.taggedPeople))
    }

    @Test func inaccessibleRecipeRendersIdentityOnlyWithoutVisitPayloadFallback() {
        let postOwnerID = UUID()
        let viewerID = UUID()
        let recipeIdentityID = UUID()
        let recipeVersionID = UUID()
        let row = SupabaseVisitRow(
            id: UUID(),
            userId: postOwnerID,
            cafeId: nil,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Espresso",
            caption: "Private dial-in.",
            notes: nil,
            visibility: "friends",
            ratings: [:],
            overallScore: 4,
            posterPhotoURL: nil,
            contextType: "Recipe",
            locationName: "Home",
            cityState: nil,
            brewMethod: "Secret method",
            createdAt: "2026-07-21T12:00:00Z",
            equipment: "Secret machine",
            brewDetails: BrewDetails(
                beans: "Secret beans",
                steps: [BrewRecipeStep(instruction: "Secret step")],
                additions: "Secret additions"
            ),
            recipeVersionID: recipeVersionID
        )
        let identity = RemoteVisitRecipeIdentityProjection(
            recipeIdentityID: recipeIdentityID,
            recipeVersionID: recipeVersionID,
            recipeName: "House Espresso",
            versionNumber: 7,
            versionLabel: "v7",
            ownerID: postOwnerID,
            ownerDisplayName: "Amanda",
            ownerUsername: "amanda",
            ownerAvatarURL: nil
        )
        let detail = RemoteVisitDetail(
            summary: RemoteVisitSummary(visit: row, cafe: nil),
            photos: [],
            comments: [],
            likeCount: 0,
            currentUserHasLiked: false,
            recipeProjection: nil,
            recipeIdentityProjection: identity
        )

        let presentation = SipDetailPresentationAdapter.remote(
            detail: detail,
            currentUserID: viewerID,
            reactions: [],
            isCafeSaved: false,
            canRecommend: false,
            canRepeat: false,
            replyingToUsername: nil
        )

        #expect(presentation.content.recipe?.accessState == .locked)
        #expect(presentation.content.recipe?.name == "House Espresso")
        #expect(presentation.content.recipe?.versionLabel == "v7")
        #expect(presentation.content.recipe?.creatorUsername == "@amanda")
        #expect(presentation.content.recipe?.brewMethod == nil)
        #expect(presentation.content.recipe?.equipment == nil)
        #expect(presentation.content.recipe?.details == nil)
        #expect(presentation.content.recipe?.canSaveAndAdapt == false)
    }

    @Test func recipeOwnerKeepsBrewAgainInsteadOfSaveAndAdapt() {
        let ownerID = UUID()
        let recipeVersionID = UUID()
        let row = SupabaseVisitRow(
            id: UUID(), userId: ownerID, cafeId: nil,
            drinkType: "Coffee", drinkTypeCustom: nil, drinkSubtype: "Aeropress",
            caption: "", notes: nil, visibility: "everyone", ratings: [:],
            overallScore: 4, posterPhotoURL: nil, contextType: "Recipe",
            locationName: "Home", cityState: nil, brewMethod: nil,
            createdAt: "2026-07-21T12:00:00Z", recipeVersionID: recipeVersionID
        )
        let projection = RemoteVisitRecipeProjection(
            recipeIdentityID: UUID(),
            recipeVersionID: recipeVersionID,
            recipeName: "Daily Aeropress",
            versionNumber: 1,
            versionLabel: nil,
            visibilityValue: "everyone",
            sourceKindValue: "original",
            sourceRecipeVersionID: nil,
            brewMethod: "Aeropress",
            equipment: "Aeropress",
            brewDetails: .empty,
            canSaveAndAdapt: true
        )
        let detail = RemoteVisitDetail(
            summary: RemoteVisitSummary(visit: row, cafe: nil),
            photos: [], comments: [], likeCount: 0,
            currentUserHasLiked: false,
            recipeProjection: projection
        )

        let presentation = SipDetailPresentationAdapter.remote(
            detail: detail,
            currentUserID: ownerID,
            reactions: [],
            isCafeSaved: false,
            canRecommend: false,
            canRepeat: true,
            replyingToUsername: nil
        )

        #expect(presentation.content.recipe?.canBrewAgain == true)
        #expect(presentation.content.recipe?.canSaveAndAdapt == false)
    }

    private func makeContent(
        caption: String? = "Bright, balanced, and worth another visit.",
        privateNote: String? = nil,
        reactions: [SipDetailReactionSummary] = [],
        ratings: [SipDetailRatingItem] = []
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
            contextScore: nil,
            caption: caption,
            sharedRawNote: nil,
            privateNote: privateNote,
            sharedMugshot: nil,
            recipe: nil,
            taggedAccounts: [],
            photos: [],
            usesMugsyPhotoFallback: false,
            ratings: ratings,
            contextRatingLabel: nil,
            contextRatings: [],
            sensorySnapshot: nil,
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
