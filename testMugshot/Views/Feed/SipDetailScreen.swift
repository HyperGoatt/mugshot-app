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

    var id: String {
        switch self {
        case .local(let path): "local-\(path)"
        case .remote(let url): "remote-\(url)"
        }
    }
}

struct SipDetailPhotoViewerPresentation: Identifiable, Equatable {
    let id = UUID()
    let photos: [SipDetailPhotoSource]
    let initialIndex: Int

    static func == (lhs: SipDetailPhotoViewerPresentation, rhs: SipDetailPhotoViewerPresentation) -> Bool {
        lhs.id == rhs.id
    }
}

struct SipDetailRatingItem: Identifiable, Equatable {
    let name: String
    let score: Double

    var id: String { name }
}

struct SipDetailVisitFact: Identifiable, Equatable {
    let label: String
    let value: String
    let systemImage: String?

    init(label: String, value: String, systemImage: String? = nil) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }

    var id: String { "\(label)-\(value)" }
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
    case visitDetails
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
    /// The independent drink score used inside Taste snapshot.
    let sipScore: Double
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
    let visitFacts: [SipDetailVisitFact]
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
        if !visitFacts.isEmpty { sections.append(.visitDetails) }
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
        let authorName = isOwner ? "Your sip" : detail.summary.authorDisplayName
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
            locationSubtitle: detail.summary.locationSubtitle,
            locationSystemImage: visit.journalContext.systemImage,
            score: displayedScore,
            sipScore: detail.v3Reflection?.sipScore ?? visit.overallScore,
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
            visitFacts: remoteVisitFacts(detail),
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
            authorName: isOwner ? "Your sip" : authorDisplayName,
            authorUsername: "@\(user?.username ?? "user")",
            authorAvatarURL: nil,
            timestamp: SipDetailFormat.timestamp(visit.createdAt),
            visibility: visit.visibility == .everyone ? "Public" : visit.visibility.rawValue,
            drinkName: visit.journalDrinkName,
            locationName: visit.context == .cafe
                ? (cafe?.consumerDisplayName ?? "Cafe")
                : (visit.locationName?.remoteTrimmedNonEmpty ?? visit.context.locationFallback),
            locationSubtitle: visit.context == .cafe
                ? cafe?.address.remoteTrimmedNonEmpty
                : nil,
            locationSystemImage: visit.context.systemImage,
            score: displayedScore,
            sipScore: visit.v3Reflection?.sipScore ?? visit.overallScore,
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
            visitFacts: localVisitFacts(visit: visit, cafe: cafe),
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

    private static func remoteVisitFacts(_ detail: RemoteVisitDetail) -> [SipDetailVisitFact] {
        let visit = detail.summary.visit
        let structured = visit.recipeVersionID == nil
            ? visit.structuredBrewDetails
            : BrewDetails.empty
        var facts: [SipDetailVisitFact] = []
        if let companions = structured.companions, !companions.isEmpty {
            facts.append(SipDetailVisitFact(label: "With", value: companions.joined(separator: ", "), systemImage: "person.2"))
        }
        if let subtitle = detail.summary.locationSubtitle?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Address", value: subtitle, systemImage: "mappin"))
        }
        facts.append(SipDetailVisitFact(
            label: "Visited",
            value: visit.createdAtDate.formatted(date: .abbreviated, time: .omitted),
            systemImage: "calendar"
        ))
        if let reflection = detail.v3Reflection {
            facts.append(SipDetailVisitFact(
                label: "Sip",
                value: reflection.sipScore.formatted(.number.precision(.fractionLength(1))),
                systemImage: "cup.and.saucer.fill"
            ))
            if let contextScore = reflection.contextScore {
                facts.append(SipDetailVisitFact(
                    label: contextRatingLabel(for: visit.journalContext),
                    value: contextScore.formatted(.number.precision(.fractionLength(1))),
                    systemImage: visit.journalContext == .cafe ? "storefront.fill" : "mappin.and.ellipse"
                ))
            }
            facts.append(SipDetailVisitFact(
                label: "Mugshot",
                value: reflection.mugshotScore.formatted(.number.precision(.fractionLength(1))),
                systemImage: "sparkles"
            ))
        }
        if let session = detail.cafeSessionSummary {
            facts.append(SipDetailVisitFact(
                label: "This visit",
                value: "\(session.sipCount) \(session.sipCount == 1 ? "sip" : "sips")",
                systemImage: "cup.and.saucer.fill"
            ))
            if let cafeRating = session.cafeRating,
               detail.v3Reflection?.contextScore == nil {
                facts.append(SipDetailVisitFact(
                    label: "The Cafe",
                    value: cafeRating.formatted(.number.precision(.fractionLength(1))),
                    systemImage: "storefront.fill"
                ))
            }
            if let nextMove = session.nextMove {
                facts.append(SipDetailVisitFact(
                    label: "Next move",
                    value: nextMove.title,
                    systemImage: "arrow.triangle.branch"
                ))
            }
        }
        if let order = structured.orderNotes?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Order", value: order, systemImage: "cup.and.saucer"))
        }
        if let additions = structured.additions?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Additions", value: additions, systemImage: "plus.circle"))
        }
        if visit.recipeVersionID == nil,
           let brewMethod = visit.brewMethod?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Method", value: brewMethod, systemImage: "drop"))
        }
        if visit.recipeVersionID == nil,
           let equipment = visit.equipment?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Equipment", value: equipment, systemImage: "wrench.and.screwdriver"))
        }
        return facts
    }

    private static func localVisitFacts(visit: Visit, cafe: Cafe?) -> [SipDetailVisitFact] {
        var facts: [SipDetailVisitFact] = []
        if let companions = visit.brewDetails.companions, !companions.isEmpty {
            facts.append(SipDetailVisitFact(label: "With", value: companions.joined(separator: ", "), systemImage: "person.2"))
        }
        if visit.context == .cafe,
           let address = cafe?.address.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Address", value: address, systemImage: "mappin"))
        }
        facts.append(SipDetailVisitFact(
            label: "Visited",
            value: visit.createdAt.formatted(date: .abbreviated, time: .omitted),
            systemImage: "calendar"
        ))
        if let reflection = visit.v3Reflection {
            facts.append(SipDetailVisitFact(
                label: "Sip",
                value: reflection.sipScore.formatted(.number.precision(.fractionLength(1))),
                systemImage: "cup.and.saucer.fill"
            ))
            if let contextScore = reflection.contextScore {
                facts.append(SipDetailVisitFact(
                    label: contextRatingLabel(for: visit.context),
                    value: contextScore.formatted(.number.precision(.fractionLength(1))),
                    systemImage: visit.context == .cafe ? "storefront.fill" : "mappin.and.ellipse"
                ))
            }
            facts.append(SipDetailVisitFact(
                label: "Mugshot",
                value: reflection.mugshotScore.formatted(.number.precision(.fractionLength(1))),
                systemImage: "sparkles"
            ))
        }
        if let method = visit.brewMethod?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Method", value: method, systemImage: "drop"))
        }
        if let equipment = visit.equipment?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Equipment", value: equipment, systemImage: "wrench.and.screwdriver"))
        }
        return facts
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
    @State private var isVisitExpanded = false
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
                        .frame(height: heroHeight(for: viewport.size.width))
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
                .ignoresSafeArea(edges: .top)
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
        let base = width / 0.88
        if dynamicTypeSize.isAccessibilitySize {
            return max(base, 680)
        }
        return min(max(base, 390), 472)
    }

    private func contentSurface(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let caption = presentation.content.caption {
                SipDetailEditorialNote(text: caption)
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
            }

            if let rawNote = presentation.content.sharedRawNote {
                SipSharedRawNoteSection(text: rawNote)
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
            }

            if let sharedMugshot = presentation.content.sharedMugshot {
                SipSharedMugshotSection(model: sharedMugshot)
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
            }

            if let recipe = presentation.content.recipe {
                SipDetailRecipeSection(
                    model: recipe,
                    isWorking: isWorking,
                    onAction: onRecipeAction
                )
                .padding(.horizontal, 22)
                .padding(.top, 24)
            }

            if !presentation.content.taggedAccounts.isEmpty {
                SipDetailTaggedPeopleSection(
                    accounts: presentation.content.taggedAccounts,
                    isWorking: isWorking,
                    onOpenProfile: onTaggedAccount,
                    onRemoveOwnTag: onRemoveOwnTag
                )
                .padding(.horizontal, 22)
                .padding(.top, 24)
            }

            SipDetailActionDock(
                actions: presentation.capabilities.dockActions,
                model: presentation.content,
                isWorking: isWorking,
                onAction: { action in handle(action, proxy: proxy) }
            )
            .padding(.horizontal, 18)
            .padding(.top, presentation.content.caption == nil ? 26 : 22)

            if let statusMessage {
                SipDetailStatusBanner(message: statusMessage)
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
            }

            if !presentation.content.reactions.isEmpty {
                SipFriendsNoticedSection(reactions: presentation.content.reactions)
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
            }

            if presentation.content.sipScore > 0 || !presentation.content.ratings.isEmpty || presentation.content.sensorySnapshot != nil {
                SipTasteSnapshotSection(
                    score: presentation.content.sipScore,
                    ratings: presentation.content.ratings,
                    sensorySnapshot: presentation.content.sensorySnapshot,
                    isExpanded: $isTasteExpanded,
                    revealProgress: tasteReveal
                )
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .onChange(of: isTasteExpanded) { _, isExpanded in
                    guard isExpanded else { return }
                    revealTaste()
                }
            }

            if !presentation.content.contextRatings.isEmpty {
                SipContextCriteriaSection(
                    label: presentation.content.contextRatingLabel ?? "Setting",
                    ratings: presentation.content.contextRatings
                )
                .padding(.horizontal, 22)
                .padding(.top, 28)
            }

            if !presentation.content.visitFacts.isEmpty {
                SipVisitDetailsSection(
                    facts: presentation.content.visitFacts,
                    isExpanded: $isVisitExpanded
                )
                .padding(.horizontal, 22)
                .padding(.top, 28)
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
                .padding(.top, 30)
                .id(commentsAnchor)
            }
        }
        .padding(.bottom, 42)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.creamWhite)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 28,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 28,
            style: .continuous
        ))
        .offset(y: -18)
        .padding(.bottom, -18)
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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Label("People tagged", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                Text("Tags credit people without changing who owns this MugShot or who can see it.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(accounts) { account in
                HStack(spacing: 10) {
                    Button {
                        onOpenProfile(account.userID)
                    } label: {
                        HStack(spacing: 10) {
                            MugshotAvatar(
                                name: account.displayName,
                                size: 38,
                                imageURL: account.avatarURL
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.espressoBrown)
                                Text(account.username)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this Mugshot profile")

                    if account.isCurrentUser {
                        Button("Remove tag", role: .destructive) {
                            onRemoveOwnTag()
                        }
                        .font(.system(size: 12, weight: .bold))
                        .buttonStyle(.bordered)
                        .disabled(isWorking)
                        .accessibilityHint("Removes your name without changing this post's audience")
                    }
                }
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
        .accessibilityIdentifier("sip.detail.taggedPeople")
    }
}

// MARK: - Hero

private struct SipDetailHero: View {
    let model: SipDetailContentModel
    @Binding var selectedPhotoIndex: Int
    let onPhotoTap: (Int) -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SipDetailPhotoPager(
                photos: model.photos,
                usesMugsyFallback: model.usesMugsyPhotoFallback,
                selectedIndex: $selectedPhotoIndex,
                onTap: onPhotoTap
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.12), .black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    MugshotAvatar(
                        name: model.authorName,
                        size: 42,
                        imageURL: model.authorAvatarURL
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.authorName)
                            .font(.system(.subheadline, design: .default, weight: .bold))
                        Text("\(model.authorUsername)  ·  \(model.timestamp)  ·  \(model.visibility)")
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(2)
                    }
                }

                Text(model.drinkName)
                    .font(.system(.largeTitle, design: .serif, weight: .regular))
                    .tracking(-0.7)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 12) {
                    Label(model.locationName, systemImage: model.locationSystemImage)
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("MUGSHOT")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.2)
                        MugshotRatingBadge(score: model.score, onPhoto: false)
                            .background(Color.mugshotMint.opacity(0.76), in: Capsule())
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.bottom, 38)
            .shadow(color: .black.opacity(0.36), radius: 16, x: 0, y: 8)
            .allowsHitTesting(false)
        }
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.drinkName) at \(model.locationName), Mugshot score \(String(format: "%.1f", model.score))")
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
                        SipDetailPhoto(source: source)
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
                                        .padding(.top, 96)
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

    var body: some View {
        switch source {
        case .local(let path):
            PhotoImageView(photoPath: path)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .remote(let url):
            RemotePhotoImageView(urlString: url, placeholderSystemName: "photo.on.rectangle")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
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
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(presentation.photos.enumerated()), id: \.element.id) { index, source in
                    SipDetailPhoto(source: source)
                        .tag(index)
                        .scaledToFit()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: presentation.photos.count > 1 ? .automatic : .never))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(.body, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
            .accessibilityLabel("Close photo viewer")
        }
    }
}

