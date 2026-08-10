import Foundation

enum SipCaptureMode: String, Codable, CaseIterable {
    case quickSip
    case addDetails
}

enum SipComposerSource: String, Codable, CaseIterable {
    case centralAdd
    case map
    case saved
    case cafeDetail
    case repeatSip
    case addAnotherSip
    case brewAgain
    case widget
    case appShortcut
    case camera
}

struct SipComposerLaunchContext: Codable, Equatable {
    var source: SipComposerSource
    var preselectedCafe: Cafe?
    var sourceVisitID: UUID?
    var sourceRecipeIdentityID: UUID?
    var sourceRecipeVersion: String?
    var returnTab: Int?

    static let centralAdd = SipComposerLaunchContext(source: .centralAdd)
}

enum SipDraftUploadState: String, Codable {
    case local
    case prepared
    case uploading
    case failed
}

enum SipV3ComposerStep: String, Codable, CaseIterable, Identifiable {
    case setup
    case sip
    case context
    case publish

    var id: String { rawValue }
}

enum SipPhotoFallback: String, Codable, Equatable {
    case mugsyMissedPhoto = "mugsy_missed_photo"
}

enum HomeMakeAgain: String, Codable, CaseIterable, Identifiable {
    case yes
    case withATweak = "with_a_tweak"
    case notThisVersion = "not_this_version"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: return "Yes"
        case .withATweak: return "With a tweak"
        case .notThisVersion: return "Not this one"
        }
    }
}

enum SipCriterionImportance: String, Codable, CaseIterable, Identifiable {
    case most
    case more
    case normal
    case less

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var weight: Double {
        switch self {
        case .less: return 0.5
        case .normal: return 1
        case .more: return 1.5
        case .most: return 2.25
        }
    }

    init(weight: Double) {
        self = Self.allCases.min { lhs, rhs in
            abs(lhs.weight - weight) < abs(rhs.weight - weight)
        } ?? .normal
    }
}

enum SipPublicationRequirement: Equatable {
    case ready
    case needsTextOrPhoto
    case needsTextOnlyConfirmation
}

enum SipPublicationPolicy {
    static func requirement(
        visibility: VisitVisibility,
        photoCount: Int,
        socialCaption: String,
        confirmedTextOnlyEveryone: Bool
    ) -> SipPublicationRequirement {
        guard visibility == .everyone, photoCount == 0 else { return .ready }
        guard socialCaption.remoteTrimmedNonEmpty != nil else { return .needsTextOrPhoto }
        return confirmedTextOnlyEveryone ? .ready : .needsTextOnlyConfirmation
    }
}

enum SipRecipeSourceKind: String, Codable, CaseIterable, Identifiable {
    case original
    case adapted
    case purchased
    case external

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: return "My original recipe"
        case .adapted: return "Adapted from Mugshot"
        case .purchased: return "Purchased recipe"
        case .external: return "From somewhere else"
        }
    }

    var permitsRedistribution: Bool {
        self == .original || self == .adapted
    }
}

enum SipRecipePublicationRequirement: Equatable {
    case ready
    case needsImmutableSource
    case sourceCannotBePublic
    case needsRedistributionPermission
    case needsPublicReuseAcknowledgment
}

/// Frozen independently from the Mugshot audience. Recipe instructions begin
/// Private and only move outward after source rights have been captured.
struct SipRecipePublicationContract: Codable, Equatable {
    var visibility: VisitVisibility
    var sourceKind: SipRecipeSourceKind
    var redistributionAllowed: Bool
    var sourceRecipeVersionID: UUID?
    var acknowledgesPublicReuse: Bool

    static let privateOriginal = SipRecipePublicationContract(
        visibility: .private,
        sourceKind: .original,
        redistributionAllowed: false,
        sourceRecipeVersionID: nil,
        acknowledgesPublicReuse: false
    )

    var requirement: SipRecipePublicationRequirement {
        if sourceKind == .adapted, sourceRecipeVersionID == nil {
            return .needsImmutableSource
        }
        guard visibility == .everyone else { return .ready }
        guard sourceKind.permitsRedistribution else { return .sourceCannotBePublic }
        guard redistributionAllowed else { return .needsRedistributionPermission }
        guard acknowledgesPublicReuse else { return .needsPublicReuseAcknowledgment }
        return .ready
    }

