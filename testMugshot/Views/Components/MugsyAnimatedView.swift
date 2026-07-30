import SwiftUI

/// Event-driven articulation around the canonical static renderer. Ordinary
/// placements stay still; touch reactions are explicitly enabled only where
/// Mugsy is meant to be playful.
struct MugsyAnimatedView: View {
    var configuration = MugsyModelConfiguration()
    var action: MugsyActionState = .resting
    var tapBehavior: MugsyTapBehavior = .disabled
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride
    @Environment(\.scenePhase) private var scenePhase
    @State private var responseAmount: CGFloat = 0
    @State private var tapRequest = 0
    @State private var tapCycleIndex = 0
    @State private var activeReaction: MugsyTapReaction?
    @State private var reactionAmount: CGFloat = 0
    @State private var reactionDirection: CGFloat = 0

    private var effectiveReduceMotion: Bool { reduceMotionOverride ?? reduceMotion }
    private var canAnimate: Bool { !isPaused && !effectiveReduceMotion && scenePhase == .active }

    private var renderedConfiguration: MugsyModelConfiguration {
        var result = action.applying(to: configuration)
        switch activeReaction {
        case .wave:
            result.expression = .delighted
            result.armPose = .waving
            result.gaze = .topTrailing
        case .hop:
            result.expression = .delighted
            result.gaze = .top
        case .happyDance:
            result.expression = .delighted
            result.armPose = .presenting
            result.gaze = .topTrailing
        case nil:
            break
        }
        return result
    }

    var body: some View {
        Group {
            if tapBehavior == .disabled {
                articulatedMugsy
            } else {
                articulatedMugsy
                    .contentShape(Rectangle())
                    .onTapGesture(perform: requestTapReaction)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Tap to play with Mugsy")
                    .accessibilityAction(named: Text("Play with Mugsy"), requestTapReaction)
            }
        }
    }

    private var articulatedMugsy: some View {
        MugsyModelView(configuration: renderedConfiguration)
            .scaleEffect(
                (baseScale + responseAmount * responseScale) * (1 + reactionAmount * reactionScale),
                anchor: .bottom
            )
            .rotationEffect(
                .degrees(baseRotation + responseAmount * responseRotation + Double(reactionDirection * reactionRotation)),
                anchor: .bottom
            )
            .offset(
                x: reactionDirection * reactionTravel,
                y: baseOffsetY - responseAmount * responseLift - reactionAmount * reactionLift
            )
            .animation(
                MugshotMotion.animation(MugshotMotion.response, reduceMotion: effectiveReduceMotion),
                value: action
            )
            .task(id: action.responseKey) {
                await performResponseIfNeeded()
            }
            .task(id: tapRequest) {
                await performTapReactionIfNeeded()
            }
    }

    private var baseScale: CGFloat {
        switch action {
        case .entering: return 0.98
        case .pulling(let progress): return 0.91 + MugshotMotion.normalized(progress) * 0.09
        case .composing(let progress): return 0.98 + MugshotMotion.normalized(progress) * 0.02
        case .recovering: return 0.98
        case .resting, .refreshing, .focusing, .capturing, .saving, .success, .celebrating:
            return 1
        }
    }

    private var baseRotation: Double {
        switch action {
        case .pulling(let progress):
            return Double(MugshotMotion.normalized(progress) - 0.5) * 2.4
        case .focusing, .saving: return -0.8
        case .recovering: return -1.2
        case .resting, .entering, .refreshing, .composing, .capturing, .success, .celebrating:
            return 0
        }
    }

    private var baseOffsetY: CGFloat {
        switch action {
        case .entering: return 4
        case .pulling(let progress): return 5 - MugshotMotion.normalized(progress) * 5
        case .resting, .refreshing, .composing, .focusing, .capturing, .saving, .success, .recovering, .celebrating:
            return 0
        }
    }

    private var responseScale: CGFloat {
        switch action {
        case .success, .celebrating: return 0.055
        case .capturing: return 0.025
        case .refreshing, .entering: return 0.018
        case .resting, .pulling, .composing, .focusing, .saving, .recovering: return 0
        }
    }

    private var responseRotation: Double {
        switch action {
        case .success, .celebrating: return 2.2
        case .capturing: return -1.4
        case .refreshing: return 1.0
        case .resting, .entering, .pulling, .composing, .focusing, .saving, .recovering: return 0
        }
    }

    private var responseLift: CGFloat {
        switch action {
        case .success, .celebrating: return 7
        case .capturing: return 3
        case .refreshing, .entering: return 2
        case .resting, .pulling, .composing, .focusing, .saving, .recovering: return 0
        }
    }

    private var shouldRespond: Bool {
        switch action {
        case .entering, .refreshing, .capturing, .success, .celebrating:
            return true
        case .resting, .pulling, .composing, .focusing, .saving, .recovering:
            return false
        }
    }

    private var reactionScale: CGFloat {
        switch activeReaction {
        case .wave: return 0.018
        case .hop: return 0.045
        case .happyDance: return 0.032
        case nil: return 0
        }
    }

    private var reactionRotation: CGFloat {
        switch activeReaction {
        case .wave: return 3.1
        case .hop: return 0
        case .happyDance: return 4.2
        case nil: return 0
        }
    }

    private var reactionLift: CGFloat {
        switch activeReaction {
        case .wave: return 1
        case .hop: return 15
        case .happyDance: return 7
        case nil: return 0
        }
    }

    private var reactionTravel: CGFloat {
        activeReaction == .happyDance ? 3 : 0
    }

