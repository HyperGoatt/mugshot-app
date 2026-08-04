#if DEBUG
import SwiftUI

struct FeedRefreshPreviewHost: View {
    @State private var selectedRoute: FeedPostRoute?
    @State private var selectedScope: FeedScope = .friends

    private let visits = FeedRefreshPreviewFixtures.visits

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MugshotScreenHeader("Feed", subtitle: "Sips from friends")

                MugshotSegmentedControl(
                    options: FeedScope.allCases,
                    selection: $selectedScope,
                    title: { $0.displayName },
                    icon: { scope in
                        switch scope {
                        case .ranked: "sparkles"
                        case .friends: "person.2.fill"
                        case .everyone: "globe.americas.fill"
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(visits) { visit in
                            RemoteFeedVisitCard(
                                visit: visit,
                                isCafeSaved: visit.id == FeedRefreshPreviewFixtures.amandaID,
                                isSocialActionInFlight: false,
                                showsRecommendationReason: false,
                                onOpen: { selectedRoute = .remote(visit) },
                                onLike: {},
                                onSaveCafe: {},
                                onComment: { selectedRoute = .remote(visit) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            }
            .background(Color.creamWhite)
            .navigationDestination(item: $selectedRoute) { route in
                FeedRefreshPreviewDetail(route: route)
                    .id(route.id)
                    .accessibilityIdentifier("feed.destination.\(route.visitID.uuidString)")
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct FeedRefreshPreviewDetail: View {
    let route: FeedPostRoute
    @State private var photoIndex = 0
    @State private var comment = ""
    @State private var toolbarProgress: CGFloat = 0
    @FocusState private var commentFocus: Bool

    private var presentation: SipDetailPresentation {
        FeedRefreshPreviewFixtures.presentation(for: route)
    }

    var body: some View {
        SipDetailScreen(
            presentation: presentation,
            selectedPhotoIndex: $photoIndex,
            commentText: $comment,
            toolbarProgress: $toolbarProgress,
            commentFocus: $commentFocus,
            isWorking: false,
            statusMessage: nil,
            mentionSuggestions: [],
            onAction: { _ in },
            onSubmitComment: {},
            onReply: { _ in },
            onCommentAction: { _, _ in },
            onCancelReply: {},
            onSelectMention: { _ in },
            onPhotoTap: { _ in },
            onRecipeAction: { _ in },
            onTaggedAccount: { _ in },
            onRemoveOwnTag: {}
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.creamWhite, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private enum FeedRefreshPreviewFixtures {
    static let amandaID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    static let joeID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!

    static let visits: [RemoteVisitSummary] = [
        makeVisit(
            id: amandaID,
            authorName: "Amanda Metze",
            username: "amandametze",
            drinkName: "Iced Brown Sugar Cinnamon Latte",
            locationName: "Uptown Coffee",
            city: "Pittsburgh, PA",
            score: 4.0,
            assetName: "V3OrangeCreamsicleHeroV2",
            caption: maximumCaption,
            likeCount: 18,
            commentCount: 4
        ),
        makeVisit(
            id: joeID,
            authorName: "Joe Rosso",
            username: "rosso5",
            drinkName: "Peach Cobbler Latte",
            locationName: "Uptown Coffee",
            city: "Pittsburgh, PA",
            score: 3.5,
            assetName: "V3CreamyLatte",
            caption: "Birthday morning cafe with Amanda in the home town! Great start to the day.",
            likeCount: 1,
            commentCount: 1
        ),
        makeVisit(
            id: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
            authorName: "Jamie Chen",
            username: "jamie",
            drinkName: "Orange Creamsicle Espresso Tonic",
            locationName: "A Very Long Cafe Name for Overlay Stress Testing",
            city: "Charleston, SC",
            score: 4.7,
            assetName: "V3TastePassportBackdrop",
            caption: "Bright, sparkling, and exactly right for a hot afternoon.",
            likeCount: 9,
            commentCount: 2
        ),
        makeVisit(
            id: UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!,
            authorName: "Avery Brooks",
            username: "avery",
            drinkName: "Quiet Corner Cortado",
            locationName: "Home espresso bar",
            city: "Charleston, SC",
            score: 4.2,
            assetName: "V3QuietCafeCorner",
            caption: "A calm square frame with enough room for the whole memory.",
            likeCount: 3,
            commentCount: 0,
            context: .home
        ),
        makeVisit(
            id: UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!,
            authorName: "Marco Lee",
            username: "marco",
            drinkName: "Citrus Detail Pour",
            locationName: "Waterfront picnic",
            city: "Charleston, SC",
            score: 4.4,
            assetName: "V3OrangeCitrusDetail",
            caption: "Carousel cover stays in charge of every photo that follows.",
            likeCount: 7,
            commentCount: 3,
            context: .elsewhere
        ),
        makeVisit(
            id: UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff")!,
            authorName: "Sam Rivera",
            username: "sam",
            drinkName: "No-photo Flat White",
            locationName: "Kitchen counter",
            city: "Charleston, SC",
            score: 3.9,
            assetName: nil,
            caption: "The no-photo state keeps the same three-by-four feed rhythm.",
            likeCount: 0,
            commentCount: 0,
            context: .home
        )
    ]

    static func presentation(for route: FeedPostRoute) -> SipDetailPresentation {
        let summary: RemoteVisitSummary
        switch route {
        case .remote(let visit): summary = visit
        case .local:
            summary = visits[0]
        }

        let photos: [SipDetailPhotoSource]
        if summary.id == amandaID {
            photos = [.asset("V3OrangeCreamsicleHeroV2"), .asset("V3QuietCafeCorner")]
        } else if let reference = summary.visit.posterPhotoURL,
                  reference.hasPrefix("asset://") {
            photos = [.asset(String(reference.dropFirst("asset://".count)))]
        } else {
            photos = []
        }

        let content = SipDetailContentModel(
            id: summary.id,
            authorName: summary.authorDisplayName,
            authorUsername: "@\(summary.authorUsername)",
            authorAvatarURL: nil,
            timestamp: "23h",
            visibility: "Friends",
            drinkName: summary.visit.drinkDisplayName,
            locationName: summary.locationTitle,
            locationSubtitle: summary.visit.journalContext == .cafe
                ? MugshotPostLocationLine.locality(
                    from: summary.cafe?.city ?? summary.visit.cityState
                )
                : nil,
            locationSystemImage: summary.visit.journalContext.systemImage,
            score: summary.v3FeedProjection?.mugshotScore ?? summary.visit.overallScore,
            sipScore: summary.visit.overallScore,
            contextScore: nil,
            caption: summary.visit.caption,
            sharedRawNote: nil,
            journalVisibility: nil,
            privateNote: nil,
            recipe: nil,
            taggedAccounts: [],
            photos: photos,
            usesMugsyPhotoFallback: photos.isEmpty,
            ratings: [SipDetailRatingItem(name: "Taste", score: summary.visit.overallScore)],
            contextRatingLabel: nil,
            contextRatings: [],
            sensorySnapshot: nil,
            reactions: [],
            comments: [],
            isLiked: summary.socialState.currentUserHasLiked,
            likeCount: summary.socialState.likeCount,
            isCafeSaved: false,
            replyingToUsername: nil,
            sharePayload: SipShareCardPayload(
                visitID: summary.id,
                visibility: .friends,
                isOwner: summary.id == joeID,
                isRemote: false,
                authorName: summary.authorDisplayName,
                drinkName: summary.visit.drinkDisplayName,
                cafeName: summary.locationTitle,
                rating: summary.visit.overallScore,
                date: summary.visit.createdAtDate,
                publicCaption: summary.visit.caption,
                remotePhotoURL: nil,
                localPhotoPath: nil
            )
        )

        return SipDetailPresentation(
            content: content,
            capabilities: .friend(
                hasCafe: summary.visit.journalContext == .cafe,
                canComment: true,
                canRecommend: true,
                canShareExternally: false
            )
        )
    }

    private static var maximumCaption: String {
        let sentence = "Birthday morning cafe with Amanda, warm light, a silky finish, and enough cinnamon to make the whole walk worth remembering. "
        return String(String(repeating: sentence, count: 10).prefix(SipCaptionPolicy.maximumLength))
    }

    private static func makeVisit(
        id: UUID,
        authorName: String,
        username: String,
        drinkName: String,
        locationName: String,
        city: String?,
        score: Double,
        assetName: String?,
        caption: String,
        likeCount: Int,
        commentCount: Int,
        context: JournalEntryContext = .cafe
    ) -> RemoteVisitSummary {
        let userID = UUID()
        return RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: id,
                userId: userID,
                cafeId: context == .cafe ? UUID() : nil,
                drinkType: "Coffee",
                drinkTypeCustom: nil,
                drinkSubtype: drinkName,
                caption: caption,
                notes: nil,
                visibility: "friends",
                ratings: ["Taste": score],
                overallScore: score,
                posterPhotoURL: assetName.map { "asset://\($0)" },
                contextType: context.rawValue,
                locationName: locationName,
                cityState: city,
                brewMethod: nil,
                createdAt: "2026-07-30T14:00:00Z"
            ),
            cafe: context == .cafe
                ? SupabaseCafeSummary(
                    id: UUID(),
                    name: locationName,
                    address: nil,
                    city: city,
                    latitude: nil,
                    longitude: nil,
                    applePlaceId: nil,
                    websiteURL: nil
                )
                : nil,
            author: SupabaseUserProfile(
                id: userID,
                displayName: authorName,
                username: username,
                bio: nil,
                location: nil,
                favoriteDrink: nil,
                instagramHandle: nil,
                avatarURL: nil,
                bannerURL: nil,
                websiteURL: nil
            ),
            socialState: RemoteVisitSocialState(
                likeCount: likeCount,
                commentCount: commentCount,
                currentUserHasLiked: id == joeID
            ),
            v3FeedProjection: RemoteVisitV3FeedProjection(
                visitID: id,
                mugshotScore: score,
                photoFallbackValue: assetName == nil ? SipPhotoFallback.mugsyMissedPhoto.rawValue : nil
            )
        )
    }
}
#endif
