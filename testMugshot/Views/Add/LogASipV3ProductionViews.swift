import SwiftUI
import UIKit

// MARK: - Production flow

/// The production presentation for Log a Sip V3.
///
/// Persistence, media acquisition, cafe search, friend lookup, and publication
/// remain owned by the existing composer host. This view only renders and edits
/// the supplied durable state.
struct LogASipV3ProductionView: View {
    @Binding var draft: SipDraft
    @Binding var photoImages: [UIImage]
    @Binding var step: SipV3ComposerStep

    let isSaving: Bool
    let isDraftSaved: Bool
    let isRecoveryLocked: Bool
    let statusMessage: String?
    let isOpeningPublishedMugshot: Bool
    let completionStatusMessage: String?
    let completion: LogASipV3PassportSummary?
    let wantToTryAchievementCafeName: String?
    let canUseLastSipSetup: Bool
    let canUseLastContextSetup: Bool
    let onCancel: () -> Void
    let onAddPhoto: () -> Void
    let onOrganizePhotos: () -> Void
    let onChooseCafe: () -> Void
    let onTagPeople: () -> Void
    let onRepairProtectedSave: (() -> Void)?
    let onDiscardProtectedSave: (() -> Void)?
    let onUseLastSipSetup: () -> Void
    let onUseLastContextSetup: () -> Void
    let onPublish: () -> Void
    let onViewPublishedMugshot: () -> Void
    let onViewPassport: () -> Void
    let onUndoWantToTryRemoval: () -> Void
    let onFinish: () -> Void
    let onStartAnother: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presentedSheet: LogASipV3Sheet?
    @State private var sipCoachIndex = 0
    @State private var contextCoachIndex = 0