    mutating func selectSource(_ source: SipRecipeSourceKind) {
        sourceKind = source
        if source != .adapted {
            sourceRecipeVersionID = nil
        }
        if !source.permitsRedistribution {
            redistributionAllowed = false
            acknowledgesPublicReuse = false
        }
    }
}

struct SipRatingCriterionSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var score: Double
    var weight: Double
    var sortOrder: Int
    var relevanceOverride: Bool?
    var isPinned: Bool?

    init(
        id: UUID = UUID(),
        name: String,
        score: Double = 0,
        weight: Double = 1,
        sortOrder: Int,
        relevanceOverride: Bool? = nil,
        isPinned: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.score = score
        self.weight = weight
        self.sortOrder = sortOrder
        self.relevanceOverride = relevanceOverride
        self.isPinned = isPinned
    }

    var isRelevant: Bool {
        get { relevanceOverride ?? true }
        set { relevanceOverride = newValue }
    }

    var importance: SipCriterionImportance {
        get { SipCriterionImportance(weight: weight) }
        set { weight = newValue.weight }
    }

    static func weightedSuggestion(
        for criteria: [SipRatingCriterionSnapshot]
    ) -> Double? {
        let rated = criteria.filter {
            $0.isRelevant && (0.5...5).contains($0.score)
        }
        let totalWeight = rated.reduce(0) { $0 + max($1.weight, 0.01) }
        guard totalWeight > 0 else { return nil }
        let weightedTotal = rated.reduce(0) {
            $0 + ($1.score * max($1.weight, 0.01))
        }
        return ((weightedTotal / totalWeight) * 10).rounded() / 10
    }
}

struct SipCompanion: Identifiable, Codable, Equatable, Hashable {
    let userID: UUID
    let displayName: String
    let username: String
    let avatarURL: String?

    var id: UUID { userID }
}

struct SipDraft: Identifiable, Codable, Equatable {
    let id: UUID
    var ownerUserID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var captureMode: SipCaptureMode
    var launchContext: SipComposerLaunchContext
    var context: JournalEntryContext {
        didSet {
            if !context.supportsCafeSession {
                clearCafeSession()
            }
        }
    }
    var cafe: Cafe?
    var locationName: String
    var drinkType: DrinkType
    var customDrinkType: String
    var drinkName: String
    var overallScore: Double
    var socialCaption: String
    var privateNotes: String
    var visibility: VisitVisibility
    var ratingCriteria: [SipRatingCriterionSnapshot]
    var orderNotes: String
    var tags: [String]
    var companions: [String]
    /// Account-bound companion identities. `companions` remains as a legacy
    /// display snapshot so older visits and drafts continue to render.
    var taggedCompanions: [SipCompanion]?
    /// Optional storage keeps drafts written before independent recipe sharing
    /// decodable. The resolved contract always defaults to Private.
    private var storedRecipePublication: SipRecipePublicationContract?
    var brewMethod: String
    var equipment: String
    var brewDetails: BrewDetails
    var localPhotoNames: [String]
    var posterPhotoIndex: Int
    var uploadState: SipDraftUploadState
    var composerExperience: SipComposerExperience?
    var guidedStep: SipGuidedStep?
    var memoryDetailsExpanded: Bool?
    var drinkAnalysis: DrinkAnalysis?
    /// Immutable, versioned Tasting Lens 2.0 result. This remains separate
    /// from legacy criterion scores and from the user's independent stars.
    var sensorySnapshot: SipSensorySnapshot?
    /// Autosaved, mutable Lens work. This is never published and is cleared
    /// only after an immutable snapshot is completed.
    var sensorySessionDraft: TastingLensSessionDraft?
    /// The primary sip owns the full mutable session draft. Additional sips
    /// carry only `cafeSessionReference`, so Cafe Pulse is never duplicated.
    var cafeSessionDraft: CafeSessionDraft?
    var cafeSessionReference: CafeSessionReference?
    var cafeSessionSipOrder: Int?
    var cafeSessionSipRole: CafeSessionSipRole?
    var sipReorderIntention: SipReorderIntention?
    var v3Step: SipV3ComposerStep?
    private var v3ContextNotes: String?
    private var v3RawNoteVisibility: VisitVisibility?
    var contextScore: Double?
    private var v3ContextRatingCriteria: [SipRatingCriterionSnapshot]?
    var photoFallback: SipPhotoFallback?
    var homeMakeAgain: HomeMakeAgain?

