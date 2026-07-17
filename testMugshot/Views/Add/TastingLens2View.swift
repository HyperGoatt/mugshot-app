import SwiftUI

/// The production Tasting Lens 2.0 journey.
///
/// The caller provides a deterministic knowledge selection and owns persistence.
/// The completion callback returns a fully populated, typed session draft so the
/// repository layer can freeze it into an immutable `SipSensorySnapshot`.
struct TastingLens2View: View {
    typealias SelectionBuilder = (
        SensoryDrinkIdentity,
        TastingDepth,
        TastingLensUserPreferences
    ) -> TastingLensSelection

    let bundle: SensoryKnowledgeBundle
    let history: [SipSensorySnapshot]
    let learnedPatterns: [LearnedSensoryPattern]
    let contentState: TastingLensContentState
    let onComplete: (TastingLensSessionDraft, TastingLensUserPreferences) -> Void
    let onCancel: () -> Void
    let onUpdatePreferences: (TastingLensUserPreferences) -> Void
    let onSessionUpdate: (TastingLensSessionDraft) -> Void
    let onRetry: () -> Void
    private let selectionBuilder: SelectionBuilder?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var session: TastingLensSessionDraft
    @State private var selection: TastingLensSelection
    @State private var preferences: TastingLensUserPreferences
    @State private var currentPageIndex = 0
    @State private var answers: [String: TastingLensCriterionAnswer]
    @State private var selectedFlavorIDs: Set<String>
    @State private var customFlavor = ""
    @State private var flavorState: TastingLensAnswerStatus = .unanswered
    @State private var ownWordsUncertain = false
    @State private var leadingSensation: String?
    @State private var mugsyDistinction: String?
    @State private var presentedSheet: TastingLens2Sheet?
    @AccessibilityFocusState private var pageContentFocused: Bool

    init(
        session: TastingLensSessionDraft,
        bundle: SensoryKnowledgeBundle,
        selection: TastingLensSelection,
        history: [SipSensorySnapshot] = [],
        preferences: TastingLensUserPreferences,
        learnedPatterns: [LearnedSensoryPattern] = [],
        contentState: TastingLensContentState = .ready,
        selectionBuilder: SelectionBuilder? = nil,
        onComplete: @escaping (TastingLensSessionDraft, TastingLensUserPreferences) -> Void,
        onCancel: @escaping () -> Void,
        onUpdatePreferences: @escaping (TastingLensUserPreferences) -> Void = { _ in },
        onSessionUpdate: @escaping (TastingLensSessionDraft) -> Void = { _ in },
        onRetry: @escaping () -> Void = {}
    ) {
        self.bundle = bundle
        self.history = history
        self.learnedPatterns = learnedPatterns
        self.contentState = contentState
        self.selectionBuilder = selectionBuilder
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onUpdatePreferences = onUpdatePreferences
        self.onSessionUpdate = onSessionUpdate
        self.onRetry = onRetry
        _session = State(initialValue: session)
        _selection = State(initialValue: selection)
        _preferences = State(initialValue: preferences)
        _answers = State(initialValue: Self.makeAnswers(from: session.responses))

        let flavorCriterionIDs = Set([
            selection.criteria.first(where: { $0.id == "criterion.flavor.web" })?.id
                ?? selection.criteria.first(where: {
                    $0.dimension == .flavor && !$0.descriptorRootIDs.isEmpty
                })?.id
        ].compactMap { $0 })
        let flavorResponses = session.responses.filter { flavorCriterionIDs.contains($0.criterionID) }
        _selectedFlavorIDs = State(
            initialValue: Set(flavorResponses.flatMap(\.descriptorIDs))
        )
        _customFlavor = State(
            initialValue: flavorResponses.compactMap(\.customText).first ?? ""
        )
        _flavorState = State(
            initialValue: flavorResponses.first.map { Self.uiStatus($0.state) } ?? .unanswered
        )
        _ownWordsUncertain = State(
            initialValue: session.responses.contains {
                $0.criterionID == "criterion.own_words"
                    && $0.state == .unsure
            }
        )
        let mugsyChoices = session.responses
            .first(where: { $0.criterionID == "criterion.mugsy.leading" })?
            .choiceIDs ?? []
        _leadingSensation = State(initialValue: mugsyChoices.first(where: Self.mugsyLeadingChoiceIDs.contains))
        _mugsyDistinction = State(initialValue: mugsyChoices.first(where: { !Self.mugsyLeadingChoiceIDs.contains($0) }))
    }

