import Foundation

// MARK: - Independent cafe rating

enum CafeExperienceDepth: String, Codable, CaseIterable, Identifiable {
    case quick
    case guided
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .guided: return "Guided"
        case .deep: return "Deep"
        }
    }
}

/// Independent cafe-experience score. Direct star input still moves in
/// half-steps, while an explicitly adopted criteria suggestion may preserve one
/// decimal place. No Cafe Pulse observation silently changes this value.
struct CafeExperienceRating: Codable, Equatable, Comparable {
    let tenths: Int

    init?(value: Double) {
        let scaled = value * 10
        guard (scaled.rounded() - scaled).magnitude < 0.000_001 else { return nil }
        let tenths = Int(scaled.rounded())
        guard (10...50).contains(tenths) else { return nil }
        self.tenths = tenths
    }

    var value: Double { Double(tenths) / 10 }

    static func < (lhs: CafeExperienceRating, rhs: CafeExperienceRating) -> Bool {
        lhs.tenths < rhs.tenths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Double.self)
        guard let rating = Self(value: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cafe experience must be from 1 through 5 with at most one decimal place."
            )
        }
        self = rating
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Visit context

enum CafeVisitMode: String, Codable, CaseIterable, Identifiable {
    case grabAndGo = "grab_and_go"
    case stayAwhile = "stay_awhile"
    case workStudy = "work_study"
    case social
    case foodFocused = "food_focused"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grabAndGo: return "Grab-and-go"
        case .stayAwhile: return "Stay awhile"
        case .workStudy: return "Work or study"
        case .social: return "Social"
        case .foodFocused: return "Food-focused"
        }
    }
}

enum CafeVisitOverlay: String, Codable, CaseIterable, Identifiable, Hashable {
    case outdoorSeating = "outdoor_seating"
    case busyQueue = "busy_queue"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outdoorSeating: return "Outdoor seating"
        case .busyQueue: return "Busy queue"
        }
    }
}

struct CafeVisitContext: Codable, Equatable {
    var mode: CafeVisitMode
    var overlays: Set<CafeVisitOverlay>

    init(
        mode: CafeVisitMode = .stayAwhile,
        overlays: Set<CafeVisitOverlay> = []
    ) {
        self.mode = mode
        self.overlays = overlays
    }

    private enum CodingKeys: String, CodingKey {
        case mode, overlays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(CafeVisitMode.self, forKey: .mode)
        overlays = Set(
            try container.decodeIfPresent([CafeVisitOverlay].self, forKey: .overlays) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(
            overlays.sorted { $0.rawValue < $1.rawValue },
            forKey: .overlays
        )
    }
}

// MARK: - Cafe Pulse observations

enum CafeExperienceDimension: String, Codable, CaseIterable, Identifiable {
    case atmosphere
    case musicAndSound = "music_and_sound"
    case hospitality
    case menuAndValue = "menu_and_value"
    case comfortAndPracticality = "comfort_and_practicality"
    case communityAndCharacter = "community_and_character"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atmosphere: return "Atmosphere"
        case .musicAndSound: return "Music and sound"
        case .hospitality: return "Hospitality"
        case .menuAndValue: return "Menu and value"
        case .comfortAndPracticality: return "Comfort and practicality"
        case .communityAndCharacter: return "Community and character"
        }
    }
}

enum CafeExperienceFacet: String, Codable, CaseIterable, Identifiable, Hashable {
    case atmosphereDesign = "atmosphere.design"
    case atmosphereLighting = "atmosphere.lighting"
    case atmosphereEnergy = "atmosphere.energy"
    case atmosphereScent = "atmosphere.scent"
    case atmosphereTemperature = "atmosphere.temperature"
    case atmosphereSenseOfPlace = "atmosphere.sense_of_place"

    case soundPlaylistFit = "music_and_sound.playlist_fit"
    case soundVolume = "music_and_sound.volume"
    case soundConversationNoise = "music_and_sound.conversation_noise"
    case soundAcoustics = "music_and_sound.acoustics"
    case soundCalmOrStimulation = "music_and_sound.calm_or_stimulation"
    case soundStreetNoise = "music_and_sound.street_noise"

    case hospitalityWelcome = "hospitality.welcome"
    case hospitalityClarity = "hospitality.clarity"
    case hospitalityAttentiveness = "hospitality.attentiveness"
    case hospitalityKnowledge = "hospitality.knowledge"
    case hospitalityPace = "hospitality.pace"
    case hospitalityCommunication = "hospitality.communication"
    case hospitalityRecovery = "hospitality.recovery"
    case hospitalityOrderAccuracy = "hospitality.order_accuracy"
    case hospitalityExpectationSetting = "hospitality.expectation_setting"

