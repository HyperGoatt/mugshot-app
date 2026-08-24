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
    static let totalSteps = 10
}

enum MugshotSignedInOnboardingGate {
    static func requiresPresentation(
        isSignedIn: Bool,
        shouldOfferCapturePreferences: Bool,
        hasPendingGuestSavedCafes: Bool,
        hasAuthenticationPrompt: Bool,
        isGuestSavedMergePresented: Bool,
        isProductTourActive: Bool
    ) -> Bool {
        isSignedIn
            && shouldOfferCapturePreferences
            && !hasPendingGuestSavedCafes
            && !hasAuthenticationPrompt
            && !isGuestSavedMergePresented
            && !isProductTourActive
    }
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
    @State private var hasChosenGoal = false
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
                configuration: MugsySceneFamily.playfulWavingMugsy.configuration,
                action: .entering,
                height: 258,
                backdropOpacity: 0.44,
                speech: "I’ll help you remember the sip, the cafe, and the little moment."
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
                height: 274,
                backdropOpacity: 0.72,
                speech: "Each rating becomes a pin—then your whole coffee world comes into view."
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
                configuration: hasChosenGoal
                    ? MugsySceneFamily.excitedFirstSipCelebration.configuration
                    : MugsySceneFamily.joyfulJournalKeeper.configuration,
                action: hasChosenGoal ? .celebrating : .focusing,
                height: 144,
                backdropOpacity: 0.38,
                speech: hasChosenGoal
                    ? "Perfect. I’ll start there—and show you the rest."
                    : "What should we make easiest first?"
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
            withAnimation(effectiveReduceMotion ? nil : MugshotMotion.character) {
                selectedGoal = goal
                hasChosenGoal = true
            }
            MugshotHaptic.success.play()
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
    let speech: String