    var contextNotes: String {
        get { v3ContextNotes ?? "" }
        set { v3ContextNotes = newValue }
    }

    var rawNoteVisibility: VisitVisibility {
        get { v3RawNoteVisibility ?? .private }
        set { v3RawNoteVisibility = newValue }
    }

    var contextRatingCriteria: [SipRatingCriterionSnapshot] {
        get { v3ContextRatingCriteria ?? [] }
        set { v3ContextRatingCriteria = newValue }
    }

    var recipePublication: SipRecipePublicationContract {
        get { storedRecipePublication ?? .privateOriginal }
        set { storedRecipePublication = newValue }
    }

    var includesRecipeBlueprint: Bool {
        context == .recipe || brewDetails.recipeName?.remoteTrimmedNonEmpty != nil
    }

    var recipePublicationRequirement: SipRecipePublicationRequirement {
        includesRecipeBlueprint ? recipePublication.requirement : .ready
    }

    init(
        id: UUID = UUID(),
        ownerUserID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        captureMode: SipCaptureMode = .quickSip,
        launchContext: SipComposerLaunchContext = .centralAdd,
        context: JournalEntryContext = .cafe,
        cafe: Cafe? = nil,
        locationName: String = "Home",
        drinkType: DrinkType = .coffee,
        customDrinkType: String = "",
        drinkName: String = "",
        overallScore: Double = 0,
        socialCaption: String = "",
        privateNotes: String = "",
        visibility: VisitVisibility = .private,
        ratingCriteria: [SipRatingCriterionSnapshot] = [],
        orderNotes: String = "",
        tags: [String] = [],
        companions: [String] = [],
        taggedCompanions: [SipCompanion]? = nil,
        recipePublication: SipRecipePublicationContract = .privateOriginal,
        brewMethod: String = "",
        equipment: String = "",
        brewDetails: BrewDetails = .empty,
        localPhotoNames: [String] = [],
        posterPhotoIndex: Int = 0,
        uploadState: SipDraftUploadState = .local,
        composerExperience: SipComposerExperience? = nil,
        guidedStep: SipGuidedStep? = nil,
        memoryDetailsExpanded: Bool? = nil,
        drinkAnalysis: DrinkAnalysis? = nil,
        sensorySnapshot: SipSensorySnapshot? = nil,
        sensorySessionDraft: TastingLensSessionDraft? = nil,
        cafeSessionDraft: CafeSessionDraft? = nil,
        cafeSessionReference: CafeSessionReference? = nil,
        cafeSessionSipOrder: Int? = nil,
        cafeSessionSipRole: CafeSessionSipRole? = nil,
        sipReorderIntention: SipReorderIntention? = nil,
        v3Step: SipV3ComposerStep? = nil,
        contextNotes: String = "",
        rawNoteVisibility: VisitVisibility = .private,
        contextScore: Double? = nil,
        contextRatingCriteria: [SipRatingCriterionSnapshot] = [],
        photoFallback: SipPhotoFallback? = nil,
        homeMakeAgain: HomeMakeAgain? = nil
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.captureMode = captureMode
        self.launchContext = launchContext
        self.context = context
        self.cafe = cafe
        self.locationName = locationName
        self.drinkType = drinkType
        self.customDrinkType = customDrinkType
        self.drinkName = drinkName
        self.overallScore = overallScore
        self.socialCaption = socialCaption
        self.privateNotes = privateNotes
        self.visibility = visibility
        self.ratingCriteria = ratingCriteria
        self.orderNotes = orderNotes
        self.tags = tags
        self.companions = companions
        self.taggedCompanions = taggedCompanions
        self.storedRecipePublication = recipePublication
        self.brewMethod = brewMethod
        self.equipment = equipment
        self.brewDetails = brewDetails
        self.localPhotoNames = localPhotoNames
        self.posterPhotoIndex = posterPhotoIndex
        self.uploadState = uploadState
        self.composerExperience = composerExperience
        self.guidedStep = guidedStep
        self.memoryDetailsExpanded = memoryDetailsExpanded
        self.drinkAnalysis = drinkAnalysis
        self.sensorySnapshot = sensorySnapshot
        self.sensorySessionDraft = sensorySessionDraft
        if context.supportsCafeSession {
            self.cafeSessionDraft = cafeSessionDraft
            self.cafeSessionReference = cafeSessionReference
            self.cafeSessionSipOrder = cafeSessionSipOrder
            self.cafeSessionSipRole = cafeSessionSipRole
            self.sipReorderIntention = sipReorderIntention
        } else {
            self.cafeSessionDraft = nil
            self.cafeSessionReference = nil
            self.cafeSessionSipOrder = nil
            self.cafeSessionSipRole = nil
            self.sipReorderIntention = nil
        }
        self.v3Step = v3Step
        self.v3ContextNotes = contextNotes
        self.v3RawNoteVisibility = rawNoteVisibility
        self.contextScore = contextScore
        self.v3ContextRatingCriteria = contextRatingCriteria
        self.photoFallback = photoFallback
        self.homeMakeAgain = homeMakeAgain
    }

