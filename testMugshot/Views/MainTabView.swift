//
//  MainTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(MugshotGuestIntroductionPolicy.storageKey) private var hasSeenGuestIntroduction = false
    @StateObject private var tabCoordinator: TabCoordinator
    @StateObject private var mapLocationManager = LocationManager()
    @StateObject private var systemRouter = SipSystemRouter.shared
    @StateObject private var activityStore = ActivityCenterStore()
    @StateObject private var activityRouter = ActivityDeepLinkRouter.shared
    @StateObject private var nearbyReminderRouter = NearbyCafeReminderRouter.shared
    @StateObject private var enforcementStore = EnforcementNoticeStore()
    @StateObject private var automaticSipRecovery = AutomaticSipRecoveryCoordinator()
    @StateObject private var placeImportCoordinator = PendingPlaceImportCoordinator()
    @State private var composerDraft: SipDraft?
    @State private var composerSessionID = UUID()
    @State private var authenticationPrompt: AuthenticationPrompt?
    @State private var authenticationPromptAnalyticsSource: String?
    @State private var showsGuestSavedMerge = false
    @State private var showsSignedInOnboarding = false
    @State private var signedInOnboardingInitialStep: MugshotOnboardingStep = .welcome
    @State private var signedInOnboardingStartedAt: Date?
    @State private var productTourStep: MugshotProductTourStep?
    @State private var productTourGoal: CapturePreferenceGoal = .nearby
    @State private var completedProductTourSteps: Set<MugshotProductTourStep> = []
    @State private var isCompletingProductTour = false
    @State private var isGuidingFirstSip = false
    @State private var didPresentOnboardingDesignQA = false
    @State private var showsGuestIntroduction = false
    @State private var guestIntroductionStartedAt: Date?
    @State private var guestIntroductionCompleted = false
    @State private var showsActivityCenter = false
    @State private var lastReportedActivityRouteID: UUID?
    @State private var showsEnforcementCenter = false
    @State private var systemRouteError: String?
    @State private var sharedMugshotRoute: MugshotSharedLinkRoute?
    @State private var sharedProfileRoute: MugshotProfileSharedLinkRoute?
    @State private var publicCafeListRoute: PublicCafeListLinkRoute?
    @State private var nearbyReminderCafe: Cafe?
    @State private var isBottomNavHidden = false

    init(dataManager: DataManager, initialTab: Int = 0) {
        self.dataManager = dataManager
        _tabCoordinator = StateObject(wrappedValue: TabCoordinator(selectedTab: initialTab))
    }
    
    var body: some View {
        routedScene
    }

    private var coreScene: some View {
        ZStack(alignment: .bottom) {
            activeTab
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.creamWhite)

            if tabCoordinator.selectedTab != 2, !isBottomNavHidden {
                MugshotBottomNav(selectedTab: gatedTabSelection)
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let productTourStep {
                MugshotProductTourOverlay(
                    step: productTourStep,
                    isWorking: isCompletingProductTour,
                    errorMessage: authModel.capturePreferencesError,
                    onNext: advanceProductTour,
                    onBack: goBackInProductTour,
                    onSkip: skipProductTour,
                    onStartFirstSip: { completeProductTour(startsFirstSip: true) },
                    onLater: { completeProductTour(startsFirstSip: false) }
                )
                .zIndex(5)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if let sessionMessage {
                    SessionUnavailableBanner(message: sessionMessage) {
                        Task { await authModel.restoreSession(dataManager: dataManager) }
                    }
                }
                AutomaticSipRecoveryBanner(
                    state: automaticSipRecovery.state,
                    retry: automaticSipRecovery.retryNow
                )
                if let action = enforcementStore.primaryAction {
                    EnforcementStatusBanner(
                        action: action,
                        additionalActiveCount: max(enforcementStore.activeCount - 1, 0)
                    ) {
                        showsEnforcementCenter = true
                    }
                }
            }
        }
        .environmentObject(tabCoordinator)
        .onPreferenceChange(MugshotBottomNavHiddenPreferenceKey.self) { isHidden in
            withAnimation(DesignSystem.Motion.fast) {
                isBottomNavHidden = isHidden
            }
        }
        .tint(.mugshotSage)
        .background(Color.creamWhite.ignoresSafeArea())
        // The dock deliberately extends through the container safe area so it
        // sits with the home indicator instead of hovering a full safe-area
        // height above it.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var lifecycleScene: some View {
        coreScene
        .onAppear {
#if DEBUG
            if MugshotLaunchEnvironment.savedAuditScenario != nil {
                tabCoordinator.selectedTab = 3
            }
#endif
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.mugshotSage)
            activateLocalStorage()
            isGuidingFirstSip = MugshotFirstSipGuideStore.isActive(
                accountID: authModel.authenticatedUser?.id
            )
            automaticSipRecovery.activate(accountID: authModel.authenticatedUser?.id)
            automaticSipRecovery.setAppActive(scenePhase == .active)
            if !hasAuthenticatedNavigation,
               !Self.guestTabs.contains(tabCoordinator.selectedTab) {
                tabCoordinator.selectedTab = 0
            }
            handlePendingSystemRoute()
            synchronizeActivityRouter()
            handlePendingActivityRoute()
            scheduleGuestIntroductionIfNeeded()
            captureSelectedScreen()
            synchronizeMapLocationUpdates()
            NearbyCafeReminderCoordinator.shared.refresh(cafes: dataManager.appData.cafes)
            handlePendingNearbyReminder()
            presentOnboardingDesignQAIfNeeded()
            scheduleSignedInOnboardingIfNeeded()
            Task {
                await refreshShareExtensionListCache(
                    accountID: authModel.authenticatedUser?.id
                )
                await placeImportCoordinator.drain(
                    dataManager: dataManager,
                    accountID: authModel.authenticatedUser?.id
                )
            }
        }
        .onChange(of: tabCoordinator.selectedTab) { _, _ in
            captureSelectedScreen()
            synchronizeMapLocationUpdates()
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, userId in
            AccountBoundActivityUpdateSignal.shared.activate(
                accountID: nil,
                refresh: nil
            )
            if showsActivityCenter {
                showsActivityCenter = false
            }
            activateLocalStorage(scope: .forUserID(userId))
            automaticSipRecovery.activate(accountID: userId)
            if userId != nil {
                authenticationPrompt = nil
                showsGuestIntroduction = false
            } else if !hasAuthenticatedNavigation,
                      !Self.guestTabs.contains(tabCoordinator.selectedTab) {
                tabCoordinator.selectedTab = 0
            }
            if userId == nil {
                showsSignedInOnboarding = false
                productTourStep = nil
                isGuidingFirstSip = false
            } else {
                isGuidingFirstSip = MugshotFirstSipGuideStore.isActive(accountID: userId)
            }
            handlePendingSystemRoute()
            synchronizeActivityRouter()
            enforcementStore.prepare(accountID: userId)
            handlePendingActivityRoute()
            scheduleGuestIntroductionIfNeeded()
            scheduleSignedInOnboardingIfNeeded()
            Task {
                await refreshShareExtensionListCache(accountID: userId)
                await placeImportCoordinator.drain(
                    dataManager: dataManager,
                    accountID: userId
                )
            }
        }
        .onChange(of: dataManager.journalRevision) { _, _ in
            activateLocalStorage()
            NearbyCafeReminderCoordinator.shared.refresh(cafes: dataManager.appData.cafes)
        }
        .onChange(of: automaticSipRecovery.completionRevision) { _, _ in
            dataManager.noteJournalMutation()
        }
        .onChange(of: authModel.status) { _, _ in
            synchronizeActivityRouter()
            handlePendingSystemRoute()
            handlePendingActivityRoute()
            scheduleGuestIntroductionIfNeeded()
            scheduleSignedInOnboardingIfNeeded()
        }
        .onChange(of: systemRouter.pendingRoute?.id) { _, _ in
            handlePendingSystemRoute()
        }
        .onChange(of: activityRouter.pendingRoute?.id) { _, _ in
            handlePendingActivityRoute()
        }
        .onChange(of: nearbyReminderRouter.pendingCafeID) { _, _ in
            handlePendingNearbyReminder()
        }
        .onChange(of: scenePhase) { _, phase in
            automaticSipRecovery.setAppActive(phase == .active)
            synchronizeMapLocationUpdates()
            if phase == .active {
                NearbyCafeReminderCoordinator.shared.refresh(cafes: dataManager.appData.cafes)
                handlePendingNearbyReminder()
                scheduleSignedInOnboardingIfNeeded()
            }
            guard phase == .active else { return }
            let expectedAccountID = authModel.authenticatedUser?.id
            Task {
                // A share extension success is a durable promise. Always drain
                // its app-group queue, including Release builds where discovery
                // experiments may otherwise be disabled.
                await refreshShareExtensionListCache(accountID: expectedAccountID)
                await placeImportCoordinator.drain(
                    dataManager: dataManager,
                    accountID: expectedAccountID
                )
                guard let expectedAccountID else { return }
                guard !Task.isCancelled,
                      authModel.authenticatedUser?.id == expectedAccountID else { return }
                await activityStore.refresh()
                guard !Task.isCancelled,
                      authModel.authenticatedUser?.id == expectedAccountID else { return }
                await NotificationDeviceCoordinator.shared.refreshPermission()
                guard !Task.isCancelled,
                      authModel.authenticatedUser?.id == expectedAccountID else { return }
                await enforcementStore.refresh()
            }
        }
        .onChange(of: authModel.pendingGuestSavedCafes.count) { _, count in
            guard count > 0 else {
                scheduleSignedInOnboardingIfNeeded()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                guard authenticationPrompt == nil else { return }
                showsGuestSavedMerge = true
            }
        }
        .onChange(of: authModel.shouldOfferCapturePreferences) { _, shouldOffer in
            guard shouldOffer else { return }
            scheduleSignedInOnboardingIfNeeded()
        }
        .confirmationDialog(
            "Choose where to keep this cafe",
            isPresented: Binding(
                get: { placeImportCoordinator.recovery != nil },
                set: { if !$0 { placeImportCoordinator.dismissRecovery() } }
            ),
            presenting: placeImportCoordinator.recovery
        ) { recovery in
            Button("Keep in Want to Try") {
                Task {
                    await placeImportCoordinator.keepInWantToTry(
                        recovery.command,
                        dataManager: dataManager,
                        accountID: authModel.authenticatedUser?.id
                    )
                }
            }
            ForEach(Array(recovery.eligibleLists.prefix(5))) { list in
                Button("Add to \(list.title)") {
                    Task {
                        await placeImportCoordinator.retry(
                            recovery.command,
                            in: list,
                            dataManager: dataManager,
                            accountID: authModel.authenticatedUser?.id
                        )
                    }
                }
            }
            Button("Not now", role: .cancel) {
                placeImportCoordinator.dismissRecovery()
            }
        } message: { recovery in
            Text(
                "\(recovery.command.name) is saved to Want to Try, but \(recovery.command.destinationListTitle ?? "the selected list") is no longer writable."
            )
        }
    }

    private var presentedScene: some View {
        lifecycleScene
        .sheet(item: $authenticationPrompt, onDismiss: handleAuthenticationPromptDismissed) { prompt in
            AuthEntryView(
                dataManager: dataManager,
                contextTitle: prompt.title,
                contextMessage: prompt.message,
                showsCloseButton: true
            )
            .environmentObject(authModel)
        }
        .sheet(isPresented: $showsGuestIntroduction, onDismiss: handleGuestIntroductionDismissed) {
            MugsyGuestIntroductionView(onContinue: completeGuestIntroduction)
        }
        .sheet(isPresented: $showsGuestSavedMerge, onDismiss: scheduleSignedInOnboardingIfNeeded) {
            GuestSavedMergeView(dataManager: dataManager)
                .environmentObject(authModel)
                .interactiveDismissDisabled(authModel.isMergingGuestSaved)
        }
        .fullScreenCover(isPresented: signedInOnboardingPresentation) {
            MugshotSignedInOnboardingView(
                initialGoal: authModel.capturePreferences.onboardingGoal ?? productTourGoal,
                initialStep: signedInOnboardingInitialStep,
                onStarted: {
                    if signedInOnboardingStartedAt == nil {
                        signedInOnboardingStartedAt = .now
                    }
                },
                onBeginTour: beginProductTour,
                onSkip: {
                    await skipSignedInOnboarding()
                }
            )
        }
        .sheet(isPresented: $showsActivityCenter) {
            if let accountID = authModel.authenticatedUser?.id {
                ActivityCenterView(
                    store: activityStore,
                    router: activityRouter,
                    dataManager: dataManager,
                    accountID: accountID,
                    onLogSipRequested: {
                        withAnimation(DesignSystem.Motion.base) {
                            tabCoordinator.selectedTab = 2
                        }
                    },
                    onExploreMapRequested: {
                        withAnimation(DesignSystem.Motion.base) {
                            tabCoordinator.selectedTab = 0
                        }
                    }
                )
                .environmentObject(authModel)
            } else {
                NavigationStack {
                    ContentUnavailableView(
                        "Session changed",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Sign in again to view activity for your account.")
                    )
                    .navigationTitle("Activity")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Close") { showsActivityCenter = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showsEnforcementCenter, onDismiss: {
            Task { await enforcementStore.refresh() }
        }) {
            NavigationStack {
                EnforcementCenterView()
                    .environmentObject(authModel)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsEnforcementCenter = false }
                        }
                    }
            }
        }
        .sheet(isPresented: Binding(
            get: { authModel.requiresNewPassword },
            set: { _ in }
        )) {
            PasswordRecoveryView(dataManager: dataManager)
                .environmentObject(authModel)
        }
        .sheet(item: $sharedMugshotRoute) { route in
            NavigationStack {
                CanonicalMugshotLinkRouteView(
                    route: route,
                    currentUserID: authModel.authenticatedUser?.id,
                    dataManager: dataManager
                )
            }
        }
        .sheet(item: $sharedProfileRoute) { route in
            NavigationStack {
                SharedProfileView(
                    source: .share(slug: route.slug),
                    dataManager: dataManager
                )
                .environmentObject(authModel)
            }
        }
        .sheet(item: $publicCafeListRoute) { route in
            NavigationStack {
                PublicCafeListLinkView(
                    route: route,
                    dataManager: dataManager,
                    currentUserID: authModel.authenticatedUser?.id
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { publicCafeListRoute = nil }
                    }
                }
            }
            .environmentObject(authModel)
            .presentationDetents([.large])
        }
        .sheet(item: $nearbyReminderCafe) { cafe in
            CafeDetailView(
                cafe: cafe,
                dataManager: dataManager,
                discoverySource: .nearbyReminder,
                onLogVisitRequested: beginCafeSip,
                onAuthenticationRequired: requestAuthentication
            )
            .environmentObject(authModel)
        }
    }

    private var routedScene: some View {
        presentedScene
        .alert("Couldn’t open that shortcut", isPresented: Binding(
            get: { systemRouteError != nil },
            set: { if !$0 { systemRouteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(systemRouteError ?? "Please try again.")
        }
        .onOpenURL { url in
            if MugshotAuthCallbackRoute.resolve(url) != nil {
                // The always-mounted root queues auth callbacks until session
                // restoration finishes and consumes each one-time URL once.
                return
            } else if let route = MugshotSharedLinkRoute.resolve(url) {
                sharedMugshotRoute = route
            } else if let route = MugshotProfileSharedLinkRoute.resolve(url) {
                sharedProfileRoute = route
            } else if let route = PublicCafeListLinkRoute.resolve(url) {
                publicCafeListRoute = route
            } else if let accountID = authModel.authenticatedUser?.id,
                      activityRouter.enqueue(
                          url: url,
                          accountID: accountID,
                          source: .deepLink
                      ) {
                MugshotAnalytics.shared.capture(.activityOpened(source: .deepLink))
                handlePendingActivityRoute()
            } else {
                systemRouter.enqueue(url: url)
            }
        }
        .task(id: authModel.authenticatedUser?.id) {
            let userId = authModel.authenticatedUser?.id
            synchronizeActivityRouter()
            await activityStore.activate(accountID: userId)
            guard !Task.isCancelled,
                  authModel.authenticatedUser?.id == userId else { return }
            AccountBoundActivityUpdateSignal.shared.activate(
                accountID: userId,
                activationAlreadyRefreshed: userId != nil,
                refresh: userId == nil ? nil : {
                    await activityStore.refresh()
                }
            )
            await NotificationDeviceCoordinator.shared.activate(accountID: userId)
            guard !Task.isCancelled,
                  authModel.authenticatedUser?.id == userId else { return }
            await enforcementStore.activate(accountID: userId)
            guard !Task.isCancelled,
                  authModel.authenticatedUser?.id == userId else { return }
            handlePendingActivityRoute()

            guard let userId,
                  let client = try? SupabaseClientProvider.shared.client() else { return }
            if let clearedCount = try? await CafeStateService(client: client)
                .reconcileVisitedWantToTry(userId: userId),
               clearedCount > 0 {
                guard !Task.isCancelled,
                      authModel.authenticatedUser?.id == userId else { return }
                dataManager.noteJournalMutation()
            }
            guard !Task.isCancelled,
                  authModel.authenticatedUser?.id == userId else { return }
            await VisitDeletionService(client: client).retryPendingMediaCleanup(userId: userId)
            guard !Task.isCancelled,
                  authModel.authenticatedUser?.id == userId else { return }
            await DrinkAnalysisService(client: client).retryPendingAnalyses(userId: userId)
        }
    }

    @ViewBuilder
    private var activeTab: some View {
        switch tabCoordinator.selectedTab {
        case 0:
            MapTabView(
                dataManager: dataManager,
                locationManager: mapLocationManager,
                hidesUserLocation: productTourStep == .map,
                onLogVisitRequested: beginCafeSip,
                onAuthenticationRequired: requestAuthentication
            )
        case 1:
            FeedTabView(
                dataManager: dataManager,
                onLogVisitRequested: beginCafeSip,
                onComposeDraft: { draft in
                    composerDraft = draft
                    composerSessionID = UUID()
                    withAnimation(DesignSystem.Motion.base) {
                        tabCoordinator.selectedTab = 2
                    }
                },
                activityUnreadCount: activityStore.unreadCount,
                onActivityRequested: {
                    MugshotAnalytics.shared.capture(
                        .screenViewed(.activityCenter, source: .sheet)
                    )
                    MugshotAnalytics.shared.capture(
                        .activityOpened(source: .activityBell)
                    )
                    showsActivityCenter = true
                }
            )
        case 2:
            AddTabView(
                dataManager: dataManager,
                initialDraft: composerDraft,
                onAuthenticationRequired: requestDraftAuthentication,
                isFirstSipGuidanceEnabled: isGuidingFirstSip,
                onFirstSipGuidanceDismissed: dismissFirstSipGuidance,
                onFirstSipGuidanceCompleted: completeFirstSipGuidance
            )
                .id(composerSessionID)
                .onAppear {
                    if composerDraft != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            composerDraft = nil
                        }
                    }
                }
        case 3:
            SavedTabView(
                dataManager: dataManager,
                onLogVisitRequested: beginCafeSip,
                onAuthenticationRequired: requestAuthentication
            )
        default:
            JournalTabView(dataManager: dataManager) { draft in
                composerDraft = draft
                composerSessionID = UUID()
                withAnimation(DesignSystem.Motion.base) {
                    tabCoordinator.selectedTab = 2
                }
            }
        }
    }

    private static let guestTabs: Set<Int> = [0, 2, 3]

    private func captureSelectedScreen() {
        let screen: MugshotAnalyticsScreen
        switch tabCoordinator.selectedTab {
        case 0: screen = .map
        case 1: screen = .feed
        case 2: screen = .sipComposer
        case 3: screen = .saved
        default: screen = .journal
        }
        MugshotAnalytics.shared.capture(.screenViewed(screen, source: .tab))
    }

    private func synchronizeMapLocationUpdates() {
        guard tabCoordinator.selectedTab == 0, scenePhase == .active else {
            mapLocationManager.stopUpdatingLocation()
            return
        }

        // This never prompts. If permission already exists, retaining this
        // manager at the tab shell gives Map an immediate known location and
        // requests one fresh update whenever the tab becomes active.
        mapLocationManager.startUpdatingLocation()
    }

    private func beginCafeSip(_ cafe: Cafe) {
        composerDraft = Self.cafeDraft(
            cafe,
            dataManager: dataManager,
            userID: activeAccountUserID
        )
        composerSessionID = UUID()
        tabCoordinator.selectedTab = 2
    }

    private var hasAuthenticatedNavigation: Bool {
        authModel.authenticatedUser != nil
            || (sessionMessage != nil && dataManager.appData.currentUser != nil)
            || (MugshotLaunchEnvironment.isUITesting && !MugshotLaunchEnvironment.isUITestingSignedOut)
    }

    private var activeAccountUserID: UUID? {
        authModel.authenticatedUser?.id
            ?? (sessionMessage == nil ? nil : dataManager.appData.currentUser?.id)
    }

    private var sessionMessage: String? {
        guard authModel.authenticatedUser != nil
                || dataManager.appData.currentUser != nil,
              case .sessionUnavailable(let message) = authModel.status else {
            return nil
        }
        return message
    }

    private var gatedTabSelection: Binding<Int> {
        Binding(
            get: { tabCoordinator.selectedTab },
            set: { requestedTab in
                guard !hasAuthenticatedNavigation,
                      !Self.guestTabs.contains(requestedTab) else {
                    tabCoordinator.selectedTab = requestedTab
                    return
                }

                switch requestedTab {
                case 1:
                    requestAuthentication(
                        title: "Friends make discovery better",
                        message: "Sign in to see friend sips and Your Mix. You can keep exploring Map and Saved without an account."
                    )
                case 2:
                    tabCoordinator.selectedTab = requestedTab
                default:
                    requestAuthentication(
                        title: "Your journal lives here",
                        message: "Sign in to open your profile, settings, and personal sip history."
                    )
                }
            }
        )
    }

    private func requestAuthentication(title: String, message: String) {
        requestAuthentication(
            title: title,
            message: message,
            analyticsSource: "product_gate"
        )
    }

    private func requestDraftAuthentication() {
        requestAuthentication(
            title: "Save this draft to your journal",
            message: "Your draft is safe on this device. Sign in or create an account to keep it in your journal. Nothing publishes until you return and tap Publish.",
            analyticsSource: "guest_publish"
        )
    }

    private func requestAuthentication(
        title: String,
        message: String,
        analyticsSource: String
    ) {
        guard authenticationPrompt == nil else { return }
        authenticationPromptAnalyticsSource = analyticsSource
        MugshotAnalytics.shared.capture(.authPromptViewed(source: analyticsSource))
        authenticationPrompt = AuthenticationPrompt(title: title, message: message)
    }

    private func handleAuthenticationPromptDismissed() {
        if authModel.authenticatedUser == nil,
           let source = authenticationPromptAnalyticsSource {
            MugshotAnalytics.shared.capture(.authAbandoned(source: source))
        }
        authenticationPromptAnalyticsSource = nil
        scheduleSignedInOnboardingIfNeeded()
    }

    private func handlePendingSystemRoute() {
        guard authModel.status != .checking,
              authModel.status != .working,
              let route = systemRouter.pendingRoute else { return }
        guard hasAuthenticatedNavigation else {
            requestAuthentication(
                title: route.destination == .journal ? "Your journal lives here" : "Keep this sip in your journal",
                message: "Sign in to continue. Mugshot will keep this shortcut ready while authentication finishes."
            )
            return
        }

        if route.destination == .journal {
            tabCoordinator.selectedTab = 4
            systemRouter.consume(route)
            return
        }

        Task { await openComposer(for: route) }
    }

    private func handlePendingActivityRoute() {
        guard authModel.status != .checking,
              authModel.status != .working,
              let accountID = authModel.authenticatedUser?.id,
              let route = activityRouter.pendingRoute,
              route.accountID == accountID else { return }
        reportActivityRoute(route, result: .accepted)
        showsActivityCenter = true
    }

    private func handlePendingNearbyReminder() {
        guard let cafeID = nearbyReminderRouter.pendingCafeID,
              let cafe = dataManager.getCafe(id: cafeID) else { return }
        nearbyReminderCafe = cafe
        nearbyReminderRouter.consume()
        MugshotAnalytics.shared.capture(.discovery(
            action: .nearbyReminderOpened,
            source: .nearbyReminder,
            surface: .nearbyReminder,
            rankingVersion: nil,
            cafeID: cafe.remoteCafeId
        ))
        Task {
            guard authModel.authenticatedUser?.id != nil,
                  let client = try? SupabaseClientProvider.shared.client() else { return }
            _ = try? await DiscoveryInteractionService(client: client).record(
                cafeID: cafe.remoteCafeId,
                appleMapsPlaceID: cafe.appleMapsPlaceID,
                source: .nearbyReminder,
                kind: .nearbyNudgeOpened
            )
        }
    }

    @MainActor
    private func refreshShareExtensionListCache(accountID: UUID?) async {
        guard let accountID else {
            await PendingPlaceImportQueue.shared.cacheEligibleLists([])
            return
        }
        do {
            let client = try SupabaseClientProvider.shared.client()
            let lists = try await CollaborativeCafeListService(client: client)
                .lists(accountID: accountID)
            guard !Task.isCancelled,
                  authModel.authenticatedUser?.id == accountID else { return }
            await PendingPlaceImportQueue.shared.cacheEligibleLists(
                lists
                    .filter { $0.accessKind != .pendingInvitation && $0.canEditItems }
                    .map {
                        ShareExtensionCafeListCacheEntry(
                            id: $0.id,
                            title: $0.title,
                            accountID: accountID,
                            canEdit: true
                        )
                    }
            )
        } catch {
            // Keep the last account-matched cache through a transient outage.
            // The app validates write access again when it drains a command.
        }
    }

    private func synchronizeActivityRouter() {
        if case .signedOut = authModel.status {
            if let route = activityRouter.pendingRoute {
                reportActivityRoute(route, result: .accountRejected)
            }
            activityRouter.deactivateForSignedOutSession()
        } else {
            let accountID = authModel.authenticatedUser?.id
            if let accountID,
               let route = activityRouter.pendingRoute,
               route.accountID != accountID {
                reportActivityRoute(route, result: .accountRejected)
            }
            activityRouter.activate(accountID: accountID)
        }
    }

    private func reportActivityRoute(
        _ route: PendingActivityRoute,
        result: ActivityRouteResult
    ) {
        guard lastReportedActivityRouteID != route.id else { return }
        lastReportedActivityRouteID = route.id
        MugshotAnalytics.shared.capture(
            .activityRouteResult(result, source: route.source ?? .deepLink)
        )
    }

    private func openComposer(for route: SipSystemRoute) async {
        let ownerID = activeAccountUserID
        var draft: SipDraft?
        switch route.destination {
        case .cafeSip, .cameraSip:
            draft = SipDraft(
                ownerUserID: ownerID,
                launchContext: SipComposerLaunchContext(
                    source: route.destination == .cameraSip ? .camera : .appShortcut,
                    returnTab: tabCoordinator.selectedTab
                ),
                context: .cafe,
                visibility: CafeVisibilityPreferenceStore.shared.defaultCafeVisibility(
                    in: .forUserID(ownerID)
                ),
                composerExperience: .guided,
                guidedStep: route.destination == .cameraSip ? .drink : .context
            )
        case .homeSip:
            draft = SipDraft(
                ownerUserID: ownerID,
                launchContext: SipComposerLaunchContext(source: .appShortcut, returnTab: tabCoordinator.selectedTab),
                context: .home,
                locationName: JournalEntryContext.home.locationFallback,
                visibility: .private,
                composerExperience: .guided,
                guidedStep: .context
            )
        case .repeatRecentSip, .brewSavedRecipe:
            guard let ownerID,
                  let client = try? SupabaseClientProvider.shared.client() else { break }
            do {
                let entries = try await JournalService(client: client).fetchEntries(userID: ownerID)
                if route.destination == .repeatRecentSip, let recent = entries.first?.summary {
                    draft = .repeatSip(from: recent, ownerUserID: ownerID)
                } else if let recipe = entries.first(where: {
                    $0.context == .recipe || $0.summary.visit.recipeVersionID != nil
                })?.summary {
                    let projection = try await VisitService(client: client)
                        .fetchRecipeProjection(visitId: recipe.id)
                    if let projection {
                        draft = .brewAgain(
                            from: recipe,
                            recipeProjection: projection,
                            ownerUserID: ownerID
                        )
                    } else {
                        systemRouteError = "Mugshot couldn’t load that recipe’s private blueprint. Your saved recipe is unchanged."
                    }
                }
            } catch {
                systemRouteError = "Mugshot couldn’t load your journal for this shortcut. Your existing drafts are safe."
            }
        case .journal:
            break
        }

        guard var draft else {
            if systemRouteError == nil {
                systemRouteError = route.destination == .brewSavedRecipe
                    ? "Save a recipe first, then Brew Again can open it here."
                    : "Save a sip first, then Repeat Recent Sip can open it here."
            }
            systemRouter.consume(route)
            return
        }
        draft.refreshRatingCriteria(from: dataManager.appData.ratingTemplate)
        composerDraft = draft
        composerSessionID = UUID()
        tabCoordinator.selectedTab = 2
        systemRouter.consume(route)
    }

    private static func cafeDraft(_ cafe: Cafe, dataManager: DataManager, userID: UUID?) -> SipDraft {
        var draft = SipDraft(
            ownerUserID: userID,
            launchContext: SipComposerLaunchContext(source: .cafeDetail, preselectedCafe: cafe),
            context: .cafe,
            cafe: cafe,
            visibility: userID == nil
                ? .private
                : CafeVisibilityPreferenceStore.shared.defaultCafeVisibility(
                    in: .forUserID(userID)
                )
        )
        draft.refreshRatingCriteria(from: dataManager.appData.ratingTemplate)
        return draft
    }

    private func beginProductTour(goal: CapturePreferenceGoal) {
        productTourGoal = goal
        signedInOnboardingInitialStep = .welcome
        showsSignedInOnboarding = false
        setProductTourStep(.map)
    }

    private func advanceProductTour() {
        guard let current = productTourStep,
              let next = MugshotProductTourStep(rawValue: current.rawValue + 1) else { return }
        recordProductTourStepCompletion(current)
        setProductTourStep(next)
        MugshotHaptic.selection.play()
    }

    private func goBackInProductTour() {
        guard let current = productTourStep else { return }
        if let previous = MugshotProductTourStep(rawValue: current.rawValue - 1) {
            setProductTourStep(previous)
        } else {
            productTourStep = nil
            signedInOnboardingInitialStep = .personalize
            showsSignedInOnboarding = true
        }
        MugshotHaptic.selection.play()
    }

    private func setProductTourStep(_ step: MugshotProductTourStep) {
        withAnimation(DesignSystem.Motion.slow) {
            tabCoordinator.selectedTab = step.tabIndex
            productTourStep = step
        }
    }

    private func skipProductTour() {
        guard let current = productTourStep, !isCompletingProductTour else { return }
        isCompletingProductTour = true
        Task {
            if !isOnboardingDesignQA,
               !(await authModel.skipCapturePreferences()) {
                authModel.deferCapturePreferencesForSession()
            }
            MugshotAnalytics.shared.capture(
                .onboardingSkipped(
                    step: current.number,
                    totalSteps: MugshotOnboardingPlan.totalSteps
                )
            )
            MugshotAnalytics.shared.capture(.capturePreferencesSkipped)
            isCompletingProductTour = false
            productTourStep = nil
            completedProductTourSteps = []
            signedInOnboardingStartedAt = nil
            tabCoordinator.selectedTab = preferredLandingTab(for: productTourGoal)
        }
    }

    private func completeProductTour(startsFirstSip: Bool) {
        guard productTourStep == .shareImport, !isCompletingProductTour else { return }
        isCompletingProductTour = true
        Task {
            let didSave = await saveOnboardingGoal(productTourGoal)
            if !didSave, !isOnboardingDesignQA {
                authModel.deferCapturePreferencesForSession()
            }

            recordProductTourStepCompletion(.shareImport)
            MugshotAnalytics.shared.capture(
                .onboardingCompleted(durationSeconds: signedInOnboardingDurationSeconds)
            )
            MugshotAnalytics.shared.capture(
                .capturePreferencesCompleted(
                    selectedDrinkFamilyCount: 0,
                    selectedDiscoveryIntentCount: 1,
                    hasHabit: false
                )
            )

            if startsFirstSip {
                isGuidingFirstSip = true
                MugshotFirstSipGuideStore.setActive(
                    true,
                    accountID: authModel.authenticatedUser?.id
                )
                tabCoordinator.selectedTab = 2
            } else {
                tabCoordinator.selectedTab = preferredLandingTab(for: productTourGoal)
            }

            isCompletingProductTour = false
            productTourStep = nil
            completedProductTourSteps = []
            signedInOnboardingStartedAt = nil
            MugshotHaptic.success.play()
        }
    }

    private func skipSignedInOnboarding() async {
        if !isOnboardingDesignQA,
           !(await authModel.skipCapturePreferences()) {
            authModel.deferCapturePreferencesForSession()
        }
        showsSignedInOnboarding = false
        signedInOnboardingStartedAt = nil
    }

    private func saveOnboardingGoal(_ goal: CapturePreferenceGoal) async -> Bool {
        if isOnboardingDesignQA { return true }
        return await authModel.saveCapturePreferences(
            authModel.capturePreferences.applyingOnboardingGoal(goal)
        )
    }

    private func recordProductTourStepCompletion(_ step: MugshotProductTourStep) {
        guard completedProductTourSteps.insert(step).inserted else { return }
        MugshotAnalytics.shared.capture(
            .onboardingStepCompleted(
                step: step.number,
                totalSteps: MugshotOnboardingPlan.totalSteps
            )
        )
    }

    private var signedInOnboardingDurationSeconds: Int {
        guard let signedInOnboardingStartedAt else { return 0 }
        return Int(Date().timeIntervalSince(signedInOnboardingStartedAt).rounded())
    }

    private func preferredLandingTab(for goal: CapturePreferenceGoal) -> Int {
        switch goal {
        case .nearby: 0
        case .friends: 1
        case .taste, .journal: 4
        }
    }

    private func dismissFirstSipGuidance() {
        isGuidingFirstSip = false
        MugshotFirstSipGuideStore.setActive(
            false,
            accountID: authModel.authenticatedUser?.id
        )
    }

    private func completeFirstSipGuidance() {
        dismissFirstSipGuidance()
        MugshotHaptic.success.play()
    }

    private var isOnboardingDesignQA: Bool {
#if DEBUG
        MugshotLaunchEnvironment.shouldShowSignedInOnboardingDesignQA
#else
        false
#endif
    }

    private func presentOnboardingDesignQAIfNeeded() {
#if DEBUG
        guard MugshotLaunchEnvironment.shouldShowSignedInOnboardingDesignQA,
              !didPresentOnboardingDesignQA else { return }
        didPresentOnboardingDesignQA = true
        productTourGoal = .nearby
        completedProductTourSteps = []
        signedInOnboardingInitialStep = .welcome
        signedInOnboardingStartedAt = .now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showsSignedInOnboarding = true
        }
#endif
    }

    private func scheduleSignedInOnboardingIfNeeded() {
        guard requiresSignedInOnboarding,
              !showsSignedInOnboarding else { return }
        productTourGoal = authModel.capturePreferences.onboardingGoal ?? .nearby
        completedProductTourSteps = []
        signedInOnboardingInitialStep = .welcome
        signedInOnboardingStartedAt = nil
        showsSignedInOnboarding = true
    }

    private var requiresSignedInOnboarding: Bool {
#if DEBUG
        if MugshotLaunchEnvironment.shouldShowSignedInOnboardingDesignQA {
            return true
        }
#endif
        return false
    }

    private var signedInOnboardingPresentation: Binding<Bool> {
        Binding(
            get: { showsSignedInOnboarding || requiresSignedInOnboarding },
            set: { isPresented in
                if isPresented {
                    showsSignedInOnboarding = true
                } else if !requiresSignedInOnboarding {
                    showsSignedInOnboarding = false
                }
            }
        )
    }

    private func scheduleGuestIntroductionIfNeeded() {
        guard MugshotGuestIntroductionPolicy.shouldPresent(
            hasSeen: hasSeenGuestIntroduction,
            hasAuthenticatedNavigation: hasAuthenticatedNavigation,
            isUITesting: MugshotLaunchEnvironment.isUITesting
        ),
        authenticationPrompt == nil,
        !showsGuestSavedMerge,
        !showsSignedInOnboarding,
        !showsGuestIntroduction else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard MugshotGuestIntroductionPolicy.shouldPresent(
                hasSeen: hasSeenGuestIntroduction,
                hasAuthenticatedNavigation: hasAuthenticatedNavigation,
                isUITesting: MugshotLaunchEnvironment.isUITesting
            ),
            authenticationPrompt == nil,
            !showsGuestSavedMerge,
            !showsSignedInOnboarding else { return }
            guestIntroductionStartedAt = .now
            guestIntroductionCompleted = false
            MugshotAnalytics.shared.capture(.guestIntroductionStarted)
            showsGuestIntroduction = true
        }
    }

    private func completeGuestIntroduction() {
        guestIntroductionCompleted = true
        hasSeenGuestIntroduction = true
        let duration = guestIntroductionDurationSeconds
        MugshotAnalytics.shared.capture(
            .guestIntroductionCompleted(durationSeconds: duration)
        )
        MugshotAnalytics.shared.capture(
            .timeToFirstValue(value: "map_available", durationSeconds: duration)
        )
        showsGuestIntroduction = false
    }

    private func handleGuestIntroductionDismissed() {
        if !guestIntroductionCompleted {
            MugshotAnalytics.shared.capture(.guestIntroductionDismissed)
        }
        hasSeenGuestIntroduction = true
        guestIntroductionStartedAt = nil
        guestIntroductionCompleted = false
    }

    private var guestIntroductionDurationSeconds: Int {
        guard let guestIntroductionStartedAt else { return 0 }
        return Int(Date().timeIntervalSince(guestIntroductionStartedAt).rounded())
    }

    private var localAccountScope: LocalAccountScope {
        .forUserID(
            authModel.authenticatedUser?.id
                ?? dataManager.appData.currentUser?.id
        )
    }

    private func activateLocalStorage(scope: LocalAccountScope? = nil) {
        let resolvedScope = scope ?? localAccountScope
        SipDraftStore.shared.activate(scope: resolvedScope)
        CafeVisibilityPreferenceStore.shared.activate(scope: resolvedScope)
        try? PhotoCache.shared.activate(
            scope: resolvedScope,
            migratingKnownKeys: knownLegacyPhotoKeys(for: resolvedScope)
        )
    }

    private func knownLegacyPhotoKeys(for scope: LocalAccountScope) -> Set<String> {
        guard let userID = scope.userID else { return [] }
        return Set(
            dataManager.appData.visits
                .filter { $0.userId == userID }
                .flatMap(\.photos)
        )
    }
}

