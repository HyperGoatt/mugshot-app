import Foundation
import Testing
import UIKit
@testable import testMugshot

struct HomeWorkbenchTests {
    @Test func coffeeMethodNormalizationAndRatioStayMethodAware() {
        #expect(HomeBrewMethod(storedValue: "V60") == .pourOver)
        #expect(HomeBrewMethod(storedValue: "Aero Press") == .aeroPress)
        #expect(HomeBrewMethod(storedValue: "unknown brewer") == .other)

        var details = BrewDetails.empty
        details.doseGrams = 20
        details.homeMethodDetails = HomeMethodDetails(waterGrams: 320)
        #expect(details.brewRatio == 16)

        details.yieldGrams = 40
        #expect(details.brewRatio == 2)
    }

    @Test func measurementUnitsNormalizeIntoCanonicalStorageValues() {
        #expect(abs(HomeBrewMetrics.grams(1, from: .ounces) - 28.3495) < 0.001)
        #expect(abs(HomeBrewMetrics.celsius(212, from: .fahrenheit) - 100) < 0.001)
        #expect(HomeBrewMetrics.seconds(2.5, from: .minutes) == 150)
        #expect(HomeBrewMetrics.seconds(12, from: .hours) == 43_200)
    }

    @Test func advancedFieldsStayMethodSpecific() {
        #expect(HomeBrewMethod.espresso.detailFields == [.preinfusion, .pressure, .pressureFlowNotes])
        #expect(HomeBrewMethod.pourOver.detailFields.contains(.pourStages))
        #expect(!HomeBrewMethod.pourOver.detailFields.contains(.pressure))
        #expect(HomeBrewMethod.coldBrew.detailFields == [.coldBrewSteep, .customNotes])
        #expect(HomeBrewMethod.pod.detailFields == [.customNotes])
    }

    @Test func comparisonReportsOnlyChangedEvidence() {
        var previousDetails = BrewDetails.empty
        previousDetails.doseGrams = 18
        previousDetails.yieldGrams = 36
        previousDetails.grindSetting = "17"
        previousDetails.brewTimeSeconds = 28

        var currentDetails = previousDetails
        currentDetails.doseGrams = 18.5
        currentDetails.grindSetting = "16"

        let previous = HomeBrewSnapshot(
            drinkName: "Ethiopia",
            brewMethod: "Espresso",
            equipment: "Niche Zero",
            brewDetails: previousDetails
        )
        let current = HomeBrewSnapshot(
            drinkName: "Ethiopia",
            brewMethod: "Espresso",
            equipment: "Niche Zero",
            brewDetails: currentDetails
        )

        let comparison = HomeBrewComparison.compare(current: current, with: previous)
        #expect(comparison.deltas.map(\.key) == ["dose", "grind"])
        #expect(comparison.summary?.contains("was 18g") == true)
        #expect(comparison.summary?.contains("was 17") == true)
    }