private struct SipDetailNoPhotoSurface: View {
    let usesMugsyFallback: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.darkRoast, Color.roastBrown, Color.mugshotSage.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                if usesMugsyFallback {
                    MugsyModelView(configuration: MugsyModelConfiguration(
                        expression: .curious,
                        prop: .camera,
                        pose: .leaningLeft
                    ))
                    .frame(width: 112, height: 112)
                } else {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 54, weight: .light))
                }
                Text(usesMugsyFallback ? "Oops, missed the photo" : "No photo added")
                    .font(.system(.callout, design: .default, weight: .semibold))
                if usesMugsyFallback {
                    Text("Mugsy saved this memory a spot.")
                        .font(.caption)
                }
            }
            .foregroundStyle(Color.creamWhite.opacity(0.72))
            .padding(.bottom, 90)
        }
    }
}

// MARK: - Content sections

private struct SipDetailEditorialNote: View {
    let text: String

    var body: some View {
        Text("“\(text)”")
            .font(.system(.title2, design: .serif, weight: .regular))
            .foregroundStyle(Color.espressoBrown)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Tasting note: \(text)")
    }
}

private struct SipDetailActionDock: View {
    let actions: [SipDetailAction]
    let model: SipDetailContentModel
    let isWorking: Bool
    let onAction: (SipDetailAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : max(min(actions.count, 4), 1)
        return Array(repeating: GridItem(.flexible(), spacing: 0), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(actions) { action in
                if action == .share {
                    SipShareButton(payload: model.sharePayload, layout: .dock)
                        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 76 : 70)
                } else {
                    Button {
                        onAction(action)
                    } label: {
                        SipDetailDockLabel(
                            action: action,
                            isActive: isActive(action),
                            value: action == .like && model.likeCount > 0 ? "\(model.likeCount)" : nil
                        )
                    }
                    .buttonStyle(SipDetailPressButtonStyle())
                    .disabled(isWorking)
                    .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 76 : 70)
                    .accessibilityLabel(accessibilityLabel(action))
                }
            }
        }
        .background(Color.creamWhite)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        case .saveCafe where model.isCafeSaved: "Cafe saved"
        default: action.title
        }
    }
}

