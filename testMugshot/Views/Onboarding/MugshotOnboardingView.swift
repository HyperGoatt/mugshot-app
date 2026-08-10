import SwiftUI

enum MugshotGuestIntroductionPolicy {
    static let storageKey = "MugshotActivation.guestIntroduction.v1.seen"

    static func shouldPresent(
        hasSeen: Bool,
        hasAuthenticatedNavigation: Bool,
        isUITesting: Bool
    ) -> Bool {
        !hasSeen && !hasAuthenticatedNavigation && !isUITesting
    }
}

struct MugsyGuestIntroductionView: View {
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MugsyAnimatedView(
                        configuration: MugsyPlacement.onboarding.configuration,
                        action: .entering,
                        tapBehavior: MugsyPlacement.onboarding.tapBehavior
                    )
                    .frame(width: 132, height: 132)
                    .accessibilityHidden(true)

                    VStack(spacing: 7) {
                        Text("A sip is a tiny time capsule")
                            .mugshotDisplay(size: 31)
                            .foregroundColor(.espressoBrown)
                            .multilineTextAlignment(.center)

                        Text("Mugsy will help you notice the drink and the moment while they are still in front of you.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        GuestIntroductionRow(
                            icon: "sparkles",
                            title: "Your reaction is the score",
                            detail: "A Mugshot score records your own memory—not an objective grade for a cafe."
                        )
                        Divider().padding(.leading, 54)
                        GuestIntroductionRow(
                            icon: "lock.shield.fill",
                            title: "You choose what leaves the journal",
                            detail: "Private notes stay private. Posts, recipes, and your Taste Passport each have their own audience."
                        )
                        Divider().padding(.leading, 54)
                        GuestIntroductionRow(
                            icon: "mappin.and.ellipse",
                            title: "Your footprint grows one sip at a time",
                            detail: "Log your first cafe sip and that place begins to carry your memories across Map and Journal."
                        )
                    }
                    .cardStyle(radius: DesignSystem.Radius.heroCard)

                    Text("Explore Map and save cafes without an account. Sign in only when you are ready to keep a sip or join friends.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Explore the Map", action: onContinue)
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityHint("Dismisses this introduction and leaves you on the Map")
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 34)
            }
            .background(Color.creamWhite)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onContinue)
                        .accessibilityLabel("Close introduction")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct GuestIntroductionRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .frame(width: 34, height: 34)
                .background(Color.mugshotMint.opacity(0.22))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Signed-in onboarding introduction

enum MugshotOnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case map
    case personalize

    var id: Int { rawValue }
    var number: Int { rawValue + 1 }

    var primaryActionTitle: String {
        switch self {
        case .welcome: "Make it mine"
        case .map: "Show me how"
        case .personalize: "Tour the app"
        }
    }
}

enum MugshotOnboardingPlan {
    static let totalSteps = 8
}

struct MugshotSignedInOnboardingView: View {
    let initialGoal: CapturePreferenceGoal
    let initialStep: MugshotOnboardingStep
    let onStarted: () -> Void
    let onBeginTour: (CapturePreferenceGoal) -> Void
    let onSkip: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride
    @State private var step: MugshotOnboardingStep
    @State private var selectedGoal: CapturePreferenceGoal
    @State private var completedStepNumbers: Set<Int> = []
    @State private var hasStarted = false
    @State private var hasFinished = false
    @State private var isCompleting = false

    private var effectiveReduceMotion: Bool { reduceMotionOverride ?? reduceMotion }

