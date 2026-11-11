#if DEBUG
import SwiftUI

/// Fictional, local-only editors for the isolated UI runner. Publication is a
/// labelled preview completion; this host never creates a remote post.
struct HomeEditorPreviewHost: View {
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var isReady = false
    @State private var saved: String?
    @State private var inspectedPrivateEdit = false
    @State private var originalRecipe: HomeRecipeRecord?
    @State private var originalSavedAt: Date?
    private static let editAttemptID = UUID(uuidString: "00000000-0000-4000-8000-000000000606")!
    private static let editCreatedAt = Date(timeIntervalSince1970: 1_800_000_000)
    @State private var shareDraft = SipDraft(context: .home, locationName: "Kitchen counter",
        drinkName: "Cinnamon latte", socialCaption: "A cozy coffee break.", visibility: .friends)
    private let gearStore = HomeLibraryStore(baseDirectory: FileManager.default.temporaryDirectory
        .appendingPathComponent("MugshotHomeEditorFixtureGear"))

    private var arguments: [String] { ProcessInfo.processInfo.arguments }
    var body: some View {
        Group {
            if inspectedPrivateEdit {
                privateEditVerification
            } else if let saved {
                Text(saved).font(.title).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.creamWhite)
            } else if !isReady { ProgressView() }
            else if arguments.contains("--ui-testing-home-gear") {
                HomeEquipmentEditorSheet(configuration: .new, scope: .guest, store: gearStore) { _ in saved = "Gear saved" }
            } else {
                NavigationStack {
                    if arguments.contains("--ui-testing-home-private-edit") {
                        HomeAttemptCanonicalDetailView(attemptID: Self.editAttemptID,
                            onShare: {}, onMakeAgain: {}, onDone: { inspectedPrivateEdit = true })
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("Back", systemImage: "chevron.left") { inspectedPrivateEdit = true }
                                        .labelStyle(.iconOnly)
                                        .accessibilityIdentifier("home.sip.back")
                                }
                            }
                    } else if arguments.contains("--ui-testing-home-legacy-log") {
                        HomeQuickLogScreen(store: store, initial: HomeAttemptRecord(name: "Cinnamon matcha"),
                            onSaved: { _ in saved = "Sip saved" })
                    } else if arguments.contains("--ui-testing-home-legacy-share") {
                        HomeAttemptPostSurface(draft: $shareDraft, photoImages: [], isSaving: false,
                            isRecoveryLocked: false, statusMessage: nil, onPublish: { saved = "Post preview ready" })
                    } else {
                        HomeRecipeEditorView(store: store, draft: fixture) { _ in saved = "Recipe saved" }
                    }
                }
            }
        }
        .task {
            guard MugshotLaunchEnvironment.isUITesting, Bundle.main.bundleIdentifier == "co.mugshot.app.homeqa" else {
                saved = "Isolated flow app required"; return
            }
            guard !isReady else { return }
            store.activate(.guest)
            do {
                if arguments.contains("--ui-testing-home-private-edit") { try seedPrivateEdit() }
                isReady = true
            } catch { saved = "Fixture could not load" }
        }
    }

    private var privateEditVerification: some View {
        let original = store.workspace.attempts.first { $0.id == Self.editAttemptID }
        let recipeUnchanged = originalRecipe.map { baseline in store.workspace.recipes.first { $0.id == baseline.id } == baseline } ?? false
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(store.workspace.attempts.count) saved sip").font(.title2.weight(.semibold))
                Text("Name: \(original?.name ?? "Missing")")
                Text("Score: \(HomeRecipeContent.number(original?.resolvedRating ?? 0))")
                Text("Private note: \(original?.privateNote ?? "Missing")")
                Text(original?.createdAt == Self.editCreatedAt && original?.savedAt == originalSavedAt
                    ? "Original journal identity kept" : "Journal identity changed")
                Text(recipeUnchanged ? "Recipe unchanged" : "Recipe changed")
                Text("Pending edit drafts: \(store.workspace.attemptDrafts.filter { $0.editingAttemptID == Self.editAttemptID }.count)")
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.creamWhite)
    }

    private func seedPrivateEdit() throws {
        if !store.workspace.attempts.contains(where: { $0.id == Self.editAttemptID }) {
            var content = HomeRecipeContent(name: "Cinnamon latte", template: .drink, method: .completeDrink)
            content.ingredients = [HomeRecipeIngredient(name: "Milk", amount: 180, unit: "ml")]
            content.steps = [HomePreparationStep(instruction: "Bring the latte together.")]
            let recipeID = try store.saveRecipe(HomeRecipeEditorDraft(content: content))
            guard let recipe = store.workspace.recipes.first(where: { $0.id == recipeID }), let version = recipe.current else { return }
            let attempt = HomeAttemptRecord(id: Self.editAttemptID, createdAt: Self.editCreatedAt,
                name: content.name, locationName: "Kitchen counter",
                recipe: HomeRecipeReference(recipeID: recipeID, versionID: version.id), targets: content, preparation: content,
                ratingCriteria: [SipRatingCriterionSnapshot(name: "Flavor", score: 4, sortOrder: 0)], privateNote: "First cup.")
            try store.saveAttempt(attempt)
        }
        let source = store.workspace.attempts.first { $0.id == Self.editAttemptID }
        originalSavedAt = source?.savedAt
        originalRecipe = source?.recipe.flatMap { reference in store.workspace.recipes.first { $0.id == reference.recipeID } }
    }

    private var fixture: HomeRecipeEditorDraft {
        var content = HomeRecipeContent(name: "Vanilla syrup", template: .component, method: .syrupSauce)
        content.ingredients = [HomeRecipeIngredient(name: "Milk", unit: "ml"), HomeRecipeIngredient(name: "Sugar", unit: "g")]
        content.steps = [HomePreparationStep(instruction: "Stir gently."), HomePreparationStep(instruction: "Pour into a jar.")]
        return HomeRecipeEditorDraft(content: content)
    }
}
#endif
