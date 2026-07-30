import Foundation

extension TastingLensSessionDraft {
    init(restoring snapshot: SipSensorySnapshot) {
        self.init(
            id: snapshot.id,
            bundleID: snapshot.bundleID,
            bundleContentVersion: snapshot.bundleContentVersion,
            depth: snapshot.depth,
            identity: snapshot.identity,
            ownWords: snapshot.ownWords,
            responses: snapshot.responses.map {
                SensoryResponseDraft(
                    id: $0.id,
                    criterionID: $0.criterionID,
                    state: $0.state,
                    descriptorIDs: $0.descriptors.map(\.id),
                    choiceIDs: $0.selectedChoiceIDs,
                    customText: $0.customText,
                    intensity: $0.intensity,
                    duration: $0.duration,
                    preference: $0.preference,
                    qualityImpression: $0.qualityImpression,
                    confidence: $0.confidence,
                    suggestionOrigin: $0.suggestionOrigin,
                    sourcePackIDs: $0.sourcePackIDs,
                    userConfirmed: $0.userConfirmed,
                    aiProvenance: $0.aiProvenance,
                    displayedOrder: $0.displayedOrder
                )
            },
            personalEnjoyment: snapshot.personalEnjoyment,
            activePackIDs: Array(Set(snapshot.responses.flatMap(\.sourcePackIDs))).sorted(),
            startedAt: snapshot.createdAt,
            updatedAt: .now
        )
    }
}
