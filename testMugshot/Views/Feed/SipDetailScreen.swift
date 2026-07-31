import SwiftUI

// MARK: - Value model

enum SipDetailPresentationMode: Equatable {
    case pushed
    case postSave

    var dismissIcon: String {
        switch self {
        case .pushed: "chevron.left"
        case .postSave: "xmark"
        }
    }

    var dismissLabel: String {
        switch self {
        case .pushed: "Back"
        case .postSave: "Close sip"
        }
    }
}

enum SipDetailPhotoSource: Identifiable, Equatable {
    case local(String)
    case remote(String)
    case asset(String)

    var id: String {
        switch self {
        case .local(let path): "local-\(path)"
        case .remote(let url): "remote-\(url)"
        case .asset(let name): "asset-\(name)"
        }
    }

    var postMediaSource: MugshotPostMediaSource {
        switch self {
        case .local(let path): .local(path)
        case .remote(let url): .remote(url)
        case .asset(let name): .asset(name)
        }
    }
}

struct SipDetailPhotoViewerPresentation: Identifiable, Equatable {
    let id = UUID()
    let photos: [SipDetailPhotoSource]
    let initialIndex: Int
    let drinkName: String
    let locationName: String

    static func == (lhs: SipDetailPhotoViewerPresentation, rhs: SipDetailPhotoViewerPresentation) -> Bool {
        lhs.id == rhs.id
    }
}

struct SipDetailRatingItem: Identifiable, Equatable {
    let name: String
    let score: Double

    var id: String { name }
}

struct SipDetailReactionSummary: Identifiable, Equatable {
    let title: String
    let systemImage: String
    let count: Int

    var id: String { title }
}

struct SipDetailCommentAction: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let isDestructive: Bool
}

enum SipDetailCommentActionPolicy {
    static func actions(
        commentOwnerID: UUID,
        postOwnerID: UUID,
        viewerID: UUID?
    ) -> [SipDetailCommentAction] {
        if commentOwnerID == viewerID {
            return [
                SipDetailCommentAction(
                    id: "edit",
                    title: "Edit comment",
                    systemImage: "pencil",
                    isDestructive: false
                ),
                SipDetailCommentAction(
                    id: "remove",
                    title: "Remove comment",
                    systemImage: "trash",
                    isDestructive: true
                )
            ]
        }

        var actions: [SipDetailCommentAction] = []
        if postOwnerID == viewerID {
            actions.append(SipDetailCommentAction(
                id: "remove",
                title: "Remove from your post",
                systemImage: "trash",
                isDestructive: true
            ))
        }
        actions.append(SipDetailCommentAction(
            id: "report",
            title: "Report comment",
            systemImage: "exclamationmark.bubble",
            isDestructive: true
        ))
        return actions
    }
}

struct SipDetailCommentModel: Identifiable, Equatable {
    let id: UUID
    let authorName: String
    let username: String
    let text: String
    let timestamp: String
    let canReply: Bool
    let actions: [SipDetailCommentAction]

    init(
        id: UUID,
        authorName: String,
        username: String,
        text: String,
        timestamp: String,
        canReply: Bool,
        actions: [SipDetailCommentAction] = []
    ) {
        self.id = id
        self.authorName = authorName
        self.username = username
        self.text = text
        self.timestamp = timestamp
        self.canReply = canReply
        self.actions = actions
    }
}

struct SipDetailMentionSuggestion: Identifiable, Equatable {
    let id: UUID
    let username: String
}

enum SipDetailSection: String, CaseIterable, Equatable {
    case note
    case rawNote
    case sharedMugshot
    case recipe
    case taggedPeople
    case actions
    case friendsNoticed
    case taste
    case contextEvidence
    case privateNote
    case conversation
}

struct SipDetailSharedMugshotContribution: Identifiable, Equatable {
    let visitID: UUID
    let personName: String
    let username: String
    let avatarURL: String?
    let drinkName: String
    let caption: String?
    let score: Double
    let posterPhotoURL: String?
    let isCurrentPost: Bool

    var id: UUID { visitID }
}

struct SipDetailSharedMugshotModel: Equatable {
    let locationLabel: String?
    let contributions: [SipDetailSharedMugshotContribution]
}

enum SipDetailRecipeAccessState: Equatable {
    case available
    case locked
}

enum SipDetailRecipeAction: Equatable {
    case brewAgain
    case saveAndAdapt
}

struct SipDetailRecipeModel: Identifiable, Equatable {
    let id: UUID
    let recipeIdentityID: UUID?
    let recipeVersionID: UUID?
    let name: String
    let versionLabel: String?
    let creatorName: String
    let creatorUsername: String
    let accessState: SipDetailRecipeAccessState
    let visibility: String?
    let sourceKind: String?
    let brewMethod: String?
    let equipment: String?
    let details: BrewDetails?
    let canSaveAndAdapt: Bool
    let canBrewAgain: Bool

    var suggestedAdaptationName: String {
        let base = name.remoteTrimmedNonEmpty ?? "Saved recipe"
        let suffix = " Adaptation"
        guard base.count + suffix.count <= 120 else {
            return String(base.prefix(120 - suffix.count)) + suffix
        }
        return base + suffix
    }
}

struct SipDetailTaggedAccount: Identifiable, Equatable {
    let userID: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
    let isCurrentUser: Bool

    var id: UUID { userID }
}

enum SipDetailAction: String, CaseIterable, Identifiable, Equatable {
    case like
    case comment
    case saveCafe
    case share
    case recommend
    case more
    case edit
    case correctDrink
    case repeatSip
    case delete
    case report
    case block

    var id: String { rawValue }

    var title: String {
        switch self {
        case .like: "Like"
        case .comment: "Comment"
        case .saveCafe: "Save cafe"
        case .share: "Share"
        case .recommend: "Recommend"
        case .more: "More"
        case .edit: "Edit Sip"
        case .correctDrink: "Correct Drink Details"
        case .repeatSip: "Repeat Sip"
        case .delete: "Delete Sip"
        case .report: "Report Sip"
        case .block: "Block User"
        }
    }

    var systemImage: String {
        switch self {
        case .like: "heart"
        case .comment: "bubble.right"
        case .saveCafe: "bookmark"
        case .share: "square.and.arrow.up"
        case .recommend: "paperplane"
        case .more: "ellipsis"
        case .edit: "pencil"
        case .correctDrink: "slider.horizontal.3"
        case .repeatSip: "plus.square.on.square"
        case .delete: "trash"
        case .report: "exclamationmark.bubble"
        case .block: "hand.raised"
        }
    }
}

enum SipDetailInteractionGate {
    static func requiresAuthentication(
        for action: SipDetailAction,
        currentUserID: UUID?
    ) -> Bool {
        guard currentUserID == nil else { return false }
        switch action {
        case .like, .comment, .saveCafe, .recommend, .report, .block:
            return true
        case .share, .more, .edit, .correctDrink, .repeatSip, .delete:
            return false
        }
    }
}

struct SipDetailCapabilities: Equatable {
    let isOwner: Bool
    let dockActions: [SipDetailAction]
    let menuActions: [SipDetailAction]
    let canComment: Bool

    static func owner(
        hasCafe: Bool,
        canComment: Bool,
        canRepeat: Bool,
        canCorrectDrink: Bool = true
    ) -> SipDetailCapabilities {
        var dock: [SipDetailAction] = [.comment]
        if hasCafe { dock.append(.saveCafe) }
        dock.append(.share)
        dock.append(.more)

        var menu: [SipDetailAction] = [.edit]
        if canCorrectDrink { menu.append(.correctDrink) }
        if canRepeat { menu.append(.repeatSip) }
        menu.append(.delete)

        return SipDetailCapabilities(
            isOwner: true,
            dockActions: Array(dock.prefix(4)),
            menuActions: menu,
            canComment: canComment
        )
    }

    static func friend(
        hasCafe: Bool,
        canComment: Bool,
        canRecommend: Bool,
        canShareExternally: Bool
    ) -> SipDetailCapabilities {
        var dock: [SipDetailAction] = [.like, .comment]
        if hasCafe { dock.append(.saveCafe) }
        if canRecommend {
            dock.append(.recommend)
        } else if canShareExternally {
            dock.append(.share)
        }
        if dock.count < 4 {
            dock.append(.more)
        }

        var menu: [SipDetailAction] = []
        if canRecommend && canShareExternally {
            menu.append(.share)
        }
        menu.append(contentsOf: [.report, .block])

        return SipDetailCapabilities(
            isOwner: false,
            dockActions: Array(dock.prefix(4)),
            menuActions: menu,
            canComment: canComment
        )
    }
}

struct SipDetailContentModel: Identifiable, Equatable {
    let id: UUID
    let authorName: String
    let authorUsername: String
    let authorAvatarURL: String?
    let timestamp: String
    let visibility: String
    let drinkName: String
    let locationName: String
    let locationSubtitle: String?
    let locationSystemImage: String
    /// The whole-memory score shown on the post.
    let score: Double
    /// The independent drink score used inside taste evidence.
    let sipScore: Double
    /// The optional Cafe, Home, or Elsewhere context score supporting the Mugshot score.
    let contextScore: Double?
    let caption: String?
    let sharedRawNote: String?
    let privateNote: String?
    let sharedMugshot: SipDetailSharedMugshotModel?
    let recipe: SipDetailRecipeModel?
    let taggedAccounts: [SipDetailTaggedAccount]
    let photos: [SipDetailPhotoSource]
    let usesMugsyPhotoFallback: Bool
    let ratings: [SipDetailRatingItem]
    let contextRatingLabel: String?
    let contextRatings: [SipDetailRatingItem]
    let sensorySnapshot: SipSensorySnapshot?
    let reactions: [SipDetailReactionSummary]
    let comments: [SipDetailCommentModel]
    let isLiked: Bool
    let likeCount: Int
    let isCafeSaved: Bool
    let replyingToUsername: String?
    let sharePayload: SipShareCardPayload