    case menuRange = "menu_and_value.range"
    case menuSignatures = "menu_and_value.signatures"
    case menuFood = "menu_and_value.food"
    case menuDietaryClarity = "menu_and_value.dietary_clarity"
    case menuPricing = "menu_and_value.pricing"
    case menuPortionAndQuality = "menu_and_value.portion_and_quality"
    case menuPairing = "menu_and_value.pairing"

    case comfortSeating = "comfort_and_practicality.seating"
    case comfortCleanliness = "comfort_and_practicality.cleanliness"
    case comfortOrderingFlow = "comfort_and_practicality.ordering_flow"
    case comfortWait = "comfort_and_practicality.wait"
    case comfortWifi = "comfort_and_practicality.wifi"
    case comfortOutlets = "comfort_and_practicality.outlets"
    case comfortTableSpace = "comfort_and_practicality.table_space"
    case comfortAccessibility = "comfort_and_practicality.accessibility"
    case comfortRestrooms = "comfort_and_practicality.restrooms"
    case comfortOutdoorComfort = "comfort_and_practicality.outdoor_comfort"
    case comfortPickupFlow = "comfort_and_practicality.pickup_flow"
    case comfortPackaging = "comfort_and_practicality.packaging"
    case comfortGroupSeating = "comfort_and_practicality.group_seating"
    case comfortShadeAndWeather = "comfort_and_practicality.shade_and_weather"

    case communityLocalIdentity = "community_and_character.local_identity"
    case communitySoloSocialBalance = "community_and_character.solo_social_balance"
    case communityInclusiveness = "community_and_character.inclusiveness"
    case communityRegulars = "community_and_character.regulars"
    case communityMemorableCharacter = "community_and_character.memorable_character"

    var id: String { rawValue }

    var dimension: CafeExperienceDimension {
        switch self {
        case .atmosphereDesign, .atmosphereLighting, .atmosphereEnergy, .atmosphereScent,
             .atmosphereTemperature, .atmosphereSenseOfPlace:
            return .atmosphere
        case .soundPlaylistFit, .soundVolume, .soundConversationNoise, .soundAcoustics,
             .soundCalmOrStimulation, .soundStreetNoise:
            return .musicAndSound
        case .hospitalityWelcome, .hospitalityClarity, .hospitalityAttentiveness,
             .hospitalityKnowledge, .hospitalityPace, .hospitalityCommunication,
             .hospitalityRecovery, .hospitalityOrderAccuracy,
             .hospitalityExpectationSetting:
            return .hospitality
        case .menuRange, .menuSignatures, .menuFood, .menuDietaryClarity, .menuPricing,
             .menuPortionAndQuality, .menuPairing:
            return .menuAndValue
        case .comfortSeating, .comfortCleanliness, .comfortOrderingFlow, .comfortWait,
             .comfortWifi, .comfortOutlets, .comfortTableSpace, .comfortAccessibility,
             .comfortRestrooms, .comfortOutdoorComfort, .comfortPickupFlow,
             .comfortPackaging, .comfortGroupSeating, .comfortShadeAndWeather:
            return .comfortAndPracticality
        case .communityLocalIdentity, .communitySoloSocialBalance, .communityInclusiveness,
             .communityRegulars, .communityMemorableCharacter:
            return .communityAndCharacter
        }
    }

    var title: String {
        switch self {
        case .atmosphereDesign: return "Design"
        case .atmosphereLighting: return "Lighting"
        case .atmosphereEnergy: return "Energy"
        case .atmosphereScent: return "Scent"
        case .atmosphereTemperature: return "Temperature"
        case .atmosphereSenseOfPlace: return "Sense of place"
        case .soundPlaylistFit: return "Playlist fit"
        case .soundVolume: return "Volume"
        case .soundConversationNoise: return "Conversation noise"
        case .soundAcoustics: return "Acoustics"
        case .soundCalmOrStimulation: return "Calm or stimulation"
        case .soundStreetNoise: return "Street noise"
        case .hospitalityWelcome: return "Welcome"
        case .hospitalityClarity: return "Clarity"
        case .hospitalityAttentiveness: return "Attentiveness"
        case .hospitalityKnowledge: return "Knowledge"
        case .hospitalityPace: return "Pace"
        case .hospitalityCommunication: return "Communication"
        case .hospitalityRecovery: return "Service recovery"
        case .hospitalityOrderAccuracy: return "Order accuracy"
        case .hospitalityExpectationSetting: return "Expectation setting"
        case .menuRange: return "Menu range"
        case .menuSignatures: return "Signature offerings"
        case .menuFood: return "Food"
        case .menuDietaryClarity: return "Dietary clarity"
        case .menuPricing: return "Pricing"
        case .menuPortionAndQuality: return "Portion and quality"
        case .menuPairing: return "Pairing"
        case .comfortSeating: return "Seating"
        case .comfortCleanliness: return "Cleanliness"
        case .comfortOrderingFlow: return "Ordering flow"
        case .comfortWait: return "Wait"
        case .comfortWifi: return "Wi-Fi"
        case .comfortOutlets: return "Outlets"
        case .comfortTableSpace: return "Table space"
        case .comfortAccessibility: return "Accessibility"
        case .comfortRestrooms: return "Restrooms"
        case .comfortOutdoorComfort: return "Outdoor comfort"
        case .comfortPickupFlow: return "Pickup flow"
        case .comfortPackaging: return "Packaging"
        case .comfortGroupSeating: return "Group seating"
        case .comfortShadeAndWeather: return "Shade and weather"
        case .communityLocalIdentity: return "Local identity"
        case .communitySoloSocialBalance: return "Solo and social balance"
        case .communityInclusiveness: return "Inclusiveness"
        case .communityRegulars: return "Regulars"
        case .communityMemorableCharacter: return "Memorable character"
        }
    }
}

