import SwiftUI

/// Controls how much framing the reusable Cafe Pulse editor supplies around
/// the same capture controls. Both presentations preserve the full data model.
enum CafePulsePresentationStyle: Hashable {
    case compact
    case guided
}

/// A binding-driven Cafe Pulse editor. The caller owns draft persistence and
/// decides where this surface appears in the broader cafe-session journey.
struct CafePulseCaptureView: View {
    @Binding private var draft: CafeExperienceDraft
    @Binding private var returnIntention: CafeReturnIntention?
    @Binding private var sipReorderIntention: SipReorderIntention?
    @Binding private var repeatComparison: CafeRepeatComparison?
    @Binding private var shareProjection: CafeExperienceShareProjection

    private let presentation: CafePulsePresentationStyle
    private let showsRepeatComparison: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        draft: Binding<CafeExperienceDraft>,
        returnIntention: Binding<CafeReturnIntention?>,
        sipReorderIntention: Binding<SipReorderIntention?>,
        repeatComparison: Binding<CafeRepeatComparison?>,
        shareProjection: Binding<CafeExperienceShareProjection>,
        presentation: CafePulsePresentationStyle = .guided,
        showsRepeatComparison: Bool = true
    ) {
        _draft = draft
        _returnIntention = returnIntention
        _sipReorderIntention = sipReorderIntention
        _repeatComparison = repeatComparison
        _shareProjection = shareProjection
        self.presentation = presentation
        self.showsRepeatComparison = showsRepeatComparison
    }

    var body: some View {
        VStack(alignment: .leading, spacing: presentation == .compact ? 14 : 18) {
            if currentStepIndex == 0 {
                introduction
                depthCard
            } else {
                compactDepthControl
            }
            journeyProgress
            currentStepContent

            if presentation == .compact {
                inlineJourneyControls
            }
        }
        .onAppear(perform: normalizeJourneyStep)
        .onChange(of: journeyPlan.steps.map(\.id)) { _, _ in
            normalizeJourneyStep()
        }
        .onChange(of: draft.observations.map(\.id)) { _, currentObservationIDs in
            let validIDs = Set(currentObservationIDs)
            shareProjection.observationIDs.formIntersection(validIDs)
        }
    }

    private var journeyPlan: CafePulseJourneyPlan {
        CafePulseJourneyPlan.make(
            depth: draft.depth,
            context: draft.visitContext,
            showsRepeatComparison: showsRepeatComparison
        )
    }

    private var currentStepIndex: Int {
        journeyPlan.resolvedIndex(for: draft.journeyStepID)
    }

    private var currentStep: CafePulseJourneyStep {
        journeyPlan.steps[currentStepIndex]
    }

    private var journeyProgress: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(draft.depth.title) Cafe Pulse")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.espressoBrown)

                Spacer()

                Text("Step \(currentStepIndex + 1) of \(journeyPlan.steps.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.mugshotSage)
            }

            ProgressView(
                value: Double(currentStepIndex + 1),
                total: Double(journeyPlan.steps.count)
            )
            .tint(Color.mugshotSage)
            .accessibilityLabel("\(draft.depth.title) Cafe Pulse progress")
            .accessibilityValue("Step \(currentStepIndex + 1) of \(journeyPlan.steps.count)")
        }
        .padding(.horizontal, presentation == .compact ? 2 : 4)
        .accessibilityIdentifier("cafePulse.progress")
    }

    /// Keep the runtime type shallow on iOS betas by materializing only the
    /// selected Cafe Pulse screen instead of one generic tree containing all
    /// 28 possible Deep screens.
    private var currentStepContent: AnyView {
        switch currentStep.content {
        case .ownWords:
            return AnyView(ownWordsCard)
        case .rating:
            return AnyView(ratingCard)
        case .context:
            return AnyView(contextCard)
        case .quickSignals:
            return AnyView(quickSignalsCard)
        case .dimension(let dimension, let facets, let includesBroadSignal):
            return AnyView(
                dimensionCard(
                    dimension,
                    facets: facets,
                    includesBroadSignal: includesBroadSignal
                )
            )
        case .repeatComparison:
            return AnyView(repeatComparisonCard)
        case .intentions:
            return AnyView(
                Group {
                    intentionsCard
                    nextMoveCard
                }
            )
        case .privateNotes:
            return AnyView(privateNotesCard)
        case .sharing:
            return AnyView(shareSummaryCard)
        case .quickWrapUp:
            return AnyView(
                Group {
                    intentionsCard
                    nextMoveCard
                    shareSummaryCard
                }
            )
        }
    }

    private var inlineJourneyControls: some View {
        HStack(spacing: 10) {
            if currentStepIndex > 0 {
                Button(action: moveToPriorJourneyStep) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Previous Cafe Pulse step")
                .accessibilityIdentifier("cafePulse.previous")
            }

            if journeyPlan.isLastStep(draft.journeyStepID) {
                Label("Cafe Pulse ready", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.mugshotMint.opacity(0.2))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("cafePulse.complete")
            } else {
                Button(action: moveToNextJourneyStep) {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("cafePulse.continue")
            }
        }
    }

    private var quickSignalsCard: some View {
        CafePulseCard(presentation: presentation) {
            CafePulseCardHeading(
                eyebrow: "Cafe Pulse",
                title: "What shaped today?",
                message: "Give each broad area one signal, or leave it untouched.",
                systemImage: "waveform.path.ecg"
            )

            VStack(spacing: 12) {
                ForEach(CafeExperienceDimension.allCases) { dimension in
                    CafePulseDimensionEditor(
                        dimension: dimension,
                        facets: [],
                        impactForFacet: { facet in
                            observation(dimension: dimension, facet: facet)?.impact
                        },
                        onSelectImpact: { impact, facet in
                            setImpact(impact, dimension: dimension, facet: facet)
                        }
                    )
                }
            }

            cafeObservationIndependenceLabel
        }
        .accessibilityIdentifier("cafePulse.step.quick-signals")
    }

    private func dimensionCard(
        _ dimension: CafeExperienceDimension,
        facets: [CafeExperienceFacet],
        includesBroadSignal: Bool
    ) -> some View {
        CafePulseCard(presentation: presentation) {
            CafePulseCardHeading(
                eyebrow: dimension.title,
                title: dimensionStepTitle(
                    dimension,
                    facets: facets,
                    includesBroadSignal: includesBroadSignal
                ),
                message: dimensionStepMessage(
                    facets: facets,
                    includesBroadSignal: includesBroadSignal
                ),
                systemImage: dimensionIcon(dimension)
            )

            CafePulseDimensionEditor(
                dimension: dimension,
                facets: facets,
                showsBroadSignal: includesBroadSignal,
                impactForFacet: { facet in
                    observation(dimension: dimension, facet: facet)?.impact
                },
                onSelectImpact: { impact, facet in
                    setImpact(impact, dimension: dimension, facet: facet)
                }
            )

            cafeObservationIndependenceLabel
        }
        .accessibilityIdentifier("cafePulse.step.\(currentStep.id)")
    }

    private var cafeObservationIndependenceLabel: some View {
        Label(
            "Lifted, Neutral, and Detracted are observations, not points in a score formula.",
            systemImage: "equal.circle"
        )
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var nextMoveCard: some View {
        CafePulseNextMoveCard(
            nextMove: CafeNextMove(
                returnIntention: returnIntention,
                reorderIntention: sipReorderIntention
            )
        )
    }

    @ViewBuilder
    private var introduction: some View {
        if presentation == .guided {
            TastingLensSectionHeading(
                eyebrow: "The cafe",
                title: "Capture the whole visit.",
                message: "Rate the cafe separately from the sip, then name what shaped the experience. Nothing here changes your drink rating."
            )
        } else {
            MugshotSectionTitle(
                title: "Cafe Pulse",
                subtitle: "The place and the sip keep separate stars."
            )
        }
    }

    private var depthCard: some View {
        CafePulseCard(presentation: presentation, tint: Color.mugshotMint.opacity(0.13)) {
            CafePulseCardHeading(
                eyebrow: "Depth",
                title: "How much do you want to notice?",
                message: presentation == .guided
                    ? "Quick captures the signal. Guided adds useful prompts. Deep opens every facet."
                    : nil,
                systemImage: "dial.medium"
            )

            depthSelector
        }
    }

    private var compactDepthControl: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("DEPTH")
                .font(.caption2.weight(.black))
                .tracking(1.2)
                .foregroundStyle(Color.mugshotSage)
            depthSelector
        }
    }

    private var depthSelector: some View {
        MugshotSegmentedControl(
            options: CafeExperienceDepth.allCases,
            selection: depthBinding,
            title: \.title,
            icon: { depth in
                switch depth {
                case .quick: return "bolt.fill"
                case .guided: return "sparkles"
                case .deep: return "scope"
                }
            }
        )
        .accessibilityIdentifier("cafePulse.depth")
    }

    private var ownWordsCard: some View {
        CafePulseCard(presentation: presentation) {
            CafePulseCardHeading(
                eyebrow: "First impression",
                title: "Start in your own words.",
                message: presentation == .guided
                    ? "Before prompts shape the memory, what did the cafe feel like?"
                    : "What did the place feel like?",
                systemImage: "text.quote"
            )

            ZStack(alignment: .topLeading) {
                if draft.ownWords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Warm, lively, and easy to settle into…")
                        .font(.body)
                        .foregroundStyle(Color.inputPlaceholder)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                }

                TextEditor(text: ownWordsBinding)
                    .font(.body)
                    .foregroundStyle(Color.inputText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 150 : 104)
                    .accessibilityLabel("Cafe first impression")
                    .accessibilityHint("Write what stood out before using the guided prompts")
                    .accessibilityIdentifier("cafePulse.ownWords")
            }
            .padding(10)
            .background(Color.creamWhite.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            }

            Label(
                "Your full words stay in your private Cafe Pulse. Sharing uses only the summary choices below.",
                systemImage: "lock.fill"
            )
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ratingCard: some View {
        CafePulseCard(presentation: presentation) {
            CafePulseCardHeading(
                eyebrow: "Independent stars",
                title: "How was the cafe?",
                message: "Rate the place, atmosphere, service, and visit as one personal impression—not the drink.",
                systemImage: "storefront.fill"
            )

            CafePulseHalfStarRating(rating: cafeRatingBinding)

            Label(
                "Cafe stars and sip stars are always stored and learned from separately.",
                systemImage: "arrow.left.and.right"
            )
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var contextCard: some View {
        CafePulseCard(presentation: presentation) {
            CafePulseCardHeading(
                eyebrow: "Visit context",
                title: "What were you here for?",
                message: presentation == .guided
                    ? "Context changes which prompts are useful. It never changes your stars."
                    : nil,
                systemImage: "mappin.and.ellipse"
            )

            TastingLensFlowLayout(spacing: 8) {
                ForEach(CafeVisitMode.allCases) { mode in
                    TastingLensSelectionChip(
                        label: mode.title,
                        systemImage: visitModeIcon(mode),
                        isSelected: draft.visitContext.mode == mode
                    ) {
                        setVisitMode(mode)
                    }
                    .accessibilityIdentifier("cafePulse.visitMode.\(mode.rawValue)")
                }
            }

            Divider()
                .overlay(Color.mugshotLine)

            Text("Anything else true right now?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.espressoBrown)

            TastingLensFlowLayout(spacing: 8) {
                ForEach(CafeVisitOverlay.allCases) { overlay in
                    TastingLensSelectionChip(
                        label: overlay.title,
                        systemImage: visitOverlayIcon(overlay),
                        isSelected: draft.visitContext.overlays.contains(overlay)
                    ) {
                        toggleVisitOverlay(overlay)
                    }
                    .accessibilityIdentifier("cafePulse.visitOverlay.\(overlay.rawValue)")
                }
            }
        }
    }

    private var observationsCard: some View {
        CafePulseCard(presentation: presentation) {
            CafePulseCardHeading(
                eyebrow: "Cafe Pulse",
                title: draft.depth == .quick ? "What shaped today?" : "What shaped the visit?",
                message: observationMessage,
                systemImage: "waveform.path.ecg"
            )

            VStack(spacing: 12) {
                ForEach(CafeExperienceDimension.allCases) { dimension in
                    CafePulseDimensionEditor(
                        dimension: dimension,
                        facets: CafeExperiencePromptRouter.facets(
                            for: dimension,
                            context: draft.visitContext,
                            depth: draft.depth
                        ),
                        impactForFacet: { facet in
                            observation(dimension: dimension, facet: facet)?.impact
                        },
                        onSelectImpact: { impact, facet in
                            setImpact(impact, dimension: dimension, facet: facet)
                        }
                    )
                }
            }

            Label(
                "Lifted, Neutral, and Detracted are observations, not points in a score formula.",
                systemImage: "equal.circle"
            )
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var repeatComparisonCard: some View {
        CafePulseCard(presentation: presentation, tint: Color.sandBeige.opacity(0.38)) {
            CafePulseCardHeading(
                eyebrow: "Repeat visit",
                title: "Compared with last time?",
                message: "Skip this on a first visit. Mugshot treats your answer as context, never as a recalculated rating.",
                systemImage: "clock.arrow.circlepath"
            )

            TastingLensFlowLayout(spacing: 8) {
                ForEach(CafeRepeatComparison.allCases) { comparison in
                    TastingLensSelectionChip(
                        label: comparison.title,
                        isSelected: repeatComparison == comparison
                    ) {
                        repeatComparison = repeatComparison == comparison ? nil : comparison
                    }
                    .accessibilityIdentifier("cafePulse.repeat.\(comparison.rawValue)")
                }
            }
        }
    }

    private var intentionsCard: some View {
        CafePulseCard(presentation: presentation) {
            CafePulseCardHeading(
                eyebrow: "Your intentions",
                title: "What would you do next?",
                message: "Two direct answers create one deterministic Next Move. Stars and Cafe Pulse observations do not change it.",
                systemImage: "arrow.triangle.branch"
            )

            CafePulseOptionalChoiceRow(
                title: "Would you return to this cafe?",
                accessibilityIdentifier: "cafePulse.return",
                options: CafeReturnIntention.allCases,
                selection: returnIntention,
                titleForOption: \.title
            ) { selected in
                returnIntention = returnIntention == selected ? nil : selected
                if returnIntention == nil, sipReorderIntention == nil {
                    shareProjection.includesNextMove = false
                }
            }

            Divider()
                .overlay(Color.mugshotLine)

            CafePulseOptionalChoiceRow(
                title: "Would you reorder this sip?",
                accessibilityIdentifier: "cafePulse.reorder",
                options: SipReorderIntention.allCases,
                selection: sipReorderIntention,
                titleForOption: \.title
            ) { selected in
                sipReorderIntention = sipReorderIntention == selected ? nil : selected
                if returnIntention == nil, sipReorderIntention == nil {
                    shareProjection.includesNextMove = false
                }
            }
        }
    }

    private var privateNotesCard: some View {
        CafePulseCard(presentation: presentation, tint: Color.sandBeige.opacity(0.34)) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(width: 32, height: 32)
                    .background(Color.mugshotMint.opacity(0.28), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("PRIVATE NOTES")
                        .font(.caption2.weight(.black))
                        .tracking(1.3)
                        .foregroundStyle(Color.mugshotSage)
                    Text("Only you can see this")
                        .font(.headline)
                        .foregroundStyle(Color.espressoBrown)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            TextField(
                "Anything you want to remember privately about the service, space, people, price, or moment…",
                text: privateNotesBinding,
                axis: .vertical
            )
            .lineLimit(3...8)
            .mugshotFormField()
            .accessibilityLabel("Private cafe notes")
            .accessibilityHint("These notes can never appear in Feed or sharing")
            .accessibilityIdentifier("cafePulse.privateNotes")

            Label(
                "Owner-only journal space. Full notes are excluded from every shared summary.",
                systemImage: "person.crop.circle.badge.checkmark"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.mugshotSage)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shareSummaryCard: some View {
        CafePulseCard(presentation: presentation, tint: Color.mugshotMint.opacity(0.12)) {
            CafePulseCardHeading(
                eyebrow: "Optional sharing",
                title: "Choose the cafe summary.",
                message: "Everything starts private. Turn on only the pieces you want beside the primary sip.",
                systemImage: "person.2.fill"
            )

            CafePulseShareToggle(
                title: "Share cafe stars",
                message: draft.cafeRating.map {
                    "\($0.value.formatted(.number.precision(.fractionLength(1)))) out of 5"
                } ?? "Choose cafe stars first",
                isOn: includesCafeRatingBinding,
                isEnabled: draft.cafeRating != nil,
                accessibilityIdentifier: "cafePulse.share.rating"
            )

            CafePulseShareToggle(
                title: "Share Next Move",
                message: hasIntentionAnswer
                    ? CafeNextMove(
                        returnIntention: returnIntention,
                        reorderIntention: sipReorderIntention
                    ).kind.title
                    : "Answer a return or reorder question first",
                isOn: includesNextMoveBinding,
                isEnabled: hasIntentionAnswer,
                accessibilityIdentifier: "cafePulse.share.nextMove"
            )

            if !sortedObservedResponses.isEmpty {
                Divider()
                    .overlay(Color.mugshotLine)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Observed signals")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.espressoBrown)

                    Text("Each signal stays private until you explicitly include it.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)

                    ForEach(sortedObservedResponses) { observation in
                        CafePulseShareToggle(
                            title: observationShareTitle(observation),
                            message: observation.impact?.title ?? "Not observed",
                            isOn: shareObservationBinding(observation.id),
                            isEnabled: observation.state.contributesEvidence,
                            accessibilityIdentifier: "cafePulse.share.observation.\(observation.id.uuidString)"
                        )
                    }
                }
            }

            Label(
                "Private notes, full written responses, and unselected signals are never included.",
                systemImage: "hand.raised.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.mugshotSage)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var observationMessage: String {
        switch draft.depth {
        case .quick:
            return "Give each broad area one signal, or leave it untouched."
        case .guided:
            return "Broad signals come first, followed by prompts chosen for this visit context."
        case .deep:
            return "Broad signals come first, followed by every detailed facet."
        }
    }

    private var depthBinding: Binding<CafeExperienceDepth> {
        Binding(
            get: { draft.depth },
            set: { newValue in
                guard draft.depth != newValue else { return }
                draft.depth = newValue
                let replacementPlan = CafePulseJourneyPlan.make(
                    depth: newValue,
                    context: draft.visitContext,
                    showsRepeatComparison: showsRepeatComparison
                )
                draft.journeyStepID = replacementPlan.steps.first?.id
                touchDraft()
            }
        )
    }

    private var ownWordsBinding: Binding<String> {
        Binding(
            get: { draft.ownWords },
            set: { newValue in
                draft.ownWords = newValue
                touchDraft()
            }
        )
    }

    private var cafeRatingBinding: Binding<CafeExperienceRating?> {
        Binding(
            get: { draft.cafeRating },
            set: { newValue in
                draft.cafeRating = newValue
                if newValue == nil {
                    shareProjection.includesCafeRating = false
                }
                touchDraft()
            }
        )
    }

    private var privateNotesBinding: Binding<String> {
        Binding(
            get: { draft.privateNotes },
            set: { newValue in
                draft.privateNotes = newValue
                touchDraft()
            }
        )
    }

    private var includesCafeRatingBinding: Binding<Bool> {
        Binding(
            get: { draft.cafeRating != nil && shareProjection.includesCafeRating },
            set: { shareProjection.includesCafeRating = draft.cafeRating != nil && $0 }
        )
    }

    private var includesNextMoveBinding: Binding<Bool> {
        Binding(
            get: { hasIntentionAnswer && shareProjection.includesNextMove },
            set: { shareProjection.includesNextMove = hasIntentionAnswer && $0 }
        )
    }

    private var hasIntentionAnswer: Bool {
        returnIntention != nil || sipReorderIntention != nil
    }

    private var sortedObservedResponses: [CafeExperienceObservation] {
        draft.observations
            .filter(\.state.contributesEvidence)
            .sorted {
                let lhsDimension = CafeExperienceDimension.allCases.firstIndex(of: $0.dimension) ?? 0
                let rhsDimension = CafeExperienceDimension.allCases.firstIndex(of: $1.dimension) ?? 0
                if lhsDimension != rhsDimension {
                    return lhsDimension < rhsDimension
                }
                return ($0.facet?.title ?? "") < ($1.facet?.title ?? "")
            }
    }

    private func observation(
        dimension: CafeExperienceDimension,
        facet: CafeExperienceFacet?
    ) -> CafeExperienceObservation? {
        draft.observations.last {
            $0.dimension == dimension && $0.facet == facet
        }
    }

    private func setImpact(
        _ impact: CafeExperienceImpact,
        dimension: CafeExperienceDimension,
        facet: CafeExperienceFacet?
    ) {
        let existing = observation(dimension: dimension, facet: facet)

        if existing?.impact == impact {
            if let existing {
                shareProjection.observationIDs.remove(existing.id)
            }
            draft.removeObservation(dimension: dimension, facet: facet)
            return
        }

        let id = existing?.id ?? UUID()
        let updated: CafeExperienceObservation
        if let facet {
            updated = .observed(
                id: id,
                facet: facet,
                impact: impact,
                privateNote: existing?.privateNote
            )
        } else {
            updated = .observed(
                id: id,
                dimension: dimension,
                impact: impact,
                privateNote: existing?.privateNote
            )
        }
        draft.record(updated)
    }

    private func setVisitMode(_ mode: CafeVisitMode) {
        draft.visitContext.mode = mode
        touchDraft()
    }

    private func toggleVisitOverlay(_ overlay: CafeVisitOverlay) {
        if draft.visitContext.overlays.contains(overlay) {
            draft.visitContext.overlays.remove(overlay)
        } else {
            draft.visitContext.overlays.insert(overlay)
        }
        touchDraft()
    }

    private func shareObservationBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { shareProjection.observationIDs.contains(id) },
            set: { isIncluded in
                if isIncluded {
                    shareProjection.observationIDs.insert(id)
                } else {
                    shareProjection.observationIDs.remove(id)
                }
            }
        )
    }

    private func observationShareTitle(_ observation: CafeExperienceObservation) -> String {
        if let facet = observation.facet {
            return "\(observation.dimension.title): \(facet.title)"
        }
        return observation.dimension.title
    }

    private func normalizeJourneyStep() {
        let resolvedStep = journeyPlan.steps[currentStepIndex]
        guard draft.journeyStepID != resolvedStep.id else { return }
        draft.journeyStepID = resolvedStep.id
        touchDraft()
    }

    private func moveToNextJourneyStep() {
        guard let next = journeyPlan.step(after: draft.journeyStepID) else { return }
        withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
            draft.journeyStepID = next.id
            touchDraft()
        }
        MugshotHaptic.softImpact.play()
    }

    private func moveToPriorJourneyStep() {
        guard let prior = journeyPlan.step(before: draft.journeyStepID) else { return }
        withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
            draft.journeyStepID = prior.id
            touchDraft()
        }
        MugshotHaptic.softImpact.play()
    }

    private func dimensionStepTitle(
        _ dimension: CafeExperienceDimension,
        facets: [CafeExperienceFacet],
        includesBroadSignal: Bool
    ) -> String {
        if includesBroadSignal, facets.isEmpty {
            return "What was the overall signal?"
        }
        if includesBroadSignal {
            return "Notice the broad signal, then look closer."
        }
        return "Look closer at \(dimension.title.lowercased())."
    }

    private func dimensionStepMessage(
        facets: [CafeExperienceFacet],
        includesBroadSignal: Bool
    ) -> String {
        if includesBroadSignal, facets.isEmpty {
            return "Choose Lifted, Neutral, or Detracted—or leave it untouched."
        }
        if includesBroadSignal {
            return "Your visit context selected these useful prompts. None of them calculate the cafe stars."
        }
        return "A focused Deep pass through \(facets.count) specific \(facets.count == 1 ? "detail" : "details")."
    }

    private func dimensionIcon(_ dimension: CafeExperienceDimension) -> String {
        switch dimension {
        case .atmosphere: return "sparkles"
        case .musicAndSound: return "music.note"
        case .hospitality: return "hand.wave.fill"
        case .menuAndValue: return "menucard.fill"
        case .comfortAndPracticality: return "chair.lounge.fill"
        case .communityAndCharacter: return "person.3.fill"
        }
    }

    private func touchDraft() {
        draft.updatedAt = .now
    }

    private func visitModeIcon(_ mode: CafeVisitMode) -> String {
        switch mode {
        case .grabAndGo: return "takeoutbag.and.cup.and.straw.fill"
        case .stayAwhile: return "chair.lounge.fill"
        case .workStudy: return "laptopcomputer"
        case .social: return "person.2.fill"
        case .foodFocused: return "fork.knife"
        }
    }

    private func visitOverlayIcon(_ overlay: CafeVisitOverlay) -> String {
        switch overlay {
        case .outdoorSeating: return "sun.max.fill"
        case .busyQueue: return "person.3.fill"
        }
    }
}

private struct CafePulseCard<Content: View>: View {
    let presentation: CafePulsePresentationStyle
    let tint: Color
    @ViewBuilder let content: Content

    init(
        presentation: CafePulsePresentationStyle,
        tint: Color = .foamWhite,
        @ViewBuilder content: () -> Content
    ) {
        self.presentation = presentation
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: presentation == .compact ? 12 : 15) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(presentation == .compact ? 14 : 18)
        .background(tint)
        .clipShape(
            RoundedRectangle(
                cornerRadius: presentation == .compact
                    ? DesignSystem.Radius.card
                    : DesignSystem.Radius.heroCard,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: presentation == .compact
                    ? DesignSystem.Radius.card
                    : DesignSystem.Radius.heroCard,
                style: .continuous
            )
            .stroke(Color.mugshotLine, lineWidth: 1)
        }
    }
}

private struct CafePulseCardHeading: View {
    let eyebrow: String
    let title: String
    let message: String?
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.mugshotSage)
                .frame(width: 34, height: 34)
                .background(Color.mugshotMint.opacity(0.26), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(Color.mugshotSage)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct CafePulseHalfStarRating: View {
    @Binding var rating: CafeExperienceRating?

    @AppStorage("MugshotSettings.haptics.v1") private var ratingHaptics = true

    private var value: Double {
        rating?.value ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    GeometryReader { proxy in
                        Image(systemName: symbol(for: index))
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(
                                value >= Double(index) - 0.5
                                    ? Color.mugshotSage
                                    : Color.espressoBrown.opacity(0.16)
                            )
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { gesture in
                                        setValue(
                                            Self.ratingValue(
                                                starIndex: index,
                                                tapX: gesture.location.x,
                                                starWidth: proxy.size.width
                                            )
                                        )
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 44)
            .sensoryFeedback(.selection, trigger: value) { _, _ in ratingHaptics }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Independent cafe rating")
            .accessibilityValue(
                rating.map {
                    "\($0.value.formatted(.number.precision(.fractionLength(1)))) out of 5. \(ratingAnchor(for: $0.value))"
                } ?? "Not rated"
            )
            .accessibilityHint("Swipe up or down to change by half a star")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    setValue(value <= 0 ? 1 : min(5, value + 0.5))
                case .decrement:
                    if value <= 1 {
                        rating = nil
                    } else {
                        setValue(value - 0.5)
                    }
                @unknown default:
                    break
                }
            }
            .accessibilityIdentifier("cafePulse.rating.stars")

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(rating.map { ratingAnchor(for: $0.value) } ?? "Tap a half or whole star")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text(
                    rating.map {
                        $0.value.formatted(.number.precision(.fractionLength(1)))
                    } ?? "—"
                )
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.mugshotSage)
            }

            if rating != nil {
                Button("Clear cafe stars") {
                    rating = nil
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.mugshotSage)
                .buttonStyle(.plain)
                .accessibilityIdentifier("cafePulse.rating.clear")
            }
        }
    }

    private func symbol(for index: Int) -> String {
        let threshold = Double(index)
        if value >= threshold { return "star.fill" }
        if value >= threshold - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    private func setValue(_ newValue: Double) {
        rating = CafeExperienceRating(value: newValue)
    }

    private func ratingAnchor(for value: Double) -> String {
        switch value {
        case 1: return "Not for me"
        case 1.5: return "Mostly missed"
        case 2: return "Fell short"
        case 2.5: return "Mixed"
        case 3: return "Solid"
        case 3.5: return "Enjoyable"
        case 4: return "Really liked it"
        case 4.5: return "Standout"
        case 5: return "A favorite"
        default: return "Your cafe impression"
        }
    }

    static func ratingValue(starIndex: Int, tapX: CGFloat, starWidth: CGFloat) -> Double {
        let clampedIndex = min(max(starIndex, 1), 5)
        return max(
            1,
            Double(clampedIndex) - (tapX < max(starWidth, 1) / 2 ? 0.5 : 0)
        )
    }
}

private struct CafePulseDimensionEditor: View {
    let dimension: CafeExperienceDimension
    let facets: [CafeExperienceFacet]
    var showsBroadSignal = true
    let impactForFacet: (CafeExperienceFacet?) -> CafeExperienceImpact?
    let onSelectImpact: (CafeExperienceImpact, CafeExperienceFacet?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if showsBroadSignal {
                CafePulseImpactRow(
                    title: dimension.title,
                    subtitle: facets.isEmpty ? nil : "Broad signal",
                    selectedImpact: impactForFacet(nil)
                ) { impact in
                    onSelectImpact(impact, nil)
                }
                .accessibilityIdentifier("cafePulse.dimension.\(dimension.rawValue)")
            }

            if !facets.isEmpty {
                VStack(spacing: 8) {
                    ForEach(facets) { facet in
                        CafePulseImpactRow(
                            title: facet.title,
                            subtitle: nil,
                            selectedImpact: impactForFacet(facet),
                            isFacet: true
                        ) { impact in
                            onSelectImpact(impact, facet)
                        }
                        .accessibilityIdentifier("cafePulse.facet.\(facet.rawValue)")
                    }
                }
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.mugshotMint.opacity(0.7))
                        .frame(width: 3)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(12)
        .background(Color.creamWhite.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
    }
}

private struct CafePulseImpactRow: View {
    let title: String
    let subtitle: String?
    let selectedImpact: CafeExperienceImpact?
    var isFacet = false
    let onSelect: (CafeExperienceImpact) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isFacet ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.tertiaryText)
                }
            }

            CafePulseImpactPicker(
                selectedImpact: selectedImpact,
                stacksVertically: dynamicTypeSize.isAccessibilitySize,
                onSelect: onSelect
            )
        }
    }
}

