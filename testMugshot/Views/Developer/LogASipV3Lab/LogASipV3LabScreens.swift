#if DEBUG
import SwiftUI

struct V3LabSetupScreen: View {
    @Binding var draft: V3LabDraft
    let onAddPhoto: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
                MugshotScreenHeader("Log a Sip") {
                    Label("Draft saved", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.mugshotSage)
                }

                MugshotSegmentedControl(
                    options: V3LabContext.allCases,
                    selection: $draft.context,
                    title: { $0.title },
                    icon: { $0.icon }
                )

                VStack(alignment: .leading, spacing: DesignSystem.Space.sm) {
                    V3LabSectionHeader("Photos", subtitle: "Tap any photo to make it your cover.")
                    V3LabPhotoPicker(
                        coverIndex: $draft.coverIndex,
                        usesPlaceholder: draft.didUsePlaceholder,
                        onAddPhoto: onAddPhoto
                    )

                    Button {
                        draft.didUsePlaceholder.toggle()
                    } label: {
                        Label(
                            draft.didUsePlaceholder ? "Use my photos" : "I missed the photo",
                            systemImage: draft.didUsePlaceholder ? "photo.on.rectangle" : "mug.fill"
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                    }
                    .buttonStyle(.plain)
                }

                V3LabLabeledTextField(
                    title: "Drink name",
                    placeholder: "What are you sipping?",
                    text: $draft.drinkName,
                    systemImage: "cup.and.saucer"
                )

                contextField

                if draft.context == .cafe {
                    HStack(spacing: 10) {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.mugshotSage)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Near you")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.tertiaryText)
                            Text(draft.cafeName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.espressoBrown)
                        }
                        Spacer()
                        Text("0.2 mi")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tertiaryText)
                    }
                    .padding(12)
                    .background(Color.sandBeige.opacity(0.42))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                }

                Text(contextHelper)
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.bottom, 112)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            V3LabBottomAction(
                title: "Start my reflection",
                subtitle: "Sip first, then \(draft.context.title.lowercased()).",
                systemImage: "arrow.right",
                action: onContinue
            )
        }
    }

    @ViewBuilder
    private var contextField: some View {
        switch draft.context {
        case .cafe:
            V3LabLabeledTextField(
                title: "Cafe",
                placeholder: "Choose a cafe",
                text: $draft.cafeName,
                systemImage: "storefront"
            )
        case .home:
            V3LabLabeledTextField(
                title: "Home setup",
                placeholder: "Name this setup",
                text: $draft.homeSetupName,
                systemImage: "house"
            )
        case .elsewhere:
            V3LabLabeledTextField(
                title: "Setting",
                placeholder: "Train, campsite, office...",
                text: $draft.settingName,
                systemImage: "mappin.and.ellipse"
            )
        }
    }

    private var contextHelper: String {
        switch draft.context {
        case .cafe:
            return "The cafe is part of this memory, so you will reflect on it once."
        case .home:
            return "Save as much or as little recipe evidence as helps future you."
        case .elsewhere:
            return "Name the setting in your own words. Exact location is never required."
        }
    }
}

struct V3LabSipScreen: View {
    @Binding var draft: V3LabDraft
    @Binding var coachIndex: Int
    let onEditSetup: () -> Void
    let onExploreFlavors: () -> Void
    let onAddOwn: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
                MugshotScreenHeader("How was the sip?", subtitle: "Capture the feeling first. Details are optional.")

                summaryCard

                V3LabJournalEditor(
                    title: "Just for my journal",
                    prompt: "What hit first? What stayed with you?",
                    text: $draft.sipNote,
                    privacyLabel: "Private unless you choose otherwise"
                )

                V3LabInlineMugsyCoach(
                    prompts: V3LabCoachPrompt.sip,
                    index: $coachIndex,
                    onExploreFlavors: onExploreFlavors
                )

                scoreBlock

                criteriaBlock