    var ratingsDictionary: [String: Double] {
        // Tasting Lens 2.0 responses have typed scale semantics and must never
        // be flattened into the legacy name-to-star-score dictionary.
        guard sensorySnapshot == nil else { return [:] }
        return ratingCriteria.reduce(into: [:]) { result, criterion in
            let name = criterion.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard criterion.isRelevant, !name.isEmpty,
                  criterion.score >= 0.5, criterion.score <= 5 else { return }
            result[name] = criterion.score
        }
    }

    var ratingTemplateSnapshot: RatingTemplate {
        RatingTemplate(categories: ratingCriteria
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { criterion in
                let name = criterion.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard criterion.isRelevant, !name.isEmpty else { return nil }
                return RatingCategory(id: criterion.id, name: name, weight: max(criterion.weight, 0.25))
            })
    }

    var hasRequiredCore: Bool {
        let hasContext = context == .cafe
            ? cafe != nil
            : locationName.remoteTrimmedNonEmpty != nil
        let hasDrink = drinkName.remoteTrimmedNonEmpty != nil
        let hasRatingPath = resolvedOverallScore >= 0.5 && resolvedOverallScore <= 5
            && (captureMode == .quickSip || sensorySnapshot != nil)
        return hasContext && hasDrink && hasRatingPath
    }

    var resolvedOverallScore: Double {
        overallScore
    }

    var resolvedGuidedStep: SipGuidedStep { guidedStep ?? .context }

    var isMemoryExpanded: Bool { memoryDetailsExpanded ?? false }

    var isEligibleForCafeSession: Bool { context == .cafe && cafe != nil }

    var cafeSessionID: UUID? {
        cafeSessionDraft?.id ?? cafeSessionReference?.id
    }

    var cafeSessionReturnIntention: CafeReturnIntention? {
        cafeSessionDraft?.returnIntention ?? cafeSessionReference?.returnIntention
    }

    var cafeNextMove: CafeNextMove {
        CafeNextMove(
            returnIntention: cafeSessionReturnIntention,
            reorderIntention: sipReorderIntention
        )
    }

    mutating func refreshDrinkAnalysis() {
        drinkAnalysis = DrinkAnalysisParser.analyze(
            drinkName,
            servingVolumeMilliliters: brewDetails.servingVolumeMilliliters,
            explicitShotCount: brewDetails.espressoShotCount,
            userOverrides: drinkAnalysis?.userOverrides ?? [:]
        )
        if let analysis = drinkAnalysis {
            drinkType = analysis.legacyDrinkType
            customDrinkType = analysis.legacyCustomDrinkType ?? ""
        }
    }

