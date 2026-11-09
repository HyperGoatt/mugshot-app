import Foundation
import Testing
@testable import testMugshot

@MainActor
struct HomeRecipeCompositionTests {
    @Test func legacySyrupIsDiscoverableAsAComponentWithoutRewritingIt() {
        let source = HomeRecipeContent(name: "Wildberry syrup", template: .preparation, method: .other)
        #expect(HomeRecipeUse.suggested(for: source) == .component)
        #expect(source.template == .preparation)
        #expect(source.method == .other)
        #expect(HomeRecipeUse.suggested(for: HomeRecipeContent(name: "Wildberry syrup latte", template: .preparation, method: .other)) == .drink)
        #expect(HomeRecipeUse.suggested(for: HomeRecipeContent(name: "Tea idea", template: .preparation, method: .other)) == .base)
    }

    @Test func explicitRecipeKindWinsAndChangingKindPreservesTheRecipe() {
        var content = HomeRecipeContent(name: "House syrup latte", template: .component, method: .other)
        content.sourceURL = "https://example.org/recipe"; content.creatorCredit = "Recipe creator"
        content.sourceText = "Original caption"
        content.ingredients = [HomeRecipeIngredient(name: "Blueberries", amount: 2, unit: "cups")]
        content.steps = [HomePreparationStep(instruction: "Simmer gently.")]
        content.sourceReuseAllowed = false
        let before = content
        #expect(HomeRecipeUse.suggested(for: content) == .component)
        HomeRecipeUse.drink.apply(to: &content)
        #expect(content.template == .drink)
        #expect(content.ingredients == before.ingredients && content.steps == before.steps)
        #expect(content.sourceText == before.sourceText && content.sourceURL == before.sourceURL)
        #expect(content.creatorCredit == before.creatorCredit && content.sourceReuseAllowed == false)
        #expect(content.targets == before.targets)
    }

    @Test func explicitlyChosenBrewKindSurvivesAnAmbiguousNameAndRoundTrip() throws {
        var content = HomeRecipeContent(name: "Blueberry syrup", template: .preparation, method: .other)
        content.creatorCredit = "Recipe maker"
        content.steps = [HomePreparationStep(instruction: "Steep the berries.")]
        #expect(HomeRecipeUse.suggested(for: content) == .component)
        HomeRecipeUse.base.apply(to: &content)
        let restored = try JSONDecoder().decode(HomeRecipeContent.self, from: JSONEncoder().encode(content))
        #expect(HomeRecipeUse.suggested(for: restored) == .base)
        #expect(restored.methodDisplayName == "Brew recipe")
        #expect(restored.name == "Blueberry syrup" && restored.creatorCredit == "Recipe maker")
        #expect(restored.steps == content.steps)
    }

    @Test func creatingADrinkLinksTheExactComponentAndInventsNoServingAmount() throws {
        let source = syrup()
        let version = try #require(source.current)
        let drink = HomeDrinkComposition.starting(with: source)
        #expect(drink.template == .drink)
        #expect(drink.ingredients.contains { $0.name == "Milk" && $0.amount == nil })
        let linked = try #require(drink.ingredients.first { $0.recipe != nil })
        #expect(linked.recipe == HomeRecipeReference(recipeID: source.id, versionID: version.id))
        #expect(linked.amount == nil)
        #expect(linked.unit == "ml")
        #expect(drink.sourceText.isEmpty && drink.creatorCredit.isEmpty)
        #expect(!drink.steps.contains { $0.instruction == "Simmer the berries." })
    }

    @Test func addingTheSameSavedRecipeTwiceDoesNotDuplicateIt() throws {
        let source = syrup(); let version = try #require(source.current)
        var drink = HomeDrinkComposition.starting()
        HomeDrinkComposition.add(source, version: version, to: &drink)
        HomeDrinkComposition.add(source, version: version, to: &drink)
        #expect(drink.ingredients.filter { $0.recipe?.versionID == version.id }.count == 1)
        #expect(source.versions.count == 1)
    }

