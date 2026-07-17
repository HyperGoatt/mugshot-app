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

struct SipRatingCriterionSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var score: Double
    var weight: Double
    var sortOrder: Int
    var relevanceOverride: Bool?

    init(
        id: UUID = UUID(),
        name: String,
        score: Double = 0,
        weight: Double = 1,
        sortOrder: Int,
        relevanceOverride: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.score = score
        self.weight = weight
        self.sortOrder = sortOrder
        self.relevanceOverride = relevanceOverride
    }

    var isRelevant: Bool {
        get { relevanceOverride ?? true }
        set { relevanceOverride = newValue }
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
    var context: JournalEntryContext
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
        visibility: VisitVisibility = .friends,
        ratingCriteria: [SipRatingCriterionSnapshot] = [],
        orderNotes: String = "",
        tags: [String] = [],
        companions: [String] = [],
        taggedCompanions: [SipCompanion]? = nil,
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
        sensorySessionDraft: TastingLensSessionDraft? = nil
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

    var hasMeaningfulContent: Bool {
        captureMode == .addDetails || context != .cafe || cafe != nil ||
            drinkName.remoteTrimmedNonEmpty != nil || overallScore > 0 ||
            socialCaption.remoteTrimmedNonEmpty != nil || privateNotes.remoteTrimmedNonEmpty != nil ||
            !localPhotoNames.isEmpty || ratingCriteria.contains(where: { $0.score > 0 }) ||
            brewDetails.hasStructuredData || orderNotes.remoteTrimmedNonEmpty != nil ||
            !tags.isEmpty || !companions.isEmpty || guidedStep != nil || drinkAnalysis != nil ||
            sensorySnapshot != nil || sensorySessionDraft != nil
    }

    mutating func applyContextDefaults(using preferences: CafeVisibilityPreferenceStore) {
        switch context {
        case .cafe:
            visibility = preferences.defaultCafeVisibility
        case .home, .recipe:
            visibility = .private
        }
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
        var draft = repeatSip(from: prior, ownerUserID: ownerUserID, now: now)
        var details = prior.visit.structuredBrewDetails
        details.sourceRecipeIdentityID = details.recipeIdentityID
        details.sourceRecipeVersion = details.recipeVersion
        details.recipeName = nil
        details.recipeVersion = nil
        draft.context = .home
        draft.visibility = .private
        draft.brewDetails = details
        draft.launchContext = SipComposerLaunchContext(
            source: .brewAgain,
            sourceVisitID: prior.id,
            sourceRecipeIdentityID: prior.visit.structuredBrewDetails.recipeIdentityID,
            sourceRecipeVersion: prior.visit.structuredBrewDetails.recipeVersion,
            returnTab: 4
        )
        return draft
    }
}
