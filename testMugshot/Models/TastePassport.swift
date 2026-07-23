import Foundation

enum TastePassportVisibility: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case privateOnly = "private"
    case friends
    case everyone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privateOnly: "Private"
        case .friends: "Friends"
        case .everyone: "Everyone"
        }
    }

    var systemImage: String {
        switch self {
        case .privateOnly: "lock.fill"
        case .friends: "person.2.fill"
        case .everyone: "globe.americas.fill"
        }
    }

    var ownerExplanation: String {
        switch self {
        case .privateOnly:
            "Only you can see your Taste Passport."
        case .friends:
            "You and your confirmed friends can see your Taste Passport."
        case .everyone:
            "Anyone signed in to Mugshot can see your Taste Passport."
        }
    }
}

enum TastePassportDescriptorKind: String, Decodable, Hashable, Sendable {
    case orderPreference = "order_preference"
    case sensoryLens = "sensory_lens"
    case ritual
}

struct TastePassportDescriptor: Decodable, Equatable, Identifiable, Sendable {
    let kind: TastePassportDescriptorKind
    let label: String

    var id: TastePassportDescriptorKind { kind }

    var displayLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TastePassportConfidenceBand: String, Decodable, Equatable, Sendable {
    case emerging
    case growing
    case established

    var cautiousLabel: String {
        switch self {
        case .emerging: "Emerging patterns"
        case .growing: "Growing patterns"
        case .established: "Established patterns"
        }
    }
}

struct TastePassportProjection: Decodable, Equatable, Sendable {
    let userID: UUID
    let visibility: TastePassportVisibility
    let descriptors: [TastePassportDescriptor]
    let summaryDescription: String
    let isForming: Bool
    let confidenceBand: TastePassportConfidenceBand
    let calculationVersion: String
    let updatedAt: String?

    var isCompatibilityPreview: Bool {
        calculationVersion.hasPrefix("taste-passport-compatibility-")
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case visibility, descriptors
        case summaryDescription = "description"
        case isForming = "is_forming"
        case confidenceBand = "confidence_band"
        case calculationVersion = "calculation_version"
        case updatedAt = "updated_at"
    }
}

struct TastePassportVisibilityProjection: Decodable, Equatable, Sendable {
    let userID: UUID
    let visibility: TastePassportVisibility

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case visibility
    }

    func value(forAccountID accountID: UUID) throws -> TastePassportVisibility {
        guard userID == accountID else {
            throw TastePassportContractError.accountScopeMismatch
        }
        return visibility
    }
}

enum TastePassportAccessState: Equatable, Sendable {
    case hidden
    case insufficient(visibility: TastePassportVisibility)
    case compatibilityInsufficient
    case visible(TastePassportProjection)

    static func resolve(
        _ projection: TastePassportProjection?,
        requestedUserID: UUID
    ) throws -> TastePassportAccessState {
        guard let projection else { return .hidden }
        guard projection.userID == requestedUserID else {
            throw TastePassportContractError.accountScopeMismatch
        }
        guard !projection.isForming else {
            // Deliberately discard all inferred labels in the insufficient
            // state. UI cannot accidentally expose a low-evidence trait.
            if projection.isCompatibilityPreview {
                return .compatibilityInsufficient
            }
            return .insufficient(visibility: projection.visibility)
        }

        let kinds = Set(projection.descriptors.map(\.kind))
        guard projection.descriptors.count == 3,
              kinds == Set(TastePassportDescriptorKind.allContractKinds),
              projection.descriptors.allSatisfy({ !$0.displayLabel.isEmpty }) else {
            throw TastePassportContractError.invalidProjection
        }
        return .visible(projection)
    }
}

enum TastePassportLoadState: Equatable, Sendable {
    case loading
    case loaded(TastePassportAccessState)
    case failed(String)
}

enum TastePassportContractError: LocalizedError, Equatable {
    case accountScopeMismatch
    case invalidProjection
    case saveWasNotConfirmed
    case audienceControlsUnavailable

    var errorDescription: String? {
        switch self {
        case .accountScopeMismatch:
            "This Taste Passport response belongs to a different account. Nothing was shown or changed."
        case .invalidProjection:
            "This Taste Passport could not be shown safely. Please try again."
        case .saveWasNotConfirmed:
            "Mugshot could not confirm that your Taste Passport audience was saved."
        case .audienceControlsUnavailable:
            "Taste Passport audience controls are waiting for the Mugshot backend update. Your audience was not changed."
        }
    }
}

enum TastePassportCompatibility {
    static func accessState(
        userID: UUID,
        summary: TasteIdentitySummary,
        visibility: TastePassportVisibility = .everyone,
        confidenceBand: TastePassportConfidenceBand = .emerging,
        updatedAt: String? = nil
    ) throws -> TastePassportAccessState {
        let labels = summary.isForming
            ? ["Taste Forming", "Lens Forming", "Ritual Forming"]
            : summary.descriptors
        guard labels.count == 3 else {
            throw TastePassportContractError.invalidProjection
        }
        let projection = TastePassportProjection(
            userID: userID,
            visibility: visibility,
            descriptors: [
                TastePassportDescriptor(kind: .orderPreference, label: labels[0]),
                TastePassportDescriptor(kind: .sensoryLens, label: labels[1]),
                TastePassportDescriptor(kind: .ritual, label: labels[2])
            ],
            summaryDescription: summary.description,
            isForming: summary.isForming,
            confidenceBand: confidenceBand,
            calculationVersion: "taste-passport-compatibility-1",
            updatedAt: updatedAt
        )
        return try TastePassportAccessState.resolve(
            projection,
            requestedUserID: userID
        )
    }

    static func confidenceBand(signals: [RemoteTasteSignal]) -> TastePassportConfidenceBand {
        let confidence = signals
            .filter(\.isDurableClaim)
            .map(\.confidence)
            .max() ?? 0
        if confidence >= 0.75 { return .established }
        if confidence >= 0.40 { return .growing }
        return .emerging
    }

    static func publicConfidenceBand(visibleVisitCount: Int) -> TastePassportConfidenceBand {
        if visibleVisitCount >= 10 { return .established }
        if visibleVisitCount >= 5 { return .growing }
        return .emerging
    }
}

private extension TastePassportDescriptorKind {
    static let allContractKinds: [TastePassportDescriptorKind] = [
        .orderPreference,
        .sensoryLens,
        .ritual
    ]
}
