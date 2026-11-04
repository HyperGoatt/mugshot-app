import PhotosUI
import SwiftUI

struct HomeQuickRecipeSheet: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let onSaved: (HomeRecipeRecord, HomeRecipeVersion) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var permission = CoffeeAssistancePermissionStore.shared
    @StateObject private var assistance = CoffeeAssistanceSession()
    @State private var content = HomeRecipeContent(name: "", template: .preparation, method: .other)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var movieURL: URL?
    @State private var includesSpeech = false
    @State private var importID = UUID()
    @State private var sourceGeneration = UUID()
    @State private var linkRetry = UUID()
    @State private var isReading = false
    @State private var sourceStatus: String?
    @State private var error: String?
    @State private var showsFullEditor = false
    @State private var isFinished = false
    @State private var generatedIngredients: [HomeRecipeIngredient] = []
    @State private var generatedSteps: [HomePreparationStep] = []
    @State private var generatedName: String?
    @State private var generatedMethod: HomeBrewMethod?
    @State private var generatedCustomMethod = ""
    @State private var sources = HomeRecipeCaptureSources()
    private let originalScope: LocalAccountScope

    init(store: HomeRecipeWorkspaceStore, onSaved: @escaping (HomeRecipeRecord, HomeRecipeVersion) -> Void) {
        self.store = store; self.onSaved = onSaved; originalScope = store.scope
    }
    private var isCurrentOwner: Bool { !isFinished && store.scope == originalScope && authModel.authenticatedUser?.id == originalScope.userID }
    private var canRead: Bool { isCurrentOwner && !showsFullEditor }
    private var hasSource: Bool { image != nil || !content.sourceText.isEmpty }

    var body: some View {
        NavigationStack {
            captureForm
                .scrollContentBackground(.hidden).background(Color.creamWhite)
                .navigationTitle("Add a recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { stop(); dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save).disabled(!isCurrentOwner || content.name.remoteTrimmedNonEmpty == nil)
                            .accessibilityIdentifier("home.recipe.saveIdea")
                    }
                }
                .onChange(of: content.sourceText) { _, _ in restartImport() }
                .onChange(of: permission.revision) { _, _ in restartImport() }
                .onChange(of: authModel.authenticatedUser?.id) { _, _ in if !isCurrentOwner { stop(); dismiss() } }
                .onChange(of: showsFullEditor) { _, shows in if shows { sourceGeneration = UUID(); isReading = false; assistance.invalidate() } }
                .task(id: content.sourceURL + linkRetry.uuidString) { await readLink() }
                .task(id: selectedPhoto) { await loadPhoto() }
                .task(id: selectedVideo) { await loadVideo() }
                .task(id: includesSpeech) { if includesSpeech, let movieURL { await readVideo(movieURL, speech: true) } }
                .task(id: importID) { await readWithLuna() }
                .onDisappear {
                    sourceGeneration = UUID(); isReading = false; assistance.invalidate()
                    if !showsFullEditor { stop() }
                }
        }
        .fullScreenCover(isPresented: $showsFullEditor) {
            NavigationStack { HomeRecipeEditorView(store: store, draft: HomeRecipeEditorDraft(content: content)) { id in finish(id) } }
        }
    }

    private var captureForm: some View {
        Form {
            Section {
                TextField("Recipe name", text: $content.name).accessibilityIdentifier("home.recipe.name")
                TextField("Paste a website or social link", text: $content.sourceURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .accessibilityIdentifier("home.recipe.sourceURL")
                if (try? HomeRecipeSourceURL(content.sourceURL)) != nil {
                    Button("Read link again", systemImage: "arrow.clockwise") { linkRetry = UUID() }
                        .accessibilityIdentifier("home.recipe.readLink")
                }
                TextField("Creator credit", text: $content.creatorCredit)
                TextField("Paste a caption or instructions", text: $content.sourceText, axis: .vertical)
                    .lineLimit(3...8).accessibilityIdentifier("home.recipe.sourceText")
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(image == nil ? "Add a recipe screenshot" : "Change screenshot", systemImage: "photo")
                }.accessibilityIdentifier("home.recipe.screenshot")
                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                    Label("Add a saved recipe video", systemImage: "video")
                }.accessibilityIdentifier("home.recipe.video")
                if permission.isEnabled(ownerID: originalScope.userID) {
                    Text("Luna reads selected text and images, including video frames. Audio stays on your iPhone.")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                }
                if let image { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160) }
                if movieURL != nil {
                    Toggle("Include spoken steps on this iPhone", isOn: $includesSpeech)
                    Text("Up to 60 seconds. Video frames and visible text are read first. Spoken steps use on-device speech recognition when available.")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                }
            } header: { Text("From wherever you found it") }
            if isReading || sourceStatus != nil {
                Section {
                    if isReading { ProgressView("Reading your source…") }
                    if let sourceStatus { Text(sourceStatus).font(.footnote).foregroundStyle(Color.secondaryText).accessibilityIdentifier("home.recipe.sourceStatus") }
                }
            }
            if hasSource {
                Section {
                    LunaPermissionControl(ownerID: originalScope.userID)
                    if assistance.isWorking { ProgressView("Luna is reading your recipe…") }
                    if let message = assistance.message { Text(message).font(.footnote).foregroundStyle(Color.secondaryText) }
                    if !content.ingredients.isEmpty || !content.steps.isEmpty {
                        Label("\(content.ingredients.count) ingredients · \(content.steps.count) steps", systemImage: "checkmark.circle")
                            .accessibilityIdentifier("home.recipe.extractedCount")
                        DisclosureGroup("Check the recipe details") {
                            ForEach(content.ingredients) { Text($0.name) }
                            ForEach(content.steps) { Text($0.instruction) }
                        }
                    }
                }
            }
            Section {
                Button("Edit ingredients, steps & method", systemImage: "slider.horizontal.3") { showsFullEditor = true }
                Text("A name and link are enough to save an idea. Check amounts and steps before making it.")
                    .font(.footnote).foregroundStyle(Color.secondaryText)
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
    }

    private func readLink() async {
        let raw = content.sourceURL
        guard canRead, (try? HomeRecipeSourceURL(raw)) != nil else { return }
        let operation = UUID(); sourceGeneration = operation
        assistance.invalidate()
        let baseline = content.sourceText
        do {
            try await Task.sleep(for: .milliseconds(750))
            guard canRead else { return }
            isReading = true
            let source = try await HomeRecipeSourceReader().read(raw)
            guard !Task.isCancelled, canRead, operation == sourceGeneration, raw == content.sourceURL else { return }
            if content.sourceText == baseline {
                removeGeneratedFields()
                content.sourceText = sources.update(.caption, text: source.text, currentText: content.sourceText)
                if content.creatorCredit.isEmpty { content.creatorCredit = source.creator }
                applyFields(HomeRecipeSourceParser.fields(in: source.text))
            }
            sourceStatus = "Caption read from this post. Check the details before saving."
            if let video = source.videoURL {
                do {
                    let local = try await HomeRecipeSourceReader().video(video)
                    defer { try? FileManager.default.removeItem(at: local) }
                    guard !Task.isCancelled, canRead, operation == sourceGeneration else { return }
                    let capture = try await HomeRecipeMediaReader().video(at: local)
                    guard !Task.isCancelled, canRead, operation == sourceGeneration else { return }
                    applyCapture(capture)
                } catch is CancellationError { throw CancellationError() }
                catch { sourceStatus = "Caption read. The video wasn’t accessible; add a saved clip or screenshots for details shown or spoken in it." }
            } else {
                sourceStatus = "Caption read. Add screenshots or a saved video for details that only appear in the video."
            }
            isReading = false; restartImport()
        } catch is CancellationError { if operation == sourceGeneration { isReading = false } }
        catch {
            guard canRead, operation == sourceGeneration else { return }
            isReading = false
            sourceStatus = (error as? HomeRecipeSourceError)?.localizedDescription ?? HomeRecipeSourceError.unavailable.localizedDescription
        }
    }

    private func loadPhoto() async {
        guard let item = selectedPhoto, canRead else { return }
        let operation = UUID(); sourceGeneration = operation
        isReading = true; assistance.invalidate()
        defer { if operation == sourceGeneration { isReading = false } }
        guard let data = try? await item.loadTransferable(type: Data.self), data.count <= 20_000_000,
              !Task.isCancelled, canRead, operation == sourceGeneration, let chosen = UIImage(data: data) else { return }
        image = chosen
        let text = (try? await HomeRecipeMediaReader().text(in: chosen)) ?? ""
        guard !Task.isCancelled, canRead, operation == sourceGeneration else { return }
        addCapturedText(text, kind: .screenshot)
        sourceStatus = text.isEmpty ? "Screenshot loaded. Luna can read visible recipe details, or you can enter them yourself." : "Screenshot text read on your iPhone. Check the extracted recipe details."
        restartImport()
    }

    private func loadVideo() async {
        guard let item = selectedVideo, canRead else { return }
        do {
            guard let movie = try await item.loadTransferable(type: HomeRecipeMovie.self) else { throw HomeRecipeSourceError.invalidMedia }
            guard !Task.isCancelled, canRead else { try? FileManager.default.removeItem(at: movie.url); return }
            if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
            movieURL = movie.url
            await readVideo(movie.url, speech: includesSpeech)
        } catch { if canRead { sourceStatus = (error as? HomeRecipeSourceError)?.localizedDescription ?? HomeRecipeSourceError.invalidMedia.localizedDescription } }
    }

    private func readVideo(_ url: URL, speech: Bool) async {
        let operation = UUID(); sourceGeneration = operation; isReading = true; assistance.invalidate()
        defer { if operation == sourceGeneration { isReading = false } }
        do {
            let capture = try await HomeRecipeMediaReader().video(at: url, includeSpeech: speech)
            guard !Task.isCancelled, canRead, operation == sourceGeneration else { return }
            applyCapture(capture); restartImport()
        } catch is CancellationError { }
        catch { if canRead, operation == sourceGeneration { sourceStatus = (error as? HomeRecipeSourceError)?.localizedDescription ?? HomeRecipeSourceError.invalidMedia.localizedDescription } }
    }

    private func applyCapture(_ capture: HomeRecipeVideoCapture) {
        image = capture.image; addCapturedText(capture.text, kind: .video)
        sourceStatus = "Read \(capture.frameCount) sampled video frames" + (capture.hasTranscript ? " and on-device spoken steps. Check amounts and timing." : ". Spoken steps haven’t been read. Check anything between the sampled frames.")
    }

    private func addCapturedText(_ text: String, kind: HomeRecipeCaptureSources.Kind) {
        guard !text.isEmpty else { return }
        removeGeneratedFields()
        content.sourceText = sources.update(kind, text: text, currentText: content.sourceText)
        applyFields(HomeRecipeSourceParser.fields(in: content.sourceText))
    }

    private func readWithLuna() async {
        let operation = importID
        guard canRead, hasSource, content.sourceReuseAllowed != false else { return }
        do {
            try await Task.sleep(for: .milliseconds(900))
            guard !isReading else { return }
            removeGeneratedFields()
            applyFields(HomeRecipeSourceParser.fields(in: content.sourceText))
            guard let owner = originalScope.userID, permission.isEnabled(ownerID: owner) else { return }
            let encoded = try image.map(CoffeeAssistanceImage.encode)
            let request = CoffeeAssistanceRequest(ownerID: owner, task: .recipeImport,
                evidence: CoffeeAssistanceRecipeImport.source(content), image: encoded)
            await assistance.run(request, consent: true, currentOwner: { authModel.authenticatedUser?.id })
            guard !Task.isCancelled, operation == importID, canRead, content.sourceReuseAllowed != false,
                  permission.isEnabled(ownerID: owner), let result = assistance.result else { return }
            applyFields(result.fields)
        } catch is CancellationError { }
        catch { self.error = "Couldn’t read that image. Your recipe idea can still be saved." }
    }

    private func applyFields(_ fields: [CoffeeAssistanceField]) {
        guard content.sourceReuseAllowed != false else { return }
        let previous = content
        CoffeeAssistanceRecipeImport.apply(fields, to: &content)
        generatedIngredients += content.ingredients.filter { item in !previous.ingredients.contains(where: { $0.id == item.id }) }
        generatedSteps += content.steps.filter { item in !previous.steps.contains(where: { $0.id == item.id }) }
        if previous.name.isEmpty, !content.name.isEmpty { generatedName = content.name }
        if previous.method == .other, previous.customMethodName.isEmpty,
           content.method != .other || !content.customMethodName.isEmpty {
            generatedMethod = content.method; generatedCustomMethod = content.customMethodName
        }
    }
    private func removeGeneratedFields() {
        content.ingredients.removeAll { generatedIngredients.contains($0) }
        content.steps.removeAll { generatedSteps.contains($0) }
        if content.name == generatedName { content.name = "" }
        if content.method == generatedMethod, content.customMethodName == generatedCustomMethod {
            content.method = .other; content.customMethodName = ""
        }
        generatedIngredients = []; generatedSteps = []; generatedName = nil
        generatedMethod = nil; generatedCustomMethod = ""
    }
    private func restartImport() { assistance.invalidate(); importID = UUID() }
    private func stop() {
        isFinished = true; sourceGeneration = UUID(); assistance.invalidate()
        if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
    }
    private func save() {
        guard isCurrentOwner else { return }
        assistance.invalidate(); sourceGeneration = UUID()
        if let normalized = try? HomeRecipeSourceURL(content.sourceURL) { content.sourceURL = normalized.url.absoluteString }
        do { finish(try store.saveRecipe(HomeRecipeEditorDraft(content: content))) }
        catch { self.error = "Couldn’t save that recipe. Your details are still here." }
    }
    private func finish(_ id: UUID) {
        guard isCurrentOwner, let recipe = store.workspace.recipes.first(where: { $0.id == id }), let version = recipe.current else { return }
        showsFullEditor = false; stop(); onSaved(recipe, version)
    }
}
