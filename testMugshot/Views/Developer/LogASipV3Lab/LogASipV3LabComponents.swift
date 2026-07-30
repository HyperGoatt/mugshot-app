#if DEBUG
import SwiftUI

struct V3LabSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let eyebrow: String?
    @ViewBuilder var trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        eyebrow: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.eyebrow = eyebrow
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Space.sm) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.mugshotSage)
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: DesignSystem.Space.xs)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct V3LabPhotoPicker: View {
    @Binding var coverIndex: Int
    var usesPlaceholder = false
    var onAddPhoto: () -> Void

    private let imageNames = V3LabMedia.photos

    private var selectedImageName: String {
        imageNames[min(max(coverIndex, 0), imageNames.count - 1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.sm) {
            ZStack(alignment: .bottomLeading) {
                if usesPlaceholder {
                    placeholder
                } else {
                    Image(selectedImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 224)
                        .clipped()
                }

                Label("Cover", systemImage: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.mugshotMint)
                    .clipShape(Capsule())
                    .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 224)
            .background(Color.sandBeige.opacity(0.66))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(usesPlaceholder ? "Mugsy forgot my photo placeholder" : "Selected Mugshot cover photo")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Space.xs) {
                    ForEach(Array(imageNames.enumerated()), id: \.offset) { index, imageName in
                        Button {
                            withAnimation(DesignSystem.Motion.base) {
                                coverIndex = index
                            }
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                Image(imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                                if coverIndex == index {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.espressoBrown)
                                        .frame(width: 21, height: 21)
                                        .background(Color.mugshotMint)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.foamWhite, lineWidth: 2))
                                        .offset(x: 3, y: 3)
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(
                                        coverIndex == index ? Color.mugshotMint : Color.mugshotLine,
                                        lineWidth: coverIndex == index ? 4 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use photo \(index + 1) as cover")
                        .accessibilityAddTraits(coverIndex == index ? .isSelected : [])
                    }

                    Button(action: onAddPhoto) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Add")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.mugshotSage)
                        .frame(width: 58, height: 58)
                        .background(Color.foamWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.mugshotLine, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add another photo")
                }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.mugshotMint.opacity(0.32), Color.sandBeige.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: DesignSystem.Space.md) {
                MugsyModelView(configuration: MugsyModelConfiguration(
                    expression: .curious,
                    prop: .camera,
                    pose: .leaningLeft
                ))
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Oops, missed the photo")
                        .mugshotDisplay(size: 21)
                        .foregroundColor(.espressoBrown)
                    Text("Mugsy saved your memory a spot.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
            }
            .padding(20)
        }
    }
}

struct V3LabLabeledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)

            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 20)
                }

                TextField(placeholder, text: $text)
                    .font(.system(size: 15, weight: .medium))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }
            .mugshotFormField()
        }
    }
}

struct V3LabJournalEditor: View {
    let title: String
    let prompt: String
    @Binding var text: String
    var privacyLabel: String? = "Private journal"
    var minimumHeight: CGFloat = 148

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.xs) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Spacer(minLength: 8)

                if let privacyLabel {
                    Label(privacyLabel, systemImage: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.mugshotMint.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(prompt)
                        .font(.system(size: 15))
                        .foregroundColor(.inputPlaceholder)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(.inputText)
                    .tint(.mugshotSage)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .frame(minHeight: minimumHeight)
            }
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
        }
    }
}

struct V3LabHalfStarRating: View {
    @Binding var rating: Double
    var label: String? = nil
    var starSize: CGFloat = 28
    var spacing: CGFloat = 6
    var isInteractive = true

    var body: some View {
        MugshotV3HalfStarRating(
            rating: $rating,
            label: label,
            starSize: starSize,
            spacing: spacing,
            isInteractive: isInteractive
        )
    }
}

struct V3LabCriterionRow: View {
    @Binding var criterion: V3LabCriterion
    var onRemove: () -> Void

    var body: some View {
        MugshotV3CriterionRow(
            title: criterion.title,
            systemImage: criterion.systemImage,
            rating: $criterion.rating,
            importance: $criterion.importance,
            isPinned: $criterion.isPinned,
            onRemove: onRemove
        )
    }
}

struct V3LabSuggestionChip: View {
    let suggestion: V3LabSuggestion
    var isAdded = false
    var action: () -> Void

    var body: some View {
        MugshotV3SuggestionChip(
            title: suggestion.title,
            systemImage: suggestion.systemImage,
            isAdded: isAdded,
            action: action
        )
    }
}

