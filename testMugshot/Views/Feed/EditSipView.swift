import SwiftUI
import UIKit

struct EditSipView: View {
    let seed: SipPostEditSeed
    let onSave: (SipPostEditDraft) async -> SipDetailEditSaveResult

    @Environment(\.dismiss) private var dismiss
    @State private var draft: SipPostEditDraft
    @State private var pickedImages: [UIImage] = []
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingTagPicker = false
    @State private var isConfirmingTextOnlyPublicPost = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        seed: SipPostEditSeed,
        onSave: @escaping (SipPostEditDraft) async -> SipDetailEditSaveResult
    ) {
        self.seed = seed
        self.onSave = onSave
        _draft = State(initialValue: seed.draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photosSection
                    Divider()
                    captionSection
                    Divider()
                    criteriaSection(
                        title: "Sip criteria",
                        subtitle: "Edit what shaped your sip score.",
                        score: $draft.sipScore,
                        criteria: $draft.sipCriteria,
                        suggestions: LogASipV3CriterionSuggestion.sip,
                        accessibilityScope: "sip"
                    )

                    if supportsContextReflection {
                        Divider()
                        contextCriteriaSection
                    }

                    Divider()
                    journalSection
                    Divider()
                    audienceSection
                    Divider()
                    taggedPeopleSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("editSip.error")
                    }

                    Button(action: save) {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text(isSaving ? "Saving…" : "Save sip")
                                .frame(maxWidth: .infinity)
                        }
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(height: 52)
                        .background(
                            Color.mugshotSage,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.55)
                    .accessibilityIdentifier("editSip.save")
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.creamWhite)
            .navigationTitle("Edit Sip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save", action: save)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isShowingPhotoLibrary, onDismiss: appendPickedImages) {
                PhotoLibraryPickerView(
                    images: $pickedImages,
                    isPresented: $isShowingPhotoLibrary,
                    maximumSelectionCount: max(1, VisitPhotoUploadPlan.maxPhotoCount - draft.photos.count)
                )
            }
            .sheet(isPresented: $isShowingTagPicker) {
                SipCompanionPicker(
                    mode: .tag,
                    selected: draft.taggedPeople,
                    onSave: { draft.taggedPeople = $0 }
                )
            }
            .confirmationDialog(
                "Publish without a photo?",
                isPresented: $isConfirmingTextOnlyPublicPost,
                titleVisibility: .visible
            ) {
                Button("Save public Mugshot") { performSave() }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("This Mugshot will be visible to everyone using its text-only presentation.")
            }
            .onChange(of: draft.postAudience) { _, postAudience in
                if draft.journalAudience.breadth > postAudience.breadth {
                    draft.journalAudience = postAudience
                }
            }
        }
    }

    private var photosSection: some View {
        editSection(title: "Photos", subtitle: "Choose the cover, reorder, add, or remove photos.") {
            if draft.photos.isEmpty {
                ContentUnavailableView(
                    "No photos",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("This Mugshot will use its no-photo presentation.")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(draft.photos.enumerated()), id: \.element.id) { index, photo in
                        EditSipPhotoRow(
                            photo: photo,
                            index: index,
                            isCover: draft.coverPhotoID == photo.id,
                            canMoveUp: index > 0,
                            canMoveDown: index < draft.photos.count - 1,
                            onMakeCover: { draft.coverPhotoID = photo.id },
                            onMoveUp: { movePhoto(from: index, to: index - 1) },
                            onMoveDown: { movePhoto(from: index, to: index + 1) },
                            onRemove: { removePhoto(id: photo.id) }
                        )
                    }
                }
            }

            Button {
                isShowingPhotoLibrary = true
            } label: {
                Label(
                    draft.photos.isEmpty ? "Add photos" : "Add more photos",
                    systemImage: "photo.badge.plus"
                )
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Color.mugshotMint.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.mugshotSage)
            .disabled(draft.photos.count >= VisitPhotoUploadPlan.maxPhotoCount || isSaving)
            .accessibilityIdentifier("editSip.photos.add")

            Text("The cover appears first in Feed, Journal, and the full post.")
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
        }
    }

    private var captionSection: some View {
        editSection(title: "Caption", subtitle: "The public text shown directly below your photos.") {
            TextField("Write a caption", text: $draft.caption, axis: .vertical)
                .lineLimit(3...8)
                .editSipField()
                .accessibilityIdentifier("editSip.caption")

            Text("\(captionCount.formatted()) / \(SipCaptionPolicy.maximumLength.formatted())")
                .font(.caption)
                .foregroundStyle(captionError == nil ? Color.tertiaryText : Color.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var contextCriteriaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(contextLabel) criteria")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text("Update the setting evidence separately from the sip.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                if let contextScore = draft.contextScore {
                    Text(contextScore, format: .number.precision(.fractionLength(1)))
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .monospacedDigit()
                }
            }

            if draft.contextScore != nil {
                MugshotV3HalfStarRating(
                    rating: Binding(
                        get: { draft.contextScore ?? 0.5 },
                        set: { draft.contextScore = $0 }
                    ),
                    label: "\(contextLabel) score",
                    minimumScore: 0.5
                )
            } else {
                Button("Add \(contextLabel.lowercased()) score") {
                    draft.contextScore = 3
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mugshotSage)
            }

            EditSipCriteriaList(
                criteria: $draft.contextCriteria,
                suggestions: contextSuggestions,
                accessibilityScope: "context"
            )
        }
    }

    private var journalSection: some View {
        editSection(
            title: seed.detail.v3Reflection == nil ? "Private journal note" : "Journal note",
            subtitle: seed.detail.v3Reflection == nil
                ? "This older note remains visible only to you."
                : "Your journal writing is separate from the caption."
        ) {
            if seed.detail.v3Reflection == nil {
                TextField(
                    "Only visible to you",
                    text: $draft.legacyPrivateJournalNote,
                    axis: .vertical
                )
                .lineLimit(3...8)
                .editSipField()
            } else {
                TextField("What did you notice about the sip?", text: $draft.sipJournalNote, axis: .vertical)
                    .lineLimit(3...8)
                    .editSipField()
                    .accessibilityIdentifier("editSip.journal.sip")

                if supportsContextReflection {
                    TextField(
                        "What did you notice about the \(contextLabel.lowercased())?",
                        text: $draft.contextJournalNote,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .editSipField()
                    .accessibilityIdentifier("editSip.journal.context")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Journal audience")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.7)
                        .foregroundStyle(Color.mugshotSage)
                    MugshotSegmentedControl(
                        options: journalAudienceOptions,
                        selection: $draft.journalAudience,
                        title: { $0.rawValue }
                    )
                    Text(journalAudienceExplanation)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
    }

    private var audienceSection: some View {
        editSection(title: "Post audience", subtitle: "Controls who can see the complete Mugshot.") {
            MugshotSegmentedControl(
                options: VisitVisibility.allCases,
                selection: $draft.postAudience,
                title: { $0.rawValue }
            )
            .accessibilityIdentifier("editSip.postAudience")
            Text("A journal note can be more private than the post, but never more public.")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var taggedPeopleSection: some View {
        editSection(
            title: "Tagged people",
            subtitle: "Tags add context to your coffee story. They do not create co-owners or change who can see this post."
        ) {
            if draft.taggedPeople.isEmpty {
                Text("No one tagged")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            } else {
                ForEach(draft.taggedPeople) { person in
                    HStack(spacing: 10) {
                        MugshotAvatar(
                            name: person.displayName,
                            size: 36,
                            imageURL: person.avatarURL
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName).font(.subheadline.weight(.semibold))
                            Text("@\(person.username)")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                        Button("Remove") {
                            draft.taggedPeople.removeAll { $0.userID == person.userID }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }

            Button {
                isShowingTagPicker = true
            } label: {
                Label("Edit tagged people", systemImage: "person.crop.circle.badge.plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.mugshotSage)
            .disabled(isSaving)
            .accessibilityIdentifier("editSip.tags.edit")
        }
    }

    private func criteriaSection(
        title: String,
        subtitle: String,
        score: Binding<Double>,
        criteria: Binding<[SipRatingCriterionSnapshot]>,
        suggestions: [LogASipV3CriterionSuggestion],
        accessibilityScope: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                Text(score.wrappedValue, format: .number.precision(.fractionLength(1)))
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .monospacedDigit()
            }
            MugshotV3HalfStarRating(
                rating: score,
                label: "Sip score",
                minimumScore: 0.5
            )
            EditSipCriteriaList(
                criteria: criteria,
                suggestions: suggestions,
                accessibilityScope: accessibilityScope
            )
        }
    }

    private func editSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.espressoBrown)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    private var canSave: Bool {
        !isSaving && validationError == nil
    }

    private var validationError: Error? {
        do {
            _ = try SipPostEditPolicy.normalize(
                draft,
                context: seed.detail.summary.visit.journalContext,
                hasV3Reflection: seed.detail.v3Reflection != nil
            )
            return nil
        } catch {
            return error
        }
    }

    private var captionCount: Int { SipCaptionPolicy.characterCount(draft.caption) }
    private var captionError: SipCaptionValidationError? { SipCaptionPolicy.validationError(for: draft.caption) }

    private var supportsContextReflection: Bool {
        guard seed.detail.v3Reflection != nil else { return false }
        let context = seed.detail.summary.visit.journalContext
        return context != .home && context != .recipe
    }

    private var contextLabel: String {
        switch seed.detail.summary.visit.journalContext {
        case .cafe: "Cafe"
        case .elsewhere: "Setting"
        case .home, .recipe: "Home"
        }
    }

    private var contextSuggestions: [LogASipV3CriterionSuggestion] {
        seed.detail.summary.visit.journalContext == .cafe
            ? LogASipV3CriterionSuggestion.cafe
            : LogASipV3CriterionSuggestion.elsewhere
    }

    private var journalAudienceOptions: [VisitVisibility] {
        VisitVisibility.allCases.filter { $0.breadth <= draft.postAudience.breadth }
    }

    private var journalAudienceExplanation: String {
        switch draft.journalAudience {
        case .private: "The post can be shared, while this journal note remains only yours."
        case .friends: "Only confirmed friends who can see the post can read the journal note."
        case .everyone: "Everyone who can see the post can read the journal note."
        }
    }

    private func appendPickedImages() {
        let remaining = max(0, VisitPhotoUploadPlan.maxPhotoCount - draft.photos.count)
        let additions = pickedImages.prefix(remaining).map { SipPostEditPhoto.added($0) }
        draft.photos.append(contentsOf: additions)
        if draft.coverPhotoID == nil { draft.coverPhotoID = draft.photos.first?.id }
        pickedImages = []
    }

    private func movePhoto(from source: Int, to destination: Int) {
        guard draft.photos.indices.contains(source), draft.photos.indices.contains(destination) else { return }
        let item = draft.photos.remove(at: source)
        draft.photos.insert(item, at: destination)
        MugshotHaptic.softImpact.play()
    }

    private func removePhoto(id: String) {
        draft.photos.removeAll { $0.id == id }
        if draft.coverPhotoID == id { draft.coverPhotoID = draft.photos.first?.id }
    }

    private func save() {
        guard canSave else {
            errorMessage = validationError?.localizedDescription
            return
        }
        if seed.detail.summary.visit.posterPhotoURL != nil,
           draft.photos.isEmpty,
           draft.postAudience == .everyone {
            isConfirmingTextOnlyPublicPost = true
            return
        }
        performSave()
    }

    private func performSave() {
        Task { @MainActor in
            isSaving = true
            errorMessage = nil
            let result = await onSave(draft)
            isSaving = false
            switch result {
            case .success:
                dismiss()
            case .failure(let message):
                errorMessage = message
            }
        }
    }
}

private struct EditSipCriteriaList: View {
    @Binding var criteria: [SipRatingCriterionSnapshot]
    let suggestions: [LogASipV3CriterionSuggestion]
    let accessibilityScope: String

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(criteria.indices), id: \.self) { index in
                EditSipCriterionRow(
                    criterion: $criteria[index],
                    canMoveUp: index > 0,
                    canMoveDown: index < criteria.count - 1,
                    onMoveUp: { move(from: index, to: index - 1) },
                    onMoveDown: { move(from: index, to: index + 1) },
                    onRemove: { remove(at: index) }
                )
                .accessibilityIdentifier("editSip.\(accessibilityScope).criterion.\(index)")
            }

            Menu {
                let available = suggestions.filter { suggestion in
                    !criteria.contains {
                        $0.name.caseInsensitiveCompare(suggestion.title) == .orderedSame
                    }
                }
                ForEach(available) { suggestion in
                    Button(suggestion.title) { add(named: suggestion.title) }
                }
                Button("Custom criterion") { add(named: "") }
            } label: {
                Label("Add criterion", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.sandBeige.opacity(0.52), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.mugshotSage)
            .disabled(criteria.count >= SipPostEditPolicy.maximumCriteriaCount)
        }
    }

    private func add(named name: String) {
        criteria.append(SipRatingCriterionSnapshot(
            name: name,
            score: 3,
            weight: 1,
            sortOrder: criteria.count,
            relevanceOverride: true
        ))
    }

    private func move(from source: Int, to destination: Int) {
        guard criteria.indices.contains(source), criteria.indices.contains(destination) else { return }
        let criterion = criteria.remove(at: source)
        criteria.insert(criterion, at: destination)
        reindex()
    }

    private func remove(at index: Int) {
        guard criteria.indices.contains(index) else { return }
        criteria.remove(at: index)
        reindex()
    }

    private func reindex() {
        for index in criteria.indices { criteria[index].sortOrder = index }
    }
}

private struct EditSipCriterionRow: View {
    @Binding var criterion: SipRatingCriterionSnapshot
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Criterion name", text: $criterion.name)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Menu {
                    Button("Move up", action: onMoveUp).disabled(!canMoveUp)
                    Button("Move down", action: onMoveDown).disabled(!canMoveDown)
                    Button("Delete", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Criterion actions")
            }
            HStack(alignment: .center, spacing: 10) {
                MugshotV3HalfStarRating(
                    rating: $criterion.score,
                    label: criterion.name.remoteTrimmedNonEmpty ?? "Criterion",
                    starSize: 22,
                    spacing: 1,
                    minimumScore: 0.5
                )
                Spacer(minLength: 0)
                Picker("Importance", selection: Binding(
                    get: { criterion.importance },
                    set: { criterion.importance = $0 }
                )) {
                    ForEach(SipCriterionImportance.allCases) { importance in
                        Text(importance.title).tag(importance)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
        .padding(12)
        .background(Color.sandBeige.opacity(0.35), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.mugshotLine, lineWidth: 1))
    }
}

private struct EditSipPhotoRow: View {
    let photo: SipPostEditPhoto
    let index: Int
    let isCover: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMakeCover: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            photoPreview
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Photo \(index + 1)")
                    .font(.subheadline.weight(.bold))
                Button(isCover ? "Cover photo" : "Make cover", action: onMakeCover)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mugshotSage)
                    .disabled(isCover)
            }
            Spacer()
            Menu {
                Button("Make cover", action: onMakeCover).disabled(isCover)
                Button("Move up", action: onMoveUp).disabled(!canMoveUp)
                Button("Move down", action: onMoveDown).disabled(!canMoveDown)
                Button("Delete photo", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Photo \(index + 1) actions")
        }
        .padding(10)
        .background(Color.sandBeige.opacity(0.35), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(isCover ? Color.mugshotSage : Color.mugshotLine, lineWidth: isCover ? 2 : 1)
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        switch photo.source {
        case .existing(let value):
            RemotePhotoImageView(urlString: value, placeholderSystemName: "photo")
        case .added(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}

private extension View {
    func editSipField() -> some View {
        font(.body)
            .padding(14)
            .background(Color.foamWhite)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.mugshotLine, lineWidth: 1))
    }
}

#if DEBUG
struct EditSipPreviewHost: View {
    var body: some View {
        EditSipView(seed: .qualitySprintPreview) { _ in .success }
    }
}

private extension SipPostEditSeed {
    static var qualitySprintPreview: SipPostEditSeed {
        let ownerID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        let visitID = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
        let cafe = SupabaseCafeSummary(
            id: UUID(uuidString: "30000000-0000-4000-8000-000000000001")!,
            name: "Nook Tiny Cafe & Market",
            address: "83 Spring Street",
            city: "Charleston, SC",
            latitude: nil,
            longitude: nil,
            applePlaceId: nil,
            websiteURL: nil
        )
        let visit = SupabaseVisitRow(
            id: visitID,
            userId: ownerID,
            cafeId: cafe.id,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Iced Pistachio Latte",
            caption: "Mid-work day pick me up at Nook! Support your local cafe.",
            notes: nil,
            visibility: "friends",
            ratings: ["Flavor balance": 3.7, "Mouth-feel": 4.2, "Coffee finish": 4.0],
            overallScore: 4.0,
            posterPhotoURL: nil,
            contextType: "Cafe",
            locationName: cafe.name,
            cityState: cafe.city,
            brewMethod: nil,
            createdAt: "2026-08-04T14:30:00Z"
        )
        let reflection = V3VisitReflection(
            visitID: visitID,
            sipScore: 3.8,
            contextScore: 4.2,
            contextCriteria: [
                SipRatingCriterionSnapshot(name: "Atmosphere", score: 4.0, sortOrder: 0),
                SipRatingCriterionSnapshot(name: "Service", score: 4.5, sortOrder: 1)
            ],
            sipRawNote: "Creamy with a coffee-forward finish.",
            contextRawNote: "Quiet back room and a kind barista.",
            rawNoteVisibility: .friends,
            photoFallback: .mugsyMissedPhoto,
            homeMakeAgain: nil
        )
        let tags = [
            RemoteVisitTag(
                userID: UUID(uuidString: "40000000-0000-4000-8000-000000000001")!,
                displayName: "Amanda",
                username: "amanda",
                avatarURL: nil,
                taggedAt: "2026-08-04T14:30:00Z"
            ),
            RemoteVisitTag(
                userID: UUID(uuidString: "40000000-0000-4000-8000-000000000002")!,
                displayName: "Paul",
                username: "paul",
                avatarURL: nil,
                taggedAt: "2026-08-04T14:30:00Z"
            )
        ]
        return SipPostEditSeed(
            detail: RemoteVisitDetail(
                summary: RemoteVisitSummary(visit: visit, cafe: cafe),
                photos: [],
                comments: [],
                likeCount: 12,
                currentUserHasLiked: false,
                v3Reflection: reflection,
                taggedAccounts: tags
            ),
            currentUserID: ownerID
        )
    }
}
#endif
