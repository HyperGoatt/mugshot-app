import Foundation

enum CafePreferenceSignalTarget: String, Codable, CaseIterable, Hashable {
    case dimension
    case facet
}

enum CafePreferenceSignalDirection: String, Codable, CaseIterable, Hashable {
    case lifted
    case detracted
}

enum CafePreferenceSignalStrength: String, Codable, CaseIterable {
    case emerging
    case established
}

struct CafePreferenceSignal: Identifiable, Codable, Equatable {
    let id: String
    let userID: UUID
    let target: CafePreferenceSignalTarget
    let targetID: String
    let title: String
    let direction: CafePreferenceSignalDirection
    let strength: CafePreferenceSignalStrength
    let supportSessionCount: Int
    let distinctCafeCount: Int
    let evidenceSessionIDs: [UUID]
    let evidenceSnapshotIDs: [UUID]
    let generatedAt: Date
    let explanation: String
}

/// User-controlled corrections for transparent Cafe Pulse learning.
///
/// `excludedObservationIDs` marks individual evidence as mistaken. A dismissed
/// signal stays out of prompts without deleting its underlying cafe history.
struct CafeExperienceLearningPreferences: Codable, Equatable {
    let userID: UUID
    var dismissedSignalIDs: Set<String>
    var excludedObservationIDs: Set<UUID>

    init(
        userID: UUID,
        dismissedSignalIDs: Set<String> = [],
        excludedObservationIDs: Set<UUID> = []
    ) {
        self.userID = userID
        self.dismissedSignalIDs = dismissedSignalIDs
        self.excludedObservationIDs = excludedObservationIDs
    }
}

struct CafeExperienceLearningEngine {
    let emergingSessionMinimum: Int
    let emergingCafeMinimum: Int
    let establishedSessionMinimum: Int
    let establishedCafeMinimum: Int

    init(
        emergingSessionMinimum: Int = 3,
        emergingCafeMinimum: Int = 2,
        establishedSessionMinimum: Int = 5,
        establishedCafeMinimum: Int = 3
    ) {
        self.emergingSessionMinimum = max(emergingSessionMinimum, 3)
        self.emergingCafeMinimum = max(emergingCafeMinimum, 2)
        self.establishedSessionMinimum = max(
            establishedSessionMinimum,
            max(emergingSessionMinimum, 5)
        )
        self.establishedCafeMinimum = max(
            establishedCafeMinimum,
            max(emergingCafeMinimum, 3)
        )
    }

