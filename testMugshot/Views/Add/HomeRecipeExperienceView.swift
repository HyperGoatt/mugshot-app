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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var path: [HomeRecipeRoute] = []
    @SceneStorage private var tab: String
    @SceneStorage private var query: String
    @SceneStorage private var filterValue: String
    @SceneStorage private var selectedTag: String
    private var filter: HomeRecipeTemplate? { HomeRecipeTemplate(rawValue: filterValue) }
    @State private var editorSheet: HomeRecipeEditorSheet?
    @State private var openedInitial = false
    @State private var sharedRecipe: HomeLinkedRecipeSheet?
    @State private var transientAttempts: [UUID: HomeAttemptRecord] = [:]

    init(ownerID: UUID?, initialAttempt: HomeAttemptRecord? = nil, initialSessionID: UUID? = nil,
         initialRecipeID: UUID? = nil,
         initialCollection: String? = nil, onBackToJournal: (() -> Void)? = nil,
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
        let account = LocalAccountScope.forUserID(ownerID).storageComponent
        _tab = SceneStorage(wrappedValue: "My makes", "home.recipes.\(account).tab")
        _query = SceneStorage(wrappedValue: "", "home.recipes.\(account).query")
        _filterValue = SceneStorage(wrappedValue: "", "home.recipes.\(account).filter")
        _selectedTag = SceneStorage(wrappedValue: "", "home.recipes.\(account).tag")
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeCollectionList(storageKey: "home.recipes.\(LocalAccountScope.forUserID(ownerID).storageComponent).\(tab).scroll") {
                Section {
                    Picker("Home collection", selection: $tab) {
                        Text("My makes").tag("My makes")
                        Text("Recipes").tag("Recipes")
                    }.pickerStyle(.segmented)
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
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(onBackToJournal == nil ? "Done" : "Journal") {
                        if let onExit { onExit() }
                        else if let onBackToJournal { onBackToJournal() }
                        else { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(tab == "Recipes" ? "New recipe" : "Log a make", systemImage: "plus") {
                        if tab == "Recipes" { editorSheet = .create } else { startLog(nil) }
                    }
                }
            }
            .navigationDestination(for: HomeRecipeRoute.self) { route in
                switch route {
                case .recipe(let id):
                    HomeRecipeDetailScreen(store: store, recipeID: id, onEdit: { editorSheet = .edit($0) },
                        onLog: { startLog($0) }, onMake: { startMaking($0) },
                        onAttempt: { path.append(.attempt($0)) })
                case .attempt(let id):
                    HomeAttemptDetailScreen(store: store, attemptID: id,
                        onRepeat: { recipe, setup in
                            MugshotAnalytics.shared.capture(.homeRecipe(.repeated, hasRecipe: recipe != nil, durationSeconds: 0))
                            if recipe != nil { startLog(recipe, setup: setup) }
                            else if let previous = store.workspace.attempts.first(where: { $0.id == id }) {
                                let fresh = HomeAttemptRecord(name: previous.name, recipe: previous.recipe,
                                    targets: previous.targets, preparation: setup ?? previous.preparation)
                                perform { try store.saveAttemptDraft(fresh); path.append(.log(fresh.id)) }
                            }
                        },
                        onServing: { batch in
                            var serving = HomeAttemptRecord(name: "\(batch.name) · serving", recipe: batch.recipe,
                                targets: batch.targets, preparation: batch.preparation, batchID: batch.batchID ?? batch.id,
                                batchSourceAttemptID: batch.id)
                            serving.actuals = HomeAttemptActuals()
                            perform { try store.saveAttemptDraft(serving); path.append(.log(serving.id)) }
                        },
                        onSaveRecipe: { editorSheet = .edit(HomeRecipeEditorDraft(content: $0)) }, onShare: share)
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
                            transientAttempts[savedID] = nil
                            path.removeLast(); path.append(.attempt(savedID))
                        }, onDiscard: {
                            transientAttempts[id] = nil
                            perform { try store.discardAttemptDraft(id: id); path.removeLast() }
                        }, onKeep: {
                            transientAttempts[id] = nil
                            path.removeLast()
                        })
                    } else { ContentUnavailableView("Draft unavailable", systemImage: "doc") }
                }
            }
            .sheet(item: $editorSheet) { destination in
                switch destination {
                case .create:
                    HomeRecipeCreationFlow(store: store) { id in path.append(.recipe(id)) }
                case .edit(let draft):
                    NavigationStack {
                        HomeRecipeEditorView(store: store, draft: draft) { id in path.append(.recipe(id)) }
                    }
                }
            }
            .sheet(item: $sharedRecipe) { selected in
                HomeSharedRecipeScreen(versionID: selected.reference.versionID, ownerID: ownerID, onShare: onShare)
            }
        }
        .tint(.mugshotSage)
        .task(id: ownerID) {
            store.activate(.forUserID(ownerID))
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
                startLog(recipe)
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
        if !store.workspace.sessions.filter({ $0.currentPhase == .preparing }).isEmpty {
            Section("In progress") {
                ForEach(store.workspace.sessions.filter { $0.currentPhase == .preparing }) { session in
                    Button { path.append(.preparation(session.id)) } label: {
                        Label(session.attempt.name, systemImage: "timer")
                    }
                }
            }
        }
        let meaningfulAttemptDrafts = store.workspace.attemptDrafts.filter(\.hasMeaningfulDraftContent)
        let meaningfulRecipeDrafts = store.workspace.recipeDrafts.filter { $0.content.hasMeaningfulDraftContent }
        if !meaningfulAttemptDrafts.isEmpty || !meaningfulRecipeDrafts.isEmpty {
            Section("Pick up where you left off") {
                ForEach(meaningfulAttemptDrafts) { draft in
                    Button(draft.name.isEmpty ? "Unfinished make" : draft.name) { path.append(.log(draft.id)) }
                }
                ForEach(meaningfulRecipeDrafts) { draft in
                    Button(draft.content.name.isEmpty ? "Unfinished recipe" : draft.content.name) { editorSheet = .edit(draft) }
                }
            }
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
                        Image(systemName: attempt.preparation?.template.symbol ?? "mug")
                        VStack(alignment: .leading) {
                            Text(attempt.name).font(.headline)
                            Text(attempt.rating.map { "\(HomeRecipeContent.number($0)) / 5" } ?? "Unrated")
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
                Text("Coffee").tag(HomeRecipeTemplate.coffee as HomeRecipeTemplate?)
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
                !$0.isArchived && (filter == nil || $0.current?.content.template == filter)
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
        let attempt = HomeAttemptRecord.fresh(from: recipe, setup: setup)
        transientAttempts[attempt.id] = attempt
        path.append(.log(attempt.id))
    }
    private func startMaking(_ recipe: HomeRecipeRecord) {
        let session = HomePreparationSession(attempt: .fresh(from: recipe), phase: .preparing)
        perform { try store.saveSession(session); path.append(.preparation(session.id)) }
    }
    private func share(_ attempt: HomeAttemptRecord) {
        perform {
            if let existing = SipDraftStore.shared.load(id: attempt.publicationDraftID ?? attempt.id, in: store.scope),
               existing.draft.launchContext.homeAttemptID == attempt.id {
                onShare(existing.draft)
                return
            }
            let publicationID = attempt.publicationDraftID ?? UUID()
            var draft = SipDraft(id: publicationID, ownerUserID: ownerID,
                context: .home, drinkName: attempt.name, overallScore: attempt.rating ?? 0,
                visibility: .private, homeMakeAgain: attempt.makeAgain, homeWorkbenchPhase: .publish)
            draft.launchContext.homeAttemptID = attempt.id
            draft.ratingCriteria = []
            draft.visibility = .friends
            // Only explicitly public-facing measurements enter the existing post path.
            draft.brewDetails.doseGrams = attempt.actuals.dose
            draft.brewDetails.yieldGrams = attempt.actuals.output
            draft.brewDetails.brewTimeSeconds = attempt.actuals.seconds.map { Int($0) }
            draft.brewMethod = attempt.preparation?.method.title ?? ""
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
    let onDiscard: () -> Void
    let onKeep: () -> Void
    private let originalScope: LocalAccountScope
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
         onSaved: @escaping (UUID) -> Void, onDiscard: @escaping () -> Void = {}, onKeep: @escaping () -> Void = {}) {
        self.store = store
        originalScope = store.scope
        _attempt = State(initialValue: initial)
        self.onSaved = onSaved
        self.onDiscard = onDiscard
        self.onKeep = onKeep
    }
    var body: some View {
        Form {
            if reflecting { reflection } else { capture }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .scrollContentBackground(.hidden).background(Color.creamWhite)
        .navigationTitle(reflecting ? "How was it?" : "What did you make?")
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
            Button("Continue editing", role: .cancel) { }
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
            Button("Cancel", role: .cancel) { pendingRecipe = nil }
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
        .onChange(of: reflecting) { _, value in
            if value { MugshotAnalytics.shared.capture(.homeRecipe(.reflectionViewed, hasRecipe: attempt.recipe != nil, durationSeconds: 0)) }
        }
        .onChange(of: attempt) { _, value in
            autosaveTask?.cancel()
            autosaveTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, store.scope == originalScope else { return }
                do { try store.saveAttemptDraft(value) } catch { self.error = error.localizedDescription }
            }
        }
        .task(id: photo) {
            guard let photo else { return }
            let scope = store.scope
            do {
                if let data = try await photo.loadTransferable(type: Data.self), store.scope == scope {
                    attempt.photoNames.append(try await store.savePhotoAsync(data, attemptID: attempt.id))
                }
            } catch { self.error = error.localizedDescription }
        }
        .onChange(of: cameraImage) { _, image in
            guard let image, let data = image.jpegData(compressionQuality: 0.9) else { return }
            cameraImage = nil
            let capturedScope = store.scope
            Task {
                do {
                    let name = try await store.savePhotoAsync(data, attemptID: attempt.id)
                    guard store.scope == capturedScope else { return }
                    attempt.photoNames.append(name)
                }
                catch { self.error = error.localizedDescription }
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCaptureView(image: $cameraImage, isPresented: $showsCamera)
        }
    }
    @ViewBuilder private var capture: some View {
        Section {
            TextField("Creation name", text: $attempt.name).accessibilityIdentifier("home.log.name")
            HStack {
                Button("Take photo", systemImage: "camera") { showsCamera = true }
                Spacer()
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                }
            }
            ForEach(attempt.photoNames, id: \.self) { name in
                if let image = store.photo(name) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 120)
                    Button("Remove photo", role: .destructive) { attempt.photoNames.removeAll { $0 == name } }
                }
            }
        }
        Section("Use a recipe") {
            TextField("Search your recipes", text: $query)
            if let reference = attempt.recipe,
               let content = store.workspace.version(reference)?.content ?? attempt.targets ?? attempt.preparation {
                HomeRecipeRow(content: content)
                if store.workspace.version(reference) == nil {
                    Label("Saved from another creator · exact version attached", systemImage: "person.2")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Remove recipe") { attempt.recipe = nil; attempt.targets = nil; attempt.preparation = nil }
                if let note = store.workspace.recipes.first(where: { $0.id == reference.recipeID })?.nextTimeNote, !note.isEmpty {
                    Label(note, systemImage: "lightbulb").font(.callout)
                }
            } else {
                ForEach(store.workspace.recipes.filter { !$0.isArchived && (query.isEmpty || $0.current?.content.searchText.contains(query.lowercased()) == true) }.prefix(6)) { recipe in
                    if let version = recipe.current {
                        Button(version.content.name) {
                            requestSelection(recipe)
                        }
                    }
                }
            }
        }
        Section {
            if attempt.batchSourceAttemptID != nil {
                HomeNumberField(title: "Serving amount (ml)", value: $attempt.actuals.servingMilliliters)
                TextField("Serving dilution", text: $attempt.actuals.dilution)
            }
            DisclosureGroup("Preparation details (optional)", isExpanded: $details) {
                HomeActualsEditor(actuals: $attempt.actuals, method: attempt.preparation?.method, template: attempt.preparation?.template)
            }
            if attempt.preparation != nil {
                DisclosureGroup("Change this make’s recipe", isExpanded: $editTargets) {
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
                }
            }
            Button("How was it?") { reflecting = true }
                .buttonStyle(.borderedProminent).tint(.mugshotSage)
                .disabled(attempt.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        didDiscard = true
        if store.scope == originalScope { onDiscard() }
        else { onKeep() }
    }
    @ViewBuilder private var reflection: some View {
        Section {
            Text(attempt.name).font(.headline)
            Toggle("Add a rating", isOn: Binding(get: { attempt.rating != nil }, set: { attempt.rating = $0 ? 3 : nil }))
            if attempt.rating != nil {
                Slider(value: Binding(get: { attempt.rating ?? 3 }, set: { attempt.rating = $0 }), in: 0.5...5, step: 0.5)
                    .accessibilityLabel("Rating")
                Text("\(HomeRecipeContent.number(attempt.rating ?? 0)) / 5")
            }
            Picker("Reaction", selection: $attempt.reaction) {
                Text("Rate later").tag("")
                ForEach(["Loved it", "Good", "Needs a tweak"], id: \.self) { Text($0).tag($0) }
            }
            TextField("Private note", text: $attempt.privateNote, axis: .vertical)
            Picker("Make again?", selection: $attempt.makeAgain) {
                Text("Not decided").tag(nil as HomeMakeAgain?)
                ForEach(HomeMakeAgain.allCases) { Text($0.title).tag($0 as HomeMakeAgain?) }
            }
            TextField("For next time", text: $attempt.nextTimeNote, axis: .vertical)
        }
        if attempt.recipe != nil, attempt.preparation != attempt.targets {
            Section {
                Picker("Save changes", selection: $updateRecipe) {
                    Text("Just this time").tag(false)
                    Text("Update my recipe").tag(true)
                }
            }
        }
        Section {
            Button("Save to journal") {
                do {
                    guard store.scope == originalScope else {
                        throw HomeRecipeWorkspaceError.invalid("Your account changed. This make was not moved to another account.")
                    }
                    try store.saveAttempt(attempt, updateRecipe: updateRecipe)
                    didSave = true
                    MugshotAnalytics.shared.capture(.homeRecipe(.logSaved, hasRecipe: attempt.recipe != nil,
                        durationSeconds: Int(Date.now.timeIntervalSince(openedAt ?? .now))))
                    onSaved(attempt.id)
                } catch {
                    self.error = error.localizedDescription
                    MugshotAnalytics.shared.capture(.homeRecipe(.saveFailed, hasRecipe: attempt.recipe != nil, durationSeconds: 0))
                }
            }.buttonStyle(.borderedProminent).tint(.mugshotSage).accessibilityIdentifier("home.log.save")
            Button("Edit preparation") { reflecting = false }
        }
    }
}

struct HomeActualsEditor: View {
    @Binding var actuals: HomeAttemptActuals
    var method: HomeBrewMethod?
    var template: HomeRecipeTemplate?
    var body: some View {
        if template == nil || template == .coffee {
            if method != .pod { HomeNumberField(title: "Actual coffee (g)", value: $actuals.dose) }
            HomeNumberField(title: method == .espresso || method == .pod ? "Actual beverage (g)" : "Actual water (g)", value: $actuals.output)
            HomeNumberField(title: "Temperature (°C)", value: $actuals.temperature)
            if method != .pod { TextField("Grinder setting", text: $actuals.grind) }
        } else {
            HomeNumberField(title: "Amount made (ml)", value: $actuals.batchMilliliters)
        }
        HomeNumberField(title: "Actual time (seconds)", value: $actuals.seconds)
        if method == .coldBrew {
            HomeNumberField(title: "Batch made (ml)", value: $actuals.batchMilliliters)
            TextField("Serving dilution", text: $actuals.dilution)
        }
    }
}
