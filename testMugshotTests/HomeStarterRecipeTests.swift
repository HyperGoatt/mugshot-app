import Foundation
import Testing
@testable import testMugshot

@MainActor
struct HomeStarterRecipeTests {
    @Test func eachStarterHasEnoughLocalInstructionsToMakeTheDrink() throws {
        let recipes = HomeStarterRecipes.all.map(\.content)
        #expect(Set(recipes.map(\.method.family)) == Set([.coffee, .tea, .matcha]))
        for content in recipes {
            #expect(content.validationMessage == nil)
            #expect(!content.ingredients.isEmpty)
            #expect(content.visibleSteps.count >= 2)
            #expect(content.ingredients.allSatisfy { $0.recipe == nil })
            #expect(content.sourceURL.isEmpty)
        }
        let tea = try #require(recipes.first { $0.method.family == .tea })
        #expect(tea.visibleSteps.contains { $0.waitSeconds == 180 })
    }

    @Test func starterDraftKeepsItsPlanAcrossRelaunchWithNoMeasuredValues() throws {
        let content = try #require(HomeStarterRecipes.all.first?.content)
        let owner = UUID()
        let draft = HomeStarterRecipes.draft(for: content, ownerID: owner)
        let restored = try JSONDecoder().decode(SipDraft.self, from: JSONEncoder().encode(draft))
        #expect(restored.ownerUserID == owner)
        #expect(restored.context == .home)
        #expect(restored.homeWorkbenchPhase == .workbench && restored.homeSipPath == .guided)
        #expect(restored.homeSetupContent == content)
        #expect(restored.launchContext.sourceRecipeIdentityID == nil)
        #expect(restored.launchContext.homeRecipeVersionID == nil)
        #expect(restored.homeAttemptActuals == HomeAttemptActuals())
        #expect(restored.homeCoffeeBagID == nil)
    }

    @Test func defaultNicknameOnlyAppliesToFreshBlankHomeWork() {
        let owner = UUID()
        let profile = HomePlaceProfile(ownerUserID: owner, name: "Brew bench")
        var shelf = HomeLibrarySnapshot.empty
        shelf.preferences = HomeLibraryPreferences(homeProfiles: [profile], defaultHomeProfileID: profile.id)
        var fresh = SipDraft(ownerUserID: owner, context: .home, locationName: "Home")
        HomeBrewSetup.applyDefaultLocation(to: &fresh, from: shelf, isStoredDraft: false)
        #expect(fresh.locationName == "Brew bench")
        #expect(!fresh.hasDraftWorthyUserContent)

        var resumed = SipDraft(ownerUserID: owner, context: .home, locationName: "Home")
        HomeBrewSetup.applyDefaultLocation(to: &resumed, from: shelf, isStoredDraft: true)
        #expect(resumed.locationName == "Home")
        resumed.locationName = "Weekend kitchen"
        HomeBrewSetup.applyDefaultLocation(to: &resumed, from: shelf, isStoredDraft: false)
        #expect(resumed.locationName == "Weekend kitchen")
        var other = SipDraft(ownerUserID: UUID(), context: .home, locationName: "Home")
        HomeBrewSetup.applyDefaultLocation(to: &other, from: shelf, isStoredDraft: false)
        #expect(other.locationName == "Home")
    }

    @Test func selectingAnOlderRecipeUsesItsExactVersionAndKeepsTheQuickSipEvidence() {
        let owner = UUID()
        let first = HomeRecipeVersion(number: 1, content: HomeRecipeContent(
            name: "House espresso", template: .preparation, method: .espresso,
            targets: HomeRecipeTargets(dose: 18, ratio: 2),
            steps: [HomePreparationStep(instruction: "Pull a double shot.")],
            coffee: CoffeeBagSnapshot(roaster: "House", name: "Original beans")))
        let newest = HomeRecipeVersion(number: 2, content: HomeRecipeContent(
            name: "House espresso", template: .preparation, method: .espresso,
            targets: HomeRecipeTargets(dose: 20, ratio: 2.3)))
        let recipe = HomeRecipeRecord(versions: [first, newest])
        var draft = SipDraft(ownerUserID: owner, context: .home, locationName: "Brew bench",
                             drinkName: "My morning espresso", homeWorkbenchPhase: .quickCapture)
        draft.homeAttemptActuals.dose = 17.5
        HomeBrewSetup.applySavedRecipe(recipe, version: first, to: &draft, shelf: .empty, path: .quick)

        #expect(draft.homeSipPath == .quick && draft.homeWorkbenchPhase == .quickCapture)
        #expect(draft.drinkName == "My morning espresso" && draft.locationName == "Brew bench")
        #expect(draft.homeAttemptActuals.dose == 17.5)
        #expect(draft.launchContext.sourceRecipeIdentityID == recipe.id)
        #expect(draft.launchContext.homeRecipeVersionID == first.id)
        #expect(draft.launchContext.sourceRecipeVersion == "v1")
        #expect(draft.homeSetupContent == first.content)
        #expect(draft.brewDetails.coffeeBag == first.content.coffee)
        #expect(recipe.current?.id == newest.id)
    }

