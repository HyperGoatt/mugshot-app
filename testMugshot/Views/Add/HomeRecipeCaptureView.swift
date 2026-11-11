import PhotosUI
import SwiftUI

struct HomeQuickRecipeSheet: View {
    private struct SpeechReadID: Equatable {
        let generation: UUID
        let movieURL: URL?
    }

    @ObservedObject var store: HomeRecipeWorkspaceStore
    let onSaved: (HomeRecipeRecord, HomeRecipeVersion) -> Void
    let onMake: ((HomeRecipeRecord, HomeRecipeVersion) -> Void)?
    private let sharedSource: HomeRecipeShareCapture?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var permission = CoffeeAssistancePermissionStore.shared
    @StateObject private var assistance = CoffeeAssistanceSession()
    @State private var content = HomeRecipeContent(name: "", template: .preparation, method: .other)
    @State private var selectedUse: HomeRecipeUse?
    @State private var showsCaption = false
    @State private var showsLink = false
    @State private var showsManual = false
    @State private var showsSteps = false
    @State private var showsDrinkBuilder = false
    @FocusState private var sourceField: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageSource: HomeRecipeCaptureSources.Kind?
    @State private var movieURL: URL?
    @State private var isReadingSpeech = false
    @State private var importedCreatorCredit: String?
    @State private var importID = UUID()
    @State private var sourceGeneration = UUID()
    @State private var linkRetry = UUID()
    @State private var isReading = false
    @State private var sourceStatus: String?
    @State private var error: String?
    @State private var showsFullEditor = false
    @State private var isFinished = false
    @State private var extraction = CoffeeAssistanceRecipeImport.Draft()
    @State private var sources = HomeRecipeCaptureSources()
    @State private var showsSources = true
    @State private var reviewJump = UUID()
    @State private var reviewAnchor = "recipe.review"
    @State private var shouldReadSharedLink = false
    @State private var saveID = UUID()
    @State private var confirmsDiscardSource = false
    private let originalScope: LocalAccountScope

    init(store: HomeRecipeWorkspaceStore, sharedSource: HomeRecipeShareCapture? = nil,
         onMake: ((HomeRecipeRecord, HomeRecipeVersion) -> Void)? = nil,
         onSaved: @escaping (HomeRecipeRecord, HomeRecipeVersion) -> Void) {
        self.store = store
        self.sharedSource = sharedSource
        self.onMake = onMake
        self.onSaved = onSaved
        originalScope = store.scope
        if let sharedSource {
            var initialContent = HomeRecipeContent(name: "", template: .preparation, method: .other)
            initialContent.sourceURL = sharedSource.url ?? ""
            _content = State(initialValue: initialContent)
            _saveID = State(initialValue: sharedSource.id)
            _showsSources = State(initialValue: false)
        }
    }
    private var isCurrentOwner: Bool {
        !isFinished && store.scope == originalScope && authModel.authenticatedUser?.id == originalScope.userID
            && (sharedSource == nil || sharedSource?.owner.userID == originalScope.userID)
    }
    private var canRead: Bool { isCurrentOwner && !showsFullEditor && !showsDrinkBuilder }
    private var hasSource: Bool { image != nil || !sources.text.isEmpty }
    private var isReadingSource: Bool { isReading || isReadingSpeech }
    private var recipeUse: HomeRecipeUse { selectedUse ?? HomeRecipeUse.suggested(for: content) }
    private var classifiedContent: HomeRecipeContent {
        var result = content
        result.sourceText = sources.text
        recipeUse.apply(to: &result)
        return result
    }