    func visibleSections(capabilities: SipDetailCapabilities) -> [SipDetailSection] {
        var sections: [SipDetailSection] = []
        if caption != nil { sections.append(.note) }
        if sharedRawNote != nil { sections.append(.rawNote) }
        if sharedMugshot != nil { sections.append(.sharedMugshot) }
        if recipe != nil { sections.append(.recipe) }
        if !taggedAccounts.isEmpty { sections.append(.taggedPeople) }
        if !capabilities.dockActions.isEmpty { sections.append(.actions) }
        if !reactions.isEmpty { sections.append(.friendsNoticed) }
        if sipScore > 0 || !ratings.isEmpty || sensorySnapshot != nil { sections.append(.taste) }
        if !contextRatings.isEmpty { sections.append(.contextEvidence) }
        if capabilities.isOwner, privateNote != nil { sections.append(.privateNote) }
        if capabilities.canComment || !comments.isEmpty { sections.append(.conversation) }
        return sections
    }
}

struct SipDetailPresentation: Equatable {
    let content: SipDetailContentModel
    let capabilities: SipDetailCapabilities
}

enum SipDetailPresentationAdapter {
    static func remote(
        detail: RemoteVisitDetail,
        currentUserID: UUID?,
        reactions: [SipReactionRecord],
        isCafeSaved: Bool,
        canRecommend: Bool,
        canRepeat: Bool,
        replyingToUsername: String?
    ) -> SipDetailPresentation {
        let visit = detail.summary.visit
        let isOwner = visit.userId == currentUserID
        let authorName = detail.summary.authorDisplayName
        let caption = consumerCaption(visit.caption)
        let rawNote = combinedRawNote(detail.v3Reflection, context: visit.journalContext)
        let displayedScore = detail.v3Reflection?.mugshotScore
            ?? detail.summary.v3FeedProjection?.mugshotScore
            ?? visit.overallScore
        let usesMugsyPhotoFallback = detail.v3Reflection.map {
            $0.photoFallback == .mugsyMissedPhoto
        } ?? detail.summary.usesMugsyPhotoFallback
        let reactionSummaries = Dictionary(grouping: reactions, by: \SipReactionRecord.reaction)
            .map { reaction, records in
                SipDetailReactionSummary(
                    title: reaction.title,
                    systemImage: reaction.systemImage,
                    count: records.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.title < rhs.title }
                return lhs.count > rhs.count
            }

        let content = SipDetailContentModel(
            id: detail.id,
            authorName: authorName,
            authorUsername: "@\(detail.summary.authorUsername)",
            authorAvatarURL: detail.summary.author?.avatarURL,
            timestamp: SipDetailFormat.timestamp(visit.createdAtDate),
            visibility: audienceLabel(visit.visibility),
            drinkName: visit.drinkDisplayName,
            locationName: detail.summary.locationTitle,
            locationSubtitle: visit.journalContext == .cafe
                ? MugshotPostLocationLine.locality(
                    from: detail.summary.cafe?.city ?? visit.cityState
                )
                : nil,
            locationSystemImage: visit.journalContext.systemImage,
            score: displayedScore,
            sipScore: detail.v3Reflection?.sipScore ?? visit.overallScore,
            contextScore: detail.v3Reflection?.contextScore,
            caption: caption,
            sharedRawNote: rawNote,
            privateNote: isOwner && detail.v3Reflection == nil
                ? detail.privateNote?.remoteTrimmedNonEmpty
                : nil,
            sharedMugshot: sharedMugshotModel(
                detail.sharedMugshotProjection,
                currentVisitID: detail.id
            ),
            recipe: remoteRecipeModel(
                detail,
                isOwner: isOwner,
                canRepeat: canRepeat
            ),
            taggedAccounts: detail.taggedAccounts.map { tag in
                SipDetailTaggedAccount(
                    userID: tag.userID,
                    displayName: tag.personLabel,
                    username: "@\(tag.username)",
                    avatarURL: tag.avatarURL,
                    isCurrentUser: tag.userID == currentUserID
                )
            },
            photos: detail.photoURLs.map(SipDetailPhotoSource.remote),
            usesMugsyPhotoFallback: usesMugsyPhotoFallback,
            ratings: visit.orderedRatingScores.map {
                SipDetailRatingItem(name: $0.name, score: $0.score)
            },
            contextRatingLabel: detail.v3Reflection.map { _ in
                contextRatingLabel(for: visit.journalContext)
            },
            contextRatings: detail.v3Reflection?.contextCriteria
                .filter { $0.score > 0 }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { SipDetailRatingItem(name: $0.name, score: $0.score) }
                ?? [],
            sensorySnapshot: isOwner ? detail.sensorySnapshot : nil,
            reactions: reactionSummaries,
            comments: detail.comments.map { comment in
                SipDetailCommentModel(
                    id: comment.id,
                    authorName: comment.authorDisplayName,
                    username: "@\(comment.authorUsername)",
                    text: comment.comment.text,
                    timestamp: SipDetailFormat.relative(comment.comment.createdAtDate),
                    canReply: currentUserID != nil && comment.comment.parentCommentId == nil,
                    actions: SipDetailCommentActionPolicy.actions(
                        commentOwnerID: comment.comment.userId,
                        postOwnerID: visit.userId,
                        viewerID: currentUserID
                    )
                )
            },
            isLiked: detail.currentUserHasLiked,
            likeCount: detail.likeCount,
            isCafeSaved: isCafeSaved,
            replyingToUsername: replyingToUsername,
            sharePayload: SipShareCardPayload(
                visitID: visit.id,
                visibility: .supabaseValue(visit.visibility),
                isOwner: isOwner,
                isRemote: true,
                authorName: detail.summary.authorDisplayName,
                drinkName: visit.drinkDisplayName,
                cafeName: detail.summary.locationTitle,
                rating: displayedScore,
                date: visit.createdAtDate,
                publicCaption: caption,
                remotePhotoURL: detail.photoURLs.first,
                localPhotoPath: nil
            )
        )

        let capabilities = isOwner
            ? SipDetailCapabilities.owner(
                hasCafe: visit.journalContext == .cafe && detail.summary.cafe != nil,
                canComment: currentUserID != nil,
                canRepeat: canRepeat
            )
            : SipDetailCapabilities.friend(
                hasCafe: visit.journalContext == .cafe && detail.summary.cafe != nil,
                canComment: currentUserID != nil,
                canRecommend: canRecommend,
                canShareExternally: visit.visibility.lowercased() == "everyone"
            )

        return SipDetailPresentation(content: content, capabilities: capabilities)
    }

    static func local(
        visit: Visit,
        cafe: Cafe?,
        user: User?,
        comments: [Comment],
        isCafeSaved: Bool
    ) -> SipDetailPresentation {
        let isOwner = user?.id == visit.userId
        let authorDisplayName = user?.displayNameOrUsername ?? "Mugshot User"
        let caption = consumerCaption(visit.caption)
        let orderedPhotos = orderedLocalPhotos(visit)
        let rawNote = combinedRawNote(visit.v3Reflection, context: visit.context)
        let displayedScore = visit.v3Reflection?.mugshotScore ?? visit.overallScore
        let ratings = visit.ratingCriteria
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { $0.score > 0 }
            .map { SipDetailRatingItem(name: $0.name, score: $0.score) }
        let fallbackRatings = visit.ratings.keys.sorted().compactMap { name -> SipDetailRatingItem? in
            guard let score = visit.ratings[name] else { return nil }
            return SipDetailRatingItem(name: name, score: score)
        }

        let content = SipDetailContentModel(
            id: visit.id,
            authorName: authorDisplayName,
            authorUsername: "@\(user?.username ?? "user")",
            authorAvatarURL: nil,
            timestamp: SipDetailFormat.timestamp(visit.createdAt),
            visibility: visit.visibility == .everyone ? "Public" : visit.visibility.rawValue,
            drinkName: visit.journalDrinkName,
            locationName: visit.context == .cafe
                ? (cafe?.consumerDisplayName ?? "Cafe")
                : (visit.locationName?.remoteTrimmedNonEmpty ?? visit.context.locationFallback),
            locationSubtitle: visit.context == .cafe
                ? MugshotPostLocationLine.locality(from: cafe?.address)
                : nil,
            locationSystemImage: visit.context.systemImage,
            score: displayedScore,
            sipScore: visit.v3Reflection?.sipScore ?? visit.overallScore,
            contextScore: visit.v3Reflection?.contextScore,
            caption: caption,
            sharedRawNote: rawNote,
            privateNote: isOwner && visit.v3Reflection == nil
                ? visit.notes?.remoteTrimmedNonEmpty
                : nil,
            sharedMugshot: nil,
            recipe: localRecipeModel(
                visit,
                creatorName: authorDisplayName,
                creatorUsername: "@\(user?.username ?? "user")"
            ),
            taggedAccounts: [],
            photos: orderedPhotos.map(SipDetailPhotoSource.local),
            usesMugsyPhotoFallback: visit.v3Reflection?.photoFallback == .mugsyMissedPhoto,
            ratings: ratings.isEmpty ? fallbackRatings : ratings,
            contextRatingLabel: visit.v3Reflection.map { _ in
                contextRatingLabel(for: visit.context)
            },
            contextRatings: visit.v3Reflection?.contextCriteria
                .filter { $0.score > 0 }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { SipDetailRatingItem(name: $0.name, score: $0.score) }
                ?? [],
            sensorySnapshot: isOwner ? visit.sensorySnapshot : nil,
            reactions: [],
            comments: comments.map { comment in
                SipDetailCommentModel(
                    id: comment.id,
                    authorName: comment.userId == user?.id ? authorDisplayName : "Mugshot User",
                    username: comment.userId == user?.id ? "@\(user?.username ?? "user")" : "@user",
                    text: comment.text,
                    timestamp: SipDetailFormat.relative(comment.createdAt),
                    canReply: false
                )
            },
            isLiked: user.map { visit.isLikedBy(userId: $0.id) } ?? false,
            likeCount: visit.likeCount,
            isCafeSaved: isCafeSaved,
            replyingToUsername: nil,
            sharePayload: SipShareCardPayload(
                visitID: visit.id,
                visibility: visit.visibility,
                isOwner: isOwner,
                isRemote: false,
                authorName: authorDisplayName,
                drinkName: visit.journalDrinkName,
                cafeName: visit.context == .cafe
                    ? (cafe?.consumerDisplayName ?? "Cafe")
                    : (visit.locationName?.remoteTrimmedNonEmpty ?? visit.context.locationFallback),
                rating: displayedScore,
                date: visit.createdAt,
                publicCaption: caption,
                remotePhotoURL: nil,
                localPhotoPath: orderedPhotos.first
            )
        )

        let capabilities = isOwner
            ? SipDetailCapabilities.owner(
                hasCafe: visit.context == .cafe && cafe != nil,
                canComment: user != nil,
                canRepeat: false,
                canCorrectDrink: false
            )
            : SipDetailCapabilities.friend(
                hasCafe: visit.context == .cafe && cafe != nil,
                canComment: user != nil,
                canRecommend: false,
                canShareExternally: visit.visibility == .everyone
            )

        return SipDetailPresentation(content: content, capabilities: capabilities)
    }

