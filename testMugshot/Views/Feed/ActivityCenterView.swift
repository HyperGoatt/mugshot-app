import SwiftUI

struct ActivityBellButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: unreadCount > 0 ? "bell.fill" : "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .frame(width: 36, height: 36)
                    .background(Color.foamWhite, in: Circle())
                    .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))

                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, unreadCount > 9 ? 4 : 3)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Color.red.opacity(0.88), in: Capsule())
                        .offset(x: 4, y: -4)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Activity")
        .accessibilityValue(unreadCount == 0 ? "No unread activity" : "\(unreadCount) unread")
    }
}

struct ActivityCenterView: View {
    @ObservedObject var store: ActivityCenterStore
    @ObservedObject var router: ActivityDeepLinkRouter
    @ObservedObject var dataManager: DataManager
    @ObservedObject private var notificationCoordinator = NotificationDeviceCoordinator.shared
    let accountID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var path: [ActivityDeepLinkDestination] = []
    @State private var dismissedPushEducation = false

    var body: some View {
        NavigationStack(path: $path) {
            activityContent
                .background(Color.creamWhite)
                .navigationTitle("Activity")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if store.unreadCount > 0 {
                            Button("Read all") { Task { await store.markAllRead() } }
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .navigationDestination(for: ActivityDeepLinkDestination.self) { destination in
                    destinationView(destination)
                }
        }
        .task(id: accountID) {
            path = []
            await store.activate(accountID: accountID)
            dismissedPushEducation = UserDefaults.standard.bool(
                forKey: pushEducationDismissalKey
            )
            await notificationCoordinator.refreshPermission()
            handlePendingRoute()
        }
        .onChange(of: accountID) { _, _ in
            path = []
        }
        .onChange(of: router.pendingRoute?.id) { _, _ in
            handlePendingRoute()
        }
        .alert("Activity needs another try", isPresented: Binding(
            get: { store.actionError != nil },
            set: { if !$0 { store.clearActionError() } }
        )) {
            Button("OK", role: .cancel) { store.clearActionError() }
        } message: {
            Text(store.actionError ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var activityContent: some View {
        switch store.state {
        case .idle, .loading:
            ScrollView {
                MugshotLoadingState(layout: .journal, count: 5)
                    .padding(16)
            }
            .accessibilityLabel("Loading activity")
        case .failed(let message):
            VStack(spacing: 16) {
                MugshotStatusCard(
                    title: "Couldn’t load activity",
                    message: message,
                    systemImage: "wifi.exclamationmark"
                )
                Button("Try Again") { Task { await store.refresh() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.mugshotSage)
            }
            .padding(20)
        case .loaded:
            if store.events.isEmpty {
                ScrollView {
                    VStack(spacing: 14) {
                        if shouldShowPushEducation {
                            pushEducationCard
                        }
                        MugsyEmptyStateView(
                            placement: .friendsEmpty,
                            title: "All quiet for now",
                            message: "Friend posts, tags, invitations, likes, comments, and requests will collect here."
                        )
                    }
                    .padding(16)
                }
                .refreshable { await store.refresh() }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if shouldShowPushEducation {
                            pushEducationCard
                        }
                        ForEach(store.events) { event in
                            ActivityEventRow(event: event) {
                                open(event)
                            } onRemoveTag: {
                                Task { await store.removePrivateTag(event) }
                            }
                            .onAppear {
                                guard event.id == store.events.last?.id else { return }
                                Task { await store.loadMore() }
                            }
                        }

                        if store.isLoadingMore {
                            ProgressView("Loading older activity…")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.vertical, 14)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 18)
                }
                .refreshable { await store.refresh() }
            }
        }
    }

    private var pushEducationDismissalKey: String {
        "MugshotActivity.pushEducationDismissed.v1."
            + accountID.uuidString.lowercased()
    }

    private var shouldShowPushEducation: Bool {
        !dismissedPushEducation
            && notificationCoordinator.capability.isConfigured
            && notificationCoordinator.permissionState == .notRequested
    }

    private var pushEducationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Keep up with your coffee people", systemImage: "bell.badge.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text("Mugshot can give you a quiet heads-up for friend posts, tags, invitations, and conversations. In-app Activity always stays available.")
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Enable") {
                    Task { _ = await notificationCoordinator.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.mugshotSage)

                Button("Not now") {
                    dismissedPushEducation = true
                    UserDefaults.standard.set(true, forKey: pushEducationDismissalKey)
                }
                .buttonStyle(.bordered)
                .tint(.espressoBrown)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.mugshotMint.opacity(0.30))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func open(_ event: MugshotActivityEvent) {
        Task { await store.markRead(event) }
        guard let destination = event.destination, destination != .center else { return }
        path.append(destination)
    }

    private func handlePendingRoute() {
        guard let route = router.pendingRoute,
              route.accountID == accountID else { return }
        if route.destination == .center {
            router.consume(route, accountID: accountID)
            return
        }
        path = [route.destination]
        // The route stays durable until NavigationStack has accepted the path.
        DispatchQueue.main.async {
            guard path.last == route.destination else { return }
            router.consume(route, accountID: accountID)
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: ActivityDeepLinkDestination) -> some View {
        switch destination {
        case .center:
            EmptyView()
        case .visit(let visitID):
            ActivityVisitDestination(
                visitID: visitID,
                currentUserID: accountID,
                dataManager: dataManager
            )
        case .profile(let profileID):
            let actor = store.events.first { $0.actorUserID == profileID }
            PublicProfileView(
                route: PeopleProfileRoute(
                    id: profileID,
                    displayName: actor?.displayName ?? "Mugshot member",
                    username: actor?.actorUsername ?? "member"
                ),
                dataManager: dataManager,
                onRelationshipChanged: { await store.refresh() }
            )
        case .collaborativeLists:
            ScrollView {
                SharedCafeListsView(dataManager: dataManager, currentUserID: accountID)
                    .padding(16)
            }
            .background(Color.creamWhite)
            .navigationTitle("Cafe lists")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ActivityEventRow: View {
    let event: MugshotActivityEvent
    let onOpen: () -> Void
    let onRemoveTag: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        MugshotAvatar(
                            name: event.displayName,
                            size: 44,
                            imageURL: event.actorAvatarURL
                        )
                        Image(systemName: event.kind.systemImage)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 19, height: 19)
                            .background(Color.mugshotSage, in: Circle())
                            .overlay(Circle().stroke(Color.foamWhite, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(event.title)
                                .font(.system(size: 15, weight: event.isRead ? .semibold : .bold))
                                .foregroundColor(.espressoBrown)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Text(relativeTime)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.tertiaryText)
                        }
                        Text(event.body)
                            .font(.system(size: 13))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !event.isRead {
                        Circle()
                            .fill(Color.mugshotSage)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(event.destination == .center ? "" : "Opens this activity")

            if event.kind == .tag, event.canRemoveTag {
                Button("Remove tag", role: .destructive, action: onRemoveTag)
                    .font(.system(size: 12, weight: .bold))
                    .buttonStyle(.bordered)
                    .accessibilityHint("Removes your name from this MugShot without changing its audience")
            } else if event.kind == .collaborativeListInvitation {
                Button("Review cafe list", action: onOpen)
                    .font(.system(size: 12, weight: .bold))
                    .buttonStyle(.bordered)
                    .tint(.mugshotSage)
            }
        }
        .padding(14)
        .background(event.isRead ? Color.foamWhite : Color.mugshotMint.opacity(0.30))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: event.createdDate, relativeTo: Date())
    }

    private var accessibilityLabel: String {
        "\(event.isRead ? "Read" : "Unread"). \(event.title). \(event.body). \(relativeTime)"
    }
}

private struct ActivityVisitDestination: View {
    let visitID: UUID
    let currentUserID: UUID
    @ObservedObject var dataManager: DataManager

    @State private var summary: RemoteVisitSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let summary {
                RemoteVisitDetailView(
                    visitId: visitID,
                    initialSummary: summary,
                    currentUserId: currentUserID,
                    dataManager: dataManager
                )
            } else if isLoading {
                ProgressView("Opening MugShot…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    MugshotStatusCard(
                        title: "This MugShot isn’t available",
                        message: errorMessage ?? "It may have been deleted, made private, or hidden for safety.",
                        systemImage: "eye.slash.fill"
                    )
                    Button("Try Again") { Task { await load() } }
                        .buttonStyle(.bordered)
                        .tint(.mugshotSage)
                }
                .padding(20)
            }
        }
        .background(Color.creamWhite)
        .task(id: currentUserID) { await load() }
    }

    @MainActor
    private func load() async {
        let expectedAccountID = currentUserID
        isLoading = true
        errorMessage = nil
        summary = nil
        do {
            let service = VisitService(client: try SupabaseClientProvider.shared.client())
            let detail = try await service.fetchVisitDetail(
                visitId: visitID,
                currentUserId: expectedAccountID
            )
            guard currentUserID == expectedAccountID,
                  !Task.isCancelled else { return }
            summary = detail.summary
        } catch is CancellationError {
            return
        } catch {
            guard currentUserID == expectedAccountID else { return }
            summary = nil
            errorMessage = "Mugshot couldn’t open this post. It may no longer be visible to you."
        }
        if currentUserID == expectedAccountID {
            isLoading = false
        }
    }
}