enum CafeExperienceImpact: String, Codable, CaseIterable, Identifiable, Hashable {
    case lifted
    case neutral
    case detracted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lifted: return "Lifted"
        case .neutral: return "Neutral"
        case .detracted: return "Detracted"
        }
    }
}

enum CafeExperienceObservationState: String, Codable, CaseIterable {
    case notAsked = "not_asked"
    case skipped
    case notObserved = "not_observed"
    case notRelevant = "not_relevant"
    case observed

    var contributesEvidence: Bool { self == .observed }
}

struct CafeExperienceObservation: Identifiable, Codable, Equatable {
    let id: UUID
    let dimension: CafeExperienceDimension
    let facet: CafeExperienceFacet?
    let state: CafeExperienceObservationState
    let impact: CafeExperienceImpact?
    /// Private memory only. Learning and public projections must ignore it.
    let privateNote: String?

    init?(
        id: UUID = UUID(),
        dimension: CafeExperienceDimension,
        facet: CafeExperienceFacet? = nil,
        state: CafeExperienceObservationState,
        impact: CafeExperienceImpact? = nil,
        privateNote: String? = nil
    ) {
        guard facet == nil || facet?.dimension == dimension else { return nil }
        guard (state == .observed) == (impact != nil) else { return nil }
        self.id = id
        self.dimension = dimension
        self.facet = facet
        self.state = state
        self.impact = impact
        self.privateNote = privateNote?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    static func observed(
        id: UUID = UUID(),
        dimension: CafeExperienceDimension,
        impact: CafeExperienceImpact,
        privateNote: String? = nil
    ) -> Self {
        Self(
            id: id,
            dimension: dimension,
            state: .observed,
            impact: impact,
            privateNote: privateNote
        )!
    }

    static func observed(
        id: UUID = UUID(),
        facet: CafeExperienceFacet,
        impact: CafeExperienceImpact,
        privateNote: String? = nil
    ) -> Self {
        Self(
            id: id,
            dimension: facet.dimension,
            facet: facet,
            state: .observed,
            impact: impact,
            privateNote: privateNote
        )!
    }

    static func unobserved(
        id: UUID = UUID(),
        dimension: CafeExperienceDimension,
        facet: CafeExperienceFacet? = nil,
        state: CafeExperienceObservationState
    ) -> Self? {
        guard state != .observed else { return nil }
        return Self(id: id, dimension: dimension, facet: facet, state: state)
    }

    private enum CodingKeys: String, CodingKey {
        case id, dimension, facet, state, impact, privateNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let dimension = try container.decode(CafeExperienceDimension.self, forKey: .dimension)
        let facet = try container.decodeIfPresent(CafeExperienceFacet.self, forKey: .facet)
        let state = try container.decode(CafeExperienceObservationState.self, forKey: .state)
        let impact = try container.decodeIfPresent(CafeExperienceImpact.self, forKey: .impact)
        let privateNote = try container.decodeIfPresent(String.self, forKey: .privateNote)
        guard let observation = Self(
            id: id,
            dimension: dimension,
            facet: facet,
            state: state,
            impact: impact,
            privateNote: privateNote
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .state,
                in: container,
                debugDescription: "Observed Cafe Pulse entries require an impact and facets must match their dimension."
            )
        }
        self = observation
    }
}

// MARK: - Intent and Next Move

enum CafeReturnIntention: String, Codable, CaseIterable, Identifiable {
    case yes
    case maybe
    case no

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: return "Yes"
        case .maybe: return "Maybe"
        case .no: return "No"
        }
    }
}