    private static func consumerCaption(_ caption: String) -> String? {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let internalMarkers = ["smoke", "photo-required", "ui pass", "polish pass"]
        guard !internalMarkers.contains(where: trimmed.lowercased().contains) else { return nil }
        return trimmed
    }

    private static func combinedRawNote(
        _ reflection: V3VisitReflection?,
        context: JournalEntryContext
    ) -> String? {
        guard let reflection else { return nil }
        var sections: [String] = []
        if let sip = reflection.sipRawNote?.remoteTrimmedNonEmpty {
            sections.append("Sip\n\(sip)")
        }
        if let contextNote = reflection.contextRawNote?.remoteTrimmedNonEmpty {
            sections.append("\(contextRatingLabel(for: context))\n\(contextNote)")
        }
        return sections.joined(separator: "\n\n").remoteTrimmedNonEmpty
    }

    private static func contextRatingLabel(for context: JournalEntryContext) -> String {
        context == .cafe ? "Cafe" : "Setting"
    }

    private static func audienceLabel(_ visibility: String) -> String {
        switch visibility.lowercased() {
        case "everyone": "Public"
        case "friends": "Friends"
        case "private": "Private"
        default: visibility.capitalized
        }
    }

    private static func remoteRecipeModel(
        _ detail: RemoteVisitDetail,
        isOwner: Bool,
        canRepeat: Bool
    ) -> SipDetailRecipeModel? {
        let visit = detail.summary.visit
        guard let referencedVersionID = visit.recipeVersionID else { return nil }

        if let projection = detail.recipeProjection {
            let owner = projection.owner
            return SipDetailRecipeModel(
                id: projection.recipeVersionID,
                recipeIdentityID: projection.recipeIdentityID,
                recipeVersionID: projection.recipeVersionID,
                name: projection.recipeName,
                versionLabel: projection.versionLabel?.remoteTrimmedNonEmpty
                    ?? "Version \(projection.versionNumber)",
                creatorName: owner?.personLabel ?? detail.summary.authorDisplayName,
                creatorUsername: "@\(owner?.username ?? detail.summary.authorUsername)",
                accessState: .available,
                visibility: audienceLabel(projection.visibilityValue),
                sourceKind: projection.sourceKindValue
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized,
                brewMethod: projection.brewMethod?.remoteTrimmedNonEmpty,
                equipment: projection.equipment?.remoteTrimmedNonEmpty,
                details: projection.resolvedBrewDetails,
                canSaveAndAdapt: !isOwner && projection.canSaveAndAdapt,
                canBrewAgain: isOwner && canRepeat
            )
        }

        // The identity-only RPC is deliberately separate from the protected
        // blueprint projection. Never fall back to visit brew payload when
        // the caller-bound full projection is unavailable.
        let identity = detail.recipeIdentityProjection
        return SipDetailRecipeModel(
            id: referencedVersionID,
            recipeIdentityID: identity?.recipeIdentityID,
            recipeVersionID: referencedVersionID,
            name: identity?.recipeName.remoteTrimmedNonEmpty ?? "Private recipe",
            versionLabel: identity?.versionLabel?.remoteTrimmedNonEmpty
                ?? identity.map { "Version \($0.versionNumber)" },
            creatorName: identity?.ownerLabel ?? detail.summary.authorDisplayName,
            creatorUsername: "@\(identity?.ownerUsername ?? detail.summary.authorUsername)",
            accessState: .locked,
            visibility: nil,
            sourceKind: nil,
            brewMethod: nil,
            equipment: nil,
            details: nil,
            canSaveAndAdapt: false,
            canBrewAgain: false
        )
    }

    private static func localRecipeModel(
        _ visit: Visit,
        creatorName: String,
        creatorUsername: String
    ) -> SipDetailRecipeModel? {
        guard visit.context == .recipe else { return nil }
        let identityID = visit.brewDetails.recipeIdentityID
        return SipDetailRecipeModel(
            id: identityID ?? visit.id,
            recipeIdentityID: identityID,
            recipeVersionID: nil,
            name: visit.brewDetails.recipeName?.remoteTrimmedNonEmpty ?? "Saved recipe",
            versionLabel: visit.brewDetails.recipeVersion?.remoteTrimmedNonEmpty,
            creatorName: creatorName,
            creatorUsername: creatorUsername,
            accessState: .available,
            visibility: nil,
            sourceKind: nil,
            brewMethod: visit.brewMethod?.remoteTrimmedNonEmpty,
            equipment: visit.equipment?.remoteTrimmedNonEmpty,
            details: visit.brewDetails,
            canSaveAndAdapt: false,
            canBrewAgain: false
        )
    }

    private static func orderedLocalPhotos(_ visit: Visit) -> [String] {
        guard !visit.photos.isEmpty else { return [] }
        var ordered = visit.photos
        if let poster = visit.posterImagePath,
           let posterIndex = ordered.firstIndex(of: poster) {
            ordered.remove(at: posterIndex)
            ordered.insert(poster, at: 0)
        }
        return ordered
    }

    private static func sharedMugshotModel(
        _ projection: RemoteSharedMugshotProjection?,
        currentVisitID: UUID
    ) -> SipDetailSharedMugshotModel? {
        guard let projection,
              let contributions = projection.groupedContributions else {
            return nil
        }
        return SipDetailSharedMugshotModel(
            locationLabel: projection.locationLabel?.remoteTrimmedNonEmpty,
            contributions: contributions.map { contribution in
                SipDetailSharedMugshotContribution(
                    visitID: contribution.visitID,
                    personName: contribution.personLabel,
                    username: "@\(contribution.username)",
                    avatarURL: contribution.avatarURL,
                    drinkName: contribution.drink,
                    caption: contribution.caption?.remoteTrimmedNonEmpty,
                    score: contribution.overallScore,
                    posterPhotoURL: contribution.posterPhotoURL,
                    isCurrentPost: contribution.visitID == currentVisitID
                )
            }
        )
    }
}

// MARK: - Shared Immersive Pour screen

struct SipDetailToolbarTitle: View {
    let drinkName: String
    let progress: CGFloat

    private var normalizedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Text("MUGSHOT")
                .font(.system(size: 12, weight: .black))
                .tracking(2.2)
                .foregroundStyle(Color.mugshotSage)
                .opacity(1 - normalizedProgress)
                .accessibilityHidden(normalizedProgress > 0.5)

            Text(drinkName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.espressoBrown)
                .lineLimit(1)
                .opacity(normalizedProgress)
                .accessibilityHidden(normalizedProgress <= 0.5)
        }
        .animation(.easeOut(duration: 0.16), value: normalizedProgress)
    }
}

struct SipDetailScreen: View {
    let presentation: SipDetailPresentation
    @Binding var selectedPhotoIndex: Int
    @Binding var commentText: String
    @Binding var toolbarProgress: CGFloat
    let commentFocus: FocusState<Bool>.Binding
    let isWorking: Bool
    let statusMessage: String?
    let mentionSuggestions: [SipDetailMentionSuggestion]
    let onAction: (SipDetailAction) -> Void
    let onSubmitComment: () -> Void
    let onReply: (UUID) -> Void
    let onCommentAction: (UUID, SipDetailCommentAction) -> Void
    let onCancelReply: () -> Void
    let onSelectMention: (UUID) -> Void
    let onPhotoTap: (Int) -> Void
    let onRecipeAction: (SipDetailRecipeAction) -> Void
    let onTaggedAccount: (UUID) -> Void
    let onRemoveOwnTag: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isTasteExpanded = false
    @State private var isJournalExpanded = false
    @State private var isComposerPresented = false
    @State private var tasteReveal: CGFloat = 0