struct V3LabScoreGuidanceCard: View {
    let suggestedScore: Double
    let currentScore: Double
    var onUse: () -> Void

    var body: some View {
        MugshotV3ScoreGuidanceCard(
            suggestedScore: suggestedScore,
            currentScore: currentScore,
            onUse: onUse
        )
    }
}

struct V3LabInlineMugsyCoach: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let prompts: [V3LabCoachPrompt]
    @Binding var index: Int
    var onExploreFlavors: (() -> Void)? = nil

    @State private var isExpanded = false
    @State private var mugsyWiggle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 0) {
                Button {
                    if reduceMotion {
                        isExpanded = true
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.58)) {
                            mugsyWiggle.toggle()
                            isExpanded = true
                        }
                    }
                } label: {
                    MugsyModelView(configuration: MugsyModelConfiguration(
                        expression: .curious,
                        prop: .journalNotebook,
                        pose: .leaningRight,
                        gaze: UnitPoint(x: 0.60, y: 0.44)
                    ))
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (mugsyWiggle ? 2.5 : -1.5)))
                    .scaleEffect(reduceMotion ? 1 : (mugsyWiggle ? 1.03 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ask Mugsy for a reflection nudge")

                Button {
                    if reduceMotion {
                        isExpanded.toggle()
                    } else {
                        withAnimation(DesignSystem.Motion.base) {
                            isExpanded.toggle()
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isExpanded ? safePrompt.prompt : "Need a nudge?")
                            .font(.system(size: isExpanded ? 14 : 15, weight: .semibold, design: .serif))
                            .foregroundColor(.espressoBrown)
                            .multilineTextAlignment(.leading)
                        Text(isExpanded ? safePrompt.hint : "Mugsy is here when your words need a little motion.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.mugshotMint.opacity(0.76), lineWidth: 1)
                    )
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.foamWhite)
                            .offset(x: -9, y: -13)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                HStack(spacing: 10) {
                    Button {
                        if reduceMotion {
                            index = max(0, safeIndex - 1)
                        } else {
                            withAnimation(DesignSystem.Motion.fast) {
                                index = max(0, safeIndex - 1)
                            }
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(safeIndex == 0)

                    Spacer()
                    Text("\(safeIndex + 1) of \(prompts.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.tertiaryText)
                    Spacer()

                    Button {
                        if reduceMotion {
                            index = min(prompts.count - 1, safeIndex + 1)
                        } else {
                            withAnimation(DesignSystem.Motion.fast) {
                                index = min(prompts.count - 1, safeIndex + 1)
                            }
                        }
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .disabled(safeIndex == prompts.count - 1)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .padding(.leading, 88)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let onExploreFlavors {
                Button(action: onExploreFlavors) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.mugshotSage)
                            .frame(width: 30, height: 30)
                            .background(Color.mugshotMint.opacity(0.22))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Explore flavors")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            Text("Start broad, then drill into what fits")
                                .font(.system(size: 10))
                                .foregroundColor(.tertiaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.mugshotSage)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 50)
                    .background(Color.mugshotMint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.mugshotMint.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotMint.opacity(0.34), lineWidth: 1)
        )
    }

    private var safeIndex: Int {
        min(max(index, 0), max(prompts.count - 1, 0))
    }

    private var safePrompt: V3LabCoachPrompt {
        prompts[safeIndex]
    }
}

struct V3LabScoreEquation: View {
    let sipScore: Double
    let contextScore: Double?
    var contextLabel = "Cafe"
    let mugshotScore: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("YOUR MUGSHOT", systemImage: "camera.aperture")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundColor(.foamWhite.opacity(0.82))
                    Text(mugshotScore, format: .number.precision(.fractionLength(1)))
                        .mugshotDisplay(size: 46)
                        .monospacedDigit()
                        .foregroundColor(.foamWhite)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.mugshotMint.opacity(0.55), lineWidth: 1)
                        .frame(width: 64, height: 64)
                    Circle()
                        .stroke(Color.foamWhite.opacity(0.72), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 52, height: 52)
                    Image(systemName: "mug.fill")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundColor(.foamWhite)
                }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 104)
            .background(Color.mugshotSage)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))

            HStack(spacing: 8) {
                scorePill(label: "Sip", score: sipScore, icon: "cup.and.saucer.fill")

                if let contextScore {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.tertiaryText)
                        .accessibilityHidden(true)
                    scorePill(label: contextLabel, score: contextScore, icon: contextLabel == "Cafe" ? "storefront.fill" : "mappin.and.ellipse")
                }

                Spacer(minLength: 0)
                Text("One whole memory")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundColor(.mugshotSage)
            }
        }
        .padding(12)
        .background(Color.sandBeige.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func scorePill(label: String, score: Double, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.mugshotSage)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondaryText)
            Text(score, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.espressoBrown)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color.foamWhite)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.mugshotLine, lineWidth: 1))
    }

    private var accessibilitySummary: String {
        if let contextScore {
            return String(
                format: "Sip %.1f plus %@ %.1f equals Mugshot %.1f",
                sipScore,
                contextLabel,
                contextScore,
                mugshotScore
            )
        }
        return String(format: "Sip %.1f equals Mugshot %.1f", sipScore, mugshotScore)
    }
}