enum SipReorderIntention: String, Codable, CaseIterable, Identifiable {
    case yes
    case maybe
    case no

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: return "Yes"
        case .maybe: return "Maybe"
        case .no: return "No"
        }
    }
}

enum CafeNextMoveKind: String, Codable, CaseIterable, Identifiable {
    case comeBackForThis = "come_back_for_this"
    case comeBackTryAnother = "come_back_try_another"
    case thisDrinkElsewhere = "this_drink_elsewhere"
    case probablyNotAgain = "probably_not_again"
    case notSureYet = "not_sure_yet"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comeBackForThis: return "Come back for this"
        case .comeBackTryAnother: return "Come back, try another"
        case .thisDrinkElsewhere: return "This drink, elsewhere"
        case .probablyNotAgain: return "Probably not again"
        case .notSureYet: return "Not sure yet"
        }
    }
}

struct CafeNextMove: Codable, Equatable {
    let returnIntention: CafeReturnIntention?
    let reorderIntention: SipReorderIntention?
    let kind: CafeNextMoveKind

    init(
        returnIntention: CafeReturnIntention?,
        reorderIntention: SipReorderIntention?
    ) {
        self.returnIntention = returnIntention
        self.reorderIntention = reorderIntention
        kind = Self.resolve(
            returnIntention: returnIntention,
            reorderIntention: reorderIntention
        )
    }

    static func resolve(
        returnIntention: CafeReturnIntention?,
        reorderIntention: SipReorderIntention?
    ) -> CafeNextMoveKind {
        switch (returnIntention, reorderIntention) {
        case (.yes, .yes):
            return .comeBackForThis
        case (.yes, .no):
            return .comeBackTryAnother
        case (.no, .yes):
            return .thisDrinkElsewhere
        case (.no, .no):
            return .probablyNotAgain
        default:
            return .notSureYet
        }
    }

    private enum CodingKeys: String, CodingKey {
        case returnIntention, reorderIntention, kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            returnIntention: try container.decodeIfPresent(
                CafeReturnIntention.self,
                forKey: .returnIntention
            ),
            reorderIntention: try container.decodeIfPresent(
                SipReorderIntention.self,
                forKey: .reorderIntention
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(returnIntention, forKey: .returnIntention)
        try container.encodeIfPresent(reorderIntention, forKey: .reorderIntention)
        try container.encode(kind, forKey: .kind)
    }
}

enum CafeRepeatComparison: String, Codable, CaseIterable, Identifiable, Hashable {
    case same
    case better
    case worse
    case different

    var id: String { rawValue }

    var title: String {
        switch self {
        case .same: return "Same"
        case .better: return "Better"
        case .worse: return "Worse"
        case .different: return "Different"
        }
    }
}

// MARK: - Drafts and immutable snapshots

struct CafeExperienceDraft: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var depth: CafeExperienceDepth
    var ownWords: String
    var cafeRating: CafeExperienceRating?
    var visitContext: CafeVisitContext
    var observations: [CafeExperienceObservation]
    /// Optional V3 evidence. The authored cafe score remains independent and
    /// criteria only provide an advisory weighted suggestion.
    var ratingCriteria: [SipRatingCriterionSnapshot]?
    var privateNotes: String
    /// Draft-only navigation state. Snapshots intentionally omit this because
    /// it describes where the editor resumes, not cafe-experience evidence.
    var journeyStepID: String?
    var updatedAt: Date

    init(
        schemaVersion: Int = currentSchemaVersion,
        depth: CafeExperienceDepth = .quick,
        ownWords: String = "",
        cafeRating: CafeExperienceRating? = nil,
        visitContext: CafeVisitContext = CafeVisitContext(),
        observations: [CafeExperienceObservation] = [],
        ratingCriteria: [SipRatingCriterionSnapshot]? = nil,
        privateNotes: String = "",
        journeyStepID: String? = nil,
        updatedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.depth = depth
        self.ownWords = ownWords
        self.cafeRating = cafeRating
        self.visitContext = visitContext
        self.observations = observations
        self.ratingCriteria = ratingCriteria
        self.privateNotes = privateNotes
        self.journeyStepID = journeyStepID
        self.updatedAt = updatedAt
    }

    var hasMeaningfulContent: Bool {
        cafeRating != nil ||
            ownWords.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty != nil ||
            !observations.isEmpty ||
            !(ratingCriteria ?? []).isEmpty ||
            privateNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty != nil
    }

    mutating func record(_ observation: CafeExperienceObservation, now: Date = .now) {
        observations.removeAll {
            $0.dimension == observation.dimension && $0.facet == observation.facet
        }
        observations.append(observation)
        updatedAt = now
    }