                if let suggestion = draft.weightedAverage(for: draft.sipCriteria) {
                    V3LabScoreGuidanceCard(
                        suggestedScore: suggestion,
                        currentScore: draft.sipScore,
                        onUse: { draft.sipScore = suggestion }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.bottom, 116)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            V3LabBottomAction(
                title: continueTitle,
                subtitle: "Your overall score stays yours.",
                systemImage: "arrow.right",
                action: onContinue
            )
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image("V3OrangeCreamsicleSquare")
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(draft.drinkName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)
                Text(draft.contextDisplayName)
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
            }
            Spacer()
            Button("Edit", action: onEditSetup)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.mugshotSage)
        }
        .padding(10)
        .cardStyle(radius: DesignSystem.Radius.control, shadow: DesignSystem.subtleShadow)
    }

    private var scoreBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                V3LabSectionHeader("Sip score", subtitle: "How it worked for you")
                Spacer()
                Text(draft.sipScore, format: .number.precision(.fractionLength(1)))
                    .mugshotDisplay(size: 34)
                    .foregroundColor(.espressoBrown)
            }
            V3LabHalfStarRating(rating: $draft.sipScore, label: "Sip score", starSize: 31)
        }
    }

    private var criteriaBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                V3LabSectionHeader("What shaped it?", subtitle: "Optional")
                Spacer()
                Button("Use last setup") {
                    restoreLastSipSetup()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.mugshotSage)
            }

            VStack(spacing: 0) {
                ForEach($draft.sipCriteria) { $criterion in
                    V3LabCriterionRow(criterion: $criterion) {
                        draft.sipCriteria.removeAll { $0.id == criterion.id }
                    }
                    if criterion.id != draft.sipCriteria.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .cardStyle(radius: DesignSystem.Radius.control, shadow: DesignSystem.subtleShadow)

            HStack {
                Text("Suggested for this drink")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Spacer()
                Text("\(V3LabSuggestion.sip.count) ideas")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(V3LabSuggestion.sip) { suggestion in
                        V3LabSuggestionChip(
                            suggestion: suggestion,
                            isAdded: draft.sipCriteria.contains { $0.id == suggestion.id }
                        ) {
                            add(suggestion, to: &draft.sipCriteria)
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
                }
            }
        }
    }

    private var continueTitle: String {
        draft.context == .cafe ? "Continue to cafe" : "Continue to \(draft.context.title.lowercased())"
    }

    private func restoreLastSipSetup() {
        for criterion in V3LabDraft.fixture.sipCriteria where !draft.sipCriteria.contains(where: { $0.id == criterion.id }) {
            var blank = criterion
            blank.rating = 0
            blank.importance = .normal
            draft.sipCriteria.append(blank)
        }
    }
}

struct V3LabContextScreen: View {
    @Binding var draft: V3LabDraft
    @Binding var coachIndex: Int
    let onAddOwn: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
                MugshotScreenHeader(draft.context.reflectionTitle, subtitle: draft.contextDisplayName)

                MugshotSegmentedControl(
                    options: V3LabContext.allCases,
                    selection: $draft.context,
                    title: { $0.title },
                    icon: { $0.icon }
                )

                V3LabJournalEditor(
                    title: draft.context == .home ? "What did you change?" : "Just for my journal",
                    prompt: contextPrompt,
                    text: $draft.contextNote,
                    privacyLabel: "Private unless you choose otherwise",
                    minimumHeight: 106
                )

                V3LabInlineMugsyCoach(
                    prompts: V3LabCoachPrompt.forContext(draft.context),
                    index: $coachIndex
                )