    /// True only when a person has supplied evidence worth preserving as a
    /// draft. Composer navigation, seeded criteria, derived analysis, and
    /// empty Cafe Session envelopes must not manufacture an "Untitled sip."
    var hasDraftWorthyUserContent: Bool {
        let hasSensoryWork = sensorySessionDraft.map { session in
            session.ownWords.remoteTrimmedNonEmpty != nil ||
                session.personalEnjoyment != nil ||
                session.responses.contains { response in
                    response.userConfirmed || response.state != .notAsked ||
                        !response.descriptorIDs.isEmpty || !response.choiceIDs.isEmpty ||
                        response.customText?.remoteTrimmedNonEmpty != nil ||
                        response.intensity != nil || response.duration != nil ||
                        response.preference != nil || response.qualityImpression != nil ||
                        response.confidence != nil
                }
        } ?? false
        let hasCafeSessionWork = cafeSessionDraft.map { session in
            session.experienceDraft?.hasMeaningfulContent == true ||
                session.returnIntention != nil || session.repeatComparison != nil
        } ?? false

        return context != .cafe || cafe != nil || launchContext.preselectedCafe != nil ||
            drinkType != .coffee || customDrinkType.remoteTrimmedNonEmpty != nil ||
            drinkName.remoteTrimmedNonEmpty != nil || overallScore > 0 ||
            socialCaption.remoteTrimmedNonEmpty != nil || privateNotes.remoteTrimmedNonEmpty != nil ||
            !localPhotoNames.isEmpty || ratingCriteria.contains(where: { $0.score > 0 }) ||
            brewMethod.remoteTrimmedNonEmpty != nil || equipment.remoteTrimmedNonEmpty != nil ||
            brewDetails.hasStructuredData || orderNotes.remoteTrimmedNonEmpty != nil ||
            !tags.isEmpty || !companions.isEmpty || !(taggedCompanions ?? []).isEmpty ||
            sensorySnapshot != nil || hasSensoryWork || hasCafeSessionWork ||
            sipReorderIntention != nil || contextNotes.remoteTrimmedNonEmpty != nil ||
            contextScore != nil || contextRatingCriteria.contains(where: { $0.score > 0 }) ||
            photoFallback != nil || homeMakeAgain != nil
    }

    /// Compatibility alias for existing domain checks. New persistence gates
    /// should use `hasDraftWorthyUserContent` to make their intent explicit.
    var hasMeaningfulContent: Bool { hasDraftWorthyUserContent }

    mutating func applyContextDefaults(using preferences: CafeVisibilityPreferenceStore) {
        switch context {
        case .cafe:
            visibility = preferences.defaultCafeVisibility
        case .home, .elsewhere, .recipe:
            visibility = .private
            clearCafeSession()
        }
    }

    /// Changes the V3 reflection context without carrying place-specific
    /// evidence into a different kind of memory.
    mutating func selectV3Context(
        _ selectedContext: JournalEntryContext,
        using preferences: CafeVisibilityPreferenceStore = .shared
    ) {
        let normalizedContext: JournalEntryContext = selectedContext == .recipe
            ? .home
            : selectedContext
        let currentContext: JournalEntryContext = context == .recipe ? .home : context
        guard normalizedContext != currentContext else { return }

        context = normalizedContext
        contextNotes = ""
        contextScore = nil
        contextRatingCriteria = []
        homeMakeAgain = nil

        switch normalizedContext {
        case .cafe:
            locationName = ""
        case .home, .recipe:
            cafe = nil
            locationName = "Home"
        case .elsewhere:
            cafe = nil
            locationName = ""
        }

        applyContextDefaults(using: preferences)
    }

    mutating func clearCafeSession() {
        cafeSessionDraft = nil
        cafeSessionReference = nil
        cafeSessionSipOrder = nil
        cafeSessionSipRole = nil
        sipReorderIntention = nil
    }