private struct SessionUnavailableBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button("Retry", action: retry)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.roastBrown)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.sandBeige)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.mugshotLine)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sessionUnavailableBanner")
    }
}

struct MugshotBottomNavHiddenPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func mugshotBottomNavHidden(_ isHidden: Bool = true) -> some View {
        preference(key: MugshotBottomNavHiddenPreferenceKey.self, value: isHidden)
    }
}

private struct AuthenticationPrompt: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct GuestSavedMergeView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss

    private var cafes: [Cafe] { authModel.pendingGuestSavedCafes }
    private var favoriteCount: Int { cafes.filter(\.isFavorite).count }
    private var wantToTryCount: Int { cafes.filter(\.wantToTry).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bring your guest saves with you?")
                            .mugshotDisplay(size: 30)
                            .foregroundColor(.espressoBrown)
                        Text("Mugshot found cafes you saved before signing in. Review the count, then merge them into this account or leave them safely on this device.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        mergeStat(title: "Favorites", value: favoriteCount, icon: "heart.fill")
                        mergeStat(title: "Want to Try", value: wantToTryCount, icon: "bookmark.fill")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(cafes.prefix(4)) { cafe in
                            HStack(spacing: 10) {
                                Image(systemName: cafe.isFavorite ? "heart.fill" : "bookmark.fill")
                                    .foregroundColor(.mugshotSage)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cafe.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.espressoBrown)
                                    if !cafe.address.isEmpty {
                                        Text(cafe.address)
                                            .font(.system(size: 12))
                                            .foregroundColor(.tertiaryText)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                        }

                        if cafes.count > 4 {
                            Text("And \(cafes.count - 4) more")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .padding(16)
                    .cardStyle()

                    if let error = authModel.guestSavedMergeError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.roastBrown)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task {
                            if await authModel.mergeGuestSaved(dataManager: dataManager) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if authModel.isMergingGuestSaved {
                                ProgressView().tint(.foamWhite)
                            }
                            Text("Merge \(cafes.count) cafe\(cafes.count == 1 ? "" : "s")")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(authModel.isMergingGuestSaved)

                    Button("Not now") {
                        authModel.postponeGuestSavedMerge()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.roastBrown)
                    .frame(maxWidth: .infinity)
                    .disabled(authModel.isMergingGuestSaved)
                }
                .padding(22)
            }
            .background(Color.creamWhite)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func mergeStat(title: String, value: Int, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.espressoBrown)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sandBeige.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
    }
}