    mutating func removeObservation(
        dimension: CafeExperienceDimension,
        facet: CafeExperienceFacet? = nil,
        now: Date = .now
    ) {
        observations.removeAll { $0.dimension == dimension && $0.facet == facet }
        updatedAt = now
    }
}

struct CafeExperienceSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    let sessionID: UUID
    let ownerUserID: UUID
    let cafeID: UUID
    let schemaVersion: Int
    let createdAt: Date
    let depth: CafeExperienceDepth
    let ownWords: String?
    let cafeRating: CafeExperienceRating?
    let visitContext: CafeVisitContext
    let observations: [CafeExperienceObservation]
    let ratingCriteria: [SipRatingCriterionSnapshot]?
    let returnIntention: CafeReturnIntention?
    let repeatComparison: CafeRepeatComparison?
    let privateNotes: String?

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        ownerUserID: UUID,
        cafeID: UUID,
        createdAt: Date = .now,
        draft: CafeExperienceDraft,
        returnIntention: CafeReturnIntention?,
        repeatComparison: CafeRepeatComparison?
    ) {
        self.id = id
        self.sessionID = sessionID
        self.ownerUserID = ownerUserID
        self.cafeID = cafeID
        self.schemaVersion = draft.schemaVersion
        self.createdAt = createdAt
        self.depth = draft.depth
        self.ownWords = draft.ownWords.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.cafeRating = draft.cafeRating
        self.visitContext = draft.visitContext
        self.observations = draft.observations
        self.ratingCriteria = draft.ratingCriteria
        self.returnIntention = returnIntention
        self.repeatComparison = repeatComparison
        self.privateNotes = draft.privateNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    func rebindingCafeID(_ cafeID: UUID) -> CafeExperienceSnapshot {
        guard self.cafeID != cafeID else { return self }
        return CafeExperienceSnapshot(
            id: id,
            sessionID: sessionID,
            ownerUserID: ownerUserID,
            cafeID: cafeID,
            createdAt: createdAt,
            draft: CafeExperienceDraft(
                schemaVersion: schemaVersion,
                depth: depth,
                ownWords: ownWords ?? "",
                cafeRating: cafeRating,
                visitContext: visitContext,
                observations: observations,
                ratingCriteria: ratingCriteria,
                privateNotes: privateNotes ?? "",
                updatedAt: createdAt
            ),
            returnIntention: returnIntention,
            repeatComparison: repeatComparison
        )
    }
}

struct CafeExperienceShareProjection: Codable, Equatable {
    var includesCafeRating: Bool
    var includesNextMove: Bool
    /// Only explicitly selected observation IDs may be projected. Full
    /// responses and private notes never belong in the projection.
    var observationIDs: Set<UUID>

    init(
        includesCafeRating: Bool = false,
        includesNextMove: Bool = false,
        observationIDs: Set<UUID> = []
    ) {
        self.includesCafeRating = includesCafeRating
        self.includesNextMove = includesNextMove
        self.observationIDs = observationIDs
    }

    var isEmpty: Bool {
        !includesCafeRating && !includesNextMove && observationIDs.isEmpty
    }

    /// Cafe stars and observations are claims from a recorded Cafe Pulse.
    /// Next Move is derived from the independently stored return and reorder
    /// intentions, so it can be shared without manufacturing a snapshot.
    var requiresSnapshot: Bool {
        includesCafeRating || !observationIDs.isEmpty
    }
}

// MARK: - Cafe sessions

enum CafeSessionStatus: String, Codable, CaseIterable {
    case draft
    case active
    case complete
    case abandoned

    var countsAsPhysicalVisit: Bool { self == .active || self == .complete }
}

enum CafeSessionSipRole: String, Codable, CaseIterable {
    case primary
    case secondary
}

struct CafeSessionReference: Codable, Equatable {
    let id: UUID
    let ownerUserID: UUID?
    let cafeID: UUID
    let startedAt: Date
    let visibility: VisitVisibility
    let primaryVisitID: UUID?
    let returnIntention: CafeReturnIntention?
}

struct CafeSessionDraft: Identifiable, Codable, Equatable {
    let id: UUID
    var ownerUserID: UUID?
    let cafeID: UUID
    var startedAt: Date
    var updatedAt: Date
    var status: CafeSessionStatus
    var visibility: VisitVisibility
    var primaryVisitID: UUID?
    var primarySipDraftID: UUID
    var sipDraftIDs: [UUID]
    var returnIntention: CafeReturnIntention?
    var repeatComparison: CafeRepeatComparison?
    var experienceDraft: CafeExperienceDraft?
    var shareProjection: CafeExperienceShareProjection

