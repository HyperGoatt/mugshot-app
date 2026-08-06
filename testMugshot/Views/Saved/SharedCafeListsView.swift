import MapKit
import SwiftUI

struct SharedCafeListsView: View {
    @ObservedObject var dataManager: DataManager
    let currentUserID: UUID

    @State private var lists: [CollaborativeCafeList] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var activeSheet: RootSheet?
    @State private var invitationActionID: UUID?
    @State private var stateAccountID: UUID?
    @State private var activeLoadRequestID: UUID?

    private var invitations: [CollaborativeCafeList] {
        accountScopedLists.filter { $0.accessKind == .pendingInvitation }
    }

    private var availableLists: [CollaborativeCafeList] {
        accountScopedLists.filter { $0.accessKind != .pendingInvitation }
    }

    private var accountScopedLists: [CollaborativeCafeList] {
        stateAccountID == currentUserID ? lists : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                MugshotSectionTitle(
                    title: "Cafe lists",
                    subtitle: "Save a route, plan a trip, or build one together."
                )
                Spacer(minLength: 8)
                Button {
                    activeSheet = .create(accountID: currentUserID)
                } label: {
                    Label("New list", systemImage: "plus")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.bordered)
                .tint(Color.mugshotSage)
                .accessibilityHint("Creates a private or shared cafe list")
            }

            if DiscoveryFeatureFlags.isEnabled(.publicLists) {
                PublicCafeListsSection(
                    dataManager: dataManager,
                    currentUserID: currentUserID
                )
            }