    @Test func replacingTheBaseKeepsTheSyrupAmountAndUsesTheSelectedBaseTargets() throws {
        let source = syrup(); let sourceVersion = try #require(source.current)
        var drink = HomeDrinkComposition.starting(with: source)
        let index = try #require(drink.ingredients.firstIndex { $0.recipe?.versionID == sourceVersion.id })
        drink.ingredients[index].amount = 15
        let base = HomeRecipeRecord(versions: [HomeRecipeVersion(content: HomeRecipeContent(
            name: "House espresso", template: .preparation, method: .espresso,
            targets: HomeRecipeTargets(dose: 19, ratio: 2.2, seconds: 30)))])
        let version = try #require(base.current)
        HomeDrinkComposition.useBase(base, version: version, in: &drink)
        #expect(drink.ingredients.first?.recipe?.versionID == version.id)
        #expect(!drink.ingredients.contains { $0.recipe == nil && $0.name == "Espresso" })
        #expect(drink.ingredients.first { $0.recipe?.versionID == sourceVersion.id }?.amount == 15)
        #expect(drink.targets.dose == 19)
        #expect(abs((drink.targets.resolvedOutput ?? 0) - 41.8) < 0.001)
        #expect(base.current?.content.targets.dose == 19)
    }

    @Test func switchingToMatchaKeepsOtherPartsAndProducesMatchaGuidance() {
        var drink = HomeDrinkComposition.starting(with: syrup())
        HomeDrinkComposition.usePreset(.traditionalMatcha, in: &drink)
        #expect(drink.method == .traditionalMatcha)
        #expect(drink.ingredients.first?.name == "Traditional matcha")
        #expect(drink.ingredients.contains { $0.name == "Milk" })
        #expect(drink.ingredients.contains { $0.recipe != nil })
        #expect(drink.asBrewDetails().homeMethodDetails?.waterGrams == drink.targets.resolvedOutput)
        #expect(drink.asBrewDetails().yieldGrams == nil)
    }

    @Test func choosingABaseForAnImportedDrinkMustNotDeleteItsFirstIngredient() {
        var drink = HomeRecipeContent(name: "Imported drink", template: .drink, method: .other)
        let milk = HomeRecipeIngredient(name: "Oat milk", amount: 150, unit: "ml")
        drink.ingredients = [milk, HomeRecipeIngredient(name: "Vanilla syrup", amount: 10, unit: "ml")]
        HomeDrinkComposition.usePreset(.traditionalMatcha, in: &drink)
        #expect(drink.ingredients.contains(milk))
        #expect(drink.ingredients.count == 3)
    }

