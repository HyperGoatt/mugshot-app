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
                    V3LabSectionHeader("Photos", subtitle: "Choose the first photo as your cover.")
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
    let onEditSetup: () -> Void
    let onCoach: () -> Void
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
                    privacyLabel: "Private unless you choose otherwise",
                    onCoach: onCoach
                )

                scoreBlock

                criteriaBlock

                if let suggestion = draft.weightedAverage(for: draft.sipCriteria) {
                    V3LabScoreGuidanceCard(
                        suggestedScore: suggestion,
                        currentScore: draft.sipScore,
                        onUse: { draft.sipScore = nearestHalf(suggestion) }
                    )
                }

                V3LabMugsyCoachRow(
                    title: "Need a thought?",
                    prompt: "Gentle prompts from Mugsy, only when you ask.",
                    action: onCoach
                )

                Button(action: onExploreFlavors) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.mugshotSage)
                        Text("Explore flavors")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.mugshotSage)
                        Text("Taste ideas")
                            .font(.system(size: 11))
                            .foregroundColor(.tertiaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.tertiaryText)
                    }
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
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
    let onCoach: () -> Void
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
                    minimumHeight: 106,
                    onCoach: onCoach
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
                            onUse: { draft.contextScore = nearestHalf(suggestion) }
                        )
                    }
                }

                V3LabMugsyCoachRow(
                    title: draft.context == .home ? "Plan one tiny experiment" : "Notice one more thing",
                    prompt: coachPrompt,
                    action: onCoach
                )
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
            V3LabSectionHeader("What shaped it?", subtitle: "Optional")

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

    private var contextPrompt: String {
        switch draft.context {
        case .cafe: return "How did the room, service, and value feel?"
        case .home: return "What did you try, and what might future you repeat?"
        case .elsewhere: return "How did this place change the memory?"
        }
    }

    private var coachPrompt: String {
        switch draft.context {
        case .cafe: return "Try atmosphere, comfort, presentation, or service."
        case .home: return "Change one variable next time so the result can teach you something."
        case .elsewhere: return "Think about the view, occasion, comfort, or company."
        }
    }
}

struct V3LabPublishScreen: View {
    @Binding var draft: V3LabDraft
    let onInviteFriends: () -> Void
    let onPublish: () -> Void

    @State private var showsCriteria = false

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
                                .stroke(Color.mugshotLine, lineWidth: 1)
                        )
                    HStack {
                        Spacer()
                        Text("\(draft.caption.count)/80")
                            .font(.system(size: 11))
                            .foregroundColor(.tertiaryText)
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
                subtitle: draft.audience == .private ? "Only you will see this." : "Ready for \(draft.audience.title.lowercased()).",
                systemImage: "arrow.up.circle.fill",
                action: onPublish
            )
        }
        .onChange(of: draft.audience) { _, _ in
            draft.constrainRawNoteVisibility()
        }
    }

    private var coverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                Image("V3OrangeCreamsicleHeroV2")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                Label("Cover", systemImage: "photo")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
            }

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
            VStack(alignment: .leading, spacing: 9) {
                Label("Audience", systemImage: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                MugshotSegmentedControl(
                    options: V3LabAudience.allCases,
                    selection: $draft.audience,
                    title: { $0.title }
                )
            }
            .padding(14)

            Divider().padding(.leading, 44)

            Menu {
                ForEach(draft.allowedRawNoteVisibilities) { visibility in
                    Button(visibility.title) {
                        draft.rawNoteVisibility = visibility
                    }
                }
            } label: {
                V3LabPublishSettingRow(
                    title: "Raw note",
                    value: draft.rawNoteVisibility.title,
                    systemImage: "lock.doc",
                    action: nil
                )
            }

            Divider().padding(.leading, 44)

            V3LabPublishSettingRow(
                title: "Invite friends",
                value: draft.invitedFriendCount == 0 ? "None" : "\(draft.invitedFriendCount) selected",
                systemImage: "person.badge.plus",
                action: onInviteFriends
            )

            Divider().padding(.leading, 44)

            V3LabPublishSettingRow(
                title: "Cover photo",
                value: draft.coverIndex == 0 ? "First photo" : "Photo \(draft.coverIndex + 1)",
                systemImage: "photo",
                action: { draft.coverIndex = (draft.coverIndex + 1) % 3 }
            )
        }
        .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
    }

    private func criteriaSummary(title: String, criteria: [V3LabCriterion]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.tertiaryText)
            Text(criteria.map { "\($0.title) \($0.rating.formatted(.number.precision(.fractionLength(1))))" }.joined(separator: "  ·  "))
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct V3LabTastePassportScreen: View {
    let draft: V3LabDraft
    let onWhy: () -> Void
    let onStartAnother: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.lg) {
                MugshotScreenHeader("Taste Passport", subtitle: "Built gently from memories you choose to keep") {
                    ShareLink(item: "My Mugshot Taste Passport") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                            .frame(width: 36, height: 36)
                            .background(Color.foamWhite)
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
                title: "Log another sip",
                subtitle: "Keep the ritual going when it feels right.",
                systemImage: "plus",
                action: onStartAnother
            )
        }
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your taste identity", systemImage: "leaf.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.mugshotSage)
            Text("Bright-city wanderer")
                .mugshotDisplay(size: 30)
                .foregroundColor(.espressoBrown)
            Text("Bright citrus keeps showing up, and quiet cafe corners lift the whole memory.")
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        HStack(spacing: 14) {
            Image(systemName: "map.fill")
                .font(.system(size: 26, weight: .regular))
                .foregroundColor(.mugshotSage)
                .frame(width: 52, height: 52)
                .background(Color.mugshotMint.opacity(0.22))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("Memories across 6 places")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.espressoBrown)
                Text("Charleston · Vancouver · Home")
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
            }
            Spacer()
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(.mugshotSage)
        }
        .padding(14)
        .background(Color.mugshotMint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
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

private func nearestHalf(_ value: Double) -> Double {
    (value * 2).rounded() / 2
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