    init(
        draft: Binding<SipDraft>,
        photoImages: Binding<[UIImage]>,
        step: Binding<SipV3ComposerStep>,
        isSaving: Bool,
        isDraftSaved: Bool = false,
        isRecoveryLocked: Bool = false,
        statusMessage: String? = nil,
        isOpeningPublishedMugshot: Bool = false,
        completionStatusMessage: String? = nil,
        completion: LogASipV3PassportSummary? = nil,
        wantToTryAchievementCafeName: String? = nil,
        canUseLastSipSetup: Bool = false,
        canUseLastContextSetup: Bool = false,
        onCancel: @escaping () -> Void,
        onAddPhoto: @escaping () -> Void,
        onOrganizePhotos: @escaping () -> Void,
        onChooseCafe: @escaping () -> Void,
        onTagPeople: @escaping () -> Void,
        onRepairProtectedSave: (() -> Void)? = nil,
        onDiscardProtectedSave: (() -> Void)? = nil,
        onUseLastSipSetup: @escaping () -> Void = {},
        onUseLastContextSetup: @escaping () -> Void = {},
        onPublish: @escaping () -> Void,
        onViewPublishedMugshot: @escaping () -> Void = {},
        onViewPassport: @escaping () -> Void = {},
        onUndoWantToTryRemoval: @escaping () -> Void = {},
        onFinish: @escaping () -> Void = {},
        onStartAnother: (() -> Void)? = nil
    ) {
        _draft = draft
        _photoImages = photoImages
        _step = step
        self.isSaving = isSaving
        self.isDraftSaved = isDraftSaved
        self.isRecoveryLocked = isRecoveryLocked
        self.statusMessage = statusMessage
        self.isOpeningPublishedMugshot = isOpeningPublishedMugshot
        self.completionStatusMessage = completionStatusMessage
        self.completion = completion
        self.wantToTryAchievementCafeName = wantToTryAchievementCafeName
        self.canUseLastSipSetup = canUseLastSipSetup
        self.canUseLastContextSetup = canUseLastContextSetup
        self.onCancel = onCancel
        self.onAddPhoto = onAddPhoto
        self.onOrganizePhotos = onOrganizePhotos
        self.onChooseCafe = onChooseCafe
        self.onTagPeople = onTagPeople
        self.onRepairProtectedSave = onRepairProtectedSave
        self.onDiscardProtectedSave = onDiscardProtectedSave
        self.onUseLastSipSetup = onUseLastSipSetup
        self.onUseLastContextSetup = onUseLastContextSetup
        self.onPublish = onPublish
        self.onViewPublishedMugshot = onViewPublishedMugshot
        self.onViewPassport = onViewPassport
        self.onUndoWantToTryRemoval = onUndoWantToTryRemoval
        self.onFinish = onFinish
        self.onStartAnother = onStartAnother
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamWhite.ignoresSafeArea()

                if let completion {
                    Group {
                        if MugshotShareFeatureFlags.isEnabled(MugshotShareFeatureFlags.hub) {
                            MugshotShareHubView(
                                summary: completion,
                                isOpeningMugshot: isOpeningPublishedMugshot,
                                statusMessage: completionStatusMessage,
                                onViewMugshot: onViewPublishedMugshot,
                                onViewPassport: onViewPassport,
                                onFinish: onFinish,
                                onStartAnother: onStartAnother
                            )
                        } else {
                            LogASipV3PassportCompletionView(
                                summary: completion,
                                isOpeningMugshot: isOpeningPublishedMugshot,
                                statusMessage: completionStatusMessage,
                                onViewMugshot: onViewPublishedMugshot,
                                onFinish: onFinish,
                                onStartAnother: onStartAnother
                            )
                        }
                    }
                    .transition(.opacity)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if let cafeName = wantToTryAchievementCafeName {
                            WantToTryAchievementBanner(
                                cafeName: cafeName,
                                reduceMotion: reduceMotion,
                                onUndo: onUndoWantToTryRemoval
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                } else {
                    currentSurface
                        .id(step)
                        .transition(stepTransition)
                }
            }
            .foregroundStyle(Color.espressoBrown)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: dismissKeyboard)
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheetContent(sheet)
                    .presentationBackground(Color.creamWhite)
            }
            .onChange(of: draft.visibility) { _, visibility in
                if draft.rawNoteVisibility.breadth > visibility.breadth {
                    draft.rawNoteVisibility = visibility
                }
            }
            .onChange(of: photoImages.count) { _, count in
                guard count > 0 else { return }
                draft.photoFallback = nil
                draft.posterPhotoIndex = min(
                    max(draft.posterPhotoIndex, 0),
                    max(count - 1, 0)
                )
            }
        }
    }

    @ViewBuilder
    private var currentSurface: some View {
        switch step {
        case .setup:
            LogASipV3SetupSurface(
                draft: $draft,
                photoImages: $photoImages,
                isDraftSaved: isDraftSaved,
                isRecoveryLocked: isRecoveryLocked,
                onAddPhoto: onAddPhoto,
                onOrganizePhotos: onOrganizePhotos,
                onChooseCafe: onChooseCafe,
                onContinue: { move(to: .sip) }
            )
        case .sip:
            LogASipV3SipSurface(
                draft: $draft,
                coverImage: selectedCoverImage,
                coachIndex: $sipCoachIndex,
                isRecoveryLocked: isRecoveryLocked,
                canUseLastSetup: canUseLastSipSetup,
                onEditSetup: { move(to: .setup) },
                onExploreFlavors: { presentedSheet = .flavors },
                onAddCriterion: { presentedSheet = .addCriterion(.sip) },
                onUseLastSetup: onUseLastSipSetup,
                onContinue: { move(to: .context) }
            )
        case .context:
            LogASipV3ContextSurface(
                draft: $draft,
                coachIndex: $contextCoachIndex,
                isRecoveryLocked: isRecoveryLocked,
                canUseLastSetup: canUseLastContextSetup,
                onAddCriterion: { presentedSheet = .addCriterion(.context) },
                onUseLastSetup: onUseLastContextSetup,
                onContinue: { move(to: .publish) }
            )
        case .publish:
            LogASipV3PublishSurface(
                draft: $draft,
                photoImages: $photoImages,
                isSaving: isSaving,
                isRecoveryLocked: isRecoveryLocked,
                statusMessage: statusMessage,
                onTagPeople: onTagPeople,
                onRepairProtectedSave: onRepairProtectedSave,
                onDiscardProtectedSave: onDiscardProtectedSave,
                onPublish: onPublish
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 4) {
                Button(action: completion == nil ? onCancel : onFinish) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Color.foamWhite, in: Circle())
                        .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .accessibilityLabel(completion == nil ? "Close Log a Sip" : "Close Taste Passport")

                if completion == nil, step != .setup {
                    Button(action: moveBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .accessibilityLabel("Previous step")
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if completion != nil {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("5 of 5")
                }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .accessibilityLabel("Step 5 of 5, published")
            } else {
                Text("\(stepNumber) of 5")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .fixedSize(horizontal: true, vertical: true)
                    .accessibilityLabel("Step \(stepNumber) of 5")
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: LogASipV3Sheet) -> some View {
        switch sheet {
        case .flavors:
            LogASipV3FlavorHelperSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .addCriterion(let target):
            LogASipV3AddCriterionSheet(target: target) { name in
                addCustomCriterion(name, to: target)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var stepNumber: Int {
        switch step {
        case .setup: return 1
        case .sip: return 2
        case .context: return 3
        case .publish: return 4
        }
    }

    private var selectedCoverImage: UIImage? {
        guard !photoImages.isEmpty else { return nil }
        let index = min(max(draft.posterPhotoIndex, 0), photoImages.count - 1)
        return photoImages[index]
    }

    private func move(to destination: SipV3ComposerStep) {
        withAnimation(reduceMotion ? nil : DesignSystem.Motion.slow) {
            step = destination
        }
        MugshotHaptic.softImpact.play()
    }

    private func moveBack() {
        switch step {
        case .setup: break
        case .sip: move(to: .setup)
        case .context: move(to: .sip)
        case .publish: move(to: .context)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func addCustomCriterion(_ rawName: String, to target: LogASipV3CriterionTarget) {
        guard let name = rawName.remoteTrimmedNonEmpty else { return }
        switch target {
        case .sip:
            guard !draft.ratingCriteria.contains(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }) else { return }
            draft.ratingCriteria.append(SipRatingCriterionSnapshot(
                name: name,
                weight: 1,
                sortOrder: draft.ratingCriteria.count,
                isPinned: false
            ))
        case .context:
            guard !draft.contextRatingCriteria.contains(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }) else { return }
            draft.contextRatingCriteria.append(SipRatingCriterionSnapshot(
                name: name,
                weight: 1,
                sortOrder: draft.contextRatingCriteria.count,
                isPinned: false
            ))
        }
    }
}

private struct WantToTryAchievementBanner: View {
    let cafeName: String
    let reduceMotion: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if reduceMotion {
                    MugsyModelView(configuration: configuration)
                } else {
                    MugsyAnimatedView(
                        configuration: configuration,
                        action: .celebrating,
                        tapBehavior: .disabled
                    )
                }
            }
            .frame(width: 58, height: 58)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("You tried a saved cafe")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text("\(cafeName) was removed from Want to Try.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
            Button("Undo", action: onUndo)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.mugshotSageText)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mugshotMint.opacity(0.30), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mugshotSageText, lineWidth: 1.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Achievement. You tried \(cafeName). Removed from Want to Try.")
    }

    private var configuration: MugsyModelConfiguration {
        MugsyModelConfiguration(
            expression: .delighted,
            prop: .wishlistBadge,
            outfit: .cafeScout,
            pose: .leaningRight
        )
    }
}

// MARK: - Setup

private struct LogASipV3SetupSurface: View {
    @Binding var draft: SipDraft
    @Binding var photoImages: [UIImage]

    let isDraftSaved: Bool
    let isRecoveryLocked: Bool
    let onAddPhoto: () -> Void
    let onOrganizePhotos: () -> Void
    let onChooseCafe: () -> Void
    let onContinue: () -> Void

    private var contextSelection: Binding<JournalEntryContext> {
        Binding(
            get: { draft.context == .recipe ? .home : draft.context },
            set: { draft.selectV3Context($0) }
        )
    }

    private var recipeSelection: Binding<Bool> {
        Binding(
            get: { draft.context == .recipe },
            set: { draft.context = $0 ? .recipe : .home }
        )
    }

    private var hasVisual: Bool {
        !photoImages.isEmpty || draft.photoFallback == .mugsyMissedPhoto
    }

    private var placeholderBinding: Binding<Bool> {
        Binding(
            get: { photoImages.isEmpty && draft.photoFallback == .mugsyMissedPhoto },
            set: { usesPlaceholder in
                draft.photoFallback = usesPlaceholder ? .mugsyMissedPhoto : nil
            }
        )
    }

    private var hasContext: Bool {
        switch draft.context {
        case .cafe: return draft.cafe != nil
        case .home, .recipe, .elsewhere:
            return draft.locationName.remoteTrimmedNonEmpty != nil
        }
    }

    private var canContinue: Bool {
        hasVisual && hasContext && draft.drinkName.remoteTrimmedNonEmpty != nil
    }

    var body: some View {
        LogASipV3ScrollableSurface(
            actionTitle: "Start my reflection",
            actionSubtitle: setupActionSubtitle,
            actionIcon: "arrow.right",
            actionEnabled: canContinue,
            contentEnabled: !isRecoveryLocked,
            action: onContinue
        ) {
            MugshotScreenHeader("Log a Sip") {
                Label(
                    isDraftSaved ? "Draft saved" : "Drafts save automatically",
                    systemImage: isDraftSaved ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDraftSaved ? Color.mugshotSage : Color.tertiaryText)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MugshotSegmentedControl(
                options: [JournalEntryContext.cafe, .home, .elsewhere],
                selection: contextSelection,
                title: { $0.rawValue },
                icon: { contextIcon($0) },
                accessibilityIdentifier: { context in
                    "logASipV3.context.\(context.rawValue.lowercased())"
                }
            )
            .padding(.horizontal, DesignSystem.Space.md)

            if draft.context == .home || draft.context == .recipe {
                VStack(alignment: .leading, spacing: 8) {
                    LogASipV3SectionHeader(
                        title: "Home memory",
                        subtitle: "A recipe keeps an independently shareable blueprint."
                    )
                    MugshotSegmentedControl(
                        options: [false, true],
                        selection: recipeSelection,
                        title: { $0 ? "Recipe" : "One-time brew" },
                        icon: { $0 ? "book.pages.fill" : "clock.arrow.circlepath" },
                        accessibilityIdentifier: { value in
                            value ? "logASipV3.home.recipe" : "logASipV3.home.oneTime"
                        }
                    )
                }
                .padding(.horizontal, DesignSystem.Space.md)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Space.sm) {
                LogASipV3SectionHeader(
                    title: "Photos",
                    subtitle: "Tap any photo to make it your cover."
                )

                LogASipV3PhotoStrip(
                    images: photoImages,
                    posterPhotoIndex: $draft.posterPhotoIndex,
                    usesPlaceholder: placeholderBinding,
                    onAddPhoto: onAddPhoto
                )

                HStack(spacing: 8) {
                    if photoImages.isEmpty {
                        Button {
                            draft.photoFallback = draft.photoFallback == .mugsyMissedPhoto
                                ? nil
                                : .mugsyMissedPhoto
                        } label: {
                            Label(
                                draft.photoFallback == .mugsyMissedPhoto ? "Use my photos" : "I missed the photo",
                                systemImage: draft.photoFallback == .mugsyMissedPhoto ? "photo.on.rectangle" : "mug.fill"
                            )
                            .frame(minHeight: 44)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("logASipV3.photoFallback.missed")
                    }

                    Spacer()

                    if photoImages.count > 1 {
                        Button(action: onOrganizePhotos) {
                            Label("Reorder", systemImage: "rectangle.2.swap")
                                .frame(minHeight: 44)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Space.md)

            LogASipV3LabeledField(
                title: "Drink name",
                placeholder: "What are you sipping?",
                text: $draft.drinkName,
                systemImage: "cup.and.saucer.fill",
                accessibilityIdentifier: "logASipV3.drinkName"
            )
            .padding(.horizontal, DesignSystem.Space.md)

            contextField
                .padding(.horizontal, DesignSystem.Space.md)

            Text(contextHelper)
                .font(.system(size: 12))
                .foregroundStyle(Color.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DesignSystem.Space.md)
        }
    }

    @ViewBuilder
    private var contextField: some View {
        switch draft.context {
        case .cafe:
            Button(action: onChooseCafe) {
                HStack(spacing: 12) {
                    Image(systemName: "storefront.fill")
                        .foregroundStyle(Color.mugshotSage)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Cafe")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.tertiaryText)
                        Text(draft.cafe?.consumerDisplayName ?? "Choose a cafe")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.espressoBrown)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.mugshotSage)
                }
                .padding(14)
                .frame(minHeight: 58)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                        .stroke(Color.mugshotLine, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("logASipV3.cafe.selector")
            .accessibilityLabel("Cafe")
            .accessibilityValue(draft.cafe?.consumerDisplayName ?? "Choose a cafe")
            .accessibilityHint("Opens cafe search")
        case .home, .recipe:
            LogASipV3LabeledField(
                title: "Home setup",
                placeholder: "Joe’s Home Cafe",
                text: $draft.locationName,
                systemImage: "house.fill",
                accessibilityIdentifier: "logASipV3.locationName"
            )
        case .elsewhere:
            LogASipV3LabeledField(
                title: "Setting",
                placeholder: "Train, campsite, office…",
                text: $draft.locationName,
                systemImage: "mappin.and.ellipse",
                accessibilityIdentifier: "logASipV3.locationName"
            )
        }
    }

    private var setupActionSubtitle: String {
        guard canContinue else {
            if !hasVisual { return "Add a photo or choose Mugsy’s placeholder." }
            if draft.drinkName.remoteTrimmedNonEmpty == nil { return "Name the drink you want to remember." }
            return draft.context == .cafe ? "Choose the cafe." : "Name this setting."
        }
        return "Sip first, then reflect on the setting."
    }

    private var contextHelper: String {
        switch draft.context {
        case .cafe:
            return "The cafe is part of this memory, so you will reflect on it once."
        case .home, .recipe:
            return "Save as much or as little recipe evidence as helps future you."
        case .elsewhere:
            return "Name the setting in your own words. Exact location is never required."
        }
    }

    private func contextIcon(_ context: JournalEntryContext) -> String? {
        switch context {
        case .cafe: return "storefront"
        case .home, .recipe: return "house"
        case .elsewhere: return "mappin.and.ellipse"
        }
    }
}

// MARK: - Sip reflection

private struct LogASipV3SipSurface: View {
    @Binding var draft: SipDraft
    let coverImage: UIImage?
    @Binding var coachIndex: Int

    let isRecoveryLocked: Bool
    let canUseLastSetup: Bool
    let onEditSetup: () -> Void
    let onExploreFlavors: () -> Void
    let onAddCriterion: () -> Void
    let onUseLastSetup: () -> Void
    let onContinue: () -> Void

    private var suggestedScore: Double? {
        SipRatingCriterionSnapshot.weightedSuggestion(for: draft.ratingCriteria)
    }

    var body: some View {
        LogASipV3ScrollableSurface(
            actionTitle: continueTitle,
            actionSubtitle: draft.overallScore > 0
                ? "Your overall score stays yours."
                : "Choose one honest overall sip score.",
            actionIcon: "arrow.right",
            actionEnabled: draft.overallScore > 0,
            contentEnabled: !isRecoveryLocked,
            action: onContinue
        ) {
            MugshotScreenHeader(
                "How was the sip?",
                subtitle: "Capture the feeling first. Details are optional."
            )

            LogASipV3MemorySummary(
                image: coverImage,
                title: draft.drinkName,
                subtitle: draft.contextDisplayNameV3,
                onEdit: onEditSetup
            )
            .padding(.horizontal, DesignSystem.Space.md)

            LogASipV3JournalEditor(
                title: "Just for my journal",
                prompt: "What hit first? What stayed with you?",
                text: $draft.privateNotes,
                privacyLabel: "Private unless you choose otherwise"
            )
            .padding(.horizontal, DesignSystem.Space.md)

            LogASipV3MugsyCoach(
                prompts: LogASipV3CoachPrompt.sip,
                index: $coachIndex,
                onExploreFlavors: onExploreFlavors
            )
            .padding(.horizontal, DesignSystem.Space.md)

            LogASipV3ScoreBlock(
                title: "Sip score",
                subtitle: "How it worked for you",
                score: $draft.overallScore,
                accessibilityLabel: "Sip score"
            )
            .padding(.horizontal, DesignSystem.Space.md)

            LogASipV3CriteriaEditor(
                title: "What shaped it?",
                subtitle: "Optional",
                suggestionLabel: "Suggested for this drink",
                criteria: $draft.ratingCriteria,
                suggestions: LogASipV3CriterionSuggestion.sip,
                accessibilityScope: "sip",
                canUseLastSetup: canUseLastSetup,
                onUseLastSetup: onUseLastSetup,
                onAddOwn: onAddCriterion
            )
            .padding(.horizontal, DesignSystem.Space.md)

            if let suggestedScore {
                LogASipV3ScoreGuidance(
                    suggestedScore: suggestedScore,
                    currentScore: draft.overallScore,
                    onUse: { draft.overallScore = suggestedScore }
                )
                .padding(.horizontal, DesignSystem.Space.md)
            }
        }
    }

    private var continueTitle: String {
        switch draft.context {
        case .cafe: return "Continue to cafe"
        case .home, .recipe: return "Continue to home"
        case .elsewhere: return "Continue to setting"
        }
    }
}

// MARK: - Context reflection

private struct LogASipV3ContextSurface: View {
    @Binding var draft: SipDraft
    @Binding var coachIndex: Int

    let isRecoveryLocked: Bool
    let canUseLastSetup: Bool
    let onAddCriterion: () -> Void
    let onUseLastSetup: () -> Void
    let onContinue: () -> Void

    private var suggestedScore: Double? {
        SipRatingCriterionSnapshot.weightedSuggestion(for: draft.contextRatingCriteria)
    }

    private var isCafe: Bool { draft.context == .cafe }
    private var isHome: Bool { draft.context == .home || draft.context == .recipe }

    private var canContinue: Bool {
        !isCafe || (draft.contextScore ?? 0) >= 1
    }

    private var contextScoreBinding: Binding<Double> {
        Binding(
            get: { draft.contextScore ?? 0 },
            set: {
                guard $0 > 0 else {
                    draft.contextScore = nil
                    return
                }
                draft.contextScore = isCafe ? max(1, $0) : $0
            }
        )
    }

    var body: some View {
        LogASipV3ScrollableSurface(
            actionTitle: "Review & share",
            actionSubtitle: canContinue
                ? "One Mugshot for the whole memory."
                : "Choose an overall cafe score.",
            actionIcon: "arrow.right",
            actionEnabled: canContinue,
            contentEnabled: !isRecoveryLocked,
            action: onContinue
        ) {
            MugshotScreenHeader(reflectionTitle, subtitle: draft.contextDisplayNameV3)

            LogASipV3JournalEditor(
                title: isHome ? "What did you change?" : "Just for my journal",
                prompt: journalPrompt,
                text: $draft.contextNotes,
                privacyLabel: "Private unless you choose otherwise",
                minimumHeight: 112
            )
            .padding(.horizontal, DesignSystem.Space.md)

            LogASipV3MugsyCoach(
                prompts: contextPrompts,
                index: $coachIndex,
                onExploreFlavors: nil
            )
                .padding(.horizontal, DesignSystem.Space.md)

            if isHome {
                LogASipV3HomeReflection(draft: $draft)
                    .padding(.horizontal, DesignSystem.Space.md)
            } else {
                LogASipV3ScoreBlock(
                    title: isCafe ? "Cafe score" : "Setting score",
                    subtitle: isCafe
                        ? "How the cafe shaped the visit"
                        : "Optional · how the setting shaped the memory",
                    score: contextScoreBinding,
                    accessibilityLabel: isCafe ? "Cafe score" : "Setting score",
                    minimumScore: isCafe ? 1 : 0.5
                )
                .padding(.horizontal, DesignSystem.Space.md)

                LogASipV3CriteriaEditor(
                    title: "What shaped it?",
                    subtitle: "Optional",
                    suggestionLabel: isCafe ? "Suggested for this cafe" : "Suggested for this setting",
                    criteria: $draft.contextRatingCriteria,
                    suggestions: isCafe
                        ? LogASipV3CriterionSuggestion.cafe
                        : LogASipV3CriterionSuggestion.elsewhere,
                    accessibilityScope: isCafe ? "cafe" : "setting",
                    canUseLastSetup: canUseLastSetup,
                    onUseLastSetup: onUseLastSetup,
                    onAddOwn: onAddCriterion
                )
                .padding(.horizontal, DesignSystem.Space.md)

                if let suggestedScore {
                    LogASipV3ScoreGuidance(
                        suggestedScore: suggestedScore,
                        currentScore: draft.contextScore ?? 0,
                        onUse: {
                            draft.contextScore = isCafe ? max(1, suggestedScore) : suggestedScore
                        }
                    )
                    .padding(.horizontal, DesignSystem.Space.md)
                }
            }
        }
    }

    private var reflectionTitle: String {
        if isHome { return "Would you make it again?" }
        return isCafe ? "How was the cafe?" : "How was the setting?"
    }

    private var journalPrompt: String {
        if isHome { return "What did you try, and what might future you repeat?" }
        return isCafe
            ? "How did the room, service, and value feel?"
            : "How did this place change the memory?"
    }

    private var contextPrompts: [LogASipV3CoachPrompt] {
        if isHome { return LogASipV3CoachPrompt.home }
        return isCafe ? LogASipV3CoachPrompt.cafe : LogASipV3CoachPrompt.elsewhere
    }
}

// MARK: - Publish

private struct LogASipV3PublishSurface: View {
    @Binding var draft: SipDraft
    @Binding var photoImages: [UIImage]

    let isSaving: Bool
    let isRecoveryLocked: Bool
    let statusMessage: String?
    let onTagPeople: () -> Void
    let onRepairProtectedSave: (() -> Void)?
    let onDiscardProtectedSave: (() -> Void)?
    let onPublish: () -> Void

    @State private var previewIndex = 0
    @State private var showsCriteria = false

    private var isHome: Bool { draft.context == .home || draft.context == .recipe }
    private var hasRequiredContextScore: Bool {
        draft.context != .cafe || (draft.contextScore ?? 0) >= 1
    }

    private var isReadyToPublish: Bool {
        draft.drinkName.remoteTrimmedNonEmpty != nil
            && SipCaptionPolicy.validationError(for: draft.socialCaption) == nil
            && draft.overallScore > 0
            && hasRequiredContextScore
            && (!photoImages.isEmpty || draft.photoFallback == .mugsyMissedPhoto)
            && draft.recipePublicationRequirement == .ready
    }

    private var contextScoreForBlend: Double? {
        if isHome { return nil }
        guard let contextScore = draft.contextScore, contextScore > 0 else { return nil }
        return contextScore
    }

    private var mugshotScore: Double {
        LogASipV3ScoreMath.mugshotScore(
            sipScore: draft.overallScore,
            contextScore: contextScoreForBlend
        )
    }

    var body: some View {
        LogASipV3ScrollableSurface(
            actionTitle: isSaving ? "Publishing Mugshot…" : "Publish Mugshot",
            actionSubtitle: publishSubtitle,
            actionIcon: "arrow.up.circle.fill",
            actionEnabled: isReadyToPublish
                && !isSaving
                && onDiscardProtectedSave == nil,
            showsProgress: isSaving,
            statusMessage: statusMessage,
            contentEnabled: !isRecoveryLocked,
            recoveryPrimaryTitle: onRepairProtectedSave == nil ? nil : "Replace photos",
            recoveryPrimaryAction: onRepairProtectedSave,
            recoverySecondaryTitle: onDiscardProtectedSave == nil
                ? nil
                : "Discard interrupted save",
            recoverySecondaryAction: onDiscardProtectedSave,
            action: onPublish
        ) {
            MugshotScreenHeader(
                "Publish Mugshot",
                subtitle: "Review the memory before it reaches your people."
            )

            LogASipV3PublishMediaCard(
                images: photoImages,
                posterPhotoIndex: draft.posterPhotoIndex,
                usesPlaceholder: draft.photoFallback == .mugsyMissedPhoto,
                previewIndex: $previewIndex,
                drinkName: draft.drinkName,
                contextName: draft.contextDisplayNameV3,
                createdAt: draft.createdAt
            )
            .padding(.horizontal, DesignSystem.Space.md)

            VStack(alignment: .leading, spacing: 8) {
                LogASipV3SectionHeader(title: "Caption", subtitle: "Required · written by you")
                TextField("Say it your way", text: $draft.socialCaption, axis: .vertical)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .lineLimit(2...4)
                    .padding(14)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                            .stroke(
                                captionIsOverLimit ? Color.red : Color.mugshotLine,
                                lineWidth: captionIsOverLimit ? 1.5 : 1
                            )
                    )
                    .accessibilityIdentifier("logASipV3.caption")

                Text("\(captionCharacterCount.formatted()) / \(SipCaptionPolicy.maximumLength.formatted())")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(captionIsOverLimit ? Color.red : Color.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, DesignSystem.Space.md)

            LogASipV3ScoreEquation(
                sipScore: draft.overallScore,
                contextScore: contextScoreForBlend,
                contextLabel: draft.context == .cafe ? "Cafe" : "Setting",
                mugshotScore: mugshotScore,
                sipCriteria: draft.ratingCriteria,
                contextCriteria: draft.contextRatingCriteria,
                showsCriteria: $showsCriteria
            )
            .padding(.horizontal, DesignSystem.Space.md)

            VStack(spacing: 0) {
                LogASipV3VisibilitySelector(
                    title: "Audience",
                    detail: "Who can see the finished Mugshot",
                    systemImage: "person.2.fill",
                    selection: $draft.visibility,
                    enabledOptions: VisitVisibility.allCases
                )

                Divider().padding(.leading, 54)

                LogASipV3VisibilitySelector(
                    title: "Raw note",
                    detail: "Never broader than your Mugshot",
                    systemImage: "lock.doc.fill",
                    selection: $draft.rawNoteVisibility,
                    enabledOptions: VisitVisibility.allCases.filter {
                        $0.breadth <= draft.visibility.breadth
                    }
                )

                Divider().padding(.leading, 54)

                if draft.includesRecipeBlueprint {
                    LogASipV3RecipeSharingControls(draft: $draft)
                    Divider().padding(.leading, 54)
                }

                LogASipV3PeopleStrip(
                    title: "Tag people",
                    emptyDetail: "Attribute anyone without sharing ownership",
                    populatedDetail: { "\($0) tagged" },
                    systemImage: "person.crop.circle.badge.plus",
                    people: draft.taggedCompanions ?? [],
                    actionAccessibilityLabel: "Choose people to tag",
                    action: onTagPeople
                )

            }
            .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
            .padding(.horizontal, DesignSystem.Space.md)

            Label("Your journal stays yours.", systemImage: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.tertiaryText)
                .frame(maxWidth: .infinity)
        }
        .onAppear {
            previewIndex = min(
                max(draft.posterPhotoIndex, 0),
                max(photoImages.count - 1, 0)
            )
        }
    }

    private var captionCharacterCount: Int {
        SipCaptionPolicy.characterCount(draft.socialCaption)
    }

    private var captionIsOverLimit: Bool {
        captionCharacterCount > SipCaptionPolicy.maximumLength
    }

    private var publishSubtitle: String {
        if isSaving { return "Your draft stays protected until publishing finishes." }
        if isRecoveryLocked { return "Retry uses the protected copy so nothing changes mid-upload." }
        switch draft.recipePublicationRequirement {
        case .ready:
            break
        case .needsImmutableSource:
            return "Reconnect this adaptation to its exact source recipe."
        case .sourceCannotBePublic:
            return "This source cannot share recipe instructions with Everyone."
        case .needsRedistributionPermission:
            return "Confirm that this recipe may be saved and adapted."
        case .needsPublicReuseAcknowledgment:
            return "Acknowledge public recipe reuse before publishing."
        }
        guard isReadyToPublish else { return "Finish the required details to publish." }
        switch draft.visibility {
        case .private: return "Only you will see this."
        case .friends: return "Ready for friends."
        case .everyone: return "Ready for everyone."
        }
    }
}

// MARK: - Passport completion

struct LogASipV3PassportSummary {
    let visitID: UUID
    let visibility: VisitVisibility
    let isOwner: Bool
    let isRemote: Bool
    let displayName: String
    let drinkName: String
    let contextName: String
    let createdAt: Date
    let sipScore: Double
    let contextScore: Double?
    let mugshotScore: Double
    let identityTitle: String
    let identityDetail: String
    let memoryCount: Int
    let criteria: [String]
    let evidence: [LogASipV3PassportEvidence]
    let publicCaption: String?
    let photoImages: [UIImage]
    let coverImage: UIImage?

    init(
        visitID: UUID,
        visibility: VisitVisibility,
        isOwner: Bool,
        isRemote: Bool,
        displayName: String,
        drinkName: String,
        contextName: String,
        createdAt: Date,
        sipScore: Double,
        contextScore: Double?,
        mugshotScore: Double,
        identityTitle: String,
        identityDetail: String,
        memoryCount: Int,
        criteria: [String],
        evidence: [LogASipV3PassportEvidence],
        publicCaption: String?,
        photoImages: [UIImage],
        coverImage: UIImage?
    ) {
        self.visitID = visitID
        self.visibility = visibility
        self.isOwner = isOwner
        self.isRemote = isRemote
        self.displayName = displayName
        self.drinkName = drinkName
        self.contextName = contextName
        self.createdAt = createdAt
        self.sipScore = sipScore
        self.contextScore = contextScore
        self.mugshotScore = mugshotScore
        self.identityTitle = identityTitle
        self.identityDetail = identityDetail
        self.memoryCount = memoryCount
        self.criteria = criteria
        self.evidence = evidence
        self.publicCaption = publicCaption
        self.photoImages = photoImages
        self.coverImage = coverImage
    }
}

struct LogASipV3PassportEvidence: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String

    init(id: String, title: String, detail: String, systemImage: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }
}

struct LogASipV3PassportCompletionView: View {
    let summary: LogASipV3PassportSummary
    let isOpeningMugshot: Bool
    let statusMessage: String?
    let onViewMugshot: () -> Void
    let onFinish: () -> Void
    let onStartAnother: (() -> Void)?

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                Image("V3TastePassportBackdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 340)
                    .clipped()
                    .opacity(0.30)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
                    MugshotScreenHeader(
                        "Taste Passport",
                        subtitle: "Built gently from memories you choose to keep"
                    )

                    completionHero
                    identityCard

                    if !summary.evidence.isEmpty {
                        evidenceCard
                    }

                    if !summary.criteria.isEmpty {
                        criteriaCard
                    }

                    Button(action: onFinish) {
                        Text("Done")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if let onStartAnother {
                        Button(action: onStartAnother) {
                            Label("Pour another one", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignSystem.Space.md)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LogASipV3BottomAction(
                title: isOpeningMugshot ? "Opening Mugshot…" : "View my Mugshot",
                subtitle: "Published and safely in your journal.",
                systemImage: "checkmark.seal.fill",
                isEnabled: !isOpeningMugshot,
                showsProgress: isOpeningMugshot,
                statusMessage: statusMessage,
                action: onViewMugshot
            )
        }
        .accessibilityIdentifier("logASipV3.passport")
    }

    private var completionHero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                if let coverImage = summary.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    MugsyAnimatedView(
                        configuration: MugsyModelConfiguration(
                            expression: .delighted,
                            prop: .journalNotebook,
                            pose: .leaningRight
                        ),
                        action: .celebrating,
                        tapBehavior: .playfulCycle
                    )
                    .frame(width: 108, height: 118)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Label("Mugshot published", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                    Text(summary.drinkName)
                        .mugshotDisplay(size: 25)
                        .lineLimit(2)
                    Text("\(summary.contextName) · \(summary.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.tertiaryText)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MUGSHOT")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.mugshotSage)
                    Text(summary.mugshotScore, format: .number.precision(.fractionLength(1)))
                        .mugshotDisplay(size: 48)
                        .monospacedDigit()
                }
                Spacer()
                LogASipV3MiniScore(label: "Sip", score: summary.sipScore, icon: "cup.and.saucer.fill")
                if let contextScore = summary.contextScore {
                    LogASipV3MiniScore(
                        label: completionContextLabel,
                        score: contextScore,
                        icon: completionContextLabel == "Cafe"
                            ? "storefront.fill"
                            : "mappin.and.ellipse"
                    )
                }
            }
        }
        .padding(18)
        .background(Color.foamWhite.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
                .stroke(Color.mugshotMint.opacity(0.8), lineWidth: 1.5)
        )
        .shadow(color: DesignSystem.cardShadow.color, radius: 18, y: 8)
    }

    private var completionContextLabel: String {
        let scoreEvidence = summary.evidence.first { $0.id == "score-evidence" }?.detail
        return scoreEvidence?.localizedCaseInsensitiveContains(" and Cafe ") == true
            ? "Cafe"
            : "Setting"
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Your taste identity", systemImage: "book.closed.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                Spacer()
                Text(summary.memoryCount > 0 ? "\(summary.memoryCount) memories" : "Still learning")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.mugshotMint.opacity(0.30), in: Capsule())
            }
            Text(summary.identityTitle)
                .mugshotDisplay(size: 29)
            Text(summary.identityDetail)
                .font(.system(size: 13))
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
    }

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LogASipV3SectionHeader(
                title: "Evidence from your journal",
                subtitle: "Patterns, not verdicts"
            )
            ForEach(summary.evidence) { evidence in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: evidence.systemImage)
                        .foregroundStyle(Color.mugshotSage)
                        .frame(width: 28, height: 28)
                        .background(Color.mugshotMint.opacity(0.25), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(evidence.title)
                            .font(.system(size: 13, weight: .bold))
                        Text(evidence.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondaryText)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
    }

    private var criteriaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LogASipV3SectionHeader(
                title: "Your criteria",
                subtitle: "The things you choose to notice"
            )
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(summary.criteria, id: \.self) { criterion in
                    Text(criterion)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.espressoBrown)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 36)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.sandBeige.opacity(0.62), in: Capsule())
                }
            }
        }
        .padding(16)
        .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
    }
}