                if draft.context == .home {
                    homeReflection
                } else {
                    contextScore
                    contextCriteria

                    if let suggestion = draft.weightedAverage(for: draft.contextCriteria) {
                        V3LabScoreGuidanceCard(
                            suggestedScore: suggestion,
                            currentScore: draft.contextScore,
                            onUse: { draft.contextScore = suggestion }
                        )
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.bottom, 116)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            V3LabBottomAction(
                title: "Review & share",
                subtitle: "One Mugshot for the whole memory.",
                systemImage: "arrow.right",
                action: onContinue
            )
        }
    }

    private var contextScore: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                V3LabSectionHeader(draft.context.scoreTitle, subtitle: "How the setting shaped the visit")
                Spacer()
                Text(draft.contextScore, format: .number.precision(.fractionLength(1)))
                    .mugshotDisplay(size: 34)
                    .foregroundColor(.espressoBrown)
            }
            V3LabHalfStarRating(
                rating: $draft.contextScore,
                label: draft.context.scoreTitle,
                starSize: 31
            )
        }
    }

    private var contextCriteria: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                V3LabSectionHeader("What shaped it?", subtitle: "Optional")
                Spacer()
                Button("Use last setup") {
                    restoreLastContextSetup()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.mugshotSage)
            }

            VStack(spacing: 0) {
                ForEach($draft.contextCriteria) { $criterion in
                    V3LabCriterionRow(criterion: $criterion) {
                        draft.contextCriteria.removeAll { $0.id == criterion.id }
                    }
                    if criterion.id != draft.contextCriteria.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .cardStyle(radius: DesignSystem.Radius.control, shadow: DesignSystem.subtleShadow)

            HStack {
                Text("Suggested for this \(draft.context.title.lowercased())")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Spacer()
                Text("\(contextSuggestions.count) ideas")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(contextSuggestions) { suggestion in
                        V3LabSuggestionChip(
                            suggestion: suggestion,
                            isAdded: draft.contextCriteria.contains { $0.id == suggestion.id }
                        ) {
                            add(suggestion, to: &draft.contextCriteria)
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
                }
            }
        }
    }

    private var homeReflection: some View {
        VStack(alignment: .leading, spacing: 14) {
            V3LabSectionHeader("Would you make it again?", subtitle: "A decision, not another rating")

            MugshotSegmentedControl(
                options: V3LabMakeAgain.allCases,
                selection: $draft.makeAgain,
                title: { $0.title }
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Recipe snapshot", systemImage: "list.clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Spacer()
                    Text("Version \(draft.recipeVersion)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.mugshotSage)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.mugshotMint.opacity(0.26))
                        .clipShape(Capsule())
                }
                Text("Lelit Bianca V3 · AllGround Sense · 18 g in · 38 g out · 26 sec")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Equipment and method support the sip score; they do not become another score.")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            .padding(14)
            .cardStyle(radius: DesignSystem.Radius.control, shadow: DesignSystem.subtleShadow)
        }
    }

    private var contextSuggestions: [V3LabSuggestion] {
        draft.context == .cafe ? V3LabSuggestion.cafe : V3LabSuggestion.elsewhere
    }

    private func restoreLastContextSetup() {
        for criterion in V3LabDraft.fixture.contextCriteria where !draft.contextCriteria.contains(where: { $0.id == criterion.id }) {
            var blank = criterion
            blank.rating = 0
            blank.importance = .normal
            draft.contextCriteria.append(blank)
        }
    }

    private var contextPrompt: String {
        switch draft.context {
        case .cafe: return "How did the room, service, and value feel?"
        case .home: return "What did you try, and what might future you repeat?"
        case .elsewhere: return "How did this place change the memory?"
        }
    }

}

struct V3LabPublishScreen: View {
    @Binding var draft: V3LabDraft
    let onInviteFriends: () -> Void
    let onPublish: () -> Void

    @State private var showsCriteria = false
    @State private var previewIndex = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
                MugshotScreenHeader("Publish Mugshot", subtitle: "Review the memory before it reaches your people.")

                coverCard

                VStack(alignment: .leading, spacing: 8) {
                    V3LabSectionHeader("Caption", subtitle: "Required · written by you")
                    TextField("Say it your way", text: $draft.caption, axis: .vertical)
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
                    HStack {
                        Spacer()
                        Text("\(captionCharacterCount.formatted()) / \(SipCaptionPolicy.maximumLength.formatted())")
                            .font(.system(size: 11))
                            .foregroundColor(captionIsOverLimit ? .red : .tertiaryText)
                    }
                }

                VStack(spacing: 0) {
                    V3LabScoreEquation(
                        sipScore: draft.sipScore,
                        contextScore: draft.context == .home ? nil : draft.contextScore,
                        contextLabel: draft.contextScoreLabel,
                        mugshotScore: draft.mugshotScore
                    )

                    Divider()

                    DisclosureGroup(isExpanded: $showsCriteria) {
                        VStack(alignment: .leading, spacing: 8) {
                            criteriaSummary(title: "Sip", criteria: draft.sipCriteria)
                            if draft.context != .home {
                                criteriaSummary(title: draft.contextScoreLabel, criteria: draft.contextCriteria)
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        Text("See what shaped this")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                    }
                    .tint(.mugshotSage)
                    .padding(14)
                }
                .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)

                publishControls

                Label("Your journal stays yours.", systemImage: "lock.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.tertiaryText)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.bottom, 116)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            V3LabBottomAction(
                title: "Publish Mugshot",
                subtitle: publishSubtitle,
                systemImage: "arrow.up.circle.fill",
                isEnabled: draft.isReadyToPublish,
                action: onPublish
            )
        }
        .onChange(of: draft.audience) { _, _ in
            draft.constrainRawNoteVisibility()
        }
        .onAppear {
            previewIndex = min(max(draft.coverIndex, 0), max(V3LabMedia.photos.count - 1, 0))
        }
    }

    private var captionCharacterCount: Int {
        SipCaptionPolicy.characterCount(draft.caption)
    }

    private var captionIsOverLimit: Bool {
        captionCharacterCount > SipCaptionPolicy.maximumLength
    }

    private var publishSubtitle: String {
        guard draft.isReadyToPublish else { return "Finish the required details to publish." }
        return draft.audience == .private ? "Only you will see this." : "Ready for \(draft.audience.title.lowercased())."
    }

    private var coverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if draft.didUsePlaceholder {
                    HStack(spacing: 14) {
                        MugsyModelView(configuration: MugsyModelConfiguration(
                            expression: .curious,
                            prop: .camera,
                            pose: .leaningLeft
                        ))
                        .frame(width: 104, height: 104)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Oops, missed the photo")
                                .mugshotDisplay(size: 20)
                            Text("Mugsy saved your memory a spot.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 210)
                    .background(Color.mugshotMint.opacity(0.18))
                } else {
                    TabView(selection: $previewIndex) {
                        ForEach(Array(V3LabMedia.photos.enumerated()), id: \.offset) { index, imageName in
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 210)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .tag(index)
                        }
                    }
                    .frame(height: 210)
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }

                if !draft.didUsePlaceholder, previewIndex == draft.coverIndex {
                    Label("Cover", systemImage: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.mugshotMint)
                        .clipShape(Capsule())
                        .padding(10)
                }

                if !draft.didUsePlaceholder {
                    Text("\(previewIndex + 1) of \(V3LabMedia.photos.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.creamWhite)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.espressoBrown.opacity(0.72))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                        .padding(10)
                }
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))

            Text(draft.drinkName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)
            Text("\(draft.contextDisplayName)  ·  Jul 20, 2026")
                .font(.system(size: 12))
                .foregroundColor(.tertiaryText)
        }
    }

    private var publishControls: some View {
        VStack(spacing: 0) {
            V3LabVisibilitySelector(
                title: "Audience",
                detail: "Who can see the finished Mugshot",
                systemImage: "person.2.fill",
                options: V3LabAudience.allCases,
                selection: $draft.audience,
                optionTitle: { $0.title }
            )

            Divider().padding(.leading, 54)

            V3LabVisibilitySelector(
                title: "Raw note",
                detail: "Never broader than your Mugshot",
                systemImage: "lock.doc",
                options: V3LabRawNoteVisibility.allCases,
                selection: $draft.rawNoteVisibility,
                optionTitle: { $0.title },
                isEnabled: { $0.breadth <= draft.audience.breadth }
            )

            Divider().padding(.leading, 54)

            V3LabFriendInviteStrip(
                selectedIDs: $draft.invitedFriendIDs,
                onShowAll: onInviteFriends
            )
        }
        .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
    }

    private func criteriaSummary(title: String, criteria: [V3LabCriterion]) -> some View {
        let rated = criteria.filter { $0.rating > 0 }
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.tertiaryText)
            Text(rated.map { "\($0.title) \($0.rating.formatted(.number.precision(.fractionLength(1))))" }.joined(separator: "  ·  "))
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct V3LabTastePassportScreen: View {
    let onWhy: () -> Void
    let onStartAnother: () -> Void

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Image("V3TastePassportBackdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()

            Color.creamWhite.opacity(0.52)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Space.lg) {
                    MugshotScreenHeader("Taste Passport", subtitle: "Built gently from memories you choose to keep") {
                        ShareLink(item: "My Mugshot Taste Passport") {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                                .frame(width: 36, height: 36)
                                .background(Color.foamWhite.opacity(0.92))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))
                        }
                    }

                    identityBlock
                    evidenceBlock
                    memoryPlaces
                    criteriaBlock

                    VStack(spacing: 0) {
                        V3LabPublishSettingRow(
                            title: "Why am I seeing this?",
                            value: "",
                            systemImage: "info.circle",
                            action: onWhy
                        )
                        Divider().padding(.leading, 44)
                        V3LabPublishSettingRow(
                            title: "Passport",
                            value: "Only me",
                            systemImage: "lock",
                            action: nil
                        )
                    }
                    .cardStyle(radius: DesignSystem.Radius.control, shadow: DesignSystem.subtleShadow)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.mugshotSage)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Still learning from every memory")
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundColor(.mugshotSage)
                            Text("Four sips show a clue. More sips bring more clarity—never a permanent label.")
                                .font(.system(size: 12))
                                .foregroundColor(.tertiaryText)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Space.md)
                .padding(.bottom, 112)
            }
            .safeAreaInset(edge: .bottom) {
                V3LabBottomAction(
                    title: "Pour another one",
                    subtitle: "Optional—your finished memory is already safe.",
                    systemImage: "plus",
                    action: onStartAnother
                )
            }
        }
    }

    private var identityBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Label("Your taste identity", systemImage: "leaf.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                Text("Bright-city wanderer")
                    .mugshotDisplay(size: 29)
                    .foregroundColor(.espressoBrown)
                Text("Bright citrus keeps showing up, and quiet cafe corners lift the whole memory.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("4 SIPS · TAKING SHAPE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.9)
                    .foregroundColor(.mugshotSage)
            }

            ZStack {
                Circle()
                    .stroke(Color.mugshotSage.opacity(0.44), lineWidth: 1)
                    .frame(width: 76, height: 76)
                Circle()
                    .stroke(Color.mugshotSage.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 62, height: 62)
                Image(systemName: "mug.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.mugshotSage)
            }
        }
        .padding(16)
        .background(Color.foamWhite.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotMint.opacity(0.64), lineWidth: 1)
        )
    }

    private var evidenceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            V3LabSectionHeader("Evidence from your journal", subtitle: "Patterns, not verdicts")

            VStack(spacing: 0) {
                passportEvidenceRow(
                    image: "V3OrangeCitrusDetail",
                    title: "Bright citrus keeps showing up",
                    evidence: "4 sips",
                    confidence: "Taking shape"
                )
                Divider().padding(.leading, 76)
                passportEvidenceRow(
                    image: "V3CreamyLatte",
                    title: "Body matters when drinks turn creamy",
                    evidence: "7 ratings",
                    confidence: "Consistent pattern"
                )
                Divider().padding(.leading, 76)
                passportEvidenceRow(
                    image: "V3QuietCafeCorner",
                    title: "Quiet cafe corners lift the memory",
                    evidence: "3 visits",
                    confidence: "Early signal"
                )
            }
            .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
        }
    }

    private var memoryPlaces: some View {
        ZStack(alignment: .leading) {
            Image("V3TastePassportBackdrop")
                .resizable()
                .scaledToFill()
                .frame(height: 132)
                .clipped()
                .opacity(0.82)
                .accessibilityHidden(true)

            HStack(spacing: 14) {
                Image(systemName: "map.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 50, height: 50)
                    .background(Color.foamWhite.opacity(0.90))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memories across 6 places")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(.espressoBrown)
                    Text("Charleston · Vancouver · Home")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.mugshotSage)
            }
            .padding(14)
        }
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotMint.opacity(0.58), lineWidth: 1)
        )
    }

    private var criteriaBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            V3LabSectionHeader("Your criteria", subtitle: "The things you choose to notice")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    passportChip("Body", icon: "water.waves")
                    passportChip("Value", icon: "dollarsign")
                    passportChip("Coffee presence", icon: "cup.and.saucer")
                }
            }
        }
    }

    private func passportEvidenceRow(image: String, title: String, evidence: String, confidence: String) -> some View {
        HStack(spacing: 12) {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 7) {
                    Text(evidence)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.tertiaryText)
                    Text(confidence)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.mugshotMint.opacity(0.24))
                        .clipShape(Capsule())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private func passportChip(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.espressoBrown)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.sandBeige.opacity(0.56))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.mugshotLine, lineWidth: 1))
    }
}

private func add(_ suggestion: V3LabSuggestion, to criteria: inout [V3LabCriterion]) {
    guard !criteria.contains(where: { $0.id == suggestion.id }) else { return }
    criteria.append(
        V3LabCriterion(
            id: suggestion.id,
            title: suggestion.title,
            systemImage: suggestion.systemImage,
            rating: 0,
            importance: .normal,
            isPinned: false
        )
    )
}
#endif