    var body: some View {
        Image("V3TastePassportBackdrop")
            .resizable()
            .scaledToFill()
            .opacity(backdropOpacity)
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: -12) {
                    MugsyAnimatedView(
                        configuration: configuration,
                        action: action,
                        tapBehavior: .playfulCycle
                    )
                    .frame(width: min(height * 0.62, 158), height: min(height * 0.62, 158))
                    .accessibilityHidden(true)

                    Text(speech)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 188, alignment: .leading)
                        .background(Color.foamWhite.opacity(0.96))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.mugshotLine, lineWidth: 1)
                        }
                        .shadow(color: Color.espressoBrown.opacity(0.10), radius: 10, y: 4)
                        .padding(.bottom, 28)
                        .accessibilityLabel("Mugsy says: \(speech)")
                }
                .padding(.horizontal, 14)
            }
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
    case shareImport

    var id: Int { rawValue }
    var number: Int { rawValue + 4 }

    var tabIndex: Int {
        switch self {
        case .map: 0
        case .feed: 1
        case .saved: 3
        case .journal: 4
        case .shareImport: 0
        }
    }

    var label: String {
        switch self {
        case .map: "YOUR COFFEE MAP"
        case .feed: "THE FEED"
        case .saved: "YOUR CAFE LIBRARY"
        case .journal: "YOUR JOURNAL"
        case .shareImport: "A SHORTCUT YOU’LL LOVE"
        }
    }

    var message: String {
        switch self {
        case .map: "Every cafe you rate becomes a pin. Zoom out and watch your whole coffee world come into view."
        case .feed: "Your Mix brings the sips most relevant to you forward. Switch to Friends for the intimate view."
        case .saved: "Favorites, Want to Try, and Lists keep every cafe plan in one place."
        case .journal: "Every sip, private note, recipe, and Taste Passport signal comes home here."
        case .shareImport: "In Google Maps, tap Share, choose Mugshot, and save the cafe straight to Want to Try."
        }
    }

    var scene: MugsySceneFamily {
        switch self {
        case .map: .cheerfulCafeScout
        case .feed: .welcomingFriendsPhone
        case .saved: .delightedWishlistHolder
        case .journal: .joyfulJournalKeeper
        case .shareImport: .playfulWavingMugsy
        }
    }

    var action: MugsyActionState {
        switch self {
        case .map: .entering
        case .feed: .focusing
        case .saved: .saving
        case .journal: .composing(progress: 0.72)
        case .shareImport: .celebrating
        }
    }

    var overlayAlignment: Alignment {
        switch self {
        case .map, .saved, .shareImport: .bottomLeading
        case .feed, .journal: .bottomTrailing
        }
    }

    var referenceImageName: String? {
        switch self {
        case .map: "OnboardingMapTour"
        case .feed: "OnboardingFeedTour"
        case .saved: "OnboardingSavedTour"
        case .journal: nil
        case .shareImport: "GoogleMapsShareOnboarding"
        }
    }

    var referenceAccessibilityLabel: String? {
        switch self {
        case .map: "Mugshot map filled with seven rated cafe pins"
        case .feed: "Mugshot feed showing an iced pistachio latte at Nook Tiny Cafe and Market"
        case .saved: "Mugshot Saved library showing cafes, favorites, and Want to Try controls"
        case .journal: nil
        case .shareImport: "Google Maps share sheet with Mugshot in the app row"
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
            if let referenceImageName = step.referenceImageName {
                Image(referenceImageName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .accessibilityLabel(step.referenceAccessibilityLabel ?? "Mugshot product tour")
            }

            if step == .map {
                mapPrivacyCover
            }

            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            coachConversation
                .id(step)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: step.overlayAlignment)
                .padding(.horizontal, 12)
                .padding(.bottom, step == .shareImport ? 24 : 104)
                .transition(cardTransition)
        }
        .animation(effectiveReduceMotion ? nil : MugshotMotion.reveal, value: step)
    }

    private var mapPrivacyCover: some View {
        GeometryReader { proxy in
            ZStack {
                Color.foamWhite.opacity(0.98)
                    .frame(height: 54)
                    .position(x: proxy.size.width / 2, y: 27)
                    .accessibilityHidden(true)

                Label("Location hidden", systemImage: "lock.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.espressoBrown)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.foamWhite.opacity(0.97), in: Capsule())
                    .overlay(Capsule().stroke(Color.mugshotLine, lineWidth: 1))
                    .shadow(color: Color.espressoBrown.opacity(0.14), radius: 10, y: 4)
                    .position(x: proxy.size.width * 0.424, y: proxy.size.height * 0.421)
                    .accessibilityLabel("Your precise location is hidden during this tour")
            }
        }
        .ignoresSafeArea()
    }

    private var cardTransition: AnyTransition {
        guard !effectiveReduceMotion else { return .opacity }
        return .move(edge: step == .feed || step == .journal ? .trailing : .leading)
            .combined(with: .opacity)
    }

    private var coachConversation: some View {
        HStack(alignment: .bottom, spacing: -10) {
            if step == .feed || step == .journal {
                speechBubble
                canonicalMugsy
            } else {
                canonicalMugsy
                speechBubble
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var canonicalMugsy: some View {
        MugsyAnimatedView(
            configuration: step.scene.configuration,
            action: step.action,
            tapBehavior: .playfulCycle
        )
        .frame(width: 88, height: 88)
        .accessibilityHidden(true)
        .zIndex(1)
    }

    private var speechBubble: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 6) {
                Text("\(step.number) OF \(MugshotOnboardingPlan.totalSteps) · \(step.label)")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.50)
                    .foregroundColor(.mugshotSageText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)

                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .frame(width: 28, height: 28)
                        .background(Color.sandBeige.opacity(0.70), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityLabel("Skip tour")
                .accessibilityIdentifier("mugshot.productTour.skip")
            }

            if step == .map {
                Text("7 cafes · 3.6 average")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.mugshotSageText)
            }

            Text(step.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Label(errorMessage, systemImage: "wifi.exclamationmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.roastBrown)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if step == .shareImport {
                Button(action: onStartFirstSip) {
                    HStack(spacing: 7) {
                        if isWorking { ProgressView().tint(.foamWhite) }
                        Text("Log my first sip")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.foamWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.mugshotSage, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityIdentifier("mugshot.productTour.startFirstSip")

                Button("I’ll do this later", action: onLater)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.mugshotSageText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 32)
                    .disabled(isWorking)
                    .accessibilityIdentifier("mugshot.productTour.later")
            } else {
                HStack(spacing: 8) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .frame(width: 40, height: 40)
                            .background(Color.sandBeige.opacity(0.70), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous tour step")
                    .accessibilityIdentifier("mugshot.productTour.back")

                    Button(action: onNext) {
                        HStack(spacing: 6) {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.foamWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.mugshotSage, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mugshot.productTour.next")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 270, alignment: .leading)
        .background(Color.foamWhite.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .shadow(color: Color.espressoBrown.opacity(0.18), radius: 16, y: 7)
        .accessibilityLabel("Mugsy says: \(step.message)")
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
        HStack(alignment: .bottom, spacing: -9) {
            if characterOnTrailingEdge {
                speechBubble
                canonicalMugsy
            } else {
                canonicalMugsy
                speechBubble
            }
        }
        .frame(maxWidth: .infinity, alignment: characterOnTrailingEdge ? .trailing : .leading)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mugshot.firstSipGuide.\(step.rawValue)")
    }

    private var canonicalMugsy: some View {
        MugsyAnimatedView(
            configuration: scene.configuration,
            action: action,
            tapBehavior: .playfulCycle
        )
        .frame(width: 74, height: 74)
        .accessibilityHidden(true)
        .zIndex(1)
    }

    private var speechBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                Text("MUGSY · \(stepNumber) OF 4")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(.mugshotSageText)

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .frame(width: 28, height: 28)
                        .background(Color.sandBeige.opacity(0.70), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop first sip tips")
            }

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 272, alignment: .leading)
        .background(Color.foamWhite.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.mugshotSage.opacity(0.55), lineWidth: 1.25)
        }
        .shadow(color: Color.espressoBrown.opacity(0.14), radius: 13, y: 5)
        .accessibilityLabel("Mugsy says: \(title). \(message)")
    }

    private var characterOnTrailingEdge: Bool {
        step == .sip || step == .publish
    }

    private var action: MugsyActionState {
        switch step {
        case .setup: .capturing
        case .sip: .focusing
        case .context: .pulling(progress: 0.64)
        case .publish: .success
        }
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
        case .setup: "Choose the scene, add the photos you love, then pick the cafe."
        case .sip: "Name the drink and rate how it felt to you—there’s no expert answer to match."
        case .context: "Rate the setting separately so a great drink and a great room stay distinct."
        case .publish: "Private is the safe starting point. Share only when you want to."
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

// MARK: - First-launch education

enum MugshotFirstLaunchPolicy {
    static let completedKey = "MugshotActivation.firstLaunchEducation.v1.completed"
    static let landingTabKey = "MugshotActivation.firstLaunchEducation.v1.landingTab"
}

enum MugshotFirstLaunchStep: Int, CaseIterable, Identifiable {
    case welcome
    case map
    case feed
    case friends
    case saved
    case journal
    case tastePassport
    case googleMaps
    case add

    var id: Int { rawValue }
    var number: Int { rawValue + 1 }

    var artworkName: String {
        switch self {
        case .welcome: "OnboardingMarketing01Capture"
        case .map: "OnboardingMarketing02Map"
        case .feed: "OnboardingMarketing03Feed"
        case .friends: "OnboardingMarketing04Friends"
        case .saved: "OnboardingMarketing05Saved"
        case .journal: "OnboardingMarketing06Journal"
        case .tastePassport: "OnboardingMarketing07TastePassport"
        case .googleMaps: "OnboardingMarketing08GoogleMaps"
        case .add: "OnboardingMarketing09Account"
        }
    }

    var title: String {
        switch self {
        case .welcome: "Capture Every Sip"
        case .map: "Watch your world take shape."
        case .feed: "Share the sip, not the performance."
        case .friends: "Your people. Your pace. Your privacy."
        case .saved: "Never forget the cafe you meant to try."
        case .journal: "A memory, not just a rating."
        case .tastePassport: "Your taste has a story."
        case .googleMaps: "Found it on Maps? Keep it in Mugshot."
        case .add: "Ready to remember your first sip?"
        }
    }

    var message: String {
        switch self {
        case .welcome:
            "Coffee, matcha, tea, and everything between. Mugsy keeps the little moments that would otherwise disappear."
        case .map:
            "Every sip becomes a pin—and every pin brings the memory back."
        case .feed:
            "The people you care about—and the drinks actually worth talking about."
        case .friends:
            "Friendship is mutual. Share with close friends, keep it private, or open it to everyone. Private is owner-only, Friends means confirmed mutual friends, and Everyone is public."
        case .saved:
            "Favorites, Want to Try, and Lists keep the next plan one tap away."
        case .journal:
            "Keep the photo, the feeling, the recipe, and the details you would otherwise forget."
        case .tastePassport:
            "Mugshot finds the patterns in your memories—and turns them into a Taste Passport that keeps getting more personal."
        case .googleMaps:
            "Share any cafe from Google Maps straight to Want to Try—before you forget it."
        case .add:
            "Create your account, make your profile yours, and Mugsy will meet you right here. Your private memories stay private."
        }
    }

    var isAuthenticationStep: Bool { self == .add }
}

struct MugshotFirstLaunchOnboardingView: View {
    let onCreateAccount: (Int) -> Void
    let onSignIn: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: MugshotFirstLaunchStep = .welcome

    var body: some View {
        MugshotFirstLaunchArtworkView(
            step: step,
            onContinue: advance,
            onSkipToAccountSetup: skipToAccountSetup,
            onCreateAccount: { onCreateAccount(landingTab) },
            onSignIn: { onSignIn(landingTab) }
        )
        .id(step)
        .transition(reduceMotion ? .identity : .opacity)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .interactiveDismissDisabled(true)
    }

    private var landingTab: Int {
        2
    }

    private func advance() {
        guard let next = MugshotFirstLaunchStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(reduceMotion ? nil : MugshotMotion.reveal) { step = next }
        MugshotHaptic.selection.play()
    }

    private func skipToAccountSetup() {
        withAnimation(reduceMotion ? nil : MugshotMotion.reveal) { step = .add }
        MugshotHaptic.selection.play()
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