// MARK: - Shared production components

private struct LogASipV3ScrollableSurface<Content: View>: View {
    let actionTitle: String
    let actionSubtitle: String
    let actionIcon: String
    let actionEnabled: Bool
    let showsProgress: Bool
    let statusMessage: String?
    let contentEnabled: Bool
    let recoveryPrimaryTitle: String?
    let recoveryPrimaryAction: (() -> Void)?
    let recoverySecondaryTitle: String?
    let recoverySecondaryAction: (() -> Void)?
    let action: () -> Void
    @ViewBuilder let content: Content

    init(
        actionTitle: String,
        actionSubtitle: String,
        actionIcon: String,
        actionEnabled: Bool = true,
        showsProgress: Bool = false,
        statusMessage: String? = nil,
        contentEnabled: Bool = true,
        recoveryPrimaryTitle: String? = nil,
        recoveryPrimaryAction: (() -> Void)? = nil,
        recoverySecondaryTitle: String? = nil,
        recoverySecondaryAction: (() -> Void)? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.actionTitle = actionTitle
        self.actionSubtitle = actionSubtitle
        self.actionIcon = actionIcon
        self.actionEnabled = actionEnabled
        self.showsProgress = showsProgress
        self.statusMessage = statusMessage
        self.contentEnabled = contentEnabled
        self.recoveryPrimaryTitle = recoveryPrimaryTitle
        self.recoveryPrimaryAction = recoveryPrimaryAction
        self.recoverySecondaryTitle = recoverySecondaryTitle
        self.recoverySecondaryAction = recoverySecondaryAction
        self.action = action
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
                content
            }
            .disabled(!contentEnabled)
            .padding(.bottom, 116)
        }
        .accessibilityIdentifier("logASipV3.scroll")
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LogASipV3BottomAction(
                title: actionTitle,
                subtitle: actionSubtitle,
                systemImage: actionIcon,
                isEnabled: actionEnabled,
                showsProgress: showsProgress,
                statusMessage: statusMessage,
                recoveryPrimaryTitle: recoveryPrimaryTitle,
                recoveryPrimaryAction: recoveryPrimaryAction,
                recoverySecondaryTitle: recoverySecondaryTitle,
                recoverySecondaryAction: recoverySecondaryAction,
                action: action
            )
        }
    }
}