    var body: some View {
        Group {
            switch contentState {
            case .loading:
                loadingView
            case .failed(let title, let message):
                errorView(title: title, message: message)
            case .ready, .offline, .notice:
                journey
            }
        }
        .background(Color.creamWhite.ignoresSafeArea())
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .identity:
                TastingLensIdentityEditor(identity: session.identity) { identity in
                    apply(identity: identity)
                }
            case .customize:
                TastingLensCustomizeSheet(
                    criteria: customizableCriteria,
                    identity: session.identity,
                    preferences: preferences
                ) { updatedPreferences in
                    apply(preferences: updatedPreferences)
                }
            }
        }
        .onChange(of: session) { _, updatedSession in
            onSessionUpdate(updatedSession)
        }
    }

    // MARK: Shell

    private var journey: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear
                            .frame(height: 1)
                            .id("tastingLens2.top")

                        if contentState.showsJourneyBanner {
                            TastingLensStatusBanner(state: contentState)
                        }

                        currentPageContent
                            .id(currentPage.id)
                            .accessibilityFocused($pageContentFocused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: currentPage.id) { _, _ in
                    if reduceMotion {
                        proxy.scrollTo("tastingLens2.top", anchor: .top)
                    } else {
                        withAnimation(DesignSystem.Motion.base) {
                            proxy.scrollTo("tastingLens2.top", anchor: .top)
                        }
                    }
                    Task { @MainActor in
                        pageContentFocused = false
                        await Task.yield()
                        pageContentFocused = true
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .onAppear {
            pageContentFocused = true
            onSessionUpdate(session)
        }
    }

    private var header: some View {
        VStack(spacing: 11) {
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 44, height: 44)
                        } else {
                            Text("Cancel")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .frame(minWidth: 60, minHeight: 44, alignment: .leading)
                        }
                    }
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.espressoBrown)
                    .accessibilityLabel("Cancel")
                    .accessibilityIdentifier("tastingLens2.cancel")

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    Text("TASTING LENS")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.8)
                        .foregroundStyle(Color.espressoBrown)
                    Text(progressLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tasting Lens. \(progressLabel)")

                Spacer(minLength: 0)

                Button {
                    presentedSheet = .customize
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.espressoBrown)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Customize My Lens")
                .accessibilityIdentifier("tastingLens2.customize")
            }

            HStack(spacing: 6) {
                ForEach(0..<progressSegmentCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= progressSegmentIndex ? Color.mugshotSage : Color.sandBeige)
                        .frame(height: 5)
                }
            }
            .accessibilityHidden(true)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.creamWhite)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.mugshotLine.opacity(0.75))
                .frame(height: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                if currentPageIndex > 0 {
                    Button {
                        moveBackward()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.espressoBrown)
                            .frame(width: 50, height: 50)
                            .background(Color.foamWhite, in: Circle())
                            .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous question")
                    .accessibilityIdentifier("tastingLens2.back")
                }

                Button(action: performPrimaryAction) {
                    HStack(spacing: 8) {
                        Text(dynamicTypeSize.isAccessibilitySize ? compactPrimaryActionTitle : primaryActionTitle)
                            .font(.body.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Image(systemName: currentPage == .snapshot ? "checkmark" : "arrow.right")
                            .font(.system(size: 14, weight: .black))
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Color.foamWhite)
                    .background(canContinue ? Color.mugshotSage : Color.mugshotSage.opacity(0.38))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
                .accessibilityLabel(primaryActionTitle)
                .accessibilityIdentifier("tastingLens2.primary")
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Text(footerMessage)
                    .font(.caption2)
                    .foregroundStyle(Color.tertiaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .background(Color.creamWhite.opacity(0.9))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.mugshotLine.opacity(0.75))
                .frame(height: 1)
        }
    }

    // MARK: Pages

    @ViewBuilder
    private var currentPageContent: some View {
        switch currentPage {
        case .identity:
            identityPage
        case .ownWords:
            ownWordsPage
        case .flavor:
            flavorPage
        case .mugsy:
            mugsyPage
        case .criterion(let criterionID):
            criterionPage(id: criterionID)
        case .enjoyment:
            enjoymentPage
        case .snapshot:
            snapshotPage
        }
    }

    private var identityPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            TastingLensSectionHeading(
                eyebrow: "Set the lens",
                title: "Make the Lens fit the drink.",
                message: "Mugshot uses the confirmed drink—not a universal coffee form—to choose useful questions."
            )

            TastingLensCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: drinkIdentitySymbol)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Color.mugshotSage)
                            .frame(width: 42, height: 42)
                            .background(Color.mugshotMint.opacity(0.25), in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.identity.displayName)
                                .font(.headline)
                                .foregroundStyle(Color.espressoBrown)
                            Text(session.identity.summary)
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 4)

                        Button("Edit") { presentedSheet = .identity }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.mugshotSage)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("tastingLens2.identity.edit")
                    }

                    if session.identity.userConfirmed {
                        Label("Confirmed by you", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.mugshotSage)
                    } else {
                        Label("Please confirm or edit this before continuing.", systemImage: "questionmark.circle")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }

                    if !selection.explanations.isEmpty {
                        DisclosureGroup("Why these questions?") {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(selection.explanations, id: \.self) { explanation in
                                    Label(explanation, systemImage: "sparkle")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .font(.caption.weight(.bold))
                        .tint(.mugshotSage)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Choose your depth")
                    .font(.headline)
                    .foregroundStyle(Color.espressoBrown)

                ForEach(TastingDepth.allCases) { depth in
                    depthButton(depth)
                }
            }

            Label(
                selection.usedUniversalFallback
                    ? "This drink uses Mugshot's universal offline Lens. You can still describe it fully."
                    : "The knowledge pack works offline and never claims what is in your cup.",
                systemImage: selection.usedUniversalFallback ? "circle.grid.cross" : "checkmark.shield"
            )
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func depthButton(_ depth: TastingDepth) -> some View {
        let selected = session.depth == depth
        return Button {
            apply(depth: depth)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: depthSymbol(depth))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selected ? Color.foamWhite : Color.mugshotSage)
                    .frame(width: 30, height: 30)
                    .background(selected ? Color.foamWhite.opacity(0.14) : Color.mugshotMint.opacity(0.2), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(depth.title)
                        .font(.subheadline.weight(.bold))
                    Text(depthDescription(depth))
                        .font(.caption)
                        .foregroundStyle(selected ? Color.foamWhite.opacity(0.8) : Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(selected ? Color.foamWhite : Color.espressoBrown)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(selected ? Color.mugshotSage : Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(selected ? Color.espressoBrown.opacity(0.65) : Color.mugshotLine, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("tastingLens2.depth.\(depth.rawValue)")
    }

    private var ownWordsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            TastingLensSectionHeading(
                eyebrow: "Your impression first",
                title: "Start with your words.",
                message: "Before any labels, what stands out? A fragment is enough."
            )

            TastingLensCard {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        if session.ownWords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Bright, almost tea-like…")
                                .font(.body)
                                .foregroundStyle(Color.inputPlaceholder)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 9)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $session.ownWords)
                            .font(.body)
                            .foregroundStyle(Color.inputText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 180 : 132)
                            .onChange(of: session.ownWords) { _, newValue in
                                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    ownWordsUncertain = false
                                }
                                persistOwnWordsResponse()
                            }
                            .accessibilityLabel("Your first impression")
                            .accessibilityHint("Suggestions stay hidden until the next step")
                            .accessibilityIdentifier("tastingLens2.ownWords")
                    }
                    .padding(10)
                    .background(Color.creamWhite.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ownWordsUncertain ? Color.mugshotSage : Color.mugshotLine, lineWidth: ownWordsUncertain ? 2 : 1)
                    }

                    TastingLensSelectionChip(
                        label: "Not sure yet",
                        systemImage: "questionmark.circle",
                        isSelected: ownWordsUncertain
                    ) {
                        ownWordsUncertain.toggle()
                        if ownWordsUncertain { session.ownWords = "" }
                        persistOwnWordsResponse()
                    }
                    .accessibilityIdentifier("tastingLens2.ownWords.unsure")
                }
            }

            TastingLensCard(tint: Color.mugshotMint.opacity(0.12), padding: 15) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Suggestions are intentionally hidden")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.espressoBrown)
                        Text("Seeing a list first can influence what people select. Mugshot begins with your memory of the sip, including uncertainty.")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var flavorPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            TastingLensSectionHeading(
                eyebrow: "Broad to specific",
                title: "Explore the sip.",
                message: "Open one broad family, then choose only the details that feel useful. There is no correct number."
            )

            if let provenanceMessage {
                Label(provenanceMessage, systemImage: "square.3.layers.3d")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.sandBeige.opacity(0.42))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            TastingLensFlavorExplorer(
                branches: flavorBranches,
                selectedLeafIDs: $selectedFlavorIDs,
                customFlavor: $customFlavor
            )
            .onChange(of: selectedFlavorIDs) { _, newValue in
                if !newValue.isEmpty {
                    flavorState = .observed
                } else if customFlavor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          flavorState == .observed {
                    flavorState = .unanswered
                }
                persistFlavorResponse()
            }
            .onChange(of: customFlavor) { _, newValue in
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    flavorState = .observed
                } else if selectedFlavorIDs.isEmpty, flavorState == .observed {
                    flavorState = .unanswered
                }
                persistFlavorResponse()
            }

            TastingLensFlowLayout(spacing: 8) {
                TastingLensSelectionChip(
                    label: "Nothing clear",
                    systemImage: "circle.slash",
                    isSelected: flavorState == .notPresent
                ) { setFlavorState(.notPresent) }
                TastingLensSelectionChip(
                    label: "Not sure yet",
                    systemImage: "questionmark.circle",
                    isSelected: flavorState == .unsure
                ) { setFlavorState(.unsure) }
                TastingLensSelectionChip(
                    label: "Skip",
                    systemImage: "forward",
                    isSelected: flavorState == .skipped
                ) { setFlavorState(.skipped) }
            }

            Text("These are possibilities to investigate—not claims about what the drink contains.")
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var mugsyPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            TastingLensSectionHeading(
                eyebrow: "One guided distinction",
                title: "Notice what arrives first.",
                message: "Mugsy steps in only where a small distinction can make the next sip easier to describe."
            )

            TastingLensMugsyMoment(
                identity: session.identity,
                leadingSensation: $leadingSensation,
                distinction: $mugsyDistinction
            )
            .onChange(of: leadingSensation) { _, _ in persistMugsyResponse() }
            .onChange(of: mugsyDistinction) { _, _ in persistMugsyResponse() }

            Text("This moment does not score your answer or judge your palate.")
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
        }
    }

    @ViewBuilder
    private func criterionPage(id: String) -> some View {
        if let item = criterionItems.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 18) {
                TastingLensSectionHeading(
                    eyebrow: item.dimension,
                    title: item.prompt,
                    message: item.helper
                )

                TastingLensCard {
                    TastingLensCriterionControlView(
                        criterion: item,
                        answer: answerBinding(for: id)
                    )
                }

                if shouldShowSafetyCheck(for: id) {
                    Label(
                        "If this seems like actual mold, spoiled milk, a cleaning chemical, or contamination, stop drinking and ask the cafe to check it. This note stays outside your rating.",
                        systemImage: "exclamationmark.shield.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.sandBeige.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("tastingLens2.safetyCheck")
                }

                DisclosureGroup("Why this question appeared") {
                    Text(item.whyItAppeared)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 7)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.espressoBrown)
                .tint(.mugshotSage)

                let sources = evidenceSources(for: id)
                if !sources.isEmpty {
                    DisclosureGroup("Evidence and limits") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(sources.prefix(3))) { source in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let url = URL(string: source.url) {
                                        Link(source.title, destination: url)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.mugshotSage)
                                            .frame(minHeight: 44, alignment: .leading)
                                            .contentShape(Rectangle())
                                    } else {
                                        Text(source.title)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.espressoBrown)
                                    }
                                    Text("\(source.evidenceClass.consumerLabel) · \(source.confidence.consumerLabel) confidence")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.secondaryText)
                                    Text(source.attribution)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                    if let limit = source.doNotInfer?.trimmingCharacters(in: .whitespacesAndNewlines),
                                       !limit.isEmpty {
                                        Text("Limit: \(limit)")
                                            .font(.caption2)
                                            .foregroundStyle(Color.tertiaryText)
                                    }
                                }
                            }
                            Text("Professional methods inform the prompt; this remains consumer reflection, not certification or an objective grade.")
                                .font(.caption2)
                                .foregroundStyle(Color.tertiaryText)
                        }
                        .padding(.top, 7)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.espressoBrown)
                    .tint(.mugshotSage)
                }

                criterionPreferenceActions(id: id)
            }
        } else {
            ContentUnavailableView(
                "Question unavailable",
                systemImage: "questionmark.circle",
                description: Text("The Lens kept your other answers. Continue to the next question.")
            )
        }
    }

    private func criterionPreferenceActions(id: String) -> some View {
        let isPinned = preferences.pinnedCriterionIDs(for: session.identity.personalizationScopeID).contains(id)
        return HStack(spacing: 8) {
            Button {
                setCriterion(id: id, pinned: !isPinned)
            } label: {
                Label(isPinned ? "Pinned to my Lens" : "Pin to my Lens", systemImage: isPinned ? "pin.fill" : "pin")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isPinned ? .isSelected : [])

            Spacer(minLength: 8)

            Button("Hide for this drink type") {
                hideCriterion(id: id)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.secondaryText)
            .frame(minHeight: 44)
            .buttonStyle(.plain)
        }
    }

    private var enjoymentPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            TastingLensSectionHeading(
                eyebrow: "Personal enjoyment",
                title: "How was this drink for you?",
                message: "Now that you have observed the sip, give it one independent personal rating."
            )

            TastingLensCard {
                TastingLensEnjoymentRating(value: enjoymentBinding)
            }

            TastingLensCard(tint: Color.sandBeige.opacity(0.36), padding: 15) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("The observations do not calculate these stars", systemImage: "equal.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text("A bitter espresso can be a five-star favorite. A technically polished matcha can still be two stars for you. Neither answer is contradictory.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var snapshotPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            TastingLensSectionHeading(
                eyebrow: "Taste Snapshot",
                title: "A memory, not a formula.",
                message: "Your words, observations, and enjoyment stay distinct so this sip remains understandable later."
            )

            TastingLensCard(tint: Color.mugshotMint.opacity(0.12)) {
                HStack(alignment: .center, spacing: 16) {
                    if !snapshotBloomSamples.isEmpty {
                        MugshotTasteBloom(
                            samples: snapshotBloomSamples,
                            confidence: snapshotBloomConfidence,
                            size: dynamicTypeSize.isAccessibilitySize ? 92 : 108
                        )
                        .accessibilitySortPriority(1)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.identity.displayName)
                            .font(.headline)
                            .foregroundStyle(Color.espressoBrown)
                        Text(session.identity.summary)
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                        if let rating = session.personalEnjoyment {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(rating.value.formatted(.number.precision(.fractionLength(1))))
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(Color.mugshotSage)
                                Text(rating.anchor)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                    }
                }
            }

            if !session.ownWords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                snapshotSection(title: "Your first words", icon: "quote.opening") {
                    Text("“\(session.ownWords.trimmingCharacters(in: .whitespacesAndNewlines))”")
                        .font(.system(.title3, design: .serif, weight: .regular))
                        .foregroundStyle(Color.espressoBrown)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !selectedFlavorIDs.isEmpty || !customFlavor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                snapshotSection(title: "Vocabulary from this sip", icon: "circle.hexagongrid") {
                    TastingLensFlowLayout(spacing: 8) {
                        ForEach(selectedFlavorLabels, id: \.self) { label in
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.espressoBrown)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 36)
                                .background(Color.mugshotMint.opacity(0.24), in: Capsule())
                        }
                        if !customFlavor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(customFlavor.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.espressoBrown)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 36)
                                .background(Color.sandBeige.opacity(0.72), in: Capsule())
                        }
                    }
                }
            }

            if !responseSummaries.isEmpty {
                snapshotSection(title: "The sip in detail", icon: "list.bullet.rectangle") {
                    VStack(spacing: 10) {
                        ForEach(responseSummaries) { summary in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(summary.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.espressoBrown)
                                Spacer(minLength: 12)
                                Text(summary.value)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .multilineTextAlignment(.trailing)
                            }
                            if summary.id != responseSummaries.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            if let previousSipComparison {
                snapshotSection(title: "Compared with your last similar sip", icon: "arrow.left.arrow.right") {
                    Text(previousSipComparison)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("This comparison describes your own saved records. It does not rank either drink or infer a cause.")
                        .font(.caption2)
                        .foregroundStyle(Color.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            learnedEvidenceSection

            TastingLensCard(tint: Color.mugshotMint.opacity(0.1), padding: 15) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.mugshotSage)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your full Lens stays private")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.espressoBrown)
                        Text("Your first words, confidence, and complete observation trail are saved for you. Mugshot shares no sensory summary unless you make a separate sharing choice.")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text("Nothing here is a Q score, professional calibration, or objective quality grade.")
                .font(.caption2)
                .foregroundStyle(Color.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private func snapshotSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TastingLensCard {
            VStack(alignment: .leading, spacing: 13) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.mugshotSage)
                content()
            }
        }
    }

    @ViewBuilder
    private var learnedEvidenceSection: some View {
        let patterns = visibleLearnedPatterns

        if !patterns.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Mugshot is learning with you")
                        .font(.headline)
                        .foregroundStyle(Color.espressoBrown)
                    Spacer()
                    Text("Evidence shown")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.mugshotSage)
                }

                ForEach(patterns.prefix(3)) { pattern in
                    TastingLensLearnedPatternCard(
                        pattern: patternItem(pattern),
                        onDismiss: { dismiss(pattern: pattern) },
                        onMarkLatestMistake: { markLatestEvidenceMistaken(pattern: pattern) }
                    )
                }

                Text("Patterns only compare your own confirmed, same-type tastings. They never label your palate or change a rating.")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            TastingLensCard(tint: Color.sandBeige.opacity(0.34), padding: 15) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(Color.mugshotSage)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Learning at your pace")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.espressoBrown)
                        Text(learningEmptyMessage)
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Loading and error

    private var loadingView: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.espressoBrown)
                    .frame(minHeight: 44)
                Spacer()
                Text("TASTING LENS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.8)
                    .foregroundStyle(Color.espressoBrown)
                Spacer()
                Color.clear.frame(width: 52, height: 44)
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TastingLensStatusBanner(state: contentState)
                    TastingLensSectionHeading(
                        eyebrow: "Preparing",
                        title: "Making this Lens fit.",
                        message: "Loading the versioned sensory pack and your confirmed preferences."
                    )
                    TastingLensCard {
                        VStack(alignment: .leading, spacing: 12) {
                            RoundedRectangle(cornerRadius: 8).fill(Color.sandBeige).frame(height: 20)
                            RoundedRectangle(cornerRadius: 8).fill(Color.sandBeige).frame(height: 52)
                            RoundedRectangle(cornerRadius: 8).fill(Color.sandBeige).frame(width: 180, height: 20)
                        }
                    }
                    .redacted(reason: .placeholder)
                }
                .padding(20)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tastingLens2.loading")
    }

    private func errorView(title: String, message: String) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(width: 68, height: 68)
                    .background(Color.sandBeige.opacity(0.62), in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(.title, design: .serif, weight: .regular))
                    .foregroundStyle(Color.espressoBrown)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again", action: onRetry)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("tastingLens2.retry")
                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tastingLens2.error")
    }

    // MARK: Flow state

    private enum Page: Equatable, Identifiable {
        case identity
        case ownWords
        case flavor
        case mugsy
        case criterion(String)
        case enjoyment
        case snapshot

        var id: String {
            switch self {
            case .identity: return "identity"
            case .ownWords: return "ownWords"
            case .flavor: return "flavor"
            case .mugsy: return "mugsy"
            case .criterion(let id): return "criterion.\(id)"
            case .enjoyment: return "enjoyment"
            case .snapshot: return "snapshot"
            }
        }
    }

    private var pages: [Page] {
        if session.depth == .quick {
            return [.identity, .ownWords, .enjoyment, .snapshot]
        }
        return [.identity, .ownWords, .flavor, .mugsy]
            + criterionItems.map { .criterion($0.id) }
            + [.enjoyment, .snapshot]
    }

    private var currentPage: Page {
        pages[min(max(currentPageIndex, 0), max(pages.count - 1, 0))]
    }

    private var progressSegmentCount: Int {
        max(pages.count - 1, 1)
    }

    private var progressSegmentIndex: Int {
        min(currentPageIndex, progressSegmentCount - 1)
    }

    private var progressLabel: String {
        if currentPage == .snapshot { return "Snapshot ready" }
        return "Step \(progressSegmentIndex + 1) of \(progressSegmentCount)"
    }

    private var canContinue: Bool {
        switch currentPage {
        case .identity:
            return !session.identity.displayName.isEmpty
        case .ownWords:
            return session.depth == .quick
                || ownWordsUncertain
                || !session.ownWords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .flavor:
            return flavorState != .unanswered
                || !selectedFlavorIDs.isEmpty
                || !customFlavor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .mugsy:
            return true
        case .criterion(let id):
            return answers[id]?.hasResponse == true || criterionItems.first(where: { $0.id == id }) == nil
        case .enjoyment:
            return session.personalEnjoyment != nil
        case .snapshot:
            return true
        }
    }

    private var primaryActionTitle: String {
        switch currentPage {
        case .identity:
            return session.identity.userConfirmed ? "Continue" : "This looks right"
        case .ownWords:
            if session.depth == .quick,
               session.ownWords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !ownWordsUncertain {
                return "Skip for now"
            }
            return "Keep my words"
        case .flavor:
            return "Keep exploring"
        case .mugsy:
            return "Continue"
        case .criterion:
            return "Next observation"
        case .enjoyment:
            return "See my Taste Snapshot"
        case .snapshot:
            return "Use this Taste Snapshot"
        }
    }

    private var compactPrimaryActionTitle: String {
        switch currentPage {
        case .identity:
            return session.identity.userConfirmed ? "Continue" : "Confirm"
        case .ownWords:
            if session.depth == .quick,
               session.ownWords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !ownWordsUncertain {
                return "Skip"
            }
            return "Keep words"
        case .flavor, .mugsy:
            return "Continue"
        case .criterion:
            return "Next"
        case .enjoyment:
            return "View snapshot"
        case .snapshot:
            return "Use snapshot"
        }
    }

    private var footerMessage: String {
        switch currentPage {
        case .identity:
            return "You stay in control of the drink identity and depth."
        case .ownWords:
            return "No descriptor suggestions are shown on this step."
        case .flavor:
            return "Broad families open into optional, more specific language."
        case .mugsy:
            return "Mugsy guides one distinction, then steps aside."
        case .criterion:
            return "Intensity, preference, confidence, and enjoyment stay separate."
        case .enjoyment:
            return "Only this personal rating becomes the stars on your sip."
        case .snapshot:
            return "Saving freezes the meaning of this versioned sensory record."
        }
    }

    private func performPrimaryAction() {
        guard canContinue else { return }
        persistCurrentPage()

        if currentPage == .snapshot {
            onComplete(session, preferences)
            return
        }

        withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
            currentPageIndex = min(currentPageIndex + 1, pages.count - 1)
        }
        MugshotHaptic.softImpact.play()
    }

    private func moveBackward() {
        persistCurrentPage()
        withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
            currentPageIndex = max(0, currentPageIndex - 1)
        }
    }

    private func persistCurrentPage() {
        switch currentPage {
        case .identity:
            session.identity.userConfirmed = true
            rebuildSelection()
        case .ownWords:
            persistOwnWordsResponse()
        case .flavor:
            persistFlavorResponse()
        case .mugsy:
            persistMugsyResponse()
        case .criterion(let id):
            persistAnswer(for: id)
        case .enjoyment, .snapshot:
            break
        }
        session.updatedAt = .now
    }

    private func persistOwnWordsResponse() {
        guard let criterion = selection.criteria.first(where: { $0.id == "criterion.own_words" })
                ?? selection.criteria.first(where: { $0.measure == .ownWords }) else { return }
        let text = session.ownWords.trimmingCharacters(in: .whitespacesAndNewlines)
        let state: SensoryResponseState
        if !text.isEmpty {
            state = .observed
        } else if ownWordsUncertain {
            state = .unsure
        } else {
            state = .skipped
        }
        session.setResponse(
            SensoryResponseDraft(
                criterionID: criterion.id,
                state: state,
                customText: text.isEmpty ? nil : text,
                suggestionOrigin: .neutralPrompt,
                sourcePackIDs: rankedCriterion(id: criterion.id)?.sourcePackIDs ?? [],
                userConfirmed: true,
                displayedOrder: criterion.order
            )
        )
    }

    private func persistFlavorResponse() {
        guard let criterion = flavorCriterion else { return }
        let trimmedCustomFlavor = customFlavor.trimmingCharacters(in: .whitespacesAndNewlines)
        let state: SensoryResponseState
        if !selectedFlavorIDs.isEmpty || !trimmedCustomFlavor.isEmpty {
            state = .observed
        } else {
            state = domainStatus(flavorState)
        }
        session.setResponse(
            SensoryResponseDraft(
                criterionID: criterion.id,
                state: state,
                descriptorIDs: selectedFlavorIDs.sorted(),
                customText: trimmedCustomFlavor.isEmpty ? nil : trimmedCustomFlavor,
                suggestionOrigin: rankedCriterion(id: criterion.id)?.origin ?? .basePack,
                sourcePackIDs: rankedCriterion(id: criterion.id)?.sourcePackIDs ?? [],
                userConfirmed: true,
                displayedOrder: criterion.order
            )
        )
    }

    private func persistAnswer(for criterionID: String) {
        guard let criterion = selection.criteria.first(where: { $0.id == criterionID }),
              let answer = answers[criterionID] else { return }

        let intensityScale: SensoryIntensityScale = criterion.scaleID?.contains("5") == true ? .deepFive : .consumerThree
        let preference: SensoryPreference?
        switch answer.preference {
        case 1: preference = .notForMe
        case 2: preference = .neutral
        case 3: preference = .liked
        default: preference = nil
        }
        let confidence: SensoryConfidence?
        switch answer.confidence {
        case .learning: confidence = .learning
        case .maybe: confidence = .maybe
        case .sure: confidence = .sure
        case nil: confidence = nil
        }
        let selectedChoiceIDs = criterion.options.isEmpty ? [] : answer.selectedIDs.sorted()
        let descriptorIDs: [String]
        if criterion.options.isEmpty {
            descriptorIDs = criterion.measure == .preference ? [] : answer.selectedIDs.sorted()
        } else {
            descriptorIDs = criterion.options
                .filter { answer.selectedIDs.contains($0.id) }
                .compactMap(\.descriptorID)
                .sensoryUnique
        }
        let trimmedCustomText = answer.customText.trimmingCharacters(in: .whitespacesAndNewlines)

        session.setResponse(
            SensoryResponseDraft(
                criterionID: criterionID,
                state: domainStatus(answer.status),
                descriptorIDs: descriptorIDs,
                choiceIDs: selectedChoiceIDs,
                customText: trimmedCustomText.isEmpty ? nil : trimmedCustomText,
                intensity: answer.intensity.flatMap { SensoryIntensityValue(scale: intensityScale, level: $0) },
                duration: answer.duration,
                preference: preference,
                qualityImpression: answer.quality.flatMap(SensoryQualityImpression.init),
                confidence: confidence,
                suggestionOrigin: rankedCriterion(id: criterionID)?.origin ?? .basePack,
                sourcePackIDs: rankedCriterion(id: criterionID)?.sourcePackIDs ?? [],
                userConfirmed: true,
                displayedOrder: criterion.order
            )
        )
    }

    private func persistMugsyResponse() {
        guard let criterion = selection.criteria.first(where: { $0.id == "criterion.mugsy.leading" }) else { return }
        let selectedIDs = [leadingSensation, mugsyDistinction].compactMap { $0 }.sensoryUnique
        let state: SensoryResponseState
        if leadingSensation == "mugsy.unsure" {
            state = .unsure
        } else if selectedIDs.isEmpty {
            state = .skipped
        } else {
            state = .observed
        }
        let descriptorIDs = criterion.options
            .filter { selectedIDs.contains($0.id) }
            .compactMap(\.descriptorID)
            .sensoryUnique
        session.setResponse(SensoryResponseDraft(
            criterionID: criterion.id,
            state: state,
            descriptorIDs: descriptorIDs,
            choiceIDs: selectedIDs,
            confidence: state == .unsure || mugsyDistinction == "mugsy.followup_unsure" ? .learning : nil,
            suggestionOrigin: .neutralPrompt,
            sourcePackIDs: rankedCriterion(id: criterion.id)?.sourcePackIDs ?? [],
            userConfirmed: true,
            displayedOrder: criterion.order
        ))
    }

    // MARK: Adaptation and preferences

    private func apply(identity: SensoryDrinkIdentity) {
        session.identity = identity
        rebuildSelection()
    }

    private func apply(depth: TastingDepth) {
        guard session.depth != depth else { return }
        session.depth = depth
        rebuildSelection()
    }

    private func apply(preferences updatedPreferences: TastingLensUserPreferences) {
        preferences = updatedPreferences
        onUpdatePreferences(updatedPreferences)
        rebuildSelection()
    }

    private func rebuildSelection() {
        let previousPageID = pages.indices.contains(currentPageIndex) ? currentPage.id : nil
        let previousPageIndex = currentPageIndex
        if let selectionBuilder {
            selection = selectionBuilder(session.identity, session.depth, preferences)
        } else {
            selection = TastingLensSelection(
                identity: session.identity,
                basePack: selection.basePack,
                overlays: selection.overlays,
                orderedCriteria: selection.orderedCriteria,
                descriptors: selection.descriptors,
                usedUniversalFallback: selection.usedUniversalFallback,
                explanations: selection.explanations
            )
        }
        session.activePackIDs = selection.activePackIDs
        reconcileAnswersWithSelection()
        if let previousPageID,
           let matchingIndex = pages.firstIndex(where: { $0.id == previousPageID }) {
            currentPageIndex = matchingIndex
        } else {
            currentPageIndex = min(previousPageIndex, max(pages.count - 1, 0))
        }
    }

    private func reconcileAnswersWithSelection() {
        let allowedFlavorIDs = Set(flavorBranches.flatMap { $0.children.map(\.id) })
        let reconciledFlavorIDs = selectedFlavorIDs.intersection(allowedFlavorIDs)
        if reconciledFlavorIDs != selectedFlavorIDs {
            selectedFlavorIDs = reconciledFlavorIDs
            if selectedFlavorIDs.isEmpty,
               customFlavor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               flavorState == .observed {
                flavorState = .unanswered
            }
            persistFlavorResponse()
        }

        for criterion in selection.criteria {
            guard criterion.id != "criterion.own_words",
                  criterion.id != "criterion.flavor.web",
                  criterion.id != "criterion.mugsy.leading" else {
                continue
            }
            guard var answer = answers[criterion.id] else { continue }
            let allowedChoiceIDs = Set(criterion.options.map(\.id))
            if !allowedChoiceIDs.isEmpty {
                answer.selectedIDs.formIntersection(allowedChoiceIDs)
            } else if criterion.measure == .singleChoice
                        || criterion.measure == .multipleChoice
                        || criterion.measure == .presence {
                let allowedDescriptorIDs = Set(
                    descriptorLeaves(rootIDs: criterion.descriptorRootIDs).map(\.id)
                )
                answer.selectedIDs.formIntersection(allowedDescriptorIDs)
            }
            if answer.status == .observed,
               answer.selectedIDs.isEmpty,
               answer.intensity == nil,
               answer.duration == nil,
               answer.preference == nil,
               answer.quality == nil,
               answer.confidence == nil,
               answer.customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                answer.status = .unanswered
            }
            answers[criterion.id] = answer
            if answer.hasResponse {
                persistAnswer(for: criterion.id)
            }
        }
    }

    private func setCriterion(id: String, pinned: Bool) {
        let scopeID = session.identity.personalizationScopeID
        var updated = preferences
        var ids = updated.pinnedCriterionIDsByScope[scopeID] ?? []
        if pinned {
            if !ids.contains(id) { ids.append(id) }
        } else {
            ids.removeAll { $0 == id }
        }
        updated.pinnedCriterionIDsByScope[scopeID] = ids
        updated.updatedAt = .now
        apply(preferences: updated)
    }

    private func hideCriterion(id: String) {
        var updated = preferences
        updated.dismissals.append(
            SensorySuggestionDismissal(
                targetID: id,
                scopeID: session.identity.personalizationScopeID,
                reason: .notRelevant
            )
        )
        updated.updatedAt = .now
        apply(preferences: updated)
    }

    private func dismiss(pattern: LearnedSensoryPattern) {
        var updated = preferences
        updated.dismissals.append(
            SensorySuggestionDismissal(
                targetID: pattern.targetID,
                scopeID: pattern.scopeID,
                reason: .notUseful
            )
        )
        updated.updatedAt = .now
        preferences = updated
        onUpdatePreferences(updated)
    }

    private func markLatestEvidenceMistaken(pattern: LearnedSensoryPattern) {
        let evidenceIDs = Set(pattern.evidenceSnapshotIDs)
        guard let snapshot = history
            .filter({ evidenceIDs.contains($0.id) })
            .max(by: { $0.createdAt < $1.createdAt }) else {
            return
        }
        var updated = preferences
        updated.dismissals.removeAll {
            $0.targetID == pattern.targetID
                && $0.scopeID == pattern.scopeID
                && $0.snapshotID == snapshot.id
                && $0.reason == .selectedByMistake
        }
        updated.dismissals.append(SensorySuggestionDismissal(
            targetID: pattern.targetID,
            scopeID: pattern.scopeID,
            snapshotID: snapshot.id,
            reason: .selectedByMistake
        ))
        updated.updatedAt = .now
        preferences = updated
        onUpdatePreferences(updated)
    }

    private func setFlavorState(_ status: TastingLensAnswerStatus) {
        if flavorState == status {
            flavorState = .unanswered
        } else {
            flavorState = status
            selectedFlavorIDs = []
            customFlavor = ""
        }
        persistFlavorResponse()
    }

    // MARK: Presentation adapters

    private var criterionItems: [TastingLensCriterionItem] {
        selection.orderedCriteria.compactMap { ranked in
            let criterion = ranked.criterion
            guard criterion.id != "criterion.own_words",
                  criterion.measure != .overallEnjoyment,
                  criterion.id != "criterion.flavor.web",
                  criterion.id != "criterion.mugsy.leading" else {
                return nil
            }

            return TastingLensCriterionItem(
                id: criterion.id,
                title: criterion.title,
                dimension: criterion.dimension.displayTitle,
                prompt: criterion.prompt,
                helper: criterion.helper ?? criterion.dimension.defaultHelper,
                whyItAppeared: ranked.explanation,
                control: control(for: criterion),
                scaleAnchors: criterion.scaleID
                    .flatMap(bundle.scale(id:))?
                    .anchors
                    .map { TastingLensScaleAnchorItem(value: $0.value, label: $0.label, anchor: $0.anchor) } ?? [],
                supportsNotPresent: criterion.measure != .qualityImpression
                    && criterion.measure != .preference
                    && criterion.measure != .confidence,
                supportsNotRelevant: true,
                showsInlineConfidence: session.depth == .deep
            )
        }
    }

    private var customizableCriteria: [SensoryCriterionDefinition] {
        var inclusivePreferences = preferences
        inclusivePreferences.dismissals.removeAll {
            $0.snapshotID == nil && $0.reason == .notRelevant
        }
        let customIDs = Set(inclusivePreferences.customCriteria.map(\.id))
        return TastingLensSelectionService().makeSelection(
            analysis: nil,
            confirmedIdentity: session.identity,
            depth: .deep,
            bundle: bundle,
            preferences: inclusivePreferences,
            patterns: learnedPatterns
        ).criteria.filter { !customIDs.contains($0.id) }
    }

    private func control(for criterion: SensoryCriterionDefinition) -> TastingLensCriterionControl {
        let choices: [TastingLensFlavorLeaf]
        if !criterion.options.isEmpty {
            choices = criterion.options.map {
                TastingLensFlavorLeaf(id: $0.id, label: $0.label, helper: $0.helper)
            }
        } else {
            choices = descriptorLeaves(rootIDs: criterion.descriptorRootIDs)
        }

        switch criterion.measure {
        case .ownWords:
            return .freeText
        case .intensity:
            return .intensity
        case .duration:
            return .duration
        case .singleChoice, .presence:
            let fallback = choices.isEmpty
                ? [TastingLensFlavorLeaf(id: "present", label: "I notice it")]
                : choices
            return .singleChoice(fallback)
        case .multipleChoice:
            return .multipleChoice(choices)
        case .preference:
            let mappedChoices = criterion.options.enumerated().map { index, option in
                TastingLensPreferenceChoice(
                    id: option.id,
                    label: option.label,
                    value: preferenceValue(for: option, fallbackIndex: index),
                    helper: option.helper
                )
            }
            return .preference(mappedChoices.isEmpty ? [
                TastingLensPreferenceChoice(id: "preference.not_for_me", label: "Not for me", value: 1),
                TastingLensPreferenceChoice(id: "preference.neutral", label: "Neutral", value: 2),
                TastingLensPreferenceChoice(id: "preference.liked", label: "I liked it", value: 3)
            ] : mappedChoices)
        case .confidence:
            return .confidence
        case .qualityImpression:
            return .quality
        case .overallEnjoyment:
            return .singleChoice([])
        }
    }

    private func preferenceValue(
        for option: SensoryChoiceDefinition,
        fallbackIndex: Int
    ) -> Int {
        let semanticText = "\(option.id) \(option.label)".lowercased()
        if semanticText.contains("not_for_me")
            || semanticText.contains("not for me")
            || semanticText.contains("distract") {
            return 1
        }
        if semanticText.contains("neutral") || semanticText.contains("mixed") {
            return 2
        }
        if semanticText.contains("liked")
            || semanticText.contains("like")
            || semanticText.contains("adds to") {
            return 3
        }
        return min(max(fallbackIndex + 1, 1), 3)
    }

    private var flavorBranches: [TastingLensFlavorBranch] {
        let descriptorIDs = Set(selection.descriptors.map(\.id))
        let roots = selection.descriptors.filter { descriptor in
            guard let parentID = descriptor.parentID else { return true }
            return !descriptorIDs.contains(parentID)
        }
        let rootsByID = Dictionary(uniqueKeysWithValues: roots.map { ($0.id, $0) })
        let priorityIDs = (
            selection.basePack.descriptorRootIDs
                + selection.overlays.flatMap(\.descriptorRootIDs)
                + selection.orderedCriteria.flatMap { $0.criterion.descriptorRootIDs }
        )
        var seen = Set<String>()
        var orderedRoots = priorityIDs.compactMap { descriptorID -> SensoryDescriptorDefinition? in
            let rootID = topLevelSelectionRootID(for: descriptorID, descriptorIDs: descriptorIDs)
            guard seen.insert(rootID).inserted else { return nil }
            return rootsByID[rootID]
        }
        orderedRoots.append(contentsOf: roots
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id < rhs.id
            })

        return Array(orderedRoots.prefix(8)).enumerated().map { index, root in
            TastingLensFlavorBranch(
                id: root.id,
                label: root.title,
                systemImage: flavorSymbol(for: root.title),
                tint: flavorTints[index % flavorTints.count],
                children: descriptorLeaves(rootIDs: [root.id])
            )
        }
    }

    private func descriptorLeaves(rootIDs: [String]) -> [TastingLensFlavorLeaf] {
        let allowedDescriptorIDs = Set(selection.descriptors.map(\.id))
        return rootIDs.flatMap { rootID -> [TastingLensFlavorLeaf] in
            guard allowedDescriptorIDs.contains(rootID) else { return [] }
            let directChildren = bundle.descriptorChildren(of: rootID)
                .filter { allowedDescriptorIDs.contains($0.id) }
            if directChildren.isEmpty,
               let root = selection.descriptors.first(where: { $0.id == rootID }) {
                return [TastingLensFlavorLeaf(id: root.id, label: root.title, helper: root.definition)]
            }

            return directChildren.flatMap { child -> [TastingLensFlavorLeaf] in
                let grandchildren = bundle.descriptorChildren(of: child.id)
                    .filter { allowedDescriptorIDs.contains($0.id) }
                if grandchildren.isEmpty {
                    return [TastingLensFlavorLeaf(id: child.id, label: child.title, helper: child.definition)]
                }
                return grandchildren.map {
                    TastingLensFlavorLeaf(
                        id: $0.id,
                        label: "\(child.title) · \($0.title)",
                        helper: $0.definition
                    )
                }
            }
        }
    }

    private func topLevelSelectionRootID(
        for descriptorID: String,
        descriptorIDs: Set<String>
    ) -> String {
        var currentID = descriptorID
        var visited = Set<String>()
        while visited.insert(currentID).inserted,
              let parentID = bundle.descriptor(id: currentID)?.parentID,
              descriptorIDs.contains(parentID) {
            currentID = parentID
        }
        return currentID
    }

    private var flavorCriterion: SensoryCriterionDefinition? {
        selection.criteria.first(where: { $0.id == "criterion.flavor.web" })
            ?? selection.criteria.first {
                $0.dimension == .flavor && !$0.descriptorRootIDs.isEmpty
            }
    }

    private func rankedCriterion(id: String) -> RankedSensoryCriterion? {
        selection.orderedCriteria.first { $0.id == id }
    }

    private func evidenceSources(for criterionID: String) -> [SensorySourceReference] {
        guard let criterion = selection.criteria.first(where: { $0.id == criterionID }) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: bundle.sources.map { ($0.id, $0) })
        return criterion.evidenceSourceIDs.compactMap { byID[$0] }
    }

    private func answerBinding(for criterionID: String) -> Binding<TastingLensCriterionAnswer> {
        Binding(
            get: { answers[criterionID] ?? TastingLensCriterionAnswer() },
            set: { updatedAnswer in
                answers[criterionID] = updatedAnswer
                persistAnswer(for: criterionID)
            }
        )
    }

    private var enjoymentBinding: Binding<Double> {
        Binding(
            get: { session.personalEnjoyment?.value ?? 0 },
            set: { newValue in
                session.personalEnjoyment = PersonalEnjoymentRating(value: newValue)
                session.updatedAt = .now
            }
        )
    }

    private var selectedFlavorLabels: [String] {
        selectedFlavorIDs.compactMap { id in
            bundle.descriptor(id: id)?.title
                ?? selection.descriptors.first(where: { $0.id == id })?.title
        }.sorted()
    }

    private var responseSummaries: [ResponseSummary] {
        criterionItems.compactMap { item in
            guard let answer = answers[item.id], answer.hasResponse else { return nil }
            return ResponseSummary(id: item.id, title: item.title, value: answerSummary(answer, item: item))
        }
    }

    private func answerSummary(_ answer: TastingLensCriterionAnswer, item: TastingLensCriterionItem) -> String {
        guard answer.status == .observed else { return answer.status.label }
        let customText = answer.customText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customText.isEmpty { return customText }
        if let intensity = answer.intensity {
            return item.scaleAnchors.first(where: { $0.value == intensity })?.label
                ?? [1: "Low", 2: "Medium", 3: "High"][intensity]
                ?? "Level \(intensity)"
        }
        if let duration = answer.duration {
            return duration.title
        }
        if !answer.selectedIDs.isEmpty {
            let labels: [String]
            switch item.control {
            case .singleChoice(let choices), .multipleChoice(let choices):
                labels = choices.filter { answer.selectedIDs.contains($0.id) }.map(\.label)
            default:
                labels = answer.selectedIDs.sorted()
            }
            return labels.joined(separator: ", ")
        }
        if let preference = answer.preference {
            return [1: "Not for me", 2: "Neutral", 3: "I liked it"][preference] ?? "Recorded"
        }
        if let quality = answer.quality {
            return "Personal style impression \(quality) of 5"
        }
        if let confidence = answer.confidence {
            return confidence.label
        }
        return "Observed"
    }

    private struct ResponseSummary: Identifiable {
        let id: String
        let title: String
        let value: String
    }

    private var visibleLearnedPatterns: [LearnedSensoryPattern] {
        let recalculated = history.isEmpty
            ? learnedPatterns
            : TastingLensPersonalizationEngine().learnedPatterns(
                userID: preferences.userID,
                snapshots: history,
                preferences: preferences,
                bundle: bundle
            )
        return recalculated.filter {
            $0.scopeID == session.identity.personalizationScopeID
                && !preferences.suppressesPattern(targetID: $0.targetID, scopeID: $0.scopeID)
        }
    }

    private func patternItem(_ pattern: LearnedSensoryPattern) -> TastingLensLearnedPatternItem {
        let scope = session.identity.family.title.lowercased() + " tastings"
        let sureCount = pattern.confidenceCounts.sure
        let confidence = pattern.supportCount > 0
            ? Double(sureCount) / Double(pattern.supportCount)
            : 0
        return TastingLensLearnedPatternItem(
            id: pattern.id,
            title: pattern.title,
            detail: pattern.evidenceSummary,
            supportCount: pattern.supportCount,
            opportunityCount: pattern.totalCount,
            scope: scope,
            confidence: confidence
        )
    }

    private var scopeHistoryCount: Int {
        history.filter { $0.personalizationScopeID == session.identity.personalizationScopeID }.count
    }

    private var learningEmptyMessage: String {
        if scopeHistoryCount == 0 {
            return "This is the first confirmed \(session.identity.family.title.lowercased()) snapshot in this scope. Repeated observations—not vocabulary size—will shape future prompts."
        }
        return "Mugshot has \(scopeHistoryCount) confirmed \(session.identity.family.title.lowercased()) snapshot\(scopeHistoryCount == 1 ? "" : "s") here. A prompt is promoted only after repeated support, normally at least three tastings."
    }

    private var snapshotBloomSamples: [TasteBloomSample] {
        visibleLearnedPatterns.prefix(6).map {
            TasteBloomSample(
                label: $0.title,
                value: Double($0.supportCount) / Double(max($0.totalCount, 1)),
                support: $0.supportCount
            )
        }
    }

    private var snapshotBloomConfidence: Double {
        guard !visibleLearnedPatterns.isEmpty else { return 0.25 }
        let support = visibleLearnedPatterns.reduce(0) { $0 + $1.supportCount }
        let total = visibleLearnedPatterns.reduce(0) { $0 + max($1.totalCount, 1) }
        return total > 0 ? Double(support) / Double(total) : 0
    }

    private var previousSipComparison: String? {
        guard let previous = history
            .filter({
                $0.identity.userConfirmed
                    && $0.personalizationScopeID == session.identity.personalizationScopeID
                    && $0.id != session.id
            })
            .max(by: { $0.createdAt < $1.createdAt }) else {
            return nil
        }

        var parts: [String] = []
        if let currentRating = session.personalEnjoyment?.value,
           let previousRating = previous.personalEnjoyment?.value {
            let difference = currentRating - previousRating
            if abs(difference) < 0.25 {
                parts.append("Your personal rating is the same as \(previous.identity.displayName): \(currentRating.formatted(.number.precision(.fractionLength(1)))) stars.")
            } else {
                let direction = difference > 0 ? "higher" : "lower"
                parts.append("Your personal rating is \(abs(difference).formatted(.number.precision(.fractionLength(1)))) stars \(direction) than \(previous.identity.displayName).")
            }
        }

        let previousDescriptorTitles = previous.responses
            .filter { $0.state == .observed && $0.userConfirmed }
            .flatMap(\.descriptors)
            .map(\.displayedTitle)
            .sensoryUnique
        let shared = selectedFlavorLabels.filter { previousDescriptorTitles.contains($0) }
        if let sharedLabel = shared.first {
            parts.append("You recorded \(sharedLabel.lowercased()) in both snapshots.")
        } else if let current = selectedFlavorLabels.first,
                  let prior = previousDescriptorTitles.first {
            parts.append("This time you recorded \(current.lowercased()); last time you recorded \(prior.lowercased()).")
        }

        return parts.isEmpty
            ? "Your last confirmed \(session.identity.family.title.lowercased()) snapshot is ready beside this one for future comparison."
            : parts.joined(separator: " ")
    }

    private var provenanceMessage: String? {
        if let firstFlavor = session.identity.flavors.first {
            return "Added \(firstFlavor) stays labeled as an ingredient—not as proof that you detected it in the base drink."
        }
        switch session.identity.family {
        case .milkCoffee, .matchaLatte, .hojichaLatte, .milkTea:
            return "Mugshot keeps the base drink, milk, sweetness, additions, texture, and integration separate."
        default:
            return nil
        }
    }

    private var drinkIdentitySymbol: String {
        switch session.identity.family {
        case .matcha, .matchaLatte, .greenTea, .blackTea, .whiteTea, .oolongTea, .herbalInfusion:
            return "leaf.fill"
        case .hojichaLeaf, .hojichaPowder, .hojichaLatte:
            return "flame.fill"
        default:
            return "cup.and.saucer.fill"
        }
    }

    private func depthSymbol(_ depth: TastingDepth) -> String {
        switch depth {
        case .quick: return "bolt.fill"
        case .guided: return "sparkles"
        case .deep: return "scope"
        }
    }

    private func depthDescription(_ depth: TastingDepth) -> String {
        switch depth {
        case .quick: return "Personal stars and optional first words."
        case .guided: return "Own words, flavor web, a few relevant observations, then stars."
        case .deep: return "Full applicable detail, confidence, and optional style impression."
        }
    }

    private func flavorSymbol(for title: String) -> String {
        let value = title.lowercased()
        if value.contains("fruit") { return "apple.logo" }
        if value.contains("floral") { return "camera.macro" }
        if value.contains("sweet") || value.contains("brown") { return "drop.fill" }
        if value.contains("nut") || value.contains("cocoa") { return "circle.hexagongrid.fill" }
        if value.contains("green") || value.contains("botanical") { return "leaf.fill" }
        if value.contains("roast") || value.contains("smoke") { return "flame.fill" }
        if value.contains("grain") || value.contains("malt") { return "lines.measurement.horizontal" }
        if value.contains("dairy") || value.contains("ingredient") { return "square.3.layers.3d" }
        return "sparkle"
    }

    private var flavorTints: [Color] {
        [
            .mugshotSage,
            .roastBrown,
            .mugshotMatcha,
            Color(hex: "B86E63"),
            Color(hex: "7B779A"),
            Color(hex: "B28A55"),
            Color(hex: "517E86")
        ]
    }

    static func makeAnswers(
        from responses: [SensoryResponseDraft]
    ) -> [String: TastingLensCriterionAnswer] {
        Dictionary(uniqueKeysWithValues: responses.map { response in
            let preference: Int?
            switch response.preference {
            case .notForMe: preference = 1
            case .neutral: preference = 2
            case .liked: preference = 3
            case nil: preference = nil
            }
            let confidence: TastingLensAnswerConfidence?
            switch response.confidence {
            case .learning: confidence = .learning
            case .maybe: confidence = .maybe
            case .sure: confidence = .sure
            case nil: confidence = nil
            }
            return (
                response.criterionID,
                TastingLensCriterionAnswer(
                    status: uiStatus(response.state),
                    intensity: response.intensity?.level,
                    duration: response.duration,
                    selectedIDs: Set(
                        response.choiceIDs.isEmpty
                            ? response.descriptorIDs
                            : response.choiceIDs
                    ),
                    preference: preference,
                    quality: response.qualityImpression?.value,
                    confidence: confidence,
                    customText: response.customText ?? ""
                )
            )
        })
    }

    private static func uiStatus(_ status: SensoryResponseState) -> TastingLensAnswerStatus {
        switch status {
        case .notAsked: return .unanswered
        case .skipped: return .skipped
        case .notPresent: return .notPresent
        case .unsure: return .unsure
        case .observed: return .observed
        case .notRelevant: return .notRelevant
        }
    }

    private static let mugsyLeadingChoiceIDs: Set<String> = [
        "mugsy.sweet", "mugsy.bright", "mugsy.bitter", "mugsy.texture",
        "mugsy.umami", "mugsy.fresh_green", "mugsy.toasted", "mugsy.green",
        "mugsy.aromatic", "mugsy.brisk_dry", "mugsy.body", "mugsy.unsure"
    ]

    private func domainStatus(_ status: TastingLensAnswerStatus) -> SensoryResponseState {
        switch status {
        case .unanswered: return .notAsked
        case .observed: return .observed
        case .notPresent: return .notPresent
        case .unsure: return .unsure
        case .skipped: return .skipped
        case .notRelevant: return .notRelevant
        }
    }

    private func shouldShowSafetyCheck(for criterionID: String) -> Bool {
        guard let selected = answers[criterionID]?.selectedIDs else { return false }
        let safetyIDs: Set<String> = [
            "descriptor.unexpected.mold_like",
            "descriptor.unexpected.chemical"
        ]
        return !selected.isDisjoint(with: safetyIDs)
    }
}

