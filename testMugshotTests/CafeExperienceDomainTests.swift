import Foundation
import Testing
@testable import testMugshot

struct CafeExperienceDomainTests {
    @Test func allNineIntentCombinationsResolveWithoutUsingStars() {
        let cases: [(CafeReturnIntention, SipReorderIntention, CafeNextMoveKind)] = [
            (.yes, .yes, .comeBackForThis),
            (.yes, .maybe, .notSureYet),
            (.yes, .no, .comeBackTryAnother),
            (.maybe, .yes, .notSureYet),
            (.maybe, .maybe, .notSureYet),
            (.maybe, .no, .notSureYet),
            (.no, .yes, .thisDrinkElsewhere),
            (.no, .maybe, .notSureYet),
            (.no, .no, .probablyNotAgain)
        ]

        for (returnIntention, reorderIntention, expected) in cases {
            let move = CafeNextMove(
                returnIntention: returnIntention,
                reorderIntention: reorderIntention
            )
            #expect(move.kind == expected)
        }
        #expect(CafeNextMove(returnIntention: nil, reorderIntention: .yes).kind == .notSureYet)
    }

    @Test func sipAndCafeRatingsRemainIndependent() throws {
        let cafe = Cafe(name: "Independent Cafe")
        let primaryDraftID = UUID()
        var cafeExperience = CafeExperienceDraft(
            depth: .guided,
            cafeRating: try rating(2)
        )
        cafeExperience.record(.observed(
            facet: .soundVolume,
            impact: .detracted
        ))
        var session = CafeSessionDraft(
            cafeID: cafe.id,
            primarySipDraftID: primaryDraftID,
            returnIntention: .no,
            experienceDraft: cafeExperience
        )
        var sip = SipDraft(
            id: primaryDraftID,
            context: .cafe,
            cafe: cafe,
            drinkName: "Cappuccino",
            overallScore: 4.5,
            cafeSessionDraft: session,
            cafeSessionSipOrder: 0,
            cafeSessionSipRole: .primary,
            sipReorderIntention: .yes
        )

        #expect(sip.resolvedOverallScore == 4.5)
        #expect(sip.cafeSessionDraft?.experienceDraft?.cafeRating?.value == 2)
        #expect(sip.cafeNextMove.kind == .thisDrinkElsewhere)

        session.experienceDraft?.cafeRating = try rating(5)
        sip.cafeSessionDraft = session
        #expect(sip.resolvedOverallScore == 4.5)
        #expect(sip.cafeSessionDraft?.experienceDraft?.cafeRating?.value == 5)
        #expect(sip.cafeNextMove.kind == .thisDrinkElsewhere)
    }

    @Test func intentionAndRepeatEvidenceProduceMinimalSnapshots() throws {
        let ownerID = UUID()
        let cafeID = UUID()
        let primaryDraftID = UUID()
        let capturedAt = Date(timeIntervalSince1970: 12_345)

        let empty = CafeSessionDraft(
            ownerUserID: ownerID,
            cafeID: cafeID,
            primarySipDraftID: primaryDraftID,
            experienceDraft: nil
        )
        #expect(empty.makeSnapshot(now: capturedAt) == nil)

        let returnOnly = CafeSessionDraft(
            ownerUserID: ownerID,
            cafeID: cafeID,
            primarySipDraftID: primaryDraftID,
            returnIntention: .yes,
            experienceDraft: nil
        )
        let returnSnapshot = try #require(
            returnOnly.makeSnapshot(now: capturedAt)
        )
        #expect(returnSnapshot.returnIntention == .yes)
        #expect(returnSnapshot.repeatComparison == nil)
        #expect(returnSnapshot.cafeRating == nil)
        #expect(returnSnapshot.observations.isEmpty)