    mutating func refreshRatingCriteria(from template: RatingTemplate) {
        guard ratingCriteria.isEmpty else { return }
        ratingCriteria = template.categories.enumerated().map { index, category in
            SipRatingCriterionSnapshot(
                id: category.id,
                name: category.name,
                weight: category.weight,
                sortOrder: index
            )
        }
    }

    static func repeatSip(
        from prior: SipDraft,
        ownerUserID: UUID?,
        cafeVisibilityPreferences: CafeVisibilityPreferenceStore = .shared,
        now: Date = Date()
    ) -> SipDraft {
        let repeated = SipDraft(
            ownerUserID: ownerUserID,
            createdAt: now,
            updatedAt: now,
            launchContext: SipComposerLaunchContext(
                source: .repeatSip,
                preselectedCafe: prior.cafe,
                sourceVisitID: prior.id
            ),
            context: prior.context,
            cafe: prior.cafe,
            locationName: prior.locationName,
            drinkType: prior.drinkType,
            customDrinkType: prior.customDrinkType,
            drinkName: prior.drinkName,
            visibility: prior.context == .cafe ? cafeVisibilityPreferences.defaultCafeVisibility : .private,
            ratingCriteria: prior.ratingCriteria.map {
                var criterion = $0
                criterion.score = 0
                return criterion
            },
            orderNotes: prior.orderNotes,
            tags: prior.tags,
            companions: [],
            brewMethod: prior.brewMethod,
            equipment: prior.equipment,
            brewDetails: prior.brewDetails
        )
        return repeated
    }

    static func additionalSip(
        in session: inout CafeSessionDraft,
        cafe: Cafe,
        ownerUserID: UUID?,
        now: Date = .now
    ) -> SipDraft {
        let draftID = UUID()
        if session.ownerUserID == nil {
            session.ownerUserID = ownerUserID
        }
        let order = session.registerAdditionalSipDraft(draftID, now: now)
        return SipDraft(
            id: draftID,
            ownerUserID: session.ownerUserID,
            createdAt: now,
            updatedAt: now,
            launchContext: SipComposerLaunchContext(
                source: .addAnotherSip,
                preselectedCafe: cafe,
                sourceVisitID: session.primaryVisitID
            ),
            context: .cafe,
            cafe: cafe,
            locationName: cafe.consumerDisplayName,
            visibility: session.visibility,
            cafeSessionReference: session.reference,
            cafeSessionSipOrder: order,
            cafeSessionSipRole: .secondary
        )
    }

    static func brewAgain(
        from recipe: SipDraft,
        ownerUserID: UUID?,
        now: Date = Date()
    ) -> SipDraft {
        var details = recipe.brewDetails
        details.sourceRecipeIdentityID = recipe.brewDetails.recipeIdentityID
        details.sourceRecipeVersion = recipe.brewDetails.recipeVersion
        details.recipeName = nil
        details.recipeVersion = nil

        return SipDraft(
            ownerUserID: ownerUserID,
            createdAt: now,
            updatedAt: now,
            launchContext: SipComposerLaunchContext(
                source: .brewAgain,
                sourceRecipeIdentityID: recipe.brewDetails.recipeIdentityID,
                sourceRecipeVersion: recipe.brewDetails.recipeVersion
            ),
            context: .home,
            locationName: recipe.locationName,
            drinkType: recipe.drinkType,
            customDrinkType: recipe.customDrinkType,
            drinkName: recipe.drinkName,
            visibility: .private,
            ratingCriteria: recipe.ratingCriteria.map {
                var criterion = $0
                criterion.score = 0
                return criterion
            },
            brewMethod: recipe.brewMethod,
            equipment: recipe.equipment,
            brewDetails: details
        )
    }