struct V3LabVisibilitySelector<Option: Identifiable & Equatable>: View {
    let title: String
    let detail: String
    let systemImage: String
    let options: [Option]
    @Binding var selection: Option
    let optionTitle: (Option) -> String
    var isEnabled: (Option) -> Bool

    init(
        title: String,
        detail: String,
        systemImage: String,
        options: [Option],
        selection: Binding<Option>,
        optionTitle: @escaping (Option) -> String,
        isEnabled: @escaping (Option) -> Bool = { _ in true }
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.options = options
        self._selection = selection
        self.optionTitle = optionTitle
        self.isEnabled = isEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 30, height: 30)
                    .background(Color.mugshotMint.opacity(0.18))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(.tertiaryText)
                }
            }

            HStack(spacing: 6) {
                ForEach(options) { option in
                    let enabled = isEnabled(option)
                    Button {
                        guard enabled else { return }
                        withAnimation(DesignSystem.Motion.fast) {
                            selection = option
                        }
                    } label: {
                        Text(optionTitle(option))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selection == option ? .foamWhite : (enabled ? .espressoBrown : .tertiaryText))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(selection == option ? Color.mugshotSage : Color.foamWhite.opacity(enabled ? 1 : 0.5))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selection == option ? Color.clear : Color.mugshotLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
        }
        .padding(13)
        .background(Color.foamWhite)
    }
}

struct V3LabFriendInviteStrip: View {
    @Binding var selectedIDs: Set<String>
    let onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Invite friends", systemImage: "person.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Spacer()
                Text(selectedIDs.isEmpty ? "Shared MugShot" : "\(selectedIDs.count) invited")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            HStack(spacing: 9) {
                ForEach(V3LabFriend.recommended.prefix(5)) { friend in
                    Button {
                        withAnimation(DesignSystem.Motion.fast) {
                            if selectedIDs.contains(friend.id) {
                                selectedIDs.remove(friend.id)
                            } else {
                                selectedIDs.insert(friend.id)
                            }
                        }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            MugshotAvatar(name: friend.name, size: 42, imageURL: friend.imageURL)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedIDs.contains(friend.id) ? Color.mugshotSage : Color.clear,
                                            lineWidth: 3
                                        )
                                )

                            if selectedIDs.contains(friend.id) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.foamWhite)
                                    .frame(width: 15, height: 15)
                                    .background(Color.mugshotSage)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.foamWhite, lineWidth: 1.5))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(selectedIDs.contains(friend.id) ? "Remove" : "Invite") \(friend.name)")
                }

                Button(action: onShowAll) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 42, height: 42)
                        .background(Color.mugshotMint.opacity(0.18))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.mugshotMint.opacity(0.62), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("See all friends")
            }
        }
        .padding(13)
        .background(Color.foamWhite)
    }
}

struct V3LabPublishSettingRow: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .mugshotSage
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(action == nil ? "" : "Double tap to change")
    }

    private var rowContent: some View {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tertiaryText)
                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.tertiaryText)
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 58)
            .background(Color.foamWhite)
            .contentShape(Rectangle())
    }
}

struct V3LabBottomAction: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = "arrow.right"
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.mugshotLine.opacity(0.7))
                .frame(height: 1)

            Button(action: action) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.foamWhite.opacity(0.78))
                        }
                    }

                    Spacer(minLength: 8)

                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundColor(.foamWhite)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(minHeight: subtitle == nil ? 50 : 56)
                .background(isEnabled ? Color.mugshotSage : Color.mugshotSage.opacity(0.42))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .background(Color.creamWhite.opacity(0.88))
    }
}
#endif