    private let heroAnchor = "sip-detail-hero"
    private let commentsAnchor = "sip-detail-comments"

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        SipDetailHero(
                            model: presentation.content,
                            selectedPhotoIndex: $selectedPhotoIndex,
                            onPhotoTap: onPhotoTap
                        )
                        .id(heroAnchor)

                        contentSurface(proxy: proxy)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    let collapseDistance = max(heroHeight(for: viewport.size.width) - 84, 1)
                    toolbarProgress = MugshotMotion.normalized(max(offset, 0) / collapseDistance)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isComposerPresented {
                        SipDetailComposerBar(
                            text: $commentText,
                            replyingToUsername: presentation.content.replyingToUsername,
                            isWorking: isWorking,
                            mentionSuggestions: mentionSuggestions,
                            focus: commentFocus,
                            onCancelReply: onCancelReply,
                            onSelectMention: onSelectMention,
                            onSubmit: onSubmitComment
                        )
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(Color.creamWhite)
            }
        }
        .background(Color.creamWhite)
        .accessibilityIdentifier("sip.detail.screen")
        .accessibilityElement(children: .contain)
        .onChange(of: commentFocus.wrappedValue) { _, isFocused in
            guard !isFocused, commentText.remoteTrimmedNonEmpty == nil else { return }
            withAnimation(MugshotMotion.animation(MugshotMotion.response, reduceMotion: reduceMotion)) {
                isComposerPresented = false
            }
        }
    }

    private func heroHeight(for width: CGFloat) -> CGFloat {
        let authorHeight: CGFloat = dynamicTypeSize.isAccessibilitySize ? 116 : 82
        let source = presentation.content.photos.first?.postMediaSource
            ?? .placeholder(usesMugsyFallback: presentation.content.usesMugsyPhotoFallback)
        let ratio = MugshotPostAspectRatioCache.shared.ratio(for: source.cacheKey)
            ?? MugshotPostAspectRatioPolicy.fallback
        let mediaHeight = max(width - 40, 1) / ratio
        return authorHeight + mediaHeight + 12
    }

    private func contentSurface(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SipDetailPostSummary(model: presentation.content)
                .padding(.horizontal, 22)
                .padding(.top, 24)

            SipDetailActionDock(
                actions: presentation.capabilities.dockActions,
                model: presentation.content,
                isWorking: isWorking,
                onAction: { action in handle(action, proxy: proxy) }
            )
            .padding(.horizontal, 22)
            .padding(.top, 12)

            if let statusMessage {
                SipDetailStatusBanner(message: statusMessage)
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
            }

            if !presentation.content.reactions.isEmpty {
                SipSocialProofSection(model: presentation.content)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
            }

            if presentation.content.score > 0
                || presentation.content.sipScore > 0
                || !presentation.content.ratings.isEmpty
                || !presentation.content.contextRatings.isEmpty
                || presentation.content.sensorySnapshot != nil {
                SipTasteEvidenceSection(
                    model: presentation.content,
                    isExpanded: $isTasteExpanded,
                    revealProgress: tasteReveal
                )
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .onChange(of: isTasteExpanded) { _, isExpanded in
                    guard isExpanded else { return }
                    revealTaste()
                }
            }

            if let sharedMugshot = presentation.content.sharedMugshot {
                SipSharedMugshotSection(model: sharedMugshot)
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
            }

            if let recipe = presentation.content.recipe {
                SipDetailRecipeSection(
                    model: recipe,
                    isWorking: isWorking,
                    onAction: onRecipeAction
                )
                .padding(.horizontal, 22)
                .padding(.top, 20)
            }

            if !presentation.content.taggedAccounts.isEmpty {
                SipDetailTaggedPeopleSection(
                    accounts: presentation.content.taggedAccounts,
                    isWorking: isWorking,
                    onOpenProfile: onTaggedAccount,
                    onRemoveOwnTag: onRemoveOwnTag
                )
                .padding(.horizontal, 22)
                .padding(.top, 14)
            }

            if let rawNote = presentation.content.sharedRawNote {
                SipSharedRawNoteSection(
                    text: rawNote,
                    visibility: presentation.content.visibility,
                    isExpanded: $isJournalExpanded
                )
                .padding(.horizontal, 22)
                .padding(.top, 14)
            }

            if presentation.capabilities.isOwner,
               let privateNote = presentation.content.privateNote {
                SipPrivateNoteSection(text: privateNote)
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
            }

            if presentation.capabilities.canComment || !presentation.content.comments.isEmpty {
                SipConversationSection(
                    comments: presentation.content.comments,
                    canComment: presentation.capabilities.canComment,
                    onReply: { commentID in
                        onReply(commentID)
                        focusComposer(proxy: proxy)
                    },
                    onCompose: { focusComposer(proxy: proxy) },
                    onCommentAction: onCommentAction
                )
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .id(commentsAnchor)
            }
        }
        .padding(.bottom, 42)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.creamWhite)
    }

    private func handle(_ action: SipDetailAction, proxy: ScrollViewProxy) {
        if action == .comment {
            guard presentation.capabilities.canComment else {
                onAction(.comment)
                return
            }
            focusComposer(proxy: proxy)
            return
        }
        if action == .like || action == .saveCafe {
            MugshotHaptic.softImpact.play()
        }
        onAction(action)
    }

    private func focusComposer(proxy: ScrollViewProxy) {
        withAnimation(MugshotMotion.animation(MugshotMotion.response, reduceMotion: reduceMotion)) {
            proxy.scrollTo(commentsAnchor, anchor: .bottom)
            isComposerPresented = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 20 : 140))
            commentFocus.wrappedValue = true
            onAction(.comment)
        }
    }

    private func revealTaste() {
        guard tasteReveal == 0 else { return }
        if reduceMotion {
            tasteReveal = 1
        } else {
            withAnimation(.easeOut(duration: 0.64)) {
                tasteReveal = 1
            }
        }
    }
}

private struct SipDetailStatusBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "info.circle.fill")
            .font(.system(.footnote, design: .default, weight: .semibold))
            .foregroundStyle(Color.espressoBrown)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(
                Color.sandBeige.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
            .accessibilityIdentifier("sip.detail.status")
    }
}

private struct SipSharedMugshotSection: View {
    let model: SipDetailSharedMugshotModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(width: 38, height: 38)
                    .background(Color.mugshotMint.opacity(0.34), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Shared MugShot")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text(model.locationLabel?.remoteTrimmedNonEmpty
                         ?? "One moment, independently remembered")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                }
            }

            VStack(spacing: 10) {
                ForEach(model.contributions) { contribution in
                    HStack(spacing: 11) {
                        PhotoThumbnailView(
                            photoPath: contribution.posterPhotoURL,
                            size: 54
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(contribution.personName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.espressoBrown)
                                if contribution.isCurrentPost {
                                    Text("This post")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.mugshotSage)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.mugshotMint.opacity(0.34), in: Capsule())
                                }
                            }
                            Text("\(contribution.drinkName) · \(contribution.score.formatted(.number.precision(.fractionLength(1))))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.secondaryText)
                            if let caption = contribution.caption {
                                Text(caption)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(contribution.personName), \(contribution.drinkName), score \(contribution.score.formatted(.number.precision(.fractionLength(1))))"
                    )
                }
            }

            Text("Each person keeps their own post and audience. This grouped view only includes MugShots you can already see.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sip.detail.sharedMugshot")
    }
}

private struct SipDetailRecipeSection: View {
    let model: SipDetailRecipeModel
    let isWorking: Bool
    let onAction: (SipDetailRecipeAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.accessState == .locked ? "lock.fill" : "book.pages.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(width: 38, height: 38)
                    .background(Color.mugshotMint.opacity(0.34), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.espressoBrown)
                    HStack(spacing: 5) {
                        if let version = model.versionLabel {
                            Text(version)
                        }
                        Text("by \(model.creatorUsername)")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                }
                Spacer(minLength: 0)
            }

            if model.accessState == .locked {
                lockedContent
            } else {
                availableContent
            }