    init(
        id: UUID = UUID(),
        ownerUserID: UUID? = nil,
        cafeID: UUID,
        startedAt: Date = .now,
        updatedAt: Date = .now,
        status: CafeSessionStatus = .draft,
        visibility: VisitVisibility = .friends,
        primaryVisitID: UUID? = nil,
        primarySipDraftID: UUID,
        sipDraftIDs: [UUID]? = nil,
        returnIntention: CafeReturnIntention? = nil,
        repeatComparison: CafeRepeatComparison? = nil,
        experienceDraft: CafeExperienceDraft? = CafeExperienceDraft(),
        shareProjection: CafeExperienceShareProjection = CafeExperienceShareProjection()
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.cafeID = cafeID
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.status = status
        self.visibility = visibility
        self.primaryVisitID = primaryVisitID
        self.primarySipDraftID = primarySipDraftID
        let suppliedIDs = sipDraftIDs ?? [primarySipDraftID]
        self.sipDraftIDs = [primarySipDraftID] + suppliedIDs.filter { $0 != primarySipDraftID }
        self.returnIntention = returnIntention
        self.repeatComparison = repeatComparison
        self.experienceDraft = experienceDraft
        self.shareProjection = shareProjection
    }

    var reference: CafeSessionReference {
        CafeSessionReference(
            id: id,
            ownerUserID: ownerUserID,
            cafeID: cafeID,
            startedAt: startedAt,
            visibility: visibility,
            primaryVisitID: primaryVisitID,
            returnIntention: returnIntention
        )
    }

    var nextSipOrder: Int { sipDraftIDs.count }

    @discardableResult
    mutating func registerAdditionalSipDraft(_ sipDraftID: UUID, now: Date = .now) -> Int {
        if let existingIndex = sipDraftIDs.firstIndex(of: sipDraftID) {
            return existingIndex
        }
        let order = nextSipOrder
        sipDraftIDs.append(sipDraftID)
        updatedAt = now
        return order
    }

    func makeSnapshot(now: Date = .now) -> CafeExperienceSnapshot? {
        guard let ownerUserID else {
            return nil
        }
        let resolvedDraft = experienceDraft ?? CafeExperienceDraft()
        guard resolvedDraft.hasMeaningfulContent ||
                returnIntention != nil ||
                repeatComparison != nil else {
            return nil
        }
        return CafeExperienceSnapshot(
            sessionID: id,
            ownerUserID: ownerUserID,
            cafeID: cafeID,
            createdAt: now,
            draft: resolvedDraft,
            returnIntention: returnIntention,
            repeatComparison: repeatComparison
        )
    }
}

struct CafeSession: Identifiable, Codable, Equatable {
    let id: UUID
    var ownerUserID: UUID
    var cafeID: UUID
    var startedAt: Date
    var endedAt: Date?
    var status: CafeSessionStatus
    var visibility: VisitVisibility
    var primaryVisitID: UUID?
    var visitIDs: [UUID]
    var returnIntention: CafeReturnIntention?
    var experienceSnapshot: CafeExperienceSnapshot?

    init(
        id: UUID = UUID(),
        ownerUserID: UUID,
        cafeID: UUID,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        status: CafeSessionStatus = .draft,
        visibility: VisitVisibility = .friends,
        primaryVisitID: UUID? = nil,
        visitIDs: [UUID] = [],
        returnIntention: CafeReturnIntention? = nil,
        experienceSnapshot: CafeExperienceSnapshot? = nil
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.cafeID = cafeID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.visibility = visibility
        self.primaryVisitID = primaryVisitID
        self.visitIDs = visitIDs
        self.returnIntention = returnIntention
        self.experienceSnapshot = experienceSnapshot
    }
}

// MARK: - Relationship summaries

enum CafeRelationshipStage: String, Codable, CaseIterable {
    case unrated
    case firstImpression = "first_impression"
    case emergingView = "emerging_view"
    case trendReady = "trend_ready"

    static func resolve(ratedSessionCount: Int) -> Self {
        switch ratedSessionCount {
        case ..<1: return .unrated
        case 1: return .firstImpression
        case 2: return .emergingView
        default: return .trendReady
        }
    }

    var title: String {
        switch self {
        case .unrated: return "Not rated yet"
        case .firstImpression: return "First impression"
        case .emergingView: return "Emerging view"
        case .trendReady: return "Your pattern"
        }
    }
}

enum CafeRelationshipTrend: String, Codable, CaseIterable {
    case same
    case better
    case worse
    case different
    case mixed
}

