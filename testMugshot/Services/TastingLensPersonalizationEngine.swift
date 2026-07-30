import Foundation

struct TastingLensPersonalizationEngine {
    let minimumConfirmedSupport: Int
    let minimumComparisonSupport: Int

    init(minimumConfirmedSupport: Int = 3, minimumComparisonSupport: Int = 3) {
        self.minimumConfirmedSupport = max(minimumConfirmedSupport, 3)
        self.minimumComparisonSupport = max(minimumComparisonSupport, 3)
    }

    /// Derives transparent prompt-order patterns from immutable, account-scoped history.
    /// The caller must pass only snapshots owned by `userID`.
    func learnedPatterns(
        userID: UUID,
        snapshots: [SipSensorySnapshot],
        preferences: TastingLensUserPreferences,
        bundle: SensoryKnowledgeBundle? = nil,
        now: Date = .now
    ) -> [LearnedSensoryPattern] {
        guard preferences.userID == userID else { return [] }

        var patterns: [LearnedSensoryPattern] = []
        let confirmedSnapshots = snapshots.filter(\.identity.userConfirmed)
        let snapshotsByScope = Dictionary(grouping: confirmedSnapshots, by: \.personalizationScopeID)

        for (scopeID, scopeSnapshots) in snapshotsByScope {
            let criterionEvidence = evidenceGroups(
                scopeSnapshots: scopeSnapshots,
                scopeID: scopeID,
                targetType: .criterion,
                preferences: preferences
            )
            let descriptorEvidence = evidenceGroups(
                scopeSnapshots: scopeSnapshots,
                scopeID: scopeID,
                targetType: .descriptor,
                preferences: preferences
            )

            for (key, evidence) in criterionEvidence where evidence.distinctSnapshotCount >= minimumConfirmedSupport {
                let title = bundle?.criterion(id: key)?.title ?? evidence.fallbackTitle
                patterns.append(makePattern(
                    userID: userID,
                    scopeID: scopeID,
                    targetType: .criterion,
                    targetID: key,
                    title: title,
                    evidence: evidence,
                    allScopeSnapshots: scopeSnapshots,
                    now: now
                ))
            }

            for (key, evidence) in descriptorEvidence where evidence.distinctSnapshotCount >= minimumConfirmedSupport {
                let title = bundle?.descriptor(id: key)?.title ?? evidence.fallbackTitle
                patterns.append(makePattern(
                    userID: userID,
                    scopeID: scopeID,
                    targetType: .descriptor,
                    targetID: key,
                    title: title,
                    evidence: evidence,
                    allScopeSnapshots: scopeSnapshots,
                    now: now
                ))
            }
        }

        return patterns.sorted { lhs, rhs in
            if lhs.rankBoost != rhs.rankBoost { return lhs.rankBoost > rhs.rankBoost }
            if lhs.supportCount != rhs.supportCount { return lhs.supportCount > rhs.supportCount }
            return lhs.id < rhs.id
        }
    }

    private func evidenceGroups(
        scopeSnapshots: [SipSensorySnapshot],
        scopeID: String,
        targetType: LearnedSensoryPatternTarget,
        preferences: TastingLensUserPreferences
    ) -> [String: PatternEvidence] {
        var output: [String: PatternEvidence] = [:]

        for snapshot in scopeSnapshots {
            for response in snapshot.responses where response.state == .observed && response.userConfirmed {
                switch targetType {
                case .criterion:
                    let targetID = response.criterionID
                    guard !Self.infrastructureCriterionIDs.contains(targetID),
                          !preferences.suppressesPattern(targetID: targetID, scopeID: scopeID),
                          !isMistaken(
                            targetID: targetID,
                            snapshotID: snapshot.id,
                            scopeID: scopeID,
                            preferences: preferences
                          ) else {
                        continue
                    }
                    output[targetID, default: PatternEvidence(fallbackTitle: response.displayedCriterionTitle)]
                        .append(snapshot: snapshot, response: response)

                case .descriptor:
                    for descriptor in response.descriptors {
                        guard !preferences.suppressesPattern(targetID: descriptor.id, scopeID: scopeID),
                              !isMistaken(
                                targetID: descriptor.id,
                                snapshotID: snapshot.id,
                                scopeID: scopeID,
                                preferences: preferences
                              ) else {
                            continue
                        }
                        output[descriptor.id, default: PatternEvidence(fallbackTitle: descriptor.displayedTitle)]
                            .append(snapshot: snapshot, response: response)
                    }
                }
            }
        }
        return output
    }