    var body: some View {
        NavigationStack { captureScreen }
            .fullScreenCover(isPresented: $showsDrinkBuilder) {
                HomeDrinkBuilderSheet(store: store) { id in finish(id) }
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .fullScreenCover(isPresented: $showsFullEditor) {
                NavigationStack {
                    HomeRecipeEditorView(store: store, draft: HomeRecipeEditorDraft(id: saveID, content: content)) { id in finish(id) }
                }
                .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .confirmationDialog("Discard this shared source?", isPresented: $confirmsDiscardSource, titleVisibility: .visible) {
                Button("Discard source", role: .destructive, action: discardSharedSource)
                Button("Keep source", role: .cancel) {}
            } message: {
                Text("This removes the link, text, or screenshot you shared to Mugshot.")
            }
    }

    private var captureScreen: some View {
        VStack(spacing: 0) {
            activeCapture
            saveBar
        }
            .background(Color.creamWhite).foregroundStyle(Color.espressoBrown)
            .navigationTitle("Save a recipe").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { stop(); dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        if hasSource && showsSources { showImportedReview(dismissingKeyboard: true) }
                        else { sourceField = nil }
                    }
                    .accessibilityIdentifier("home.recipe.keyboardDone")
                }
            }
    }

    private var activeCapture: some View {
        // Bound the SwiftUI type and stack size across source and sheet transitions.
        AnyView(observedCapture)
            .task(id: content.sourceURL + linkRetry.uuidString) { await readLink() }
            .task(id: selectedPhoto) { await loadPhoto() }
            .task(id: selectedVideo) { await loadVideo() }
            .task(id: sharedSource?.id) { await loadSharedSource() }
            .task(id: SpeechReadID(generation: sources.speechGeneration, movieURL: movieURL)) { await readSelectedSpeech() }
            .task(id: importID) { await readWithLuna() }
            .onDisappear {
                suspendSourceReading()
                if !showsFullEditor && !showsDrinkBuilder { stop() }
            }
    }

