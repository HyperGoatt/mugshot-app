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
        case .sharedMugshots:
            SharedMugshotInvitationsView(accountID: accountID) {
                await store.refresh()
            }
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
            } else if event.kind == .sharedMugshotInvitation {
                Button("Review invitation", action: onOpen)
                    .font(.system(size: 12, weight: .bold))
                    .buttonStyle(.bordered)
                    .tint(.mugshotSage)
                    .accessibilityLabel("Review shared MugShot invitation from \(event.displayName)")
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

private struct SharedMugshotInvitationsView: View {
    let accountID: UUID
    let onChanged: () async -> Void

    @State private var memberships: [SharedMugshotMembership] = []
    @State private var ownedMugshots: [OwnedSharedMugshot] = []
    @State private var managedInvitations: [UUID: [ManagedSharedMugshotInvitation]] = [:]
    @State private var candidateVisits: [RemoteVisitSummary] = []
    @State private var isLoading = true
    @State private var workingIDs: Set<UUID> = []
    @State private var pickerRequest: SharedMugshotContributionPickerRequest?
    @State private var leaveTarget: SharedMugshotMembership?
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("A shared MugShot is a grouped view of posts each person owns. Joining never changes anyone’s original post or audience.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let statusMessage {
                    MugshotStatusCard(
                        title: "Shared MugShot updated",
                        message: statusMessage,
                        systemImage: "checkmark.circle.fill"
                    )
                }

                if isLoading && memberships.isEmpty && ownedMugshots.isEmpty {
                    MugshotLoadingState(layout: .journal, count: 3)
                } else if memberships.isEmpty && ownedMugshots.isEmpty {
                    MugsyEmptyStateView(
                        placement: .friendsEmpty,
                        title: "No shared MugShots yet",
                        message: "Invitations you receive and shared MugShots you start will be managed here."
                    )
                } else {
                    if !memberships.isEmpty {
                        MugshotSectionTitle(
                            title: "Your invitations",
                            subtitle: "Consent and your own post stay under your control."
                        )
                        ForEach(memberships) { membership in
                            membershipRow(membership)
                        }
                    }

                    if !ownedMugshots.isEmpty {
                        MugshotSectionTitle(
                            title: "Shared MugShots you started",
                            subtitle: "You can cancel invitations that are still pending."
                        )
                        ForEach(ownedMugshots) { mugshot in
                            managedMugshotRow(mugshot)
                        }
                    }
                }

                if let errorMessage {
                    MugshotStatusCard(
                        title: "Couldn’t update shared MugShots",
                        message: errorMessage,
                        systemImage: "wifi.exclamationmark"
                    )
                }
            }
            .padding(16)
        }
        .background(Color.creamWhite)
        .navigationTitle("Shared MugShots")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: accountID) { await load() }
        .onChange(of: accountID) { _, _ in
            memberships = []
            ownedMugshots = []
            managedInvitations = [:]
            candidateVisits = []
            workingIDs = []
            pickerRequest = nil
            leaveTarget = nil
            statusMessage = nil
            errorMessage = nil
        }
        .refreshable { await load() }
        .sheet(item: $pickerRequest) { request in
            SharedMugshotContributionPicker(request: request) { visit in
                await attach(visit, to: request.membership)
            }
        }
        .confirmationDialog(
            "Leave this shared MugShot?",
            isPresented: Binding(
                get: { leaveTarget != nil },
                set: { if !$0 { leaveTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Leave shared MugShot", role: .destructive) {
                guard let target = leaveTarget else { return }
                leaveTarget = nil
                Task { await leave(target) }
            }
            .accessibilityLabel(leaveConfirmationAccessibilityLabel)
            Button("Keep shared MugShot", role: .cancel) { leaveTarget = nil }
                .accessibilityLabel(keepSharedMugshotAccessibilityLabel)
        } message: {
            Text("Your MugShot stays intact with its existing audience. Only its grouped presentation is removed.")
        }
    }

    private func membershipRow(_ membership: SharedMugshotMembership) -> some View {
        let candidates = eligibleVisits(for: membership)
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                MugshotAvatar(
                    name: membership.inviterLabel,
                    size: 42,
                    imageURL: membership.relationshipAvailable
                        ? membership.inviterAvatarURL
                        : nil
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(membership.inviterLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text(membership.locationLabel?.remoteTrimmedNonEmpty
                         ?? "A shared coffee moment")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Text(membership.status == "pending" ? "Invited" : "Accepted")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.mugshotSageText)
            }

            if membership.status == "pending" {
                HStack(spacing: 10) {
                    Button("Decline", role: .destructive) {
                        Task { await respond(membership, accept: false) }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(
                        "Decline invitation to \(membershipAccessibilityContext(membership))"
                    )

                    if membership.relationshipAvailable {
                        Button("Accept invitation") {
                            Task { await respond(membership, accept: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mugshotSage)
                        .accessibilityLabel(
                            "Accept invitation to \(membershipAccessibilityContext(membership))"
                        )
                    }
                }
                .disabled(workingIDs.contains(membership.id))
            } else if membership.status == "accepted" {
                Text(candidates.isEmpty
                     ? "Your consent is recorded. A matching completed MugShot is needed before this can appear as a group."
                     : "Choose one of your matching completed MugShots. It keeps its own audience and can be changed later.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if !candidates.isEmpty, membership.relationshipAvailable {
                        Button("Choose your MugShot") {
                            pickerRequest = SharedMugshotContributionPickerRequest(
                                membership: membership,
                                candidates: candidates
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mugshotSage)
                        .accessibilityLabel(
                            "Choose your MugShot for \(membershipAccessibilityContext(membership))"
                        )
                    }
                    Button("Leave", role: .destructive) {
                        leaveTarget = membership
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Leave \(membershipAccessibilityContext(membership))")
                }
                .disabled(workingIDs.contains(membership.id))
            }
        }
        .padding(14)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private func managedMugshotRow(_ mugshot: OwnedSharedMugshot) -> some View {
        let pending = (managedInvitations[mugshot.id] ?? []).filter(\.canCancel)
        return VStack(alignment: .leading, spacing: 11) {
            Label(
                mugshot.locationLabel?.remoteTrimmedNonEmpty ?? "Shared coffee moment",
                systemImage: "person.2.wave.2.fill"
            )
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.espressoBrown)

            if pending.isEmpty {
                Text("No invitations to manage.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            } else {
                ForEach(pending) { invitation in
                    HStack(spacing: 10) {
                        MugshotAvatar(
                            name: invitation.personLabel,
                            size: 34,
                            imageURL: invitation.avatarURL
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invitation.personLabel)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            Text("Pending")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondaryText)
                        }
                        Spacer()
                        Button("Cancel", role: .destructive) {
                            Task { await cancel(invitation) }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .buttonStyle(.bordered)
                        .disabled(workingIDs.contains(invitation.id))
                        .accessibilityLabel(
                            managedInvitationAccessibilityLabel(invitation, mugshot: mugshot)
                        )
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private func eligibleVisits(
        for membership: SharedMugshotMembership
    ) -> [RemoteVisitSummary] {
        SharedMugshotContributionEligibility.eligibleVisits(
            from: candidateVisits,
            for: membership,
            ownerID: accountID
        )
    }

    private func membershipAccessibilityContext(
        _ membership: SharedMugshotMembership
    ) -> String {
        if let location = membership.locationLabel?.remoteTrimmedNonEmpty {
            return "the shared MugShot with \(membership.inviterLabel) at \(location)"
        }
        return "the shared MugShot with \(membership.inviterLabel)"
    }

    private func managedInvitationAccessibilityLabel(
        _ invitation: ManagedSharedMugshotInvitation,
        mugshot: OwnedSharedMugshot
    ) -> String {
        if let location = mugshot.locationLabel?.remoteTrimmedNonEmpty {
            return "Cancel shared MugShot invitation to \(invitation.personLabel) at \(location)"
        }
        return "Cancel shared MugShot invitation to \(invitation.personLabel)"
    }

    private var leaveConfirmationAccessibilityLabel: String {
        guard let leaveTarget else { return "Confirm leaving shared MugShot" }
        return "Confirm leaving \(membershipAccessibilityContext(leaveTarget))"
    }

    private var keepSharedMugshotAccessibilityLabel: String {
        guard let leaveTarget else { return "Keep shared MugShot" }
        return "Keep \(membershipAccessibilityContext(leaveTarget))"
    }

    @MainActor
    private func load() async {
        let expectedAccountID = accountID
        isLoading = true
        defer {
            if accountID == expectedAccountID {
                isLoading = false
            }
        }
        do {
            let client = try SupabaseClientProvider.shared.client()
            let activity = ActivityService(client: client)
            async let loadedMemberships = activity.sharedMugshotMemberships(
                accountID: expectedAccountID
            )
            async let loadedOwned = activity.ownedSharedMugshots(
                accountID: expectedAccountID
            )
            async let loadedVisits = VisitService(client: client).fetchRecentVisits(
                userId: accountID,
                limit: 100
            )
            let (resolvedMemberships, resolvedOwned, resolvedVisits) = try await (
                loadedMemberships,
                loadedOwned,
                loadedVisits
            )
            guard accountID == expectedAccountID,
                  !Task.isCancelled else { return }

            var rosters: [UUID: [ManagedSharedMugshotInvitation]] = [:]
            for mugshot in resolvedOwned {
                rosters[mugshot.id] = try await activity.managedInvitations(
                    sharedMugshotID: mugshot.id,
                    accountID: expectedAccountID
                )
                guard accountID == expectedAccountID,
                      !Task.isCancelled else { return }
            }

            memberships = resolvedMemberships
            ownedMugshots = resolvedOwned
            candidateVisits = resolvedVisits
            managedInvitations = rosters
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard accountID == expectedAccountID else { return }
            errorMessage = "Mugshot couldn’t load shared MugShots. Your posts and invitations are unchanged—try again when you’re online."
        }
    }

    @MainActor
    private func respond(_ membership: SharedMugshotMembership, accept: Bool) async {
        let expectedAccountID = accountID
        workingIDs.insert(membership.id)
        defer {
            if accountID == expectedAccountID {
                workingIDs.remove(membership.id)
            }
        }
        do {
            _ = try await activityService().respondToSharedMugshotInvitation(
                invitationID: membership.id,
                accept: accept,
                accountID: expectedAccountID
            )
            guard accountID == expectedAccountID else { return }
            let candidates = eligibleVisits(for: membership)
            await load()
            await onChanged()
            errorMessage = nil
            if accept {
                statusMessage = candidates.isEmpty
                    ? "Invitation accepted. Your posts remain separate until you choose a matching completed MugShot."
                    : "Invitation accepted. Choose the MugShot you want to contribute."
                if !candidates.isEmpty {
                    pickerRequest = SharedMugshotContributionPickerRequest(
                        membership: membership,
                        candidates: candidates
                    )
                }
            } else {
                statusMessage = "Invitation declined. No post or audience was changed."
            }
        } catch {
            guard accountID == expectedAccountID else { return }
            errorMessage = accept
                ? "That invitation is no longer available to accept. No post was changed."
                : "Mugshot couldn’t decline that invitation yet. Your posts are unchanged."
        }
    }

    @MainActor
    private func attach(
        _ visit: RemoteVisitSummary,
        to membership: SharedMugshotMembership
    ) async -> String? {
        let expectedAccountID = accountID
        guard SharedMugshotContributionEligibility.isEligible(
            visit: visit.visit,
            contextType: membership.contextType,
            cafeID: membership.cafeID,
            occurredAt: membership.occurredAt,
            ownerID: accountID
        ) else {
            return "That MugShot is not eligible for this shared moment. Nothing was changed."
        }
        do {
            _ = try await activityService().attachSharedMugshotContribution(
                sharedMugshotID: membership.sharedMemoryID,
                visitID: visit.id,
                accountID: expectedAccountID
            )
            guard accountID == expectedAccountID else { return nil }
            statusMessage = "Your MugShot is now part of the grouped view. Its original audience is unchanged."
            errorMessage = nil
            await load()
            await onChanged()
            return nil
        } catch {
            guard accountID == expectedAccountID else { return nil }
            return "That MugShot couldn’t be added. It may already anchor another shared MugShot, or the invitation may have changed."
        }
    }

    @MainActor
    private func cancel(_ invitation: ManagedSharedMugshotInvitation) async {
        let expectedAccountID = accountID
        guard invitation.canCancel else { return }
        workingIDs.insert(invitation.id)
        defer {
            if accountID == expectedAccountID {
                workingIDs.remove(invitation.id)
            }
        }
        do {
            guard try await activityService().cancelSharedMugshotInvitation(
                invitationID: invitation.id,
                accountID: expectedAccountID
            ) else {
                guard accountID == expectedAccountID else { return }
                errorMessage = "That invitation was already answered or cancelled."
                await load()
                return
            }
            guard accountID == expectedAccountID else { return }
            statusMessage = "Invitation cancelled. Existing posts and audiences were not changed."
            errorMessage = nil
            await load()
            await onChanged()
        } catch {
            guard accountID == expectedAccountID else { return }
            errorMessage = "Mugshot couldn’t cancel that invitation yet. Please try again."
        }
    }

    @MainActor
    private func leave(_ membership: SharedMugshotMembership) async {
        let expectedAccountID = accountID
        workingIDs.insert(membership.id)
        defer {
            if accountID == expectedAccountID {
                workingIDs.remove(membership.id)
            }
        }
        do {
            guard try await activityService().leaveSharedMugshot(
                sharedMugshotID: membership.sharedMemoryID,
                accountID: expectedAccountID
            ) else {
                guard accountID == expectedAccountID else { return }
                errorMessage = "You had already left this shared MugShot."
                await load()
                return
            }
            guard accountID == expectedAccountID else { return }
            statusMessage = "You left the shared MugShot. Your independent post and its audience are unchanged."
            errorMessage = nil
            await load()
            await onChanged()
        } catch {
            guard accountID == expectedAccountID else { return }
            errorMessage = "Mugshot couldn’t leave that shared MugShot yet. Your post is unchanged."
        }
    }

    private func activityService() throws -> ActivityService {
        ActivityService(client: try SupabaseClientProvider.shared.client())
    }
}

private struct SharedMugshotContributionPickerRequest: Identifiable {
    let membership: SharedMugshotMembership
    let candidates: [RemoteVisitSummary]
    var id: UUID { membership.id }
}

private struct SharedMugshotContributionPicker: View {
    let request: SharedMugshotContributionPickerRequest
    let onAttach: (RemoteVisitSummary) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("Only your completed primary MugShots that match this moment are available. The selected post keeps its existing audience.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(request.candidates) { visit in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                PhotoThumbnailView(
                                    photoPath: visit.visit.posterPhotoURL,
                                    size: 58
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(visit.visit.drinkDisplayName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.espressoBrown)
                                    Text(visit.locationTitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondaryText)
                                    Text(visit.visit.createdAtDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.tertiaryText)
                                    Text("Score \(visit.displayedMugshotScore.formatted(.number.precision(.fractionLength(1))))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.mugshotSageText)
                                }
                                Spacer()
                            }
                            Button(selectedID == visit.id ? "Adding…" : "Use this MugShot") {
                                Task { await attach(visit) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.mugshotSage)
                            .disabled(selectedID != nil)
                        }
                        .padding(14)
                        .cardStyle()
                    }

                    if let errorMessage {
                        MugshotStatusCard(
                            title: "Couldn’t add that MugShot",
                            message: errorMessage,
                            systemImage: "exclamationmark.triangle.fill"
                        )
                    }
                }
                .padding(16)
            }
            .background(Color.creamWhite)
            .navigationTitle("Choose your MugShot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func attach(_ visit: RemoteVisitSummary) async {
        selectedID = visit.id
        defer { selectedID = nil }
        if let message = await onAttach(visit) {
            errorMessage = message
        } else {
            dismiss()
        }
    }
}
