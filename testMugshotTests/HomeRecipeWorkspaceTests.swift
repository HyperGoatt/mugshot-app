import Foundation
import Testing
@testable import testMugshot

@MainActor
struct HomeRecipeWorkspaceTests {
    private func espresso() -> HomeRecipeContent {
        var content = HomeRecipeContent(name: "Morning espresso", template: .coffee, method: .espresso)
        content.targets = HomeRecipeTargets(dose: 18, ratio: 2, seconds: 28)
        return content
    }

    @Test func calculationsKeepUnknownActualsUnknown() {
        var content = espresso()
        #expect(content.targets.resolvedOutput == 36)
        content.targets.calculation = .output
        content.targets.output = 45
        #expect(content.targets.resolvedRatio == 2.5)
        let attempt = HomeAttemptRecord.fresh(from: HomeRecipeRecord(versions: [HomeRecipeVersion(content: content)]))
        #expect(attempt.actuals.dose == nil)
        #expect(attempt.actuals.output == nil)
        #expect(attempt.actuals.seconds == nil)
        #expect(attempt.rating == nil)
        content.targets.dose = 0
        #expect(content.validationMessage != nil)
        #expect(content.targets.resolvedRatio == nil)
    }

    @Test func scalingAndMixedPourStepsPreserveNonQuantitySettings() {
        var content = espresso()
        content.targets.temperature = 94
        content.targets.grind = "12"
        content.targets.pressure = 9
        content.targets.steepSeconds = 57_600
        content.steps = [HomePreparationStep(instruction: "Bloom", waitSeconds: 40, waterGrams: 60),
                         HomePreparationStep(instruction: "Pour", waterGrams: 120, waterMode: .incremental),
                         HomePreparationStep(instruction: "Finish", startSeconds: 80, waterGrams: 300)]
        #expect(content.cumulativeWater(through: 1) == 180)
        #expect(content.cumulativeWater(through: 2) == 300)
        let scaled = content.scaled(by: 2)
        #expect(scaled.targets.resolvedOutput == 72)
        #expect(scaled.cumulativeWater(through: 2) == 600)
        #expect(scaled.steps[0].waitSeconds == 40)
        #expect(scaled.targets.temperature == 94)
        #expect(scaled.targets.grind == "12")
        #expect(scaled.targets.pressure == 9)
        #expect(scaled.targets.steepSeconds == 57_600)
    }

    @Test func sourceOnlyAndArbitraryFieldsAreValid() {
        var content = HomeRecipeContent(name: "An idea", sourceURL: "https://example.invalid/inspiration")
        #expect(content.validationMessage == nil)
        #expect(!content.isActionable)
        content.fields = [HomeCustomField(label: "Whisk speed", kind: .choice, value: "Slow", choices: ["Slow", "Fast"]),
                          HomeCustomField(label: "Rest", kind: .duration, value: "30")]
        #expect(content.validationMessage == nil)
        content.fields[1].value = "not a duration"
        #expect(content.validationMessage != nil)
    }

    @Test func versionedAttemptsDraftsAndAccountIsolationSurviveReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root)
        let owner = UUID()
        store.activate(.user(owner))
        let id = try store.saveRecipe(HomeRecipeEditorDraft(content: espresso()))
        let recipe = try #require(store.workspace.recipes.first)
        var attempt = HomeAttemptRecord.fresh(from: recipe)
        attempt.actuals.output = 39
        attempt.privateNote = "Only for me"
        attempt.nextTimeNote = "Try a shorter shot"
        attempt.rating = 4.5
        try store.saveAttemptDraft(attempt)
        let reopened = HomeRecipeWorkspaceStore(root: root)
        reopened.activate(.user(owner))
        #expect(reopened.workspace.attemptDrafts.first == attempt)
        try reopened.saveAttempt(attempt)
        try reopened.saveAttempt(attempt)
        #expect(reopened.workspace.attempts.count == 1)
        #expect(reopened.workspace.recipes[0].versions.count == 1)
        var updated = espresso()
        updated.targets.ratio = 2.2
        _ = try reopened.saveRecipe(HomeRecipeEditorDraft(recipeID: id, baseVersionID: recipe.current?.id, content: updated))
        #expect(reopened.workspace.recipes[0].versions.count == 2)
        #expect(reopened.workspace.attempts[0].targets?.targets.resolvedOutput == 36)
        let repeatAttempt = HomeAttemptRecord.fresh(from: reopened.workspace.recipes[0])
        #expect(repeatAttempt.rating == nil && repeatAttempt.privateNote.isEmpty && repeatAttempt.photoNames.isEmpty)
        #expect(repeatAttempt.actuals == HomeAttemptActuals())
        #expect(repeatAttempt.recipe?.versionID == reopened.workspace.recipes[0].current?.id)
        reopened.activate(.user(UUID()))
        #expect(reopened.workspace.recipes.isEmpty && reopened.workspace.attempts.isEmpty)
        reopened.activate(.user(owner))
        #expect(reopened.workspace.attempts.first?.privateNote == "Only for me")
    }

    @Test func unchangedSaveCreatesNoVersionAndStaleEditPreservesDraft() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root)
        store.activate(.guest)
        let id = try store.saveRecipe(HomeRecipeEditorDraft(content: espresso()))
        let current = try #require(store.workspace.recipes[0].current)
        let unchanged = HomeRecipeEditorDraft(recipeID: id, baseVersionID: current.id, content: current.content)
        _ = try store.saveRecipe(unchanged)
        #expect(store.workspace.recipes[0].versions.count == 1)
        var changed = unchanged
        changed.content.targets.ratio = 3
        _ = try store.saveRecipe(changed)
        try store.saveDraft(unchanged)
        #expect(throws: (any Error).self) { try store.saveRecipe(unchanged) }
        #expect(store.workspace.recipeDrafts.contains { $0.id == unchanged.id })
    }

    @Test func linkedCyclesAreRejectedAndAdoptionIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root)
        store.activate(.guest)
        let id = try store.saveRecipe(HomeRecipeEditorDraft(content: espresso()))
        let current = try #require(store.workspace.recipes[0].current)
        var cyclic = current.content
        cyclic.ingredients.append(HomeRecipeIngredient(name: "Self", recipe: HomeRecipeReference(recipeID: id, versionID: current.id)))
        #expect(throws: (any Error).self) { try store.saveRecipe(HomeRecipeEditorDraft(recipeID: id, baseVersionID: current.id, content: cyclic)) }
        let owner = UUID()
        try store.adoptGuestWorkspace(for: owner)
        try store.adoptGuestWorkspace(for: owner)
        #expect(store.scope == .user(owner))
        #expect(store.workspace.recipes.count == 1)
        store.activate(.guest)
        #expect(store.workspace.recipes.isEmpty)
    }
}