            if model.canBrewAgain {
                recipeButton(
                    title: "Brew Again",
                    systemImage: "arrow.clockwise.circle.fill",
                    action: .brewAgain
                )
            } else if model.canSaveAndAdapt {
                recipeButton(
                    title: "Save & Adapt",
                    systemImage: "square.and.pencil",
                    action: .saveAndAdapt
                )
            }
        }
        .padding(16)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sip.detail.recipe")
    }

    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Private blueprint", systemImage: "lock.shield.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.espressoBrown)
            Text("You can see which recipe inspired this MugShot, but its method, equipment, quantities, and steps stay private.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sandBeige.opacity(0.66), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var availableContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            if model.visibility != nil || model.sourceKind != nil {
                HStack(spacing: 8) {
                    if let visibility = model.visibility {
                        recipeChip(visibility, systemImage: "eye.fill")
                    }
                    if let sourceKind = model.sourceKind {
                        recipeChip(sourceKind, systemImage: "point.3.connected.trianglepath.dotted")
                    }
                }
            }

            if let method = model.brewMethod {
                detailLine("Method", method)
            }
            if let equipment = model.equipment {
                detailLine("Equipment", equipment)
            }
            if let details = model.details {
                if let extraction = details.extractionSummary {
                    detailLine("Extraction", extraction)
                }
                if let beans = details.beans?.remoteTrimmedNonEmpty {
                    detailLine("Beans", beans)
                }
                if let origin = details.beanOrigin?.remoteTrimmedNonEmpty {
                    detailLine("Origin", origin)
                }
                if let roast = details.roastLevel?.remoteTrimmedNonEmpty {
                    detailLine("Roast", roast)
                }
                if let grind = details.grindSetting?.remoteTrimmedNonEmpty {
                    detailLine("Grind", grind)
                }
                if let temperature = details.waterTemperatureCelsius {
                    detailLine("Water", String(format: "%.0f°C", temperature))
                }
                if let waterNotes = details.waterNotes?.remoteTrimmedNonEmpty {
                    detailLine("Water notes", waterNotes)
                }
                if let additions = details.additions?.remoteTrimmedNonEmpty {
                    detailLine("Additions", additions)
                }
                if let servingVolume = details.servingVolumeMilliliters {
                    detailLine("Serving", String(format: "%.0f ml", servingVolume))
                }
                if let shotCount = details.espressoShotCount {
                    detailLine("Espresso", "\(shotCount) \(shotCount == 1 ? "shot" : "shots")")
                }
                if let steps = details.steps?.filter({ $0.instruction.remoteTrimmedNonEmpty != nil }),
                   !steps.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Instructions")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.tertiaryText)
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            HStack(alignment: .top, spacing: 9) {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.foamWhite)
                                    .frame(width: 22, height: 22)
                                    .background(Color.mugshotSage, in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.instruction)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.espressoBrown)
                                    if let duration = step.durationSeconds {
                                        Text("\(duration) sec")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.tertiaryText)
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Step \(index + 1), \(step.instruction)")
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func recipeChip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.espressoBrown)
            .padding(.horizontal, 9)
            .frame(minHeight: 32)
            .background(Color.mugshotMint.opacity(0.28), in: Capsule())
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .frame(width: 82, alignment: .leading)
                Text(value)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                Text(value)
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.espressoBrown)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    private func recipeButton(
        title: String,
        systemImage: String,
        action: SipDetailRecipeAction
    ) -> some View {
        Button {
            onAction(action)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isWorking)
    }
}

private struct SipDetailTaggedPeopleSection: View {
    let accounts: [SipDetailTaggedAccount]
    let isWorking: Bool
    let onOpenProfile: (UUID) -> Void
    let onRemoveOwnTag: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: -8) {
                ForEach(accounts.prefix(3)) { account in
                    Button {
                        onOpenProfile(account.userID)
                    } label: {
                        MugshotAvatar(
                            name: account.displayName,
                            size: 36,
                            imageURL: account.avatarURL
                        )
                        .overlay(Circle().stroke(Color.creamWhite, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(account.displayName)’s profile")
                }
            }

            Text(taggedSummary)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
                .frame(maxWidth: .infinity, alignment: .leading)

            if accounts.contains(where: \.isCurrentUser) {
                Button("Remove", role: .destructive) {
                    onRemoveOwnTag()
                }
                .font(.system(size: 12, weight: .bold))
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityHint("Removes your name without changing this post's audience")
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.mugshotSage)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 58)
        .overlay(alignment: .top) { Divider().foregroundStyle(Color.mugshotLine) }
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sip.detail.taggedPeople")
    }

    private var taggedSummary: String {
        let names = accounts.map(\.displayName)
        switch names.count {
        case 0: return "With friends"
        case 1: return "With \(names[0])"
        case 2: return "With \(names[0]) and \(names[1])"
        default: return "With \(names[0]), \(names[1]) and \(names.count - 2) more"
        }
    }
}

// MARK: - Hero

private struct SipDetailHero: View {
    let model: SipDetailContentModel
    @Binding var selectedPhotoIndex: Int
    let onPhotoTap: (Int) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MugshotAvatar(
                    name: model.authorName,
                    size: 44,
                    imageURL: model.authorAvatarURL
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.authorName)
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text("\(model.authorUsername) · \(model.timestamp)")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .frame(
                maxWidth: .infinity,
                minHeight: dynamicTypeSize.isAccessibilitySize ? 116 : 82,
                maxHeight: dynamicTypeSize.isAccessibilitySize ? 116 : 82,
                alignment: .leading
            )
            .background(Color.creamWhite)

            MugshotAdaptivePostMedia(
                ratioCacheKey: firstMediaSource.cacheKey,
                drinkName: model.drinkName,
                locationName: model.locationName,
                locationDetail: model.locationSubtitle,
                score: model.score
            ) {
                SipDetailPhotoPager(
                    photos: model.photos,
                    usesMugsyFallback: model.usesMugsyPhotoFallback,
                    selectedIndex: $selectedPhotoIndex,
                    onTap: onPhotoTap
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .clipped()
        .accessibilityElement(children: .contain)
    }

    private var firstMediaSource: MugshotPostMediaSource {
        model.photos.first?.postMediaSource
            ?? .placeholder(usesMugsyFallback: model.usesMugsyPhotoFallback)
    }
}

private struct SipDetailPhotoPager: View {
    let photos: [SipDetailPhotoSource]
    let usesMugsyFallback: Bool
    @Binding var selectedIndex: Int
    let onTap: (Int) -> Void

    var body: some View {
        Group {
            if photos.isEmpty {
                SipDetailNoPhotoSurface(usesMugsyFallback: usesMugsyFallback)
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, source in
                        SipDetailPhoto(source: source, reportsImageSize: index == 0)
                            .tag(index)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(index) }
                            .overlay(alignment: .topTrailing) {
                                if photos.count > 1 {
                                    Text("\(selectedIndex + 1)/\(photos.count)")
                                        .font(.system(.caption, design: .default, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.black.opacity(0.54), in: Capsule())
                                        .padding(.top, 16)
                                        .padding(.trailing, 18)
                                }
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            }
        }
        .accessibilityAction(named: "Open photo full screen") {
            guard !photos.isEmpty else { return }
            onTap(selectedIndex)
        }
    }
}

private struct SipDetailPhoto: View {
    let source: SipDetailPhotoSource
    var reportsImageSize = false
    @Environment(\.mugshotImageSizeReporter) private var reportImageSize

    var body: some View {
        switch source {
        case .local(let path):
            PhotoImageView(photoPath: path)
                .environment(\.mugshotImageSizeReporter, reportsImageSize ? reportImageSize : nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .remote(let url):
            RemotePhotoImageView(urlString: url, placeholderSystemName: "photo.on.rectangle")
                .environment(\.mugshotImageSizeReporter, reportsImageSize ? reportImageSize : nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .asset(let name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onAppear {
                    guard reportsImageSize, let size = UIImage(named: name)?.size else { return }
                    reportImageSize?(size)
                }
        }
    }
}

struct SipDetailPhotoViewer: View {
    let presentation: SipDetailPhotoViewerPresentation
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(presentation: SipDetailPhotoViewerPresentation) {
        self.presentation = presentation
        _selectedIndex = State(initialValue: presentation.initialIndex)
    }

    var body: some View {
        ZStack {
            Color.espressoBrown.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("\(selectedIndex + 1) of \(presentation.photos.count)")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(Color.creamWhite)
                        .monospacedDigit()

                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(.body, design: .default, weight: .bold))
                                .foregroundStyle(Color.creamWhite)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.22), in: Circle())
                        }
                        .accessibilityLabel("Close photo viewer")

                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 60)

                TabView(selection: $selectedIndex) {
                    ForEach(Array(presentation.photos.enumerated()), id: \.element.id) { index, source in
                        SipDetailViewerPhoto(source: source)
                            .tag(index)
                            .padding(.horizontal, 10)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if presentation.photos.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(presentation.photos.enumerated()), id: \.element.id) { index, source in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedIndex = index
                                    }
                                } label: {
                                    SipDetailPhoto(source: source)
                                        .frame(width: 58, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(
                                                    index == selectedIndex ? Color.mugshotMint : Color.creamWhite.opacity(0.24),
                                                    lineWidth: index == selectedIndex ? 3 : 1
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Show photo \(index + 1)")
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .frame(height: 88)
                }

                Text("\(presentation.drinkName)  ·  \(presentation.locationName)")
                    .font(.system(.footnote, design: .serif, weight: .regular))
                    .foregroundStyle(Color.creamWhite.opacity(0.78))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
        }
    }
}

private struct SipDetailViewerPhoto: View {
    let source: SipDetailPhotoSource