private struct CafePulseImpactPicker: View {
    let selectedImpact: CafeExperienceImpact?
    let stacksVertically: Bool
    let onSelect: (CafeExperienceImpact) -> Void

    var body: some View {
        Group {
            if stacksVertically {
                VStack(spacing: 6) {
                    impactButtons
                }
            } else {
                HStack(spacing: 6) {
                    impactButtons
                }
            }
        }
    }

    @ViewBuilder
    private var impactButtons: some View {
        ForEach(CafeExperienceImpact.allCases) { impact in
            let selected = selectedImpact == impact
            Button {
                onSelect(impact)
            } label: {
                Label(impact.title, systemImage: icon(for: impact))
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(selected ? Color.foamWhite : foreground(for: impact))
                    .background(selected ? selectedBackground(for: impact) : Color.foamWhite)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(
                                selected ? selectedBackground(for: impact) : Color.mugshotLine,
                                lineWidth: selected ? 2 : 1
                            )
                    }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .accessibilityHint("Double tap to select; double tap again to clear")
        }
    }

    private func icon(for impact: CafeExperienceImpact) -> String {
        switch impact {
        case .lifted: return "arrow.up"
        case .neutral: return "minus"
        case .detracted: return "arrow.down"
        }
    }

    private func foreground(for impact: CafeExperienceImpact) -> Color {
        switch impact {
        case .lifted: return .mugshotSage
        case .neutral: return .roastBrown
        case .detracted: return .espressoBrown
        }
    }