        let repeatOnly = CafeSessionDraft(
            ownerUserID: ownerID,
            cafeID: cafeID,
            primarySipDraftID: primaryDraftID,
            repeatComparison: .different,
            experienceDraft: nil
        )
        let repeatSnapshot = try #require(
            repeatOnly.makeSnapshot(now: capturedAt)
        )
        #expect(repeatSnapshot.returnIntention == nil)
        #expect(repeatSnapshot.repeatComparison == .different)
        #expect(repeatSnapshot.cafeRating == nil)
        #expect(repeatSnapshot.observations.isEmpty)
    }

    @Test func nextMoveAloneDoesNotRequireCafePulseSnapshot() {
        let nextMoveOnly = CafeExperienceShareProjection(
            includesNextMove: true
        )
        let cafeStars = CafeExperienceShareProjection(
            includesCafeRating: true
        )
        let observations = CafeExperienceShareProjection(
            observationIDs: [UUID()]
        )

        #expect(!nextMoveOnly.requiresSnapshot)
        #expect(cafeStars.requiresSnapshot)
        #expect(observations.requiresSnapshot)
    }

    @Test func relationshipStagesAndTrendsRequireRatedSessionEvidence() throws {
        let ownerID = UUID()
        let cafeID = UUID()

        #expect(CafeRelationshipStage.resolve(ratedSessionCount: 0) == .unrated)
        #expect(CafeRelationshipStage.resolve(ratedSessionCount: 1) == .firstImpression)
        #expect(CafeRelationshipStage.resolve(ratedSessionCount: 2) == .emergingView)
        #expect(CafeRelationshipStage.resolve(ratedSessionCount: 3) == .trendReady)

        let sessions = try [
            makeSession(
                ownerID: ownerID,
                cafeID: cafeID,
                day: 1,
                rating: 3,
                comparison: nil
            ),
            makeSession(
                ownerID: ownerID,
                cafeID: cafeID,
                day: 2,
                rating: 3.5,
                comparison: .better
            )
        ]
        let emerging = CafeRelationshipStats(cafeID: cafeID, sessions: sessions)
        #expect(emerging.stage == .emergingView)
        #expect(emerging.explicitTrend == nil)

        let third = try makeSession(
            ownerID: ownerID,
            cafeID: cafeID,
            day: 3,
            rating: 4,
            comparison: .better
        )
        let established = CafeRelationshipStats(cafeID: cafeID, sessions: sessions + [third])
        #expect(established.stage == .trendReady)
        #expect(established.explicitTrend == .better)
        #expect(established.averageCafeRating == 3.5)
    }

    @Test func generalPlaceLearningRequiresThreeSessionsAcrossTwoCafes() throws {
        let userID = UUID()
        let cafeIDs = [UUID(), UUID(), UUID()]
        let snapshots = try (0..<5).map { index in
            try makeSnapshot(
                ownerID: userID,
                cafeID: cafeIDs[index % cafeIDs.count],
                day: index,
                rating: Double(index + 1),
                returnIntention: .yes,
                observations: [
                    .observed(facet: .soundVolume, impact: .lifted)
                ]
            )
        }
        let engine = CafeExperienceLearningEngine()

        #expect(engine.learnedSignals(userID: userID, snapshots: Array(snapshots.prefix(2))).isEmpty)

        let emerging = try #require(
            engine.learnedSignals(userID: userID, snapshots: Array(snapshots.prefix(3))).first
        )
        #expect(emerging.strength == .emerging)
        #expect(emerging.supportSessionCount == 3)
        #expect(emerging.distinctCafeCount == 3)
        #expect(emerging.direction == .lifted)

        let established = try #require(
            engine.learnedSignals(userID: userID, snapshots: snapshots).first
        )
        #expect(established.strength == .established)
        #expect(established.supportSessionCount == 5)
        #expect(established.distinctCafeCount == 3)
    }

    @Test func learningNeverTreatsLowStarsOrMissingResponsesAsNegativeEvidence() throws {
        let userID = UUID()
        let cafeIDs = [UUID(), UUID()]
        let starsOnly = try (0..<4).map { index in
            try makeSnapshot(
                ownerID: userID,
                cafeID: cafeIDs[index % 2],
                day: index,
                rating: 1,
                returnIntention: .no,
                observations: []
            )
        }
        let unobserved = try (4..<7).map { index in
            try makeSnapshot(
                ownerID: userID,
                cafeID: cafeIDs[index % 2],
                day: index,
                rating: 1,
                returnIntention: .no,
                observations: [
                    try #require(.unobserved(
                        dimension: .hospitality,
                        facet: .hospitalityWelcome,
                        state: .notObserved
                    ))
                ]
            )
        }
        let engine = CafeExperienceLearningEngine()
        #expect(engine.learnedSignals(
            userID: userID,
            snapshots: starsOnly + unobserved
        ).isEmpty)

        let explicit = try (7..<10).map { index in
            try makeSnapshot(
                ownerID: userID,
                cafeID: cafeIDs[index % 2],
                day: index,
                rating: 5,
                returnIntention: .yes,
                observations: [
                    .observed(facet: .hospitalityWelcome, impact: .detracted)
                ]
            )
        }
        let detracted = try #require(
            engine.learnedSignals(userID: userID, snapshots: explicit).first
        )
        #expect(detracted.direction == .detracted)
        #expect(detracted.explanation.contains("stars alone were not used"))
    }

    @Test func homeAndRecipeEntriesCannotCarryCafeSessionState() {
        let session = CafeSessionDraft(
            cafeID: UUID(),
            primarySipDraftID: UUID(),
            returnIntention: .yes
        )
        let home = SipDraft(
            context: .home,
            cafeSessionDraft: session,
            cafeSessionSipOrder: 0,
            cafeSessionSipRole: .primary,
            sipReorderIntention: .yes
        )
        let recipe = SipDraft(
            context: .recipe,
            cafeSessionReference: session.reference,
            cafeSessionSipOrder: 1,
            cafeSessionSipRole: .secondary,
            sipReorderIntention: .no
        )

        #expect(!JournalEntryContext.home.supportsCafeSession)
        #expect(!JournalEntryContext.recipe.supportsCafeSession)
        #expect(home.cafeSessionID == nil)
        #expect(home.sipReorderIntention == nil)
        #expect(recipe.cafeSessionID == nil)
        #expect(recipe.sipReorderIntention == nil)

        let visit = Visit(
            cafeId: UUID(),
            userId: UUID(),
            drinkType: .coffee,
            context: .home,
            cafeSessionID: session.id,
            cafeSessionSipOrder: 0,
            cafeSessionSipRole: .primary,
            sipReorderIntention: .yes
        )
        #expect(visit.cafeSessionID == nil)
        #expect(visit.sipReorderIntention == nil)
    }

    @Test func additionalSipKeepsSessionIntentWithoutDuplicatingCafePulse() throws {
        let ownerID = UUID()
        let cafe = Cafe(name: "Two Drink Cafe")
        let primaryDraftID = UUID()
        var session = CafeSessionDraft(
            ownerUserID: ownerID,
            cafeID: cafe.id,
            visibility: .friends,
            primarySipDraftID: primaryDraftID,
            returnIntention: .yes,
            experienceDraft: CafeExperienceDraft(
                cafeRating: try rating(4.5)
            )
        )
        let secondary = SipDraft.additionalSip(
            in: &session,
            cafe: cafe,
            ownerUserID: ownerID
        )

        #expect(secondary.cafeSessionID == session.id)
        #expect(secondary.cafeSessionReturnIntention == .yes)
        #expect(secondary.cafeSessionDraft == nil)
        #expect(secondary.cafeSessionReference != nil)
        #expect(secondary.cafeSessionSipRole == .secondary)
        #expect(secondary.cafeSessionSipOrder == 1)
        #expect(secondary.overallScore == 0)
        #expect(secondary.sensorySnapshot == nil)
        #expect(secondary.localPhotoNames.isEmpty)
        #expect(session.sipDraftIDs == [primaryDraftID, secondary.id])
    }

    @Test func legacyAppDataAndVisitPayloadsDecodeWithoutSessionFields() throws {
        let visit = Visit(
            cafeId: UUID(),
            userId: UUID(),
            drinkType: .coffee,
            overallScore: 4
        )
        let encodedVisit = try JSONEncoder().encode(visit)
        var visitObject = try #require(
            JSONSerialization.jsonObject(with: encodedVisit) as? [String: Any]
        )
        visitObject.removeValue(forKey: "cafeSessionID")
        visitObject.removeValue(forKey: "cafeSessionSipOrder")
        visitObject.removeValue(forKey: "cafeSessionSipRole")
        visitObject.removeValue(forKey: "sipReorderIntention")
        let legacyVisit = try JSONDecoder().decode(
            Visit.self,
            from: JSONSerialization.data(withJSONObject: visitObject)
        )
        #expect(legacyVisit.cafeSessionID == nil)
        #expect(legacyVisit.sipReorderIntention == nil)

        let encodedDraft = try JSONEncoder().encode(SipDraft(
            context: .cafe,
            cafe: Cafe(name: "Legacy Draft Cafe"),
            drinkName: "Latte",
            overallScore: 4
        ))
        var draftObject = try #require(
            JSONSerialization.jsonObject(with: encodedDraft) as? [String: Any]
        )
        draftObject.removeValue(forKey: "cafeSessionDraft")
        draftObject.removeValue(forKey: "cafeSessionReference")
        draftObject.removeValue(forKey: "cafeSessionSipOrder")
        draftObject.removeValue(forKey: "cafeSessionSipRole")
        draftObject.removeValue(forKey: "sipReorderIntention")
        let legacyDraft = try JSONDecoder().decode(
            SipDraft.self,
            from: JSONSerialization.data(withJSONObject: draftObject)
        )
        #expect(legacyDraft.cafeSessionID == nil)
        #expect(legacyDraft.sipReorderIntention == nil)

        let encodedAppData = try JSONEncoder().encode(AppData(visits: [visit]))
        var appDataObject = try #require(
            JSONSerialization.jsonObject(with: encodedAppData) as? [String: Any]
        )
        appDataObject.removeValue(forKey: "cafeSessions")
        let legacyAppData = try JSONDecoder().decode(
            AppData.self,
            from: JSONSerialization.data(withJSONObject: appDataObject)
        )
        #expect(legacyAppData.cafeSessions.isEmpty)
        #expect(legacyAppData.visits.count == 1)
    }

    @Test func promptRouterUsesDepthAndVisitContext() {
        let workContext = CafeVisitContext(
            mode: .workStudy,
            overlays: [.busyQueue]
        )
        #expect(CafeExperienceDimension.allCases.count == 6)
        #expect(CafeExperiencePromptRouter.facets(
            for: .comfortAndPracticality,
            context: workContext,
            depth: .quick
        ).isEmpty)

        let guidedComfort = CafeExperiencePromptRouter.facets(
            for: .comfortAndPracticality,
            context: workContext,
            depth: .guided
        )
        #expect(guidedComfort.contains(.comfortWifi))
        #expect(guidedComfort.contains(.comfortOutlets))
        #expect(guidedComfort.contains(.comfortWait))

        for dimension in CafeExperienceDimension.allCases {
            let deep = CafeExperiencePromptRouter.facets(
                for: dimension,
                context: workContext,
                depth: .deep
            )
            #expect(deep == CafeExperienceFacet.allCases.filter { $0.dimension == dimension })
        }
    }

    @Test func visitContextEncodingIsStableAcrossSetInsertionOrder() throws {
        let first = CafeVisitContext(
            mode: .social,
            overlays: [.busyQueue, .outdoorSeating]
        )
        let second = CafeVisitContext(
            mode: .social,
            overlays: [.outdoorSeating, .busyQueue]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(first) == encoder.encode(second))
    }

    @Test func remoteCafeRebindingPreservesTheRecordedCafePulse() throws {
        let localCafeID = UUID()
        let remoteCafeID = UUID()
        let snapshot = CafeExperienceSnapshot(
            sessionID: UUID(),
            ownerUserID: UUID(),
            cafeID: localCafeID,
            createdAt: Date(timeIntervalSince1970: 1_000),
            draft: CafeExperienceDraft(
                depth: .deep,
                cafeRating: try rating(4.5),
                observations: [
                    CafeExperienceObservation.observed(
                        facet: .soundPlaylistFit,
                        impact: .lifted
                    )
                ]
            ),
            returnIntention: .yes,
            repeatComparison: .better
        )

        let rebound = snapshot.rebindingCafeID(remoteCafeID)

        #expect(rebound.cafeID == remoteCafeID)
        #expect(rebound.sessionID == snapshot.sessionID)
        #expect(rebound.ownerUserID == snapshot.ownerUserID)
        #expect(rebound.createdAt == snapshot.createdAt)
        #expect(rebound.schemaVersion == snapshot.schemaVersion)
        #expect(rebound.depth == snapshot.depth)
        #expect(rebound.ownWords == snapshot.ownWords)
        #expect(rebound.cafeRating == snapshot.cafeRating)
        #expect(rebound.visitContext == snapshot.visitContext)
        #expect(rebound.observations == snapshot.observations)
        #expect(rebound.privateNotes == snapshot.privateNotes)
        #expect(rebound.returnIntention == snapshot.returnIntention)
        #expect(rebound.repeatComparison == snapshot.repeatComparison)
    }

    @Test func cafeSessionContinuationSurvivesRelaunchAndExpires() throws {
        let suiteName = "CafeSessionContinuationStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CafeSessionContinuationStore(
            defaults: defaults,
            expirationInterval: 60
        )
        let ownerID = UUID()
        let cafe = Cafe(name: "Continuation Cafe")
        let now = Date(timeIntervalSince1970: 50_000)
        let record = CafeSessionContinuationRecord(
            ownerUserID: ownerID,
            session: CafeSessionDraft(
                ownerUserID: ownerID,
                cafeID: cafe.id,
                startedAt: now,
                updatedAt: now,
                status: .complete,
                primaryVisitID: UUID(),
                primarySipDraftID: UUID(),
                experienceDraft: CafeExperienceDraft(updatedAt: now)
            ),
            cafe: cafe,
            summary: SipCompletionSnapshot(
                drinkName: "Cortado",
                locationName: cafe.name,
                context: .cafe,
                score: 4.5,
                visibility: .friends,
                usedTastingLens: true,
                hasPhoto: true,
                hasThought: false,
                hasPrivateNote: false,
                hasBrewDetails: false,
                isCafeSession: true,
                cafeRating: 4,
                nextMove: .comeBackForThis
            ),
            stage: .completion,
            activeDraftID: nil,
            updatedAt: now
        )

        try store.save(record)
        #expect(store.load(ownerUserID: ownerID, now: now.addingTimeInterval(30)) == record)
        #expect(store.load(ownerUserID: ownerID, now: now.addingTimeInterval(61)) == nil)
    }

    @Test func cafePulseJourneyPacesQuickGuidedAndDeepWithoutChangingEvidence() {
        let context = CafeVisitContext(mode: .stayAwhile)
        let quick = CafePulseJourneyPlan.make(
            depth: .quick,
            context: context,
            showsRepeatComparison: true
        )
        let guided = CafePulseJourneyPlan.make(
            depth: .guided,
            context: context,
            showsRepeatComparison: true
        )
        let deep = CafePulseJourneyPlan.make(
            depth: .deep,
            context: context,
            showsRepeatComparison: true
        )

        #expect(quick.steps.count == 3)
        #expect(guided.steps.count == 13)
        #expect(deep.steps.count == 28)
        #expect(quick.steps.map(\.id) == ["rating", "quick-signals", "quick-wrap-up"])
        #expect(guided.steps.first?.content == .ownWords)
        #expect(deep.steps.first?.content == .ownWords)
        #expect(guided.steps.last?.content == .sharing)
        #expect(deep.steps.last?.content == .sharing)

        let deepFacetPages = deep.steps.compactMap { step -> [CafeExperienceFacet]? in
            guard case .dimension(_, let facets, let includesBroadSignal) = step.content,
                  !includesBroadSignal else {
                return nil
            }
            return facets
        }
        #expect(deepFacetPages.count == 15)
        #expect(deepFacetPages.allSatisfy { !$0.isEmpty && $0.count <= 4 })
        #expect(Set(deepFacetPages.flatMap { $0 }) == Set(CafeExperienceFacet.allCases))
    }

    @Test func guidedCafePulseUsesVisitContextToChooseFocusedPrompts() {
        let workPlan = CafePulseJourneyPlan.make(
            depth: .guided,
            context: CafeVisitContext(mode: .workStudy),
            showsRepeatComparison: true
        )
        let comfortStep = workPlan.steps.first { step in
            guard case .dimension(let dimension, _, _) = step.content else { return false }
            return dimension == .comfortAndPracticality
        }
        guard let comfortStep,
              case .dimension(_, let facets, let includesBroadSignal) = comfortStep.content else {
            Issue.record("Expected a Guided comfort and practicality step.")
            return
        }

        #expect(includesBroadSignal)
        #expect(facets.contains(.comfortWifi))
        #expect(facets.contains(.comfortOutlets))
        #expect(facets.contains(.comfortTableSpace))
        #expect(facets.contains(.comfortSeating))
    }

    @Test func cafePulseJourneyNavigationResumesFromTheSavedDraftStep() throws {
        let plan = CafePulseJourneyPlan.make(
            depth: .deep,
            context: CafeVisitContext(mode: .social),
            showsRepeatComparison: true
        )
        let target = try #require(plan.steps.dropFirst(9).first)
        let draft = CafeExperienceDraft(
            depth: .deep,
            journeyStepID: target.id
        )
        let restored = try JSONDecoder().decode(
            CafeExperienceDraft.self,
            from: JSONEncoder().encode(draft)
        )

        #expect(restored.journeyStepID == target.id)
        #expect(plan.resolvedIndex(for: restored.journeyStepID) == 9)
        #expect(plan.step(before: restored.journeyStepID)?.id == plan.steps[8].id)
        #expect(plan.step(after: restored.journeyStepID)?.id == plan.steps[10].id)
        #expect(plan.resolvedIndex(for: "retired-step") == 0)
    }

    private func makeSession(
        ownerID: UUID,
        cafeID: UUID,
        day: Int,
        rating: Double,
        comparison: CafeRepeatComparison?
    ) throws -> CafeSession {
        let snapshot = try makeSnapshot(
            ownerID: ownerID,
            cafeID: cafeID,
            day: day,
            rating: rating,
            returnIntention: .yes,
            comparison: comparison,
            observations: []
        )
        return CafeSession(
            id: snapshot.sessionID,
            ownerUserID: ownerID,
            cafeID: cafeID,
            startedAt: snapshot.createdAt,
            endedAt: snapshot.createdAt,
            status: .complete,
            primaryVisitID: UUID(),
            visitIDs: [UUID()],
            returnIntention: .yes,
            experienceSnapshot: snapshot
        )
    }

    private func makeSnapshot(
        ownerID: UUID,
        cafeID: UUID,
        day: Int,
        rating: Double,
        returnIntention: CafeReturnIntention,
        comparison: CafeRepeatComparison? = nil,
        observations: [CafeExperienceObservation]
    ) throws -> CafeExperienceSnapshot {
        let date = Date(timeIntervalSince1970: Double(day * 86_400))
        return CafeExperienceSnapshot(
            sessionID: UUID(),
            ownerUserID: ownerID,
            cafeID: cafeID,
            createdAt: date,
            draft: CafeExperienceDraft(
                depth: .guided,
                cafeRating: try self.rating(rating),
                observations: observations,
                updatedAt: date
            ),
            returnIntention: returnIntention,
            repeatComparison: comparison
        )
    }

    private func rating(_ value: Double) throws -> CafeExperienceRating {
        guard let rating = CafeExperienceRating(value: value) else {
            throw FixtureError.invalidCafeRating(value)
        }
        return rating
    }

    private enum FixtureError: Error {
        case invalidCafeRating(Double)
    }
}