struct SipDetailDockLabel: View {
    let action: SipDetailAction
    let isActive: Bool
    let value: String?

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: activeSystemImage)
                .font(.system(size: 21, weight: .semibold))
                .symbolEffect(.bounce, value: isActive)
            HStack(spacing: 3) {
                Text(action.title)
                if let value { Text(value) }
            }
                .font(.system(.caption, design: .default, weight: .semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
        .foregroundStyle(isActive ? Color.mugshotSage : Color.espressoBrown)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
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
            .background(configuration.isPressed ? Color.mugshotMint.opacity(0.16) : .clear)
            .animation(MugshotMotion.animation(MugshotMotion.response, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

private struct SipFriendsNoticedSection: View {
    let reactions: [SipDetailReactionSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Friends noticed")
                    .font(.system(.title3, design: .default, weight: .bold))
                Spacer()
                HStack(spacing: -7) {
                    ForEach(Array(reactions.prefix(3).enumerated()), id: \.offset) { _, reaction in
                        Circle()
                            .fill(Color.mugshotMint)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: reaction.systemImage)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.espressoBrown)
                            )
                            .overlay(Circle().stroke(Color.creamWhite, lineWidth: 2))
                    }
                }
                .accessibilityHidden(true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { reactionContent }
                VStack(alignment: .leading, spacing: 8) { reactionContent }
            }
        }
        .foregroundStyle(Color.espressoBrown)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
    }

    @ViewBuilder
    private var reactionContent: some View {
        ForEach(reactions) { reaction in
            Label("\(reaction.title) \(reaction.count)", systemImage: reaction.systemImage)
                .font(.system(.footnote, design: .default, weight: .semibold))
                .foregroundStyle(Color.roastBrown)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Color.sandBeige.opacity(0.64), in: Capsule())
        }
    }
}

