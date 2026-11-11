import PhotosUI
import SwiftUI

private enum HomeRecipeRoute: Hashable {
    case recipe(UUID), attempt(UUID), preparation(UUID), log(UUID)
}

private enum HomeRecipeEditorSheet: Identifiable {
    case create
    case edit(HomeRecipeEditorDraft)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let draft): "edit-\(draft.id.uuidString)"
        }
    }
}

struct HomeRecipeExperienceView: View {
    let ownerID: UUID?
    var initialAttempt: HomeAttemptRecord?
    var initialSessionID: UUID?
    var initialRecipeID: UUID?
    let onShare: (SipDraft) -> Void
    var onBackToJournal: (() -> Void)?
    var onExit: (() -> Void)?
    var onEarlierEntries: (() -> Void)?
    var initialCollection: String?
    var opensRecipeDirectly: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(RoadmapFeatureFlags.homeSipV4Route) private var homeSipV4RouteEnabled = RoadmapFeatureFlags.homeSipV4RouteEnabledByDefault
    @StateObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var path: [HomeRecipeRoute] = []
    @SceneStorage private var tab: String
    @SceneStorage private var query: String
    @SceneStorage private var filterValue: String
    @SceneStorage private var selectedTag: String
    private var filter: HomeRecipeTemplate? { HomeRecipeTemplate(rawValue: filterValue) }
    @State private var editorSheet: HomeRecipeEditorSheet?
    @State private var openedInitial = false
    @State private var replacementRecipeID: UUID?
    @State private var sharedRecipe: HomeLinkedRecipeSheet?
    @State private var showsRecipeIdea = false
    @State private var showsDraftManager = false
    @State private var sipDrafts: [SipDraft] = []
    @State private var transientAttempts: [UUID: HomeAttemptRecord] = [:]

    init(ownerID: UUID?, initialAttempt: HomeAttemptRecord? = nil, initialSessionID: UUID? = nil,
         initialRecipeID: UUID? = nil,
         initialCollection: String? = nil, opensRecipeDirectly: Bool = false, onBackToJournal: (() -> Void)? = nil,
         onEarlierEntries: (() -> Void)? = nil, onExit: (() -> Void)? = nil,
         onShare: @escaping (SipDraft) -> Void) {
        self.ownerID = ownerID
        self.initialAttempt = initialAttempt
        self.initialSessionID = initialSessionID
        self.initialRecipeID = initialRecipeID
        self.onShare = onShare
        self.onBackToJournal = onBackToJournal
        self.onEarlierEntries = onEarlierEntries
        self.onExit = onExit
        self.initialCollection = initialCollection
        self.opensRecipeDirectly = opensRecipeDirectly
        let account = LocalAccountScope.forUserID(ownerID).storageComponent
        _tab = SceneStorage(wrappedValue: "My makes", "home.recipes.\(account).tab")
        _query = SceneStorage(wrappedValue: "", "home.recipes.\(account).query")
        _filterValue = SceneStorage(wrappedValue: "", "home.recipes.\(account).filter")
        _selectedTag = SceneStorage(wrappedValue: "", "home.recipes.\(account).tag")
    }