    var body: some View {
        switch source {
        case .local(let path):
            PhotoImageView(photoPath: path, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .remote(let url):
            RemotePhotoImageView(
                urlString: url,
                placeholderSystemName: "photo.on.rectangle",
                contentMode: .fit
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .asset(let name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SipDetailNoPhotoSurface: View {
    let usesMugsyFallback: Bool

    var body: some View {
        ZStack {
            Color.sandBeige.opacity(0.56)

            Circle()
                .fill(Color.mugshotMint.opacity(0.28))
                .frame(width: 210, height: 210)
                .offset(x: 132, y: -82)

            VStack(spacing: 12) {
                if usesMugsyFallback {
                    MugsyModelView(configuration: MugsyModelConfiguration(
                        expression: .curious,
                        prop: .camera,
                        pose: .leaningLeft
                    ))
                    .frame(width: 118, height: 118)
                } else {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(Color.mugshotSage)
                }

                VStack(spacing: 7) {
                    Text(usesMugsyFallback ? "Oops, missed the photo" : "No photo added")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.espressoBrown)
                    Text(
                        usesMugsyFallback
                            ? "Mugsy saved this memory a spot."
                            : "The story of this Mugshot still lives here."
                    )
                    .font(.system(.footnote, design: .default, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.mugshotLine.opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Content sections

private struct SipDetailPostSummary: View {
    let model: SipDetailContentModel

    var body: some View {
        Group {
            if let caption = model.caption {
                MugshotExpandableCaption(caption: caption, alwaysExpanded: true)
            }
        }
    }
}

private struct SipDetailActionDock: View {
    let actions: [SipDetailAction]
    let model: SipDetailContentModel
    let isWorking: Bool
    let onAction: (SipDetailAction) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(leadingActions) { action in
                actionControl(action)
            }

            Spacer(minLength: 12)

            ForEach(trailingActions) { action in
                actionControl(action)
            }
        }
        .frame(minHeight: 52)
        .background(Color.creamWhite)
        .overlay(alignment: .top) { Divider().foregroundStyle(Color.mugshotLine) }
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
    }

    private var leadingActions: [SipDetailAction] {
        actions.filter { $0 != .saveCafe && $0 != .more }
    }

    private var trailingActions: [SipDetailAction] {
        actions.filter { $0 == .saveCafe || $0 == .more }
    }

    @ViewBuilder
    private func actionControl(_ action: SipDetailAction) -> some View {
        if action == .share {
            SipShareButton(payload: model.sharePayload, layout: .dock)
                .frame(minWidth: 44, minHeight: 44)
        } else {
            Button {
                onAction(action)
            } label: {
                SipDetailDockLabel(
                    action: action,
                    isActive: isActive(action),
                    value: displayValue(for: action)
                )
            }
            .buttonStyle(SipDetailPressButtonStyle())
            .disabled(isWorking)
            .accessibilityLabel(accessibilityLabel(action))
        }
    }

    private func displayValue(for action: SipDetailAction) -> String? {
        switch action {
        case .like where model.likeCount > 0:
            return "\(model.likeCount)"
        case .comment where !model.comments.isEmpty:
            return "\(model.comments.count)"
        default:
            return nil
        }
    }

    private func isActive(_ action: SipDetailAction) -> Bool {
        switch action {
        case .like: model.isLiked
        case .saveCafe: model.isCafeSaved
        default: false
        }
    }

    private func accessibilityLabel(_ action: SipDetailAction) -> String {
        switch action {
        case .like where model.isLiked: "Unlike sip, \(model.likeCount) likes"
        case .like: "Like sip, \(model.likeCount) likes"
        case .comment: "Comment, \(model.comments.count) comments"
        case .saveCafe where model.isCafeSaved: "Cafe saved"
        case .recommend: "Recommend this sip"
        default: action.title
        }
    }
}

struct SipDetailDockLabel: View {
    let action: SipDetailAction
    let isActive: Bool
    let value: String?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: activeSystemImage)
                .font(.system(size: 22, weight: .medium))
                .symbolEffect(.bounce, value: isActive)
            if let value {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(isActive ? Color.mugshotSage : Color.espressoBrown)
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, value == nil ? 0 : 5)
        .contentShape(Rectangle())
    }

    private var activeSystemImage: String {
        guard isActive else { return action.systemImage }
        switch action {
        case .like: return "heart.fill"
        case .saveCafe: return "bookmark.fill"
        default: return action.systemImage
        }
    }
}

private struct SipDetailPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .background(
                configuration.isPressed ? Color.mugshotMint.opacity(0.16) : .clear,
                in: Capsule()
            )
            .animation(MugshotMotion.animation(MugshotMotion.response, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

private struct SipSocialProofSection: View {
    let model: SipDetailContentModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.reactions) { reaction in
                    Label("\(reaction.title) \(reaction.count)", systemImage: reaction.systemImage)
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(Color.roastBrown)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 34)
                        .background(Color.sandBeige.opacity(0.58), in: Capsule())
                    }
                }
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
        .accessibilityElement(children: .contain)
    }
}

private struct SipTasteEvidenceSection: View {
    let model: SipDetailContentModel
    @Binding var isExpanded: Bool
    let revealProgress: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SipEvidenceScoreStrip(
                sipScore: model.sipScore,
                contextLabel: contextLabel,
                contextScore: model.contextScore,
                mugshotScore: model.score
            )

            Button {
                guard hasExpandableDetails else { return }
                withAnimation(MugshotMotion.animation(MugshotMotion.reveal, reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "leaf")
                        .foregroundStyle(Color.mugshotSage)
                    Text("What shaped this Mugshot?")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.espressoBrown)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if hasExpandableDetails {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(.footnote, design: .default, weight: .bold))
                            .foregroundStyle(Color.mugshotSage)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sip.detail.taste.toggle")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if !descriptorPreview.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(descriptorPreview, id: \.self) { descriptor in
                            Text(descriptor)
                                .font(.system(.caption, design: .default, weight: .semibold))
                                .foregroundStyle(Color.espressoBrown)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 34)
                                .background(Color.mugshotMint.opacity(0.2), in: Capsule())
                        }
                    }
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Your ratings describe how this memory worked for you.")
                        .font(.system(.footnote, design: .default, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !meaningfulResponses.isEmpty || !model.ratings.isEmpty {
                        SipEvidenceGroup(
                            title: "The drink itself",
                            ratings: model.ratings,
                            responses: meaningfulResponses,
                            revealProgress: revealProgress
                        )
                    }

                    if !model.contextRatings.isEmpty {
                        SipEvidenceGroup(
                            title: "The \(contextLabel.lowercased()) & experience",
                            ratings: model.contextRatings,
                            responses: [],
                            revealProgress: revealProgress
                        )
                    }

                    Label(
                        "These are personal observations, not universal quality scores.",
                        systemImage: "equal.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
    }

    private var contextLabel: String {
        model.contextRatingLabel?.remoteTrimmedNonEmpty ?? "Context"
    }

    private var meaningfulResponses: [SipSensoryResponseSnapshot] {
        model.sensorySnapshot?.responses.filter {
            $0.state != .notAsked && $0.state != .skipped
        } ?? []
    }

    private var descriptorPreview: [String] {
        let sensory = meaningfulResponses.flatMap(\.descriptors).map(\.displayedTitle)
        let fallback = model.ratings.map(\.name) + model.contextRatings.map(\.name)
        return Array((sensory.isEmpty ? fallback : sensory).sensoryUnique.prefix(4))
    }

    private var hasExpandableDetails: Bool {
        !meaningfulResponses.isEmpty || !model.ratings.isEmpty || !model.contextRatings.isEmpty
    }
}

private struct SipEvidenceScoreStrip: View {
    let sipScore: Double
    let contextLabel: String
    let contextScore: Double?
    let mugshotScore: Double

    var body: some View {
        HStack(spacing: 0) {
            scoreColumn(label: "Sip", score: sipScore)

            Divider()
                .frame(height: 56)

            scoreColumn(
                label: contextScore == nil ? "Mugshot" : contextLabel,
                score: contextScore ?? mugshotScore
            )
        }
        .padding(.vertical, 12)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
    }

    private func scoreColumn(label: String, score: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(.footnote, design: .serif, weight: .medium))
                .foregroundStyle(Color.secondaryText)
            HStack(spacing: 8) {
                Text(score.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(.title, design: .serif, weight: .regular))
                    .foregroundStyle(Color.espressoBrown)
                    .monospacedDigit()

                HStack(spacing: 1) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: score >= Double(star) - 0.25 ? "star.fill" : "star")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .foregroundStyle(Color.mugshotSage)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) score \(score.formatted(.number.precision(.fractionLength(1))))")
    }
}

private struct SipEvidenceGroup: View {
    let title: String
    let ratings: [SipDetailRatingItem]
    let responses: [SipSensoryResponseSnapshot]
    let revealProgress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)

            ForEach(responses) { response in
                SipSensoryResponseDetail(response: response)
                if response.id != responses.last?.id || !ratings.isEmpty {
                    Divider().foregroundStyle(Color.mugshotLine)
                }
            }

            ForEach(ratings) { rating in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(rating.name)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 12)
                        Text(rating.score.formatted(.number.precision(.fractionLength(1))))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.mugshotSage)
                            .monospacedDigit()
                    }
                    .font(.system(.footnote, design: .default, weight: .semibold))

                    GeometryReader { geometry in
                        Capsule().fill(Color.mugshotLine)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.mugshotSage)
                                    .frame(
                                        width: geometry.size.width
                                            * CGFloat(min(max(rating.score / 5, 0), 1))
                                            * revealProgress
                                    )
                            }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(16)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
    }
}

private struct SipSensoryResponseDetail: View {
    let response: SipSensoryResponseSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(response.displayedCriterionTitle)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.espressoBrown)
                Spacer(minLength: 10)
                Text(stateLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(response.state == .observed ? Color.mugshotSage : Color.tertiaryText)
            }

            if !detailParts.isEmpty {
                Text(detailParts.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var stateLabel: String {
        switch response.state {
        case .notAsked: return "Unanswered"
        case .skipped: return "Skipped"
        case .notPresent: return "Not present"
        case .unsure: return "Not sure yet"
        case .observed: return "Observed"
        case .notRelevant: return "Not relevant"
        }
    }

    private var detailParts: [String] {
        var parts = response.descriptors.map(\.displayedTitle)
        parts.append(contentsOf: response.selectedChoices.map(\.displayedLabel))
        if let customText = response.customText?.remoteTrimmedNonEmpty {
            parts.append(customText)
        }
        if let intensity = response.intensity {
            let label = response.displayedScaleAnchors
                .first(where: { $0.value == intensity.level })?.displayedLabel
                ?? "Intensity \(intensity.level)"
            parts.append(label)
        }
        if let duration = response.duration {
            parts.append(duration.title)
        }
        if let preference = response.preference {
            parts.append(preference.title)
        }
        if let quality = response.qualityImpression {
            parts.append("Personal style impression \(quality.value) of 5")
        }
        if let confidence = response.confidence {
            parts.append(confidence.title)
        }
        return parts.sensoryUnique
    }
}

private extension Array where Element == String {
    var sensoryUnique: [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0).inserted }
    }
}

