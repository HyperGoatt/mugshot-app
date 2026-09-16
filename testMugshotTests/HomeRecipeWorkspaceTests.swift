import Foundation
import Testing
import UIKit
@testable import testMugshot

@MainActor
struct HomeRecipeWorkspaceTests {
    @Test func unratedHomePublicationDoesNotInventARequiredScore() throws {
        func payload(_ context: JournalEntryContext, _ score: Double) throws -> SupabaseVisitInsert {
            try SupabaseVisitInsert.make(userId: UUID(), remoteCafe: nil, entryContext: context,
                drinkType: .coffee, customDrinkType: nil, drinkSubtype: "Home make", caption: "My make",
                notes: nil, visibility: .friends, ratings: [:], overallScore: score,
                ratingTemplate: RatingTemplate(categories: []))
        }
        #expect(try payload(.home, 0).overallScore == 0)
        #expect(throws: (any Error).self) { try payload(.cafe, 0) }
        #expect(throws: (any Error).self) { try payload(.elsewhere, 0) }
        #expect(throws: (any Error).self) { try payload(.home, -1) }
    }
    @Test func justThisTimeChangesStillRequireValidPreparation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root)
        store.activate(.guest)
        var content = espresso()
        content.targets.ratio = -2
        let attempt = HomeAttemptRecord(name: "Invalid variation", preparation: content)
        #expect(throws: (any Error).self) { try store.saveAttempt(attempt) }
        #expect(store.workspace.attempts.isEmpty)
    }
    @Test func variationTargetsRemainDistinctFromOriginalAndActuals() {
        let original = espresso()
        var attempt = HomeAttemptRecord(targets: original, preparation: original)
        attempt.preparation?.targets.ratio = 2.1
        #expect(abs((attempt.plannedTargets?.resolvedOutput ?? 0) - 37.8) < 0.0001)
        #expect(attempt.targets?.targets.resolvedOutput == 36)
        #expect(attempt.actuals.output == nil)
    }

    @Test func conflictingAttemptDraftRecoveryIsIdempotentAndSurvivesRemoteSave() {
        var local = HomeRecipeWorkspace(), remote = HomeRecipeWorkspace()
        let draft = HomeAttemptRecord(name: "Local unfinished make", privateNote: "Keep my edit")
        local.attemptDrafts = [draft]
        var saved = draft
        saved.privateNote = "Other device"
        saved.savedAt = Date()
        remote.attempts = [saved]
        let merged = remote.reconciling(local: local)
        #expect(merged.attempts == [saved])
        #expect(merged.attemptDrafts.count == 1)
        #expect(merged.attemptDrafts.first?.privateNote == draft.privateNote)
        #expect(merged.attemptDrafts.first?.id != draft.id)
        #expect(merged.reconciling(local: local).attemptDrafts.count == 1)
    }

    @Test func privateMediaRetryReceiptsAndRemoteDownloadsSurviveRelaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = HomeWorkspaceTransportFixture()
        let owner = UUID()
        let store = HomeRecipeWorkspaceStore(root: root, transport: transport)
        store.activate(.user(owner))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.gray.setFill(); context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        var attempt = HomeAttemptRecord(name: "Photo make")
        let photo = try store.savePhoto(try #require(image.jpegData(compressionQuality: 0.8)), attemptID: attempt.id)
        attempt.photoNames = [photo]
        try store.saveAttempt(attempt)
        transport.failWorkspaceOnce = true
        await store.synchronize()
        #expect(store.workspace.attempts.count == 1)
        #expect(store.workspace.pendingOperationID != nil)
        #expect(store.errorMessage != nil)
        #expect(transport.uploads == [photo])
        let retry = HomeRecipeWorkspaceStore(root: root, transport: transport)
        retry.activate(.user(owner))
        await retry.synchronize()
        #expect(retry.workspace.pendingOperationID == nil)
        #expect(transport.uploads == [photo], "Durable receipt avoids repeating an already completed upload")
        #expect(transport.operations.count == 2 && transport.operations[0] == transport.operations[1])
        let otherDevice = HomeRecipeWorkspaceStore(root: root.appendingPathComponent("SecondDevice"), transport: transport)
        otherDevice.activate(.user(owner))
        await otherDevice.synchronize()
        #expect(otherDevice.photo(photo) != nil)
        #expect(otherDevice.workspace.attempts.first?.name == "Photo make")
        #expect(transport.downloads == [photo])
        otherDevice.activate(.user(UUID()))
        #expect(otherDevice.photo(photo) == nil)
        #expect(otherDevice.workspace.attempts.isEmpty)
    }

    @Test func inFlightAccountSwitchCannotApplyOldWorkspaceOrPhoto() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = HomeWorkspaceTransportFixture()
        let store = HomeRecipeWorkspaceStore(root: root, transport: transport)
        let first = UUID(), second = UUID()
        store.activate(.user(first))
        try store.saveAttempt(HomeAttemptRecord(name: "First account private result"))
        transport.onSynchronize = { store.activate(.user(second)) }
        await store.synchronize()
        #expect(store.scope == .user(second))
        #expect(store.workspace.attempts.isEmpty)
        #expect(!store.isSyncing)
        #expect(try store.exportSnapshot(ownerID: first).attempts.first?.name == "First account private result")
    }
    @Test func conflictKeepsDependentRecipesOutOfCanonicalGraphAndPreservesProgress() throws {
        let original = HomeRecipeVersion(content: espresso())
        let id = UUID()
        let localVersion = HomeRecipeVersion(number: 2, content: HomeRecipeContent(name: "Local espresso"))
        let remoteVersion = HomeRecipeVersion(number: 2, content: HomeRecipeContent(name: "Remote espresso"))
        let link = HomeRecipeReference(recipeID: id, versionID: localVersion.id)
        var latte = HomeRecipeContent(name: "Latte", template: .drink)
        latte.ingredients = [HomeRecipeIngredient(name: "Espresso", recipe: link)]
        let drink = HomeRecipeRecord(versions: [HomeRecipeVersion(content: latte)])
        var local = HomeRecipeWorkspace()
        local.recipes = [HomeRecipeRecord(id: id, versions: [original, localVersion]), drink]
        var session = HomePreparationSession(attempt: .fresh(from: drink))
        local.sessions = [session]
        session.stepIndex = 2
        var remote = HomeRecipeWorkspace()
        remote.recipes = [HomeRecipeRecord(id: id, versions: [original, remoteVersion])]
        remote.sessions = [session]
        let merged = remote.reconciling(local: local)
        #expect(!merged.recipes.contains { $0.id == drink.id })
        #expect(merged.recipeDrafts.contains { $0.content == latte })
        #expect(merged.version(link) == localVersion)
        #expect(merged.preparationConflicts?.first?.stepIndex == 0)
        #expect(merged.sessions.first?.stepIndex == 2)
    }

    @Test func allTemplatesAndBatchServingsSurviveOwnerScopedExportAndReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root)
        let owner = UUID()
        store.activate(.user(owner))
        var pour = HomeRecipeContent(name: "Bloom brew", template: .coffee, method: .pourOver)
        pour.targets = HomeRecipeTargets(dose: 20, ratio: 15)
        pour.steps = [HomePreparationStep(instruction: "Bloom", waitSeconds: 40, waterGrams: 60),
                      HomePreparationStep(instruction: "Add", waterGrams: 120, waterMode: .incremental),
                      HomePreparationStep(instruction: "Finish", startSeconds: 80, waterGrams: 300)]
        var cold = HomeRecipeContent(name: "Overnight", template: .coffee, method: .coldBrew)
        cold.targets = HomeRecipeTargets(dose: 100, ratio: 8, steepSeconds: 57_600, dilution: "1:1")
        var component = HomeRecipeContent(name: "Brown sugar", template: .component)
        component.ingredients = [HomeRecipeIngredient(name: "Sugar", amount: 100, unit: "g")]
        var custom = HomeRecipeContent(name: "Custom", template: .custom)
        custom.fields = [HomeCustomField(label: "Texture", kind: .choice, value: "Silky", choices: ["Silky", "Airy"])]
        for content in [espresso(), pour, cold, component, HomeRecipeContent(name: "Latte", template: .drink), custom] {
            let id = try store.saveRecipe(HomeRecipeEditorDraft(content: content))
            let recipe = try #require(store.workspace.recipes.first { $0.id == id })
            var attempt = HomeAttemptRecord.fresh(from: recipe)
            attempt.privateNote = "Private \(content.name)"
            try store.saveAttemptDraft(attempt)
            try store.saveAttempt(attempt)
            #expect(store.workspace.recipes.first { $0.id == id }?.versions.count == 1)
        }
        let coldRecipe = try #require(store.workspace.recipes.first { $0.current?.content.method == .coldBrew })
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let batch = HomePreparationSession(attempt: .fresh(from: coldRecipe), startedAt: started)
        try store.saveSession(batch)
        let reloaded = HomeRecipeWorkspaceStore(root: root)
        reloaded.activate(.user(owner))
        #expect(reloaded.workspace.sessions.first?.elapsed(at: started.addingTimeInterval(57_600)) == 57_600)
        #expect(reloaded.workspace.sessions.first?.readyAt == started.addingTimeInterval(57_600))
        var production = batch.attempt
        production.batchID = batch.id
        try reloaded.saveAttempt(production)
        for amount in [150.0, 200.0] {
            var serving = HomeAttemptRecord(name: "Cold brew serving", recipe: production.recipe,
                targets: production.targets, preparation: production.preparation, batchID: batch.id, batchSourceAttemptID: production.id)
            serving.actuals.servingMilliliters = amount
            serving.actuals.dilution = "1:2"
            try reloaded.saveAttempt(serving)
        }
        reloaded.activate(.user(UUID()))
        let exported = try reloaded.exportSnapshot(ownerID: owner)
        #expect(exported.recipes.count == 6)
        #expect(exported.attempts.count == 9)
        #expect(exported.attempts.filter { $0.batchSourceAttemptID == production.id }.count == 2)
        #expect(exported.sessions.first?.finishedAt != nil)
        #expect(reloaded.workspace.attempts.isEmpty)
        #expect(exported.attempts.allSatisfy { $0.actuals.output == nil && $0.rating == nil })
    }
    @Test func privatePhotoReferencesAreAccountBoundAndRejectPaths() throws {
        let owner = UUID()
        let name = "\(UUID())-\(UUID()).jpg"
        #expect(try HomeRecipeMediaService.path(owner: owner, name: name) == "\(owner.uuidString.lowercased())/home-attempts/\(name)")
        #expect(throws: (any Error).self) { try HomeRecipeMediaService.path(owner: owner, name: "../\(name)") }
        #expect(throws: (any Error).self) { try HomeRecipeMediaService.path(owner: owner, name: "private.jpg") }
        var state = HomeRecipeWorkspace()
        var attempt = HomeAttemptRecord(name: "Latte")
        attempt.photoNames = [name]
        state.attempts = [attempt]
        state.attemptDrafts = [attempt]
        #expect(state.referencedPhotoNames == [name])
    }
    @Test func reconciliationPreservesHistoricalReferencesAndIndependentRecipes() throws {
        let base = HomeRecipeVersion(content: HomeRecipeContent(name: "Base"))
        let id = UUID()
        let localVersion = HomeRecipeVersion(number: 2, content: HomeRecipeContent(name: "Local variation"))
        let remoteVersion = HomeRecipeVersion(number: 2, content: HomeRecipeContent(name: "Remote variation"))
        let localRecipe = HomeRecipeRecord(id: id, versions: [base, localVersion])
        let independent = HomeRecipeRecord(versions: [HomeRecipeVersion(content: HomeRecipeContent(name: "New syrup"))])
        let attempt = HomeAttemptRecord.fresh(from: localRecipe)
        var local = HomeRecipeWorkspace()
        local.recipes = [localRecipe, independent]
        local.attempts = [attempt]
        var remote = HomeRecipeWorkspace()
        remote.recipes = [HomeRecipeRecord(id: id, versions: [base, remoteVersion])]
        let merged = remote.reconciling(local: local)
        #expect(merged.recipes.first?.current == remoteVersion)
        #expect(merged.recipes.contains { $0.id == independent.id })
        #expect(merged.version(try #require(attempt.recipe)) == localVersion)
        #expect(merged.recipeDrafts.first?.content == localVersion.content)
        #expect(merged.recipeDrafts.first?.baseVersionID == remoteVersion.id)
        #expect(merged.attempts == [attempt])
        let reloaded = try JSONDecoder().decode(HomeRecipeWorkspace.self, from: JSONEncoder().encode(merged))
        #expect(reloaded.version(try #require(attempt.recipe)) == localVersion)
    }
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

    @Test func startingTemplatesStayFlexibleAndCoffeeDefaultsAreMethodAware() {
        let espresso = HomeRecipeContent.starting(.coffee)
        #expect(espresso.template == .coffee)
        #expect(espresso.method == .espresso)
        #expect(espresso.targets.dose == 18)
        #expect(espresso.targets.resolvedOutput == 36)
        #expect(espresso.targets.seconds == 28)

        var pourOver = espresso
        pourOver.changeMethod(from: .espresso, to: .pourOver)
        #expect(pourOver.targets.dose == 20)
        #expect(pourOver.targets.resolvedOutput == 300)
        #expect(pourOver.steps.count == 3)
        #expect(pourOver.cumulativeWater(through: 0) == 60)
        #expect(pourOver.cumulativeWater(through: 2) == 300)

        var customEspresso = espresso
        customEspresso.targets.dose = 19
        customEspresso.changeMethod(from: .espresso, to: .coldBrew)
        #expect(customEspresso.targets.dose == 19, "Changing methods must not overwrite deliberate values")
        #expect(customEspresso.steps.isEmpty)

        for template in HomeRecipeTemplate.allCases {
            var content = HomeRecipeContent.starting(template)
            content.name = "Anything"
            content.ingredients = [HomeRecipeIngredient(name: "Optional", amount: 1, unit: "part")]
            content.steps = [HomePreparationStep(instruction: "Do the useful thing")]
            content.fields = [HomeCustomField(label: "My field", value: "My value")]
            #expect(content.validationMessage == nil)
        }
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

    @Test func hiddenStepsRemainEditableButDoNotAdvanceWaterTargets() throws {
        var content = espresso()
        content.steps = [HomePreparationStep(instruction: "Bloom", waterGrams: 60),
            HomePreparationStep(instruction: "Optional pour", waterGrams: 100, waterMode: .incremental, isHidden: true),
            HomePreparationStep(instruction: "Pour", waterGrams: 120, waterMode: .incremental)]
        let decoded = try JSONDecoder().decode(HomeRecipeContent.self, from: JSONEncoder().encode(content))
        #expect(decoded.steps.count == 3)
        #expect(decoded.visibleSteps.count == 2)
        #expect(decoded.cumulativeWater(through: 1) == 180)
        #expect(decoded.scaled(by: 2).steps[1].isHidden == true)
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

    @Test func fieldLabelsOrderAndVisibilityDoNotChangeMetricMeaning() throws {
        var content = espresso()
        content.metricConfiguration = [
            HomeRecipeMetricConfiguration(metric: .seconds, label: "My shot time"),
            HomeRecipeMetricConfiguration(metric: .dose, label: "Basket", isVisible: false),
            HomeRecipeMetricConfiguration(metric: .output, label: "Cup")
        ]
        let decoded = try JSONDecoder().decode(HomeRecipeContent.self, from: JSONEncoder().encode(content))
        #expect(decoded.configuredMetrics.map(\.metric) == [.seconds, .dose, .output])
        #expect(decoded.configuredMetrics[1].isVisible == false)
        #expect(decoded.targets.dose == 18)
        #expect(decoded.targets.resolvedOutput == 36)
        #expect(decoded.scaled(by: 2).configuredMetrics == decoded.configuredMetrics)
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

    @Test func updatingFromAttemptRejectsCyclesWithoutSavingPartialResult() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root)
        store.activate(.guest)
        _ = try store.saveRecipe(HomeRecipeEditorDraft(content: espresso()))
        let recipe = try #require(store.workspace.recipes.first)
        var attempt = HomeAttemptRecord.fresh(from: recipe)
        attempt.preparation?.ingredients.append(HomeRecipeIngredient(name: "Self", recipe: attempt.recipe))
        try store.saveAttemptDraft(attempt)
        #expect(throws: (any Error).self) { try store.saveAttempt(attempt, updateRecipe: true) }
        #expect(store.workspace.attempts.isEmpty)
        #expect(store.workspace.recipes[0].versions.count == 1)
        #expect(store.workspace.attemptDrafts.first == attempt)
        // The variation remains loggable without changing the reusable recipe.
        try store.saveAttempt(attempt)
        #expect(store.workspace.attempts.count == 1)
        #expect(store.workspace.recipes[0].versions.count == 1)
    }

    @Test func linkedPreparationSurvivesReloadWithoutCreatingAttempts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HomeRecipeTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HomeRecipeWorkspaceStore(root: root)
        store.activate(.guest)
        _ = try store.saveRecipe(HomeRecipeEditorDraft(content: espresso()))
        let recipe = try #require(store.workspace.recipes.first)
        let reference = HomeRecipeReference(recipeID: recipe.id, versionID: try #require(recipe.current?.id))
        let began = Date(timeIntervalSince1970: 1_700_000_000)
        var parent = HomePreparationSession(attempt: HomeAttemptRecord(name: "My latte"))
        parent.linkedPreparations = [HomeLinkedPreparationProgress(reference: reference, stepIndex: 2, startedAt: began, completedAt: began.addingTimeInterval(28))]
        try store.saveSession(parent)
        let reopened = HomeRecipeWorkspaceStore(root: root)
        reopened.activate(.guest)
        #expect(reopened.workspace.sessions.first == parent)
        #expect(reopened.workspace.attempts.isEmpty)
        #expect(reopened.workspace.sessions.first?.linkedPreparations?.first?.reference.versionID == reference.versionID)
    }
}

@MainActor
private final class HomeWorkspaceTransportFixture: HomeRecipeWorkspaceTransport {
    var remote = HomeRecipeWorkspace()
    var bytes: [String: Data] = [:]
    var uploads: [String] = []
    var downloads: [String] = []
    var operations: [UUID?] = []
    var failWorkspaceOnce = false
    var onSynchronize: (() -> Void)?
    func fetch(ownerID: UUID) async throws -> HomeRecipeWorkspace { remote }
    func synchronize(_ workspace: HomeRecipeWorkspace, ownerID: UUID) async throws -> HomeRecipeWorkspace {
        operations.append(workspace.pendingOperationID)
        onSynchronize?()
        if failWorkspaceOnce { failWorkspaceOnce = false; throw URLError(.notConnectedToInternet) }
        if workspace.pendingOperationID != nil {
            remote = workspace
            remote.remoteRevision += 1
            remote.pendingOperationID = nil
        }
        return remote
    }
    func uploadPhoto(_ data: Data, name: String, ownerID: UUID) async throws {
        uploads.append(name); bytes[name] = data
    }
    func downloadPhoto(name: String, ownerID: UUID) async throws -> Data {
        downloads.append(name)
        return try #require(bytes[name])
    }
}
