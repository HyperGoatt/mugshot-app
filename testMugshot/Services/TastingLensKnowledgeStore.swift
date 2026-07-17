import Foundation

enum TastingLensKnowledgeError: Error, LocalizedError, Equatable {
    case resourceMissing(String)
    case duplicateID(collection: String, id: String)
    case unknownReference(owner: String, referencedID: String)
    case invalidCriterion(String)
    case noUniversalFallback

    var errorDescription: String? {
        switch self {
        case .resourceMissing(let name):
            return "The offline sensory knowledge resource \(name) could not be found."
        case .duplicateID(let collection, let id):
            return "The sensory bundle contains duplicate \(collection) ID \(id)."
        case .unknownReference(let owner, let referencedID):
            return "\(owner) references missing sensory ID \(referencedID)."
        case .invalidCriterion(let id):
            return "Sensory criterion \(id) has incompatible measure or scale semantics."
        case .noUniversalFallback:
            return "The sensory bundle has no universal fallback pack."
        }
    }
}

final class TastingLensKnowledgeStore {
    static let shared = TastingLensKnowledgeStore()
    static let resourceName = "SensoryKnowledgeBundle.v1"

    private let resourceBundle: Bundle
    private let decoder: JSONDecoder

    init(resourceBundle: Bundle = .main, decoder: JSONDecoder = JSONDecoder()) {
        self.resourceBundle = resourceBundle
        self.decoder = decoder
    }

    func loadBundle() throws -> SensoryKnowledgeBundle {
        let candidates: [URL?] = [
            resourceBundle.url(forResource: Self.resourceName, withExtension: "json"),
            resourceBundle.url(forResource: Self.resourceName, withExtension: "json", subdirectory: "Resources"),
            Bundle.main.url(forResource: Self.resourceName, withExtension: "json"),
            Bundle.main.url(forResource: Self.resourceName, withExtension: "json", subdirectory: "Resources"),
            Bundle(for: TastingLensResourceLocator.self).url(forResource: Self.resourceName, withExtension: "json"),
            Bundle(for: TastingLensResourceLocator.self).url(
                forResource: Self.resourceName,
                withExtension: "json",
                subdirectory: "Resources"
            )
        ]

        guard let url = candidates.compactMap({ $0 }).first else {
            throw TastingLensKnowledgeError.resourceMissing("\(Self.resourceName).json")
        }
        return try loadBundle(from: url)
    }

    func loadBundle(from url: URL) throws -> SensoryKnowledgeBundle {
        try decode(Data(contentsOf: url))
    }

    func decode(_ data: Data) throws -> SensoryKnowledgeBundle {
        let bundle = try decoder.decode(SensoryKnowledgeBundle.self, from: data)
        try validate(bundle)
        return bundle
    }

    func validate(_ bundle: SensoryKnowledgeBundle) throws {
        try requireUnique(bundle.sources.map(\.id), collection: "source")
        try requireUnique(bundle.scales.map(\.id), collection: "scale")
        try requireUnique(bundle.criteria.map(\.id), collection: "criterion")
        try requireUnique(bundle.descriptors.map(\.id), collection: "descriptor")
        try requireUnique(bundle.packs.map(\.id), collection: "pack")

        let sourceIDs = Set(bundle.sources.map(\.id))
        let scaleIDs = Set(bundle.scales.map(\.id))
        let criterionIDs = Set(bundle.criteria.map(\.id))
        let descriptorIDs = Set(bundle.descriptors.map(\.id))

        for scale in bundle.scales {
            try requireUnique(scale.anchors.map(\.value), collection: "anchor in \(scale.id)")
            guard !scale.anchors.isEmpty,
                  scale.anchors.map(\.value) == scale.anchors.map(\.value).sorted() else {
                throw TastingLensKnowledgeError.invalidCriterion(scale.id)
            }
        }

        guard bundle.packs.contains(where: {
            $0.kind == .base && $0.family == .universal
        }) else {
            throw TastingLensKnowledgeError.noUniversalFallback
        }

        for descriptor in bundle.descriptors {
            if let parentID = descriptor.parentID, !descriptorIDs.contains(parentID) {
                throw TastingLensKnowledgeError.unknownReference(owner: descriptor.id, referencedID: parentID)
            }
            try validateReferences(descriptor.evidenceSourceIDs, known: sourceIDs, owner: descriptor.id)
        }

        for criterion in bundle.criteria {
            try requireUnique(criterion.options.map(\.id), collection: "choice in \(criterion.id)")
            if let scaleID = criterion.scaleID, !scaleIDs.contains(scaleID) {
                throw TastingLensKnowledgeError.unknownReference(owner: criterion.id, referencedID: scaleID)
            }
            try validateReferences(criterion.descriptorRootIDs, known: descriptorIDs, owner: criterion.id)
            try validateReferences(criterion.evidenceSourceIDs, known: sourceIDs, owner: criterion.id)
            try validateReferences(
                criterion.options.compactMap(\.descriptorID),
                known: descriptorIDs,
                owner: criterion.id
            )

            if (criterion.measure == .intensity || criterion.measure == .duration),
               criterion.scaleID == nil {
                throw TastingLensKnowledgeError.invalidCriterion(criterion.id)
            }

            if criterion.measure == .overallEnjoyment {
                guard criterion.scaleID == "scale.personal_enjoyment_half_stars",
                      criterion.dimension == .personalResponse else {
                    throw TastingLensKnowledgeError.invalidCriterion(criterion.id)
                }
            } else if criterion.scaleID == "scale.personal_enjoyment_half_stars" {
                throw TastingLensKnowledgeError.invalidCriterion(criterion.id)
            }

            if criterion.measure == .qualityImpression,
               criterion.scaleID != "scale.quality_impression_5" {
                throw TastingLensKnowledgeError.invalidCriterion(criterion.id)
            }
        }

        for pack in bundle.packs {
            try validateReferences(pack.criterionIDs, known: criterionIDs, owner: pack.id)
            try validateReferences(pack.suppressedCriterionIDs, known: criterionIDs, owner: pack.id)
            try validateReferences(pack.descriptorRootIDs, known: descriptorIDs, owner: pack.id)
            try validateReferences(pack.evidenceSourceIDs, known: sourceIDs, owner: pack.id)
        }
    }

    private func requireUnique<Value: Hashable>(_ ids: [Value], collection: String) throws {
        var seen = Set<Value>()
        for id in ids where !seen.insert(id).inserted {
            throw TastingLensKnowledgeError.duplicateID(
                collection: collection,
                id: String(describing: id)
            )
        }
    }

    private func validateReferences(
        _ references: [String],
        known: Set<String>,
        owner: String
    ) throws {
        if let missing = references.first(where: { !known.contains($0) }) {
            throw TastingLensKnowledgeError.unknownReference(owner: owner, referencedID: missing)
        }
    }
}

private final class TastingLensResourceLocator {}