private struct SipPrivateNoteSection: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Private note", systemImage: "lock.fill")
                .font(.system(.caption2, design: .default, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.mugshotSage)
            Text(text)
                .font(.system(.title3, design: .serif, weight: .regular))
                .foregroundStyle(Color.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sandBeige.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct SipSharedRawNoteSection: View {
    let text: String
    let visibility: String
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(.body, design: .default, weight: .medium))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("SHARED JOURNAL NOTE")
                            .font(.system(.caption2, design: .default, weight: .bold))
                            .tracking(1.25)
                            .foregroundStyle(Color.mugshotSage)
                        if !isExpanded {
                            Text(text)
                                .font(.system(.body, design: .serif, weight: .regular))
                                .foregroundStyle(Color.espressoBrown)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(.footnote, design: .default, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sip.detail.journal.toggle")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Label(readerDescription, systemImage: visibilitySystemImage)
                        .font(.system(.subheadline, design: .default, weight: .medium))
                        .foregroundStyle(Color.secondaryText)

                    Text(text)
                        .font(.system(.title3, design: .serif, weight: .regular))
                        .foregroundStyle(Color.espressoBrown)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.mugshotMint.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )

                    Button(action: toggle) {
                        Label("Collapse note", systemImage: "chevron.up")
                            .font(.system(.footnote, design: .default, weight: .semibold))
                            .foregroundStyle(Color.mugshotSage)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)

                    Label(
                        "This note never travels beyond the Mugshot audience.",
                        systemImage: "lock"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sip.detail.journal")
    }

    private var readerDescription: String {
        switch visibility.lowercased() {
        case "private": "Only you can read this note"
        case "friends": "Friends can read this note"
        default: "Everyone can read this note"
        }
    }

    private var visibilitySystemImage: String {
        visibility.lowercased() == "private" ? "lock" : "person.2"
    }

    private func toggle() {
        withAnimation(MugshotMotion.animation(MugshotMotion.reveal, reduceMotion: reduceMotion)) {
            isExpanded.toggle()
        }
    }
}

private struct SipConversationSection: View {
    let comments: [SipDetailCommentModel]
    let canComment: Bool
    let onReply: (UUID) -> Void
    let onCompose: () -> Void
    let onCommentAction: (UUID, SipDetailCommentAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Conversation")
                    .font(.system(.title2, design: .default, weight: .bold))
                Spacer()
                Text("\(comments.count)")
                    .font(.system(.caption, design: .default, weight: .bold))
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.sandBeige.opacity(0.58), in: Capsule())
            }

            if !comments.isEmpty {
                VStack(spacing: 0) {
                    ForEach(comments) { comment in
                        SipDetailCommentRow(
                            comment: comment,
                            onReply: onReply,
                            onAction: onCommentAction
                        )
                        if comment.id != comments.last?.id {
                            Divider().foregroundStyle(Color.mugshotLine)
                        }
                    }
                }
            }

            if canComment {
                Button(action: onCompose) {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.right")
                        Text(comments.isEmpty ? "Be the first to comment" : "Add a thought")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Color.mugshotSage)
                    }
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(Color.espressoBrown)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .background(Color.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.mugshotLine, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SipDetailCommentRow: View {
    let comment: SipDetailCommentModel
    let onReply: (UUID) -> Void
    let onAction: (UUID, SipDetailCommentAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MugshotAvatar(name: comment.authorName, size: 36)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.authorName)
                        .font(.system(.subheadline, design: .default, weight: .bold))
                    Text(comment.timestamp)
                        .font(.caption2)
                        .foregroundStyle(Color.tertiaryText)
                    Spacer(minLength: 8)
                    if !comment.actions.isEmpty {
                        Menu {
                            ForEach(comment.actions) { action in
                                Button(role: action.isDestructive ? .destructive : nil) {
                                    onAction(comment.id, action)
                                } label: {
                                    Label(action.title, systemImage: action.systemImage)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Actions for \(comment.authorName)’s comment")
                    }
                }
                Text(comment.text)
                    .font(.body)
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)
                if comment.canReply {
                    Button("Reply") { onReply(comment.id) }
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(minHeight: 36)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }
}

private struct SipDetailComposerBar: View {
    @Binding var text: String
    let replyingToUsername: String?
    let isWorking: Bool
    let mentionSuggestions: [SipDetailMentionSuggestion]
    let focus: FocusState<Bool>.Binding
    let onCancelReply: () -> Void
    let onSelectMention: (UUID) -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let replyingToUsername {
                HStack {
                    Text("Replying to \(replyingToUsername)")
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                    Spacer()
                    Button("Cancel", action: onCancelReply)
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(Color.espressoBrown)
                }
            }

            if !mentionSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mentionSuggestions) { suggestion in
                            Button("@\(suggestion.username)") {
                                onSelectMention(suggestion.id)
                            }
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(Color.mugshotSage)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 36)
                            .background(Color.creamWhite, in: Capsule())
                            .overlay(Capsule().stroke(Color.mugshotLine, lineWidth: 1))
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Add a thought", text: $text, axis: .vertical)
                    .focused(focus)
                    .lineLimit(1...4)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.mugshotLine, lineWidth: 1)
                    )
                    .submitLabel(.send)
                    .onSubmit(onSubmit)

                Button(action: onSubmit) {
                    Image(systemName: isWorking ? "hourglass" : "arrow.up")
                        .font(.system(.body, design: .default, weight: .bold))
                        .foregroundStyle(Color.creamWhite)
                        .frame(width: 46, height: 46)
                        .background(Color.mugshotSage, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(text.remoteTrimmedNonEmpty == nil || isWorking)
                .opacity(text.remoteTrimmedNonEmpty == nil ? 0.45 : 1)
                .accessibilityLabel("Post comment")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Loading, error, edit, and delete surfaces

struct SipDetailLoadingView: View {
    @State private var shimmerOffset: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.sandBeige.opacity(0.72))
                .frame(height: 420)
                .overlay(shimmer)

            VStack(alignment: .leading, spacing: 12) {
                skeleton(width: 0.82, height: 28)
                skeleton(width: 0.64, height: 28)
                skeleton(width: 0.48, height: 16)
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.sandBeige.opacity(0.7))
                            .frame(height: 66)
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Color.creamWhite)
        .ignoresSafeArea(edges: .top)
        .accessibilityLabel("Loading sip")
        .onAppear {
            if reduceMotion {
                shimmerOffset = 0
            } else {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1
                }
            }
        }
    }

    private var shimmer: some View {
        LinearGradient(
            colors: [.clear, Color.mugshotMint.opacity(0.28), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerOffset * 360)
        .clipped()
    }

    private func skeleton(width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.sandBeige.opacity(0.72))
                .frame(width: geometry.size.width * width, height: height)
        }
        .frame(height: height)
    }
}

struct SipDetailErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.red.opacity(0.78))
                Text("Couldn’t load this sip")
                    .font(.system(.title2, design: .default, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Button("Try again", action: onRetry)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(minHeight: 50)
                Button("Close", action: onClose)
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamWhite)
    }
}

struct SipDeleteConfirmationSheet: View {
    let isDeleting: Bool
    let errorMessage: String?
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "trash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.red)
                .frame(width: 46, height: 46)
                .background(Color.red.opacity(0.10), in: Circle())
            Text("Delete this sip?")
                .font(.system(.title2, design: .default, weight: .bold))
                .foregroundStyle(Color.espressoBrown)
            Text("This permanently removes the sip, photos, comments, and reactions. This cannot be undone.")
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .default, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("sip.delete.error")
            }
            Button(role: .destructive, action: onDelete) {
                HStack {
                    if isDeleting { ProgressView().tint(.white) }
                    Text("Delete Sip")
                        .frame(maxWidth: .infinity)
                }
                .font(.system(.body, design: .default, weight: .bold))
                .foregroundStyle(.white)
                .frame(height: 50)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isDeleting)
            Button("Cancel") { dismiss() }
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.creamWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.mugshotLine, lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(Color.creamWhite)
    }
}

enum SipDetailEditSaveResult: Equatable {
    case success
    case failure(String)
}

struct SipDetailEditForm: View {
    let summary: SipDetailContentModel
    let allowsPrivateNoteEditing: Bool
    @State private var publicNote: String
    @State private var privateNote: String
    @State private var visibility: VisitVisibility
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSave: (String, String, VisitVisibility) async -> SipDetailEditSaveResult

    @Environment(\.dismiss) private var dismiss

