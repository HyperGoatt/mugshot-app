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

    private func syrup() -> HomeRecipeRecord {
        var content = HomeRecipeContent(name: "Wildberry syrup", template: .preparation, method: .other)
        content.ingredients = [HomeRecipeIngredient(name: "Blueberries", amount: 2, unit: "cups")]
        content.steps = [HomePreparationStep(instruction: "Simmer the berries.")]
        content.yieldDescription = "One small bottle"; content.sourceText = "Original creator instructions"
        content.sourceURL = "https://example.org/syrup"; content.creatorCredit = "Recipe creator"
        return HomeRecipeRecord(versions: [HomeRecipeVersion(content: content)])
    }
}