    var body: some View {
        NavigationStack(path: $path) {
            AnyView(navigationRoot)
            .navigationDestination(for: HomeRecipeRoute.self) { route in
                switch route {
                case .recipe(let id):
                    recipeDetail(id)
                case .attempt(let id):
                    if homeSipV4RouteEnabled {
                        HomeAttemptCanonicalDetailView(
                            attemptID: id,
                            onShare: {
                                if let attempt = store.workspace.attempts.first(where: { $0.id == id }) { share(attempt) }
                            },
                            onMakeAgain: { repeatMake(id) },
                            onDone: { path.removeLast() },
                            onHistory: { path.removeLast() },
                            onLogServing: {
                                if let batch = store.workspace.attempts.first(where: { $0.id == id }) {
                                    launchHomeServing(from: batch)
                                }
                            },
                            onChangeNextBrew: { repeatMake(id, change: $0) },
                            onStartExperiment: onShare
                        )
                    } else {
                        HomeAttemptDetailScreen(store: store, attemptID: id,
                        onRepeat: { recipe, setup in
                            MugshotAnalytics.shared.capture(.homeRecipe(.repeated, hasRecipe: recipe != nil, durationSeconds: 0))
                            if recipe != nil { startLog(recipe, setup: setup) }
                            else if let previous = store.workspace.attempts.first(where: { $0.id == id }) {
                                let fresh = HomeAttemptRecord(name: previous.name, locationName: previous.journalLocationName, recipe: previous.recipe,
                                    targets: previous.targets, preparation: setup ?? previous.preparation)
                                perform { try store.saveAttemptDraft(fresh); path.append(.log(fresh.id)) }
                            }
                        },
                        onServing: { batch in
                            var serving = HomeAttemptRecord(name: "\(batch.name) · serving", locationName: batch.journalLocationName, recipe: batch.recipe,
                                targets: batch.targets, preparation: batch.preparation, batchID: batch.batchID ?? batch.id,
                                batchSourceAttemptID: batch.id)
                            serving.actuals = HomeAttemptActuals()
                            perform { try store.saveAttemptDraft(serving); path.append(.log(serving.id)) }
                        },
                        onSaveRecipe: { editorSheet = .edit(HomeRecipeEditorDraft(content: $0)) }, onShare: share)
                    }
                case .preparation(let id):
                    HomePreparationScreen(store: store, sessionID: id) { attempt in
                        perform { try store.saveAttemptDraft(attempt); path.append(.log(attempt.id)) }
                    } onDiscard: {
                        if let attemptID = store.workspace.sessions.first(where: { $0.id == id })?.attempt.id {
                            perform { try store.discardAttemptDraft(id: attemptID); path.removeLast() }
                        }
                    } onKeep: { path.removeLast() }
                case .log(let id):
                    if let attempt = store.workspace.attemptDrafts.first(where: { $0.id == id }) ?? transientAttempts[id] {
                        HomeQuickLogScreen(store: store, initial: attempt, onSaved: { savedID in
                            transientAttempts[id] = nil
                            transientAttempts[savedID] = nil
                            path.removeLast(); path.append(.attempt(savedID))
                        }, onDiscard: {
                            try store.discardAttemptDraft(id: id, expectedScope: .forUserID(ownerID))
                            transientAttempts[id] = nil
                            path.removeLast()
                        }, onKeep: {
                            transientAttempts[id] = nil
                            path.removeLast()
                        }, startsAtReflection: attempt.resumeAtReflection == true || store.workspace.sessions.contains {
                            $0.attempt.id == id && $0.currentPhase == .awaitingReflection
                        })
                    } else { ContentUnavailableView("Draft unavailable", systemImage: "doc") }
                }
            }
            .sheet(item: $editorSheet) { destination in
                switch destination {
                case .create:
                    HomeRecipeCreationFlow(store: store, onSaved: showRecipe)
                case .edit(let draft):
                    NavigationStack {
                        HomeRecipeEditorView(store: store, draft: draft, onSaved: showRecipe)
                    }
                }
            }
            .sheet(item: $sharedRecipe) { selected in
                HomeSharedRecipeScreen(versionID: selected.reference.versionID, ownerID: ownerID, onShare: onShare)
            }
            .sheet(isPresented: $showsDraftManager, onDismiss: reloadSipDrafts) {
                HomeDraftManagementView(ownerID: ownerID, onResumeSip: { draft in
                    guard store.scope == .forUserID(ownerID) else { return }
                    onShare(draft)
                })
            }
            .sheet(isPresented: $showsRecipeIdea) {
                HomeQuickRecipeSheet(store: store, onMake: { recipe, _ in
                    showsRecipeIdea = false
                    startMaking(recipe)
                }) { recipe, _ in
                    showsRecipeIdea = false
                    showRecipe(recipe.id)
                }
            }
        }
        .tint(.mugshotSage)
        .task(id: ownerID) {
            guard !opensRecipeDirectly else { return }
            store.activate(.forUserID(ownerID))
            reloadSipDrafts()
            if !openedInitial, let initialCollection { tab = initialCollection }
            path = []
            if !openedInitial, let initialSessionID {
                openedInitial = true
                if let session = store.workspace.sessions.first(where: { $0.id == initialSessionID }),
                   session.currentPhase == .awaitingReflection {
                    path.append(.log(session.attempt.id))
                } else { path.append(.preparation(initialSessionID)) }
            }
            if !openedInitial, let initialRecipeID,
               let recipe = store.workspace.recipes.first(where: { $0.id == initialRecipeID && !$0.isArchived }) {
                openedInitial = true
                if initialCollection == "Recipes" { path.append(.recipe(recipe.id)) }
                else { startLog(recipe) }
            }
            if !openedInitial, let initialAttempt {
                openedInitial = true
                if store.workspace.attempts.contains(where: { $0.id == initialAttempt.id }) { path.append(.attempt(initialAttempt.id)) }
                else {
                    let restored = store.workspace.attemptDrafts.first { $0.id == initialAttempt.id } ?? initialAttempt
                    if restored.hasMeaningfulDraftContent {
                        perform { try store.saveAttemptDraft(restored); path.append(.log(restored.id)) }
                    } else {
                        transientAttempts[restored.id] = restored
                        path.append(.log(restored.id))
                    }
                }
            }
        }
    }

    @ViewBuilder private var navigationRoot: some View {
        if opensRecipeDirectly {
            Group {
                if store.scope == .forUserID(ownerID), let id = replacementRecipeID ?? initialRecipeID {
                    recipeDetail(id).id(id)
                } else {
                    ContentUnavailableView("Recipe unavailable", systemImage: "book.closed")
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("home.library.recipeDone")
                }
            }
        } else {
            collectionRoot
        }
    }

