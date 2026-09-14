#if DEBUG
import SwiftUI

struct MotionLabView: View {
    @State private var experience: LabExperience = .character
    @State private var expression: MugsyExpression = .neutral
    @State private var prop: MugsyProp = .none
    @State private var outfit: MugsyOutfit = .none
    @State private var drink: MugshotDrinkAppearance = .coffee
    @State private var intensity: MugshotMotion.Intensity = .subtle
    @State private var progress = 0.62
    @State private var temperature = 0.68
    @State private var rating = 4.2
    @State private var confidence = 0.66
    @State private var gazeX = 0.5
    @State private var gazeY = 0.5
    @State private var streakCount = 7.0
    @State private var isPaused = false
    @State private var simulateReducedMotion = false
    @State private var showDarkAppearance = false
    @State private var typeSize: LabTypeSize = .large
    @State private var outcome: LabOutcome = .neutral
    @State private var replaySeed = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                previewStage

                controlSection("Experience") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(LabExperience.allCases) { option in
                                Button {
                                    experience = option
                                    replaySeed += 1
                                } label: {
                                    Text(option.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(experience == option ? Color.foamWhite : Color.espressoBrown)
                                        .background(
                                            experience == option ? Color.mugshotSage : Color.creamWhite,
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(experience == option ? .isSelected : [])
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityLabel("Experience")

                    Picker("Outcome", selection: $outcome) {
                        ForEach(LabOutcome.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if experience == .character || experience == .emptyState || experience == .composer {
                    characterControls
                }

                if experience == .camera {
                    cameraControls
                }

                if experience == .streak {
                    controlSection("Ritual") {
                        labeledSlider("Consecutive days", value: $streakCount, range: 0...100, valueText: "\(Int(streakCount.rounded()))")
                        Button("Jump to next milestone") { jumpToNextMilestone() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }

                if experience == .taste {
                    controlSection("Taste Bloom") {
                        labeledSlider("Sample confidence", value: $confidence, range: 0...1, valueText: percent(confidence))
                        labeledSlider("Profile evolution", value: $progress, range: 0...1, valueText: percent(progress))
                    }
                }

                if experience == .refresh {
                    controlSection("Pull to Refresh") {
                        labeledSlider("Pull distance", value: $progress, range: 0...1.2, valueText: percent(min(progress, 1)))
                        Toggle("Refreshing", isOn: Binding(
                            get: { outcome == .success },
                            set: { outcome = $0 ? .success : .neutral }
                        ))
                    }
                }

                controlSection("Playback and Accessibility") {
                    Picker("Animation intensity", selection: $intensity) {
                        ForEach(MugshotMotion.Intensity.allCases) { intensity in
                            Text(intensity.rawValue.capitalized).tag(intensity)
                        }
                    }
                    Toggle("Pause motion", isOn: $isPaused)
                    Toggle("Simulate Reduce Motion", isOn: $simulateReducedMotion)
                    Toggle("Dark appearance", isOn: $showDarkAppearance)
                    Picker("Dynamic Type", selection: $typeSize) {
                        ForEach(LabTypeSize.allCases) { Text($0.title).tag($0) }
                    }
                    Button {
                        replaySeed += 1
                        MugshotHaptic.softImpact.play()
                    } label: {
                        Label("Replay", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Reset Lab", role: .destructive, action: reset)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .background(Color.creamWhite)
        .navigationTitle("Motion Lab")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(showDarkAppearance ? .dark : .light)
        .environment(\.mugshotReduceMotionOverride, simulateReducedMotion)
        .environment(\.dynamicTypeSize, typeSize.value)
    }

    private var previewStage: some View {
        Group {
            switch experience {
            case .character:
                MugsyAnimatedView(
                    configuration: characterConfiguration,
                    action: characterAction,
                    isPaused: isPaused
                )
                .frame(width: 170, height: 196)
            case .emptyState:
                MugsyEmptyStateView(
                    placement: prop == .favoriteHeart ? .savedFavorites : .savedWishlist,
                    title: prop == .favoriteHeart ? "Favorites are waiting" : "The next stop is out there",
                    message: prop == .favoriteHeart
                        ? "Save the sips and cafes you want to keep close."
                        : "Bookmark a cafe whenever it catches your curiosity."
                )
            case .composer:
                MugshotSipProgressMug(
                    progress: progress,
                    drinkName: drink.rawValue,
                    rating: rating,
                    isSaving: outcome == .neutral && progress > 0.9,
                    isComplete: outcome == .success
                )
                .frame(width: 160, height: 184)
            case .camera:
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                    Text("Apple system camera")
                        .font(.system(size: 15, weight: .bold))
                    Text("Capture controls are provided by iOS.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(width: 210, height: 184)
            case .streak:
                MugshotRitualCard(dates: ritualDates, now: labNow)
            case .taste:
                MugshotTasteBloom(samples: tasteSamples, confidence: confidence, size: 184)
            case .refresh:
                MugshotPullRefreshIndicator(progress: progress, isRefreshing: outcome == .success)
            case .completion:
                MugshotCompletionCard(
                    mugsyConfiguration: MugsyModelConfiguration(
                        expression: .delighted,
                        liquid: .coffee(fillProgress: 0.94, steamIntensity: 0.82)
                    ),
                    mugsyAction: .celebrating,
                    eyebrow: "Sip saved",
                    title: "Cortado remembered",
                    message: "A small coffee moment just joined your Journal.",
                    facts: [
                        MugshotCompletionFact(icon: "star.fill", label: "Rating", value: "4.8"),
                        MugshotCompletionFact(icon: "book.closed.fill", label: "Saved for", value: "Friends")
                    ],
                    celebrates: true
                )
                .scaleEffect(0.88)
            }
        }
        .id(replaySeed)
        .frame(maxWidth: .infinity, minHeight: 224)
        .padding(18)
        .background(stageBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(outcomeColor.opacity(outcome == .neutral ? 0.18 : 0.72), lineWidth: 1.5)
        )
    }

    private var characterControls: some View {
        controlSection("Canonical Mugsy") {
            Picker("Expression", selection: $expression) {
                ForEach(MugsyExpression.allCases) { Text($0.title).tag($0) }
            }
            Picker("Prop", selection: $prop) {
                ForEach(MugsyProp.allCases) { Text($0.title).tag($0) }
            }
            Picker("Outfit", selection: $outfit) {
                ForEach(MugsyOutfit.allCases) { Text($0.title).tag($0) }
            }
            Picker("Drink", selection: $drink) {
                ForEach(MugshotDrinkAppearance.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            labeledSlider("Progress", value: $progress, range: 0...1, valueText: percent(progress))
            labeledSlider("Temperature", value: $temperature, range: 0...1, valueText: percent(temperature))
            labeledSlider("Rating", value: $rating, range: 0...5, valueText: String(format: "%.1f", rating))
            labeledSlider("Gaze X", value: $gazeX, range: 0...1, valueText: percent(gazeX))
            labeledSlider("Gaze Y", value: $gazeY, range: 0...1, valueText: percent(gazeY))
        }
    }

    private var cameraControls: some View {
        controlSection("System Camera") {
            Text("Mugshot presents UIImagePickerController full screen in still-photo mode. Camera controls, Retake, and Use Photo are owned by iOS.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var characterConfiguration: MugsyModelConfiguration {
        MugsyModelConfiguration(
            expression: expression,
            prop: prop,
            outfit: outfit,
            gaze: UnitPoint(x: gazeX, y: gazeY),
            liquid: MugsyLiquidState(
                appearance: drink,
                fillProgress: progress,
                steamIntensity: temperature * (0.35 + rating / 7)
            )
        )
    }

    private var characterAction: MugsyActionState {
        switch outcome {
        case .neutral: return .resting
        case .success: return .celebrating
        case .error: return .recovering
        }
    }

    private var labNow: Date {
        Date(timeIntervalSince1970: 1_788_000_000)
    }

    private var ritualDates: [Date] {
        (0..<Int(streakCount.rounded())).compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: labNow)
        }
    }

    private var tasteSamples: [TasteBloomSample] {
        [
            TasteBloomSample(label: "Cold drinks", value: 0.35 + progress * 0.55, support: 8),
            TasteBloomSample(label: "Milk drinks", value: 0.28 + confidence * 0.62, support: 7),
            TasteBloomSample(label: "Bean clarity", value: 0.20 + progress * 0.48, support: 4),
            TasteBloomSample(label: "Cafe ritual", value: 0.30 + confidence * 0.48, support: 6),
            TasteBloomSample(label: "Home brews", value: 0.18 + progress * 0.36, support: 3)
        ]
    }

    private var stageBackground: Color {
        showDarkAppearance ? Color(hex: "18130F") : .foamWhite
    }

    private var outcomeColor: Color {
        switch outcome {
        case .neutral: return .mugshotSage
        case .success: return .mugshotMatcha
        case .error: return Color(hex: "B87957")
        }
    }

    private func controlSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundColor(.mugshotSage)
            content()
        }
        .padding(16)
        .cardStyle()
    }

    private func labeledSlider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                Spacer()
                Text(valueText).monospacedDigit().foregroundColor(.secondaryText)
            }
            .font(.system(size: 12, weight: .semibold))
            Slider(value: value, in: range).tint(.mugshotSage)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func jumpToNextMilestone() {
        streakCount = [3, 7, 14, 30, 50, 100].first(where: { Double($0) > streakCount })
            .map(Double.init) ?? 3
        outcome = .success
        replaySeed += 1
    }

    private func reset() {
        experience = .character
        expression = .neutral
        prop = .none
        outfit = .none
        drink = .coffee
        intensity = .subtle
        progress = 0.62
        temperature = 0.68
        rating = 4.2
        confidence = 0.66
        gazeX = 0.5
        gazeY = 0.5
        streakCount = 7
        isPaused = false
        simulateReducedMotion = false
        showDarkAppearance = false
        typeSize = .large
        outcome = .neutral
        replaySeed += 1
    }
}

private enum LabExperience: String, CaseIterable, Identifiable {
    case character, emptyState, composer, camera, streak, taste, refresh, completion
    var id: String { rawValue }
    var title: String {
        switch self {
        case .character: return "Rig"
        case .emptyState: return "Empty"
        case .composer: return "Log"
        case .camera: return "Camera"
        case .streak: return "Ritual"
        case .taste: return "Taste"
        case .refresh: return "Refresh"
        case .completion: return "Saved"
        }
    }
}

private enum LabOutcome: String, CaseIterable, Identifiable {
    case neutral, success, error
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private enum LabTypeSize: String, CaseIterable, Identifiable {
    case medium, large, accessibility
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var value: DynamicTypeSize {
        switch self {
        case .medium: return .medium
        case .large: return .large
        case .accessibility: return .accessibility3
        }
    }
}

#Preview {
    NavigationStack { MotionLabView() }
}
#endif