    private func makePattern(
        userID: UUID,
        scopeID: String,
        targetType: LearnedSensoryPatternTarget,
        targetID: String,
        title: String,
        evidence: PatternEvidence,
        allScopeSnapshots: [SipSensorySnapshot],
        now: Date
    ) -> LearnedSensoryPattern {
        let distinctEvidence = evidence.entries.uniqueBySnapshot
        let confidenceCounts = SensoryPatternCount(
            learning: distinctEvidence.filter { $0.response.confidence == .learning }.count,
            maybe: distinctEvidence.filter { $0.response.confidence == .maybe }.count,
            sure: distinctEvidence.filter { $0.response.confidence == .sure }.count
        )
        let preferences = SensoryPreferenceCount(
            notForMe: distinctEvidence.filter { $0.response.preference == .notForMe }.count,
            neutral: distinctEvidence.filter { $0.response.preference == .neutral }.count,
            liked: distinctEvidence.filter { $0.response.preference == .liked }.count
        )
        let spontaneousCount = distinctEvidence.filter {
            $0.response.suggestionOrigin == .neutralPrompt || $0.response.suggestionOrigin == .custom
        }.count
        let supportCount = distinctEvidence.count
        let rankBoost = min(30, 10 + min(supportCount, 10) + min(spontaneousCount * 2, 10))
        let scopeTitle = scopeID.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ".", with: " ")
        let evidenceSummary = "You confirmed \(title.lowercased()) in \(supportCount) of \(allScopeSnapshots.count) \(scopeTitle) tastings."