struct CafeRelationshipStats: Codable, Equatable {
    let cafeID: UUID
    let sessionCount: Int
    let ratedSessionCount: Int
    let averageCafeRating: Double?
    let stage: CafeRelationshipStage
    let explicitTrend: CafeRelationshipTrend?
    let latestReturnIntention: CafeReturnIntention?

    init(cafeID: UUID, sessions: [CafeSession]) {
        let cafeSessions = sessions
            .filter { $0.cafeID == cafeID && $0.status.countsAsPhysicalVisit }
            .sorted { $0.startedAt < $1.startedAt }
        let ratedSnapshots = cafeSessions.compactMap(\.experienceSnapshot).filter {
            $0.cafeRating != nil
        }
        let values = ratedSnapshots.compactMap(\.cafeRating?.value)

        self.cafeID = cafeID
        self.sessionCount = cafeSessions.count
        self.ratedSessionCount = values.count
        self.averageCafeRating = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        self.stage = CafeRelationshipStage.resolve(ratedSessionCount: values.count)
        self.explicitTrend = Self.resolveTrend(
            comparisons: ratedSnapshots.compactMap(\.repeatComparison),
            isEligible: values.count >= 3
        )
        self.latestReturnIntention = cafeSessions.reversed().compactMap {
            $0.returnIntention ?? $0.experienceSnapshot?.returnIntention
        }.first
    }

    private static func resolveTrend(
        comparisons: [CafeRepeatComparison],
        isEligible: Bool
    ) -> CafeRelationshipTrend? {
        guard isEligible, !comparisons.isEmpty else { return nil }
        let unique = Set(comparisons)
        guard unique.count == 1, let comparison = unique.first else { return .mixed }
        switch comparison {
        case .same: return .same
        case .better: return .better
        case .worse: return .worse
        case .different: return .different
        }
    }
}

// MARK: - Context-sensitive prompt routing

enum CafeExperiencePromptRouter {
    static func facets(
        for dimension: CafeExperienceDimension,
        context: CafeVisitContext,
        depth: CafeExperienceDepth
    ) -> [CafeExperienceFacet] {
        guard depth != .quick else { return [] }
        let all = CafeExperienceFacet.allCases.filter { $0.dimension == dimension }
        guard depth == .guided else { return all }

        var preferred = guidedDefaults[dimension] ?? []
        preferred.append(contentsOf: contextualFacets(for: context))
        let selected = Set(preferred)
        return all.filter(selected.contains)
    }

    static func contextualFacets(for context: CafeVisitContext) -> [CafeExperienceFacet] {
        var facets: [CafeExperienceFacet]
        switch context.mode {
        case .grabAndGo:
            facets = [
                .hospitalityClarity, .hospitalityPace, .hospitalityOrderAccuracy,
                .comfortOrderingFlow, .comfortWait, .comfortPickupFlow, .comfortPackaging
            ]
        case .stayAwhile:
            facets = [.atmosphereEnergy, .soundVolume, .comfortSeating, .comfortCleanliness]
        case .workStudy:
            facets = [
                .atmosphereLighting, .soundCalmOrStimulation, .comfortSeating,
                .comfortWifi, .comfortOutlets, .comfortTableSpace
            ]
        case .social:
            facets = [
                .soundConversationNoise, .comfortSeating, .comfortGroupSeating, .menuFood,
                .menuPairing, .hospitalityPace, .communitySoloSocialBalance
            ]
        case .foodFocused:
            facets = [
                .menuRange, .menuFood, .menuDietaryClarity, .menuPricing,
                .menuPortionAndQuality, .menuPairing
            ]
        }

        if context.overlays.contains(.outdoorSeating) {
            facets.append(contentsOf: [
                .comfortOutdoorComfort, .comfortShadeAndWeather, .comfortCleanliness,
                .soundStreetNoise
            ])
        }
        if context.overlays.contains(.busyQueue) {
            facets.append(contentsOf: [
                .hospitalityExpectationSetting, .hospitalityCommunication,
                .hospitalityRecovery,
                .comfortOrderingFlow, .comfortWait
            ])
        }
        return facets.removingDuplicates()
    }

    private static let guidedDefaults: [CafeExperienceDimension: [CafeExperienceFacet]] = [
        .atmosphere: [.atmosphereDesign, .atmosphereEnergy, .atmosphereSenseOfPlace],
        .musicAndSound: [.soundPlaylistFit, .soundVolume],
        .hospitality: [.hospitalityWelcome, .hospitalityAttentiveness, .hospitalityPace],
        .menuAndValue: [.menuRange, .menuSignatures, .menuPricing],
        .comfortAndPracticality: [.comfortSeating, .comfortCleanliness, .comfortOrderingFlow],
        .communityAndCharacter: [
            .communityLocalIdentity, .communitySoloSocialBalance, .communityMemorableCharacter
        ]
    ]
}