struct LogASipV3BottomAction: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isEnabled = true
    var showsProgress = false
    var statusMessage: String? = nil
    var recoveryPrimaryTitle: String? = nil
    var recoveryPrimaryAction: (() -> Void)? = nil
    var recoverySecondaryTitle: String? = nil
    var recoverySecondaryAction: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.mugshotLine.opacity(0.7))
                .frame(height: 1)

            if let statusMessage = statusMessage?.remoteTrimmedNonEmpty {
                Text(statusMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DesignSystem.Space.md)
                    .padding(.top, 8)
            }

            if recoveryPrimaryTitle != nil || recoverySecondaryTitle != nil {
                HStack(spacing: 10) {
                    if let recoveryPrimaryTitle, let recoveryPrimaryAction {
                        Button(recoveryPrimaryTitle, action: recoveryPrimaryAction)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    if let recoverySecondaryTitle, let recoverySecondaryAction {
                        Button(recoverySecondaryTitle, role: .destructive) {
                            recoverySecondaryAction()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, DesignSystem.Space.md)
                .padding(.top, 8)
            }

            Button(action: action) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.foamWhite.opacity(0.78))
                    }

                    Spacer(minLength: 8)

                    if showsProgress {
                        ProgressView().tint(.foamWhite)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundColor(.foamWhite)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(isEnabled ? Color.mugshotSage : Color.mugshotSage.opacity(0.42))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityIdentifier("logASipV3.primaryAction")
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .background(Color.creamWhite.opacity(0.88))
    }
}