        return LearnedSensoryPattern(
            id: "pattern.\(scopeID).\(targetType.rawValue).\(targetID)",
            userID: userID,
            scopeID: scopeID,
            targetType: targetType,
            targetID: targetID,
            title: title,
            supportCount: supportCount,
            totalCount: allScopeSnapshots.count,
            spontaneousSupportCount: spontaneousCount,
            confidenceCounts: confidenceCounts,
            intensity: intensitySummary(from: distinctEvidence),
            preferences: preferences,
            enjoymentAssociation: enjoymentAssociation(
                title: title,
                targetType: targetType,
                targetID: targetID,
                evidence: distinctEvidence,
                allScopeSnapshots: allScopeSnapshots
            ),
            rankBoost: rankBoost,
            evidenceSnapshotIDs: distinctEvidence.map(\.snapshot.id).sorted { $0.uuidString < $1.uuidString },
            evidenceSummary: evidenceSummary,
            generatedAt: now
        )
    }

    private func intensitySummary(from evidence: [PatternEvidence.Entry]) -> SensoryIntensitySummary? {
        let values = evidence.compactMap { $0.response.intensity }
        guard !values.isEmpty else { return nil }
        let grouped = Dictionary(grouping: values, by: \.scale)
        guard let mostSupported = grouped.max(by: { lhs, rhs in
            if lhs.value.count != rhs.value.count { return lhs.value.count < rhs.value.count }
            return lhs.key.rawValue > rhs.key.rawValue
        }) else { return nil }
        let levels = mostSupported.value.map(\.level).sorted()
        guard levels.count >= minimumConfirmedSupport else { return nil }
        let counts = Dictionary(grouping: levels, by: { $0 }).mapValues(\.count)
        return SensoryIntensitySummary(
            scale: mostSupported.key,
            levelCounts: counts,
            medianLevel: levels[(levels.count - 1) / 2]
        )
    }

    private func enjoymentAssociation(
        title: String,
        targetType: LearnedSensoryPatternTarget,
        targetID: String,
        evidence: [PatternEvidence.Entry],
        allScopeSnapshots: [SipSensorySnapshot]
    ) -> SensoryEnjoymentAssociation? {
        // A missing or skipped response is not negative evidence. Descriptor
        // options are not frozen when they were merely offered, so a safe
        // descriptor comparison cannot yet be constructed.
        guard targetType == .criterion else { return nil }
        let observedSnapshotIDs = Set(evidence.map { $0.snapshot.id })
        let observedRatings = evidence.compactMap { $0.snapshot.personalEnjoyment?.value }
        let comparisonRatings = allScopeSnapshots
            .filter { !observedSnapshotIDs.contains($0.id) }
            .filter { snapshot in
                snapshot.responses.contains {
                    $0.criterionID == targetID
                        && $0.state == .notPresent
                        && $0.userConfirmed
                }
            }
            .compactMap { $0.personalEnjoyment?.value }
        guard observedRatings.count >= minimumConfirmedSupport,
              comparisonRatings.count >= minimumComparisonSupport else {
            return nil
        }

        let observedAverage = observedRatings.reduce(0, +) / Double(observedRatings.count)
        let comparisonAverage = comparisonRatings.reduce(0, +) / Double(comparisonRatings.count)
        let difference = observedAverage - comparisonAverage
        let direction: SensoryEnjoymentAssociationDirection
        if difference >= 0.25 {
            direction = .higher
        } else if difference <= -0.25 {
            direction = .lower
        } else {
            direction = .similar
        }
        let explanation = String(
            format: "Across confirmed tastings, your average personal rating was %.1f when you recorded %@ and %.1f otherwise. This is an association, not a cause.",
            observedAverage,
            title.lowercased(),
            comparisonAverage
        )
        return SensoryEnjoymentAssociation(
            observedSupportCount: observedRatings.count,
            comparisonCount: comparisonRatings.count,
            averageWhenObserved: rounded(observedAverage),
            averageWhenNotObserved: rounded(comparisonAverage),
            difference: rounded(difference),
            direction: direction,
            explanation: explanation
        )
    }

    private func isMistaken(
        targetID: String,
        snapshotID: UUID,
        scopeID: String,
        preferences: TastingLensUserPreferences
    ) -> Bool {
        preferences.dismissals.contains {
            $0.targetID == targetID &&
                $0.scopeID == scopeID &&
                $0.snapshotID == snapshotID &&
                $0.reason == .selectedByMistake
        }
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private static let infrastructureCriterionIDs: Set<String> = [
        "criterion.own_words",
        "criterion.flavor.web",
        "criterion.mugsy.leading",
        "criterion.confidence"
    ]
}

private struct PatternEvidence {
    struct Entry {
        let snapshot: SipSensorySnapshot
        let response: SipSensoryResponseSnapshot
    }

    var fallbackTitle: String
    var entries: [Entry] = []

    var distinctSnapshotCount: Int { Set(entries.map { $0.snapshot.id }).count }

    mutating func append(snapshot: SipSensorySnapshot, response: SipSensoryResponseSnapshot) {
        entries.append(Entry(snapshot: snapshot, response: response))
    }
}

private extension Array where Element == PatternEvidence.Entry {
    var uniqueBySnapshot: [PatternEvidence.Entry] {
        var seen = Set<UUID>()
        return sorted { lhs, rhs in
            if lhs.snapshot.createdAt != rhs.snapshot.createdAt {
                return lhs.snapshot.createdAt < rhs.snapshot.createdAt
            }
            return lhs.snapshot.id.uuidString < rhs.snapshot.id.uuidString
        }.filter { seen.insert($0.snapshot.id).inserted }
    }
}