    static func repeatSip(
        from prior: RemoteVisitSummary,
        ownerUserID: UUID?,
        cafeVisibilityPreferences: CafeVisibilityPreferenceStore = .shared,
        now: Date = Date()
    ) -> SipDraft {
        let context = prior.visit.journalContext
        let criteria = prior.visit.orderedRatingScores.enumerated().map { index, score in
            SipRatingCriterionSnapshot(
                name: score.name,
                score: 0,
                weight: score.weight,
                sortOrder: index
            )
        }
        let details = prior.visit.structuredBrewDetails
        var draft = SipDraft(
            ownerUserID: ownerUserID,
            createdAt: now,
            updatedAt: now,
            captureMode: criteria.count > 1 ? .addDetails : .quickSip,
            launchContext: SipComposerLaunchContext(
                source: .repeatSip,
                preselectedCafe: prior.cafe?.localCafe(),
                sourceVisitID: prior.id,
                returnTab: 4
            ),
            context: context,
            cafe: prior.cafe?.localCafe(),
            locationName: prior.visit.locationName?.remoteTrimmedNonEmpty ?? context.locationFallback,
            drinkType: DrinkType.allCases.first {
                $0.rawValue.caseInsensitiveCompare(prior.visit.drinkType ?? "") == .orderedSame
            } ?? .other,
            customDrinkType: prior.visit.drinkTypeCustom ?? "",
            drinkName: prior.visit.drinkDisplayName,
            visibility: context == .cafe ? cafeVisibilityPreferences.defaultCafeVisibility : .private,
            ratingCriteria: criteria,
            orderNotes: details.orderNotes ?? "",
            tags: details.tags ?? [],
            companions: [],
            brewMethod: prior.visit.brewMethod ?? "",
            equipment: prior.visit.equipment ?? "",
            brewDetails: details,
            composerExperience: .guided,
            guidedStep: .rating
        )
        draft.refreshDrinkAnalysis()
        return draft
    }

    static func brewAgain(
        from prior: RemoteVisitSummary,
        ownerUserID: UUID?,
        now: Date = Date()
    ) -> SipDraft {
        brewAgain(
            from: prior,
            recipeProjection: nil,
            ownerUserID: ownerUserID,
            now: now
        )
    }

    static func brewAgain(
        from detail: RemoteVisitDetail,
        ownerUserID: UUID?,
        now: Date = Date()
    ) -> SipDraft {
        brewAgain(
            from: detail.summary,
            recipeProjection: detail.recipeProjection,
            ownerUserID: ownerUserID,
            now: now
        )
    }

    static func brewAgain(
        from prior: RemoteVisitSummary,
        recipeProjection: RemoteVisitRecipeProjection?,
        ownerUserID: UUID?,
        now: Date = Date()
    ) -> SipDraft {
        var draft = repeatSip(from: prior, ownerUserID: ownerUserID, now: now)
        var details = recipeProjection?.resolvedBrewDetails
            ?? (prior.visit.recipeVersionID == nil
                ? prior.visit.structuredBrewDetails
                : .empty)
        details.sourceRecipeIdentityID = details.recipeIdentityID
        details.sourceRecipeVersion = details.recipeVersion
        details.recipeName = nil
        details.recipeVersion = nil
        draft.context = .home
        draft.visibility = .private
        draft.brewMethod = recipeProjection?.brewMethod ?? ""
        draft.equipment = recipeProjection?.equipment ?? ""
        draft.brewDetails = details
        if let sourceRecipeVersionID = recipeProjection?.recipeVersionID
            ?? prior.visit.recipeVersionID {
            draft.recipePublication = SipRecipePublicationContract(
                visibility: .private,
                sourceKind: .adapted,
                redistributionAllowed: false,
                sourceRecipeVersionID: sourceRecipeVersionID,
                acknowledgesPublicReuse: false
            )
        }
        draft.launchContext = SipComposerLaunchContext(
            source: .brewAgain,
            sourceVisitID: prior.id,
            sourceRecipeIdentityID: recipeProjection?.recipeIdentityID
                ?? (prior.visit.recipeVersionID == nil
                    ? prior.visit.structuredBrewDetails.recipeIdentityID
                    : nil),
            sourceRecipeVersion: recipeProjection?.resolvedBrewDetails.recipeVersion
                ?? (prior.visit.recipeVersionID == nil
                    ? prior.visit.structuredBrewDetails.recipeVersion
                    : nil),
            returnTab: 4
        )
        return draft
    }
}