private struct SipTasteSnapshotSection: View {
    let score: Double
    let ratings: [SipDetailRatingItem]
    let sensorySnapshot: SipSensorySnapshot?
    @Binding var isExpanded: Bool
    let revealProgress: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Taste snapshot")
                    .font(.system(.title3, design: .default, weight: .bold))
                Spacer()
                Text(String(format: "%.1f personal", score))
                    .font(.system(.callout, design: .default, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.mugshotMint.opacity(0.28), in: Capsule())
            }

            if let sensorySnapshot {
                if let ownWords = sensorySnapshot.ownWords.remoteTrimmedNonEmpty {
                    Text("“\(ownWords)”")
                        .font(.system(.body, design: .serif, weight: .regular))
                        .foregroundStyle(Color.espressoBrown)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 13)
                } else if !descriptorPreview.isEmpty {
                    Text(descriptorPreview.joined(separator: " · "))
                        .font(.system(.footnote, design: .default, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 13)
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(meaningfulResponses) { response in
                            SipSensoryResponseDetail(response: response)
                            if response.id != meaningfulResponses.last?.id {
                                Divider().foregroundStyle(Color.mugshotLine)
                            }
                        }

                        Label(
                            "High intensity is not automatically better. Uncertainty never changes your stars.",
                            systemImage: "equal.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                        Text("\(sensorySnapshot.depth.title) Lens · vocabulary \(sensorySnapshot.bundleContentVersion)")
                            .font(.caption2)
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else if isExpanded {
                Text("Legacy tasting criteria")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.top, 14)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(ratings) { rating in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(rating.name)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text(String(format: "%.1f", rating.score))
                                    .monospacedDigit()
                            }
                            .font(.system(.footnote, design: .default, weight: .semibold))

                            GeometryReader { geometry in
                                Capsule().fill(Color.mugshotLine)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.mugshotSage)
                                            .frame(width: geometry.size.width * CGFloat(rating.score / 5) * revealProgress)
                                    }
                            }
                            .frame(height: 5)
                        }
                    }
                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if hasExpandableDetails {
                Button {
                    withAnimation(MugshotMotion.animation(MugshotMotion.reveal, reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(
                        isExpanded ? "Hide details" : (sensorySnapshot == nil ? "View legacy breakdown" : "View sensory trail"),
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                        .font(.system(.footnote, design: .default, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, isExpanded ? 14 : 6)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            }
        }
        .foregroundStyle(Color.espressoBrown)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
    }

    private var meaningfulResponses: [SipSensoryResponseSnapshot] {
        sensorySnapshot?.responses.filter {
            $0.state != .notAsked && $0.state != .skipped
        } ?? []
    }

    private var descriptorPreview: [String] {
        Array(meaningfulResponses.flatMap(\.descriptors).map(\.displayedTitle).sensoryUnique.prefix(4))
    }

    private var hasExpandableDetails: Bool {
        sensorySnapshot != nil ? !meaningfulResponses.isEmpty : !ratings.isEmpty
    }
}

private struct SipContextCriteriaSection: View {
    let label: String
    let ratings: [SipDetailRatingItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(label) · What shaped it")
                .font(.system(.title3, design: .default, weight: .bold))

            ForEach(ratings) { rating in
                HStack(spacing: 12) {
                    Text(rating.name)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                    Spacer()
                    Text(rating.score.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .monospacedDigit()
                }
            }
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
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

private struct SipVisitDetailsSection: View {
    let facts: [SipDetailVisitFact]
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var visibleFacts: ArraySlice<SipDetailVisitFact> {
        facts.prefix(isExpanded ? facts.count : 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Visit details")
                    .font(.system(.title3, design: .default, weight: .bold))
                Spacer()
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.mugshotSage)
            }

            ForEach(Array(visibleFacts)) { fact in
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        if let systemImage = fact.systemImage {
                            Label(fact.label, systemImage: systemImage)
                                .font(.system(.footnote, design: .default, weight: .medium))
                                .foregroundStyle(Color.mugshotSage)
                        } else {
                            Text(fact.label)
                                .font(.system(.footnote, design: .default, weight: .medium))
                                .foregroundStyle(Color.tertiaryText)
                        }
                        Text(fact.value)
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(Color.espressoBrown)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        if let systemImage = fact.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(.caption, design: .default, weight: .semibold))
                                .foregroundStyle(Color.mugshotSage)
                                .frame(width: 18)
                        }
                        Text(fact.label)
                            .font(.system(.footnote, design: .default, weight: .medium))
                            .foregroundStyle(Color.tertiaryText)
                            .frame(width: 68, alignment: .leading)
                        Text(fact.value)
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                            .foregroundStyle(Color.espressoBrown)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            if facts.count > 3 {
                Button(isExpanded ? "Show less" : "Show \(facts.count - 3) more") {
                    withAnimation(MugshotMotion.animation(MugshotMotion.reveal, reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                }
                .font(.system(.footnote, design: .default, weight: .semibold))
                .foregroundStyle(Color.mugshotSage)
                .frame(minHeight: 44)
            }
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Raw journal note", systemImage: "text.book.closed.fill")
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
        .background(Color.mugshotMint.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
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

            if comments.isEmpty {
                Text("No comments yet.")
                    .font(.body)
                    .foregroundStyle(Color.tertiaryText)
            } else {
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
                        Text("Add a thought")
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
                    .disabled(isSaving)
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
                        .disabled(isSaving)
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
        Task { @MainActor in
            isSaving = true
            errorMessage = nil
            let result = await onSave(publicNote, privateNote, visibility)
            isSaving = false
            switch result {
            case .success:
                dismiss()
            case .failure(let message):
                errorMessage = message
            }
        }
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
private extension SipDetailPresentation {
    static var previewOwner: SipDetailPresentation {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let content = SipDetailContentModel(
            id: id,
            authorName: "Your sip",
            authorUsername: "@joe",
            authorAvatarURL: nil,
            timestamp: "Jul 14, 2026",
            visibility: "Public",
            drinkName: "Iced Quad Shot Carmel Macchiato",
            locationName: "Babas on Cannon",
            locationSubtitle: "11 Cannon St, Charleston, SC",
            locationSystemImage: JournalEntryContext.cafe.systemImage,
            score: 3,
            sipScore: 3,
            caption: "Strong coffee and strong friends!",
            sharedRawNote: nil,
            privateNote: "Order it with an extra shot next time.",
            sharedMugshot: nil,
            recipe: nil,
            taggedAccounts: [],
            photos: [],
            usesMugsyPhotoFallback: false,
            ratings: [
                SipDetailRatingItem(name: "Presentation", score: 3.5),
                SipDetailRatingItem(name: "Value", score: 1.5),
                SipDetailRatingItem(name: "Taste", score: 3),
                SipDetailRatingItem(name: "Ambiance", score: 4)
            ],
            contextRatingLabel: nil,
            contextRatings: [],
            sensorySnapshot: nil,
            visitFacts: [
                SipDetailVisitFact(label: "With", value: "Amanda", systemImage: "person.2"),
                SipDetailVisitFact(label: "Address", value: "11 Cannon St", systemImage: "mappin"),
                SipDetailVisitFact(label: "Visited", value: "Jul 14, 2026", systemImage: "calendar")
            ],
            reactions: [],
            comments: [],
            isLiked: false,
            likeCount: 0,
            isCafeSaved: true,
            replyingToUsername: nil,
            sharePayload: SipShareCardPayload(
                authorName: "Joe",
                drinkName: "Iced Quad Shot Carmel Macchiato",
                cafeName: "Babas on Cannon",
                rating: 3,
                date: Date(timeIntervalSince1970: 1_768_000_000),
                publicCaption: "Strong coffee and strong friends!",
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

private struct SipDetailPreviewHost: View {
    let presentation: SipDetailPresentation
    @State private var photoIndex = 0
    @State private var comment = ""
    @State private var progress: CGFloat = 0
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
                onPhotoTap: { _ in },
                onRecipeAction: { _ in },
                onTaggedAccount: { _ in },
                onRemoveOwnTag: {}
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "chevron.left")
                }
                ToolbarItem(placement: .principal) {
                    Text(presentation.content.drinkName)
                        .lineLimit(1)
                        .opacity(progress)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "ellipsis")
                }
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