private struct LogASipV3SectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.espressoBrown)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.tertiaryText)
            }
        }
    }
}

private struct LogASipV3LabeledField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String
    var accessibilityIdentifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.secondaryText)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.sentences)
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                        .stroke(Color.mugshotLine, lineWidth: 1)
                )
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
    }
}

private struct LogASipV3PhotoStrip: View {
    let images: [UIImage]
    @Binding var posterPhotoIndex: Int
    @Binding var usesPlaceholder: Bool
    let onAddPhoto: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if usesPlaceholder && images.isEmpty {
                HStack(spacing: 14) {
                    MugsyAnimatedView(
                        configuration: MugsyModelConfiguration(
                            expression: .curious,
                            prop: .camera,
                            pose: .leaningLeft
                        ),
                        action: .entering,
                        tapBehavior: .wave
                    )
                    .frame(width: 98, height: 100)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Oops, missed the photo")
                            .mugshotDisplay(size: 20)
                        Text("Mugsy saved your memory a spot.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondaryText)
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 124)
                .background(Color.mugshotMint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                        .stroke(Color.mugshotSage.opacity(0.25), lineWidth: 1)
                )
            } else if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(images.indices, id: \.self) { index in
                            Button {
                                posterPhotoIndex = index
                                usesPlaceholder = false
                                MugshotHaptic.softImpact.play()
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: images[index])
                                        .resizable()
                                        .scaledToFill()
                                        .accessibilityHidden(true)
                                        .frame(width: 108, height: 126)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(
                                                    index == posterPhotoIndex ? Color.mugshotMint : Color.mugshotLine,
                                                    lineWidth: index == posterPhotoIndex ? 4 : 1
                                                )
                                        )

                                    if index == posterPhotoIndex {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.espressoBrown)
                                            .accessibilityHidden(true)
                                            .frame(width: 30, height: 30)
                                            .background(Color.mugshotMint, in: Circle())
                                            .padding(6)
                                    }
                                }
                                .frame(minWidth: 108, minHeight: 126)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("logASipV3.photos.thumbnail.\(index)")
                            .accessibilityLabel("Photo \(index + 1)")
                            .accessibilityValue(index == posterPhotoIndex ? "Cover" : "")
                            .accessibilityHint("Makes this the cover photo")
                        }
                    }
                }
            }

            Button(action: onAddPhoto) {
                VStack(spacing: 9) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22, weight: .bold))
                    Text("Add the photos that carry the memory")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.mugshotSage)
                .frame(maxWidth: .infinity, minHeight: 126)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                        .stroke(Color.mugshotLine, style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("logASipV3.photos.add")
            .accessibilityLabel("Add photos")
            .accessibilityHint("Choose or take photos that carry this memory")
        }
    }
}

private struct LogASipV3MemorySummary: View {
    let image: UIImage?
    let title: String
    let subtitle: String
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.mugshotMint.opacity(0.24))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.tertiaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onEdit) {
                Text("Edit")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .cardStyle(radius: DesignSystem.Radius.control, shadow: DesignSystem.subtleShadow)
    }
}

private struct LogASipV3JournalEditor: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let privacyLabel: String
    var minimumHeight: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                LogASipV3SectionHeader(title: title, subtitle: nil)
                Spacer()
                Label("Journal", systemImage: "book.closed.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(prompt)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(Color.tertiaryText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minimumHeight)
                    .padding(.horizontal, 1)
                    .background(Color.clear)
                    .accessibilityLabel(title)
                    .accessibilityHint(prompt)
                    .onChange(of: text) { _, updatedText in
                        guard updatedText.v3DatabaseCharacterCount
                                > V3VisitReflection.rawNoteCharacterLimit else {
                            return
                        }
                        text = updatedText.v3PrefixDatabaseCharacters(
                            V3VisitReflection.rawNoteCharacterLimit
                        )
                    }
            }
            .padding(10)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )

            HStack(spacing: 8) {
                Label(privacyLabel, systemImage: "lock.fill")
                Spacer(minLength: 8)
                if text.v3DatabaseCharacterCount >= 9_000 {
                    Text("\(text.v3DatabaseCharacterCount.formatted()) / 10,000")
                        .monospacedDigit()
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.tertiaryText)
        }
    }
}

private struct LogASipV3MugsyCoach: View {
    let prompts: [LogASipV3CoachPrompt]
    @Binding var index: Int
    let onExploreFlavors: (() -> Void)?

    @State private var isExpanded = false

