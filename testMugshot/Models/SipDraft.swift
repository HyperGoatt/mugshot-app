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
        brewMethod: String = "",
        equipment: String = "",
        brewDetails: BrewDetails = .empty,
        localPhotoNames: [String] = [],
        posterPhotoIndex: Int = 0,
        uploadState: SipDraftUploadState = .local,
        composerExperience: SipComposerExperience? = nil,
        guidedStep: SipGuidedStep? = nil,
        memoryDetailsExpanded: Bool? = nil,
        drinkAnalysis: DrinkAnalysis? = nil
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
    }

    var ratingsDictionary: [String: Double] {
        ratingCriteria.reduce(into: [:]) { result, criterion in
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
        return hasContext && hasDrink && resolvedOverallScore >= 0.5 && resolvedOverallScore <= 5
    }

    var resolvedOverallScore: Double {
        guard captureMode == .addDetails else { return overallScore }
        return ratingTemplateSnapshot.calculateOverallScore(ratings: ratingsDictionary)
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
            !tags.isEmpty || !companions.isEmpty || guidedStep != nil || drinkAnalysis != nil
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
}
