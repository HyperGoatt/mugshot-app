import PhotosUI
import SwiftUI

struct HomeQuickRecipeSheet: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let onSaved: (HomeRecipeRecord, HomeRecipeVersion) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var permission = CoffeeAssistancePermissionStore.shared
    @StateObject private var assistance = CoffeeAssistanceSession()
    @State private var content = HomeRecipeContent(name: "", template: .preparation, method: .other)
    @State private var selectedUse: HomeRecipeUse?
    @State private var showsCaption = false
    @State private var showsSteps = false
    @State private var showsDrinkBuilder = false
    @FocusState private var sourceField: String?
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
    private var canRead: Bool { isCurrentOwner && !showsFullEditor && !showsDrinkBuilder }
    private var hasSource: Bool { image != nil || !content.sourceText.isEmpty }
    private var recipeUse: HomeRecipeUse { selectedUse ?? HomeRecipeUse.suggested(for: content) }

    var body: some View {
        NavigationStack {
            captureForm
                .background(Color.creamWhite).foregroundStyle(Color.espressoBrown)
                .navigationTitle("Add a recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { stop(); dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            sourceField = nil
                            if !content.ingredients.isEmpty || !content.steps.isEmpty { showsCaption = false }
                        }.accessibilityIdentifier("home.recipe.keyboardDone")
                    }
                }
                .onChange(of: content.sourceText) { _, _ in restartImport() }
                .onChange(of: content.ingredients.count + content.steps.count) { _, count in
                    if count > 0, sourceField != "caption" { showsCaption = false }
                }
                .onChange(of: permission.revision) { _, _ in restartImport() }
                .onChange(of: authModel.authenticatedUser?.id) { _, _ in if !isCurrentOwner { stop(); dismiss() } }
                .safeAreaInset(edge: .bottom) { saveBar }
                .onChange(of: showsDrinkBuilder) { _, shows in if shows { sourceGeneration = UUID(); isReading = false; assistance.invalidate() } }
                .onChange(of: showsFullEditor) { _, shows in if shows { sourceGeneration = UUID(); isReading = false; assistance.invalidate() } }
                .task(id: content.sourceURL + linkRetry.uuidString) { await readLink() }
                .task(id: selectedPhoto) { await loadPhoto() }
                .task(id: selectedVideo) { await loadVideo() }
                .task(id: includesSpeech) { if includesSpeech, let movieURL { await readVideo(movieURL, speech: true) } }
                .task(id: importID) { await readWithLuna() }
                .onDisappear {
                    sourceGeneration = UUID(); isReading = false; assistance.invalidate()
                    if !showsFullEditor && !showsDrinkBuilder { stop() }
                }
        }
        .fullScreenCover(isPresented: $showsDrinkBuilder) {
            HomeDrinkBuilderSheet(store: store) { id in finish(id) }
                .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
        .fullScreenCover(isPresented: $showsFullEditor) {
            NavigationStack { HomeRecipeEditorView(store: store, draft: HomeRecipeEditorDraft(content: content)) { id in finish(id) } }
                .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
    }

    private var captureForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("FROM ANYWHERE, TO YOUR KITCHEN").recipeEyebrow()
                        Text("Save an idea.").mugshotDisplay(size: 36)
                        Text("A recipe you found. A favorite you make.")
                            .font(.subheadline).foregroundStyle(Color.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "book.pages")
                        .font(.system(size: 39, weight: .light)).foregroundStyle(Color.mugshotSageText)
                        .frame(width: 70, height: 86).background(Color.mugshotMint.opacity(0.2), in: RoundedRectangle(cornerRadius: 22))
                        .rotationEffect(.degrees(7)).accessibilityHidden(true)
                }
                if !hasSource && content.name.isEmpty {
                    Button { sourceField = nil; showsDrinkBuilder = true } label: {
                        HStack {
                            Label("Build a drink instead", systemImage: "mug")
                            Spacer(); Image(systemName: "arrow.right")
                        }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    }.accessibilityIdentifier("home.recipe.buildDrink")
                }
                sourceInput
                if isReading || sourceStatus != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if isReading { ProgressView("Reading your source…").tint(Color.mugshotSageText) }
                        if let sourceStatus {
                            Text(sourceStatus).font(.footnote).foregroundStyle(Color.secondaryText)
                                .accessibilityIdentifier("home.recipe.sourceStatus")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR RECIPE").recipeEyebrow()
                    TextField("Recipe name", text: $content.name, axis: .vertical)
                        .font(.system(size: 27, weight: .medium, design: .serif)).lineLimit(1...3)
                        .autocorrectionDisabled().focused($sourceField, equals: "name")
                        .accessibilityIdentifier("home.recipe.name")
                    Rectangle().fill(Color.mugshotLine).frame(height: 1)
                    if hasSource || !content.name.isEmpty {
                        HomeRecipeUsePicker(selection: Binding(get: { recipeUse }, set: { selectedUse = $0 }))
                        Text(recipeUse.detail).font(.caption).foregroundStyle(Color.secondaryText)
                    } else {
                        Text("A name is enough to save an idea.").font(.caption).foregroundStyle(Color.secondaryText)
                    }
                }
                if hasSource && ((originalScope.userID != nil && !permission.isEnabled(ownerID: originalScope.userID))
                    || assistance.isWorking || assistance.message != nil) {
                    VStack(alignment: .leading, spacing: 12) {
                        LunaPermissionControl(ownerID: originalScope.userID)
                        if assistance.isWorking { ProgressView("Luna is reading your recipe…").tint(Color.mugshotSageText) }
                        if let message = assistance.message { Text(message).font(.footnote).foregroundStyle(Color.secondaryText) }
                    }
                }
                recipePreview
                if hasSource || !content.name.isEmpty || !content.sourceURL.isEmpty {
                DisclosureGroup("Source & credit") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Creator credit", text: $content.creatorCredit)
                            .focused($sourceField, equals: "credit")
                        if !content.sourceURL.isEmpty { Text(content.sourceURL).font(.caption).textSelection(.enabled) }
                        if (try? HomeRecipeSourceURL(content.sourceURL)) != nil {
                            Button("Read link again", systemImage: "arrow.clockwise") { linkRetry = UUID() }
                                .accessibilityIdentifier("home.recipe.readLink")
                        }
                    }.padding(.top, 10)
                }.font(.subheadline.weight(.semibold))
                Button("Fine-tune recipe details", systemImage: "slider.horizontal.3") {
                    sourceField = nil; recipeUse.apply(to: &content); showsFullEditor = true
                }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }.padding(22)
        }.scrollDismissesKeyboard(.interactively)
    }

    private var sourceInput: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BRING IN A RECIPE").recipeEyebrow()
            HStack(spacing: 12) {
                Image(systemName: "link").foregroundStyle(Color.mugshotSageText)
                TextField("Paste a website or social link", text: $content.sourceURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .focused($sourceField, equals: "url").accessibilityIdentifier("home.recipe.sourceURL")
            }
            .padding(17).background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.mugshotLine))
            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(image == nil ? "Screenshot" : "Change image", systemImage: "photo")
                }.accessibilityIdentifier("home.recipe.screenshot")
                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                    Label("Video", systemImage: "video")
                }.accessibilityIdentifier("home.recipe.video")
                Spacer(minLength: 0)
            }.buttonStyle(SecondaryButtonStyle())
            Button { withAnimation { showsCaption.toggle() } } label: {
                Label(showsCaption ? "Hide caption" : (content.sourceText.isEmpty ? "Paste a caption" : "Edit caption"), systemImage: "text.alignleft")
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }.accessibilityIdentifier("home.recipe.caption")
            if showsCaption {
                TextField("Paste a caption or instructions", text: $content.sourceText, axis: .vertical)
                    .lineLimit(4...9).autocorrectionDisabled().focused($sourceField, equals: "caption")
                    .padding(16).background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.mugshotLine))
                    .accessibilityIdentifier("home.recipe.sourceText")
            }
            if let image { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 150).clipShape(RoundedRectangle(cornerRadius: 16)) }
            if movieURL != nil {
                Toggle("Include spoken steps on this iPhone", isOn: $includesSpeech).font(.subheadline)
                Text("Up to 60 seconds. Spoken steps use on-device recognition when available.")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
        }
    }

    @ViewBuilder private var recipePreview: some View {
        if !content.ingredients.isEmpty || !content.steps.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Label(content.recipeContentsSummary, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
                    .accessibilityIdentifier("home.recipe.extractedCount")
                if !content.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("What goes in").font(.title3.weight(.semibold))
                        ForEach($content.ingredients) { $ingredient in
                            TextField("Ingredient", text: $ingredient.name, axis: .vertical)
                                .lineLimit(1...4).focused($sourceField, equals: ingredient.id.uuidString)
                            if ingredient.id != content.ingredients.last?.id { Divider() }
                        }
                        Button("Add ingredient", systemImage: "plus") { content.ingredients.append(HomeRecipeIngredient()) }
                            .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    }.padding(18).background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 22))
                }
                DisclosureGroup("How to make it", isExpanded: $showsSteps) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach($content.steps) { $step in
                            TextField("Instruction", text: $step.instruction, axis: .vertical)
                                .lineLimit(2...6).focused($sourceField, equals: step.id.uuidString)
                        }
                        Button("Add a step", systemImage: "plus") { content.steps.append(HomePreparationStep()) }
                    }.font(.body).padding(.top, 14)
                }.font(.subheadline.weight(.semibold))
            }
        }
    }

    private var saveBar: some View {
        Button(action: save) {
            Text(recipeUse == .component ? "Save component" : "Save recipe").frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!isCurrentOwner || content.name.remoteTrimmedNonEmpty == nil)
        .accessibilityIdentifier("home.recipe.saveIdea")
        .padding(.horizontal, 22).padding(.vertical, 12).background(Color.creamWhite)
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
        var saved = content
        recipeUse.apply(to: &saved)
        do { finish(try store.saveRecipe(HomeRecipeEditorDraft(content: saved))) }
        catch { self.error = "Couldn’t save that recipe. Your details are still here." }
    }
    private func finish(_ id: UUID) {
        guard isCurrentOwner, let recipe = store.workspace.recipes.first(where: { $0.id == id }), let version = recipe.current else { return }
        showsFullEditor = false; stop(); onSaved(recipe, version)
    }
}