    /// Derives general place preferences only from explicit Cafe Pulse impact.
    /// Cafe stars are deliberately never inspected.
    func learnedSignals(
        userID: UUID,
        snapshots: [CafeExperienceSnapshot],
        preferences: CafeExperienceLearningPreferences? = nil,
        now: Date = .now
    ) -> [CafePreferenceSignal] {
        if let preferences, preferences.userID != userID {
            return []
        }

        let exclusions = preferences?.excludedObservationIDs ?? []
        let ownerSnapshots = latestSnapshotsPerSession(
            snapshots.filter { $0.ownerUserID == userID }
        )
        var groups: [SignalKey: [SignalEvidence]] = [:]

        for snapshot in ownerSnapshots {
            let candidates = Dictionary(grouping: snapshot.observations.filter {
                $0.state.contributesEvidence &&
                    $0.impact != .neutral &&
                    !exclusions.contains($0.id)
            }, by: SignalTarget.init)

            for (target, observations) in candidates {
                let impacts = Set(observations.compactMap(\.impact))
                // Conflicting detail recorded in the same physical visit is
                // valid history but not clean evidence for a general rule.
                guard impacts.count == 1, let impact = impacts.first else { continue }
                let direction: CafePreferenceSignalDirection
                switch impact {
                case .lifted:
                    // A positive general preference needs supportive return
                    // intent as well as a lifted observation.
                    guard snapshot.returnIntention == .yes else { continue }
                    direction = .lifted
                case .detracted:
                    direction = .detracted
                case .neutral:
                    continue
                }

                let evidence = SignalEvidence(
                    sessionID: snapshot.sessionID,
                    snapshotID: snapshot.id,
                    cafeID: snapshot.cafeID
                )
                groups[SignalKey(target: target, direction: direction), default: []].append(evidence)
            }
        }

        let directionsByTarget = Dictionary(grouping: groups.keys, by: \.target)
        var signals: [CafePreferenceSignal] = []

        for (target, keys) in directionsByTarget {
            let qualified = keys.compactMap { key -> QualifiedEvidence? in
                guard let evidence = groups[key] else { return nil }
                let unique = evidence.uniqueBySession
                let cafeCount = Set(unique.map(\.cafeID)).count
                guard unique.count >= emergingSessionMinimum,
                      cafeCount >= emergingCafeMinimum else {
                    return nil
                }
                return QualifiedEvidence(key: key, evidence: unique, cafeCount: cafeCount)
            }

            // Conflicting directions that both clear the evidence threshold
            // are intentionally left as nuanced visit history, not learned.
            guard qualified.count == 1, let result = qualified.first else { continue }
            let signalID = Self.signalID(target: target, direction: result.key.direction)
            guard preferences?.dismissedSignalIDs.contains(signalID) != true else { continue }

            let strength: CafePreferenceSignalStrength =
                result.evidence.count >= establishedSessionMinimum &&
                result.cafeCount >= establishedCafeMinimum
                ? .established
                : .emerging
            let cafeNoun = result.cafeCount == 1 ? "cafe" : "cafes"
            let sessionNoun = result.evidence.count == 1 ? "visit" : "visits"
            let explanation: String
            switch result.key.direction {
            case .lifted:
                explanation = "You explicitly said \(target.title.lowercased()) lifted \(result.evidence.count) \(sessionNoun) across \(result.cafeCount) \(cafeNoun), and you wanted to return."
            case .detracted:
                explanation = "You explicitly said \(target.title.lowercased()) detracted from \(result.evidence.count) \(sessionNoun) across \(result.cafeCount) \(cafeNoun). Cafe stars alone were not used."
            }

            signals.append(CafePreferenceSignal(
                id: signalID,
                userID: userID,
                target: target.kind,
                targetID: target.id,
                title: target.title,
                direction: result.key.direction,
                strength: strength,
                supportSessionCount: result.evidence.count,
                distinctCafeCount: result.cafeCount,
                evidenceSessionIDs: result.evidence.map(\.sessionID).sorted(by: Self.sortUUID),
                evidenceSnapshotIDs: result.evidence.map(\.snapshotID).sorted(by: Self.sortUUID),
                generatedAt: now,
                explanation: explanation
            ))
        }

        return signals.sorted {
            if $0.strength != $1.strength { return $0.strength == .established }
            if $0.supportSessionCount != $1.supportSessionCount {
                return $0.supportSessionCount > $1.supportSessionCount
            }
            return $0.id < $1.id
        }
    }

    private func latestSnapshotsPerSession(
        _ snapshots: [CafeExperienceSnapshot]
    ) -> [CafeExperienceSnapshot] {
        Dictionary(grouping: snapshots, by: \.sessionID)
            .compactMap { _, values in values.max { $0.createdAt < $1.createdAt } }
    }

    private static func signalID(
        target: SignalTarget,
        direction: CafePreferenceSignalDirection
    ) -> String {
        "cafe_preference.\(target.kind.rawValue).\(target.id).\(direction.rawValue)"
    }

    private static func sortUUID(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

private struct SignalTarget: Hashable {
    let kind: CafePreferenceSignalTarget
    let id: String
    let title: String

    init(_ observation: CafeExperienceObservation) {
        if let facet = observation.facet {
            kind = .facet
            id = facet.rawValue
            title = facet.title
        } else {
            kind = .dimension
            id = observation.dimension.rawValue
            title = observation.dimension.title
        }
    }
}

private struct SignalKey: Hashable {
    let target: SignalTarget
    let direction: CafePreferenceSignalDirection
}

private struct SignalEvidence {
    let sessionID: UUID
    let snapshotID: UUID
    let cafeID: UUID
}

private struct QualifiedEvidence {
    let key: SignalKey
    let evidence: [SignalEvidence]
    let cafeCount: Int
}

private extension Array where Element == SignalEvidence {
    var uniqueBySession: [SignalEvidence] {
        var seen: Set<UUID> = []
        return filter { seen.insert($0.sessionID).inserted }
    }
}