    @Test func savingADrinkCannotChangeTheComponentBatchOrHistory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let source = syrup()
        try store.mutate { $0.recipes.append(source) }
        var drink = HomeDrinkComposition.starting(with: source); drink.name = "Afternoon latte"
        let i = try #require(drink.ingredients.firstIndex { $0.recipe != nil }); drink.ingredients[i].amount = 15
        let id = try store.saveRecipe(HomeRecipeEditorDraft(content: drink))
        #expect(store.workspace.recipes.first { $0.id == source.id } == source)
        #expect(store.workspace.recipes.first { $0.id == id }?.current?.content.ingredients[i].amount == 15)
        #expect(store.workspace.attempts.isEmpty && store.workspace.sessions.isEmpty)
        let reloaded = HomeRecipeWorkspaceStore(root: root); reloaded.activate(.guest)
        #expect(reloaded.workspace.recipes.first { $0.id == source.id } == source)
    }

    @Test func aLinkedDrinkCannotBeSavedInAnotherOwnersWorkspace() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.user(UUID()))
        let source = syrup(); try store.mutate { $0.recipes.append(source) }
        var drink = HomeDrinkComposition.starting(with: source); drink.name = "A linked latte"
        store.activate(.user(UUID()))
        do {
            _ = try store.saveRecipe(HomeRecipeEditorDraft(content: drink))
            Issue.record("A linked recipe from another owner must not be saved.")
        } catch HomeRecipeWorkspaceError.unavailableReference { }
        catch { Issue.record("Unexpected save error: \(error)") }
        #expect(store.workspace.recipes.isEmpty)
    }

    @Test func aFailedSaveLeavesTheComponentAndEditableDrinkIntact() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        let source = syrup(); try store.mutate { $0.recipes.append(source) }
        var drink = HomeDrinkComposition.starting(with: source); drink.name = "Unsaved latte"
        drink.ingredients[0].amount = -1
        let before = store.workspace
        #expect(throws: (any Error).self) { try store.saveRecipe(HomeRecipeEditorDraft(content: drink)) }
        #expect(store.workspace == before)
        #expect(drink.name == "Unsaved latte" && drink.ingredients[0].amount == -1)
    }

    @Test func choosingTheUnchangedBaseMustNotCreateANewRecipeVersion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root); store.activate(.guest)
        var content = HomeDrinkComposition.starting(); content.name = "Morning latte"
        let id = try store.saveRecipe(HomeRecipeEditorDraft(content: content))
        let version = try #require(store.workspace.recipes.first?.current)
        HomeDrinkComposition.usePreset(.espresso, in: &content)
        _ = try store.saveRecipe(HomeRecipeEditorDraft(recipeID: id, baseVersionID: version.id, content: content))
        #expect(store.workspace.recipes.first?.versions.count == 1)
    }

    @Test func reselectingTheCurrentPresetPreservesAdjustedDrinkTargets() {
        var content = HomeDrinkComposition.starting()
        content.targets.dose = 21; content.targets.seconds = 32
        let before = content
        HomeDrinkComposition.usePreset(.espresso, in: &content)
        #expect(content == before)
    }

    @Test func reselectingTheSavedBasePreservesTheDrinksOwnOverrides() throws {
        let base = HomeRecipeRecord(versions: [HomeRecipeVersion(content: HomeRecipeContent(
            name: "House espresso", template: .preparation, method: .espresso,
            targets: HomeRecipeTargets(dose: 19, ratio: 2.1, seconds: 29)))])
        let version = try #require(base.current)
        var content = HomeDrinkComposition.starting()
        HomeDrinkComposition.useBase(base, version: version, in: &content)
        content.targets.dose = 21
        let before = content
        HomeDrinkComposition.useBase(base, version: version, in: &content)
        #expect(content == before)
    }

    @Test func replacingALinkedBaseFindsItBehindOtherIngredients() throws {
        let base = HomeRecipeContent(name: "Saved espresso", template: .preparation, method: .espresso)
        let reference = HomeRecipeReference(recipeID: UUID(), versionID: UUID())
        let milk = HomeRecipeIngredient(name: "Oat milk", amount: 100, unit: "ml")
        let linked = HomeRecipeIngredient(name: base.name, amount: 2, unit: "serving", recipe: reference)
        var drink = HomeRecipeContent(name: "Imported latte", template: .drink, method: .completeDrink)
        drink.ingredients = [milk, linked]
        let oldBaseID = HomeDrinkComposition.baseID(in: drink) { $0 == reference ? base : nil }
        #expect(oldBaseID == linked.id)
        HomeDrinkComposition.usePreset(.traditionalMatcha, in: &drink, replacing: oldBaseID)
        #expect(drink.ingredients.contains(milk))
        let replacement = try #require(drink.ingredients.first { $0.id == linked.id })
        #expect(replacement.name == "Traditional matcha" && replacement.recipe == nil)
        #expect(replacement.amount == 2 && replacement.unit == "serving")
    }

    @Test func presetMatchaGuidanceKeepsItsMethodAndDoesNotDuplicateAssembly() {
        var content = HomeDrinkComposition.starting()
        HomeDrinkComposition.usePreset(.traditionalMatcha, in: &content)
        let guide = HomeDrinkComposition.guidance(for: content)
        #expect(guide.base.method == .traditionalMatcha)
        #expect(guide.steps == content.visibleSteps)
        #expect(!guide.usesSavedBase)
    }

    @Test func guidancePrependsTheSavedBaseOnceAndKeepsParentTargets() throws {
        var base = HomeRecipeContent(name: "House brew", template: .preparation, method: .espresso,
                                     targets: HomeRecipeTargets(dose: 19, ratio: 2, seconds: 28))
        base.steps = [HomePreparationStep(instruction: "Prepare the saved base.")]
        let record = HomeRecipeRecord(versions: [HomeRecipeVersion(content: base)])
        let version = try #require(record.current)
        var content = HomeDrinkComposition.starting(with: record); content.targets.dose = 21
        let guide = HomeDrinkComposition.guidance(for: content) { $0.versionID == version.id ? base : nil }
        #expect(guide.base.targets.dose == 21 && base.targets.dose == 19)
        #expect(guide.steps == base.visibleSteps + content.visibleSteps)
        #expect(guide.usesSavedBase)
    }

    @Test func genericLegacyDrinkKeepsEspressoFallbackWithoutRepeatingSteps() {
        var content = HomeRecipeContent(name: "Legacy latte", template: .drink, method: .completeDrink,
                                        targets: HomeRecipeTargets(dose: 18, ratio: 2))
        content.steps = [HomePreparationStep(instruction: "Put this drink together.")]
        let guide = HomeDrinkComposition.guidance(for: content)
        #expect(guide.base.method == .espresso)
        #expect(guide.steps == content.visibleSteps && !guide.usesSavedBase)
        content.method = .other; content.targets = HomeRecipeTargets()
        #expect(HomeDrinkComposition.guidance(for: content).base.method == .other)
    }

    @Test func anIngredientListIsAnIdeaUntilInstructionsAreUsable() {
        var idea = HomeRecipeContent(name: "Jasmine tea", template: .preparation, method: .other)
        idea.ingredients = [HomeRecipeIngredient(name: "Tea", amount: 2, unit: "g")]
        idea.steps = [HomePreparationStep(instruction: "  "), HomePreparationStep(instruction: "Steep.", isHidden: true)]
        #expect(!idea.isReadyToMake)
        idea.steps.append(HomePreparationStep(instruction: "Steep the leaves for three minutes."))
        #expect(idea.isReadyToMake)

        let brew = HomeRecipeContent(name: "House espresso", template: .preparation, method: .espresso,
                                     targets: HomeRecipeTargets(dose: 18, ratio: 2))
        #expect(brew.isReadyToMake)
    }

    @Test func switchingAnAddInPreservesItsUsageAndBothSavedRecipes() throws {
        let first = syrup()
        let old = try #require(first.current)
        var replacementContent = old.content
        replacementContent.name = "Cinnamon syrup"
        replacementContent.creatorCredit = "Another creator"
        replacementContent.sourceURL = "https://example.org/cinnamon"
        let second = HomeRecipeRecord(versions: [HomeRecipeVersion(number: 2, content: replacementContent)])
        let new = try #require(second.current)
        var drink = HomeDrinkComposition.starting(with: first)
        let index = try #require(drink.ingredients.firstIndex { $0.recipe?.versionID == old.id })
        drink.ingredients[index].amount = 0.75
        drink.ingredients[index].unit = "tbsp"
        let id = drink.ingredients[index].id
        #expect(HomeDrinkComposition.replacePart(id: id, with: second, version: new, in: &drink))
        #expect(drink.ingredients[index].id == id && drink.ingredients[index].amount == 0.75)
        #expect(drink.ingredients[index].unit == "tbsp" && drink.ingredients[index].name == "Cinnamon syrup")
        #expect(drink.ingredients[index].recipe == HomeRecipeReference(recipeID: second.id, versionID: new.id))
        #expect(first.current == old && second.current == new)
        #expect(drink.creatorCredit.isEmpty && drink.sourceURL.isEmpty)
        let switched = drink
        #expect(!HomeDrinkComposition.replacePart(id: id, with: second, version: new, in: &drink))
        #expect(drink == switched)

        HomeDrinkComposition.add(first, version: old, to: &drink)
        let withBoth = drink
        #expect(!HomeDrinkComposition.replacePart(id: id, with: first, version: old, in: &drink))
        #expect(drink == withBoth, "Selecting a link already present cannot merge or duplicate measured parts.")
    }

    @Test func scalingPortionsUsesExactUnitsAndLeavesSourceAndBrewInstructionsAlone() throws {
        let source = syrup()
        var drink = HomeDrinkComposition.starting(with: source)
        let index = try #require(drink.ingredients.firstIndex { $0.recipe != nil })
        drink.ingredients[index].amount = 1.25
        drink.ingredients[index].unit = "tsp"
        let original = drink
        let scaled = try #require(HomeDrinkComposition.scaled(drink, toServings: 2))
        #expect(scaled.servings == 2 && scaled.ingredients[index].amount == 2.5)
        #expect(scaled.ingredients[index].unit == "tsp" && scaled.ingredients[index].recipe == original.ingredients[index].recipe)
        #expect(scaled.ingredients.first(where: { $0.name == "Milk" })?.amount == nil)
        #expect(scaled.targets == original.targets && scaled.steps == original.steps)
        #expect(drink == original && source.current?.content.ingredients.first?.amount == 2)
        #expect(HomeDrinkComposition.scaled(drink, toServings: .infinity) == nil)
        #expect(HomeDrinkComposition.scaled(drink, toServings: 0) == nil)
    }

    private func syrup() -> HomeRecipeRecord {
        var content = HomeRecipeContent(name: "Wildberry syrup", template: .preparation, method: .other)
        content.ingredients = [HomeRecipeIngredient(name: "Blueberries", amount: 2, unit: "cups")]
        content.steps = [HomePreparationStep(instruction: "Simmer the berries.")]
        content.yieldDescription = "One small bottle"; content.sourceText = "Original creator instructions"
        content.sourceURL = "https://example.org/syrup"; content.creatorCredit = "Recipe creator"
        return HomeRecipeRecord(versions: [HomeRecipeVersion(content: content)])
    }
}