private extension SensoryDimension {
    var displayTitle: String {
        switch self {
        case .identity: return "Drink identity"
        case .appearance: return "Appearance"
        case .aroma: return "Aroma"
        case .taste: return "Taste structure"
        case .flavor: return "Flavor"
        case .body: return "Body"
        case .texture: return "Texture"
        case .astringency: return "Dry grip"
        case .finish: return "Finish"
        case .temperatureChange: return "Temperature change"
        case .integration: return "Integration"
        case .balance: return "Balance"
        case .unexpected: return "Something unexpected"
        case .personalResponse: return "Personal response"
        }
    }

    var defaultHelper: String {
        switch self {
        case .aroma: return "Notice what reaches your nose before, during, or after the sip."
        case .taste: return "Record strength first. Enjoyment comes later."
        case .flavor: return "A possibility menu can help, but your own wording remains valid."
        case .body: return "Weight is separate from smoothness, grit, coating, and dryness."
        case .texture: return "Describe how the drink moves and feels, without grading it."
        case .astringency: return "Astringency is a drying or gripping mouthfeel, not bitterness."
        case .finish: return "What remains can be aroma, taste, or a physical feeling. Long is not automatically better."
        case .temperatureChange: return "There is no required direction; ‘nothing I can name’ is valid."
        case .integration: return "Joined, layered, or led by one component can all be intentional."
        case .balance: return "Balance asks what dominates for you, not whether every part is equal."
        case .appearance: return "Appearance can shape expectation, but it does not decide quality."
        case .unexpected: return "Unexpected does not automatically mean defective. Style and intent matter."
        case .identity, .personalResponse: return "Your answer stays personal and editable."
        }
    }
}

private extension Array where Element: Hashable {
    var sensoryUnique: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension SensoryEvidenceClass {
    var consumerLabel: String {
        switch self {
        case .establishedScience: return "Established sensory science"
        case .professionalConvention: return "Professional convention"
        case .productInterpretation: return "Mugshot product interpretation"
        case .openQuestion: return "Open research question"
        }
    }
}

private extension SensoryEvidenceConfidence {
    var consumerLabel: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .exploratory: return "Exploratory"
        }
    }
}
