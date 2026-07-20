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

    private let imageNames = [
        "V3OrangeCreamsicleHeroV2",
        "V3OrangeCreamsicleSquare",
        "V3OrangeCitrusDetail",
        "V3CreamyLatte",
        "V3QuietCafeCorner"
    ]

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

                Label("Cover", systemImage: "photo.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.creamWhite)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.espressoBrown.opacity(0.74))
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
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(
                                            coverIndex == index ? Color.mugshotSage : Color.mugshotLine,
                                            lineWidth: coverIndex == index ? 3 : 1
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
    var onCoach: (() -> Void)? = nil

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
            .overlay(alignment: .bottomTrailing) {
                if let onCoach {
                    Button(action: onCoach) {
                        Label("Need a nudge?", systemImage: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.mugshotMint.opacity(0.9))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityHint("Opens a short Mugsy reflection prompt")
                }
            }
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
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { index in
                star(at: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Rating")
        .accessibilityValue(String(format: "%.1f out of 5", rating))
        .accessibilityHint(isInteractive ? "Swipe up or down to change by half a star" : "")
        .accessibilityAdjustableAction { direction in
            guard isInteractive else { return }
            switch direction {
            case .increment:
                rating = min(5, rating + 0.5)
            case .decrement:
                rating = max(0, rating - 0.5)
            @unknown default:
                break
            }
        }
    }

    private func fillFraction(for index: Int) -> CGFloat {
        CGFloat(min(1, max(0, rating - Double(index))))
    }

    private func star(at index: Int) -> some View {
        ZStack {
            Image(systemName: "star")
                .resizable()
                .scaledToFit()
                .foregroundColor(Color.mugshotSage.opacity(0.46))

            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.mugshotSage)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: starSize * fillFraction(for: index))
                }

            if isInteractive {
                HStack(spacing: 0) {
                    Button {
                        rating = Double(index) + 0.5
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .accessibilityHidden(true)

                    Button {
                        rating = Double(index) + 1
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: starSize, height: starSize)
    }
}

struct V3LabCriterionRow: View {
    @Binding var criterion: V3LabCriterion
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: criterion.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .frame(width: 30, height: 30)
                .background(Color.mugshotMint.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    V3LabHalfStarRating(
                        rating: $criterion.rating,
                        label: "\(criterion.title) rating",
                        starSize: 14,
                        spacing: 2
                    )

                    Text(String(format: "%.1f", criterion.rating))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.tertiaryText)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 2)

            Menu {
                ForEach(V3LabImportance.allCases) { importance in
                    Button {
                        withAnimation(DesignSystem.Motion.fast) {
                            criterion.importance = importance
                        }
                    } label: {
                        if criterion.importance == importance {
                            Label(importance.title, systemImage: "checkmark")
                        } else {
                            Text(importance.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(criterion.importance.title)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondaryText)
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Color.sandBeige.opacity(0.66))
                .clipShape(Capsule())
            }
            .accessibilityLabel("Importance: \(criterion.importance.title)")

            Button {
                withAnimation(DesignSystem.Motion.fast) {
                    criterion.isPinned.toggle()
                }
            } label: {
                Image(systemName: criterion.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(criterion.isPinned ? .foamWhite : .secondaryText)
                    .frame(width: 28, height: 28)
                    .background(criterion.isPinned ? Color.mugshotSage : Color.sandBeige.opacity(0.66))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(criterion.isPinned ? "Unpin \(criterion.title)" : "Pin \(criterion.title) for next time")

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.tertiaryText)
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(criterion.title)")
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 60)
        .background(Color.foamWhite)
    }
}

struct V3LabSuggestionChip: View {
    let suggestion: V3LabSuggestion
    var isAdded = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(suggestion.title)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: isAdded ? "checkmark" : "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(isAdded ? .foamWhite : .espressoBrown)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isAdded ? Color.mugshotSage : Color.foamWhite)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isAdded ? Color.clear : Color.mugshotLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAdded ? "Remove \(suggestion.title) criterion" : "Add \(suggestion.title) criterion")
        .accessibilityAddTraits(isAdded ? .isSelected : [])
    }
}

struct V3LabScoreGuidanceCard: View {
    let suggestedScore: Double
    let currentScore: Double
    var onUse: () -> Void

    private var scoresDiffer: Bool {
        abs(suggestedScore - currentScore) >= 0.05
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .frame(width: 34, height: 34)
                .background(Color.mugshotMint.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Your criteria suggest \(suggestedScore, specifier: "%.1f")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Text(scoresDiffer ? "Your gut score stays in charge." : "Your score and criteria are aligned.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }

            Spacer(minLength: 4)

            if scoresDiffer {
                Button("Use \(suggestedScore, specifier: "%.1f")", action: onUse)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.mugshotSage)
                    .buttonStyle(.plain)
                    .accessibilityHint("Replaces the overall score with the criteria suggestion")
            }
        }
        .padding(12)
        .background(Color.mugshotMint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                .stroke(Color.mugshotMint.opacity(0.4), lineWidth: 1)
        )
    }
}

struct V3LabMugsyCoachRow: View {
    var title = "Need help noticing?"
    var prompt = "Mugsy can offer one small question at a time."
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MugsyModelView(configuration: MugsyModelConfiguration(
                    expression: .curious,
                    prop: .journalNotebook,
                    pose: .leaningRight,
                    gaze: UnitPoint(x: 0.58, y: 0.48)
                ))
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text(prompt)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mugshotSage)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(Color.mugshotMint.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .stroke(Color.mugshotMint.opacity(0.42), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(prompt)")
        .accessibilityHint("Opens Mugsy coaching prompts")
    }
}

struct V3LabScoreEquation: View {
    let sipScore: Double
    let contextScore: Double?
    var contextLabel = "Cafe"
    let mugshotScore: Double

    var body: some View {
        HStack(spacing: 7) {
            scoreTile(label: "Sip", score: sipScore, accent: false)

            if let contextScore {
                operatorLabel("plus")
                scoreTile(label: contextLabel, score: contextScore, accent: false)
            }

            operatorLabel("equals")
            scoreTile(label: "Mugshot", score: mugshotScore, accent: true)
        }
        .padding(10)
        .background(Color.sandBeige.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func scoreTile(label: String, score: Double, accent: Bool) -> some View {
        VStack(spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(accent ? .foamWhite.opacity(0.84) : .tertiaryText)

            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(score, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundColor(accent ? .foamWhite : .espressoBrown)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background(accent ? Color.mugshotSage : Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                .stroke(accent ? Color.clear : Color.mugshotLine, lineWidth: 1)
        )
    }

    private func operatorLabel(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.tertiaryText)
            .frame(width: 10)
            .accessibilityHidden(true)
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
