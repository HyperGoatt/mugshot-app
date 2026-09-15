import SwiftUI

/// Shared recipes are re-authorized on opening. Saving a reference is not a
/// license to copy instructions, and an adaptation always retains attribution.
struct HomeSharedRecipeScreen: View {
    let versionID: UUID
    let ownerID: UUID?
    let onShare: (SipDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var projection: RemoteVisitRecipeProjection?
    @State private var content: HomeRecipeContent?
    @State private var error: String?
    @State private var editor: HomeRecipeEditorDraft?
    @State private var launch: HomeSharedMakeLaunch?
    @State private var linked: HomeLinkedRecipeSheet?
    @State private var savedRecipeID: UUID?

    var body: some View {
        NavigationStack {
            List {
                if let projection, let content {
                    Section {
                        HomeRecipeRow(content: content)
                        Text("Version \(projection.versionNumber) · \(projection.owner?.personLabel ?? "Mugshot recipe")")
                            .font(.caption).foregroundStyle(.secondary)
                        if content.isActionable, canKeepInstructions {
                            Button("Make this") { start(content, guided: true) }
                                .buttonStyle(.borderedProminent).tint(.mugshotSage)
                        }
                        Button("Log a make") { start(content, guided: false) }
                        if !canKeepInstructions {
                            Text("Follow the original instructions here, then log your result. Instructions are not copied into your journal.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button(isSaved ? "Saved in your library" : "Save to my library") { saveReference(projection) }
                            .disabled(isSaved || ownerID == nil)
                        if projection.canSaveAndAdapt {
                            Button("Adapt my own recipe") {
                                var copy = content
                                copy.sourceVersionID = projection.recipeVersionID
                                copy.creatorCredit = projection.owner?.personLabel ?? content.creatorCredit
                                // Component instructions are not copied with the parent.
                                // Retain ingredient names/amounts; the source stays credited.
                                copy.ingredients = copy.ingredients.map { var ingredient = $0; ingredient.recipe = nil; return ingredient }
                                editor = HomeRecipeEditorDraft(content: copy)
                            }
                        }
                    }
                    HomeRecipeInformation(content: content) { reference in linked = HomeLinkedRecipeSheet(reference: reference) }
                    if let legacy = content.legacyDetails {
                        Section("Original recipe record") {
                            Text("These older values are preserved as recorded, not assumed to be targets or measured results.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let dose = legacy.doseGrams { LabeledContent("Coffee", value: "\(HomeRecipeContent.number(dose)) g") }
                            if let yield = legacy.yieldGrams { LabeledContent("Yield", value: "\(HomeRecipeContent.number(yield)) g") }
                            if let seconds = legacy.brewTimeSeconds { LabeledContent("Time", value: "\(seconds) sec") }
                        }
                    }
                } else if let error { ContentUnavailableView(error, systemImage: "book.closed") }
                else { ProgressView("Opening recipe…") }
            }
            .navigationTitle("Recipe").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(Color.creamWhite)
            .toolbar { Button("Done") { dismiss() } }
            .task(id: versionID) { await load() }
            .sheet(item: $editor) { draft in
                NavigationStack {
                    HomeRecipeEditorView(store: store, draft: draft) { id in savedRecipeID = id }
                }
            }
            .navigationDestination(isPresented: Binding(get: { savedRecipeID != nil }, set: { if !$0 { savedRecipeID = nil } })) {
                if let savedRecipeID {
                    HomeRecipeDetailScreen(store: store, recipeID: savedRecipeID,
                        onEdit: { editor = $0 }, onLog: { if let value = $0.current?.content { start(value, guided: false, owned: $0) } },
                        onMake: { if let value = $0.current?.content { start(value, guided: true, owned: $0) } },
                        onAttempt: { id in launch = HomeSharedMakeLaunch(attempt: store.workspace.attempts.first { $0.id == id }) })
                }
            }
            .sheet(item: $linked) { reference in
                HomeSharedRecipeScreen(versionID: reference.reference.versionID, ownerID: ownerID, onShare: onShare)
            }
            .fullScreenCover(item: $launch) { item in
                HomeRecipeExperienceView(ownerID: ownerID, initialAttempt: item.attempt, initialSessionID: item.sessionID, onShare: onShare)
            }
        }
    }
    private var isSaved: Bool { store.workspace.savedReferences?.contains { $0.versionID == versionID } == true }
    private var canKeepInstructions: Bool {
        projection?.canSaveAndAdapt == true || (ownerID != nil && projection?.owner?.id == ownerID)
    }
    private func load() async {
        projection = nil; content = nil; error = nil
        guard let ownerID else { error = "Sign in to open shared recipes."; return }
        store.activate(.user(ownerID))
        do {
            let client = try SupabaseClientProvider.shared.client()
            guard let value = try await VisitService(client: client).fetchRecipeProjection(recipeVersionId: versionID) else {
                throw HomeRecipeWorkspaceError.unavailableReference
            }
            let native = try await HomeRecipeWorkspaceService(client: client).content(versionID: versionID)
            guard store.scope == .user(ownerID) else { return }
            var resolved = native ?? HomeRecipeContent(name: value.recipeName, template: .coffee,
                method: HomeBrewMethod.allCases.first { $0.rawValue == value.brewMethod || $0.title == value.brewMethod } ?? .other,
                steps: (value.brewDetails.steps ?? []).map { HomePreparationStep(instruction: $0.instruction, waitSeconds: $0.durationSeconds.map(Double.init)) },
                legacyDetails: value.brewDetails)
            resolved.sourceVersionID = value.recipeVersionID
            resolved.sourceReuseAllowed = value.canSaveAndAdapt || value.owner?.id == ownerID
            resolved.creatorCredit = value.owner?.personLabel ?? resolved.creatorCredit
            projection = value; content = resolved
        } catch { self.error = "This recipe is unavailable. It may be private, removed, or offline." }
    }
    private func saveReference(_ recipe: RemoteVisitRecipeProjection) {
        do {
            try store.mutate { workspace in
                var references = workspace.savedReferences ?? []
                references.removeAll { $0.versionID == versionID }
                references.append(HomeSavedRecipeReference(recipeID: recipe.recipeIdentityID, versionID: versionID, name: recipe.recipeName))
                workspace.savedReferences = references
            }
        } catch { self.error = error.localizedDescription }
    }
    private func start(_ content: HomeRecipeContent, guided: Bool, owned: HomeRecipeRecord? = nil) {
        guard let ownerID, store.scope == .user(ownerID) else { return }
        var attempt = HomeAttemptRecord.fresh(from: owned)
        if owned == nil {
            attempt.name = content.name
            // Access is not copying permission. Protected source instructions
            // stay ephemeral; their referenced attempt records only the result.
            attempt.targets = canKeepInstructions ? content : nil
            attempt.preparation = canKeepInstructions ? content : nil
            attempt.recipe = projection.map { HomeRecipeReference(recipeID: $0.recipeIdentityID, versionID: $0.recipeVersionID) }
        }
        do {
            if guided, owned != nil || canKeepInstructions {
                let session = HomePreparationSession(attempt: attempt)
                try store.saveSession(session)
                launch = HomeSharedMakeLaunch(sessionID: session.id)
            } else {
                try store.saveAttemptDraft(attempt)
                launch = HomeSharedMakeLaunch(attempt: attempt)
            }
        } catch { self.error = error.localizedDescription }
    }
}

private struct HomeSharedMakeLaunch: Identifiable {
    var id = UUID()
    var attempt: HomeAttemptRecord?
    var sessionID: UUID?
}

struct HomePostRecipeList: View {
    let visitID: UUID
    let ownerID: UUID?
    let onShare: (SipDraft) -> Void
    @State private var recipes: [HomeSavedRecipeReference] = []
    @State private var selected: HomeLinkedRecipeSheet?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                ForEach(recipes) { recipe in
                    Button(recipe.name) { selected = HomeLinkedRecipeSheet(reference: HomeRecipeReference(recipeID: recipe.recipeID, versionID: recipe.versionID)) }
                }
                if recipes.isEmpty { Text(error ?? "No accessible recipe attachments.").foregroundStyle(.secondary) }
            }.navigationTitle("Attached recipes")
                .task {
                    do { recipes = try await HomeRecipeWorkspaceService(client: SupabaseClientProvider.shared.client()).postRecipes(visitID: visitID) }
                    catch { self.error = "Recipe attachments could not be loaded." }
                }
                .sheet(item: $selected) { recipe in
                    HomeSharedRecipeScreen(versionID: recipe.reference.versionID, ownerID: ownerID, onShare: onShare)
                }
        }
    }
}