    private func selectedBackground(for impact: CafeExperienceImpact) -> Color {
        switch impact {
        case .lifted: return .mugshotSage
        case .neutral: return .roastBrown.opacity(0.78)
        case .detracted: return .espressoBrown
        }
    }
}

private struct CafePulseOptionalChoiceRow<Option: Identifiable & Equatable>: View {
    let title: String
    let accessibilityIdentifier: String
    let options: [Option]
    let selection: Option?
    let titleForOption: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)

            TastingLensFlowLayout(spacing: 8) {
                ForEach(options) { option in
                    TastingLensSelectionChip(
                        label: titleForOption(option),
                        isSelected: selection == option,
                        accessibilityIdentifier:
                            "\(accessibilityIdentifier).\(String(describing: option.id))"
                    ) {
                        onSelect(option)
                    }
                }
            }
        }
    }
}

struct CafePulseNextMoveCard: View {
    let nextMove: CafeNextMove

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.foamWhite)
                .frame(width: 42, height: 42)
                .background(Color.mugshotSage, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT MOVE")
                    .font(.caption2.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(Color.mugshotSage)

                Text(nextMove.kind.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.espressoBrown)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Resolved only from return + reorder")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Color.mugshotMint.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
                .stroke(Color.mugshotSage.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next Move: \(nextMove.kind.title)")
        .accessibilityValue(message)
        .accessibilityIdentifier("cafePulse.nextMove")
    }

    private var icon: String {
        switch nextMove.kind {
        case .comeBackForThis: return "arrow.uturn.backward.circle.fill"
        case .comeBackTryAnother: return "sparkles"
        case .thisDrinkElsewhere: return "mappin.and.ellipse"
        case .probablyNotAgain: return "hand.thumbsdown.fill"
        case .notSureYet: return "questionmark"
        }
    }

    private var message: String {
        switch nextMove.kind {
        case .comeBackForThis:
            return "The cafe and this order both earned another visit."
        case .comeBackTryAnother:
            return "The place is worth returning to, but your next sip should be different."
        case .thisDrinkElsewhere:
            return "You would choose the order again, just not at this cafe."
        case .probablyNotAgain:
            return "Neither the cafe nor this order is calling you back right now."
        case .notSureYet:
            return "One or both intentions are still open. Mugshot will not guess."
        }
    }
}

private struct CafePulseShareToggle: View {
    let title: String
    let message: String
    @Binding var isOn: Bool
    let isEnabled: Bool
    let accessibilityIdentifier: String

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.espressoBrown)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .tint(Color.mugshotSage)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