    private func requestTapReaction() {
        guard tapBehavior != .disabled, !isPaused else { return }
        tapRequest += 1
        MugshotHaptic.softImpact.play()
    }

    @MainActor
    private func performResponseIfNeeded() async {
        responseAmount = 0
        guard shouldRespond, canAnimate else { return }

        withAnimation(MugshotMotion.character) {
            responseAmount = 1
        }

        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }

        withAnimation(MugshotMotion.settle) {
            responseAmount = 0
        }
    }

    @MainActor
    private func performTapReactionIfNeeded() async {
        guard tapRequest > 0, tapBehavior != .disabled, !isPaused else { return }

        let reaction: MugsyTapReaction
        switch tapBehavior {
        case .disabled:
            return
        case .wave:
            reaction = .wave
        case .playfulCycle:
            reaction = MugsyTapReaction.allCases[tapCycleIndex % MugsyTapReaction.allCases.count]
            tapCycleIndex += 1
        }

        activeReaction = reaction
        reactionAmount = effectiveReduceMotion ? 0.12 : 0
        reactionDirection = 0
        defer {
            activeReaction = nil
            reactionAmount = 0
            reactionDirection = 0
        }

        guard canAnimate else {
            try? await Task.sleep(for: .milliseconds(360))
            return
        }

        switch reaction {
        case .wave:
            for direction: CGFloat in [0.8, -0.58, 0.72, -0.38, 0.0] {
                withAnimation(.spring(duration: 0.18, bounce: 0.18)) {
                    reactionAmount = direction == 0 ? 0.28 : 1
                    reactionDirection = direction
                }
                try? await Task.sleep(for: .milliseconds(125))
                guard !Task.isCancelled else { return }
            }
        case .hop:
            withAnimation(.spring(duration: 0.24, bounce: 0.30)) {
                reactionAmount = 1
            }
            try? await Task.sleep(for: .milliseconds(230))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.30, bounce: 0.16)) {
                reactionAmount = 0
            }
            try? await Task.sleep(for: .milliseconds(260))
        case .happyDance:
            let directions: [CGFloat] = [-1, 1, -0.82, 0.82, -0.48, 0.48, 0]
            for (index, direction) in directions.enumerated() {
                withAnimation(.spring(duration: 0.20, bounce: 0.24)) {
                    reactionAmount = direction == 0 ? 0.2 : (index.isMultiple(of: 2) ? 1 : 0.68)
                    reactionDirection = direction
                }
                try? await Task.sleep(for: .milliseconds(135))
                guard !Task.isCancelled else { return }
            }
        }
    }
}

/// A scoped loop for genuine accomplishment states. It pauses off-screen and
/// resolves to a still delighted pose when Reduce Motion is enabled.
struct MugsyCelebrationLoopView: View {
    var configuration = MugsyModelConfiguration(expression: .delighted)
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    private var effectiveReduceMotion: Bool { reduceMotionOverride ?? reduceMotion }
    private var pausesTimeline: Bool { isPaused || effectiveReduceMotion || scenePhase != .active }

    private func danceConfiguration(
        bendProgress: CGFloat,
        weightShift: CGFloat
    ) -> MugsyModelConfiguration {
        var result = configuration
        result.expression = .delighted
        result.armPose = .presenting
        result.legArticulation = MugsyLegArticulation(
            bendProgress: bendProgress,
            weightShift: weightShift
        )
        result.gaze = UnitPoint(
            x: 0.5 + weightShift * bendProgress * 0.12,
            y: 0.36
        )
        result.liquid.steamIntensity = max(result.liquid.steamIntensity, 0.62)
        return result
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: pausesTimeline)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let beat = elapsed * .pi * 1.5
            let pulse = effectiveReduceMotion ? 0 : CGFloat(abs(sin(beat)))
            let weightShift = effectiveReduceMotion ? 0 : CGFloat(sin(beat))
            let bendProgress = effectiveReduceMotion ? 0 : 0.16 + pulse * 0.84

            MugsyModelView(
                configuration: danceConfiguration(
                    bendProgress: bendProgress,
                    weightShift: weightShift
                )
            )
        }
        .onAppear { startedAt = Date() }
    }
}

#Preview("Mugsy action states") {
    ScrollView(.horizontal) {
        HStack(alignment: .bottom, spacing: 22) {
            MugsyAnimatedPreviewSpecimen(title: "Pull", action: .pulling(progress: 0.72))
            MugsyAnimatedPreviewSpecimen(title: "Refresh", action: .refreshing)
            MugsyAnimatedPreviewSpecimen(
                title: "Camera",
                configuration: MugsyPlacement.camera.configuration,
                action: .capturing
            )
            MugsyAnimatedPreviewSpecimen(title: "Success", action: .success)
            VStack(spacing: 6) {
                MugsyCelebrationLoopView()
                    .frame(width: 120, height: 120)
                Text("Dance")
                    .font(.caption.weight(.semibold))
            }
        }
        .padding()
    }
    .background(Color.creamWhite)
    .environment(\.mugshotReduceMotionOverride, true)
}

private struct MugsyAnimatedPreviewSpecimen: View {
    let title: String
    var configuration = MugsyModelConfiguration()
    let action: MugsyActionState

    var body: some View {
        VStack(spacing: 6) {
            MugsyAnimatedView(configuration: configuration, action: action)
                .frame(width: 120, height: 120)
            Text(title)
                .font(.caption.weight(.semibold))
        }
    }
}
