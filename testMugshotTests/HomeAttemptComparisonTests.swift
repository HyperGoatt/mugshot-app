import Foundation
import Testing
@testable import testMugshot

struct HomeAttemptComparisonTests {
    @Test func onlyTheLastCompatibleSavedBrewSuppliesRecordedActuals() {
        let version = HomeRecipeReference(recipeID: UUID(), versionID: UUID())
        let current = brew(version, time: 30, dose: nil, output: 39)
        let earlier = brew(version, time: 10, dose: 18, output: 36)
        let laterDraft = brew(version, time: 25, dose: 80, output: 90, saved: false)
        let otherVersion = brew(HomeRecipeReference(recipeID: version.recipeID, versionID: UUID()),
                                time: 24, dose: 99, output: 99)
        var otherMethod = brew(version, time: 20, dose: 90, output: 90)
        otherMethod.preparation?.method = .pourOver

        let comparison = HomeAttemptComparison(current, history: [otherVersion, laterDraft, otherMethod, earlier, current])
        let dose = comparison.rows.first { $0.key == .dose }
        #expect(dose?.planned?.amount == 18)
        #expect(dose?.actual == nil)
        #expect(dose?.last?.amount == 18)
        let output = comparison.rows.first { $0.key == .output }
        #expect(output?.actual?.amount == 39)
        #expect(output?.last?.amount == 36)
        #expect(output?.last?.unit == "g")
        #expect(comparison.priorDate == earlier.savedAt)
        #expect(comparison.rows.first { $0.key == .ratio }?.actual == nil)
    }

    @Test func ingredientReadingsKeepTheirUnitsAndDoNotCompareDifferentPartsOrUnits() {
        let version = HomeRecipeReference(recipeID: UUID(), versionID: UUID())
        let part = HomeRecipeIngredient(name: "Blueberry syrup", amount: 15, unit: "ml",
                                        recipe: HomeRecipeReference(recipeID: UUID(), versionID: UUID()))
        var current = brew(version, time: 20, dose: nil, output: nil)
        current.preparation?.ingredients = [part]
        current.actuals.ingredients = [HomeIngredientActual(ingredientID: part.id, amount: 17, unit: "g")]
        var prior = brew(version, time: 10, dose: nil, output: nil)
        prior.preparation?.ingredients = [part]
        prior.actuals.ingredients = [HomeIngredientActual(ingredientID: part.id, amount: 12, unit: "ml")]

        let row = HomeAttemptComparison(current, history: [prior]).rows.first { $0.key == .ingredient(part.id) }
        #expect(row?.planned?.unit == "ml")
        #expect(row?.actual?.unit == "g")
        #expect(row?.last == nil)

        current.actuals.ingredients = []
        prior.preparation?.ingredients[0].recipe?.versionID = UUID()
        #expect(HomeAttemptComparison(current, history: [prior]).rows.first { $0.key == .ingredient(part.id) }?.last == nil)
    }

    @Test func repeatDraftPreservesTheVersionAndChangesOnlyTheSelectedTarget() throws {
        let version = HomeRecipeReference(recipeID: UUID(), versionID: UUID())
        var current = brew(version, time: 30, dose: 18, output: 38)
        current.locationName = "Brew bench"
        current.privateNote = "Keep this in the old sip"
        current.photoNames = ["old-photo.jpg"]
        current.rating = 4
        let change = HomeBrewPlanChange(key: .dose, expected: 18, amount: 19)
        let next = try #require(HomeBrewRepeat.draft(for: current, ownerID: nil, versionNumber: 2, change: change))
        #expect(next.id != current.id)
        #expect(next.launchContext.homeRecipeVersionID == version.versionID)
        #expect(next.launchContext.sourceRecipeVersion == "v2")
        #expect(next.locationName == "Brew bench")
        #expect(next.homeSetupContent?.targets.dose == 19)
        #expect(next.homeSetupContent?.targets.resolvedOutput == 36)
        #expect(next.homeSetupContent?.targets.seconds == 28)
        #expect(next.homeAttemptActuals == HomeAttemptActuals())
        #expect(next.localPhotoNames.isEmpty && next.privateNotes.isEmpty && next.overallScore == 0)
        #expect(next.visibility == .private)
        #expect(current.preparation?.targets.dose == 18)
        #expect(HomeBrewRepeat.draft(for: current, ownerID: nil, change: .init(key: .dose, expected: 17, amount: 19)) == nil)
        #expect(HomeBrewRepeat.draft(for: current, ownerID: nil, change: .init(key: .dose, expected: 18, amount: .infinity)) == nil)
    }