    private var prompt: LogASipV3CoachPrompt {
        guard !prompts.isEmpty else {
            return LogASipV3CoachPrompt(id: "fallback", prompt: "What stands out?", hint: "Start with the first honest detail.")
        }
        return prompts[min(max(index, 0), prompts.count - 1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 0) {
                Button {
                    withAnimation(DesignSystem.Motion.base) {
                        isExpanded.toggle()
                    }
                    MugshotHaptic.softImpact.play()
                } label: {
                    MugsyAnimatedView(
                        configuration: MugsyModelConfiguration(
                            expression: isExpanded ? .focused : .curious,
                            prop: .journalNotebook,
                            pose: .leaningRight
                        ),
                        action: isExpanded ? .focusing : .resting,
                        tapBehavior: .wave
                    )
                    .frame(width: 105, height: 112)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Close Mugsy prompt" : "Need a nudge from Mugsy")

                VStack(alignment: .leading, spacing: 5) {
                    Text(isExpanded ? prompt.prompt : "Need a nudge?")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                    Text(isExpanded ? prompt.hint : "Tap Mugsy. He’ll help you notice, not write for you.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.mugshotMint.opacity(0.9), lineWidth: 1.5)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(DesignSystem.Motion.base) { isExpanded = true }
                }
            }

            if isExpanded {
                HStack(spacing: 8) {
                    Button {
                        index = max(0, index - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)
                    .accessibilityLabel("Previous prompt")

                    Text("\(index + 1) of \(prompts.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.tertiaryText)

                    Button {
                        index = min(max(prompts.count - 1, 0), index + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= prompts.count - 1)
                    .accessibilityLabel("Next prompt")

                    Spacer()

                    if let onExploreFlavors {
                        Button(action: onExploreFlavors) {
                            Label("Explore flavors", systemImage: "point.3.connected.trianglepath.dotted")
                                .font(.system(size: 12, weight: .bold))
                                .frame(minHeight: 44)
                        }
                        .foregroundStyle(Color.mugshotSage)
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(12)
        .background(Color.mugshotMint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
    }
}

private struct LogASipV3ScoreBlock: View {
    let title: String
    let subtitle: String
    @Binding var score: Double
    let accessibilityLabel: String
    var minimumScore = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Text(score, format: .number.precision(.fractionLength(1)))
                    .mugshotDisplay(size: 34)
                    .foregroundColor(.espressoBrown)
                    .monospacedDigit()
            }
            LogASipV3HalfStarRating(
                rating: $score,
                label: accessibilityLabel,
                minimumScore: minimumScore
            )
                .accessibilityIdentifier(
                    accessibilityLabel == "Sip score"
                        ? "logASipV3.sipScore"
                        : "logASipV3.contextScore"
                )
        }
    }
}

private struct LogASipV3HalfStarRating: View {
    @Binding var rating: Double
    let label: String
    var minimumScore = 0.5

    var body: some View {
        MugshotV3HalfStarRating(
            rating: $rating,
            label: label,
            starSize: 31,
            spacing: 6,
            minimumScore: minimumScore
        )
    }
}

private struct LogASipV3CriteriaEditor: View {
    let title: String
    let subtitle: String
    let suggestionLabel: String
    @Binding var criteria: [SipRatingCriterionSnapshot]
    let suggestions: [LogASipV3CriterionSuggestion]
    let accessibilityScope: String
    let canUseLastSetup: Bool
    let onUseLastSetup: () -> Void
    let onAddOwn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                }

                Spacer()

                if canUseLastSetup {
                    Button("Use last setup", action: onUseLastSetup)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .buttonStyle(.plain)
                }
            }

            if !criteria.isEmpty {
                VStack(spacing: 0) {
                    ForEach($criteria) { $criterion in
                        LogASipV3CriterionCard(
                            criterion: $criterion,
                            systemImage: systemImage(for: criterion.name),
                            accessibilityBaseIdentifier: criterionIdentifier(for: criterion.name),
                            onRemove: {
                                criteria.removeAll { $0.id == criterion.id }
                                reindexCriteria()
                            }
                        )

                        if criterion.id != criteria.last?.id {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .cardStyle(radius: DesignSystem.Radius.control, shadow: DesignSystem.subtleShadow)
            }

            HStack {
                Text(suggestionLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Spacer()
                Text("\(suggestions.count) ideas")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        LogASipV3SuggestionChip(
                            suggestion: suggestion,
                            isAdded: criteria.contains {
                                $0.name.caseInsensitiveCompare(suggestion.title) == .orderedSame
                            },
                            accessibilityIdentifier: "logASipV3.\(accessibilityScope).suggestion.\(suggestion.id)"
                        ) {
                            add(suggestion)
                        }
                    }

                    Button(action: onAddOwn) {
                        Label("Add my own", systemImage: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(Color.foamWhite)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.mugshotLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("logASipV3.\(accessibilityScope).suggestion.add-own")
                }
            }
        }
    }

    private func add(_ suggestion: LogASipV3CriterionSuggestion) {
        guard !criteria.contains(where: {
            $0.name.caseInsensitiveCompare(suggestion.title) == .orderedSame
        }) else { return }
        criteria.append(SipRatingCriterionSnapshot(
            name: suggestion.title,
            weight: 1,
            sortOrder: criteria.count,
            isPinned: false
        ))
        MugshotHaptic.softImpact.play()
    }

    private func reindexCriteria() {
        for index in criteria.indices {
            criteria[index].sortOrder = index
        }
    }

    private func systemImage(for criterionName: String) -> String {
        if let exactMatch = suggestions.first(where: {
            $0.title.caseInsensitiveCompare(criterionName) == .orderedSame
        }) {
            return exactMatch.systemImage
        }

        if criterionName.caseInsensitiveCompare("Orange balance") == .orderedSame {
            return "circle.lefthalf.filled"
        }

        return "slider.horizontal.3"
    }

    private func criterionIdentifier(for criterionName: String) -> String {
        let suggestionID = suggestions.first(where: {
            $0.title.caseInsensitiveCompare(criterionName) == .orderedSame
        })?.id
        let slug = suggestionID ?? criterionName.v3AccessibilitySlug
        return "logASipV3.\(accessibilityScope).criterion.\(slug)"
    }
}

private struct LogASipV3CriterionCard: View {
    @Binding var criterion: SipRatingCriterionSnapshot
    let systemImage: String
    let accessibilityBaseIdentifier: String
    let onRemove: () -> Void

    var body: some View {
        MugshotV3CriterionRow(
            title: criterion.name,
            systemImage: systemImage,
            rating: $criterion.score,
            importance: $criterion.importance,
            isPinned: Binding(
                get: { criterion.isPinned ?? false },
                set: { criterion.isPinned = $0 }
            ),
            accessibilityBaseIdentifier: accessibilityBaseIdentifier,
            onRemove: onRemove
        )
    }
}

private struct LogASipV3SuggestionChip: View {
    let suggestion: LogASipV3CriterionSuggestion
    let isAdded: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        MugshotV3SuggestionChip(
            title: suggestion.title,
            systemImage: suggestion.systemImage,
            isAdded: isAdded,
            accessibilityIdentifier: accessibilityIdentifier,
            action: action
        )
    }
}

private struct LogASipV3ScoreGuidance: View {
    let suggestedScore: Double
    let currentScore: Double
    let onUse: () -> Void

    var body: some View {
        MugshotV3ScoreGuidanceCard(
            suggestedScore: suggestedScore,
            currentScore: currentScore,
            onUse: onUse
        )
    }
}

private struct LogASipV3HomeReflection: View {
    @Binding var draft: SipDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LogASipV3SectionHeader(
                title: "Would you make it again?",
                subtitle: "A decision, not another rating"
            )

            LogASipV3MakeAgainControl(selection: $draft.homeMakeAgain)

            if hasRecipeEvidence {
                VStack(alignment: .leading, spacing: 9) {
                    Label("Recipe snapshot", systemImage: "list.clipboard.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(recipeSummary)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Equipment and method support the sip score; they do not become another score.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.tertiaryText)
                }
                .padding(14)
                .cardStyle(radius: DesignSystem.Radius.control, shadow: DesignSystem.subtleShadow)
            }
        }
    }

    private var hasRecipeEvidence: Bool {
        draft.brewMethod.remoteTrimmedNonEmpty != nil
            || draft.equipment.remoteTrimmedNonEmpty != nil
            || draft.brewDetails.hasStructuredData
    }

    private var recipeSummary: String {
        [
            draft.brewMethod.remoteTrimmedNonEmpty,
            draft.equipment.remoteTrimmedNonEmpty,
            draft.brewDetails.extractionSummary,
            draft.brewDetails.recipeDisplayName
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

private struct LogASipV3MakeAgainControl: View {
    @Binding var selection: HomeMakeAgain?

    var body: some View {
        HStack(spacing: 4) {
            option(.yes, title: "Yes")
            option(.withATweak, title: "With a tweak")
            option(.notThisVersion, title: "Not this one")
        }
        .padding(4)
        .background(Color.sandBeige.opacity(0.78), in: Capsule())
    }

    private func option(_ option: HomeMakeAgain, title: String) -> some View {
        let selected = isSelected(option)
        return Button {
            selection = option
        } label: {
            Text(title)
                .font(.system(size: 12, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Color.espressoBrown : Color.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.foamWhite : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("logASipV3.homeMakeAgain.\(option.rawValue)")
    }

    private func isSelected(_ option: HomeMakeAgain) -> Bool {
        switch (selection, option) {
        case (.some(.yes), .yes),
             (.some(.withATweak), .withATweak),
             (.some(.notThisVersion), .notThisVersion):
            return true
        default:
            return false
        }
    }
}

private struct LogASipV3PublishMediaCard: View {
    let images: [UIImage]
    let posterPhotoIndex: Int
    let usesPlaceholder: Bool
    @Binding var previewIndex: Int
    let drinkName: String
    let contextName: String
    let createdAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if usesPlaceholder || images.isEmpty {
                    HStack(spacing: 14) {
                        MugsyAnimatedView(
                            configuration: MugsyModelConfiguration(
                                expression: .curious,
                                prop: .camera,
                                pose: .leaningLeft
                            ),
                            action: .resting,
                            tapBehavior: .wave
                        )
                        .frame(width: 112, height: 124)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Oops, missed the photo")
                                .mugshotDisplay(size: 21)
                            Text("Mugsy saved your memory a spot.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .background(Color.mugshotMint.opacity(0.18))
                } else {
                    TabView(selection: $previewIndex) {
                        ForEach(images.indices, id: \.self) { index in
                            Image(uiImage: images[index])
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipped()
                                .tag(index)
                        }
                    }
                    .frame(height: 220)
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }

                if !usesPlaceholder, !images.isEmpty, previewIndex == posterPhotoIndex {
                    Label("Cover", systemImage: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.mugshotMint, in: Capsule())
                        .padding(10)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))

            Text(drinkName)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(2)
            Text("\(contextName) · \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.tertiaryText)
        }
    }
}

private struct LogASipV3ScoreEquation: View {
    let sipScore: Double
    let contextScore: Double?
    let contextLabel: String
    let mugshotScore: Double
    let sipCriteria: [SipRatingCriterionSnapshot]
    let contextCriteria: [SipRatingCriterionSnapshot]
    @Binding var showsCriteria: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR MUGSHOT")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.3)
                            .foregroundStyle(Color.mugshotSage)
                        Text(mugshotScore, format: .number.precision(.fractionLength(1)))
                            .mugshotDisplay(size: 48)
                            .monospacedDigit()
                    }
                    Spacer()
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                }

                HStack(spacing: 8) {
                    LogASipV3MiniScore(label: "Sip", score: sipScore, icon: "cup.and.saucer.fill")
                    if let contextScore {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.tertiaryText)
                        LogASipV3MiniScore(
                            label: contextLabel,
                            score: contextScore,
                            icon: contextLabel == "Cafe" ? "storefront.fill" : "mappin.and.ellipse"
                        )
                    }
                }
            }
            .padding(16)

            Divider()

            DisclosureGroup(isExpanded: $showsCriteria) {
                VStack(alignment: .leading, spacing: 8) {
                    criteriaSummary(title: "Sip", criteria: sipCriteria)
                    if contextScore != nil {
                        criteriaSummary(title: contextLabel, criteria: contextCriteria)
                    }
                }
                .padding(.top, 10)
            } label: {
                Text("See what shaped this")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .tint(.mugshotSage)
            .padding(.horizontal, 14)
        }
        .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
    }

    private func criteriaSummary(
        title: String,
        criteria: [SipRatingCriterionSnapshot]
    ) -> some View {
        let rated = criteria.filter { $0.score > 0 }
        return VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.tertiaryText)
            Text(rated.isEmpty
                ? "No criteria added"
                : rated.map {
                    "\($0.name) \($0.score.formatted(.number.precision(.fractionLength(1))))"
                }.joined(separator: " · "))
                .font(.system(size: 12))
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LogASipV3MiniScore: View {
    let label: String
    let score: Double
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .bold))
            Text(score, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 14, weight: .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(Color.espressoBrown)
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(Color.sandBeige.opacity(0.62), in: Capsule())
    }
}

private struct LogASipV3VisibilitySelector: View {
    let title: String
    let detail: String
    let systemImage: String
    @Binding var selection: VisitVisibility
    let enabledOptions: [VisitVisibility]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.mugshotSage)
                    .frame(width: 32, height: 32)
                    .background(Color.mugshotMint.opacity(0.22), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.tertiaryText)
                }
            }

            HStack(spacing: 4) {
                ForEach(VisitVisibility.allCases) { option in
                    let selected = selection == option
                    let enabled = enabledOptions.contains(option)
                    Button {
                        guard enabled else { return }
                        selection = option
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 12, weight: selected ? .bold : .medium))
                            .foregroundStyle(selected ? Color.espressoBrown : Color.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected ? Color.foamWhite : Color.clear, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.35)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Color.sandBeige.opacity(0.72), in: Capsule())
        }
        .padding(14)
    }
}

