import Foundation

struct TastingLensSelectionService {
    func makeSelection(
        analysis: DrinkAnalysis?,
        confirmedIdentity: SensoryDrinkIdentity? = nil,
        depth: TastingDepth,
        bundle: SensoryKnowledgeBundle,
        preferences: TastingLensUserPreferences? = nil,
        patterns: [LearnedSensoryPattern] = []
    ) -> TastingLensSelection {
        let identity = confirmedIdentity ?? identity(from: analysis)
        let universal = universalPack(in: bundle)
        let matchingBases = bundle.packs
            .filter { $0.kind == .base && $0.family != .universal }
            .filter { pack in
                guard pack.family == identity.family else { return false }
                return rulesMatch(pack.applicability, identity: identity)
            }
            .sorted(by: packPrecedes)

        let usedUniversalFallback = matchingBases.isEmpty
        let basePack = matchingBases.first ?? universal
        let overlays = bundle.packs
            .filter { $0.kind == .overlay && rulesMatch($0.applicability, identity: identity) }
            .sorted(by: packPrecedes)

        let activePacks = [basePack] + overlays
        let suppressedIDs = Set(activePacks.flatMap(\.suppressedCriterionIDs))
        let scopeID = identity.personalizationScopeID
        let pinnedIDs = Set(preferences?.pinnedCriterionIDs(for: scopeID) ?? [])
        let eligiblePatterns = patterns.filter { $0.scopeID == scopeID }

        var sourcePackIDsByCriterion: [String: [String]] = [:]
        for pack in activePacks {
            for criterionID in pack.criterionIDs {
                sourcePackIDsByCriterion[criterionID, default: []].append(pack.id)
            }
        }

        var candidateIDs = activePacks.flatMap(\.criterionIDs)
        if basePack.id != universal.id {
            candidateIDs.insert(contentsOf: universal.criterionIDs, at: 0)
            for criterionID in universal.criterionIDs {
                sourcePackIDsByCriterion[criterionID, default: []].insert(universal.id, at: 0)
            }
        }
        candidateIDs.append(contentsOf: pinnedIDs)

        let customCriteria = preferences?.customCriteria ?? []
        candidateIDs.append(contentsOf: customCriteria.map(\.id))
        let bundleCriteriaByID = Dictionary(uniqueKeysWithValues: bundle.criteria.map { ($0.id, $0) })
        let customByID = Dictionary(uniqueKeysWithValues: customCriteria.map { ($0.id, $0) })

        var seen = Set<String>()
        let allRanked = candidateIDs.compactMap { criterionID -> RankedSensoryCriterion? in
            guard seen.insert(criterionID).inserted,
                  !suppressedIDs.contains(criterionID),
                  let criterion = bundleCriteriaByID[criterionID] ?? customByID[criterionID],
                  criterion.depths.contains(depth),
                  rulesMatch(criterion.applicability, identity: identity) else {
                return nil
            }

            let isProtected = criterion.measure == .ownWords
                || criterion.measure == .overallEnjoyment
                || criterion.id == "criterion.flavor.web"
                || criterion.id == "criterion.mugsy.leading"
            if !isProtected,
               preferences?.hidesCriterion(targetID: criterion.id, scopeID: scopeID) == true {
                return nil
            }

            let criterionPattern = eligiblePatterns
                .filter { $0.targetType == .criterion && $0.targetID == criterionID }
                .max { $0.rankBoost < $1.rankBoost }
            let descriptorPattern = eligiblePatterns
                .filter { $0.targetType == .descriptor }
                .filter { pattern in
                    criterion.descriptorRootIDs.contains { rootID in
                        isDescriptor(pattern.targetID, beneath: rootID, bundle: bundle)
                    }
                }
                .max { $0.rankBoost < $1.rankBoost }
            let descriptorBoost = descriptorPattern?.rankBoost ?? 0
            let learnedBoost = max(criterionPattern?.rankBoost ?? 0, descriptorBoost)
            let pinBoost = pinnedIDs.contains(criterionID) ? 40 : 0
            let stageRank = criterion.stage.order * 10_000
            let stableRank = stageRank + criterion.order * 10 - pinBoost - learnedBoost

            let origin: SensorySuggestionOrigin
            let explanation: String
            if pinnedIDs.contains(criterionID) {
                origin = .userPinned
                explanation = "Shown because you pinned this question for \(identity.family.title.lowercased())."
            } else if let criterionPattern {
                origin = .learnedPattern
                explanation = criterionPattern.evidenceSummary
            } else if let descriptorPattern {
                origin = .learnedPattern
                explanation = descriptorPattern.evidenceSummary
            } else if !basePack.criterionIDs.contains(criterionID),
                      sourcePackIDsByCriterion[criterionID]?.contains(where: { id in
                overlays.contains(where: { $0.id == id })
            }) == true {
                origin = .modifierOverlay
                explanation = overlayExplanation(for: criterionID, overlays: overlays)
            } else if criterion.measure == .ownWords {
                origin = .neutralPrompt
                explanation = "Your words come before suggestions so Mugshot does not lead the sip."
            } else if customByID[criterionID] != nil {
                origin = .custom
                explanation = "Shown because you added this question to your Lens."
            } else {
                origin = .basePack
                explanation = "Shown because this is \(indefiniteArticle(for: identity.family.title)) \(identity.family.title.lowercased())."
            }

            return RankedSensoryCriterion(
                criterion: criterion,
                rank: stableRank,
                origin: origin,
                explanation: explanation,
                sourcePackIDs: sourcePackIDsByCriterion[criterionID] ?? []
            )
        }
        .sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.criterion.id < rhs.criterion.id
        }
        let ranked = criteriaForDepth(
            allRanked,
            depth: depth,
            specificCriterionIDs: Set(basePack.criterionIDs)
        )