    @Test func aServingNeverComparesWithOrRepeatsAsItsWholeBatch() throws {
        var batch = brew(nil, time: 1, dose: 40, output: 500)
        batch.name = "Cold brew"
        batch.preparation?.method = .coldBrew
        var serving = batch
        serving.id = UUID()
        serving.createdAt = Date(timeIntervalSince1970: 5)
        serving.savedAt = serving.createdAt
        serving.batchSourceAttemptID = batch.id
        serving.actuals = HomeAttemptActuals(servingMilliliters: 150)
        let comparison = HomeAttemptComparison(serving, history: [batch])
        #expect(comparison.rows.map(\.key) == [.serving])
        #expect(comparison.priorDate == nil)
        let repeatDraft = try #require(HomeBrewRepeat.draft(for: serving, ownerID: nil))
        #expect(repeatDraft.homeWorkbenchPhase == .quickCapture)
        #expect(repeatDraft.homeSetupContent == nil)
        #expect(repeatDraft.launchContext.homeBatchSourceAttemptID == batch.id)
    }

    @Test func repeatingATeaKeepsWaterAndDoesNotContradictItsWrittenTimer() throws {
        var tea = brew(nil, time: 10, dose: nil, output: nil)
        tea.name = "Black tea"
        tea.preparation = HomeRecipeContent(name: tea.name, template: .drink, method: .westernTea,
            targets: HomeRecipeTargets(output: 250, calculation: .output, steepSeconds: 180),
            steps: [HomePreparationStep(instruction: "Steep for three minutes.", waitSeconds: 180)])

        let comparison = HomeAttemptComparison(tea, history: [])
        #expect(comparison.rows.first { $0.key == .duration }?.planned?.amount == 180)
        #expect(!comparison.changes.contains { $0.key == .duration })
        #expect(HomeBrewRepeat.draft(for: tea, ownerID: nil, change: .init(key: .duration, expected: 180, amount: 240)) == nil)
        let next = try #require(HomeBrewRepeat.draft(for: tea, ownerID: nil))
        #expect(next.brewDetails.homeMethodDetails?.waterGrams == 250)
        #expect(next.brewDetails.yieldGrams == nil)
        #expect(next.homeSetupContent?.steps.first?.waitSeconds == 180)
    }

    @Test func sparseLatteGetsAnExperimentWithoutInventingMeasurements() throws {
        let sip = HomeAttemptRecord(name: "S’mores latte")
        let ideas = HomeBrewExperiment.suggestions(for: sip, comparison: HomeAttemptComparison(sip, history: []))
        let first = try #require(ideas.first)
        #expect(first.plan.title == "Find the sweetness you like")
        #expect(first.plan.instruction.contains("If you use syrup"))
        #expect(ideas.count > 1)
        #expect(ideas.allSatisfy { $0.measurement == nil && $0.change == nil })
    }

    @Test func experimentReturnsToAPlannedAmountWhenTheRecordedAmountDiffers() throws {
        let sip = brew(nil, time: 10, dose: 20, output: nil)
        let idea = try #require(HomeBrewExperiment.suggestions(for: sip,
            comparison: HomeAttemptComparison(sip, history: [])).first)
        #expect(idea.measurement?.isRecorded == true)
        #expect(idea.measurement?.before == "20 g")
        #expect(idea.measurement?.next == "18 g")
        #expect(idea.change == nil)
    }

    @Test func experimentDraftPersistsOneTargetAndItsInstruction() throws {
        let sip = brew(nil, time: 10, dose: 18, output: nil)
        let idea = try #require(HomeBrewExperiment.suggestions(for: sip,
            comparison: HomeAttemptComparison(sip, history: [])).first)
        let draft = try #require(HomeBrewRepeat.draft(for: sip, ownerID: UUID(),
            change: idea.change, experiment: idea.plan))
        let restored = try JSONDecoder().decode(SipDraft.self, from: JSONEncoder().encode(draft))
        #expect(idea.change?.key == .dose)
        #expect(restored.launchContext.homeBrewExperiment == idea.plan)
        #expect(restored.homeSetupContent?.targets.dose == 16.2)
        #expect(restored.homeSetupContent?.targets.resolvedOutput == 36)
        #expect(restored.homeAttemptActuals == HomeAttemptActuals())
        #expect(restored.visibility == .private)
        #expect(sip.preparation?.targets.dose == 18)
    }

    private func brew(_ recipe: HomeRecipeReference?, time: Double, dose: Double?, output: Double?, saved: Bool = true) -> HomeAttemptRecord {
        let date = Date(timeIntervalSince1970: time)
        var attempt = HomeAttemptRecord(createdAt: date, name: "Morning espresso", recipe: recipe,
            preparation: HomeRecipeContent(name: "Morning espresso", template: .preparation,
                                           method: .espresso, targets: HomeRecipeContent.defaultTargets(for: .espresso)))
        attempt.savedAt = saved ? date : nil
        attempt.actuals.dose = dose
        attempt.actuals.output = output
        return attempt
    }
}