private struct LogASipV3RecipeSharingControls: View {
    @Binding var draft: SipDraft

    private var visibility: Binding<VisitVisibility> {
        Binding(
            get: { draft.recipePublication.visibility },
            set: { value in
                var contract = draft.recipePublication
                contract.visibility = value
                draft.recipePublication = contract
            }
        )
    }

    private var sourceKind: Binding<SipRecipeSourceKind> {
        Binding(
            get: { draft.recipePublication.sourceKind },
            set: { value in
                var contract = draft.recipePublication
                contract.selectSource(value)
                draft.recipePublication = contract
            }
        )
    }

    private var redistributionAllowed: Binding<Bool> {
        Binding(
            get: { draft.recipePublication.redistributionAllowed },
            set: { value in
                var contract = draft.recipePublication
                contract.redistributionAllowed = value
                if !value { contract.acknowledgesPublicReuse = false }
                draft.recipePublication = contract
            }
        )
    }

    private var acknowledgesPublicReuse: Binding<Bool> {
        Binding(
            get: { draft.recipePublication.acknowledgesPublicReuse },
            set: { value in
                var contract = draft.recipePublication
                contract.acknowledgesPublicReuse = value
                draft.recipePublication = contract
            }
        )
    }

    private var availableSources: [SipRecipeSourceKind] {
        SipRecipeSourceKind.allCases.filter {
            $0 != .adapted
                || draft.recipePublication.sourceRecipeVersionID != nil
                || draft.recipePublication.sourceKind == .adapted
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            LogASipV3VisibilitySelector(
                title: "Recipe audience",
                detail: "Set separately from the Mugshot",
                systemImage: "book.pages.fill",
                selection: visibility,
                enabledOptions: VisitVisibility.allCases
            )

            Divider().padding(.leading, 54)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Color.mugshotSage)
                        .frame(width: 32, height: 32)
                        .background(Color.mugshotMint.opacity(0.22), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recipe source and rights")
                            .font(.system(size: 13, weight: .bold))
                        Text("Keeps attribution attached to this exact version")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.tertiaryText)
                    }
                    Spacer()
                }

                Picker("Recipe source", selection: sourceKind) {
                    ForEach(availableSources) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.menu)
                .tint(.mugshotSage)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

                Toggle(isOn: redistributionAllowed) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow save and adapt")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Required before an original or adapted recipe can reach Everyone")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.tertiaryText)
                    }
                }
                .tint(.mugshotSage)
                .disabled(!draft.recipePublication.sourceKind.permitsRedistribution)

                if draft.recipePublication.visibility == .everyone,
                   draft.recipePublication.sourceKind.permitsRedistribution,
                   draft.recipePublication.redistributionAllowed {
                    Toggle(isOn: acknowledgesPublicReuse) {
                        Text("I understand that anyone can save and adapt this exact public recipe.")
                            .font(.system(size: 12, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tint(.mugshotSage)
                }

                if let guidance = requirementGuidance {
                    Label(guidance, systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
        }
    }

    private var requirementGuidance: String? {
        switch draft.recipePublicationRequirement {
        case .ready: return nil
        case .needsImmutableSource:
            return "Use Brew Again from the source recipe so Mugshot can preserve its exact attribution."
        case .sourceCannotBePublic:
            return "Purchased and external instructions can stay Private or Friends, but cannot be shared with Everyone."
        case .needsRedistributionPermission:
            return "Confirm save-and-adapt rights to use the Everyone recipe audience."
        case .needsPublicReuseAcknowledgment:
            return "Acknowledge how public recipe reuse works before publishing."
        }
    }
}

private struct LogASipV3PeopleStrip: View {
    let title: String
    let emptyDetail: String
    let populatedDetail: (Int) -> String
    let systemImage: String
    let people: [SipCompanion]
    let actionAccessibilityLabel: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.mugshotSage)
                .frame(width: 32, height: 32)
                .background(Color.mugshotMint.opacity(0.22), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(people.isEmpty ? emptyDetail : populatedDetail(people.count))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.tertiaryText)
            }

            Spacer(minLength: 4)

            HStack(spacing: -8) {
                ForEach(people.prefix(4)) { companion in
                    LogASipV3Avatar(companion: companion)
                }

                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.espressoBrown)
                        .frame(width: 44, height: 44)
                        .background(Color.mugshotMint, in: Circle())
                        .overlay(Circle().stroke(Color.foamWhite, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionAccessibilityLabel)
            }
        }
        .padding(14)
    }
}

private struct LogASipV3Avatar: View {
    let companion: SipCompanion

    var body: some View {
        AsyncImage(url: companion.avatarURL.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Text(companion.displayName.prefix(1).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.sandBeige)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.foamWhite, lineWidth: 2))
        .accessibilityLabel(companion.displayName)
    }
}

// MARK: - Helper sheets

private enum LogASipV3Sheet: Identifiable {
    case flavors
    case addCriterion(LogASipV3CriterionTarget)

    var id: String {
        switch self {
        case .flavors: return "flavors"
        case .addCriterion(let target): return "criterion-\(target.rawValue)"
        }
    }
}

private enum LogASipV3CriterionTarget: String {
    case sip
    case context
}

private struct LogASipV3AddCriterionSheet: View {
    let target: LogASipV3CriterionTarget
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                MugshotScreenHeader(
                    "Add your own",
                    subtitle: "Name what mattered in plain language."
                )
                TextField(target == .sip ? "Orange balance" : "Menu clarity", text: $name)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                            .stroke(Color.mugshotLine, lineWidth: 1)
                    )

                Button {
                    onAdd(name)
                    dismiss()
                } label: {
                    Text("Add criterion")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.remoteTrimmedNonEmpty == nil)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .background(Color.creamWhite)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct LogASipV3FlavorHelperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [LogASipV3FlavorNode] = []
    @State private var selectedLeafIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MugshotScreenHeader(
                        path.last?.title ?? "Explore what you notice",
                        subtitle: "A Mugshot-made thinking aid—not a test and never a generated tasting claim."
                    )

                    if !path.isEmpty {
                        Button {
                            _ = path.popLast()
                        } label: {
                            Label("Back one level", systemImage: "chevron.left")
                                .frame(minHeight: 44)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .buttonStyle(.plain)
                        .padding(.horizontal, DesignSystem.Space.md)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 142), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(currentNodes) { node in
                            Button {
                                if node.children.isEmpty {
                                    if selectedLeafIDs.contains(node.id) {
                                        selectedLeafIDs.remove(node.id)
                                    } else {
                                        selectedLeafIDs.insert(node.id)
                                    }
                                } else {
                                    path.append(node)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: node.systemImage)
                                        .foregroundStyle(Color.mugshotSage)
                                        .frame(width: 26)
                                    Text(node.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Image(systemName: node.children.isEmpty
                                        ? (selectedLeafIDs.contains(node.id) ? "checkmark.circle.fill" : "circle")
                                        : "chevron.right")
                                        .foregroundStyle(Color.mugshotSage)
                                }
                                .foregroundStyle(Color.espressoBrown)
                                .padding(12)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                .background(Color.foamWhite)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.mugshotLine, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Space.md)

                    Text("These words stay inside this helper. Use only the ones that genuinely help your own note.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignSystem.Space.md)
                }
                .padding(.bottom, 30)
            }
            .background(Color.creamWhite)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var currentNodes: [LogASipV3FlavorNode] {
        path.last?.children ?? LogASipV3FlavorNode.roots
    }
}

// MARK: - View data

struct LogASipV3CoachPrompt: Identifiable {
    let id: String
    let prompt: String
    let hint: String

    static let sip: [Self] = [
        .init(id: "sip-first", prompt: "What hits first?", hint: "Notice the opening second before naming a flavor."),
        .init(id: "sip-after", prompt: "What’s after the sip?", hint: "Think about finish, texture, and what lingers."),
        .init(id: "sip-change", prompt: "How does it change?", hint: "A drink can become brighter, thinner, sweeter, or quieter."),
        .init(id: "sip-feeling", prompt: "What feeling does it leave?", hint: "Your experience matters more than a technical answer."),
        .init(id: "sip-temperature", prompt: "What changes as it warms or cools?", hint: "Notice whether flavor, sweetness, aroma, or texture shifts with temperature."),
        .init(id: "sip-location", prompt: "Where do you feel it most?", hint: "Pay attention to weight, sparkle, dryness, and where the sip seems to land."),
        .init(id: "sip-balance", prompt: "What feels in or out of balance?", hint: "Look for one quality that leads and another that supports or disappears."),
        .init(id: "sip-again", prompt: "Would you want this exact sip again?", hint: "Name the detail you would keep—or the one you would change.")
    ]