    init(
        summary: SipDetailContentModel,
        initialVisibility: VisitVisibility,
        allowsPrivateNoteEditing: Bool,
        onSave: @escaping (String, String, VisitVisibility) async -> SipDetailEditSaveResult
    ) {
        self.summary = summary
        self.allowsPrivateNoteEditing = allowsPrivateNoteEditing
        self.onSave = onSave
        _publicNote = State(initialValue: summary.caption ?? "")
        _privateNote = State(initialValue: summary.privateNote ?? "")
        _visibility = State(initialValue: initialVisibility)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SipEditSummaryRow(summary: summary)
                        .padding(.bottom, 22)

                    editSection(
                        title: "Public note",
                        helper: "Visible with this sip",
                        placeholder: "What should people remember?",
                        text: $publicNote
                    )

                    Text("\(publicCaptionCount.formatted()) / \(SipCaptionPolicy.maximumLength.formatted())")
                        .font(.caption)
                        .foregroundStyle(captionValidationError == nil ? Color.tertiaryText : Color.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 6)

                    Divider().padding(.vertical, 20)

                    if allowsPrivateNoteEditing {
                        editSection(
                            title: "Private note",
                            helper: "Only visible to you",
                            placeholder: "Only visible to you",
                            text: $privateNote
                        )
                    } else {
                        Label(
                            "Your structured journal notes stay unchanged in this editor.",
                            systemImage: "lock.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                    }

                    Divider().padding(.vertical, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Audience")
                            .font(.system(.caption, design: .default, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(Color.mugshotSage)
                        MugshotSegmentedControl(
                            options: [VisitVisibility.private, .friends, .everyone],
                            selection: $visibility,
                            title: { $0.rawValue }
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(.footnote, design: .default, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .padding(.top, 16)
                    }

                    Button(action: save) {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text("Save sip").frame(maxWidth: .infinity)
                        }
                        .font(.system(.body, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(height: 52)
                        .background(Color.mugshotSage, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || captionValidationError != nil)
                    .padding(.top, 28)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.creamWhite)
            .navigationTitle("Edit sip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save", action: save)
                        .disabled(isSaving || captionValidationError != nil)
                }
            }
        }
    }

    private func editSection(
        title: String,
        helper: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(.caption, design: .default, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.mugshotSage)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(3...6)
                .font(.body)
                .padding(14)
                .background(Color.creamWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.mugshotLine, lineWidth: 1)
                )
            Text(helper)
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
        }
    }

    private func save() {
        guard !isSaving else { return }
        guard let normalizedCaption = try? SipCaptionPolicy.validateAndNormalize(publicNote) else {
            errorMessage = captionValidationError?.localizedDescription
            return
        }
        Task { @MainActor in
            isSaving = true
            errorMessage = nil
            let result = await onSave(normalizedCaption, privateNote, visibility)
            isSaving = false
            switch result {
            case .success:
                dismiss()
            case .failure(let message):
                errorMessage = message
            }
        }
    }

    private var publicCaptionCount: Int {
        SipCaptionPolicy.characterCount(publicNote)
    }

    private var captionValidationError: SipCaptionValidationError? {
        SipCaptionPolicy.validationError(for: publicNote)
    }
}

private struct SipEditSummaryRow: View {
    let summary: SipDetailContentModel

    var body: some View {
        HStack(spacing: 14) {
            if let source = summary.photos.first {
                SipDetailPhoto(source: source)
                    .frame(width: 64, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.sandBeige)
                    .frame(width: 64, height: 82)
                    .overlay(Image(systemName: "cup.and.saucer").foregroundStyle(Color.mugshotSage))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(summary.drinkName)
                    .font(.system(.title2, design: .serif, weight: .regular))
                    .foregroundStyle(Color.espressoBrown)
                    .lineLimit(3)
                Text(summary.locationName)
                    .font(.system(.callout, design: .default, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Deterministic previews

#if DEBUG
extension SipDetailPresentation {
    static var previewOwner: SipDetailPresentation {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let content = SipDetailContentModel(
            id: id,
            authorName: "Your sip",
            authorUsername: "@joe",
            authorAvatarURL: nil,
            timestamp: "Jul 23, 2026",
            visibility: "Friends",
            drinkName: "Iced Pistachio Latte",
            locationName: "Nook Tiny Cafe & Market",
            locationSubtitle: "Charleston, SC",
            locationSystemImage: JournalEntryContext.cafe.systemImage,
            score: 4,
            sipScore: 3.8,
            contextScore: 4.2,
            caption: "Mid-work day pick me up at Nook! Support your local cafe.",
            sharedRawNote: """
            Sip
            Starts with a punchy pistachio flavor right off the bat. It settles into a coffee-forward aftertaste that lingers. The drink is creamy and uses quality dairy, which gives it the mouth-feel I enjoy.

            Cafe
            This was a to-go order during a work call. Nook felt quiet and welcoming, the barista was kind, and the drink was ready quickly.
            """,
            privateNote: "Order it with an extra shot next time.",
            sharedMugshot: nil,
            recipe: nil,
            taggedAccounts: [
                SipDetailTaggedAccount(
                    userID: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
                    displayName: "Jamie",
                    username: "@jamie",
                    avatarURL: nil,
                    isCurrentUser: false
                ),
                SipDetailTaggedAccount(
                    userID: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
                    displayName: "Marco",
                    username: "@marco",
                    avatarURL: nil,
                    isCurrentUser: false
                )
            ],
            photos: MugshotLaunchEnvironment.shouldShowSipDetailPhotoDesignQA
                ? [
                    .asset("V3CreamyLatte"),
                    .asset("V3QuietCafeCorner"),
                    .asset("V3OrangeCitrusDetail")
                ]
                : [],
            usesMugsyPhotoFallback: !MugshotLaunchEnvironment.shouldShowSipDetailPhotoDesignQA,
            ratings: [
                SipDetailRatingItem(name: "Flavor balance", score: 3.7),
                SipDetailRatingItem(name: "Mouth-feel", score: 4.2),
                SipDetailRatingItem(name: "Coffee finish", score: 4)
            ],
            contextRatingLabel: "Cafe",
            contextRatings: [
                SipDetailRatingItem(name: "Atmosphere", score: 4),
                SipDetailRatingItem(name: "Service", score: 4.5),
                SipDetailRatingItem(name: "Menu clarity", score: 3.5),
                SipDetailRatingItem(name: "Wait time", score: 4.5)
            ],
            sensorySnapshot: nil,
            reactions: [
                SipDetailReactionSummary(title: "Great find", systemImage: "sparkles", count: 3),
                SipDetailReactionSummary(title: "Want this", systemImage: "cup.and.saucer.fill", count: 2)
            ],
            comments: [
                SipDetailCommentModel(
                    id: UUID(uuidString: "44444444-4444-4444-8444-444444444444")!,
                    authorName: "Jamie",
                    username: "@jamie",
                    text: "That pistachio finish sounds so good.",
                    timestamp: "12m",
                    canReply: true
                ),
                SipDetailCommentModel(
                    id: UUID(uuidString: "55555555-5555-4555-8555-555555555555")!,
                    authorName: "Marco",
                    username: "@marco",
                    text: "Adding Nook to my list.",
                    timestamp: "9m",
                    canReply: true
                ),
                SipDetailCommentModel(
                    id: UUID(uuidString: "66666666-6666-4666-8666-666666666666")!,
                    authorName: "Avery",
                    username: "@avery",
                    text: "Coffee-forward is exactly how I’d order it.",
                    timestamp: "4m",
                    canReply: true
                )
            ],
            isLiked: false,
            likeCount: 12,
            isCafeSaved: true,
            replyingToUsername: nil,
            sharePayload: SipShareCardPayload(
                authorName: "Joe",
                drinkName: "Iced Pistachio Latte",
                cafeName: "Nook Tiny Cafe & Market",
                rating: 4,
                date: Date(timeIntervalSince1970: 1_768_000_000),
                publicCaption: "Mid-work day pick me up at Nook! Support your local cafe.",
                remotePhotoURL: nil,
                localPhotoPath: nil
            )
        )
        return SipDetailPresentation(
            content: content,
            capabilities: .owner(hasCafe: true, canComment: true, canRepeat: true)
        )
    }
}

struct SipDetailPreviewHost: View {
    let presentation: SipDetailPresentation
    @State private var photoIndex = 0
    @State private var comment = ""
    @State private var progress: CGFloat = 0
    @State private var photoViewerPresentation: SipDetailPhotoViewerPresentation?
    @FocusState private var commentFocus: Bool

    var body: some View {
        NavigationStack {
            SipDetailScreen(
                presentation: presentation,
                selectedPhotoIndex: $photoIndex,
                commentText: $comment,
                toolbarProgress: $progress,
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
                onPhotoTap: { index in
                    guard presentation.content.photos.indices.contains(index) else { return }
                    photoViewerPresentation = SipDetailPhotoViewerPresentation(
                        photos: presentation.content.photos,
                        initialIndex: index,
                        drinkName: presentation.content.drinkName,
                        locationName: presentation.content.locationName
                    )
                },
                onRecipeAction: { _ in },
                onTaggedAccount: { _ in },
                onRemoveOwnTag: {}
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "chevron.left")
                }
                ToolbarItem(placement: .principal) {
                    SipDetailToolbarTitle(
                        drinkName: presentation.content.drinkName,
                        progress: progress
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "ellipsis")
                }
            }
            .toolbarBackground(Color.creamWhite, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .fullScreenCover(item: $photoViewerPresentation) { presentation in
                SipDetailPhotoViewer(presentation: presentation)
            }
        }
    }
}

#Preview("Immersive Pour — Owner") {
    SipDetailPreviewHost(presentation: .previewOwner)
}

#Preview("Immersive Pour — No Photo, AX5") {
    SipDetailPreviewHost(presentation: .previewOwner)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Immersive Pour — Loading") {
    SipDetailLoadingView()
}

#Preview("Immersive Pour — Failure") {
    SipDetailErrorView(message: "Check your connection and try again.", onRetry: {}, onClose: {})
}
#endif
