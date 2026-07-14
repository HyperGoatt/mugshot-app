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
    @StateObject private var tabCoordinator = TabCoordinator()
    @StateObject private var systemRouter = SipSystemRouter.shared
    @State private var composerDraft: SipDraft?
    @State private var composerSessionID = UUID()
    @State private var authenticationPrompt: AuthenticationPrompt?
    @State private var showsGuestSavedMerge = false
    @State private var showsCapturePreferences = false
    @State private var systemRouteError: String?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            activeTab
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.creamWhite)
                .transition(.opacity)

            if tabCoordinator.selectedTab != 2 {
                MugshotBottomNav(selectedTab: gatedTabSelection)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environmentObject(tabCoordinator)
        .tint(.mugshotSage)
        .background(Color.creamWhite.ignoresSafeArea())
        // The dock deliberately extends through the container safe area so it
        // sits with the home indicator instead of hovering a full safe-area
        // height above it.
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.mugshotSage)
            if !hasAuthenticatedNavigation,
               !Self.guestTabs.contains(tabCoordinator.selectedTab) {
                tabCoordinator.selectedTab = 0
            }
            handlePendingSystemRoute()
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, userId in
            if userId != nil {
                authenticationPrompt = nil
            } else if !hasAuthenticatedNavigation,
                      !Self.guestTabs.contains(tabCoordinator.selectedTab) {
                tabCoordinator.selectedTab = 0
            }
            handlePendingSystemRoute()
        }
        .onChange(of: authModel.status) { _, _ in
            handlePendingSystemRoute()
        }
        .onChange(of: systemRouter.pendingRoute?.id) { _, _ in
            handlePendingSystemRoute()
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
        .sheet(item: $authenticationPrompt, onDismiss: scheduleCapturePreferencesIfNeeded) { prompt in
            AuthEntryView(
                dataManager: dataManager,
                contextTitle: prompt.title,
                contextMessage: prompt.message,
                showsCloseButton: true
            )
            .environmentObject(authModel)
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
        .alert("Couldn’t open that shortcut", isPresented: Binding(
            get: { systemRouteError != nil },
            set: { if !$0 { systemRouteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(systemRouteError ?? "Please try again.")
        }
        .onOpenURL { systemRouter.enqueue(url: $0) }
        .task(id: authModel.authenticatedUser?.id) {
            guard let userId = authModel.authenticatedUser?.id,
                  let client = try? SupabaseClientProvider.shared.client() else { return }
            if let clearedCount = try? await CafeStateService(client: client)
                .reconcileVisitedWantToTry(userId: userId),
               clearedCount > 0 {
                dataManager.noteJournalMutation()
            }
            await VisitDeletionService(client: client).retryPendingMediaCleanup(userId: userId)
            await DrinkAnalysisService(client: client).retryPendingAnalyses(userId: userId)
        }
    }

    @ViewBuilder
    private var activeTab: some View {
        switch tabCoordinator.selectedTab {
        case 0:
            MapTabView(dataManager: dataManager, onLogVisitRequested: { cafe in
                guard hasAuthenticatedNavigation else {
                    requestAuthentication(
                        title: "Keep this sip in your journal",
                        message: "Sign in when you are ready to log this cafe. Your Map and Saved cafes stay available while you explore."
                    )
                    return
                }
                composerDraft = Self.cafeDraft(cafe, dataManager: dataManager, userID: authModel.authenticatedUser?.id)
                composerSessionID = UUID()
                withAnimation(DesignSystem.Motion.base) {
                    tabCoordinator.selectedTab = 2
                }
            })
        case 1:
            FeedTabView(dataManager: dataManager)
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
            SavedTabView(dataManager: dataManager) { title, message in
                requestAuthentication(title: title, message: message)
            }
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

    private var hasAuthenticatedNavigation: Bool {
        authModel.authenticatedUser != nil
            || (MugshotLaunchEnvironment.isUITesting && !MugshotLaunchEnvironment.isUITestingSignedOut)
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

    private func openComposer(for route: SipSystemRoute) async {
        let ownerID = authModel.authenticatedUser?.id
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
                visibility: CafeVisibilityPreferenceStore.shared.defaultCafeVisibility,
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
                    $0.context == .recipe || $0.summary.visit.structuredBrewDetails.recipeIdentityID != nil
                })?.summary {
                    draft = .brewAgain(from: recipe, ownerUserID: ownerID)
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
            visibility: CafeVisibilityPreferenceStore.shared.defaultCafeVisibility
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
    @State private var dragPreviewTab: Int?

    private let items: [MugshotTabItem] = [
        MugshotTabItem(index: 0, title: "Map", icon: "map"),
        MugshotTabItem(index: 1, title: "Feed", icon: "square.grid.2x2"),
        MugshotTabItem(index: 2, title: "Add", icon: "plus"),
        MugshotTabItem(index: 3, title: "Saved", icon: "bookmark"),
        MugshotTabItem(index: 4, title: "Journal", icon: "book.closed")
    ]

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 14) {
                    navItems
                }
            } else {
                navItems
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .mugshotGlassSurface(
            radius: 28,
            tint: Color.creamWhite.opacity(0.94),
            stroke: Color.foamWhite.opacity(0.68),
            shadow: DesignSystem.Shadow(color: .black.opacity(0.11), radius: 20, x: 0, y: -5),
            interactive: false
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var navItems: some View {
        GeometryReader { proxy in
            ZStack {
                if let dragPosition {
                    dragGlassLens(x: clamped(position: dragPosition, width: proxy.size.width))
                        .position(x: clamped(position: dragPosition, width: proxy.size.width), y: proxy.size.height / 2)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                HStack(alignment: .center, spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            withAnimation(DesignSystem.Motion.base) {
                                selectedTab = item.index
                            }
                        } label: {
                            if item.index == 2 {
                                addButton(
                                    isSelected: selectedTab == item.index,
                                    isPreviewing: dragPreviewTab == item.index
                                )
                            } else {
                                standardItem(
                                    item,
                                    isSelected: selectedTab == item.index,
                                    isPreviewing: dragPreviewTab == item.index
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityLabel(item.title)
                    }
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(width: proxy.size.width))
        }
        .frame(height: 54)
    }

    private func standardItem(
        _ item: MugshotTabItem,
        isSelected: Bool,
        isPreviewing: Bool
    ) -> some View {
        let isHighlighted = isSelected || isPreviewing
        let showsRestingSelection = isSelected && dragPosition == nil
        let label = VStack(spacing: 3) {
            Image(systemName: isHighlighted ? selectedIcon(for: item.icon) : item.icon)
                .font(.system(size: 18, weight: .semibold))
            Text(item.title)
                .font(.system(size: 10, weight: isHighlighted ? .bold : .semibold))
        }
        .foregroundColor(isHighlighted ? .mugshotSage : .tertiaryText)
        .frame(width: 56, height: 52)

        return Group {
            if showsRestingSelection {
                label
                    .mugshotGlassSurface(
                        radius: 18,
                        tint: Color.mugshotMint.opacity(0.84),
                        stroke: Color.foamWhite.opacity(0.50),
                        shadow: DesignSystem.Shadow(color: Color.mugshotSage.opacity(0.12), radius: 8, x: 0, y: 3),
                        interactive: true
                    )
            } else {
                label
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func addButton(isSelected: Bool, isPreviewing: Bool) -> some View {
        let isHighlighted = isSelected || isPreviewing
        let fill = isHighlighted ? Color.mugshotMatcha : Color.mugshotSage

        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(fill.opacity(isHighlighted ? 0.96 : 0.90))

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.foamWhite)
            }
            .frame(width: 48, height: 48)
            .mugshotGlassCircle(
                tint: fill,
                stroke: Color.foamWhite.opacity(0.72),
                shadow: DesignSystem.Shadow(color: fill.opacity(0.34), radius: 15, x: 0, y: 6),
                interactive: true
            )
            .scaleEffect(isHighlighted ? 1.05 : 1.0)

            Text("Add")
                .font(.system(size: 10, weight: isHighlighted ? .bold : .semibold))
                .foregroundColor(isHighlighted ? .mugshotSage : .tertiaryText)
        }
        .frame(width: 56, height: 54)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dragGlassLens(x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.mugshotMint.opacity(0.16))
            .frame(width: 58, height: 52)
            .mugshotGlassSurface(
                radius: 18,
                tint: Color.mugshotMint.opacity(0.76),
                stroke: Color.foamWhite.opacity(0.54),
                shadow: DesignSystem.Shadow(color: Color.mugshotSage.opacity(0.12), radius: 8, x: 0, y: 3),
                interactive: true
            )
            .accessibilityHidden(true)
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let position = clamped(position: value.location.x, width: width)
                dragPosition = position
                dragPreviewTab = nearestTab(to: position, width: width)
            }
            .onEnded { value in
                let target = nearestTab(to: value.location.x, width: width)
                withAnimation(DesignSystem.Motion.base) {
                    selectedTab = target
                    dragPosition = nil
                    dragPreviewTab = nil
                }
            }
    }

    private func nearestTab(to position: CGFloat, width: CGFloat) -> Int {
        let itemWidth = width / CGFloat(items.count)
        let index = Int((position / itemWidth).rounded(.down))
        return min(max(index, 0), items.count - 1)
    }

    private func clamped(position: CGFloat, width: CGFloat) -> CGFloat {
        min(max(position, 29), width - 29)
    }

    private func selectedIcon(for icon: String) -> String {
        switch icon {
        case "bookmark":
            return "bookmark.fill"
        case "person":
            return "person.fill"
        case "book.closed":
            return "book.closed.fill"
        case "map":
            return "map.fill"
        default:
            return icon
        }
    }
}

private struct MugshotTabItem: Identifiable {
    let index: Int
    let title: String
    let icon: String

    var id: Int { index }
}
