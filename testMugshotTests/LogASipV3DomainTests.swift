import Foundation
import Testing
@testable import testMugshot

struct LogASipV3DomainTests {
    @Test func productionReflectionKeepsBroadCriteriaAndEightCoachPromptsPerCoreSurface() {
        #expect(LogASipV3CriterionSuggestion.sip.count >= 20)
        #expect(LogASipV3CriterionSuggestion.cafe.count >= 20)
        #expect(LogASipV3CoachPrompt.sip.count == 8)
        #expect(LogASipV3CoachPrompt.cafe.count == 8)

        #expect(Set(LogASipV3CoachPrompt.sip.map(\.id)).count == 8)
        #expect(Set(LogASipV3CoachPrompt.cafe.map(\.id)).count == 8)
        #expect(Set(LogASipV3CriterionSuggestion.sip.map(\.id)).count == LogASipV3CriterionSuggestion.sip.count)
        #expect(Set(LogASipV3CriterionSuggestion.cafe.map(\.id)).count == LogASipV3CriterionSuggestion.cafe.count)
    }

    @Test func sipCriterionCatalogIsBroadRenamedAndContextAware() {
        #expect(LogASipV3CriterionSuggestion.sip.count == 58)
        #expect(!LogASipV3CriterionSuggestion.sip.contains { $0.title == "Orange balance" })
        #expect(LogASipV3CriterionSuggestion.sip.contains { $0.title == "Flavor balance" })
        #expect(LogASipV3CriterionSuggestion.sip.contains { $0.title == "Body / Smoothness" })

        let latte = SipDraft(drinkType: .coffee, drinkName: "Oat milk latte")
        let latteSuggestions = LogASipV3CriterionSuggestion.sip(for: latte)
        #expect(Array(latteSuggestions.prefix(3).map(\.id)) == ["milk-integration", "coffee-presence", "texture"])
        #expect((12...18).contains(latteSuggestions.count))
        #expect(!latteSuggestions.contains { ["crema", "extraction", "umami", "whisk-texture"].contains($0.id) })

        let matcha = SipDraft(drinkType: .matcha, drinkName: "Ceremonial matcha")
        let matchaSuggestions = LogASipV3CriterionSuggestion.sip(for: matcha)
        #expect(Array(matchaSuggestions.prefix(4).map(\.id)) == [
            "umami", "astringency", "whisk-texture", "vegetal-character"
        ])
        #expect(!matchaSuggestions.contains { ["crema", "extraction", "coffee-presence"].contains($0.id) })
    }

    @Test func everyDrinkPreparationOffersTwelveToEighteenUniqueRelevantCriteria() {
        let cases: [(DrinkPreparation, DrinkType, String)] = [
            (.espresso, .coffee, "Espresso"),
            (.americano, .coffee, "Americano"),
            (.latte, .coffee, "Latte"),
            (.cappuccino, .coffee, "Cappuccino"),
            (.cortado, .coffee, "Cortado"),
            (.flatWhite, .coffee, "Flat white"),
            (.mocha, .coffee, "Mocha"),
            (.macchiato, .coffee, "Macchiato"),
            (.drip, .coffee, "Drip coffee"),
            (.pourOver, .coffee, "Pour over"),
            (.chemex, .coffee, "Chemex"),
            (.frenchPress, .coffee, "French press"),
            (.aeropress, .coffee, "AeroPress"),
            (.coldBrew, .coffee, "Cold brew"),
            (.matcha, .matcha, "Ceremonial matcha"),
            (.hojicha, .hojicha, "Hojicha"),
            (.tea, .tea, "Green tea"),
            (.chai, .chai, "Chai"),
            (.hotChocolate, .hotChocolate, "Hot chocolate"),
            (.unknown, .other, "Seasonal special")
        ]

        for (preparation, drinkType, name) in cases {
            var analysis = DrinkAnalysisParser.analyze(name)
            analysis.preparation = preparation
            let draft = SipDraft(
                drinkType: drinkType,
                drinkName: name,
                drinkAnalysis: analysis
            )
            let suggestions = LogASipV3CriterionSuggestion.sip(for: draft)
            #expect(
                (12...18).contains(suggestions.count),
                "\(preparation.rawValue) returned \(suggestions.count) criteria"
            )
            #expect(Set(suggestions.map(\.id)).count == suggestions.count)
        }
    }

    @Test func everyHomeBrewMethodOffersTwelveToEighteenUniqueCriteria() {
        for method in HomeBrewMethod.allCases {
            let draft = SipDraft(
                context: .home,
                drinkType: .coffee,
                drinkName: method.title,
                brewMethod: method.rawValue
            )
            let suggestions = LogASipV3CriterionSuggestion.sip(for: draft)
            #expect(
                (12...18).contains(suggestions.count),
                "\(method.rawValue) returned \(suggestions.count) criteria"
            )
            #expect(Set(suggestions.map(\.id)).count == suggestions.count)
        }
    }

    @Test func icedLatteCriteriaStayMilkRelevantAndAddColdDrinkSignals() {
        let draft = SipDraft(drinkType: .coffee, drinkName: "Iced oat milk latte")
        let ids = LogASipV3CriterionSuggestion.sip(for: draft).map(\.id)

        #expect(Array(ids.prefix(2)) == ["refreshment", "ice-balance"])
        #expect(ids.contains("milk-integration"))
        #expect(ids.contains("coffee-presence"))
        #expect(!ids.contains("crema"))
        #expect(!ids.contains("extraction"))
        #expect(!ids.contains("whisk-texture"))
    }

    @Test func feedScopeBarHoldsThenReleasesContinuously() {
        let barHeight: CGFloat = 52
        let stackSpacing = DesignSystem.Space.sm
        let contentTopInset = DesignSystem.Space.xxs
        let contentReservation = FeedScopeBarMotion.contentReservation(
            barHeight: barHeight,
            stackSpacing: stackSpacing,
            contentTopInset: contentTopInset
        )
        let pulled = FeedScopeBarMotion.metrics(offset: -80, barHeight: barHeight)
        let resting = FeedScopeBarMotion.metrics(offset: 0, barHeight: barHeight)
        let early = FeedScopeBarMotion.metrics(offset: 59, barHeight: barHeight)
        let threshold = FeedScopeBarMotion.metrics(
            offset: resting.holdDistance,
            barHeight: barHeight
        )
        let partiallyReleased = FeedScopeBarMotion.metrics(
            offset: resting.holdDistance + 30,
            barHeight: barHeight
        )
        let released = FeedScopeBarMotion.metrics(
            offset: resting.holdDistance + barHeight,
            barHeight: barHeight
        )

        #expect(FeedScopeBarMotion.restingTopInset == 0)
        #expect(
            contentTopInset + contentReservation + stackSpacing - barHeight
                == FeedScopeBarMotion.restingContentGap
        )
        #expect(resting.holdDistance == 60)
        #expect(pulled.verticalOffset == 0)
        #expect(resting.verticalOffset == 0)
        #expect(early.verticalOffset == 0)
        #expect(threshold.verticalOffset == 0)
        #expect(threshold.releaseProgress == 0)
        #expect(abs(partiallyReleased.verticalOffset + 30) < 0.0001)
        #expect(partiallyReleased.releaseProgress == 30 / barHeight)
        #expect(released.verticalOffset == -barHeight)
        #expect(released.releaseProgress == 1)
        #expect(released.shadowOpacity == 0)
    }

    @Test func legacySipDraftDecodesWhenV3OptionalStorageIsAbsent() throws {
        let sipCriterion = SipRatingCriterionSnapshot(
            name: "Taste",
            score: 4.2,
            weight: 1.5,
            sortOrder: 0,
            isPinned: true
        )
        let contextCriterion = SipRatingCriterionSnapshot(
            name: "Comfort",
            score: 3.6,
            weight: 1,
            sortOrder: 0,
            isPinned: true
        )
        let draft = SipDraft(
            context: .home,
            locationName: "Kitchen counter",
            drinkName: "Morning matcha",
            overallScore: 4.2,
            privateNotes: "A legacy note survives.",
            ratingCriteria: [sipCriterion],
            v3Step: .publish,
            contextNotes: "A newer context note",
            rawNoteVisibility: .everyone,
            contextScore: 3.6,
            contextRatingCriteria: [contextCriterion],
            photoFallback: .mugsyMissedPhoto,
            homeMakeAgain: .withATweak
        )

        let encoded = try JSONEncoder().encode(draft)
        var legacyPayload = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        [
            "v3Step",
            "v3ContextNotes",
            "v3RawNoteVisibility",
            "contextScore",
            "v3ContextRatingCriteria",
            "v3ManualOverallScore",
            "v3ManualContextScore",
            "v3HomeCoffeeBagID",
            "v3HomeComparisonSource",
            "photoFallback",
            "homeMakeAgain"
        ].forEach { legacyPayload.removeValue(forKey: $0) }

        var legacyCriteria = try #require(
            legacyPayload["ratingCriteria"] as? [[String: Any]]
        )
        legacyCriteria[0].removeValue(forKey: "isPinned")
        legacyPayload["ratingCriteria"] = legacyCriteria

        let legacyData = try JSONSerialization.data(withJSONObject: legacyPayload)
        let decoded = try JSONDecoder().decode(SipDraft.self, from: legacyData)

        #expect(decoded.context == .home)
        #expect(decoded.locationName == "Kitchen counter")
        #expect(decoded.drinkName == "Morning matcha")
        #expect(decoded.privateNotes == "A legacy note survives.")
        #expect(decoded.v3Step == nil)
        #expect(decoded.contextNotes.isEmpty)
        #expect(decoded.rawNoteVisibility == .private)
        #expect(decoded.contextScore == nil)
        #expect(decoded.contextRatingCriteria.isEmpty)
        #expect(decoded.photoFallback == nil)
        #expect(decoded.homeMakeAgain == nil)
        #expect(decoded.ratingCriteria.first?.isPinned == nil)
    }

    @Test func elsewhereRoundTripsThroughTheBackendContextValue() {
        let backendValue = JournalEntryContext.elsewhere.rawValue

        #expect(backendValue == "Elsewhere")
        #expect(JournalEntryContext(backendValue: backendValue) == .elsewhere)
        #expect(JournalEntryContext(backendValue: "  elsewhere  ") == .elsewhere)
    }

    @Test func changingV3ContextClearsPlaceSpecificEvidence() {
        var draft = SipDraft(
            context: .cafe,
            cafe: Cafe(name: "Context Cafe"),
            locationName: "Context Cafe",
            drinkName: "Latte",
            contextNotes: "Busy room",
            contextScore: 3.2,
            contextRatingCriteria: [
                SipRatingCriterionSnapshot(
                    name: "Atmosphere",
                    score: 3.2,
                    weight: 1,
                    sortOrder: 0
                )
            ]
        )

        draft.selectV3Context(.elsewhere)

        #expect(draft.context == .elsewhere)
        #expect(draft.cafe == nil)
        #expect(draft.locationName.isEmpty)
        #expect(draft.contextNotes.isEmpty)
        #expect(draft.contextScore == nil)
        #expect(draft.contextRatingCriteria.isEmpty)
        #expect(draft.visibility == .private)

        draft.selectV3Context(.home)
        #expect(draft.locationName == "Home")
    }

    @Test func weightedCriterionMathProducesOneDecimalSuggestions() throws {
        let criteria = [
            SipRatingCriterionSnapshot(
                name: "Taste",
                score: 2.3,
                weight: 2.25,
                sortOrder: 0
            ),
            SipRatingCriterionSnapshot(
                name: "Value",
                score: 3.1,
                weight: 1.5,
                sortOrder: 1
            ),
            SipRatingCriterionSnapshot(
                name: "Aroma",
                score: 4,
                weight: 0.5,
                sortOrder: 2
            ),
            SipRatingCriterionSnapshot(
                name: "Not relevant",
                score: 5,
                weight: 100,
                sortOrder: 3,
                relevanceOverride: false
            )
        ]

        let suggestion = try #require(
            SipRatingCriterionSnapshot.weightedSuggestion(for: criteria)
        )

        #expect(suggestion == 2.8)
        #expect(suggestion * 10 == (suggestion * 10).rounded())
    }

    @Test func ratedCriteriaOverrideAndThenRestoreManualSipAndCafeBaselines() throws {
        var draft = SipDraft(
            context: .cafe,
            cafe: Cafe(name: "Baseline Cafe"),
            drinkName: "Latte",
            overallScore: 4,
            ratingCriteria: [
                SipRatingCriterionSnapshot(name: "Flavor", score: 3, weight: 1, sortOrder: 0),
                SipRatingCriterionSnapshot(name: "Texture", score: 5, weight: 2, sortOrder: 1)
            ],
            contextScore: 4,
            contextRatingCriteria: [
                SipRatingCriterionSnapshot(name: "Service", score: 2, weight: 1, sortOrder: 0),
                SipRatingCriterionSnapshot(name: "Atmosphere", score: 5, weight: 1, sortOrder: 1)
            ]
        )
        draft.setManualOverallScore(4)
        draft.setManualContextScore(4)

        draft.synchronizeOverallScoreWithCriteria()
        draft.synchronizeContextScoreWithCriteria()
        #expect(draft.overallScore == 4.3)
        #expect(draft.contextScore == 3.5)
        #expect(draft.isOverallScoreDerivedFromCriteria)
        #expect(draft.isContextScoreDerivedFromCriteria)

        draft.ratingCriteria[0].weight = 2
        draft.synchronizeOverallScoreWithCriteria()
        #expect(draft.overallScore == 4)

        draft.ratingCriteria.indices.forEach { draft.ratingCriteria[$0].score = 0 }
        draft.contextRatingCriteria.indices.forEach { draft.contextRatingCriteria[$0].score = 0 }
        draft.synchronizeOverallScoreWithCriteria()
        draft.synchronizeContextScoreWithCriteria()
        #expect(draft.overallScore == 4)
        #expect(draft.contextScore == 4)

        let restored = try JSONDecoder().decode(
            SipDraft.self,
            from: JSONEncoder().encode(draft)
        )
        #expect(restored.overallScore == 4)
        #expect(restored.contextScore == 4)
    }

    @Test func clearingCriteriaWithoutAManualSipBaselineReturnsToUnrated() {
        var draft = SipDraft(
            drinkName: "Espresso",
            ratingCriteria: [
                SipRatingCriterionSnapshot(name: "Flavor", score: 4.5, weight: 1, sortOrder: 0)
            ]
        )

        draft.synchronizeOverallScoreWithCriteria()
        #expect(draft.overallScore == 4.5)

        draft.ratingCriteria[0].score = 0
        draft.synchronizeOverallScoreWithCriteria()
        #expect(draft.overallScore == 0)
    }

    @Test func rawNoteVisibilityNeverExceedsThePostAudience() {
        for postAudience in VisitVisibility.allCases {
            for requestedRawAudience in VisitVisibility.allCases {
                let draft = SipDraft(
                    context: .elsewhere,
                    locationName: "Farmers market",
                    drinkName: "Iced tea",
                    overallScore: 4,
                    visibility: postAudience,
                    rawNoteVisibility: requestedRawAudience
                )

                let reflection = V3VisitReflection.make(
                    visitID: UUID(),
                    from: draft
                )
                let expected = requestedRawAudience.breadth <= postAudience.breadth
                    ? requestedRawAudience
                    : postAudience

                #expect(reflection.rawNoteVisibility == expected)
                #expect(reflection.rawNoteVisibility.breadth <= postAudience.breadth)
            }
        }
    }

    @Test func uploadStagingKeepsRawJournalWritingPrivate() {
        let reflection = V3VisitReflection(
            visitID: UUID(),
            sipScore: 4.2,
            contextScore: 3.8,
            contextCriteria: [],
            sipRawNote: "A private first impression",
            contextRawNote: "Quiet corner",
            rawNoteVisibility: .friends,
            photoFallback: nil,
            homeMakeAgain: nil
        )

        let staged = reflection.privateUploadProjection

        #expect(staged.rawNoteVisibility == .private)
        #expect(staged.sipRawNote == reflection.sipRawNote)
        #expect(staged.contextRawNote == reflection.contextRawNote)
        #expect(reflection.rawNoteVisibility == .friends)
    }

    @Test func publishedPassportHandoffIsOwnerScopedAndExpires() throws {
        let suiteName = "V3PublishedCompletionStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = V3PublishedCompletionStore(
            defaults: defaults,
            expirationInterval: 60
        )
        let ownerID = UUID()
        let record = V3PublishedCompletionRecord(
            ownerUserID: ownerID,
            visitID: UUID(),
            isRemote: true,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        try store.save(record)

        #expect(store.load(ownerUserID: ownerID, now: Date(timeIntervalSince1970: 120)) == record)
        #expect(store.load(ownerUserID: UUID(), now: Date(timeIntervalSince1970: 120)) == nil)
        var expiredVisitID: UUID?
        #expect(
            store.load(
                ownerUserID: ownerID,
                now: Date(timeIntervalSince1970: 161),
                onExpired: { expiredVisitID = $0.visitID }
            ) == nil
        )
        #expect(expiredVisitID == record.visitID)
    }

    @Test func pinnedCriteriaReturnBlankWithRememberedImportance() throws {
        let suiteName = "PinnedCriterionStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PinnedCriterionStore(defaults: defaults)
        let importanceStore = CriterionImportanceStore(defaults: defaults)
        let pinned = SipRatingCriterionSnapshot(
            name: "Flavor balance",
            score: 4.7,
            weight: 2.25,
            sortOrder: 0,
            isPinned: true
        )
        store.synchronize([pinned], scope: "owner.sip")
        importanceStore.synchronize([pinned], scope: "owner.sip")
        var nextVisit: [SipRatingCriterionSnapshot] = []

        store.applyPins(to: &nextVisit, scope: "owner.sip")
        importanceStore.apply(to: &nextVisit, scope: "owner.sip")

        let restored = try #require(nextVisit.first)
        #expect(restored.name == "Flavor Balance")
        #expect(restored.score == 0)
        #expect(restored.weight == 2.25)
        #expect(restored.isPinned == true)
    }

    @Test func photoDeletionRepairsCoverAcrossBeforeAtAndAfterCases() {
        #expect(
            SipPhotoDeletionPolicy.repairedCoverIndex(
                removing: 1,
                currentCoverIndex: 3,
                photoCountBeforeRemoval: 5
            ) == 2
        )
        #expect(
            SipPhotoDeletionPolicy.repairedCoverIndex(
                removing: 3,
                currentCoverIndex: 3,
                photoCountBeforeRemoval: 5
            ) == 3
        )
        #expect(
            SipPhotoDeletionPolicy.repairedCoverIndex(
                removing: 4,
                currentCoverIndex: 3,
                photoCountBeforeRemoval: 5
            ) == 3
        )
        #expect(
            SipPhotoDeletionPolicy.repairedCoverIndex(
                removing: 0,
                currentCoverIndex: 0,
                photoCountBeforeRemoval: 1
            ) == 0
        )
    }

    @Test func lastCriteriaSetupReturnsNamesWithoutVisitRatings() throws {
        let suiteName = "RecentCriterionSetupStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = RecentCriterionSetupStore(defaults: defaults)
        store.remember(
            [
                SipRatingCriterionSnapshot(
                    name: "Balance",
                    score: 4.6,
                    weight: 2.25,
                    sortOrder: 0
                )
            ],
            scope: "owner.sip"
        )
        var nextVisit: [SipRatingCriterionSnapshot] = []

        store.apply(to: &nextVisit, scope: "owner.sip")

        let restored = try #require(nextVisit.first)
        #expect(restored.name == "Balance")
        #expect(restored.score == 0)
        #expect(restored.weight == 1)
    }

    @Test func homeKeepsTheSipScoreWhileCafeAndElsewhereBlendToOneDecimal() {
        let contextCriterion = SipRatingCriterionSnapshot(
            name: "Atmosphere",
            score: 1.2,
            weight: 1,
            sortOrder: 0
        )
        let homeDraft = SipDraft(
            context: .home,
            locationName: "Home",
            drinkName: "Pour over",
            overallScore: 4.4,
            contextScore: 1.2,
            contextRatingCriteria: [contextCriterion],
            homeMakeAgain: .yes
        )
        let home = V3VisitReflection.make(visitID: UUID(), from: homeDraft)

        #expect(home.contextScore == nil)
        #expect(home.contextCriteria.isEmpty)
        #expect(home.mugshotScore == 4.4)
        #expect(home.homeMakeAgain == .yes)

        let cafeDraft = SipDraft(
            context: .cafe,
            cafe: Cafe(name: "Score Blend Cafe"),
            drinkName: "Orange latte",
            overallScore: 2.4,
            contextScore: 3.4
        )
        let cafe = V3VisitReflection.make(visitID: UUID(), from: cafeDraft)

        #expect(cafe.contextScore == 3.4)
        #expect(cafe.mugshotScore == 2.9)

        let elsewhereDraft = SipDraft(
            context: .elsewhere,
            locationName: "Campground",
            drinkName: "Camp coffee",
            overallScore: 3.7,
            contextScore: 2.8
        )
        let elsewhere = V3VisitReflection.make(visitID: UUID(), from: elsewhereDraft)

        #expect(elsewhere.contextScore == 2.8)
        #expect(elsewhere.mugshotScore == 3.3)
    }

    @Test func explicitMugsyPlaceholderPersistsIntoTheReflectionEnvelope() throws {
        let draft = SipDraft(
            context: .elsewhere,
            locationName: "Train platform",
            drinkName: "Tea to go",
            overallScore: 3.8,
            photoFallback: .mugsyMissedPhoto
        )

        let restoredDraft = try JSONDecoder().decode(
            SipDraft.self,
            from: JSONEncoder().encode(draft)
        )
        let reflection = V3VisitReflection.make(
            visitID: UUID(),
            from: restoredDraft
        )
        let restoredReflection = try JSONDecoder().decode(
            V3VisitReflection.self,
            from: JSONEncoder().encode(reflection)
        )

        #expect(restoredDraft.photoFallback == .mugsyMissedPhoto)
        #expect(restoredReflection.photoFallback == .mugsyMissedPhoto)

        var photographedDraft = restoredDraft
        photographedDraft.localPhotoNames = ["photo.jpg"]
        #expect(
            V3VisitReflection.make(
                visitID: UUID(),
                from: photographedDraft
            ).photoFallback == nil
        )
    }

    @Test func cafeExperienceRatingAcceptsOneDecimalOnlyWithinRange() throws {
        let accepted = try #require(CafeExperienceRating(value: 2.4))
        let restored = try JSONDecoder().decode(
            CafeExperienceRating.self,
            from: JSONEncoder().encode(accepted)
        )

        #expect(accepted.value == 2.4)
        #expect(restored.value == 2.4)
        #expect(CafeExperienceRating(value: 2.41) == nil)
        #expect(CafeExperienceRating(value: 0.9) == nil)
        #expect(CafeExperienceRating(value: 5.1) == nil)
    }
}