private struct MugshotBottomNav: View {
    @Binding var selectedTab: Int
    @State private var dragPosition: CGFloat?
    @State private var isSettlingSelection = false

    private enum Metrics {
        static let contentHeight: CGFloat = 62
        static let standardItemWidth: CGFloat = 60
        static let addControlDiameter: CGFloat = 52
        static let lensWidth: CGFloat = 70
        static let lensHeight: CGFloat = 66
        static let lensCornerRadius: CGFloat = 25
        static let iconSize: CGFloat = 20
        static let addIconSize: CGFloat = 22
        static let labelSize: CGFloat = 11
    }

    private let items: [MugshotTabItem] = [
        MugshotTabItem(index: 0, title: "Map", icon: "map"),
        MugshotTabItem(index: 1, title: "Feed", icon: "square.grid.2x2"),
        MugshotTabItem(index: 2, title: "Add", icon: "plus"),
        MugshotTabItem(index: 3, title: "Saved", icon: "bookmark"),
        MugshotTabItem(index: 4, title: "Journal", icon: "book.closed")
    ]

    var body: some View {
        ZStack {
            glassNavigationLayer

            addForegroundIconLayer
                .frame(height: Metrics.contentHeight)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if showsRestingSelection {
                restingSelectedLayer
                    .frame(height: Metrics.contentHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .modifier(MugshotBottomNavGlassStyle())
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var glassNavigationLayer: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                navItems
            }
        } else {
            navItems
        }
    }

    private var navItems: some View {
        GeometryReader { proxy in
            let lensPosition = activeLensPosition(width: proxy.size.width)

            ZStack {
                HStack(alignment: .center, spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            settleSelection(on: item.index)
                        } label: {
                            baseItem(item)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityLabel(item.title)
                        .accessibilityIdentifier("mugshot.tab.\(item.title.lowercased())")
                        .accessibilityValue(selectedTab == item.index ? "Selected" : "")
                        .accessibilityHint(item.index == 2 ? "Opens the guided sip composer" : "Switches to the \(item.title) tab")
                        .accessibilityAddTraits(selectedTab == item.index ? .isSelected : [])
                    }
                }

                if !showsRestingSelection {
                    mintIconLayer
                        .mask {
                            selectionShape
                                .frame(width: Metrics.lensWidth, height: Metrics.lensHeight)
                                .position(x: lensPosition, y: proxy.size.height / 2)
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                selectionGlassLens
                    .position(x: lensPosition, y: proxy.size.height / 2)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(width: proxy.size.width))
        }
        .frame(height: Metrics.contentHeight)
    }

    @ViewBuilder
    private func baseItem(_ item: MugshotTabItem) -> some View {
        if showsRestingSelection, item.index == selectedTab, item.index != 2 {
            Color.clear
                .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
        } else if item.index == 2 {
            addButton
        } else {
            standardItem(item)
        }
    }

    private func standardItem(_ item: MugshotTabItem) -> some View {
        VStack(spacing: 3) {
            Image(systemName: item.icon)
                .font(.system(size: Metrics.iconSize, weight: .semibold))
            Text(item.title)
                .font(.system(size: Metrics.labelSize, weight: .semibold))
        }
        .foregroundColor(.tertiaryText)
        .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
    }

    private var addButton: some View {
        let control = Color.clear
            .frame(width: Metrics.addControlDiameter, height: Metrics.addControlDiameter)

        return VStack(spacing: 2) {
            control
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.foamWhite.opacity(0.48), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 7,
                    x: 0,
                    y: 4
                )

            Text("Add")
                .font(.system(size: Metrics.labelSize, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
    }

    private var mintIconLayer: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(items) { item in
                Group {
                    if item.index == 2 {
                        Color.clear
                            .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
                    } else {
                        mintStandardIcon(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func mintStandardIcon(_ item: MugshotTabItem) -> some View {
        VStack(spacing: 3) {
            Image(systemName: selectedIcon(for: item.icon))
                .font(.system(size: Metrics.iconSize, weight: .bold))
                .foregroundColor(.mugshotMint)
            Text(item.title)
                .font(.system(size: Metrics.labelSize, weight: .semibold))
                .hidden()
        }
        .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
    }

    private var selectionGlassLens: some View {
        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .frame(width: Metrics.lensWidth, height: Metrics.lensHeight)
                    .glassEffect(
                        .clear.interactive(),
                        in: .rect(cornerRadius: Metrics.lensCornerRadius)
                    )
                    .overlay(selectionStroke)
            } else {
                RoundedRectangle(cornerRadius: Metrics.lensCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: Metrics.lensWidth, height: Metrics.lensHeight)
                    .overlay(selectionStroke)
            }
        }
        .shadow(color: Color.mugshotSage.opacity(0.12), radius: 8, x: 0, y: 3)
        .accessibilityHidden(true)
    }

    private var selectionShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.lensCornerRadius, style: .continuous)
    }

    private var selectionStroke: some View {
        selectionShape.stroke(Color.foamWhite.opacity(0.50), lineWidth: 1)
    }

    private var showsRestingSelection: Bool {
        dragPosition == nil && !isSettlingSelection
    }

    private var addForegroundIconLayer: some View {
        GeometryReader { proxy in
            let lensPosition = activeLensPosition(width: proxy.size.width)

            ZStack {
                addIconStrip(color: .tertiaryText)

                addIconStrip(color: .mugshotMint)
                    .mask {
                        selectionShape
                            .frame(width: Metrics.lensWidth, height: Metrics.lensHeight)
                            .position(x: lensPosition, y: proxy.size.height / 2)
                    }
            }
        }
    }

    private func addIconStrip(color: Color) -> some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(items) { item in
                Group {
                    if item.index == 2 {
                        addForegroundIcon(color: color)
                    } else {
                        Color.clear
                            .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func addForegroundIcon(color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "plus")
                .font(.system(size: Metrics.addIconSize, weight: .bold))
                .foregroundColor(color)
                .frame(width: Metrics.addControlDiameter, height: Metrics.addControlDiameter)
            Text("Add")
                .font(.system(size: Metrics.labelSize, weight: .semibold))
                .hidden()
        }
        .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let position = clamped(position: value.location.x, width: width)
                isSettlingSelection = false
                dragPosition = position
            }
            .onEnded { value in
                let target = nearestTab(to: value.location.x, width: width)
                settleSelection(on: target)
            }
    }

    private var restingSelectedLayer: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(items) { item in
                Group {
                    if item.index == selectedTab {
                        restingSelectedItem(item)
                    } else {
                        Color.clear
                            .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func restingSelectedItem(_ item: MugshotTabItem) -> some View {
        if item.index == 2 {
            VStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: Metrics.addIconSize, weight: .bold))
                    .frame(width: Metrics.addControlDiameter, height: Metrics.addControlDiameter)
                    .foregroundColor(.mugshotMint)
                Text(item.title)
                    .font(.system(size: Metrics.labelSize, weight: .bold))
                    .foregroundColor(.mugshotSageText)
            }
            .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
        } else {
            VStack(spacing: 3) {
                Image(systemName: selectedIcon(for: item.icon))
                    .font(.system(size: Metrics.iconSize, weight: .bold))
                    .foregroundColor(.mugshotMint)
                Text(item.title)
                    .font(.system(size: Metrics.labelSize, weight: .bold))
                    .foregroundColor(.mugshotSageText)
            }
            .frame(width: Metrics.standardItemWidth, height: Metrics.contentHeight)
        }
    }

    private func settleSelection(on target: Int) {
        guard target != selectedTab || dragPosition != nil else { return }

        isSettlingSelection = true
        withAnimation(DesignSystem.Motion.base) {
            selectedTab = target
            dragPosition = nil
        } completion: {
            guard selectedTab == target, dragPosition == nil else { return }
            isSettlingSelection = false
        }
    }

    private func activeLensPosition(width: CGFloat) -> CGFloat {
        if let dragPosition {
            return clamped(position: dragPosition, width: width)
        }

        let itemWidth = width / CGFloat(items.count)
        return itemWidth * (CGFloat(selectedTab) + 0.5)
    }

    private func nearestTab(to position: CGFloat, width: CGFloat) -> Int {
        let itemWidth = width / CGFloat(items.count)
        let index = Int((position / itemWidth).rounded(.down))
        return min(max(index, 0), items.count - 1)
    }

    private func clamped(position: CGFloat, width: CGFloat) -> CGFloat {
        let inset = Metrics.lensWidth / 2
        return min(max(position, inset), width - inset)
    }

    private func selectedIcon(for icon: String) -> String {
        switch icon {
        case "bookmark":
            return "bookmark.fill"
        case "book.closed":
            return "book.closed.fill"
        case "map":
            return "map.fill"
        case "square.grid.2x2":
            return "square.grid.2x2.fill"
        default:
            return icon
        }
    }

}

private struct MugshotBottomNavGlassStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 36, style: .continuous)

        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 36))
                .overlay(shape.stroke(Color.foamWhite.opacity(0.58), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.11), radius: 20, x: 0, y: -5)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.mugshotLine.opacity(0.72), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.11), radius: 20, x: 0, y: -5)
        }
    }
}

private struct MugshotTabItem: Identifiable {
    let index: Int
    let title: String
    let icon: String

    var id: Int { index }
}