    static let cafe: [Self] = [
        .init(id: "cafe-arrival", prompt: "How did the room greet you?", hint: "Notice light, sound, movement, and how easy it felt to settle in."),
        .init(id: "cafe-interaction", prompt: "How did the interaction feel?", hint: "Describe what happened without turning an employee into the review."),
        .init(id: "cafe-value", prompt: "Did the experience feel worth it?", hint: "Value can include care, comfort, craft, and price."),
        .init(id: "cafe-return", prompt: "What would bring you back?", hint: "Look for the part of the memory you would want again."),
        .init(id: "cafe-settle", prompt: "Where did you want to settle in?", hint: "Notice which seat, corner, window, or flow made the cafe feel usable."),
        .init(id: "cafe-sound", prompt: "What did the sound do to the mood?", hint: "Music, voices, machines, and silence can each shape the visit."),
        .init(id: "cafe-friction", prompt: "Was anything harder than it needed to be?", hint: "Think about ordering, prices, waiting, seating, or finding what you needed."),
        .init(id: "cafe-detail", prompt: "What detail made this place itself?", hint: "Hold onto one visual, interaction, or atmosphere cue that made it distinct.")
    ]

    static let home: [Self] = [
        .init(id: "home-change", prompt: "What changed this time?", hint: "Name the smallest variable you remember."),
        .init(id: "home-result", prompt: "What did this version make possible?", hint: "Describe the result without assuming one change caused it."),
        .init(id: "home-next", prompt: "What’s one next experiment?", hint: "Change one variable so tomorrow can teach you something.")
    ]

    static let elsewhere: [Self] = [
        .init(id: "elsewhere-place", prompt: "How did the setting change the sip?", hint: "A view, journey, person, or pause can shape the memory."),
        .init(id: "elsewhere-sense", prompt: "What else could you hear or feel?", hint: "Let the setting be evidence, not merely a location."),
        .init(id: "elsewhere-memory", prompt: "What will future you want to remember?", hint: "Keep the one detail that makes this moment distinct.")
    ]
}

struct LogASipV3CriterionSuggestion: Identifiable {
    let id: String
    let title: String
    let systemImage: String

    static let sip: [Self] = [
        item("aroma", "Aroma", "wind"),
        item("flavor", "Flavor", "mouth"),
        item("sweetness", "Sweetness", "cube.fill"),
        item("brightness", "Brightness", "sun.max"),
        item("bitterness", "Bitterness", "drop.triangle"),
        item("body", "Body", "water.waves"),
        item("texture", "Texture", "waveform.path"),
        item("balance", "Balance", "scale.3d"),
        item("finish", "Finish", "hourglass.bottomhalf.filled"),
        item("presentation", "Presentation", "sparkles"),
        item("coffee-presence", "Coffee presence", "cup.and.saucer"),
        item("milk-integration", "Milk integration", "cloud.fill"),
        item("flavor-accuracy", "Flavor accuracy", "scope"),
        item("orange-balance", "Orange balance", "circle.lefthalf.filled"),
        item("refreshment", "Refreshment", "snowflake"),
        item("aftertaste", "Aftertaste", "arrow.uturn.forward"),
        item("intensity", "Intensity", "dial.medium"),
        item("complexity", "Complexity", "circle.hexagongrid"),
        item("clarity", "Clarity", "sparkle.magnifyingglass"),
        item("temperature", "Temperature", "thermometer.medium"),
        item("value", "Value", "dollarsign"),
        item("novelty", "Novelty", "lightbulb"),
        item("comfort", "Comfort", "heart"),
        item("nostalgia", "Nostalgia", "clock.arrow.circlepath")
    ]

    static let cafe: [Self] = [
        item("atmosphere", "Atmosphere", "sun.max"),
        item("service", "Service", "person.crop.circle.badge.checkmark"),
        item("comfort", "Comfort", "chair.lounge"),
        item("value", "Value", "dollarsign"),
        item("menu-clarity", "Menu clarity", "menucard"),
        item("noise", "Noise level", "speaker.wave.2"),
        item("lighting", "Lighting", "lightbulb"),
        item("seating", "Seating", "chair"),
        item("cleanliness", "Cleanliness", "sparkles"),
        item("wait-time", "Wait time", "clock"),
        item("hospitality", "Hospitality", "hand.wave"),
        item("music", "Music", "music.note"),
        item("walkability", "Walkability", "figure.walk"),
        item("accessibility", "Accessibility", "accessibility"),
        item("wifi", "Wi-Fi", "wifi"),
        item("outlets", "Outlets", "powerplug"),
        item("workability", "Workability", "laptopcomputer"),
        item("presentation", "Presentation", "rectangle.3.group"),
        item("crowd-energy", "Crowd energy", "person.3"),
        item("to-go", "To-go readiness", "takeoutbag.and.cup.and.straw"),
        item("return-appeal", "Return appeal", "arrow.uturn.backward.circle")
    ]

    static let elsewhere: [Self] = [
        item("view", "View", "binoculars.fill"),
        item("comfort", "Comfort", "figure.seated.side"),
        item("company", "Company", "person.2.fill"),
        item("weather", "Weather", "cloud.sun.fill"),
        item("quiet", "Quiet", "speaker.slash.fill"),
        item("energy", "Energy", "bolt.fill"),
        item("timing", "Timing", "clock.fill"),
        item("convenience", "Convenience", "checkmark.circle.fill"),
        item("novelty", "Novelty", "sparkles"),
        item("scenery", "Scenery", "mountain.2.fill"),
        item("movement", "Movement", "tram.fill"),
        item("weather-fit", "Weather fit", "umbrella.fill"),
        item("occasion", "Occasion", "calendar"),
        item("pace", "Pace", "gauge.with.dots.needle.33percent"),
        item("memory", "Memorability", "bookmark.fill")
    ]

    private static func item(_ id: String, _ title: String, _ systemImage: String) -> Self {
        Self(id: id, title: title, systemImage: systemImage)
    }
}

private enum LogASipV3ScoreMath {
    static func mugshotScore(sipScore: Double, contextScore: Double?) -> Double {
        guard let contextScore, contextScore > 0 else {
            return (sipScore * 10).rounded() / 10
        }
        return (((sipScore + contextScore) / 2) * 10).rounded() / 10
    }
}

private extension String {
    var v3AccessibilitySlug: String {
        let pieces = lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return pieces.isEmpty ? "custom" : pieces.joined(separator: "-")
    }
}

private struct LogASipV3FlavorNode: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let children: [Self]

    static let roots: [Self] = [
        branch("bright", "Bright & lively", "sun.max.fill", [
            branch("bright-citrus", "Citrus-like", "circle.fill", [
                leaf("bright-citrus-lemon", "Lemon-like", "circle.fill"),
                leaf("bright-citrus-orange", "Orange-like", "circle.fill"),
                leaf("bright-citrus-grapefruit", "Grapefruit-like", "circle.fill")
            ]),
            branch("bright-orchard", "Orchard fruit", "apple.logo", [
                leaf("bright-orchard-apple", "Apple-like", "apple.logo"),
                leaf("bright-orchard-pear", "Pear-like", "drop.fill")
            ]),
            branch("bright-berry", "Berry-like", "circle.grid.3x3.fill", [
                leaf("bright-berry-red", "Red berry", "circle.fill"),
                leaf("bright-berry-dark", "Dark berry", "circle.fill")
            ])
        ]),
        branch("sweet", "Sweet & comforting", "cube.fill", [
            branch("sweet-caramelized", "Caramelized", "flame.fill", [
                leaf("sweet-caramel", "Caramel-like", "drop.fill"),
                leaf("sweet-maple", "Maple-like", "leaf.fill"),
                leaf("sweet-brown-sugar", "Brown sugar-like", "cube.fill")
            ]),
            branch("sweet-cocoa", "Cocoa-like", "square.fill", [
                leaf("sweet-milk-cocoa", "Milk cocoa", "square.fill"),
                leaf("sweet-dark-cocoa", "Dark cocoa", "square.fill")
            ]),
            leaf("sweet-vanilla", "Vanilla-like", "sparkles")
        ]),
        branch("roasty", "Roasty & grounded", "flame.fill", [
            leaf("roasty-toast", "Toasted grain", "takeoutbag.and.cup.and.straw.fill"),
            leaf("roasty-nut", "Nut-like", "leaf.fill"),
            leaf("roasty-smoke", "Smoky", "smoke.fill"),
            leaf("roasty-spice", "Warm spice", "sparkles")
        ]),
        branch("green", "Green & floral", "leaf.fill", [
            leaf("green-blossom", "Blossom-like", "camera.macro"),
            leaf("green-herbal", "Herbal", "leaf.fill"),
            leaf("green-tea", "Tea leaf", "leaf.circle.fill"),
            leaf("green-grassy", "Fresh-cut green", "wind")
        ]),
        branch("texture", "Texture & finish", "water.waves", [
            branch("texture-body", "Body", "water.waves", [
                leaf("texture-silky", "Silky", "waveform.path"),
                leaf("texture-creamy", "Creamy", "cloud.fill"),
                leaf("texture-juicy", "Juicy", "drop.fill"),
                leaf("texture-light", "Light", "wind")
            ]),
            branch("texture-finish", "Finish", "hourglass.bottomhalf.filled", [
                leaf("texture-clean", "Clean", "sparkles"),
                leaf("texture-lingering", "Lingering", "ellipsis"),
                leaf("texture-dry", "Dry", "drop.triangle"),
                leaf("texture-quick", "Quick", "bolt.fill")
            ])
        ])
    ]

    private static func branch(
        _ id: String,
        _ title: String,
        _ systemImage: String,
        _ children: [Self]
    ) -> Self {
        Self(id: id, title: title, systemImage: systemImage, children: children)
    }

    private static func leaf(_ id: String, _ title: String, _ systemImage: String) -> Self {
        Self(id: id, title: title, systemImage: systemImage, children: [])
    }
}

private extension SipDraft {
    var contextDisplayNameV3: String {
        switch context {
        case .cafe:
            return cafe?.consumerDisplayName ?? "Cafe"
        case .home, .recipe:
            return locationName.remoteTrimmedNonEmpty ?? "Home"
        case .elsewhere:
            return locationName.remoteTrimmedNonEmpty ?? "Elsewhere"
        }
    }
}