    private var collectionRoot: some View {
        HomeCollectionList(storageKey: "home.recipes.\(LocalAccountScope.forUserID(ownerID).storageComponent).\(tab).scroll") {
            if initialCollection != "Recipes" {
                Section {
                    Picker("Home collection", selection: $tab) {
                        Text("My makes").tag("My makes")
                        Text("Recipes").tag("Recipes")
                    }.pickerStyle(.segmented)
                }
            }
            if tab == "My makes" { makes } else { recipes }
            if let onEarlierEntries {
                Section { Button("Earlier Home entries and recipes", action: onEarlierEntries) }
            }
            if store.workspace.pendingOperationID != nil, ownerID != nil {
                Label(store.isSyncing ? "Syncing…" : "Saved on this device · sync pending", systemImage: "icloud.and.arrow.up")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let message = store.errorMessage {
                Section("Sync") {
                    Text(message).font(.footnote)
                    if store.hasRemoteConflict {
                        if store.canResolveRemoteConflict {
                            Button("Keep local edits as drafts and load latest") {
                                perform { try store.useRemoteAfterConflict() }
                            }
                        } else {
                            Button("Load latest library") { Task { await store.refreshRemoteConflict() } }
                        }
                    } else { Button("Retry sync") { Task { await store.synchronize() } } }
                }
            }
        }
        .id(tab)
        .scrollContentBackground(.hidden).background(Color.creamWhite)
        .navigationTitle(initialCollection == "Recipes" ? "Recipe Book" : "Home")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(onBackToJournal == nil ? "Done" : "Journal") {
                    if let onExit { onExit() }
                    else if let onBackToJournal { onBackToJournal() }
                    else { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(tab == "Recipes" ? "Save a recipe idea" : "Log a make", systemImage: "plus") {
                    if tab == "Recipes" { showsRecipeIdea = true } else { startLog(nil) }
                }
            }
        }
    }

    private func recipeDetail(_ id: UUID) -> some View {
        HomeRecipeDetailScreen(store: store, recipeID: id, onEdit: { editorSheet = .edit($0) },
            onLog: { startLog($0) }, onMake: { startMaking($0) },
            onAttempt: { path.append(.attempt($0)) }, onCreatedDrink: showRecipe)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
    }

    private func showRecipe(_ id: UUID) {
        if opensRecipeDirectly {
            replacementRecipeID = id
            path.removeAll()
        } else {
            path.append(.recipe(id))
        }
    }

    private func repeatMake(_ id: UUID, change: HomeBrewPlanChange? = nil) {
        guard store.scope == .forUserID(ownerID),
              let attempt = store.workspace.attempts.first(where: { $0.id == id }) else { return }
        guard let draft = HomeBrewRepeat.draft(for: attempt, ownerID: ownerID,
            versionNumber: attempt.recipe.flatMap { store.workspace.version($0)?.number },
            change: change, resolveLinked: { store.workspace.version($0)?.content }) else {
            store.errorMessage = "This brew changed. Open its plan again to choose your next change."
            return
        }
        onShare(draft)
    }

    @ViewBuilder private var makes: some View {
        if let conflicts = store.workspace.attemptConflicts, !conflicts.isEmpty {
            Section("Review conflicting results") {
                ForEach(conflicts) { local in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(local.name).font(.headline)
                        Text("Another device saved different feedback for this make. Your local result is preserved.")
                            .font(.caption).foregroundStyle(.secondary)
                        if !local.privateNote.isEmpty { Text(local.privateNote) }
                        Button("View synced result") { path.append(.attempt(local.id)) }
                        Button("Keep local result as a separate make") {
                            perform {
                                var recovered = local
                                recovered.id = UUID()
                                recovered.publicationDraftID = nil
                                recovered.savedAt = .now
                                try store.mutate {
                                    $0.attempts.append(recovered)
                                    $0.attemptConflicts?.removeAll { $0.id == local.id }
                                }
                            }
                        }
                        Button("Use synced result") {
                            perform { try store.mutate { $0.attemptConflicts?.removeAll { $0.id == local.id } } }
                        }
                    }
                }
            }
        }
        if let conflicts = store.workspace.preparationConflicts, !conflicts.isEmpty {
            Section("Review preparation progress") {
                ForEach(conflicts) { local in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(local.attempt.name).font(.headline)
                        Text("This device and another device saved different progress. Both copies are preserved until you choose.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("This device: step \(local.stepIndex + 1), \(local.completedIngredientIDs.count) ingredients checked")
                            .font(.caption)
                        Button("Keep this device’s progress") {
                            perform {
                                try store.mutate { state in
                                    if !state.attempts.contains(where: { $0.id == local.attempt.id }) {
                                        state.sessions.removeAll { $0.id == local.id }
                                        state.sessions.append(local)
                                    }
                                    state.preparationConflicts?.removeAll { $0.id == local.id }
                                }
                            }
                        }
                        Button("Use synced progress") {
                            perform { try store.mutate { $0.preparationConflicts?.removeAll { $0.id == local.id } } }
                        }
                    }
                }
            }
        }
        Section {
            HomeDraftSummaryButton(count: draftCatalogue.count) { showsDraftManager = true }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
        }
        Section("Your usuals") {
            if store.workspace.usuals.isEmpty {
                Label("Pin a favorite recipe or make one once to keep it close.", systemImage: "pin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(store.workspace.usuals.prefix(5)) { recipe in
                if let content = recipe.current?.content {
                    Button { startLog(recipe) } label: { HomeRecipeRow(content: content) }
                }
            }
            Button("Log something else", systemImage: "plus") { startLog(nil) }
            Button("Browse all recipes") { tab = "Recipes" }
        }
        Section("Recent makes") {
            if store.workspace.attempts.isEmpty {
                Text("Your home coffee story starts with one make.").foregroundStyle(.secondary)
            }
            ForEach(store.workspace.attempts.sorted { $0.createdAt > $1.createdAt }) { attempt in
                Button { path.append(.attempt(attempt.id)) } label: {
                    HStack {
                        HomeMethodIconView(method: attempt.preparation?.method ?? .other, size: 24)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text(attempt.name).font(.headline)
                            Text(attempt.resolvedRating.map { "\(HomeRecipeContent.number($0)) / 5" } ?? "Unrated")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(attempt.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder private var recipes: some View {
        Section {
            Button("Save a recipe idea", systemImage: "square.and.pencil") { showsRecipeIdea = true }
            Text("Paste a caption now. Structure the ingredients and method when you’re ready.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        if let references = store.workspace.savedReferences, !references.isEmpty {
            Section("Saved from others") {
                ForEach(references.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { reference in
                    Button(reference.name) {
                        sharedRecipe = HomeLinkedRecipeSheet(reference: HomeRecipeReference(recipeID: reference.recipeID, versionID: reference.versionID))
                    }
                }
            }
        }
        Section {
            TextField("Search recipes, tags, beans, or gear", text: $query)
            Picker("Filter", selection: Binding<HomeRecipeTemplate?>(get: { filter }, set: { filterValue = $0?.rawValue ?? "" })) {
                Text("All").tag(nil as HomeRecipeTemplate?)
                Text("Preparations").tag(HomeRecipeTemplate.preparation as HomeRecipeTemplate?)
                Text("Components").tag(HomeRecipeTemplate.component as HomeRecipeTemplate?)
                Text("Drinks").tag(HomeRecipeTemplate.drink as HomeRecipeTemplate?)
            }.pickerStyle(.segmented)
            if !availableTags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        tagButton("All tags", value: "")
                        ForEach(availableTags, id: \.self) { tag in tagButton(tag, value: tag) }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityLabel("Recipe tags")
            }
        }
        Section("Your recipes") {
            let visible = store.workspace.recipes.filter {
                !$0.isArchived
                    && (filter == nil || $0.current.map { recipeMatchesFilter($0.content, filter: filter) } == true)
                    && (query.isEmpty || $0.current?.content.searchText.contains(query.lowercased()) == true)
                    && (selectedTag.isEmpty || $0.current?.content.tags.contains(where: { $0.caseInsensitiveCompare(selectedTag) == .orderedSame }) == true)
            }.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return (lhs.lastUsedAt ?? lhs.current?.createdAt ?? .distantPast) > (rhs.lastUsedAt ?? rhs.current?.createdAt ?? .distantPast)
            }
            ForEach(visible) { recipe in
                if let content = recipe.current?.content {
                    Button { path.append(.recipe(recipe.id)) } label: { HomeRecipeRow(content: content) }
                }
            }
            if visible.isEmpty {
                ContentUnavailableView(
                    query.isEmpty && selectedTag.isEmpty ? "No recipes yet" : "No matching recipes",
                    systemImage: "book.closed",
                    description: Text(query.isEmpty && selectedTag.isEmpty
                        ? "Save a coffee, component, drink, or anything you want to make again."
                        : "Try a different search, type, or tag.")
                )
            }
            Button("New recipe", systemImage: "plus") { editorSheet = .create }
        }
        let archived = store.workspace.recipes.filter(\.isArchived)
        if !archived.isEmpty {
            Section("Archived recipes") {
                ForEach(archived) { recipe in
                    if let content = recipe.current?.content {
                        HStack {
                            HomeRecipeRow(content: content)
                            Spacer()
                            Button("Restore") {
                                perform {
                                    try store.mutate { state in
                                        guard let index = state.recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
                                        state.recipes[index].isArchived = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var availableTags: [String] {
        Array(Set(store.workspace.recipes.filter { !$0.isArchived }.flatMap { $0.current?.content.tags ?? [] }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func recipeMatchesFilter(_ content: HomeRecipeContent, filter: HomeRecipeTemplate?) -> Bool {
        guard let filter else { return true }
        switch filter {
        case .coffee:
            return content.template == .coffee
                || (content.template == .preparation && content.method.family == .coffee)
        case .component:
            return content.template == .component
                || (content.template == .preparation && content.method.family == .component)
        case .drink:
            return content.template == .drink || content.method == .completeDrink
        case .preparation:
            return content.template == .preparation || content.template == .coffee
        case .custom:
            return content.template == .custom
        }
    }

    private func tagButton(_ title: String, value: String) -> some View {
        Button(title) { selectedTag = value }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(selectedTag == value ? Color.foamWhite : Color.mugshotSageText)
            .background(selectedTag == value ? Color.mugshotSage : Color.sandBeige, in: Capsule())
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedTag == value ? .isSelected : [])
    }

    private func startLog(_ recipe: HomeRecipeRecord?, setup: HomeRecipeContent? = nil) {
        if homeSipV4RouteEnabled {
            launchHomeComposer(recipe: recipe, setup: setup, guided: false)
            return
        }
        var attempt = HomeAttemptRecord.fresh(from: recipe, setup: setup)
        attempt.locationName = defaultHomeNickname
        transientAttempts[attempt.id] = attempt
        path.append(.log(attempt.id))
    }
    private func startMaking(_ recipe: HomeRecipeRecord) {
        if homeSipV4RouteEnabled {
            launchHomeComposer(recipe: recipe, setup: nil, guided: true)
            return
        }
        var attempt = HomeAttemptRecord.fresh(from: recipe)
        attempt.locationName = defaultHomeNickname
        let session = HomePreparationSession(attempt: attempt, phase: .preparing)
        perform { try store.saveSession(session); path.append(.preparation(session.id)) }
    }
    private func launchHomeComposer(recipe: HomeRecipeRecord?, setup: HomeRecipeContent?, guided: Bool) {
        let version = recipe?.current
        if setup == nil, let recipe, let version {
            let shelf = HomeLibraryStore.shared.load(in: .forUserID(ownerID))
            onShare(HomeBrewSetup.draft(for: recipe, version: version, ownerID: ownerID, shelf: shelf, guided: guided) {
                store.workspace.version($0)?.content
            })
            return
        }
        let content = setup ?? version?.content
        var draft = SipDraft(
            ownerUserID: ownerID,
            context: .home,
            locationName: defaultHomeNickname,
            drinkType: content?.method.drinkType ?? .coffee,
            customDrinkType: content?.method.drinkType == .other ? (content?.methodDisplayName ?? "") : "",
            drinkName: content?.name ?? "",
            brewMethod: content?.methodDisplayName ?? "",
            brewDetails: content?.asBrewDetails(
                recipeID: recipe?.id, versionNumber: version?.number,
                resolveLinked: { store.workspace.version($0)?.content }
            ) ?? .empty,
            homeWorkbenchPhase: guided ? .brew : (content == nil ? .workbench : .sip)
        )
        draft.homeSipPath = guided ? .guided : .quick
        draft.launchContext.sourceRecipeIdentityID = recipe?.id
        draft.launchContext.homeRecipeVersionID = version?.id
        draft.launchContext.sourceRecipeVersion = version.map { "v\($0.number)" }
        draft.homeSetupContent = content
        onShare(draft)
    }
    private func launchHomeServing(from batch: HomeAttemptRecord) {
        guard batch.batchID != nil, batch.batchSourceAttemptID == nil else { return }
        let recipe = batch.recipe.flatMap { reference in
            store.workspace.recipes.first { $0.id == reference.recipeID }
        }
        let content = batch.preparation ?? batch.targets ?? HomeRecipeContent(
            name: batch.name, template: .preparation, method: .coldBrew
        )
        var draft = SipDraft(
            ownerUserID: ownerID,
            context: .home,
            locationName: batch.journalLocationName,
            drinkType: content.method.drinkType,
            drinkName: "\(batch.name) · serving",
            brewMethod: content.methodDisplayName,
            brewDetails: content.asBrewDetails(
                recipeID: recipe?.id, versionNumber: recipe?.current?.number,
                resolveLinked: { store.workspace.version($0)?.content }
            ),
            homeWorkbenchPhase: .quickCapture
        )
        draft.homeSipPath = .quick
        draft.homeSetupContent = content
        draft.launchContext.sourceRecipeIdentityID = recipe?.id
        draft.launchContext.homeRecipeVersionID = batch.recipe?.versionID
        draft.launchContext.homeBatchSourceAttemptID = batch.id
        onShare(draft)
    }
    private var draftCatalogue: HomeDraftCatalogue {
        HomeDraftCatalogue(sipDrafts: sipDrafts, workspace:
            store.scope == .forUserID(ownerID) ? store.workspace : HomeRecipeWorkspace())
    }
    private func reloadSipDrafts() {
        guard store.scope == .forUserID(ownerID) else { sipDrafts = []; return }
        sipDrafts = SipDraftStore.shared.allDrafts(in: .forUserID(ownerID))
    }
    private var defaultHomeNickname: String {
        HomeLibraryStore.shared.load(in: .forUserID(ownerID)).selectedHomeProfile(for: ownerID)?.name ?? "Home"
    }
    private func share(_ attempt: HomeAttemptRecord) {
        perform {
            let resolved = try HomeSharingDraftResolver.resolve(attemptID: attempt.id,
                previousID: attempt.publicationDraftID, scope: store.scope)
            if let existing = resolved.existing {
                onShare(existing.draft)
                return
            }
            let publicationID = resolved.id
            var publicDetails = (attempt.preparation ?? attempt.targets)?.asBrewDetails(
                recipeID: attempt.recipe?.recipeID,
                versionNumber: attempt.recipe.flatMap { store.workspace.version($0)?.number }
            ) ?? .empty
            publicDetails.homePreparation = HomePublicPreparationSummary.make(
                from: attempt, resolveLinked: { store.workspace.version($0)?.content }
            )
            publicDetails.steps = nil
            publicDetails.orderNotes = nil
            publicDetails.waterNotes = nil
            publicDetails.homeMethodDetails?.customNotes = nil
            publicDetails.homeMethodDetails?.pressureFlowNotes = nil
            publicDetails.homeMethodDetails?.agitationNotes = nil
            publicDetails.homeMethodDetails?.heatNotes = nil
            var draft = SipDraft(id: publicationID, ownerUserID: ownerID,
                context: .home, locationName: attempt.journalLocationName, drinkName: attempt.name,
                overallScore: attempt.resolvedRating ?? 0,
                visibility: .friends, ratingCriteria: attempt.ratingCriteria,
                brewMethod: attempt.preparation?.methodDisplayName ?? "",
                brewDetails: publicDetails, sensorySnapshot: attempt.sensorySnapshot,
                photoFallback: attempt.photoNames.isEmpty ? .mugsyMissedPhoto : nil,
                homeMakeAgain: attempt.makeAgain, homeWorkbenchPhase: .publish)
            draft.launchContext.homeAttemptID = attempt.id
            draft.launchContext.sourceRecipeIdentityID = attempt.recipe?.recipeID
            draft.launchContext.homeRecipeVersionID = attempt.recipe?.versionID
            draft.launchContext.homeRecipeAttachmentMode = .doNotAttach
            let images = attempt.photoNames.compactMap { store.photo($0) }
            guard images.count == attempt.photoNames.count else {
                throw HomeRecipeWorkspaceError.invalid("One of this make’s photos is unavailable. Your journal entry is safe; restore or remove the photo before sharing.")
            }
            try store.setPublicationDraft(publicationID, for: attempt.id)
            let saved = try SipDraftStore.shared.save(draft, images: images, in: store.scope)
            onShare(saved)
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { store.errorMessage = error.localizedDescription }
    }
}

/// Separate, account-scoped offsets survive collection switches and reopening.
private struct HomeCollectionList<Content: View>: View {
    @SceneStorage private var offset: Double
    @State private var position = ScrollPosition(y: 0)
    let content: Content
    init(storageKey: String, @ViewBuilder content: () -> Content) {
        _offset = SceneStorage(wrappedValue: 0, storageKey)
        self.content = content()
    }
    var body: some View {
        List { content }
            .scrollPosition($position)
            .onScrollGeometryChange(for: Double.self) { geometry in
                max(0, geometry.contentOffset.y + geometry.contentInsets.top)
            } action: { _, value in
                if position.isPositionedByUser { offset = value }
            }
            .onAppear { position.scrollTo(y: offset) }
    }
}

struct HomeQuickLogScreen: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    @State private var attempt: HomeAttemptRecord
    let onSaved: (UUID) -> Void
    let onDiscard: () throws -> Void
    let onKeep: () -> Void
    private let originalScope: LocalAccountScope
    @Environment(\.dismiss) private var dismiss
    @State private var reflecting = false
    @State private var details = false
    @State private var editTargets = false
    @State private var advanced = false
    @State private var updateRecipe = false
    @State private var query = ""
    @State private var photo: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var showsCamera = false
    @State private var error: String?
    @State private var openedAt: Date?
    @State private var didSave = false
    @State private var didDiscard = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var confirmsDiscard = false
    @State private var pendingRecipe: HomeRecipeRecord?

    init(store: HomeRecipeWorkspaceStore, initial: HomeAttemptRecord,
         onSaved: @escaping (UUID) -> Void, onDiscard: @escaping () throws -> Void = {}, onKeep: @escaping () -> Void = {},
         startsAtReflection: Bool = false) {
        self.store = store
        originalScope = store.scope
        var editable = initial
        if initial.editingAttemptID != nil { editable.rating = initial.resolvedRating }
        _attempt = State(initialValue: editable)
        _reflecting = State(initialValue: initial.resumeAtReflection ?? (initial.editingAttemptID != nil || startsAtReflection || initial.rating != nil
            || !initial.reaction.isEmpty || !initial.privateNote.isEmpty || !initial.nextTimeNote.isEmpty || initial.makeAgain != nil))
        self.onSaved = onSaved
        self.onDiscard = onDiscard
        self.onKeep = onKeep
    }
    var body: some View {
        HomeEditorCanvas(title: isEditing ? (reflecting ? "Make it feel right." : "Your sip, updated.")
                : reflecting ? "Keep this moment." : "A sip worth keeping.",
            detail: isEditing ? "Update this private journal entry. Saved recipes and anything already shared keep their own details."
                : reflecting ? "A rating, a thought, something for next time. Keep as much or as little as you like."
                : "Start with what you made. A recipe, photo and preparation details are yours to add.",
            symbol: reflecting ? "heart.text.clipboard" : "cup.and.saucer", eyebrow: "YOUR HOME SIP") {
            if reflecting { reflection } else { capture }
        }
        .disabled(store.scope != originalScope)
        .safeAreaInset(edge: .bottom) { makeActionBar }
        .navigationTitle(isEditing ? "Edit sip" : reflecting ? "Reflect" : "Log a Home sip")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if attempt.hasMeaningfulDraftContent { confirmsDiscard = true }
                    else { discard() }
                }
            }
        }
        .confirmationDialog("What should happen to this make?", isPresented: $confirmsDiscard) {
            Button("Keep draft", action: onKeep)
            Button("Discard draft", role: .destructive, action: discard)
            Button("Continue editing") { confirmsDiscard = false }
        } message: {
            Text("Your recipe is unchanged. Discard removes only this unfinished make and its unreferenced photos.")
        }
        .confirmationDialog("Replace the preparation you entered?", isPresented: Binding(
            get: { pendingRecipe != nil }, set: { if !$0 { pendingRecipe = nil } }
        )) {
            Button("Use selected recipe") {
                if let pendingRecipe { select(pendingRecipe) }
                pendingRecipe = nil
            }
            Button("Cancel") { pendingRecipe = nil }
        } message: {
            Text("Your entered preparation changes and actual measurements will be cleared so they are not attached to the wrong recipe.")
        }
        .onAppear {
            if openedAt == nil {
                openedAt = .now
                MugshotAnalytics.shared.capture(.homeRecipe(.logOpened, hasRecipe: attempt.recipe != nil, durationSeconds: 0))
            }
        }
        .onDisappear {
            autosaveTask?.cancel()
            if !didSave && !didDiscard && store.scope == originalScope {
                do { try store.saveAttemptDraft(attempt) } catch { self.error = error.localizedDescription }
            }
            if !didSave, let openedAt {
                MugshotAnalytics.shared.capture(.homeRecipe(.logLeftUnfinished, hasRecipe: attempt.recipe != nil,
                    durationSeconds: Int(Date.now.timeIntervalSince(openedAt))))
            }
        }
        .onChange(of: store.scope) { _, scope in
            if scope != originalScope { showsCamera = false; dismiss() }
        }
        .onChange(of: reflecting) { _, value in
            attempt.resumeAtReflection = value
            if value { MugshotAnalytics.shared.capture(.homeRecipe(.reflectionViewed, hasRecipe: attempt.recipe != nil, durationSeconds: 0)) }
        }
        .onChange(of: attempt) { _, value in
            autosaveTask?.cancel()
            autosaveTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, !didSave, !didDiscard, store.scope == originalScope else { return }
                do { try store.saveAttemptDraft(value) } catch { self.error = error.localizedDescription }
            }
        }
        .task(id: photo) {
            guard let photo else { return }
            let scope = originalScope
            guard store.scope == scope else { return }
            do {
                if let data = try await photo.loadTransferable(type: Data.self), !Task.isCancelled, store.scope == scope {
                    let name = try await store.savePhotoAsync(data, attemptID: attempt.id)
                    guard !Task.isCancelled, !didSave, !didDiscard, store.scope == scope else {
                        try? store.removeUnreferencedPhoto(name, in: scope); return
                    }
                    attempt.photoNames.append(name)
                }
            } catch { if store.scope == scope { self.error = error.localizedDescription } }
        }
        .onChange(of: cameraImage) { _, image in
            guard store.scope == originalScope else { cameraImage = nil; return }
            guard let image, let data = image.jpegData(compressionQuality: 0.9) else { return }
            cameraImage = nil
            Task {
                guard store.scope == originalScope else { return }
                do {
                    let name = try await store.savePhotoAsync(data, attemptID: attempt.id)
                    guard !Task.isCancelled, !didSave, !didDiscard, store.scope == originalScope else {
                        try? store.removeUnreferencedPhoto(name, in: originalScope); return
                    }
                    attempt.photoNames.append(name)
                }
                catch { if store.scope == originalScope { self.error = error.localizedDescription } }
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCaptureView(image: $cameraImage, isPresented: $showsCamera)
        }
    }
    @ViewBuilder private var capture: some View {
        HomeEditorSection("Your creation", symbol: "cup.and.saucer") {
            HomeEditorField("Creation name", text: $attempt.name, placeholder: "What did you make?", identifier: "home.log.name")
            HStack(spacing: 16) {
                Button("Take photo", systemImage: "camera") { showsCamera = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
                PhotosPicker(selection: $photo, matching: .images) { Label("Choose photo", systemImage: "photo.on.rectangle") }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            ForEach(attempt.photoNames, id: \.self) { name in
                if let image = store.photo(name) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                            .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16))
                        Button("Remove photo", role: .destructive) { attempt.photoNames.removeAll { $0 == name } }
                            .frame(minHeight: 44)
                    }
                }
            }
        }
        HomeEditorSection(isEditing ? "Recipe context" : "A recipe, if you like", symbol: "book.pages") {
            if isEditing {
                if let content = attempt.recipe.flatMap({ store.workspace.version($0)?.content }) ?? attempt.targets ?? attempt.preparation {
                    HomeRecipeRow(content: content)
                }
                Text("This sip keeps its original recipe and preparation. Your saved recipes stay unchanged.")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            } else {
                HomeEditorField("Search your recipes", text: $query, placeholder: "Find a favorite")
                if let reference = attempt.recipe,
                   let content = store.workspace.version(reference)?.content ?? attempt.targets ?? attempt.preparation {
                    HomeRecipeRow(content: content)
                    if store.workspace.version(reference) == nil {
                        Label("Saved from another creator · exact version attached", systemImage: "person.2")
                            .font(.caption).foregroundStyle(Color.secondaryText)
                    }
                    Button("Remove recipe", role: .destructive) { attempt.recipe = nil; attempt.targets = nil; attempt.preparation = nil }
                        .frame(minHeight: 44)
                    if let note = store.workspace.recipes.first(where: { $0.id == reference.recipeID })?.nextTimeNote, !note.isEmpty {
                        Label(note, systemImage: "lightbulb").font(.callout)
                    }
                } else {
                    ForEach(store.workspace.recipes.filter { !$0.isArchived && (query.isEmpty || $0.current?.content.searchText.contains(query.lowercased()) == true) }.prefix(6)) { recipe in
                        if let version = recipe.current {
                            Button { requestSelection(recipe) } label: {
                                HStack {
                                    Text(version.content.name).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Image(systemName: "plus.circle").foregroundStyle(Color.mugshotSageText)
                                }.frame(minHeight: 44)
                            }
                        }
                    }
                    if store.workspace.recipes.isEmpty {
                        Text("You can keep this sip without a saved recipe.").font(.caption).foregroundStyle(Color.secondaryText)
                    }
                }
            }
        }
        HomeEditorSection("Make it repeatable", symbol: "slider.horizontal.3", detail: "Everything here is optional. Unmeasured details stay unknown.") {
            if attempt.batchSourceAttemptID != nil {
                HomeNumberField(title: "Serving amount (ml)", value: $attempt.actuals.servingMilliliters)
                HomeEditorField("Serving dilution", text: $attempt.actuals.dilution, placeholder: "Optional")
            }
            DisclosureGroup("Preparation details", isExpanded: $details) {
                VStack(alignment: .leading, spacing: 14) {
                    HomeActualsEditor(actuals: $attempt.actuals, method: attempt.preparation?.method, template: attempt.preparation?.template)
                }.padding(.top, 12)
            }
            if !isEditing, attempt.preparation != nil {
                DisclosureGroup("Change this make’s recipe", isExpanded: $editTargets) {
                    VStack(alignment: .leading, spacing: 14) {
                        if attempt.preparation?.template == .coffee {
                            if attempt.preparation?.metricConfiguration != nil {
                                HomeConfiguredTargetsEditor(content: Binding(get: { attempt.preparation ?? HomeRecipeContent() }, set: { attempt.preparation = $0 }))
                            } else {
                                HomeTargetsEditor(targets: Binding(get: { attempt.preparation?.targets ?? HomeRecipeTargets() }, set: { attempt.preparation?.targets = $0 }),
                                    method: attempt.preparation?.method ?? .other, advanced: $advanced)
                            }
                        }
                        ForEach(attempt.preparation?.ingredients.indices.map { $0 } ?? [], id: \.self) { index in
                            HomeNumberField(title: attempt.preparation?.ingredients[index].name ?? "Ingredient", value: Binding(
                                get: { attempt.preparation?.ingredients[index].amount }, set: { attempt.preparation?.ingredients[index].amount = $0 }))
                        }
                    }.padding(.top, 12)
                }
            }
        }
    }

    private func requestSelection(_ recipe: HomeRecipeRecord) {
        let hasEnteredMeasurements = attempt.actuals != HomeAttemptActuals()
        let hasChangedPreparation = attempt.preparation != nil && attempt.preparation != attempt.targets
        if hasEnteredMeasurements || hasChangedPreparation {
            pendingRecipe = recipe
        } else { select(recipe) }
    }

    private func select(_ recipe: HomeRecipeRecord) {
        guard let version = recipe.current else { return }
        attempt.recipe = HomeRecipeReference(recipeID: recipe.id, versionID: version.id)
        attempt.targets = version.content
        attempt.preparation = version.content
        attempt.actuals = HomeAttemptActuals()
        attempt.name = version.content.name
    }

    private func discard() {
        autosaveTask?.cancel()
        guard store.scope == originalScope else { onKeep(); return }
        do { try onDiscard(); didDiscard = true }
        catch { self.error = error.localizedDescription }
    }
    @ViewBuilder private var reflection: some View {
        HomeEditorSection(attempt.name, symbol: "star") {
            Toggle("Add a rating", isOn: Binding(get: { attempt.rating != nil }, set: { setRating($0 ? 3 : nil) }))
                .frame(minHeight: 44)
            if attempt.rating != nil {
                HStack {
                    Slider(value: Binding(get: { attempt.rating ?? 3 }, set: { setRating($0) }), in: 0.5...5, step: 0.5)
                        .accessibilityLabel("Rating")
                    Text("\(HomeRecipeContent.number(attempt.rating ?? 0)) / 5").font(.headline)
                        .monospacedDigit().foregroundStyle(Color.mugshotSageText)
                }
            }
            Picker("Reaction", selection: $attempt.reaction) {
                Text("Rate later").tag("")
                ForEach(["Loved it", "Good", "Needs a tweak"], id: \.self) { Text($0).tag($0) }
            }.frame(minHeight: 44)
            HomeEditorField("Private note", text: $attempt.privateNote, placeholder: "For your own memory", axis: .vertical)
        }
        HomeEditorSection("For the next cup", symbol: "arrow.clockwise") {
            Picker("Make again?", selection: $attempt.makeAgain) {
                Text("Not decided").tag(nil as HomeMakeAgain?)
                ForEach(HomeMakeAgain.allCases) { Text($0.title).tag($0 as HomeMakeAgain?) }
            }.frame(minHeight: 44)
            HomeEditorField("For next time", text: $attempt.nextTimeNote, placeholder: "Something to keep or change", axis: .vertical)
        }
        if !isEditing, attempt.recipe != nil, attempt.preparation != attempt.targets {
            HomeEditorSection("Keep this change", symbol: "book.pages") {
                Picker("Save changes", selection: $updateRecipe) {
                    Text("Just this time").tag(false)
                    Text("Update my recipe").tag(true)
                }.frame(minHeight: 44)
            }
        }
    }

    private var makeActionBar: some View {
        VStack(spacing: 8) {
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(reflecting ? (isEditing ? "Save changes" : "Save to journal") : "How was it?") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                if reflecting { saveMake() } else { reflecting = true }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(attempt.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.scope != originalScope || didSave)
            .accessibilityIdentifier(reflecting ? "home.log.save" : "home.log.reflect")
            if reflecting { Button(isEditing ? "Edit sip details" : "Edit preparation") { reflecting = false }.frame(minHeight: 44) }
        }
        .padding(.horizontal, 20).padding(.vertical, 10).background(Color.creamWhite)
    }

    private var isEditing: Bool { attempt.editingAttemptID != nil }

    private func setRating(_ value: Double?) {
        if isEditing, value != attempt.resolvedRating {
            attempt.ratingCriteria = []
            attempt.manualRating = nil
        }
        attempt.rating = value
    }

    private func saveMake() {
        guard !didSave else { return }
        autosaveTask?.cancel()
        do {
            guard store.scope == originalScope else {
                throw HomeRecipeWorkspaceError.invalid("Your account changed. This make was not moved to another account.")
            }
            try store.saveAttempt(attempt, updateRecipe: !isEditing && updateRecipe)
            didSave = true
            MugshotAnalytics.shared.capture(.homeRecipe(.logSaved, hasRecipe: attempt.recipe != nil,
                durationSeconds: Int(Date.now.timeIntervalSince(openedAt ?? .now))))
            onSaved(attempt.editingAttemptID ?? attempt.id)
        } catch {
            self.error = error.localizedDescription
            MugshotAnalytics.shared.capture(.homeRecipe(.saveFailed, hasRecipe: attempt.recipe != nil, durationSeconds: 0))
        }
    }

}

struct HomeActualsEditor: View {
    @Binding var actuals: HomeAttemptActuals
    var method: HomeBrewMethod?
    var template: HomeRecipeTemplate?
    var body: some View {
        if template == nil || template == .coffee || template == .preparation {
            let resolvedMethod = method ?? .other
            if method != .pod {
                HomeNumberField(title: "Actual \(resolvedMethod.inputLabel.lowercased()) (g)", value: $actuals.dose)
            }
            HomeNumberField(
                title: "Actual \(resolvedMethod.outputLabel.lowercased()) (\(resolvedMethod.outputUnit))",
                value: $actuals.output
            )
            HomeNumberField(title: "Temperature (°C)", value: $actuals.temperature)
            if method != .pod { HomeEditorField("Grinder setting", text: $actuals.grind, placeholder: "Optional") }
        } else {
            HomeNumberField(title: "Amount made (ml)", value: $actuals.batchMilliliters)
        }
        HomeNumberField(title: "Actual time (seconds)", value: $actuals.seconds)
        if method == .coldBrew {
            HomeNumberField(title: "Batch made (ml)", value: $actuals.batchMilliliters)
            HomeEditorField("Serving dilution", text: $actuals.dilution, placeholder: "Optional")
        }
    }
}
