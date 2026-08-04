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
    @StateObject private var tabCoordinator = TabCoordinator()
    @StateObject private var mapLocationManager = LocationManager()
    @StateObject private var systemRouter = SipSystemRouter.shared
    @StateObject private var activityStore = ActivityCenterStore()
    @StateObject private var activityRouter = ActivityDeepLinkRouter.shared
    @StateObject private var enforcementStore = EnforcementNoticeStore()
    @StateObject private var automaticSipRecovery = AutomaticSipRecoveryCoordinator()
    @State private var composerDraft: SipDraft?
    @State private var composerSessionID = UUID()
    @State private var authenticationPrompt: AuthenticationPrompt?
    @State private var showsGuestSavedMerge = false
    @State private var showsCapturePreferences = false
    @State private var showsGuestIntroduction = false
    @State private var showsActivityCenter = false
    @State private var showsEnforcementCenter = false
    @State private var systemRouteError: String?
    @State private var sharedMugshotRoute: MugshotSharedLinkRoute?
    @State private var isBottomNavHidden = false
    
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
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.mugshotSage)
            activateLocalStorage()
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
        }
        .onChange(of: tabCoordinator.selectedTab) { _, _ in
            captureSelectedScreen()
            synchronizeMapLocationUpdates()
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, userId in
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
            handlePendingSystemRoute()
            synchronizeActivityRouter()
            enforcementStore.prepare(accountID: userId)
            handlePendingActivityRoute()
            scheduleGuestIntroductionIfNeeded()
        }
        .onChange(of: dataManager.journalRevision) { _, _ in
            activateLocalStorage()
        }
        .onChange(of: automaticSipRecovery.completionRevision) { _, _ in
            dataManager.noteJournalMutation()
        }
        .onChange(of: authModel.status) { _, _ in
            synchronizeActivityRouter()
            handlePendingSystemRoute()
            handlePendingActivityRoute()
            scheduleGuestIntroductionIfNeeded()
        }
        .onChange(of: systemRouter.pendingRoute?.id) { _, _ in
            handlePendingSystemRoute()
        }
        .onChange(of: activityRouter.pendingRoute?.id) { _, _ in
            handlePendingActivityRoute()
        }
        .onChange(of: scenePhase) { _, phase in
            automaticSipRecovery.setAppActive(phase == .active)
            synchronizeMapLocationUpdates()
            guard phase == .active,
                  let expectedAccountID = authModel.authenticatedUser?.id else { return }
            Task {
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
                scheduleCapturePreferencesIfNeeded()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                guard authenticationPrompt == nil else { return }
                showsGuestSavedMerge = true
            }
        }
        .onChange(of: authModel.shouldOfferCapturePreferences) { _, shouldOffer in
            guard shouldOffer else { return }
            scheduleCapturePreferencesIfNeeded()
        }
    }

    private var presentedScene: some View {
        lifecycleScene
        .sheet(item: $authenticationPrompt, onDismiss: scheduleCapturePreferencesIfNeeded) { prompt in
            AuthEntryView(
                dataManager: dataManager,
                contextTitle: prompt.title,
                contextMessage: prompt.message,
                showsCloseButton: true
            )
            .environmentObject(authModel)
        }
        .sheet(isPresented: $showsGuestIntroduction, onDismiss: {
            hasSeenGuestIntroduction = true
        }) {
            MugsyGuestIntroductionView {
                hasSeenGuestIntroduction = true
                showsGuestIntroduction = false
            }
        }
        .sheet(isPresented: $showsGuestSavedMerge, onDismiss: scheduleCapturePreferencesIfNeeded) {
            GuestSavedMergeView(dataManager: dataManager)
                .environmentObject(authModel)
                .interactiveDismissDisabled(authModel.isMergingGuestSaved)
        }
        .sheet(isPresented: $showsCapturePreferences) {
            CapturePreferencesView(allowsSkipping: true)
                .environmentObject(authModel)
        }
        .sheet(isPresented: $showsActivityCenter) {
            if let accountID = authModel.authenticatedUser?.id {
                ActivityCenterView(
                    store: activityStore,
                    router: activityRouter,
                    dataManager: dataManager,
                    accountID: accountID
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
                PublicMugshotLinkView(route: route)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { sharedMugshotRoute = nil }
                        }
                    }
            }
            .presentationDetents([.large])
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
            } else if let accountID = authModel.authenticatedUser?.id,
                      activityRouter.enqueue(url: url, accountID: accountID) {
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
                    showsActivityCenter = true
                }
            )
        case 2:
            AddTabView(dataManager: dataManager, initialDraft: composerDraft)
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

    private static let guestTabs: Set<Int> = [0, 3]

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
        guard hasAuthenticatedNavigation else {
            requestAuthentication(
                title: "Keep this sip in your journal",
                message: "Sign in when you are ready to log this cafe. Your Map and Saved cafes stay available while you explore."
            )
            return
        }

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
                    requestAuthentication(
                        title: "Start your sip journal",
                        message: "Sign in to save a sip privately, with friends, or for Everyone. Your current guest saves will stay on this device."
                    )
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
        authenticationPrompt = AuthenticationPrompt(title: title, message: message)
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
        showsActivityCenter = true
    }

    private func synchronizeActivityRouter() {
        if case .signedOut = authModel.status {
            activityRouter.deactivateForSignedOutSession()
        } else {
            activityRouter.activate(accountID: authModel.authenticatedUser?.id)
        }
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
            visibility: CafeVisibilityPreferenceStore.shared.defaultCafeVisibility(
                in: .forUserID(userID)
            )
        )
        draft.refreshRatingCriteria(from: dataManager.appData.ratingTemplate)
        return draft
    }

    private func scheduleCapturePreferencesIfNeeded() {
        guard authModel.authenticatedUser != nil,
              authModel.shouldOfferCapturePreferences,
              authModel.pendingGuestSavedCafes.isEmpty,
              authenticationPrompt == nil,
              !showsGuestSavedMerge else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard authModel.shouldOfferCapturePreferences,
                  authModel.pendingGuestSavedCafes.isEmpty,
                  authenticationPrompt == nil,
                  !showsGuestSavedMerge else { return }
            showsCapturePreferences = true
        }
    }

    private func scheduleGuestIntroductionIfNeeded() {
        guard MugshotGuestIntroductionPolicy.shouldPresent(
            hasSeen: hasSeenGuestIntroduction,
            hasAuthenticatedNavigation: hasAuthenticatedNavigation,
            isUITesting: MugshotLaunchEnvironment.isUITesting
        ),
        authenticationPrompt == nil,
        !showsGuestSavedMerge,
        !showsCapturePreferences,
        !showsGuestIntroduction else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard MugshotGuestIntroductionPolicy.shouldPresent(
                hasSeen: hasSeenGuestIntroduction,
                hasAuthenticatedNavigation: hasAuthenticatedNavigation,
                isUITesting: MugshotLaunchEnvironment.isUITesting
            ),
            authenticationPrompt == nil,
            !showsGuestSavedMerge,
            !showsCapturePreferences else { return }
            showsGuestIntroduction = true
        }
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
