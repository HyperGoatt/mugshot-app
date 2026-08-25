import SwiftUI

/// Human-language importance options shared by the V3 UI Lab and production composer.
protocol MugshotV3ImportanceOption: CaseIterable, Identifiable, Equatable {
    var title: String { get }
}

extension SipCriterionImportance: MugshotV3ImportanceOption {}

#if DEBUG
extension V3LabImportance: MugshotV3ImportanceOption {}
#endif

/// The exact fractional-star control approved in the Log a Sip V3 UI Lab.
struct MugshotV3HalfStarRating: View {
    @Binding var rating: Double
    var label: String? = nil
    var starSize: CGFloat = 28
    var spacing: CGFloat = 6
    var isInteractive = true
    var minimumScore = 0.0
    var accessibilityIdentifier: String? = nil

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
                rating = max(minimumScore, min(5, (floor(rating * 2) + 1) / 2))
            case .decrement:
                rating = max(minimumScore, (ceil(rating * 2) - 1) / 2)
            @unknown default:
                break
            }
        }
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
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
        }
        .frame(width: starSize, height: starSize)
        .frame(width: hitTargetWidth, height: 44)
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture(coordinateSpace: .local)
                .onEnded { value in
                    guard isInteractive else { return }
                    let tappedScore = Double(index) + (value.location.x < hitTargetWidth / 2 ? 0.5 : 1)
                    rating = max(minimumScore, tappedScore)
                }
        )
    }

    private var hitTargetWidth: CGFloat {
        max(40, starSize + 10)
    }
}

/// The exact compact criterion row approved in the Log a Sip V3 UI Lab.
struct MugshotV3CriterionRow<Importance: MugshotV3ImportanceOption>: View {
    let title: String
    let systemImage: String
    @Binding var rating: Double
    @Binding var importance: Importance
    @Binding var isPinned: Bool
    var accessibilityBaseIdentifier: String? = nil
    var onRename: (() -> Void)? = nil
    var onRemove: () -> Void

    @State private var showsImportancePicker = false
    @State private var showsRemoveConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 36, height: 36)
                    .background(Color.mugshotMint.opacity(0.22))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Button {
                        onRename?()
                    } label: {
                        HStack(spacing: 5) {
                            Text(title)
                                .lineLimit(2)
                            if onRename != nil {
                                Image(systemName: "pencil")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    }
                    .buttonStyle(.plain)
                    .disabled(onRename == nil)
                    .accessibilityLabel(onRename == nil ? title : "Rename \(title)")
                    Text(rating > 0 ? "How well this worked for you" : "Tap a star when it matters")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.tertiaryText)
                }

                Spacer(minLength: 4)

                VStack(spacing: 3) {
                    Button {
                        withAnimation(DesignSystem.Motion.fast) {
                            isPinned.toggle()
                        }
                    } label: {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isPinned ? .foamWhite : .secondaryText)
                            .frame(width: 27, height: 27)
                            .background(isPinned ? Color.mugshotSage : Color.sandBeige.opacity(0.66))
                            .clipShape(Circle())
                            .padding(8.5)
                            .contentShape(Rectangle())
                            .padding(-8.5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPinned ? "Unpin \(title)" : "Pin \(title) for future sips")
                    .accessibilityValue(isPinned ? "Pinned" : "Not pinned")
                    .accessibilityHint("Pinning keeps the criterion, while importance resets for each sip")
                    .modifier(OptionalAccessibilityIdentifier(identifier: controlIdentifier("pin")))

                    Button {
                        showsRemoveConfirmation = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.tertiaryText)
                            .frame(width: 27, height: 27)
                            .background(Color.sandBeige.opacity(0.42))
                            .clipShape(Circle())
                            .padding(8.5)
                            .contentShape(Rectangle())
                            .padding(-8.5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(title)")
                    .modifier(OptionalAccessibilityIdentifier(identifier: controlIdentifier("remove")))
                }
            }

            HStack(spacing: 8) {
                MugshotV3HalfStarRating(
                    rating: $rating,
                    label: "\(title) rating",
                    starSize: 26,
                    spacing: 3,
                    minimumScore: 0.5,
                    accessibilityIdentifier: controlIdentifier("rating")
                )

                Text(String(format: "%.1f", rating))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.tertiaryText)
                    .monospacedDigit()

                Spacer(minLength: 4)

                importanceButton
            }
        }
        .padding(12)
        .background(Color.foamWhite)
        .alert("Remove \(title)?", isPresented: $showsRemoveConfirmation) {
            Button("Remove", role: .destructive, action: onRemove)
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("You can always add this criterion again later.")
        }
    }

    private var importanceButton: some View {
        Button {
            showsImportancePicker = true
        } label: {
            HStack(spacing: 5) {
                Text(importance.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.espressoBrown)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color.mugshotMint.opacity(0.24))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.mugshotMint.opacity(0.72), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Importance: \(importance.title)")
        .accessibilityValue(importance.title)
        .modifier(OptionalAccessibilityIdentifier(identifier: controlIdentifier("importance")))
        .popover(isPresented: $showsImportancePicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("How much did this matter?")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .padding(.bottom, 3)

                ForEach(Array(Importance.allCases)) { option in
                    Button {
                        withAnimation(DesignSystem.Motion.fast) {
                            importance = option
                            showsImportancePicker = false
                        }
                    } label: {
                        HStack {
                            Text(option.title)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if importance == option {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(importance == option ? .foamWhite : .espressoBrown)
                        .padding(.horizontal, 12)
                        .frame(width: 176, height: 40)
                        .background(importance == option ? Color.mugshotSage : Color.foamWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("logASipV3.importance.\(String(describing: option.id).lowercased())")
                }

                Text("Importance is only for this sip. Pinning keeps the criterion for future sips.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }
            .padding(12)
            .background(Color.creamWhite)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func controlIdentifier(_ control: String) -> String? {
        accessibilityBaseIdentifier.map { "\($0).\(control)" }
    }
}

/// The exact suggestion chip approved in the Log a Sip V3 UI Lab.
struct MugshotV3SuggestionChip: View {
    let title: String
    let systemImage: String
    var isAdded = false
    var accessibilityIdentifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
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
        .disabled(isAdded)
        .accessibilityLabel(isAdded ? "\(title) criterion already added" : "Add \(title) criterion")
        .accessibilityAddTraits(isAdded ? .isSelected : [])
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }
}

/// The exact advisory-score card approved in the Log a Sip V3 UI Lab.
struct MugshotV3ScoreGuidanceCard: View {
    let suggestedScore: Double
    let currentScore: Double
    var onUse: () -> Void

    private var scoresDiffer: Bool {
        abs(suggestedScore - currentScore) >= 0.05
    }

    var body: some View {
        HStack(spacing: 13) {
            VStack(spacing: 1) {
                Text(suggestedScore, format: .number.precision(.fractionLength(1)))
                    .mugshotDisplay(size: 28)
                    .monospacedDigit()
                Text("SUGGESTED")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.9)
            }
            .foregroundColor(.espressoBrown)
            .frame(width: 76, height: 68)
            .background(Color.mugshotMint.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Your criteria see it this way")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Text(scoresDiffer ? "Your \(currentScore, specifier: "%.1f") gut score still stays in charge." : "Your score and criteria are aligned.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if scoresDiffer {
                Button("Use \(suggestedScore, specifier: "%.1f")", action: onUse)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.foamWhite)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.mugshotSage)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .accessibilityHint("Uses the exact one-decimal criteria suggestion")
            }
        }
        .padding(13)
        .background(Color.sandBeige.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotMint.opacity(0.58), lineWidth: 1)
        )
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