// MARK: - Step-based Cafe Pulse journey

struct CafePulseJourneyStep: Identifiable, Equatable {
    enum Content: Equatable {
        case ownWords
        case rating
        case context
        case quickSignals
        case dimension(
            CafeExperienceDimension,
            facets: [CafeExperienceFacet],
            includesBroadSignal: Bool
        )
        case repeatComparison
        case intentions
        case privateNotes
        case sharing
        case quickWrapUp
    }

    let id: String
    let content: Content
}

struct CafePulseJourneyPlan: Equatable {
    let depth: CafeExperienceDepth
    let steps: [CafePulseJourneyStep]

    static func make(
        depth: CafeExperienceDepth,
        context: CafeVisitContext,
        showsRepeatComparison: Bool
    ) -> Self {
        switch depth {
        case .quick:
            return Self(
                depth: depth,
                steps: [
                    CafePulseJourneyStep(id: "rating", content: .rating),
                    CafePulseJourneyStep(id: "quick-signals", content: .quickSignals),
                    CafePulseJourneyStep(id: "quick-wrap-up", content: .quickWrapUp)
                ]
            )
        case .guided:
            var steps = openingSteps
            steps.append(contentsOf: CafeExperienceDimension.allCases.map { dimension in
                CafePulseJourneyStep(
                    id: "guided-\(dimension.rawValue)",
                    content: .dimension(
                        dimension,
                        facets: CafeExperiencePromptRouter.facets(
                            for: dimension,
                            context: context,
                            depth: .guided
                        ),
                        includesBroadSignal: true
                    )
                )
            })
            appendClosingSteps(
                to: &steps,
                showsRepeatComparison: showsRepeatComparison
            )
            return Self(depth: depth, steps: steps)
        case .deep:
            var steps = openingSteps
            for dimension in CafeExperienceDimension.allCases {
                steps.append(
                    CafePulseJourneyStep(
                        id: "deep-\(dimension.rawValue)-broad",
                        content: .dimension(
                            dimension,
                            facets: [],
                            includesBroadSignal: true
                        )
                    )
                )

                let facets = CafeExperiencePromptRouter.facets(
                    for: dimension,
                    context: context,
                    depth: .deep
                )
                for (index, chunk) in facets.chunked(maxCount: 4).enumerated() {
                    steps.append(
                        CafePulseJourneyStep(
                            id: "deep-\(dimension.rawValue)-details-\(index + 1)",
                            content: .dimension(
                                dimension,
                                facets: chunk,
                                includesBroadSignal: false
                            )
                        )
                    )
                }
            }
            appendClosingSteps(
                to: &steps,
                showsRepeatComparison: showsRepeatComparison
            )
            return Self(depth: depth, steps: steps)
        }
    }

    func resolvedIndex(for stepID: String?) -> Int {
        guard let stepID,
              let index = steps.firstIndex(where: { $0.id == stepID }) else {
            return 0
        }
        return index
    }

    func step(after stepID: String?) -> CafePulseJourneyStep? {
        let nextIndex = resolvedIndex(for: stepID) + 1
        guard steps.indices.contains(nextIndex) else { return nil }
        return steps[nextIndex]
    }

    func step(before stepID: String?) -> CafePulseJourneyStep? {
        let priorIndex = resolvedIndex(for: stepID) - 1
        guard steps.indices.contains(priorIndex) else { return nil }
        return steps[priorIndex]
    }

    func isLastStep(_ stepID: String?) -> Bool {
        resolvedIndex(for: stepID) == steps.count - 1
    }

    private static let openingSteps: [CafePulseJourneyStep] = [
        CafePulseJourneyStep(id: "own-words", content: .ownWords),
        CafePulseJourneyStep(id: "rating", content: .rating),
        CafePulseJourneyStep(id: "context", content: .context)
    ]

    private static func appendClosingSteps(
        to steps: inout [CafePulseJourneyStep],
        showsRepeatComparison: Bool
    ) {
        if showsRepeatComparison {
            steps.append(
                CafePulseJourneyStep(
                    id: "repeat-comparison",
                    content: .repeatComparison
                )
            )
        }
        steps.append(contentsOf: [
            CafePulseJourneyStep(id: "intentions", content: .intentions),
            CafePulseJourneyStep(id: "private-notes", content: .privateNotes),
            CafePulseJourneyStep(id: "sharing", content: .sharing)
        ])
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }

    func chunked(maxCount: Int) -> [[Element]] {
        guard maxCount > 0 else { return [self] }
        return stride(from: 0, to: count, by: maxCount).map { start in
            Array(self[start..<Swift.min(start + maxCount, count)])
        }
    }
}