    @Test func bagSnapshotCannotCarryInventoryPhotoOrOwnerIdentity() throws {
        let ownerID = UUID()
        let bag = CoffeeBag(
            ownerUserID: ownerID,
            roaster: "Mugshot Coffee",
            name: "Daybreak",
            origin: "Ethiopia",
            startingWeightGrams: 250,
            remainingWeightGrams: 120,
            status: .frozen,
            privatePhotoPath: "\(ownerID)/private.jpg",
            localPhotoPath: "bag-photos/local.jpg"
        )
        var details = BrewDetails.empty
        details.coffeeBag = bag.safeSnapshot

        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(details)) as? [String: Any]
        )
        let encoded = String(data: try JSONSerialization.data(withJSONObject: object), encoding: .utf8) ?? ""

        #expect(encoded.contains("Mugshot Coffee"))
        #expect(!encoded.contains(ownerID.uuidString))
        #expect(!encoded.contains("remainingWeight"))
        #expect(!encoded.contains("private.jpg"))
        #expect(!encoded.contains("frozen"))
    }

    @Test func scanParserPrefersLabelsAndMarksLayoutGuesses() throws {
        let proposal = CoffeeBagScanParser.proposal(from: [
            "Heart Coffee Roasters",
            "Kenya Gichathaini",
            "Origin: Nyeri, Kenya",
            "Process: Washed",
            "Tasting Notes: Blackcurrant, citrus, caramel"
        ])

        #expect(proposal[.origin]?.value == "Nyeri, Kenya")
        #expect(proposal[.process]?.value == "Washed")
        #expect(proposal[.tastingNotes]?.value == "Blackcurrant, citrus, caramel")
        #expect(proposal[.roaster]?.isLowConfidence == true)
        #expect(proposal[.name]?.isLowConfidence == true)
    }

    @Test func localLibraryIsAccountScopedAndKeepsImmutableRecentSetup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("home-library-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root)
        let firstUser = UUID()
        let secondUser = UUID()
        let bag = CoffeeBag(ownerUserID: firstUser, roaster: "Sey", name: "Burundi")

        _ = try store.upsert(bag, in: .user(firstUser))
        #expect(store.load(in: .user(firstUser)).bags.map(\.id) == [bag.id])
        #expect(store.load(in: .user(secondUser)).bags.isEmpty)
        #expect(store.load(in: .guest).bags.isEmpty)

        var details = BrewDetails.empty
        details.doseGrams = 15
        let setup = HomeBrewSnapshot(
            drinkName: "Burundi",
            brewMethod: "Pour-over",
            equipment: "V60",
            brewDetails: details,
            makeAgain: .yes
        )
        _ = try store.remember(setup, in: .user(firstUser))

        var changedDetails = details
        changedDetails.doseGrams = 20
        #expect(store.load(in: .user(firstUser)).recentSetups.first?.brewDetails.doseGrams == 15)
        #expect(changedDetails.doseGrams == 20)
    }

    @Test func oldBrewDetailsDecodeWithoutHomeWorkbenchFields() throws {
        let legacy = """
        {"beans":"Colombia","doseGrams":18,"yieldGrams":36,"brewTimeSeconds":28}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BrewDetails.self, from: legacy)
        #expect(decoded.beans == "Colombia")
        #expect(decoded.coffeeBag == nil)
        #expect(decoded.equipmentSnapshots == nil)
        #expect(decoded.homeMethodDetails == nil)
    }

    @Test func homeDraftRestoresPrivateBaselineAndBagRelationship() throws {
        let bagID = UUID()
        let baseline = HomeBrewSnapshot(
            drinkName: "Baseline",
            brewMethod: "Espresso",
            equipment: "Grinder",
            brewDetails: BrewDetails(doseGrams: 18, yieldGrams: 36)
        )
        let draft = SipDraft(
            context: .home,
            drinkName: "Today",
            brewMethod: "Espresso",
            brewDetails: BrewDetails(doseGrams: 18.5, yieldGrams: 38),
            homeCoffeeBagID: bagID,
            homeComparisonSource: baseline
        )

        let restored = try JSONDecoder().decode(
            SipDraft.self,
            from: JSONEncoder().encode(draft)
        )

        #expect(restored.homeCoffeeBagID == bagID)
        #expect(restored.homeComparisonSource == baseline)
        #expect(restored.brewDetails.doseGrams == 18.5)
    }

    @Test func homeDraftRestoresItsExactWorkbenchStage() throws {
        let draft = SipDraft(
            context: .home,
            drinkName: "Shantawene Espresso",
            homeWorkbenchPhase: .actuals,
            homeRecipeDecision: .createNewVersion
        )

        let restored = try JSONDecoder().decode(
            SipDraft.self,
            from: JSONEncoder().encode(draft)
        )

        #expect(restored.homeWorkbenchPhase == .actuals)
        #expect(restored.homeRecipeDecision == .createNewVersion)
        #expect(restored.homeWorkbenchPhase.progressStep == 2)
    }

    @Test func creatingRecipeVersionPreservesTheSourceAndFreezesANewVersion() {
        let identityID = UUID()
        var sourceDetails = BrewDetails.empty
        sourceDetails.recipeIdentityID = identityID
        sourceDetails.recipeName = "Shantawene Espresso"
        sourceDetails.recipeVersion = "v3"
        sourceDetails.doseGrams = 18
        sourceDetails.yieldGrams = 40
        let source = HomeBrewSnapshot(
            drinkName: "Shantawene Espresso",
            brewMethod: "Espresso",
            equipment: "Niche Zero",
            brewDetails: sourceDetails
        )

        var currentDetails = sourceDetails
        currentDetails.sourceRecipeIdentityID = identityID
        currentDetails.sourceRecipeVersion = "v3"
        currentDetails.recipeIdentityID = nil
        currentDetails.recipeName = nil
        currentDetails.recipeVersion = nil
        currentDetails.yieldGrams = 42
        var draft = SipDraft(
            context: .home,
            drinkName: "Shantawene Espresso",
            brewMethod: "Espresso",
            brewDetails: currentDetails,
            homeMakeAgain: .yes,
            homeComparisonSource: source,
            homeRecipeDecision: .createNewVersion
        )

        draft.applyHomeRecipeDecision()

        #expect(draft.context == .recipe)
        #expect(draft.brewDetails.recipeIdentityID == identityID)
        #expect(draft.brewDetails.recipeVersion == "v4")
        #expect(draft.brewDetails.sourceRecipeVersion == "v3")
        #expect(source.brewDetails.yieldGrams == 40)
        #expect(draft.brewDetails.yieldGrams == 42)
        #expect(draft.recipePublication.visibility == .private)
    }

    @Test func keepingRecipeLeavesTheSourceVersionUnchanged() {
        let identityID = UUID()
        var details = BrewDetails.empty
        details.sourceRecipeIdentityID = identityID
        details.sourceRecipeVersion = "v3"
        details.recipeIdentityID = identityID
        details.recipeName = "Shantawene Espresso"
        details.recipeVersion = "v4"
        var draft = SipDraft(
            context: .home,
            drinkName: "Shantawene Espresso",
            brewDetails: details,
            homeRecipeDecision: .keepExisting
        )

        draft.applyHomeRecipeDecision()

        #expect(draft.context == .home)
        #expect(draft.brewDetails.recipeName == nil)
        #expect(draft.brewDetails.recipeVersion == nil)
        #expect(draft.brewDetails.recipeIdentityID == nil)
        #expect(draft.brewDetails.sourceRecipeIdentityID == identityID)
        #expect(draft.brewDetails.sourceRecipeVersion == "v3")
    }

    @Test func homeCriterionSuggestionsFollowTheSelectedMethodWithoutAddingRatings() {
        let expectations: [(HomeBrewMethod, [String])] = [
            (.espresso, ["Crema", "Extraction", "Sweetness"]),
            (.pourOver, ["Clarity", "Brightness", "Aroma"]),
            (.aeroPress, ["Balance", "Body / Smoothness", "Clarity"]),
            (.frenchPress, ["Body / Smoothness", "Texture", "Sweetness"]),
            (.mokaPot, ["Intensity", "Bitterness", "Body / Smoothness"]),
            (.coldBrew, ["Refreshment", "Strength", "Sweetness"]),
            (.batch, ["Freshness", "Balance", "Temperature"]),
            (.pod, ["Consistency", "Coffee presence", "Strength"])
        ]

        for (method, expectedTitles) in expectations {
            let draft = SipDraft(
                context: .home,
                drinkType: .coffee,
                brewMethod: method.title
            )
            let suggestions = LogASipV3CriterionSuggestion.sip(for: draft)
            #expect(Array(suggestions.prefix(3).map(\.title)) == expectedTitles)
            #expect(draft.ratingCriteria.isEmpty)
        }
    }

    @Test func remoteMergeUsesUpdatedAtAndPreservesArchiveTombstones() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("home-library-merge-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root)
        let userID = UUID()
        let id = UUID()
        _ = try store.upsert(
            CoffeeBag(id: id, ownerUserID: userID, roaster: "Local", updatedAt: .now),
            in: .user(userID)
        )
        let archived = CoffeeBag(
            id: id,
            ownerUserID: userID,
            roaster: "Remote",
            status: .archived,
            updatedAt: .now.addingTimeInterval(60)
        )

        let merged = try store.mergeRemote(
            bags: [archived],
            equipment: [],
            in: .user(userID)
        )

        #expect(merged.bags.first?.status == .archived)
        #expect(merged.currentBags.isEmpty)
    }

    @Test func guestLibraryAdoptionCopiesPhotosBeforeRemovingGuestScope() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("home-library-adopt-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeLibraryStore(baseDirectory: root)
        let userID = UUID()
        var bag = CoffeeBag(roaster: "Guest Roaster", name: "Guest Coffee")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        bag.localPhotoPath = try store.saveBagPhoto(
            renderer.image { context in UIColor.brown.setFill(); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8)) },
            bagID: bag.id,
            in: .guest
        )
        _ = try store.upsert(bag, in: .guest)

        let adopted = try store.adoptGuestLibrary(for: userID)

        #expect(adopted.bags.first?.ownerUserID == userID)
        #expect(store.load(in: .guest).bags.isEmpty)
        #expect(store.bagPhoto(relativePath: bag.localPhotoPath, in: .user(userID)) != nil)
    }
}
