import Foundation
import Testing
@testable import testMugshot

struct TastingLensDomainTests {
    @Test func bundledKnowledgeIsVersionedValidatedAndCoversEverySupportedFamily() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()

        #expect(bundle.schemaVersion == 1)
        #expect(bundle.contentVersion == "2026.07.16.1")
        #expect(bundle.sources.count >= 12)
        #expect(bundle.descriptors.count >= 70)
        #expect(bundle.criteria.count >= 45)

        let expectedPackIDs: Set<String> = [
            "pack.universal",
            "pack.coffee.espresso",
            "pack.coffee.brewed",
            "pack.coffee.pour_over",
            "pack.coffee.cold_brew",
            "pack.coffee.milk",
            "pack.tea.matcha",
            "pack.tea.matcha_latte",
            "pack.tea.hojicha_leaf",
            "pack.tea.hojicha_powder",
            "pack.tea.hojicha_latte",
            "pack.tea.green",
            "pack.tea.black",
            "pack.tea.white",
            "pack.tea.oolong",
            "pack.tea.herbal",
            "pack.tea.milk"
        ]
        #expect(expectedPackIDs.isSubset(of: Set(bundle.packs.map(\.id))))

        let enjoyment = try #require(bundle.criterion(id: "criterion.overall.enjoyment"))
        #expect(enjoyment.measure == .overallEnjoyment)
        #expect(enjoyment.scaleID == "scale.personal_enjoyment_half_stars")
        #expect(bundle.criteria.filter { $0.scaleID == "scale.personal_enjoyment_half_stars" }.count == 1)
        let descriptorIDs = Set(bundle.descriptors.map(\.id))
        #expect(bundle.criteria.flatMap(\.options).compactMap(\.descriptorID).allSatisfy(descriptorIDs.contains))
    }

    @Test func specialtyMatchaLatteComposesBaseAndFactOverlaysWithoutCoffeeAssumptions() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let analysis = DrinkAnalysisParser.analyze(
            "Iced strawberry matcha latte with oat milk and vanilla syrup"
        )
        let selection = TastingLensSelectionService().makeSelection(
            analysis: analysis,
            depth: .guided,
            bundle: bundle
        )

        #expect(selection.identity.family == .matchaLatte)
        #expect(selection.identity.preparation == .whiskedPowder)
        #expect(selection.identity.temperature == .iced)
        #expect(selection.basePack.id == "pack.tea.matcha_latte")
        #expect(Set(selection.overlays.map(\.id)).isSuperset(of: [
            "overlay.temperature.iced",
            "overlay.milk",
            "overlay.sweetened",
            "overlay.flavored",
            "overlay.powdered"
        ]))
        #expect(selection.criteria.contains { $0.id == "criterion.matcha.texture" })
        #expect(selection.criteria.contains { $0.id == "criterion.addition.provenance" })
        #expect(!selection.criteria.contains { $0.id == "criterion.espresso.crema" })
        #expect(selection.criteria.first?.id == "criterion.own_words")
        #expect(selection.criteria.last?.id == "criterion.overall.enjoyment")
        #expect(selection.identity.userConfirmed == false)
        #expect(selection.explanations.contains { $0.contains("should be confirmed") })
    }

    @Test func unknownDrinkFallsBackToUniversalOfflineLens() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let analysis = DrinkAnalysisParser.analyze("House special number seven")
        let selection = TastingLensSelectionService().makeSelection(
            analysis: analysis,
            depth: .guided,
            bundle: bundle
        )

        #expect(selection.usedUniversalFallback)
        #expect(selection.basePack.id == "pack.universal")
        #expect(selection.criteria.contains { $0.id == "criterion.flavor.web" })
        #expect(selection.criteria.contains { $0.id == "criterion.overall.enjoyment" })
    }

    @Test func everySupportedIdentitySelectsItsVersionedBasePack() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let fixtures: [(SensoryBeverageFamily, SensoryPreparation, String)] = [
            (.espresso, .espresso, "pack.coffee.espresso"),
            (.espresso, .americano, "pack.coffee.espresso"),
            (.brewedCoffee, .drip, "pack.coffee.brewed"),
            (.brewedCoffee, .immersion, "pack.coffee.brewed"),
            (.brewedCoffee, .pourOver, "pack.coffee.pour_over"),
            (.brewedCoffee, .coldBrew, "pack.coffee.cold_brew"),
            (.milkCoffee, .latte, "pack.coffee.milk"),
            (.matcha, .whiskedPowder, "pack.tea.matcha"),
            (.matchaLatte, .whiskedPowder, "pack.tea.matcha_latte"),
            (.hojichaLeaf, .steepedLeaf, "pack.tea.hojicha_leaf"),
            (.hojichaPowder, .whiskedPowder, "pack.tea.hojicha_powder"),
            (.hojichaLatte, .whiskedPowder, "pack.tea.hojicha_latte"),
            (.greenTea, .steepedLeaf, "pack.tea.green"),
            (.blackTea, .steepedLeaf, "pack.tea.black"),
            (.whiteTea, .steepedLeaf, "pack.tea.white"),
            (.oolongTea, .steepedLeaf, "pack.tea.oolong"),
            (.herbalInfusion, .steepedLeaf, "pack.tea.herbal"),
            (.milkTea, .milkTea, "pack.tea.milk")
        ]

        for (family, preparation, expectedPackID) in fixtures {
            let identity = SensoryDrinkIdentity(
                rawName: family.title,
                family: family,
                preparation: preparation,
                temperature: .hot,
                confidence: 1,
                provenance: .user,
                userConfirmed: true
            )
            let selection = TastingLensSelectionService().makeSelection(
                analysis: nil,
                confirmedIdentity: identity,
                depth: .guided,
                bundle: bundle
            )
            #expect(selection.basePack.id == expectedPackID)
            #expect(selection.criteria.first?.measure == .ownWords)
            #expect(selection.criteria.last?.measure == .overallEnjoyment)
            let guidedQuestions = selection.orderedCriteria.filter {
                $0.id != "criterion.own_words"
                    && $0.id != "criterion.flavor.web"
                    && $0.id != "criterion.mugsy.leading"
                    && $0.criterion.measure != .overallEnjoyment
            }
            #expect(guidedQuestions.count <= 5)
        }
    }

    @Test func preparationSpecificPromptsDoNotLeakAcrossBrewedCoffee() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        func selection(_ preparation: SensoryPreparation) -> TastingLensSelection {
            TastingLensSelectionService().makeSelection(
                analysis: nil,
                confirmedIdentity: SensoryDrinkIdentity(
                    rawName: preparation.title,
                    family: .brewedCoffee,
                    preparation: preparation,
                    confidence: 1,
                    provenance: .user,
                    userConfirmed: true
                ),
                depth: .guided,
                bundle: bundle
            )
        }

        #expect(selection(.immersion).criteria.contains { $0.id == "criterion.coffee.sediment" })
        #expect(!selection(.drip).criteria.contains { $0.id == "criterion.coffee.sediment" })
        #expect(!selection(.pourOver).criteria.contains { $0.id == "criterion.coffee.sediment" })
    }

    @Test func applicableCustomCriteriaRemainVisibleWhenUnpinnedAndKeepOrder() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let userID = UUID()
        let identity = confirmedPourOverIdentity()
        let first = customCriterion(id: "custom.first", title: "First custom", order: 10_000)
        let second = customCriterion(id: "custom.second", title: "Second custom", order: 10_001)
        let preferences = TastingLensUserPreferences(
            userID: userID,
            pinnedCriterionIDsByScope: [:],
            customCriteria: [first, second]
        )
        let selection = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .guided,
            bundle: bundle,
            preferences: preferences
        )
        let customIDs = selection.criteria.map(\.id).filter { $0.hasPrefix("custom.") }

        #expect(customIDs == ["custom.first", "custom.second"])
        #expect(selection.orderedCriteria.first { $0.id == "custom.first" }?.origin == .custom)
    }

    @Test func onlyIndependentEnjoymentAcceptsHalfSteps() throws {
        #expect(PersonalEnjoymentRating(value: 4.5)?.value == 4.5)
        #expect(PersonalEnjoymentRating(value: 4.5)?.anchor == "Memorable; I would seek it out")
        #expect(PersonalEnjoymentRating(value: 4.25) == nil)
        #expect(PersonalEnjoymentRating(value: 0.5) == nil)
        #expect(SensoryIntensityValue(scale: .consumerThree, level: 2) != nil)
        #expect(SensoryIntensityValue(scale: .consumerThree, level: 4) == nil)
        #expect(SensoryQualityImpression(4) != nil)
        #expect(SensoryQualityImpression(3)?.value == 3)
    }

    @Test func snapshotEncodesEnjoymentAsCanonicalNumericHalfStep() throws {
        let snapshot = SipSensorySnapshot(
            bundleID: "mugshot.sensory",
            bundleContentVersion: "2026.07.16.1",
            identity: confirmedPourOverIdentity(),
            personalizationScopeID: "brewed_coffee.pour_over",
            depth: .deep,
            ownWords: "Bright and tea-like",
            responses: [],
            personalEnjoyment: PersonalEnjoymentRating(value: 4.5)
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )

        #expect(object["personalEnjoyment"] as? Double == 4.5)
        #expect(object["personalEnjoyment"] as? [String: Any] == nil)
    }

    @Test func snapshotFreezesChoiceLabelsDurationAndIndependentEnjoyment() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let identity = confirmedPourOverIdentity()
        let selection = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .deep,
            bundle: bundle
        )
        var session = TastingLensSessionDraft(
            bundleID: bundle.bundleID,
            bundleContentVersion: bundle.contentVersion,
            depth: .deep,
            identity: identity,
            ownWords: "Bright and tea-like",
            personalEnjoyment: PersonalEnjoymentRating(value: 4.5),
            activePackIDs: selection.activePackIDs
        )
        session.setResponse(SensoryResponseDraft(
            criterionID: "criterion.body.weight",
            state: .observed,
            choiceIDs: ["body.full"],
            confidence: .sure,
            sourcePackIDs: selection.activePackIDs,
            userConfirmed: true,
            displayedOrder: 1
        ))
        session.setResponse(SensoryResponseDraft(
            criterionID: "criterion.finish.duration",
            state: .observed,
            duration: .lingering,
            confidence: .maybe,
            sourcePackIDs: selection.activePackIDs,
            userConfirmed: true,
            displayedOrder: 2
        ))
        session.setResponse(SensoryResponseDraft(
            criterionID: "criterion.overall.enjoyment",
            state: .observed,
            userConfirmed: true,
            displayedOrder: 3
        ))

        let snapshot = TastingLensSnapshotFactory().makeSnapshot(
            session: session,
            selection: selection,
            bundle: bundle
        )
        let body = try #require(snapshot.responses.first { $0.criterionID == "criterion.body.weight" })
        let duration = try #require(snapshot.responses.first { $0.criterionID == "criterion.finish.duration" })

        #expect(body.selectedChoiceIDs == ["body.full"])
        #expect(body.selectedChoices.first?.displayedLabel == "Full")
        #expect(duration.duration == .lingering)
        #expect(duration.scaleID == "scale.duration_3")
        #expect(duration.displayedScaleAnchors.map(\.displayedLabel) == ["Quick", "Medium", "Lingering"])
        #expect(snapshot.personalEnjoyment?.value == 4.5)
        #expect(!snapshot.responses.contains { $0.measure == .overallEnjoyment })
    }

    @Test func personalizationRequiresThreeConfirmedSameScopeSnapshotsAndShowsSupport() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let userID = UUID()
        let preferences = TastingLensUserPreferences(userID: userID)
        let snapshots = try (0..<6).map { index in
            try historySnapshot(
                index: index,
                observedCitrus: index < 3,
                enjoyment: index < 3 ? 4.5 : 3,
                identityConfirmed: true,
                bundle: bundle
            )
        } + [try historySnapshot(
            index: 7,
            observedCitrus: true,
            enjoyment: 5,
            identityConfirmed: false,
            bundle: bundle
        )]

        let patterns = TastingLensPersonalizationEngine().learnedPatterns(
            userID: userID,
            snapshots: snapshots,
            preferences: preferences,
            bundle: bundle,
            now: Date(timeIntervalSince1970: 10_000)
        )
        let citrus = try #require(patterns.first {
            $0.targetType == .descriptor && $0.targetID == "descriptor.fruit.citrus"
        })

        #expect(citrus.supportCount == 3)
        #expect(citrus.totalCount == 6)
        #expect(citrus.spontaneousSupportCount == 3)
        #expect(citrus.evidenceSnapshotIDs.count == 3)
        #expect(citrus.evidenceSummary.contains("3 of 6"))
        #expect(citrus.enjoymentAssociation == nil, "Unselected descriptor options are not explicit negative evidence.")

        let acidityCriterion = try #require(patterns.first {
            $0.targetType == .criterion && $0.targetID == "criterion.coffee.acidity_shape"
        })
        #expect(acidityCriterion.enjoymentAssociation?.direction == .higher)
        #expect(acidityCriterion.enjoymentAssociation?.observedSupportCount == 3)
        #expect(acidityCriterion.enjoymentAssociation?.comparisonCount == 3)
        #expect(acidityCriterion.enjoymentAssociation?.explanation.contains("association, not a cause") == true)
    }

    @Test func skippedResponsesNeverBecomeNegativeEnjoymentEvidence() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let userID = UUID()
        let preferences = TastingLensUserPreferences(userID: userID)
        let observed = try (0..<3).map { index in
            try historySnapshot(
                index: index,
                observedCitrus: true,
                enjoyment: 4.5,
                identityConfirmed: true,
                bundle: bundle
            )
        }
        let skipped = try (3..<6).map { index in
            try historySnapshot(
                index: index,
                observedCitrus: false,
                enjoyment: 2,
                identityConfirmed: true,
                comparisonState: .skipped,
                bundle: bundle
            )
        }

        let pattern = try #require(TastingLensPersonalizationEngine().learnedPatterns(
            userID: userID,
            snapshots: observed + skipped,
            preferences: preferences,
            bundle: bundle
        ).first { $0.targetType == .criterion && $0.targetID == "criterion.coffee.acidity_shape" })
        #expect(pattern.enjoymentAssociation == nil)
    }

    @Test func patternDismissalDoesNotHideTheUnderlyingCriterion() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let userID = UUID()
        let identity = confirmedPourOverIdentity()
        let scopeID = identity.personalizationScopeID
        let preferences = TastingLensUserPreferences(
            userID: userID,
            dismissals: [SensorySuggestionDismissal(
                targetID: "criterion.coffee.acidity_shape",
                scopeID: scopeID,
                reason: .notUseful
            )]
        )

        #expect(preferences.suppressesPattern(targetID: "criterion.coffee.acidity_shape", scopeID: scopeID))
        #expect(!preferences.hidesCriterion(targetID: "criterion.coffee.acidity_shape", scopeID: scopeID))
        let selection = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .deep,
            bundle: bundle,
            preferences: preferences
        )
        #expect(selection.criteria.contains { $0.id == "criterion.coffee.acidity_shape" })
    }

    @Test func responseProvenanceUsesOnlyThePacksThatSuppliedItsCriterion() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let identity = confirmedPourOverIdentity()
        let selection = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .guided,
            bundle: bundle
        )
        let ownWords = try #require(selection.orderedCriteria.first { $0.id == "criterion.own_words" })
        let acidity = try #require(selection.orderedCriteria.first { $0.id == "criterion.coffee.acidity_shape" })

        #expect(ownWords.sourcePackIDs == ["pack.universal"])
        #expect(acidity.sourcePackIDs.contains("pack.coffee.pour_over"))
        #expect(!acidity.sourcePackIDs.contains("pack.universal"))
        #expect(selection.activePackIDs.contains("pack.universal"))
    }

    @Test func correctingOneMistakenObservationDropsPatternBelowPromotionThreshold() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let userID = UUID()
        let snapshots = try (0..<3).map { index in
            try historySnapshot(
                index: index,
                observedCitrus: true,
                enjoyment: 4,
                identityConfirmed: true,
                bundle: bundle
            )
        }
        let mistaken = try #require(snapshots.first)
        let preferences = TastingLensUserPreferences(
            userID: userID,
            dismissals: [SensorySuggestionDismissal(
                targetID: "descriptor.fruit.citrus",
                scopeID: mistaken.personalizationScopeID,
                snapshotID: mistaken.id,
                reason: .selectedByMistake
            )]
        )

        let patterns = TastingLensPersonalizationEngine().learnedPatterns(
            userID: userID,
            snapshots: snapshots,
            preferences: preferences,
            bundle: bundle
        )
        #expect(!patterns.contains {
            $0.targetType == .descriptor && $0.targetID == "descriptor.fruit.citrus"
        })
    }

    @Test func preferenceStoreNeverCrossesAccountScopes() throws {
        let suite = "TastingLensPreferencesTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TastingLensPreferencesStore(defaults: defaults)
        let firstUser = UUID()
        let secondUser = UUID()

        let first = try store.setPinned(
            true,
            criterionID: "criterion.matcha.texture",
            scopeID: "matcha.whisked_powder",
            userID: firstUser
        )
        #expect(first.pinnedCriterionIDs(for: "matcha.whisked_powder") == ["criterion.matcha.texture"])
        #expect(store.load(userID: secondUser).pinnedCriterionIDsByScope.isEmpty)
        #expect(throws: TastingLensPreferencesStoreError.self) {
            try store.save(first, for: secondUser)
        }
    }

    @Test func inProgressLensSurvivesSipDraftAutosaveRoundTrip() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let session = TastingLensSessionDraft(
            bundleID: bundle.bundleID,
            bundleContentVersion: bundle.contentVersion,
            depth: .guided,
            identity: confirmedPourOverIdentity(),
            ownWords: "Peach tea and honey",
            responses: [SensoryResponseDraft(
                criterionID: "criterion.own_words",
                state: .observed,
                customText: "Peach tea and honey",
                sourcePackIDs: ["pack.universal"],
                userConfirmed: true,
                displayedOrder: 1
            )],
            activePackIDs: ["pack.coffee.pour_over", "pack.universal"],
            startedAt: Date(timeIntervalSince1970: 123),
            updatedAt: Date(timeIntervalSince1970: 456)
        )
        let draft = SipDraft(
            ownerUserID: UUID(),
            drinkName: "Ethiopian pour-over",
            sensorySessionDraft: session
        )

        let restored = try JSONDecoder().decode(
            SipDraft.self,
            from: JSONEncoder().encode(draft)
        )
        #expect(restored.sensorySessionDraft == session)
        #expect(restored.hasMeaningfulContent)
        #expect(restored.sensorySnapshot == nil)
    }

    @Test func inProgressLensSurvivesActualDraftStoreDiskRoundTrip() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let session = TastingLensSessionDraft(
            bundleID: bundle.bundleID,
            bundleContentVersion: bundle.contentVersion,
            depth: .guided,
            identity: confirmedPourOverIdentity(),
            ownWords: "Peach tea and honey",
            responses: [SensoryResponseDraft(
                criterionID: "criterion.own_words",
                state: .observed,
                customText: "Peach tea and honey",
                sourcePackIDs: ["pack.universal"],
                userConfirmed: true,
                displayedOrder: 1
            )],
            activePackIDs: ["pack.coffee.pour_over", "pack.universal"],
            startedAt: Date(timeIntervalSince1970: 123),
            updatedAt: Date(timeIntervalSince1970: 456)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TastingLensDraftStore.\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SipDraftStore(baseDirectory: directory)
        let draft = SipDraft(
            ownerUserID: UUID(),
            drinkName: "Ethiopian pour-over",
            sensorySessionDraft: session
        )

        let saved = try store.save(draft, images: [])
        let restored = try #require(store.load(id: saved.id)?.draft)
        let restoredSession = try #require(restored.sensorySessionDraft)
        #expect(restoredSession.id == session.id)
        #expect(restoredSession.bundleID == session.bundleID)
        #expect(restoredSession.bundleContentVersion == session.bundleContentVersion)
        #expect(restoredSession.depth == session.depth)
        #expect(restoredSession.identity == session.identity)
        #expect(restoredSession.ownWords == session.ownWords)
        #expect(restoredSession.responses == session.responses)
        #expect(restoredSession.activePackIDs == session.activePackIDs)
        #expect(abs(restoredSession.startedAt.timeIntervalSince(session.startedAt)) < 0.01)
        #expect(abs(restoredSession.updatedAt.timeIntervalSince(session.updatedAt)) < 0.01)
        #expect(restored.hasMeaningfulContent)
    }

    @Test func versionedDraftMigrationPreservesCompatibleAnswersAndPersonalRating() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let identity = confirmedPourOverIdentity()
        let selection = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .guided,
            bundle: bundle
        )
        let descriptorID = try #require(selection.descriptors.first(where: { $0.parentID != nil })?.id)
        let sessionID = UUID()
        let source = TastingLensSessionDraft(
            id: sessionID,
            bundleID: bundle.bundleID,
            bundleContentVersion: "2025.12.31",
            depth: .guided,
            identity: identity,
            ownWords: "Bright and tea-like",
            responses: [
                SensoryResponseDraft(
                    criterionID: "criterion.flavor.web",
                    state: .observed,
                    descriptorIDs: [descriptorID, "descriptor.removed"],
                    sourcePackIDs: ["pack.retired"],
                    userConfirmed: true,
                    displayedOrder: 99
                ),
                SensoryResponseDraft(
                    criterionID: "criterion.retired",
                    state: .observed,
                    customText: "Old question",
                    sourcePackIDs: ["pack.retired"],
                    userConfirmed: true
                )
            ],
            personalEnjoyment: PersonalEnjoymentRating(value: 4.5),
            activePackIDs: ["pack.retired"]
        )

        let migrated = TastingLens2ComposerContainer.migrateSession(
            source,
            bundle: bundle,
            selection: selection,
            now: Date(timeIntervalSince1970: 123)
        )
        let flavor = try #require(migrated.response(for: "criterion.flavor.web"))
        let expectedSourcePacks = selection.orderedCriteria
            .first(where: { $0.id == "criterion.flavor.web" })?.sourcePackIDs

        #expect(migrated.id == sessionID)
        #expect(migrated.bundleContentVersion == bundle.contentVersion)
        #expect(migrated.ownWords == "Bright and tea-like")
        #expect(migrated.personalEnjoyment?.value == 4.5)
        #expect(flavor.descriptorIDs == [descriptorID])
        #expect(flavor.sourcePackIDs == expectedSourcePacks)
        #expect(migrated.response(for: "criterion.retired") == nil)
    }

    @Test func preferenceMergeKeepsOfflineCorrectionsAndRetriesOnlyMissingAppendHistory() throws {
        let userID = UUID()
        let snapshotID = UUID()
        let localCorrection = SensorySuggestionDismissal(
            id: UUID(),
            targetID: "descriptor.local",
            scopeID: "matcha.whisked_powder",
            snapshotID: snapshotID,
            reason: .selectedByMistake,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let remotePreferenceDismissal = SensorySuggestionDismissal(
            id: UUID(),
            targetID: "criterion.remote",
            scopeID: "matcha.whisked_powder",
            reason: .notUseful,
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let remoteCorrection = SensorySuggestionDismissal(
            id: UUID(),
            targetID: "descriptor.remote",
            scopeID: "matcha.whisked_powder",
            snapshotID: UUID(),
            reason: .selectedByMistake,
            createdAt: Date(timeIntervalSince1970: 30)
        )
        let local = TastingLensUserPreferences(
            userID: userID,
            dismissals: [localCorrection],
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let remote = TastingLensUserPreferences(
            userID: userID,
            defaultDepth: .deep,
            dismissals: [remotePreferenceDismissal],
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let merged = TastingLens2ComposerContainer.mergePreferences(
            local: local,
            remote: remote,
            remoteCorrections: [remoteCorrection]
        )
        let pending = TastingLens2ComposerContainer.pendingCorrections(
            local: merged.dismissals,
            remote: [remoteCorrection]
        )

        #expect(merged.defaultDepth == .deep)
        #expect(Set(merged.dismissals.map(\.id)) == [
            localCorrection.id, remotePreferenceDismissal.id, remoteCorrection.id
        ])
        #expect(pending.map(\.id) == [localCorrection.id])
    }

    @Test func learnedEvidenceActuallyChangesGuidedSelectionAndDismissalReversesIt() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let userID = UUID()
        let identity = confirmedPourOverIdentity()
        let deepSelection = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .deep,
            bundle: bundle
        )
        let learnedRanked = try #require(deepSelection.orderedCriteria.first {
            $0.id == "criterion.temperature.change"
        })
        let snapshots = (0..<3).map { index in
            var session = TastingLensSessionDraft(
                bundleID: bundle.bundleID,
                bundleContentVersion: bundle.contentVersion,
                depth: .deep,
                identity: identity,
                personalEnjoyment: PersonalEnjoymentRating(value: 4),
                activePackIDs: deepSelection.activePackIDs
            )
            session.setResponse(SensoryResponseDraft(
                criterionID: "criterion.temperature.change",
                state: .observed,
                choiceIDs: ["temperature.aroma"],
                confidence: .sure,
                suggestionOrigin: .basePack,
                sourcePackIDs: learnedRanked.sourcePackIDs,
                userConfirmed: true,
                displayedOrder: learnedRanked.criterion.order
            ))
            return TastingLensSnapshotFactory().makeSnapshot(
                session: session,
                selection: deepSelection,
                bundle: bundle,
                createdAt: Date(timeIntervalSince1970: Double(index))
            )
        }
        let preferences = TastingLensUserPreferences(userID: userID)
        let patterns = TastingLensPersonalizationEngine().learnedPatterns(
            userID: userID,
            snapshots: snapshots,
            preferences: preferences,
            bundle: bundle
        )
        let baseline = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .guided,
            bundle: bundle,
            preferences: preferences
        )
        let adapted = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .guided,
            bundle: bundle,
            preferences: preferences,
            patterns: patterns
        )

        #expect(!baseline.criteria.contains { $0.id == "criterion.temperature.change" })
        #expect(adapted.criteria.contains { $0.id == "criterion.temperature.change" })
        #expect(adapted.orderedCriteria.first(where: {
            $0.id == "criterion.temperature.change"
        })?.origin == .learnedPattern)

        let dismissedPreferences = TastingLensUserPreferences(
            userID: userID,
            dismissals: [SensorySuggestionDismissal(
                targetID: "criterion.temperature.change",
                scopeID: identity.personalizationScopeID,
                reason: .notUseful
            )]
        )
        let dismissedPatterns = TastingLensPersonalizationEngine().learnedPatterns(
            userID: userID,
            snapshots: snapshots,
            preferences: dismissedPreferences,
            bundle: bundle
        )
        let afterDismissal = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .guided,
            bundle: bundle,
            preferences: dismissedPreferences,
            patterns: dismissedPatterns
        )
        #expect(!afterDismissal.criteria.contains { $0.id == "criterion.temperature.change" })
    }

    @Test func coreJourneyCriteriaCannotBeHiddenAndResumedChoicesStayTyped() throws {
        let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
        let identity = confirmedPourOverIdentity()
        let scopeID = identity.personalizationScopeID
        let preferences = TastingLensUserPreferences(
            userID: UUID(),
            dismissals: [
                SensorySuggestionDismissal(
                    targetID: "criterion.flavor.web",
                    scopeID: scopeID,
                    reason: .notRelevant
                ),
                SensorySuggestionDismissal(
                    targetID: "criterion.mugsy.leading",
                    scopeID: scopeID,
                    reason: .notRelevant
                )
            ]
        )
        let selection = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .guided,
            bundle: bundle,
            preferences: preferences
        )
        let response = SensoryResponseDraft(
            criterionID: "criterion.coffee.sediment",
            state: .observed,
            descriptorIDs: ["descriptor.texture.gritty"],
            choiceIDs: ["sediment.liked"],
            preference: .liked,
            userConfirmed: true
        )
        let restored = try #require(TastingLens2View.makeAnswers(from: [response])[response.criterionID])

        #expect(selection.criteria.contains { $0.id == "criterion.flavor.web" })
        #expect(selection.criteria.contains { $0.id == "criterion.mugsy.leading" })
        #expect(restored.selectedIDs == ["sediment.liked"])
        #expect(!restored.selectedIDs.contains("descriptor.texture.gritty"))
    }

    private func confirmedPourOverIdentity(userConfirmed: Bool = true) -> SensoryDrinkIdentity {
        SensoryDrinkIdentity(
            rawName: "Ethiopian pour-over",
            family: .brewedCoffee,
            preparation: .pourOver,
            temperature: .warm,
            confidence: 1,
            provenance: .user,
            userConfirmed: userConfirmed
        )
    }

    private func historySnapshot(
        index: Int,
        observedCitrus: Bool,
        enjoyment: Double,
        identityConfirmed: Bool,
        comparisonState: SensoryResponseState = .notPresent,
        bundle: SensoryKnowledgeBundle
    ) throws -> SipSensorySnapshot {
        let identity = confirmedPourOverIdentity(userConfirmed: identityConfirmed)
        let selection = TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: identity,
            depth: .guided,
            bundle: bundle
        )
        var session = TastingLensSessionDraft(
            bundleID: bundle.bundleID,
            bundleContentVersion: bundle.contentVersion,
            depth: .guided,
            identity: identity,
            ownWords: observedCitrus ? "Citrus" : "Cocoa",
            personalEnjoyment: PersonalEnjoymentRating(value: enjoyment),
            activePackIDs: selection.activePackIDs,
            startedAt: Date(timeIntervalSince1970: Double(index)),
            updatedAt: Date(timeIntervalSince1970: Double(index))
        )
        session.setResponse(SensoryResponseDraft(
            criterionID: "criterion.flavor.web",
            state: observedCitrus ? .observed : comparisonState,
            descriptorIDs: observedCitrus ? ["descriptor.fruit.citrus"] : [],
            preference: observedCitrus ? .liked : nil,
            confidence: observedCitrus ? .sure : .maybe,
            suggestionOrigin: .neutralPrompt,
            sourcePackIDs: selection.activePackIDs,
            userConfirmed: true,
            displayedOrder: 1
        ), now: Date(timeIntervalSince1970: Double(index)))
        session.setResponse(SensoryResponseDraft(
            criterionID: "criterion.coffee.acidity_shape",
            state: observedCitrus ? .observed : comparisonState,
            choiceIDs: observedCitrus ? ["acidity.juicy"] : [],
            confidence: observedCitrus ? .sure : nil,
            suggestionOrigin: .basePack,
            sourcePackIDs: selection.orderedCriteria
                .first(where: { $0.id == "criterion.coffee.acidity_shape" })?
                .sourcePackIDs ?? [],
            userConfirmed: true,
            displayedOrder: 2
        ), now: Date(timeIntervalSince1970: Double(index)))
        return TastingLensSnapshotFactory().makeSnapshot(
            session: session,
            selection: selection,
            bundle: bundle,
            createdAt: Date(timeIntervalSince1970: Double(index))
        )
    }

    private func customCriterion(
        id: String,
        title: String,
        order: Int
    ) -> SensoryCriterionDefinition {
        SensoryCriterionDefinition(
            id: id,
            title: title,
            prompt: title,
            helper: "A custom typed observation.",
            accessibilityLabel: title,
            dimension: .personalResponse,
            stage: .personal,
            measure: .singleChoice,
            scaleID: nil,
            options: [SensoryChoiceDefinition(
                id: "\(id).yes",
                label: "Yes",
                helper: nil,
                descriptorID: nil
            )],
            descriptorRootIDs: [],
            depths: [.guided, .deep],
            applicability: [SensoryApplicabilityRule(
                field: .family,
                values: [SensoryBeverageFamily.brewedCoffee.rawValue]
            )],
            evidenceSourceIDs: [],
            order: order
        )
    }
}