    @Test func makingASavedIdeaCanUseAStepForTodayWhileQuickLogNeedsNoInstructions() throws {
        let idea = HomeRecipeContent(
            name: "Berry latte idea", template: .drink, method: .completeDrink,
            ingredients: [HomeRecipeIngredient(name: "Blueberry syrup", amount: 15, unit: "ml")]
        )
        let version = HomeRecipeVersion(content: idea)
        let recipe = HomeRecipeRecord(versions: [version])
        var draft = SipDraft(context: .home, drinkName: "My berry latte", homeWorkbenchPhase: .quickCapture)
        HomeBrewSetup.applySavedRecipe(recipe, version: version, to: &draft, shelf: .empty, path: .quick)
        #expect(draft.homeSipPath == .quick && draft.drinkName == "My berry latte")
        #expect(draft.homeSetupContent?.isReadyToMake == false)

        HomeBrewSetup.applySavedRecipe(recipe, version: version, to: &draft, shelf: .empty, path: .guided)
        let originalPlan = try #require(draft.homeSetupContent)
        HomeBrewSetup.updateFirstInstruction("Stir the syrup into the latte.", in: &draft, plan: originalPlan)
        #expect(draft.homeSetupContent?.isReadyToMake == true)
        #expect(draft.homeSetupContent?.visibleSteps.first?.instruction == "Stir the syrup into the latte.")
        #expect(draft.launchContext.homeRecipeVersionID == version.id)
        #expect(recipe.current?.content == idea)
    }

    @Test func decimalDisplayDoesNotRoundAnUntouchedTarget() {
        let locale = Locale(identifier: "en_US")
        let stored = 1_234.567_891
        let display = HomeSetupNumbers.display(stored, locale: locale)
        #expect(display == "1,234.57")
        #expect(HomeSetupNumbers.edit(display, replacing: display, locale: locale) == .unchanged)
    }

    @Test func numericEditsAcceptLocalizedDecimalsAndRequireACompleteBoundedValue() {
        let french = Locale(identifier: "fr_FR")
        #expect(HomeSetupNumbers.edit("1\u{202F}234,56789", replacing: "", locale: french) == .set(1_234.567_89))
        #expect(HomeSetupNumbers.edit("-5,25", replacing: "", locale: french,
                                     allowed: HomeSetupNumbers.temperatureRange) == .set(-5.25))
        let english = Locale(identifier: "en_US")
        for invalid in ["12g", "1,23", "5.5.6", "NaN", "∞", "1e200", "-3"] {
            #expect(HomeSetupNumbers.edit(invalid, replacing: "4", locale: english) == .unchanged)
        }
        #expect(HomeSetupNumbers.edit("", replacing: "4", locale: english) == .clear)
    }

    @Test func changingDoseRetainsTheExactRatioAndClearsAndRestoresYield() throws {
        let ratio = 2.123_456_789
        let plan = HomeRecipeTargets(dose: 18, ratio: ratio, output: 18 * ratio, seconds: 27.375)
        let cleared = try #require(HomeSetupNumbers.ratioTargets(plan, dose: nil, ratio: ratio))
        #expect(cleared.dose == nil && cleared.output == nil && cleared.resolvedOutput == nil)
        #expect(cleared.ratio == ratio && cleared.seconds == plan.seconds)
        let restored = try #require(HomeSetupNumbers.ratioTargets(cleared, dose: 19, ratio: cleared.ratio))
        #expect(restored.output == 19 * ratio && restored.ratio == ratio)
        #expect(HomeSetupNumbers.ratioTargets(plan, dose: 1_000_000, ratio: ratio) == nil)

        var latte = HomeRecipeContent(name: "Latte", template: .drink, method: .completeDrink, targets: cleared)
        #expect(HomeDrinkComposition.guidance(for: latte).base.method == .espresso)
        #expect(latte.asBrewDetails().yieldGrams == nil)
        latte.targets = restored
        #expect(latte.asBrewDetails().yieldGrams == 19 * ratio)
        #expect(latte.asBrewDetails().homeMethodDetails?.waterGrams == nil)

        let tea = HomeRecipeContent(name: "Tea", template: .preparation, method: .westernTea,
                                    targets: HomeRecipeTargets(output: 240, calculation: .output))
        #expect(tea.asBrewDetails().yieldGrams == nil)
        #expect(tea.asBrewDetails().homeMethodDetails?.waterGrams == 240)
    }

    @Test func timerProjectionKeepsExactRecipeTargetsAndRejectsUnsafeSavedValues() {
        var recipe = HomeRecipeContent(name: "Cold brew", template: .preparation, method: .coldBrew,
            targets: HomeRecipeTargets(seconds: 25.625, preinfusion: 4.125, steepSeconds: 43_200.75),
            steps: [HomePreparationStep(instruction: "Steep.", waitSeconds: 60.75)])
        let exactTargets = recipe.targets
        let details = recipe.asBrewDetails()
        #expect(details.brewTimeSeconds == 26)
        #expect(details.homeMethodDetails?.preinfusionSeconds == 4)
        #expect(details.homeMethodDetails?.steepSeconds == 43_201)
        #expect(details.homeMethodDetails?.coldBrewSteepHours == 43_200.75 / 3_600)
        #expect(details.steps?.first?.durationSeconds == 61)
        #expect(recipe.targets == exactTargets && recipe.steps.first?.waitSeconds == 60.75)

        recipe.targets.seconds = .infinity
        recipe.targets.preinfusion = .nan
        recipe.targets.steepSeconds = 1e100
        recipe.steps[0].waitSeconds = -1
        let unsafe = recipe.asBrewDetails()
        #expect(unsafe.brewTimeSeconds == nil)
        #expect(unsafe.homeMethodDetails?.preinfusionSeconds == nil)
        #expect(unsafe.homeMethodDetails?.steepSeconds == nil)
        #expect(unsafe.homeMethodDetails?.coldBrewSteepHours == nil)
        #expect(unsafe.steps?.first?.durationSeconds == nil)
    }
}