            if stateAccountID != currentUserID || (isLoading && !hasLoaded) {
                MugshotLoadingState(layout: .collection, count: 3)
            } else if let errorMessage, !hasLoaded {
                MugshotRecoveryCard(
                    title: "Cafe lists need another try",
                    message: errorMessage,
                    actionTitle: "Try again"
                ) {
                    Task { await load(for: currentUserID) }
                }
            } else {
                if !invitations.isEmpty {
                    invitationSection
                }

                if availableLists.isEmpty {
                    emptyState
                } else {
                    listCarousel
                }

                if let errorMessage {
                    InlineCafeListNotice(
                        title: "Couldn’t refresh cafe lists",
                        message: errorMessage,
                        actionTitle: "Try again"
                    ) {
                        Task { await load(for: currentUserID) }
                    }
                }
            }
        }
        .onChange(of: currentUserID) { _, accountID in
            resetStateIfNeeded(for: accountID)
        }
        .task(id: currentUserID) { await load(for: currentUserID) }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case let .create(accountID):
                CafeListEditorSheet(mode: .create, accountID: accountID) { created in
                    guard accountID == currentUserID,
                          accountID == stateAccountID else { return }
                    activeSheet = nil
                    lists.removeAll { $0.id == created.id }
                    lists.insert(created, at: 0)
                }
            }
        }
    }

    private var invitationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: "Invitations",
                subtitle: "You choose whether to join each shared list."
            )

            ForEach(invitations) { list in
                CafeListInvitationCard(
                    list: list,
                    actionsDisabled: invitationActionID != nil,
                    showsProgress: invitationActionID == list.id,
                    onDecline: { Task { await respond(to: list, accept: false) } },
                    onAccept: { Task { await respond(to: list, accept: true) } }
                )
            }
        }
    }

    private var listCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(availableLists) { list in
                    NavigationLink {
                        CollaborativeCafeListDetailView(
                            initialList: list,
                            dataManager: dataManager,
                            currentUserID: currentUserID,
                            onRemoved: {
                                lists.removeAll { $0.id == list.id }
                            },
                            onUpdated: { updated in
                                if let index = lists.firstIndex(where: { $0.id == updated.id }) {
                                    lists[index] = updated
                                }
                            }
                        )
                    } label: {
                        CollaborativeCafeListTile(list: list)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
            .padding(.bottom, 6)
        }
    }

    private var emptyState: some View {
        Button {
            activeSheet = .create(accountID: currentUserID)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 44, height: 44)
                    .background(Color.mugshotSage.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start a cafe list")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text("Try a neighborhood crawl, a trip, or a coffee date list.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .foregroundColor(.tertiaryText)
            }
            .padding(14)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func load(for accountID: UUID) async {
        guard accountID == currentUserID else { return }
        resetStateIfNeeded(for: accountID)

        let scope = CollaborativeCafeListLoadScope(
            accountID: accountID,
            requestID: UUID()
        )
        activeLoadRequestID = scope.requestID
        isLoading = true
        defer {
            if scope.canApply(
                currentAccountID: currentUserID,
                activeRequestID: activeLoadRequestID
            ) {
                activeLoadRequestID = nil
                isLoading = false
            }
        }
        do {
            let service = CollaborativeCafeListService(
                client: try SupabaseClientProvider.shared.client()
            )
            let loadedLists = try await service.lists(accountID: accountID)
            try Task.checkCancellation()
            guard scope.canApply(
                currentAccountID: currentUserID,
                activeRequestID: activeLoadRequestID
            ), stateAccountID == accountID else { return }
            lists = loadedLists
            await PendingPlaceImportQueue.shared.cacheEligibleLists(
                loadedLists
                    .filter { $0.accessKind != .pendingInvitation }
                    .map {
                        ShareExtensionCafeListCacheEntry(
                            id: $0.id,
                            title: $0.title,
                            accountID: accountID,
                            canEdit: $0.canEditItems
                        )
                    }
            )
            hasLoaded = true
            errorMessage = nil
        } catch CollaborativeCafeListServiceError.accountScopeMismatch,
                is CancellationError {
            return
        } catch {
            guard scope.canApply(
                currentAccountID: currentUserID,
                activeRequestID: activeLoadRequestID
            ), stateAccountID == accountID else { return }
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func respond(to list: CollaborativeCafeList, accept: Bool) async {
        let accountID = currentUserID
        guard stateAccountID == accountID else { return }
        guard invitationActionID == nil else { return }
        invitationActionID = list.id
        defer {
            if currentUserID == accountID, invitationActionID == list.id {
                invitationActionID = nil
            }
        }
        do {
            let service = CollaborativeCafeListService(
                client: try SupabaseClientProvider.shared.client()
            )
            try await service.respond(
                to: list.id,
                accept: accept,
                accountID: accountID
            )
            guard currentUserID == accountID,
                  stateAccountID == accountID else { return }
            await loadAfterMutation(for: accountID)
        } catch CollaborativeCafeListServiceError.accountScopeMismatch,
                is CancellationError {
            return
        } catch {
            guard currentUserID == accountID,
                  stateAccountID == accountID else { return }
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func loadAfterMutation(for accountID: UUID) async {
        guard currentUserID == accountID,
              stateAccountID == accountID else { return }
        await load(for: accountID)
    }

    @MainActor
    private func resetStateIfNeeded(for accountID: UUID) {
        guard stateAccountID != accountID else { return }
        stateAccountID = accountID
        activeLoadRequestID = nil
        lists = []
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        activeSheet = nil
        invitationActionID = nil
    }
}

private enum RootSheet: Identifiable {
    case create(accountID: UUID)

    var id: UUID {
        switch self {
        case let .create(accountID): accountID
        }
    }
}

private struct CafeListInvitationCard: View {
    let list: CollaborativeCafeList
    let actionsDisabled: Bool
    let showsProgress: Bool
    let onDecline: () -> Void
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                MugshotAvatar(
                    name: list.inviter?.visibleName ?? list.owner.visibleName,
                    size: 42,
                    imageURL: list.inviter?.avatarURL ?? list.owner.avatarURL
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(list.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text(invitationDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                Spacer(minLength: 4)
                Image(systemName: list.invitedRole == "editor" ? "pencil.and.list.clipboard" : "eye.fill")
                    .foregroundColor(.mugshotSage)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 9) {
                Button("Decline", action: onDecline)
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Decline invitation to \(list.title)")
                    .accessibilityHint("Removes this invitation")
                Button("Join", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .tint(.mugshotSage)
                    .accessibilityLabel("Join \(list.title)")
                    .accessibilityHint(joinAccessibilityHint)
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Responding to invitation to \(list.title)")
                }
                Spacer()
            }
            .font(.system(size: 13, weight: .bold))
            .disabled(actionsDisabled)
        }
        .padding(14)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private var invitationDescription: String {
        let inviter = list.inviter?.visibleName ?? list.owner.visibleName
        let role = list.invitedRole == "editor"
            ? "add, remove, and reorder cafes"
            : "view the list"
        return "\(inviter) invited you to \(role). Cafe details stay hidden until you join."
    }

    private var joinAccessibilityHint: String {
        list.invitedRole == "editor"
            ? "Accepts the invitation as an editor"
            : "Accepts the invitation as a viewer"
    }
}

private struct CollaborativeCafeListTile: View {
    let list: CollaborativeCafeList

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                if let photoURL = list.previewPhotoURL?.remoteTrimmedNonEmpty {
                    RemotePhotoImageView(
                        urlString: photoURL,
                        placeholderSystemName: "map.fill",
                        contentMode: .fill
                    )
                } else {
                    LinearGradient(
                        colors: [Color.mugshotMint.opacity(0.84), Color.mugshotSage.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(alignment: .trailing) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundColor(.foamWhite.opacity(0.17))
                            .padding(.trailing, 18)
                    }
                }

                Label(list.visibility.title, systemImage: visibilityIcon)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.foamWhite)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Color.espressoBrown.opacity(0.62), in: Capsule())
                    .padding(10)
            }
            .frame(minHeight: 92)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(list.title)
                .font(.headline.weight(.bold))
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            countLabels
                        }
                        Text(list.roleTitle)
                    }
                } else {
                    HStack(spacing: 10) {
                        countLabels
                        Spacer()
                        Text(list.roleTitle)
                    }
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            if let address = list.previewAddress?.remoteTrimmedNonEmpty {
                Label(address, systemImage: "mappin.circle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: tileWidth, alignment: .leading)
        .frame(minHeight: 222, alignment: .topLeading)
        .padding(12)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens this cafe list")
    }

    @ViewBuilder
    private var countLabels: some View {
        Label("\(list.cafeCount)", systemImage: "cup.and.saucer.fill")
        if list.collaboratorCount > 0 {
            Label("\(list.collaboratorCount)", systemImage: "person.2.fill")
        }
    }

    private var tileWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 260 : 198
    }

    private var accessibilitySummary: String {
        var parts = [
            list.title,
            "\(list.visibility.title) list",
            "\(list.cafeCount) \(list.cafeCount == 1 ? "cafe" : "cafes")"
        ]
        if list.collaboratorCount > 0 {
            parts.append(
                "\(list.collaboratorCount) \(list.collaboratorCount == 1 ? "collaborator" : "collaborators")"
            )
        }
        parts.append(list.roleTitle)
        if let address = list.previewAddress?.remoteTrimmedNonEmpty {
            parts.append(address)
        }
        return parts.joined(separator: ", ")
    }

    private var visibilityIcon: String {
        switch list.visibility {
        case .private: "lock.fill"
        case .friends: "person.2.fill"
        case .invited: "person.crop.circle.badge.checkmark"
        case .public: "globe.americas.fill"
        }
    }
}

private struct CollaborativeCafeListDetailView: View {
    let initialList: CollaborativeCafeList
    @ObservedObject var dataManager: DataManager
    let currentUserID: UUID
    let onRemoved: () -> Void
    let onUpdated: (CollaborativeCafeList) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var list: CollaborativeCafeList
    @State private var isLoading = true
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var activeSheet: DetailSheet?
    @State private var confirmation: DetailConfirmation?
    @State private var presentedCafe: Cafe?

    init(
        initialList: CollaborativeCafeList,
        dataManager: DataManager,
        currentUserID: UUID,
        onRemoved: @escaping () -> Void,
        onUpdated: @escaping (CollaborativeCafeList) -> Void
    ) {
        self.initialList = initialList
        self.dataManager = dataManager
        self.currentUserID = currentUserID
        self.onRemoved = onRemoved
        self.onUpdated = onUpdated
        _list = State(initialValue: initialList)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MugshotScreenHeader(list.title, subtitle: list.description ?? list.visibility.title)

                summaryMetrics
                    .padding(.horizontal, 16)

                if !list.socialActionsAvailable {
                    InlineCafeListNotice(
                        title: "This list is view-only right now",
                        message: "Your current account status keeps social changes paused. Your cafes are still visible."
                    )
                    .padding(.horizontal, 16)
                }

                if let statusMessage {
                    InlineCafeListNotice(
                        title: "Cafe list updated",
                        message: statusMessage,
                        style: .success
                    )
                    .padding(.horizontal, 16)
                }

                if let errorMessage {
                    InlineCafeListNotice(
                        title: "That change needs another try",
                        message: errorMessage,
                        actionTitle: "Reload"
                    ) {
                        Task { await load() }
                    }
                    .padding(.horizontal, 16)
                }

                if isLoading, list.items == nil {
                    MugshotLoadingState(layout: .journal, count: 3)
                        .padding(.horizontal, 16)
                } else if !list.canViewItems {
                    invitationPrivacyState
                        .padding(.horizontal, 16)
                } else {
                    detailContent
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.creamWhite)
        .navigationTitle("Cafe list")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task(id: list.id) { await load() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addCafe:
                CafeListCafePicker(
                    dataManager: dataManager,
                    existingCafeIDs: Set(list.resolvedItems.map(\.cafeID)),
                    currentUserID: currentUserID
                ) { cafe in
                    Task { await add(cafe) }
                }
            case .invite:
                CafeListFriendPicker(
                    existingMemberIDs: Set(list.resolvedMembers.compactMap { $0.person.userID })
                ) { friend, role in
                    try await invite(friend: friend, role: role)
                }
            case .edit:
                CafeListEditorSheet(mode: .edit(list), accountID: currentUserID) { updated in
                    activeSheet = nil
                    apply(updated)
                }
            case .transfer:
                CafeListTransferSheet(
                    list: list,
                    onTransfer: { userID in try await transfer(to: userID) }
                )
            }
        }
        .sheet(item: $presentedCafe) { cafe in
            CafeDetailView(cafe: cafe, dataManager: dataManager)
        }
        .alert(item: $confirmation) { confirmation in
            Alert(
                title: Text(confirmation.title),
                message: Text(confirmation.message),
                primaryButton: .destructive(Text(confirmation.actionTitle)) {
                    Task { await perform(confirmation) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if list.canManage || list.canLeave {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if list.canManage {
                        Button {
                            activeSheet = .edit
                        } label: {
                            Label("Edit list", systemImage: "pencil")
                        }
                        if list.canTransfer {
                            Button {
                                activeSheet = .transfer
                            } label: {
                                Label("Transfer ownership", systemImage: "person.2.arrow.trianglehead.counterclockwise")
                            }
                        }
                        Button(role: .destructive) {
                            confirmation = .deleteList
                        } label: {
                            Label("Delete list", systemImage: "trash")
                        }
                    }
                    if list.canLeave {
                        Button(role: .destructive) {
                            confirmation = .leaveList
                        } label: {
                            Label("Leave list", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(isMutating)
                .accessibilityLabel("Cafe list actions")
            }
        }
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if list.resolvedItems.contains(where: { $0.coordinate != nil }) {
                HydratedCafeListMapPreview(items: list.resolvedItems)
                    .padding(.horizontal, 16)
            }

            if list.canEditItems || list.canManage {
                HStack(spacing: 10) {
                    if list.canEditItems {
                        Button {
                            activeSheet = .addCafe
                        } label: {
                            Label("Add cafe", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mugshotSage)
                    }
                    if list.canManage {
                        Button {
                            activeSheet = .invite
                        } label: {
                            Label("Invite", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .tint(.mugshotSage)
                    }
                    if isMutating { ProgressView().controlSize(.small) }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .disabled(isMutating)
            }

            cafeSection
            collaboratorSection
        }
    }

    private var cafeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: "Cafes",
                subtitle: list.canEditItems
                    ? "Editors can add, remove, and reorder stops."
                    : "Your shared route, in order."
            )
            .padding(.horizontal, 16)

            if list.resolvedItems.isEmpty {
                MugsyEmptyStateView(
                    placement: .sharedLists,
                    title: "No cafes yet",
                    message: list.canEditItems
                        ? "Add the first cafe to begin this list."
                        : "An editor hasn’t added a cafe yet."
                )
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(list.resolvedItems.enumerated()), id: \.element.id) { index, item in
                        CollaborativeCafeListItemRow(
                            item: item,
                            index: index,
                            itemCount: list.resolvedItems.count,
                            canEdit: list.canEditItems,
                            isWorking: isMutating,
                            onOpen: { presentedCafe = item.localCafe },
                            onMoveUp: { Task { await move(item, to: index - 1) } },
                            onMoveDown: { Task { await move(item, to: index + 1) } },
                            onRemove: { confirmation = .removeItem(item.id, item.cafeName) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var collaboratorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: "People",
                subtitle: list.canManage
                    ? "Owners manage roles; invitations require acceptance."
                    : "People who accepted this list."
            )
            .padding(.horizontal, 16)

            CafeListOwnerRow(owner: list.owner)
                .padding(.horizontal, 16)

            ForEach(Array(list.resolvedMembers.enumerated()), id: \.offset) { _, member in
                CafeListMemberRow(
                    member: member,
                    isWorking: isMutating,
                    onSetRole: { role in Task { await setRole(member, role: role) } },
                    onRemove: {
                        guard let userID = member.person.userID else { return }
                        confirmation = member.isPending
                            ? .cancelInvitation(userID, member.person.visibleName)
                            : .removeMember(userID, member.person.visibleName)
                    }
                )
                .padding(.horizontal, 16)
            }

            if list.resolvedMembers.isEmpty {
                Text("Only you are on this list. Invite a friend when you’re ready to plan together.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var summaryMetrics: some View {
        HStack(spacing: 9) {
            metric("\(list.cafeCount)", label: list.cafeCount == 1 ? "cafe" : "cafes", icon: "cup.and.saucer.fill")
            metric("\(list.collaboratorCount)", label: "collaborators", icon: "person.2.fill")
            metric(list.roleTitle, label: "your access", icon: roleIcon)
        }
    }

    private var invitationPrivacyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.mugshotSage)
            Text("Cafe details stay private until you join")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text("Return to Cafe lists to accept or decline this invitation. MugShot won’t add you automatically.")
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .cardStyle()
    }

    private var roleIcon: String {
        switch list.currentRole {
        case "owner": "crown.fill"
        case "editor": "pencil"
        default: "eye.fill"
        }
    }

    private func metric(_ value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(value, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.sandBeige.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await makeService().list(
                id: list.id,
                accountID: currentUserID
            )
            apply(loaded)
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func reloadAfterMutation(message: String) async {
        do {
            let loaded = try await makeService().list(
                id: list.id,
                accountID: currentUserID
            )
            apply(loaded)
            statusMessage = message
            errorMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func add(_ cafe: Cafe) async {
        guard !isMutating else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            let client = try SupabaseClientProvider.shared.client()
            let remoteCafe = try await CafeService(client: client).findOrCreateCafe(from: cafe)
            dataManager.upsertRemoteCafe(remoteCafe)
            try await CollaborativeCafeListService(client: client).add(
                cafeID: remoteCafe.id,
                to: list.id,
                accountID: currentUserID
            )
            activeSheet = nil
            await reloadAfterMutation(message: "\(remoteCafe.name) was added.")
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    private func invite(friend: SocialConnection, role: String) async throws {
        try await makeService().invite(
            userID: friend.userID,
            to: list.id,
            role: role,
            accountID: currentUserID
        )
        await reloadAfterMutation(message: "Invitation sent to \(friend.displayName).")
    }

    private func transfer(to userID: UUID) async throws {
        let updated = try await makeService().transfer(
            listID: list.id,
            to: userID,
            accountID: currentUserID
        )
        await MainActor.run {
            activeSheet = nil
            apply(updated)
            statusMessage = "Ownership was transferred. You’re now an editor."
        }
    }

    @MainActor
    private func move(_ item: CollaborativeCafeListItem, to position: Int) async {
        guard !isMutating, position >= 0, position < list.resolvedItems.count else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            try await makeService().move(
                itemID: item.id,
                to: position,
                accountID: currentUserID
            )
            await reloadAfterMutation(message: "Cafe order updated.")
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func setRole(_ member: CollaborativeCafeListMember, role: String) async {
        guard !isMutating, let userID = member.person.userID else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            try await makeService().setRole(
                listID: list.id,
                userID: userID,
                role: role,
                accountID: currentUserID
            )
            await reloadAfterMutation(message: "\(member.person.visibleName) is now a\(role == "editor" ? "n" : "") \(role).")
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func perform(_ confirmation: DetailConfirmation) async {
        guard !isMutating else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            let service = try makeService()
            switch confirmation {
            case .removeItem(let itemID, let name):
                try await service.remove(itemID: itemID, accountID: currentUserID)
                await reloadAfterMutation(message: "\(name) was removed from this list.")
            case .removeMember(let userID, let name):
                try await service.removeMember(
                    listID: list.id,
                    userID: userID,
                    accountID: currentUserID
                )
                await reloadAfterMutation(message: "\(name) was removed from this list.")
            case .cancelInvitation(let userID, let name):
                try await service.cancelInvitation(
                    listID: list.id,
                    userID: userID,
                    accountID: currentUserID
                )
                await reloadAfterMutation(message: "\(name)’s invitation was cancelled.")
            case .leaveList:
                try await service.leave(listID: list.id, accountID: currentUserID)
                onRemoved()
                dismiss()
            case .deleteList:
                try await service.delete(listID: list.id, accountID: currentUserID)
                onRemoved()
                dismiss()
            }
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func apply(_ updated: CollaborativeCafeList) {
        list = updated
        onUpdated(updated)
    }

    private func makeService() throws -> CollaborativeCafeListService {
        CollaborativeCafeListService(client: try SupabaseClientProvider.shared.client())
    }
}

private enum DetailSheet: String, Identifiable {
    case addCafe
    case invite
    case edit
    case transfer
    var id: String { rawValue }
}

private enum DetailConfirmation: Identifiable {
    case removeItem(UUID, String)
    case removeMember(UUID, String)
    case cancelInvitation(UUID, String)
    case leaveList
    case deleteList

    var id: String {
        switch self {
        case .removeItem(let id, _): "remove-item-\(id)"
        case .removeMember(let id, _): "remove-member-\(id)"
        case .cancelInvitation(let id, _): "cancel-invitation-\(id)"
        case .leaveList: "leave"
        case .deleteList: "delete"
        }
    }

    var title: String {
        switch self {
        case .removeItem(_, let name): "Remove \(name)?"
        case .removeMember(_, let name): "Remove \(name)?"
        case .cancelInvitation(_, let name): "Cancel \(name)’s invitation?"
        case .leaveList: "Leave this cafe list?"
        case .deleteList: "Delete this cafe list?"
        }
    }

    var message: String {
        switch self {
        case .removeItem:
            "The cafe leaves the shared route. It stays in everyone’s personal journal and Saved areas."
        case .removeMember:
            "They’ll lose access, but cafes they added stay on the list with privacy-safe provenance."
        case .cancelInvitation:
            "They won’t be able to accept this invitation. You can invite them again later."
        case .leaveList:
            "You’ll lose access. Cafes you added remain on the shared list."
        case .deleteList:
            "The list, its invitations, and its ordering will be permanently removed. Personal cafe saves and journal entries are not affected."
        }
    }

    var actionTitle: String {
        switch self {
        case .removeItem, .removeMember: "Remove"
        case .cancelInvitation: "Cancel invitation"
        case .leaveList: "Leave"
        case .deleteList: "Delete"
        }
    }
}

private struct CollaborativeCafeListItemRow: View {
    let item: CollaborativeCafeListItem
    let index: Int
    let itemCount: Int
    let canEdit: Bool
    let isWorking: Bool
    let onOpen: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Group {
                        if let photoURL = item.photoURL?.remoteTrimmedNonEmpty {
                            RemotePhotoImageView(
                                urlString: photoURL,
                                placeholderSystemName: "cup.and.saucer.fill",
                                contentMode: .fill
                            )
                        } else {
                            MugsyPhotoPlaceholderView(
                                scene: MugsySceneResolver.cafePhoto(
                                    stableID: item.cafeID.uuidString,
                                    origin: .sharedList,
                                    isFavorite: item.isFavorite,
                                    wantToTry: item.wantToTry,
                                    hasVisited: false
                                ),
                                style: .thumbnail,
                                photoDescription: "No cafe photo yet"
                            )
                        }
                    }
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.cafeName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .multilineTextAlignment(.leading)
                        if let location = item.displayLocation {
                            Text(location)
                                .font(.system(size: 11))
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                        if let note = item.note?.remoteTrimmedNonEmpty {
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(.secondaryText)
                                .lineLimit(2)
                        }
                        HStack(spacing: 6) {
                            Text("Added by \(item.contributor.attributionName)")
                            if item.isFavorite { Label("Favorite", systemImage: "heart.fill") }
                            if item.wantToTry { Label("Want to Try", systemImage: "bookmark.fill") }
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(openAccessibilityLabel)
            .accessibilityHint("Opens cafe details")

            if canEdit {
                Menu {
                    Button(action: onMoveUp) {
                        Label("Move earlier", systemImage: "arrow.up")
                    }
                    .disabled(index == 0)
                    .accessibilityLabel("Move \(item.cafeName) earlier")
                    Button(action: onMoveDown) {
                        Label("Move later", systemImage: "arrow.down")
                    }
                    .disabled(index >= itemCount - 1)
                    .accessibilityLabel("Move \(item.cafeName) later")
                    Divider()
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove from list", systemImage: "trash")
                    }
                    .accessibilityLabel("Remove \(item.cafeName) from list")
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 19))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 42, height: 42)
                }
                .disabled(isWorking)
                .accessibilityLabel("Actions for \(item.cafeName)")
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(12)
        .cardStyle()
    }

    private var openAccessibilityLabel: String {
        var parts = [item.cafeName]
        if let location = item.displayLocation {
            parts.append(location)
        }
        if let note = item.note?.remoteTrimmedNonEmpty {
            parts.append(note)
        }
        parts.append("Added by \(item.contributor.attributionName)")
        if item.isFavorite {
            parts.append("Favorite")
        }
        if item.wantToTry {
            parts.append("Want to Try")
        }
        return parts.joined(separator: ", ")
    }
}

private struct CafeListOwnerRow: View {
    let owner: CafeListPerson

    var body: some View {
        HStack(spacing: 12) {
            MugshotAvatar(name: owner.visibleName, size: 42, imageURL: owner.avatarURL)
            VStack(alignment: .leading, spacing: 3) {
                Text(owner.visibleName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text("Owner")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            Image(systemName: "crown.fill")
                .foregroundColor(.mugshotSage)
                .accessibilityLabel("List owner")
        }
        .padding(12)
        .cardStyle()
    }
}

private struct CafeListMemberRow: View {
    let member: CollaborativeCafeListMember
    let isWorking: Bool
    let onSetRole: (String) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            MugshotAvatar(
                name: member.person.visibleName,
                size: 42,
                imageURL: member.person.avatarURL
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(member.person.visibleName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(member.isPending ? "\(member.roleTitle) · Invitation pending" : member.roleTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            if member.canChangeRole || member.canRemove,
               member.person.userID != nil {
                Menu {
                    if member.canChangeRole {
                        Button {
                            onSetRole("viewer")
                        } label: {
                            Label("Make viewer", systemImage: member.role == "viewer" ? "checkmark" : "eye")
                        }
                        Button {
                            onSetRole("editor")
                        } label: {
                            Label("Make editor", systemImage: member.role == "editor" ? "checkmark" : "pencil")
                        }
                    }
                    if member.canRemove {
                        Divider()
                        Button(role: .destructive, action: onRemove) {
                            Label(member.isPending ? "Cancel invitation" : "Remove collaborator", systemImage: "person.crop.circle.badge.minus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 19))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 42, height: 42)
                }
                .disabled(isWorking)
                .accessibilityLabel("Actions for \(member.person.visibleName)")
            } else if member.isPending {
                Text("Pending")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(Color.sandBeige.opacity(0.7), in: Capsule())
            }
        }
        .padding(12)
        .cardStyle()
    }
}

private struct HydratedCafeListMapPreview: View {
    let items: [CollaborativeCafeListItem]

    var body: some View {
        Map {
            ForEach(items.filter { $0.coordinate != nil }) { item in
                Marker(
                    item.cafeName,
                    systemImage: "cup.and.saucer.fill",
                    coordinate: item.coordinate!
                )
                .tint(Color.mugshotSage)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .frame(height: 164)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topLeading) {
            Label("List map", systemImage: "map.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.espressoBrown)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map showing \(items.filter { $0.coordinate != nil }.count) cafes in this list")
    }
}

private enum CafeListEditorMode {
    case create
    case edit(CollaborativeCafeList)

    var title: String {
        switch self {
        case .create: "New cafe list"
        case .edit: "Edit cafe list"
        }
    }
}

private struct CafeListEditorSheet: View {
    let mode: CafeListEditorMode
    let accountID: UUID
    let onSaved: (CollaborativeCafeList) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var visibility: CafeListVisibility
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        mode: CafeListEditorMode,
        accountID: UUID,
        onSaved: @escaping (CollaborativeCafeList) -> Void
    ) {
        self.mode = mode
        self.accountID = accountID
        self.onSaved = onSaved
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _description = State(initialValue: "")
            _visibility = State(initialValue: .private)
        case .edit(let list):
            _title = State(initialValue: list.title)
            _description = State(initialValue: list.description ?? "")
            _visibility = State(initialValue: list.visibility)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List") {
                    TextField("Weekend coffee crawl", text: $title)
                    TextField("Optional note", text: $description, axis: .vertical)
                        .lineLimit(2 ... 4)
                    HStack {
                        Spacer()
                        Text("\(description.count)/280")
                            .font(.caption)
                            .foregroundColor(description.count > 280 ? .red : .secondaryText)
                    }
                }

                Section("Who can see it") {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(CafeListVisibility.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Text(visibilityExplanation)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private var canSave: Bool {
        !isSaving
            && !(title.remoteTrimmedNonEmpty?.isEmpty ?? true)
            && title.trimmingCharacters(in: .whitespacesAndNewlines).count <= 80
            && description.count <= 280
    }

    private var visibilityExplanation: String {
        switch visibility {
        case .private:
            "Only you and accepted collaborators can open it."
        case .friends:
            "Your friends can view it. Only accepted editors can change cafes."
        case .invited:
            "Only people you invite can decide whether to join."
        case .public:
            "Anyone can view it. Signed-in people can follow, copy, save, and comment."
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let service = CollaborativeCafeListService(
                client: try SupabaseClientProvider.shared.client()
            )
            let saved: CollaborativeCafeList
            switch mode {
            case .create:
                saved = try await service.create(
                    title: title,
                    description: description,
                    visibility: visibility,
                    accountID: accountID
                )
            case .edit(let list):
                saved = try await service.update(
                    id: list.id,
                    title: title,
                    description: description,
                    visibility: visibility,
                    accountID: accountID
                )
            }
            onSaved(saved)
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }
}

private struct CafeListTransferSheet: View {
    let list: CollaborativeCafeList
    let onTransfer: (UUID) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMember: CollaborativeCafeListMember?
    @State private var isTransferring = false
    @State private var errorMessage: String?

    private var candidates: [CollaborativeCafeListMember] {
        list.resolvedMembers.filter { $0.isAccepted && $0.person.userID != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The new owner can edit the list, manage people, transfer it again, or delete it. You’ll remain as an editor.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                }

                Section("Accepted collaborators") {
                    ForEach(Array(candidates.enumerated()), id: \.offset) { _, member in
                        Button {
                            selectedMember = member
                        } label: {
                            HStack(spacing: 12) {
                                MugshotAvatar(
                                    name: member.person.visibleName,
                                    size: 42,
                                    imageURL: member.person.avatarURL
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(member.person.visibleName)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.espressoBrown)
                                    Text(member.roleTitle)
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.tertiaryText)
                            }
                        }
                        .disabled(isTransferring)
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Transfer ownership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() }.disabled(isTransferring) }
            .alert(item: $selectedMember) { member in
                Alert(
                    title: Text("Make \(member.person.visibleName) the owner?"),
                    message: Text("This takes effect immediately. You’ll remain an editor."),
                    primaryButton: .destructive(Text("Transfer")) {
                        Task { await transfer(member) }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    @MainActor
    private func transfer(_ member: CollaborativeCafeListMember) async {
        guard let userID = member.person.userID else { return }
        isTransferring = true
        defer { isTransferring = false }
        do {
            try await onTransfer(userID)
            dismiss()
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }
}

private struct CafeListCafePicker: View {
    @ObservedObject var dataManager: DataManager
    let existingCafeIDs: Set<UUID>
    let currentUserID: UUID
    let onSelect: (Cafe) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = MapSearchService()
    @StateObject private var locationManager = LocationManager()
    @State private var query = ""
    @State private var resolvingSuggestion: String?

    private var searchRegion: MKCoordinateRegion {
        if let coordinate = locationManager.location?.coordinate {
            return MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        }
        if let coordinate = dataManager.appData.cafes.compactMap(\.location).first {
            return MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 55)
        )
    }

    private var availableLocalCafes: [Cafe] {
        dataManager.appData.cafes.filter { cafe in
            !existingCafeIDs.contains(cafe.remoteCafeId ?? cafe.id)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.mugshotSage)
                        TextField("Search any city or cafe", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onSubmit {
                                searchService.search(query: query, region: searchRegion, immediately: true)
                            }
                    }
                } footer: {
                    Text("Search beyond your journal to plan future trips and coffee dates.")
                }

                if query.remoteTrimmedNonEmpty == nil {
                    Section("Your cafes") {
                        if availableLocalCafes.isEmpty {
                            Text("Search above to add somewhere new.")
                                .foregroundColor(.secondaryText)
                        } else {
                            ForEach(availableLocalCafes) { cafe in
                                cafeButton(cafe)
                            }
                        }
                    }
                } else {
                    if searchService.isSearching || searchService.isUpdatingSuggestions {
                        Section {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Finding cafes…")
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }

                    if !searchService.completions.isEmpty,
                       searchService.searchResults.isEmpty {
                        Section("Suggestions") {
                            ForEach(searchService.completions.prefix(6), id: \.self) { completion in
                                Button {
                                    resolvingSuggestion = completion.title
                                    Task {
                                        if let item = await searchService.resolve(
                                            completion: completion,
                                            region: searchRegion
                                        ) {
                                            choose(item)
                                        }
                                        resolvingSuggestion = nil
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(completion.title)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.espressoBrown)
                                            if !completion.subtitle.isEmpty {
                                                Text(completion.subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(.secondaryText)
                                            }
                                        }
                                        Spacer()
                                        if resolvingSuggestion == completion.title {
                                            ProgressView().controlSize(.small)
                                        }
                                    }
                                }
                                .disabled(resolvingSuggestion != nil)
                            }
                        }
                    }

                    if !searchService.searchResults.isEmpty {
                        Section("Places") {
                            ForEach(searchService.searchResults, id: \.self) { item in
                                Button { choose(item) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name ?? "Cafe")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.espressoBrown)
                                        let subtitle = MapSearchService.subtitle(for: item)
                                        if !subtitle.isEmpty {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                        }
                                    }
                                }
                            }
                        }
                    } else if !searchService.isSearching,
                              !searchService.isUpdatingSuggestions,
                              searchService.completions.isEmpty {
                        Section {
                            Text("No cafes matched yet. Try a full place name, neighborhood, or city.")
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Add a cafe")
            .toolbar { Button("Done") { dismiss() } }
            .task(id: query) {
                let value = query
                guard value.remoteTrimmedNonEmpty != nil else {
                    searchService.cancelSearch()
                    return
                }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, query == value else { return }
                searchService.search(query: value, region: searchRegion, immediately: true)
            }
            .onAppear {
                searchService.activate(scope: .user(currentUserID))
            }
        }
    }

    private func cafeButton(_ cafe: Cafe) -> some View {
        Button {
            onSelect(cafe)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(cafe.consumerDisplayName)
                    .fontWeight(.semibold)
                    .foregroundColor(.espressoBrown)
                if !cafe.address.isEmpty {
                    Text(cafe.address)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }

    private func choose(_ item: MKMapItem) {
        let cafe = dataManager.findOrCreateCafe(from: item)
        searchService.recordRecent(item)
        onSelect(cafe)
    }
}

private struct CafeListFriendPicker: View {
    let existingMemberIDs: Set<UUID>
    let onSelect: (SocialConnection, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [SocialConnection] = []
    @State private var role = "viewer"
    @State private var query = ""
    @State private var isLoading = false
    @State private var invitingFriendID: UUID?
    @State private var errorMessage: String?

    private var availableFriends: [SocialConnection] {
        let candidates = friends.filter { !existingMemberIDs.contains($0.userID) }
        guard let search = query.remoteTrimmedNonEmpty?.localizedLowercase else { return candidates }
        return candidates.filter {
            $0.displayName.localizedLowercase.contains(search)
                || $0.username.localizedLowercase.contains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Permission", selection: $role) {
                        Text("Can view").tag("viewer")
                        Text("Can edit").tag("editor")
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(role == "editor"
                        ? "Editors can add, remove, and reorder cafes after accepting."
                        : "Viewers can follow the list without changing it.")
                }

                Section("Friends") {
                    if isLoading, friends.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Finding your friends…")
                                .foregroundColor(.secondaryText)
                        }
                    } else if availableFriends.isEmpty {
                        Text(query.remoteTrimmedNonEmpty == nil
                            ? "Everyone available has already been invited."
                            : "No friends match that search.")
                            .foregroundColor(.secondaryText)
                    } else {
                        ForEach(availableFriends) { friend in
                            Button {
                                invite(friend)
                            } label: {
                                HStack(spacing: 12) {
                                    MugshotAvatar(
                                        name: friend.displayName,
                                        size: 42,
                                        imageURL: friend.avatarURL
                                    )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(friend.displayName)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.espressoBrown)
                                        Text("@\(friend.username)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondaryText)
                                    }
                                    Spacer()
                                    if invitingFriendID == friend.userID {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "person.badge.plus")
                                            .foregroundColor(.mugshotSage)
                                    }
                                }
                            }
                            .disabled(invitingFriendID != nil)
                        }
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red) }
                }
            }
            .searchable(text: $query, prompt: "Search friends")
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Invite a friend")
            .toolbar { Button("Done") { dismiss() } }
            .task { await loadFriends() }
        }
    }

    @MainActor
    private func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        do {
            friends = try await SocialDiscoveryService(
                client: try SupabaseClientProvider.shared.client()
            ).connections(kind: "friends")
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    private func invite(_ friend: SocialConnection) {
        invitingFriendID = friend.userID
        errorMessage = nil
        Task {
            do {
                try await onSelect(friend, role)
                dismiss()
            } catch {
                errorMessage = MugshotUserFacingError.message(for: error, context: .social)
                invitingFriendID = nil
            }
        }
    }
}

enum InlineCafeListNoticeStyle {
    case warning
    case success
}

struct InlineCafeListNotice: View {
    let title: String
    let message: String
    var actionTitle: String?
    var style: InlineCafeListNoticeStyle = .warning
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(style == .success ? .mugshotSage : .roastBrown)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.mugshotSage)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            (style == .success ? Color.mugshotMint : Color.sandBeige).opacity(0.42),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}
