import PhotosUI
import SwiftUI

struct CoffeeAssistancePresentation: Identifiable {
    let id = UUID()
    let ownerID: UUID
    let task: CoffeeAssistanceTask
    let query: String
    let evidence: [CoffeeAssistanceEvidence]
    let image: UIImage?
    let allowsPhoto: Bool
}

/// A contextual helper. Presenting it never makes a request or changes source data.
struct CoffeeAssistanceButton: View {
    let ownerID: UUID?
    let task: CoffeeAssistanceTask
    let evidence: [CoffeeAssistanceEvidence]
    var query = ""
    var image: UIImage? = nil
    var allowsPhoto = false
    var acceptanceTitle = "Use reviewed fields"
    var onAccepted: ((CoffeeAssistanceResult) -> Void)? = nil
    var onOpenEvidence: ((String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var presentation: CoffeeAssistancePresentation?

    var body: some View {
        if let ownerID, authModel.authenticatedUser?.id == ownerID {
            Button {
                presentation = CoffeeAssistancePresentation(ownerID: ownerID, task: task,
                    query: query, evidence: evidence, image: image, allowsPhoto: allowsPhoto)
            } label: {
                Label(task.title, systemImage: "sparkles")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("coffeeAssistance.\(task.rawValue)")
            .sheet(item: $presentation) { item in
                CoffeeAssistanceReviewSheet(presentation: item, acceptanceTitle: acceptanceTitle,
                    onAccepted: onAccepted, onOpenEvidence: onOpenEvidence)
            }
        }
    }
}

struct CoffeeAssistanceReviewSheet: View {
    let presentation: CoffeeAssistancePresentation
    var acceptanceTitle = "Use reviewed fields"
    var onAccepted: ((CoffeeAssistanceResult) -> Void)? = nil
    var onOpenEvidence: ((String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: CoffeeAssistanceSession
    private let ownerResolver: (() -> UUID?)?
    @State private var consent = false
    @State private var ownsSource = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageError: String?
    @State private var requested: UUID?
    @State private var fields: [String] = []
    @State private var selectedFields: Set<Int> = []
    @State private var editedText = ""

    init(presentation: CoffeeAssistancePresentation, acceptanceTitle: String = "Use reviewed fields",
         onAccepted: ((CoffeeAssistanceResult) -> Void)? = nil, onOpenEvidence: ((String) -> Void)? = nil,
         transport: (any CoffeeAssistanceTransport)? = nil, currentOwner: (() -> UUID?)? = nil) {
        self.presentation = presentation
        self.acceptanceTitle = acceptanceTitle
        self.onAccepted = onAccepted
        self.onOpenEvidence = onOpenEvidence
        ownerResolver = currentOwner
        _session = StateObject(wrappedValue: CoffeeAssistanceSession(transport: transport))
    }
    private var currentOwnerID: UUID? {
        if let ownerResolver { return ownerResolver() }
        return authModel.authenticatedUser?.id
    }

    private var selectedEvidence: [CoffeeAssistanceEvidence] {
        CoffeeAssistanceRequest(ownerID: presentation.ownerID, task: presentation.task,
            evidence: presentation.evidence).evidence
    }
    private var canAsk: Bool {
        consent && !session.isWorking && currentOwnerID == presentation.ownerID
            && (!selectedEvidence.isEmpty || image != nil)
            && (presentation.task != .recipeImport || ownsSource)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("An optional suggestion from Mugsy")
                        .font(.headline)
                    Text("Your original details stay available. Suggestions can be wrong; check the evidence before using them. Nothing is saved or shared automatically.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Review what you send") {
                    if !presentation.query.isEmpty { Text(presentation.query) }
                    ForEach(selectedEvidence) { item in
                        DisclosureGroup(item.title) { Text(item.detail).textSelection(.enabled) }
                    }
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                            .accessibilityLabel("Selected image for this request")
                        Button("Remove image", role: .destructive) { self.image = nil; reset() }
                    }
                    if presentation.allowsPhoto {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose a recipe screenshot", systemImage: "photo")
                        }.disabled(session.isWorking)
                    }
                    if let imageError { Text(imageError).foregroundStyle(.red) }
                    if presentation.task == .recipeImport {
                        Toggle("I created this recipe or have permission to copy it", isOn: $ownsSource)
                    }
                    Toggle("Allow OpenAI to process only these details for this request", isOn: $consent)
                        .accessibilityIdentifier("coffeeAssistance.consent")
                    Text("This may include private details shown above. It does not change who can see your journal or recipes. OpenAI may retain API content for abuse monitoring; training sharing is off by default. You can leave this helper without sending anything.")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("OpenAI data controls", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                    Button {
                        requested = UUID()
                    } label: {
                        if session.isWorking { ProgressView("Asking Mugsy…") }
                        else { Text("Get a suggestion") }
                    }
                    .disabled(!canAsk)
                    .accessibilityIdentifier("coffeeAssistance.generate")
                }
                if let message = session.message {
                    Section("Your original details are safe") { Text(message) }
                }
                if let result = session.result {
                    resultSection(result)
                }
            }
            .navigationTitle(presentation.task.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { session.invalidate(); dismiss() } } }
            .background(Color.creamWhite)
            .task { image = presentation.image }
            .task(id: requested) {
                guard requested != nil else { return }
                do {
                    let encodedImage = try image.map(CoffeeAssistanceImage.encode)
                    let request = CoffeeAssistanceRequest(ownerID: presentation.ownerID, task: presentation.task,
                        query: presentation.query, evidence: selectedEvidence, image: encodedImage)
                    await session.run(request, consent: consent, currentOwner: { currentOwnerID })
                    if let result = session.result {
                        fields = result.fields.map(\.value)
                        selectedFields = Set(fields.indices)
                        editedText = result.text
                    }
                } catch {
                    imageError = "That image is too large to send safely. Try a closer crop, or continue with manual entry."
                }
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                guard let data = try? await selectedPhoto.loadTransferable(type: Data.self),
                      !Task.isCancelled, let decoded = UIImage(data: data) else { return }
                image = decoded
                reset()
            }
            .onChange(of: consent) { _, value in if !value { reset(); CoffeeAssistanceCache.shared.clear() } }
            .onChange(of: ownsSource) { _, value in if !value && presentation.task == .recipeImport { reset() } }
            .onReceive(authModel.$authenticatedUser) { user in
                if ownerResolver == nil && user?.id != presentation.ownerID { reset(); CoffeeAssistanceCache.shared.clear(); dismiss() }
            }
            .onDisappear { session.invalidate() }
        }
    }

    @ViewBuilder
    private func resultSection(_ result: CoffeeAssistanceResult) -> some View {
        Section("AI suggestion · check before using") {
            if onAccepted != nil && result.fields.isEmpty {
                TextField("Edit the suggestion", text: $editedText, axis: .vertical).lineLimit(3...8)
            } else { Text(result.text) }
            ForEach(Array(result.fields.enumerated()), id: \.offset) { index, field in
                if fields.indices.contains(index) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(field.title, isOn: Binding(get: { selectedFields.contains(index) }, set: {
                            if $0 { selectedFields.insert(index) } else { selectedFields.remove(index) }
                        }))
                        TextField("Suggested value", text: $fields[index], axis: .vertical)
                        Text("From source: \(field.sourceQuote)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(selectedEvidence.filter { result.evidenceIDs.contains($0.id) }) { item in
                if let onOpenEvidence {
                    Button(item.title) { session.invalidate(); dismiss(); onOpenEvidence(item.id) }
                } else {
                    DisclosureGroup("Evidence: \(item.title)") { Text(item.detail) }
                }
            }
            if let onAccepted {
                Button(acceptanceTitle) {
                    guard consent, currentOwnerID == presentation.ownerID else { return }
                    let reviewed = result.fields.enumerated().compactMap { index, field -> CoffeeAssistanceField? in
                        guard selectedFields.contains(index), fields.indices.contains(index), !fields[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                        return CoffeeAssistanceField(key: field.key, value: CoffeeAssistanceText.bound(fields[index], to: 400), sourceQuote: field.sourceQuote)
                    }
                    onAccepted(CoffeeAssistanceResult(text: CoffeeAssistanceText.bound(editedText, to: 1600),
                        evidenceIDs: result.evidenceIDs, fields: reviewed, searchTerms: result.searchTerms))
                    MugshotAnalytics.shared.capture(.coffeeAssistance(task: presentation.task, action: .accepted))
                    session.invalidate()
                    dismiss()
                }
                .disabled(!consent || (result.fields.isEmpty ? editedText.isEmpty : selectedFields.isEmpty))
                .accessibilityIdentifier("coffeeAssistance.accept")
            }
        }
    }
    private func reset() { requested = nil; session.invalidate(); fields = []; selectedFields = []; editedText = "" }
}

enum CoffeeAssistanceImage {
    @MainActor
    static func encode(_ image: UIImage) throws -> String {
        let scale = min(1, 1280 / max(image.size.width, image.size.height))
        guard scale.isFinite, scale > 0 else { throw CoffeeAssistanceError.unavailable }
        let size = CGSize(width: max(1, floor(image.size.width * scale)), height: max(1, floor(image.size.height * scale)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let sanitized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = sanitized.jpegData(compressionQuality: 0.55), data.count <= 290_000 else {
            throw CoffeeAssistanceError.unavailable
        }
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }
}