    private var observedCapture: some View {
        captureForm
            .onChange(of: content.ingredients.count + content.steps.count) { _, count in
                if count > 0, sourceField != "caption" { showsCaption = false }
            }
            .onChange(of: permission.revision) { _, _ in restartImport() }
            .onChange(of: selectedUse) { _, _ in restartImport() }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in closeAfterAccountChange() }
            .onChange(of: store.scope) { _, _ in closeAfterAccountChange() }
            .onChange(of: showsDrinkBuilder) { _, shows in if shows { suspendSourceReading() } }
            .onChange(of: showsFullEditor) { _, shows in if shows { suspendSourceReading() } }
    }

    private func closeAfterAccountChange() {
        if !isCurrentOwner { stop(); dismiss() }
    }

    private func suspendSourceReading() {
        sourceGeneration = UUID()
        isReading = false
        isReadingSpeech = false
        assistance.invalidate()
    }

    private var captureForm: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    captureHeader
                    if showsSources { sourceInput.id("recipe.sources") }
                    if hasSource || sharedSource != nil || !showsSources { importReview.id("recipe.review") }
                    sourceFeedback
                    if !hasSource && sharedSource == nil && content.name.isEmpty && !showsManual {
                        Button { sourceField = nil; showsDrinkBuilder = true } label: {
                            Label("Build a drink instead", systemImage: "mug")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .accessibilityIdentifier("home.recipe.buildDrink")
                    }
                    identityCard.id("recipe.identity")
                    recipePreview
                    if hasSource || !content.name.isEmpty || !content.sourceURL.isEmpty { sourceAndDetails }
                }
                .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 22)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("home.recipe.captureScroll")
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: reviewJump) { _, _ in proxy.scrollTo(reviewAnchor, anchor: .top) }
        }
    }

    private var importReview: some View {
        HomeEditorSection("Review your recipe", symbol: "checklist") {
            Text(classifiedContent.recipeContentsSummary)
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
                .accessibilityIdentifier("home.recipe.extractedCount")
            if content.name.remoteTrimmedNonEmpty == nil {
                Button("Add a recipe name", systemImage: "pencil") {
                    jump(to: "recipe.identity")
                    sourceField = "name"
                }
                .frame(minHeight: 44)
            } else if !classifiedContent.isReadyToMake {
                Button("Add preparation steps", systemImage: "list.number") {
                    showsManual = true
                    showsSteps = true
                    if content.steps.isEmpty { content.steps.append(HomePreparationStep()) }
                    jump(to: "recipe.steps")
                    sourceField = content.steps.first?.id.uuidString
                }
                .frame(minHeight: 44)
            }
            if !showsSources {
                Button("Edit source", systemImage: "link") {
                    showsSources = true
                    jump(to: "recipe.sources")
                }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("home.recipe.editSource")
            }
            if (try? HomeRecipeSourceURL(content.sourceURL)) != nil {
                Button(sourceStatus == nil ? "Read link" : "Read link again", systemImage: "arrow.clockwise", action: retryLink)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("home.recipe.readLink")
            }
            if sharedSource != nil {
                Button("Discard shared source", systemImage: "trash", role: .destructive) { confirmsDiscardSource = true }
                    .frame(minHeight: 44)
            }
        }
    }

    private var captureHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("FROM ANYWHERE, TO YOUR KITCHEN").recipeEyebrow()
                Text("Save a recipe.").font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Keep a recipe you found or write down one you make.")
                    .font(.subheadline).foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 0)
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "book.pages")
                    .font(.system(size: 34, weight: .light)).foregroundStyle(Color.mugshotSageText)
                    .frame(width: 66, height: 76)
                    .background(Color.mugshotMint.opacity(0.25), in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)
            }
        }
    }

    private var sourceInput: some View {
        HomeEditorSection("Where did you find it?", symbol: "bookmark") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 224 : 126), spacing: 8)], spacing: 8) {
                Button {
                    sourceField = nil; showsCaption = false; showsLink.toggle()
                } label: {
                    sourceChoice(content.sourceURL.isEmpty ? "Paste a link" : "Edit link", symbol: "link")
                }
                .accessibilityIdentifier("home.recipe.link")
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    sourceChoice(selectedPhoto == nil ? "Screenshot" : "Change image", symbol: "photo")
                }
                .accessibilityIdentifier("home.recipe.screenshot")
                PhotosPicker(selection: videoSelection, matching: .videos) {
                    sourceChoice(selectedVideo == nil ? "Video" : "Change video", symbol: "video")
                }
                .accessibilityIdentifier("home.recipe.video")
                Button {
                    sourceField = nil; showsLink = false; showsCaption.toggle()
                } label: {
                    sourceChoice(sources.typedCaption.isEmpty ? "Paste a caption" : "Edit caption", symbol: "text.alignleft")
                }
                .accessibilityIdentifier("home.recipe.caption")
            }
            .buttonStyle(.plain)
            if showsLink {
                TextField("Paste a website or social link", text: $content.sourceURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .focused($sourceField, equals: "url").frame(minHeight: 44)
                    .accessibilityIdentifier("home.recipe.sourceURL")
            }
            if showsCaption {
                TextField("Paste a caption or instructions", text: captionInput, axis: .vertical)
                    .lineLimit(4...9).autocorrectionDisabled().focused($sourceField, equals: "caption")
                    .padding(12).background(Color.creamWhite, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("home.recipe.sourceText")
            }
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityLabel("Selected recipe source")
            }
            if movieURL != nil {
                Toggle("Read spoken steps on this iPhone", isOn: speechToggle).frame(minHeight: 44)
                Text("Clips can be up to 60 seconds. Spoken steps use on-device recognition when available.")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
            Button(action: startManual) {
                Label("Type it in", systemImage: "pencil.line")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("home.recipe.typeItIn")
            if hasSource || sharedSource != nil {
                Button("Review recipe", systemImage: "checklist") { showImportedReview(dismissingKeyboard: true) }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("home.recipe.reviewSource")
            }
        }
    }

    private func sourceChoice(_ title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(Color.mugshotSageText)
                .accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(10)
        .background(Color.mugshotMint.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }

    @ViewBuilder private var sourceFeedback: some View {
        if isReadingSource || sourceStatus != nil || assistance.isWorking || assistance.message != nil
            || (hasSource && originalScope.userID != nil && !permission.isEnabled(ownerID: originalScope.userID)) {
            HomeEditorSection("Your source", symbol: "text.viewfinder") {
                if isReadingSource { ProgressView("Reading your source…").tint(Color.mugshotSageText) }
                if let sourceStatus {
                    Text(sourceStatus).font(.footnote).foregroundStyle(Color.secondaryText)
                        .accessibilityIdentifier("home.recipe.sourceStatus")
                }
                if hasSource && originalScope.userID != nil && !permission.isEnabled(ownerID: originalScope.userID) {
                    MugsyPermissionControl(ownerID: originalScope.userID)
                }
                if assistance.isWorking { ProgressView("Mugsy is reading your recipe…").tint(Color.mugshotSageText) }
                if let message = assistance.message { Text(message).font(.footnote).foregroundStyle(Color.secondaryText) }
            }
        }
    }

    private var identityCard: some View {
        HomeEditorSection("Your recipe", symbol: "book.pages") {
            TextField("Recipe name", text: $content.name, axis: .vertical)
                .font(.system(.title2, design: .serif).weight(.semibold)).lineLimit(1...3)
                .autocorrectionDisabled().focused($sourceField, equals: "name").frame(minHeight: 44)
                .accessibilityIdentifier("home.recipe.name")
            if showsManual || hasSource || !content.name.isEmpty {
                Text(selectedUse == nil ? "Suggested kind" : "Recipe kind")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                HomeRecipeUsePicker(selection: Binding(get: { recipeUse }, set: { selectedUse = $0 }))
                Text(recipeUse.detail).font(.caption).foregroundStyle(Color.secondaryText)
            } else {
                Text("A name is enough to save an idea.").font(.caption).foregroundStyle(Color.secondaryText)
            }
        }
    }

    @ViewBuilder private var recipePreview: some View {
        if showsManual || !content.ingredients.isEmpty || !content.steps.isEmpty {
            ingredientCard
            HomeEditorSection("How to make it", symbol: "list.number",
                detail: "One clear step at a time. Add instructions whenever you’re ready.") {
                if showsManual { stepRows }
                else {
                    DisclosureGroup("Edit steps", isExpanded: $showsSteps) {
                        VStack(alignment: .leading, spacing: 14) { stepRows }.padding(.top, 12)
                    }
                }
            }.id("recipe.steps")
        }
    }

    private var ingredientCard: some View {
        HomeEditorSection("What goes in", symbol: "list.bullet", detail: "Amounts and units are optional.") {
            ForEach(Array(content.ingredients.enumerated()), id: \.element.id) { index, item in
                ingredientRow(item, index: index)
            }
            Button("Add ingredient", systemImage: "plus") { content.ingredients.append(HomeRecipeIngredient(unit: "")) }
                .frame(minHeight: 44)
        }
    }

    private func ingredientRow(_ item: HomeRecipeIngredient, index: Int) -> some View {
        let ingredient = HomeEditorBindings.item(item, in: $content.ingredients)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("INGREDIENT \(index + 1)").recipeEyebrow()
                Spacer()
                removeRow("Remove ingredient \(index + 1)") {
                    sourceField = nil; content.ingredients.removeAll { $0.id == item.id }
                }
            }
            TextField("Ingredient", text: ingredient.name, axis: .vertical)
                .lineLimit(1...4).focused($sourceField, equals: item.id.uuidString).frame(minHeight: 44)
                .accessibilityIdentifier("home.recipe.capture.ingredient.\(index).name")
            HomeNumberField(title: "Amount", value: ingredient.amount)
            HomeEditorField("Unit", text: ingredient.unit, placeholder: "ml, g, tsp…")
        }
        .padding(12).background(Color.creamWhite, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private var stepRows: some View {
        ForEach(Array(content.steps.enumerated()), id: \.element.id) { index, item in
            let step = HomeEditorBindings.item(item, in: $content.steps)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("STEP \(index + 1)").recipeEyebrow()
                    Spacer()
                    removeRow("Remove step \(index + 1)") {
                        sourceField = nil; content.steps.removeAll { $0.id == item.id }
                    }
                }
                TextField("Instruction", text: step.instruction, axis: .vertical)
                    .lineLimit(2...6).focused($sourceField, equals: item.id.uuidString)
                    .accessibilityIdentifier("home.recipe.capture.step.\(index).instruction")
            }
            .padding(12).background(Color.creamWhite, in: RoundedRectangle(cornerRadius: 14))
        }
        Button("Add a step", systemImage: "plus") { content.steps.append(HomePreparationStep()) }
            .frame(minHeight: 44)
    }

    private func removeRow(_ label: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "minus.circle").frame(width: 44, height: 44)
        }
        .foregroundStyle(Color.secondaryText).accessibilityLabel(label)
    }

    private var sourceAndDetails: some View {
        HomeEditorSection("Source & details", symbol: "link") {
            DisclosureGroup("Source & credit") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Creator credit", text: $content.creatorCredit)
                        .focused($sourceField, equals: "credit").frame(minHeight: 44)
                    if !content.sourceURL.isEmpty { Text(content.sourceURL).font(.caption).textSelection(.enabled) }
                }
                .padding(.top, 10)
            }
            Button("Fine-tune recipe details", systemImage: "slider.horizontal.3") {
                sourceField = nil; content = classifiedContent; showsFullEditor = true
            }
            .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }
    }

    private var saveBar: some View {
        VStack(spacing: 8) {
            if let error {
                Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let onMake, classifiedContent.isReadyToMake, sourceField == nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { saveRecipeAction; saveAndMakeAction(onMake) }
                    VStack(spacing: 8) { saveRecipeAction; saveAndMakeAction(onMake) }
                }
            } else { saveRecipeAction }
        }
        .padding(.horizontal, 22).padding(.vertical, 8)
        .background(Color.creamWhite)
        .overlay(alignment: .top) { Divider() }
        .disabled(!isCurrentOwner || content.name.remoteTrimmedNonEmpty == nil)
    }

    private var saveRecipeAction: some View {
        Button(classifiedContent.isReadyToMake ? "Save recipe" : "Save for later") { save(using: onSaved) }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("home.recipe.saveIdea")
    }

    private func saveAndMakeAction(_ action: @escaping (HomeRecipeRecord, HomeRecipeVersion) -> Void) -> some View {
        Button("Save & make") { save(using: action) }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("home.recipe.saveAndMake")
    }

    private func startManual() {
        sourceField = nil
        showsLink = false; showsCaption = false; showsManual = true; showsSteps = true
        if content.ingredients.isEmpty { content.ingredients.append(HomeRecipeIngredient(unit: "")) }
        if content.steps.isEmpty { content.steps.append(HomePreparationStep()) }
    }

    private var captionInput: Binding<String> {
        Binding(get: { sources.typedCaption }, set: { value in
            sources.typedCaption = value
            updateSourceText(rebuild: false)
        })
    }

    private var videoSelection: Binding<PhotosPickerItem?> {
        Binding(get: { selectedVideo }, set: { item in
            guard item != selectedVideo else { return }
            suspendSourceReading()
            if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
            movieURL = nil
            if imageSource == .video { image = nil; imageSource = nil }
            sources.resetSelectedVideo()
            sourceStatus = nil
            selectedVideo = item
            updateSourceText()
        })
    }

    private var speechToggle: Binding<Bool> {
        Binding(get: { sources.includesSpeech }, set: { enabled in
            guard canRead, movieURL != nil else { return }
            sources.setSpeechEnabled(enabled)
            isReadingSpeech = false
            if !enabled { sourceStatus = "Using video frames and captions." }
            updateSourceText()
        })
    }

    private func sourceIsCurrent(_ operation: UUID) -> Bool {
        !Task.isCancelled && canRead && operation == sourceGeneration
    }

    private func showImportedReview(dismissingKeyboard: Bool = false) {
        guard dismissingKeyboard || sourceField == nil || sourceField == "url" else { return }
        sourceField = nil
        showsLink = false
        showsCaption = false
        showsSources = false
        jump(to: "recipe.review")
    }

    private func jump(to anchor: String) {
        reviewAnchor = anchor
        reviewJump = UUID()
    }

    private func retryLink() {
        shouldReadSharedLink = true
        linkRetry = UUID()
    }

    private func discardSharedSource() {
        guard isCurrentOwner, let sharedSource, let inbox = PocketSipInbox.shared else { return }
        do {
            try inbox.acknowledgeRecipe(sharedSource.id, for: sharedSource.owner)
            stop()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func readLink() async {
        let raw = content.sourceURL
        guard canRead, (try? HomeRecipeSourceURL(raw)) != nil,
              raw != sharedSource?.url || shouldReadSharedLink else { return }
        let operation = UUID()
        sourceGeneration = operation
        assistance.invalidate()
        defer { if operation == sourceGeneration { isReading = false } }
        do {
            try await Task.sleep(for: .milliseconds(750))
            guard sourceIsCurrent(operation), raw == content.sourceURL else { return }
            isReading = true
            let source = try await HomeRecipeSourceReader().read(raw)
            guard sourceIsCurrent(operation), raw == content.sourceURL else { return }
            sources.set(.caption, text: source.text)
            sources.set(.linkedVideo, text: "")
            if imageSource == .linkedVideo { image = nil; imageSource = nil }
            let canReplaceCredit = importedCreatorCredit.map { content.creatorCredit == $0 } ?? content.creatorCredit.isEmpty
            if canReplaceCredit {
                content.creatorCredit = source.creator
                importedCreatorCredit = source.creator
            }
            updateSourceText()
            if let video = source.videoURL {
                do {
                    let local = try await HomeRecipeSourceReader().video(video)
                    defer { try? FileManager.default.removeItem(at: local) }
                    guard sourceIsCurrent(operation), raw == content.sourceURL else { return }
                    let capture = try await HomeRecipeMediaReader().video(at: local)
                    guard sourceIsCurrent(operation), raw == content.sourceURL else { return }
                    applyFrames(capture, kind: .linkedVideo)
                } catch is CancellationError {
                    return
                } catch {
                    guard sourceIsCurrent(operation), raw == content.sourceURL else { return }
                    sourceStatus = "Caption read. The video wasn’t accessible. Add a saved clip or screenshots for more details."
                }
            } else {
                sourceStatus = "Caption read. Add screenshots or a saved video for details that only appear in the video."
            }
            guard sourceIsCurrent(operation), raw == content.sourceURL else { return }
            isReading = false
            restartImport()
            showImportedReview()
        } catch is CancellationError { }
        catch {
            guard sourceIsCurrent(operation), raw == content.sourceURL else { return }
            sourceStatus = (error as? HomeRecipeSourceError)?.localizedDescription ?? HomeRecipeSourceError.unavailable.localizedDescription
        }
    }

    private func loadSharedSource() async {
        guard let sharedSource, canRead, sharedSource.owner.userID == originalScope.userID else { return }
        if let text = sharedSource.text, sources.typedCaption.isEmpty {
            sources.typedCaption = text
            sourceStatus = "Shared text is ready to review."
            updateSourceText()
        }
        guard image == nil, let jpeg = sharedSource.screenshot, let chosen = UIImage(data: jpeg) else { return }
        let operation = UUID()
        sourceGeneration = operation
        isReading = true
        defer { if operation == sourceGeneration { isReading = false } }
        await applyScreenshot(chosen, operation: operation)
    }

    private func loadPhoto() async {
        guard let item = selectedPhoto, canRead else { return }
        let operation = UUID()
        sourceGeneration = operation
        isReading = true
        assistance.invalidate()
        defer { if operation == sourceGeneration { isReading = false } }
        guard let data = try? await item.loadTransferable(type: Data.self), data.count <= 20_000_000,
              sourceIsCurrent(operation), let chosen = UIImage(data: data) else {
            if sourceIsCurrent(operation) { sourceStatus = "Couldn’t open that screenshot. Choose it again or type the recipe." }
            return
        }
        await applyScreenshot(chosen, operation: operation)
    }

    private func applyScreenshot(_ chosen: UIImage, operation: UUID) async {
        image = chosen
        imageSource = .screenshot
        let text = (try? await HomeRecipeMediaReader().text(in: chosen)) ?? ""
        guard sourceIsCurrent(operation) else { return }
        sources.set(.screenshot, text: text)
        sourceStatus = text.isEmpty ? "Screenshot loaded. Mugsy can read visible recipe details, or you can enter them yourself." : "Screenshot text read on your iPhone. Check the extracted recipe details."
        updateSourceText()
        showImportedReview()
    }

    private func loadVideo() async {
        guard let item = selectedVideo, canRead else { return }
        let operation = UUID()
        sourceGeneration = operation
        isReading = true
        assistance.invalidate()
        defer { if operation == sourceGeneration { isReading = false } }
        do {
            guard let movie = try await item.loadTransferable(type: HomeRecipeMovie.self) else { throw HomeRecipeSourceError.invalidMedia }
            guard sourceIsCurrent(operation), item == selectedVideo else {
                try? FileManager.default.removeItem(at: movie.url)
                return
            }
            if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
            movieURL = movie.url
            let capture = try await HomeRecipeMediaReader().video(at: movie.url)
            guard sourceIsCurrent(operation), item == selectedVideo else { return }
            applyFrames(capture, kind: .video)
            showImportedReview()
        } catch is CancellationError { }
        catch {
            guard sourceIsCurrent(operation), item == selectedVideo else { return }
            sourceStatus = (error as? HomeRecipeSourceError)?.localizedDescription ?? HomeRecipeSourceError.invalidMedia.localizedDescription
        }
    }

    private func readSelectedSpeech() async {
        guard !Task.isCancelled, canRead, sources.includesSpeech, let movieURL else { return }
        let generation = sources.speechGeneration
        isReadingSpeech = true
        assistance.invalidate()
        defer {
            if generation == sources.speechGeneration, self.movieURL == movieURL { isReadingSpeech = false }
        }
        do {
            let text = try await HomeRecipeMediaReader().spokenText(at: movieURL)
            guard !Task.isCancelled, canRead, self.movieURL == movieURL,
                  sources.applySpeech(text ?? "", generation: generation) else { return }
            sourceStatus = text == nil ? "This clip has no spoken steps to read." : "Spoken steps read on this iPhone. Check the details before saving."
            updateSourceText()
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, canRead, generation == sources.speechGeneration, self.movieURL == movieURL else { return }
            sourceStatus = "Spoken steps weren’t available. You can use the sampled frames or type the steps."
            restartImport()
        }
    }

    private func applyFrames(_ capture: HomeRecipeVideoCapture, kind: HomeRecipeCaptureSources.Kind) {
        image = capture.image
        imageSource = kind
        sources.set(kind, text: capture.text)
        sourceStatus = "Read \(capture.frameCount) sampled video frames. Check details between the frames."
        updateSourceText()
    }

    private func updateSourceText(rebuild: Bool = true) {
        content.sourceText = sources.text
        if rebuild {
            removeGeneratedFields()
            applyFields(HomeRecipeSourceParser.fields(in: content.sourceText))
        }
        restartImport()
    }

    private func readWithLuna() async {
        let operation = importID
        let speechGeneration = sources.speechGeneration
        guard canRead, hasSource, content.sourceReuseAllowed != false else { return }
        do {
            try await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, operation == importID, canRead, !isReadingSource, hasSource,
                  speechGeneration == sources.speechGeneration, content.sourceReuseAllowed != false else { return }
            removeGeneratedFields()
            applyFields(HomeRecipeSourceParser.fields(in: sources.text))
            guard let owner = originalScope.userID, permission.isEnabled(ownerID: owner) else { return }
            let encoded = try image.map(CoffeeAssistanceImage.encode)
            let includesSpokenText = sources.hasSpokenText
            let request = CoffeeAssistanceRequest(ownerID: owner, task: .recipeImport,
                evidence: CoffeeAssistanceRecipeImport.source(classifiedContent), image: encoded)
            await assistance.run(request, consent: true, currentOwner: { authModel.authenticatedUser?.id })
            guard !Task.isCancelled, operation == importID, canRead, content.sourceReuseAllowed != false,
                  speechGeneration == sources.speechGeneration, permission.isEnabled(ownerID: owner),
                  let result = assistance.result else { return }
            // Spoken results stay in the editable fields tracked by extraction.
            // Attribution comes from the link or the user's explicit entry.
            let fields = includesSpokenText
                ? result.fields.filter { ["name", "method", "ingredient", "step"].contains($0.key) }
                : result.fields
            extraction.replace(fields, to: &content)
            sourceStatus = result.text
        } catch is CancellationError { }
        catch {
            guard operation == importID, canRead else { return }
            self.error = "Couldn’t read that image. Your recipe idea can still be saved."
        }
    }

    private func applyFields(_ fields: [CoffeeAssistanceField]) {
        guard content.sourceReuseAllowed != false else { return }
        extraction.apply(fields, to: &content)
    }
    private func removeGeneratedFields() {
        extraction.removeGenerated(from: &content)
    }
    private func restartImport() { assistance.invalidate(); importID = UUID() }
    private func stop() {
        isFinished = true; sourceGeneration = UUID(); assistance.invalidate()
        if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
    }
    private func save(using action: @escaping (HomeRecipeRecord, HomeRecipeVersion) -> Void) {
        guard isCurrentOwner else { return }
        sourceField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        assistance.invalidate(); sourceGeneration = UUID(); isReading = false
        var saved = classifiedContent
        if let normalized = try? HomeRecipeSourceURL(saved.sourceURL) { saved.sourceURL = normalized.url.absoluteString }
        saved.ingredients.removeAll { $0.name.remoteTrimmedNonEmpty == nil && $0.amount == nil && $0.recipe == nil && $0.unit.isEmpty }
        saved.steps.removeAll { $0.instruction.remoteTrimmedNonEmpty == nil && $0.startSeconds == nil && $0.waitSeconds == nil && $0.waterGrams == nil }
        guard saved.ingredients.allSatisfy({ $0.name.remoteTrimmedNonEmpty != nil || $0.recipe != nil }) else {
            error = "Name each ingredient or remove the unfinished row."
            return
        }
        do { finish(try store.saveRecipe(HomeRecipeEditorDraft(id: saveID, content: saved)), using: action) }
        catch { self.error = error.localizedDescription }
    }
    private func finish(_ id: UUID, using action: ((HomeRecipeRecord, HomeRecipeVersion) -> Void)? = nil) {
        guard isCurrentOwner, let recipe = store.workspace.recipes.first(where: { $0.id == id }), let version = recipe.current else { return }
        if let sharedSource { try? PocketSipInbox.shared?.acknowledgeRecipe(sharedSource.id, for: sharedSource.owner) }
        showsFullEditor = false
        stop()
        (action ?? onSaved)(recipe, version)
    }
}