        var descriptorRoots = Set(activePacks.flatMap(\.descriptorRootIDs))
        // Aroma and the flavor web borrow the selected pack's compact broad families.
        // Other criteria can add specialized roots such as texture or finish.
        for rankedCriterion in ranked where
            rankedCriterion.criterion.id != "criterion.aroma.before" &&
            rankedCriterion.criterion.id != "criterion.flavor.web" {
            descriptorRoots.formUnion(rankedCriterion.criterion.descriptorRootIDs)
        }
        if descriptorRoots.isEmpty {
            descriptorRoots.formUnion(ranked.flatMap { $0.criterion.descriptorRootIDs })
        }
        let descriptors = bundle.descriptors
            .filter { descriptor in
                descriptor.applicability.isEmpty ||
                    descriptor.applicability.contains(.universal) ||
                    descriptor.applicability.contains(identity.family)
            }
            .filter { descriptor in
                descriptorRoots.contains { rootID in
                    isDescriptor(descriptor.id, beneath: rootID, bundle: bundle)
                }
            }
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id < rhs.id
            }

        var explanations = [basePack.explanation]
        explanations.append(contentsOf: overlays.map(\.explanation))
        if usedUniversalFallback {
            explanations.append("Mugshot could not confidently identify this drink, so it used the universal offline Lens. You can correct the identity at any time.")
        } else if !identity.userConfirmed {
            explanations.append("The drink identity came from a parser and should be confirmed before it becomes learning evidence.")
        }

        return TastingLensSelection(
            identity: identity,
            basePack: basePack,
            overlays: overlays,
            orderedCriteria: ranked,
            descriptors: descriptors,
            usedUniversalFallback: usedUniversalFallback,
            explanations: explanations
        )
    }

    /// Guided stays useful in a daily ritual by sampling a small, stage-diverse
    /// set. Deep retains the complete applicable pack. Quick owns its own short
    /// page sequence, but keeping protected records here makes selection total.
    private func criteriaForDepth(
        _ ranked: [RankedSensoryCriterion],
        depth: TastingDepth,
        specificCriterionIDs: Set<String>
    ) -> [RankedSensoryCriterion] {
        guard depth == .guided else { return ranked }

        let ownWords = ranked.first { $0.criterion.measure == .ownWords }
        let flavorWeb = ranked.first { $0.criterion.id == "criterion.flavor.web" }
        let mugsy = ranked.first { $0.criterion.id == "criterion.mugsy.leading" }
        let enjoyment = ranked.first { $0.criterion.measure == .overallEnjoyment }
        let protectedIDs = Set([ownWords?.id, flavorWeb?.id, mugsy?.id, enjoyment?.id].compactMap { $0 })
        let candidates = ranked.filter {
            !protectedIDs.contains($0.id)
                && $0.criterion.id != "criterion.confidence"
                && $0.criterion.measure != .qualityImpression
        }
        let orderedCandidates = candidates.sorted {
            let lhsPriority = guidedPriority($0, specificCriterionIDs: specificCriterionIDs)
            let rhsPriority = guidedPriority($1, specificCriterionIDs: specificCriterionIDs)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.id < $1.id
        }

        let limit = 5
        var selected: [RankedSensoryCriterion] = []
        var selectedIDs = Set<String>()
        var selectedStages = Set<SensoryStage>()

        func append(_ candidate: RankedSensoryCriterion) {
            guard selected.count < limit, selectedIDs.insert(candidate.id).inserted else { return }
            selected.append(candidate)
            selectedStages.insert(candidate.criterion.stage)
        }

        // Personal and learned choices win first, but never consume the whole journey.
        for candidate in orderedCandidates where
            candidate.origin == .userPinned
                || candidate.origin == .learnedPattern
                || candidate.origin == .custom {
            append(candidate)
            if selected.count == 2 { break }
        }

        // Reserve room for drink-specific distinctions before generic prompts.
        for candidate in orderedCandidates where
            specificCriterionIDs.contains(candidate.id)
                && !selectedStages.contains(candidate.criterion.stage) {
            append(candidate)
            if selected.filter({ specificCriterionIDs.contains($0.id) }).count == 2 { break }
        }

        let stageOrder: [SensoryStage] = [
            .aroma, .firstSip, .flavor, .mouthfeel, .finish,
            .structure, .temperature, .appearance, .personal
        ]
        for stage in stageOrder {
            guard selected.count < limit else { break }
            guard !selectedStages.contains(stage),
                  let candidate = orderedCandidates.first(where: {
                      $0.criterion.stage == stage && !selectedIDs.contains($0.id)
                  }) else {
                continue
            }
            append(candidate)
        }
        for candidate in orderedCandidates where selected.count < limit {
            append(candidate)
        }

        var result: [RankedSensoryCriterion] = []
        if let ownWords { result.append(ownWords) }
        if let flavorWeb { result.append(flavorWeb) }
        if let mugsy { result.append(mugsy) }
        result.append(contentsOf: selected.sorted {
            if $0.criterion.stage.order != $1.criterion.stage.order {
                return $0.criterion.stage.order < $1.criterion.stage.order
            }
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.id < $1.id
        })
        if let enjoyment { result.append(enjoyment) }
        return result
    }

    private func guidedPriority(
        _ candidate: RankedSensoryCriterion,
        specificCriterionIDs: Set<String>
    ) -> Int {
        switch candidate.origin {
        case .userPinned: return 0
        case .learnedPattern: return 1
        case .custom: return 2
        case .basePack where specificCriterionIDs.contains(candidate.id): return 3
        case .modifierOverlay: return 4
        case .neutralPrompt, .basePack: return 5
        case .aiCandidate: return 6
        }
    }

    func identity(from analysis: DrinkAnalysis?) -> SensoryDrinkIdentity {
        guard let analysis else {
            return SensoryDrinkIdentity(
                rawName: "",
                family: .unknown,
                confidence: 0,
                provenance: .fallback
            )
        }

        let normalized = analysis.rawDrinkName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let hasMilk = analysis.milk != nil ||
            [" latte", "milk tea", "with milk", "cappuccino", "flat white", "cortado"]
                .contains(where: normalized.contains)
        let family = sensoryFamily(analysis: analysis, normalizedName: normalized, hasMilk: hasMilk)
        let preparation = sensoryPreparation(analysis: analysis, family: family, normalizedName: normalized)
        let temperature: SensoryServingTemperature
        switch analysis.temperature {
        case .hot: temperature = .hot
        case .iced: temperature = .iced
        case .frozen: temperature = .frozen
        case .coldBrew: temperature = .coldExtracted
        }

        let sweetenerTerms = ["sugar", "sweetener", "honey", "maple", "syrup", "agave"]
        let sweeteners = Array(Set((analysis.additions + analysis.flavors).filter { term in
            sweetenerTerms.contains(where: term.lowercased().contains)
        })).sorted()
        var modifiers: [SensoryDrinkModifier] = []
        if let milk = analysis.milk {
            modifiers.append(.init(id: "milk.\(slug(milk))", kind: .milk, label: milk))
        } else if hasMilk {
            modifiers.append(.init(id: "milk.unspecified", kind: .milk, label: "milk"))
        }
        modifiers.append(contentsOf: sweeteners.map {
            .init(id: "sweetener.\(slug($0))", kind: .sweetener, label: $0)
        })
        modifiers.append(contentsOf: analysis.flavors.map {
            .init(id: "flavor.\(slug($0))", kind: .flavor, label: $0)
        })
        modifiers.append(contentsOf: analysis.additions.filter { !sweeteners.contains($0) }.map {
            .init(id: "addition.\(slug($0))", kind: .other, label: $0)
        })

        return SensoryDrinkIdentity(
            rawName: analysis.rawDrinkName,
            family: family,
            preparation: preparation,
            temperature: temperature,
            milk: analysis.milk ?? (hasMilk ? "milk" : nil),
            sweeteners: sweeteners,
            flavors: analysis.flavors,
            additions: analysis.additions,
            modifiers: modifiers,
            confidence: analysis.confidence,
            provenance: analysis.provenance == "local_rules" ? .localParser : .remoteParser,
            userConfirmed: false
        )
    }

    private func sensoryFamily(
        analysis: DrinkAnalysis,
        normalizedName: String,
        hasMilk: Bool
    ) -> SensoryBeverageFamily {
        if normalizedName.contains("matcha") { return hasMilk ? .matchaLatte : .matcha }
        if normalizedName.contains("hojicha") {
            if hasMilk { return .hojichaLatte }
            return normalizedName.contains("powder") ? .hojichaPowder : .hojichaLeaf
        }
        if normalizedName.contains("oolong") { return hasMilk ? .milkTea : .oolongTea }
        if normalizedName.contains("white tea") { return hasMilk ? .milkTea : .whiteTea }
        if normalizedName.contains("black tea") || normalizedName.contains("earl grey") || normalizedName.contains("assam") {
            return hasMilk ? .milkTea : .blackTea
        }
        if normalizedName.contains("green tea") || normalizedName.contains("sencha") || normalizedName.contains("gyokuro") {
            return hasMilk ? .milkTea : .greenTea
        }
        if ["herbal", "tisane", "rooibos", "chamomile", "peppermint"].contains(where: normalizedName.contains) {
            return hasMilk ? .milkTea : .herbalInfusion
        }
        if normalizedName.contains("milk tea") || normalizedName.contains("boba") || normalizedName.contains("chai") {
            return .milkTea
        }

        switch analysis.family {
        case .espresso: return hasMilk ? .milkCoffee : .espresso
        case .brewedCoffee: return .brewedCoffee
        case .matcha: return hasMilk ? .matchaLatte : .matcha
        case .hojicha: return hasMilk ? .hojichaLatte : .hojichaLeaf
        case .tea: return hasMilk ? .milkTea : .blackTea
        case .chai: return .milkTea
        case .hotChocolate, .unknown: return .unknown
        }
    }

    private func sensoryPreparation(
        analysis: DrinkAnalysis,
        family: SensoryBeverageFamily,
        normalizedName: String
    ) -> SensoryPreparation {
        switch family {
        case .matcha, .matchaLatte, .hojichaPowder, .hojichaLatte:
            return .whiskedPowder
        case .hojichaLeaf, .greenTea, .blackTea, .whiteTea, .oolongTea, .herbalInfusion:
            return .steepedLeaf
        case .milkTea:
            return .milkTea
        default:
            break
        }

        switch analysis.preparation {
        case .espresso: return .espresso
        case .americano: return .americano
        case .pourOver, .chemex: return .pourOver
        case .drip: return .drip
        case .frenchPress, .aeropress: return .immersion
        case .coldBrew: return .coldBrew
        case .latte, .mocha, .macchiato: return .latte
        case .cappuccino: return .cappuccino
        case .flatWhite: return .flatWhite
        case .cortado: return .cortado
        case .matcha, .hojicha: return .whiskedPowder
        case .tea, .chai: return normalizedName.contains("milk") ? .milkTea : .steepedLeaf
        case .hotChocolate: return .other
        case .unknown: return .unknown
        }
    }

    private func universalPack(in bundle: SensoryKnowledgeBundle) -> SensoryPackDefinition {
        if let pack = bundle.packs.first(where: { $0.kind == .base && $0.family == .universal }) {
            return pack
        }
        // Validation rejects this state. Keeping a value fallback makes selection total for previews.
        return SensoryPackDefinition(
            id: "pack.universal.missing",
            kind: .base,
            title: "Universal Lens",
            family: .universal,
            priority: 0,
            applicability: [],
            criterionIDs: [],
            suppressedCriterionIDs: [],
            descriptorRootIDs: [],
            explanation: "Universal tasting prompts.",
            evidenceSourceIDs: []
        )
    }

    private func rulesMatch(_ rules: [SensoryApplicabilityRule], identity: SensoryDrinkIdentity) -> Bool {
        rules.allSatisfy { rule in
            let values = identityValues(for: rule.field, identity: identity)
            let expected = rule.values.map(normalized)
            let matched: Bool
            switch rule.operation {
            case .equals, .oneOf:
                matched = values.contains { expected.contains(normalized($0)) }
            case .contains:
                matched = values.contains { actual in
                    expected.contains { normalized(actual).contains($0) }
                }
            case .exists:
                matched = !values.isEmpty
            }
            return rule.negated ? !matched : matched
        }
    }

    private func identityValues(
        for field: SensoryApplicabilityField,
        identity: SensoryDrinkIdentity
    ) -> [String] {
        switch field {
        case .family: return [identity.family.rawValue]
        case .preparation: return [identity.preparation.rawValue]
        case .temperature: return [identity.temperature.rawValue]
        case .modifierKind: return identity.modifiers.map { $0.kind.rawValue }
        case .milk: return identity.milk.map { [$0] } ?? []
        case .flavor: return identity.flavors
        case .addition: return identity.additions + identity.sweeteners
        }
    }

    private func isDescriptor(
        _ descriptorID: String,
        beneath rootID: String,
        bundle: SensoryKnowledgeBundle
    ) -> Bool {
        if descriptorID == rootID { return true }
        var current = bundle.descriptor(id: descriptorID)
        var visited = Set<String>()
        while let parentID = current?.parentID, visited.insert(parentID).inserted {
            if parentID == rootID { return true }
            current = bundle.descriptor(id: parentID)
        }
        return false
    }

    private func overlayExplanation(
        for criterionID: String,
        overlays: [SensoryPackDefinition]
    ) -> String {
        overlays.first(where: { $0.criterionIDs.contains(criterionID) })?.explanation ??
            "Shown because of a confirmed drink detail."
    }

    private func packPrecedes(_ lhs: SensoryPackDefinition, _ rhs: SensoryPackDefinition) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.id < rhs.id
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
    }

    private func slug(_ value: String) -> String {
        normalized(value)
            .replacingOccurrences(of: "[^a-z0-9]+", with: ".", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private func indefiniteArticle(for value: String) -> String {
        guard let first = value.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }
}

struct TastingLensSnapshotFactory {
    func makeSnapshot(
        session: TastingLensSessionDraft,
        selection: TastingLensSelection,
        bundle: SensoryKnowledgeBundle,
        createdAt: Date = .now
    ) -> SipSensorySnapshot {
        let criteriaByID = Dictionary(uniqueKeysWithValues: selection.criteria.map { ($0.id, $0) })
        let responseSnapshots = session.responses.compactMap { response -> SipSensoryResponseSnapshot? in
            guard let criterion = criteriaByID[response.criterionID],
                  criterion.measure != .overallEnjoyment else {
                return nil
            }

            let descriptors = response.descriptorIDs.compactMap { descriptorID -> SensoryDescriptorSnapshot? in
                guard let descriptor = bundle.descriptor(id: descriptorID) else { return nil }
                return SensoryDescriptorSnapshot(
                    id: descriptor.id,
                    displayedTitle: descriptor.title,
                    displayedPath: descriptorPath(for: descriptor, bundle: bundle)
                )
            }
            let scale = criterion.scaleID.flatMap(bundle.scale(id:))
            return SipSensoryResponseSnapshot(
                id: response.id,
                criterionID: criterion.id,
                displayedCriterionTitle: criterion.title,
                dimension: criterion.dimension,
                measure: criterion.measure,
                state: response.state,
                descriptors: descriptors,
                selectedChoices: response.choiceIDs.map { choiceID in
                    SensoryChoiceSnapshot(
                        id: choiceID,
                        displayedLabel: criterion.options.first(where: { $0.id == choiceID })?.label ?? choiceID
                    )
                },
                customText: response.customText,
                intensity: criterion.measure == .intensity ? response.intensity : nil,
                duration: criterion.measure == .duration ? response.duration : nil,
                preference: response.preference,
                qualityImpression: criterion.measure == .qualityImpression ? response.qualityImpression : nil,
                confidence: response.confidence,
                scaleID: scale?.id,
                scaleVersion: scale?.version,
                displayedScaleAnchors: scale?.anchors.map {
                    SensoryScaleAnchorSnapshot(
                        value: $0.value,
                        displayedLabel: $0.label,
                        displayedAnchor: $0.anchor
                    )
                } ?? [],
                bundleID: bundle.bundleID,
                bundleContentVersion: bundle.contentVersion,
                sourcePackIDs: response.sourcePackIDs,
                suggestionOrigin: response.suggestionOrigin,
                displayedOrder: response.displayedOrder,
                aiProvenance: response.aiProvenance,
                userConfirmed: response.userConfirmed
            )
        }

        return SipSensorySnapshot(
            bundleID: bundle.bundleID,
            bundleContentVersion: bundle.contentVersion,
            identity: session.identity,
            depth: session.depth,
            ownWords: session.ownWords,
            responses: responseSnapshots,
            personalEnjoyment: session.personalEnjoyment,
            createdAt: createdAt
        )
    }

    private func descriptorPath(
        for descriptor: SensoryDescriptorDefinition,
        bundle: SensoryKnowledgeBundle
    ) -> [String] {
        var path = [descriptor.title]
        var parentID = descriptor.parentID
        var visited = Set<String>()
        while let currentID = parentID,
              visited.insert(currentID).inserted,
              let parent = bundle.descriptor(id: currentID) {
            path.insert(parent.title, at: 0)
            parentID = parent.parentID
        }
        return path
    }
}