    init(
        initialGoal: CapturePreferenceGoal,
        initialStep: MugshotOnboardingStep = .welcome,
        onStarted: @escaping () -> Void = {},
        onBeginTour: @escaping (CapturePreferenceGoal) -> Void,
        onSkip: @escaping () async -> Void
    ) {
        self.initialGoal = initialGoal
        self.initialStep = initialStep
        self.onStarted = onStarted
        self.onBeginTour = onBeginTour
        self.onSkip = onSkip
        _step = State(initialValue: initialStep)
        _selectedGoal = State(initialValue: initialGoal)
    }

    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 1).id("onboarding-top")
                        progressHeader
                        currentStepContent
                            .id(step)
                            .transition(stepTransition)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .onChange(of: step) { _, _ in
                    withAnimation(effectiveReduceMotion ? nil : MugshotMotion.reveal) {
                        proxy.scrollTo("onboarding-top", anchor: .top)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .interactiveDismissDisabled(true)
        .onAppear(perform: startAnalyticsIfNeeded)
        .onDisappear {
            guard hasStarted, !hasFinished else { return }
            MugshotAnalytics.shared.capture(
                .onboardingAbandoned(
                    step: step.number,
                    totalSteps: MugshotOnboardingPlan.totalSteps
                )
            )
        }
    }

    private var stepTransition: AnyTransition {
        guard !effectiveReduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                if step != .welcome {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .frame(width: 44, height: 44)
                            .background(Color.foamWhite, in: Circle())
                            .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer()
                Text("\(step.number) of \(MugshotOnboardingPlan.totalSteps)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondaryText)
                    .accessibilityLabel("Step \(step.number) of \(MugshotOnboardingPlan.totalSteps)")
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }

            OnboardingProgressTrack(currentStep: step.number)
        }
        .padding(.top, 6)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .map: mapStep
        case .personalize: personalizationStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 22) {
            MugshotOnboardingHero(
                configuration: MugsySceneFamily.joyfulJournalKeeper.configuration,
                action: .entering,
                height: 300,
                backdropOpacity: 0.36
            )

            VStack(spacing: 12) {
                Text("Capture Every Sip")
                    .mugshotDisplay(size: 40)
                    .foregroundColor(.espressoBrown)
                    .multilineTextAlignment(.center)
                Text("The drink. The place. The little moment around it. Mugshot helps you remember it all.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            onboardingTrustBanner(icon: "lock.fill", message: "Private by default · Yours to shape")
        }
    }

    private var mapStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            MugshotOnboardingHero(
                configuration: MugsySceneFamily.cheerfulCafeScout.configuration,
                action: .entering,
                height: 320,
                backdropOpacity: 0.68
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Every sip leaves a little map")
                    .mugshotDisplay(size: 39)
                    .foregroundColor(.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Mugsy helps turn the drinks you notice into memories, places to return to, and a Taste Passport that grows with you.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            onboardingTrustBanner(icon: "lock.fill", message: "Your first Mugshot starts Private")
        }
    }

    private var personalizationStep: some View {
        VStack(spacing: 20) {
            MugshotOnboardingHero(
                configuration: MugsySceneFamily.joyfulJournalKeeper.configuration,
                action: .focusing,
                height: 230,
                backdropOpacity: 0.32
            )

            VStack(spacing: 8) {
                Text("Let’s make Mugshot yours")
                    .mugshotDisplay(size: 36)
                    .foregroundColor(.espressoBrown)
                    .multilineTextAlignment(.center)
                Text("What would feel most useful right now?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ForEach(CapturePreferenceGoal.allCases) { goal in goalRow(goal) }
            }

            Text("We’ll start with \(selectedGoal.title). You’ll still see every core feature, and you can change this anytime in Settings.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func goalRow(_ goal: CapturePreferenceGoal) -> some View {
        let isSelected = selectedGoal == goal
        return Button {
            selectedGoal = goal
            MugshotHaptic.selection.play()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: goal.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.mugshotSageText)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                Text(goal.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? .mugshotSage : .mugshotLine)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(isSelected ? Color.mugshotMint.opacity(0.20) : Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .stroke(isSelected ? Color.mugshotSage : Color.mugshotLine, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mugshot.onboarding.goal.\(goal.rawValue)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func onboardingTrustBanner(icon: String, message: String) -> some View {
        Label(message, systemImage: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.espressoBrown)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(Color.sandBeige.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button(action: advance) {
                HStack(spacing: 10) {
                    if isCompleting { ProgressView().tint(.foamWhite) }
                    Text(step.primaryActionTitle)
                    if step != .welcome { Image(systemName: "arrow.right") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isCompleting)
            .accessibilityIdentifier("mugshot.onboarding.primary")

            Button("Skip tour", action: skip)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.mugshotSageText)
                .frame(minHeight: 44)
                .disabled(isCompleting)
                .accessibilityIdentifier("mugshot.onboarding.skip")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.creamWhite.opacity(0.98))
        .overlay(alignment: .top) { Divider().opacity(0.45) }
    }

    private func goBack() {
        guard let previous = MugshotOnboardingStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(effectiveReduceMotion ? nil : MugshotMotion.reveal) { step = previous }
        MugshotHaptic.selection.play()
    }

    private func advance() {
        guard !isCompleting else { return }
        recordStepCompletion(step.number)
        if step == .personalize {
            hasFinished = true
            MugshotHaptic.selection.play()
            onBeginTour(selectedGoal)
            return
        }
        guard let next = MugshotOnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(effectiveReduceMotion ? nil : MugshotMotion.reveal) { step = next }
        MugshotHaptic.selection.play()
    }

    private func skip() {
        guard !isCompleting else { return }
        isCompleting = true
        hasFinished = true
        Task {
            await onSkip()
            isCompleting = false
            MugshotAnalytics.shared.capture(
                .onboardingSkipped(step: step.number, totalSteps: MugshotOnboardingPlan.totalSteps)
            )
            MugshotAnalytics.shared.capture(.capturePreferencesSkipped)
        }
    }

    private func recordStepCompletion(_ number: Int) {
        guard completedStepNumbers.insert(number).inserted else { return }
        MugshotAnalytics.shared.capture(
            .onboardingStepCompleted(step: number, totalSteps: MugshotOnboardingPlan.totalSteps)
        )
    }

    private func startAnalyticsIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        onStarted()
        if initialStep == .welcome {
            MugshotAnalytics.shared.capture(.onboardingStarted)
            MugshotAnalytics.shared.capture(.capturePreferencesViewed(allowsSkipping: true))
            MugshotAnalytics.shared.capture(.screenViewed(.capturePreferences, source: .sheet))
        }
    }
}

private struct OnboardingProgressTrack: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...MugshotOnboardingPlan.totalSteps, id: \.self) { number in
                Capsule()
                    .fill(number <= currentStep ? Color.mugshotSage : Color.mugshotLine)
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
            }
        }
        .animation(DesignSystem.Motion.base, value: currentStep)
        .accessibilityHidden(true)
    }
}

private struct MugshotOnboardingHero: View {
    let configuration: MugsyModelConfiguration
    let action: MugsyActionState
    let height: CGFloat
    let backdropOpacity: Double

    var body: some View {
        ZStack {
            Image("V3TastePassportBackdrop")
                .resizable()
                .scaledToFill()
                .opacity(backdropOpacity)
                .accessibilityHidden(true)

            MugsyAnimatedView(
                configuration: configuration,
                action: action,
                tapBehavior: .playfulCycle
            )
            .frame(width: min(height * 0.72, 220), height: min(height * 0.72, 220))
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .background(Color.mugshotMint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
    }
}

// MARK: - Live product tour

enum MugshotProductTourStep: Int, CaseIterable, Identifiable {
    case map
    case feed
    case saved
    case journal
    case firstSip

    var id: Int { rawValue }
    var number: Int { rawValue + 4 }

    var tabIndex: Int {
        switch self {
        case .map: 0
        case .feed: 1
        case .saved: 3
        case .journal: 4
        case .firstSip: 2
        }
    }

    var eyebrow: String {
        switch self {
        case .map: "MAP · PINS + RANKINGS"
        case .feed: "FEED · YOUR MIX"
        case .saved: "SAVED · LISTS"
        case .journal: "JOURNAL · YOUR MEMORY"
        case .firstSip: "THE MAIN EVENT"
        }
    }

    var title: String {
        switch self {
        case .map: "Read your coffee world at a glance"
        case .feed: "See the sips worth noticing"
        case .saved: "Turn curiosity into a plan"
        case .journal: "Everything you log comes home here"
        case .firstSip: "Ready to capture your first sip?"
        }
    }

    var message: String {
        switch self {
        case .map:
            "Scores live right on the pins, and their colors reinforce the rating. Hearts, bookmarks, and friend badges show why a cafe matters to you. For You ranks nearby options and explains each match."
        case .feed:
            "Your Mix ranks the most relevant Mugshots first. Switch to Friends for people you follow or Everyone when you want to roam. Save a cafe straight from any post."
        case .saved:
            "Favorites are proven loves. Want to Try is your coffee queue. Lists organize a plan—and shared lists let friends build one together."
        case .journal:
            "This is your private record of drinks, places, notes, recipes, and people. Every new Mugshot also teaches your Taste Passport what feels like you."
        case .firstSip:
            "The fastest way to understand Mugshot is to make one. Mugsy can guide the real flow, one small decision at a time, and your first Mugshot starts Private."
        }
    }

    var callout: String {
        switch self {
        case .map: "Tap a pin to see the cafe and the reason behind it."
        case .feed: "Relevance first; endless scrolling is not the goal."
        case .saved: "Save now, decide where it belongs later."
        case .journal: "Private means private until you choose otherwise."
        case .firstSip: "About two minutes—and you can stop anytime."
        }
    }

    var scene: MugsySceneFamily {
        switch self {
        case .map: .cheerfulCafeScout
        case .feed: .welcomingFriendsPhone
        case .saved: .delightedWishlistHolder
        case .journal: .joyfulJournalKeeper
        case .firstSip: .proudCameraCompanion
        }
    }

    var cardAtTop: Bool {
        switch self {
        case .journal: true
        case .map, .feed, .saved, .firstSip: false
        }
    }
}

struct MugshotProductTourOverlay: View {
    let step: MugshotProductTourStep
    let isWorking: Bool
    let errorMessage: String?
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    let onStartFirstSip: () -> Void
    let onLater: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride

    private var effectiveReduceMotion: Bool { reduceMotionOverride ?? reduceMotion }

    var body: some View {
        ZStack {
            Color.espressoBrown.opacity(0.13)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            VStack(spacing: 0) {
                if !step.cardAtTop { Spacer(minLength: step == .firstSip ? 100 : 180) }
                coachCard
                    .id(step)
                    .transition(cardTransition)
                if step.cardAtTop { Spacer(minLength: 180) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 64)
            .padding(.bottom, step == .firstSip ? 28 : 104)
        }
        .animation(effectiveReduceMotion ? nil : MugshotMotion.reveal, value: step)
    }

    private var cardTransition: AnyTransition {
        guard !effectiveReduceMotion else { return .opacity }
        return .move(edge: step.cardAtTop ? .top : .bottom).combined(with: .opacity)
    }

    private var coachCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                MugsyAnimatedView(
                    configuration: step.scene.configuration,
                    action: step == .firstSip ? .celebrating : .entering,
                    tapBehavior: .playfulCycle
                )
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(step.eyebrow)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(0.7)
                        .foregroundColor(.mugshotSageText)
                    Text(step.title)
                        .mugshotDisplay(size: step == .firstSip ? 27 : 25)
                        .foregroundColor(.espressoBrown)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(step.message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Label(step.callout, systemImage: step == .firstSip ? "lock.fill" : "hand.tap.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.mugshotMint.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let errorMessage {
                Label(errorMessage, systemImage: "wifi.exclamationmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.roastBrown)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if step == .firstSip {
                Button(action: onStartFirstSip) {
                    HStack(spacing: 9) {
                        if isWorking { ProgressView().tint(.foamWhite) }
                        Text("Log my first sip")
                        Image(systemName: "plus.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)
                .accessibilityIdentifier("mugshot.productTour.startFirstSip")

                Button("I’ll do this later", action: onLater)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.mugshotSageText)
                    .frame(minHeight: 44)
                    .disabled(isWorking)
                    .accessibilityIdentifier("mugshot.productTour.later")
            } else {
                HStack(spacing: 10) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Previous tour step")
                    .accessibilityIdentifier("mugshot.productTour.back")

                    Button(action: onNext) {
                        HStack(spacing: 8) {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("mugshot.productTour.next")
                }

                Button("Skip tour", action: onSkip)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.mugshotSageText)
                    .frame(minHeight: 44)
                    .disabled(isWorking)
                    .accessibilityIdentifier("mugshot.productTour.skip")
            }
        }
        .padding(18)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .shadow(color: Color.espressoBrown.opacity(0.20), radius: 24, y: 10)
    }
}

// MARK: - First sip guidance

enum MugshotFirstSipGuideStore {
    private static let keyPrefix = "MugshotActivation.firstSipGuide.v1."

    static func isActive(accountID: UUID?) -> Bool {
        guard let accountID else { return false }
        return UserDefaults.standard.bool(forKey: keyPrefix + accountID.uuidString.lowercased())
    }

    static func setActive(_ active: Bool, accountID: UUID?) {
        guard let accountID else { return }
        UserDefaults.standard.set(active, forKey: keyPrefix + accountID.uuidString.lowercased())
    }
}

struct MugshotFirstSipGuideBanner: View {
    let step: SipV3ComposerStep
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MugsyAnimatedView(
                configuration: scene.configuration,
                action: .focusing,
                tapBehavior: .playfulCycle
            )
            .frame(width: 62, height: 62)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("MUGSY’S FIRST SIP TIP · \(stepNumber) OF 4")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(.mugshotSageText)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Color.sandBeige.opacity(0.7), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop first sip tips")
        }
        .padding(12)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotSage.opacity(0.55), lineWidth: 1.5)
        }
        .shadow(color: Color.espressoBrown.opacity(0.12), radius: 12, y: 5)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mugshot.firstSipGuide.\(step.rawValue)")
    }

    private var stepNumber: Int {
        switch step {
        case .setup: 1
        case .sip: 2
        case .context: 3
        case .publish: 4
        }
    }

    private var title: String {
        switch step {
        case .setup: "Start with the scene"
        case .sip: "Your reaction is the score"
        case .context: "The place gets its own memory"
        case .publish: "You decide who sees it"
        }
    }

    private var message: String {
        switch step {
        case .setup: "Choose Cafe, Home, or Elsewhere. A photo adds texture, but Private and Friends sips can stay text-only."
        case .sip: "Name the drink, then rate how it felt to you. There is no expert answer to match."
        case .context: "Rate the setting separately from the drink so a great latte and a great room do not blur together."
        case .publish: "Private is the safe starting point. Change the audience only when you want to share this Mugshot."
        }
    }

    private var scene: MugsySceneFamily {
        switch step {
        case .setup: .proudCameraCompanion
        case .sip: .cozyCoffeeRitual
        case .context: .cheerfulCafeScout
        case .publish: .joyfulJournalKeeper
        }
    }
}

extension CapturePreferenceGoal {
    var title: String {
        switch self {
        case .nearby: "Find nearby cafes"
        case .taste: "Understand my taste"
        case .journal: "Remember every sip"
        case .friends: "Follow friends’ finds"
        }
    }

    var systemImage: String {
        switch self {
        case .nearby: "mappin"
        case .taste: "leaf.fill"
        case .journal: "cup.and.saucer.fill"
        case .friends: "person.2.fill"
        }
    }
}

#if DEBUG
struct MugshotSignedInOnboardingPreviewHost: View {
    @State private var phase: PreviewPhase = .introduction
    @State private var introStep: MugshotOnboardingStep = .welcome
    @State private var goal: CapturePreferenceGoal = .nearby
    @State private var tourStep: MugshotProductTourStep = .map

    private enum PreviewPhase { case introduction, tour, finished }

    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            if phase == .tour {
                Image("V3TastePassportBackdrop")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                MugshotProductTourOverlay(
                    step: tourStep,
                    isWorking: false,
                    errorMessage: nil,
                    onNext: advanceTour,
                    onBack: goBackInTour,
                    onSkip: { phase = .finished },
                    onStartFirstSip: { phase = .finished },
                    onLater: { phase = .finished }
                )
            } else if phase == .finished {
                VStack(spacing: 14) {
                    MugsyCelebrationLoopView(
                        configuration: MugsySceneFamily.excitedFirstSipCelebration.configuration
                    )
                    .frame(width: 150, height: 150)
                    Text("Onboarding complete")
                        .mugshotDisplay(size: 28)
                        .foregroundColor(.espressoBrown)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { phase == .introduction },
            set: { if !$0, phase == .introduction { phase = .tour } }
        )) {
            MugshotSignedInOnboardingView(
                initialGoal: goal,
                initialStep: introStep,
                onBeginTour: { selectedGoal in
                    goal = selectedGoal
                    phase = .tour
                },
                onSkip: { phase = .finished }
            )
        }
    }

    private func advanceTour() {
        guard let next = MugshotProductTourStep(rawValue: tourStep.rawValue + 1) else { return }
        tourStep = next
    }

    private func goBackInTour() {
        guard let previous = MugshotProductTourStep(rawValue: tourStep.rawValue - 1) else {
            introStep = .personalize
            phase = .introduction
            return
        }
        tourStep = previous
    }
}
#endif
