import Contacts
import ContactsUI
import CoreImage.CIFilterBuiltins
import MessageUI
import SwiftUI

struct PeopleDiscoveryHubView: View {
    @ObservedObject var dataManager: DataManager
    var initialInviteSecret: String? = nil
    var source: PeopleDiscoverySource = .peopleHub
    private let isDesignPreview: Bool
    private let previewProfileURL: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var query = ""
    @State private var capabilities = PeopleDiscoveryCapabilities.unavailable
    @State private var searchResults: [PeopleSearchResult] = []
    @State private var hasMoreSearchResults = false
    @State private var incoming: [SocialConnection] = []
    @State private var outgoing: [SocialConnection] = []
    @State private var friends: [SocialConnection] = []
    @State private var suggestions: [PeopleSuggestion] = []
    @State private var selectedProfile: PeopleProfileRoute?
    @State private var isLoading = false
    @State private var pendingIDs: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var activeSheet: PeopleDiscoverySheet?
    @State private var selectedContact: SelectedContactInvitation?
    @State private var dismissedSuggestion: PeopleSuggestion?
    @State private var hasHandledInitialInvite = false

    init(
        dataManager: DataManager,
        initialInviteSecret: String? = nil,
        source: PeopleDiscoverySource = .peopleHub,
        previewPayload: PeopleHubPayload? = nil,
        previewProfileURL: URL? = nil
    ) {
        self.dataManager = dataManager
        self.initialInviteSecret = initialInviteSecret
        self.source = source
        self.isDesignPreview = previewPayload != nil
        self.previewProfileURL = previewProfileURL
        if let previewPayload {
            _capabilities = State(initialValue: PeopleDiscoveryCapabilities(
                contactMatching: false,
                invitations: true,
                suggestions: true,
                firstWeekPrompt: false
            ))
            _incoming = State(initialValue: previewPayload.requests)
            _outgoing = State(initialValue: previewPayload.sent)
            _friends = State(initialValue: previewPayload.friends)
            _suggestions = State(initialValue: previewPayload.suggestions)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !incoming.isEmpty {
                        friendRequestSection
                    }

                    actionGrid

                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            MugshotStatusCard(
                                title: "Couldn’t update people",
                                message: errorMessage,
                                systemImage: "wifi.exclamationmark"
                            )
                            Button("Try again") {
                                Task {
                                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        await load()
                                    } else {
                                        await search(immediate: true)
                                    }
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .frame(minHeight: 44)
                            .disabled(isLoading)
                            .accessibilityIdentifier("people.retry")
                        }
                    }

                    if let dismissedSuggestion {
                        HStack {
                            Text("Suggestion hidden")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Button("Undo") { Task { await undoDismiss(dismissedSuggestion) } }
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(12)
                        .background(Color.mugshotMint.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        suggestionSection
                        connectionSection("Friends", rows: friends)
                        connectionSection("Sent", rows: outgoing)
                        if !isLoading && incoming.isEmpty && friends.isEmpty && suggestions.isEmpty {
                            discoveryEmptyState
                        }
                    } else {
                        searchSection
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color.creamWhite)
            .navigationTitle("Find your people")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Name, @username, or profile link")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Find your people")
                        .font(.system(size: 21, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.espressoBrown)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isLoading && incoming.isEmpty && friends.isEmpty && suggestions.isEmpty {
                    ProgressView("Finding your coffee people…")
                }
            }
            .task(id: authModel.authenticatedUser?.id) {
                if !isDesignPreview { await load() }
            }
            .task(id: query) { await search() }
            .task(id: initialInviteSecret) { await handleInitialInvite() }
            .refreshable { await load() }
            .navigationDestination(item: $selectedProfile) { route in
                PublicProfileView(route: route, dataManager: dataManager) {
                    await load()
                    await search(immediate: true)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .contactsEducation:
                ContactDiscoveryEducationView {
                    activeSheet = .contactPicker
                }
            case .contactPicker:
                SelectedContactPicker { contact in
                    selectedContact = contact
                    if contact != nil {
                        MugshotAnalytics.shared.capture(.peopleContactsSelectionCompleted(
                            selectedCount: 1,
                            usableCount: 1
                        ))
                    }
                    activeSheet = contact == nil ? nil : .contactInvite
                }
            case .contactInvite:
                ContactInviteComposerView(contact: selectedContact, service: try? peopleService())
            case .qr:
                ProfileQRCodeView(
                    displayName: authModel.profile?.displayName ?? "Mugshot friend",
                    username: authModel.profile?.username ?? "",
                    url: profileURL
                )
            case .invite:
                FriendInviteShareView(service: try? peopleService())
            }
        }
        .onAppear {
            MugshotAnalytics.shared.capture(.peopleHubOpened(source: source))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { clearTransientContacts() }
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, _ in
            clearTransientContacts()
        }
        .onDisappear { clearTransientContacts() }
    }

    private var profileURL: URL? {
        if let previewProfileURL { return previewProfileURL }
        guard let username = authModel.profile?.username else { return nil }
        return MugshotShareConfiguration.load().profileURL(username: username)
    }

    private var actionGrid: some View {
        HStack(spacing: 10) {
            if capabilities.invitations {
                discoveryAction(
                    "Invite contacts",
                    subtitle: "Send a private invite",
                    systemImage: "person.crop.circle.badge.plus"
                ) {
                    beginContactDiscovery()
                }
            }
            if let profileURL {
                ShareLink(item: profileURL, message: Text("Add me on Mugshot — @\(authModel.profile?.username ?? "")")) {
                    actionLabel("Share profile", subtitle: nil, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    MugshotAnalytics.shared.capture(.peopleProfileShareOpened(format: "link", source: source))
                })
            } else {
                actionLabel("Share profile", subtitle: nil, systemImage: "square.and.arrow.up").opacity(0.45)
            }
            if profileURL != nil {
                discoveryAction("My QR", systemImage: "qrcode") {
                    MugshotAnalytics.shared.capture(.peopleProfileShareOpened(format: "qr", source: source))
                    activeSheet = .qr
                }
            } else {
                actionLabel("My QR", subtitle: nil, systemImage: "qrcode").opacity(0.45)
            }
        }
    }

    private func discoveryAction(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { actionLabel(title, subtitle: subtitle, systemImage: systemImage) }
            .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, subtitle: String?, systemImage: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(Color.espressoBrown)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.control)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var suggestionSection: some View {
        if !suggestions.isEmpty {
            MugshotSectionTitle(
                title: "Suggested for you",
                subtitle: "People you may know from Mugshot."
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        PeopleSuggestionCard(
                            suggestion: suggestion,
                            isWorking: pendingIDs.contains(suggestion.id),
                            addAction: { Task { await sendRequest(to: suggestion.id, source: .suggestion) } },
                            openProfile: {
                                MugshotAnalytics.shared.capture(.peopleSuggestionOpened(
                                    reason: suggestion.reason,
                                    rankingVersion: suggestion.rankingVersion
                                ))
                                selectedProfile = PeopleProfileRoute(suggestion)
                            },
                            dismissAction: { Task { await dismissSuggestion(suggestion) } }
                        )
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 1, for: .scrollContent)
        }
    }

    private var friendRequestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: "Friend requests",
                subtitle: "People who want to connect with you."
            )
            ForEach(incoming) { person in
                PeopleDiscoveryRow(
                    displayName: person.displayName,
                    username: person.username,
                    avatarURL: person.avatarURL,
                    subtitle: "Wants to connect with you",
                    state: .incoming,
                    isWorking: pendingIDs.contains(person.userID),
                    primaryAction: { Task { await respond(person, accept: true) } },
                    secondaryAction: { Task { await respond(person, accept: false) } },
                    openProfile: { selectedProfile = PeopleProfileRoute(person) }
                )
            }
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        if searchResults.isEmpty && !isLoading {
            if capabilities.invitations {
                MugsyEmptyStateView(
                    placement: .friendsEmpty,
                    title: "No match yet",
                    message: "Try their name or @username, or send a private invitation.",
                    primaryAction: MugsyEmptyStateAction("Invite a contact", systemImage: "person.crop.circle.badge.plus", accessibilityHint: "Opens a private contact invitation") {
                        beginContactDiscovery()
                    },
                    secondaryAction: MugsyEmptyStateAction("Share profile", systemImage: "square.and.arrow.up", accessibilityHint: "Creates a private friend invitation") {
                        activeSheet = .invite
                    }
                )
            } else {
                ContentUnavailableView("No match yet", systemImage: "person.slash", description: Text("Try their exact @username later."))
            }
        } else {
            MugshotSectionTitle(title: "People")
            ForEach(searchResults) { person in
                PeopleDiscoveryRow(
                    displayName: person.displayName,
                    username: person.username,
                    avatarURL: person.avatarURL,
                    subtitle: person.mutualFriendCount > 0
                        ? "\(person.mutualFriendCount) mutual friend\(person.mutualFriendCount == 1 ? "" : "s")"
                        : person.location,
                    state: person.friendshipState,
                    isWorking: pendingIDs.contains(person.id),
                    primaryAction: { Task { await sendRequest(to: person.id, source: .search) } },
                    openProfile: { selectedProfile = PeopleProfileRoute(person) }
                )
            }
            if hasMoreSearchResults {
                Button {
                    Task { await loadMoreSearchResults() }
                } label: {
                    if isLoading { ProgressView() } else { Text("Load more people") }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(isLoading)
            }
        }
    }

    @ViewBuilder
    private func connectionSection(_ title: String, rows: [SocialConnection]) -> some View {
        if !rows.isEmpty {
            MugshotSectionTitle(title: title)
            ForEach(rows) { person in
                PeopleDiscoveryRow(
                    displayName: person.displayName,
                    username: person.username,
                    avatarURL: person.avatarURL,
                    subtitle: nil,
                    state: relationshipState(person.kind),
                    isWorking: pendingIDs.contains(person.userID),
                    primaryAction: {
                        Task {
                            if person.kind == "incoming" {
                                await respond(person, accept: true)
                            } else {
                                selectedProfile = PeopleProfileRoute(person)
                            }
                        }
                    },
                    secondaryAction: person.kind == "incoming" ? {
                        Task { await respond(person, accept: false) }
                    } : nil,
                    openProfile: { selectedProfile = PeopleProfileRoute(person) }
                )
            }
        }
    }

    @ViewBuilder
    private var discoveryEmptyState: some View {
        if capabilities.invitations {
            MugsyEmptyStateView(
                placement: .friendsEmpty,
                title: "Your coffee people are out there",
                message: "Invite someone you know or share your profile to start your circle.",
                primaryAction: MugsyEmptyStateAction("Invite a contact", systemImage: "person.crop.circle.badge.plus", accessibilityHint: "Opens a private contact invitation") {
                    beginContactDiscovery()
                },
                secondaryAction: MugsyEmptyStateAction("Share profile", systemImage: "square.and.arrow.up", accessibilityHint: "Creates a private friend invitation") {
                    activeSheet = .invite
                }
            )
        } else {
            ContentUnavailableView(
                "Find friends by username",
                systemImage: "person.2",
                description: Text("Search for an exact @username. More discovery options are temporarily unavailable.")
            )
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let discovery = try peopleService()
            capabilities = try await discovery.capabilities()
            let hub = try await discovery.hub()
            incoming = hub.requests
            outgoing = hub.sent
            friends = hub.friends
            suggestions = hub.suggestions
            errorMessage = hub.partialErrors.isEmpty
                ? nil
                : "Some people sections couldn’t update. Pull to refresh and try again."
        } catch is CancellationError {
        } catch {
            capabilities = .unavailable
            do {
                let social = try SocialDiscoveryService(client: SupabaseClientProvider.shared.client())
                async let incomingRows = social.connections(kind: "incoming")
                async let outgoingRows = social.connections(kind: "outgoing")
                async let friendRows = social.connections(kind: "friends")
                (incoming, outgoing, friends) = try await (
                    incomingRows, outgoingRows, friendRows
                )
                suggestions = []
                errorMessage = nil
            } catch {
                errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
            }
        }
    }

    @MainActor
    private func search(immediate: Bool = false) async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            searchResults = []
            hasMoreSearchResults = false
            return
        }
        if !immediate { try? await Task.sleep(for: .milliseconds(250)) }
        guard !Task.isCancelled else { return }
        if let url = URL(string: value),
           let route = MugshotProfileSharedLinkRoute.resolve(url),
           route.slug.hasPrefix("@") {
            query = String(route.slug.dropFirst())
        }
        let started = Date()
        isLoading = true
        defer { isLoading = false }
        do {
            searchResults = try await peopleService().search(query: query)
            hasMoreSearchResults = searchResults.count == 20
            errorMessage = nil
            MugshotAnalytics.shared.capture(.peopleSearchCompleted(
                resultCount: searchResults.count,
                outcome: "success",
                durationSeconds: Int(Date().timeIntervalSince(started))
            ))
        } catch is CancellationError {
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
            MugshotAnalytics.shared.capture(.peopleSearchCompleted(
                resultCount: 0, outcome: "failed", durationSeconds: Int(Date().timeIntervalSince(started))
            ))
        }
    }

    @MainActor
    private func loadMoreSearchResults() async {
        guard !isLoading, let cursor = searchResults.last else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = try await peopleService().search(query: query, after: cursor)
            let knownIDs = Set(searchResults.map(\.id))
            searchResults.append(contentsOf: next.filter { !knownIDs.contains($0.id) })
            hasMoreSearchResults = next.count == 20
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func sendRequest(to userID: UUID, source: PeopleDiscoverySource) async {
        guard !pendingIDs.contains(userID) else { return }
        pendingIDs.insert(userID)
        defer { pendingIDs.remove(userID) }
        do {
            try await peopleService().sendFriendRequest(to: userID, source: source)
            updateState(userID: userID, state: .outgoing)
            errorMessage = nil
            MugshotAnalytics.shared.capture(.peopleFriendRequestCompleted(
                action: "send", outcome: "success", source: source
            ))
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
            MugshotAnalytics.shared.capture(.peopleFriendRequestCompleted(
                action: "send", outcome: "failed", source: source
            ))
        }
    }

    @MainActor
    private func respond(_ connection: SocialConnection, accept: Bool) async {
        pendingIDs.insert(connection.userID)
        defer { pendingIDs.remove(connection.userID) }
        do {
            try await SocialDiscoveryService(client: SupabaseClientProvider.shared.client())
                .respond(to: connection.relationshipID, accept: accept)
            await load()
            MugshotAnalytics.shared.capture(.peopleFriendRequestCompleted(
                action: accept ? "accept" : "decline", outcome: "success", source: .peopleHub
            ))
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func dismissSuggestion(_ suggestion: PeopleSuggestion) async {
        suggestions.removeAll { $0.id == suggestion.id }
        dismissedSuggestion = suggestion
        do {
            try await peopleService().dismissSuggestion(userID: suggestion.id)
            MugshotAnalytics.shared.capture(.peopleSuggestionDismissed(
                reason: suggestion.reason, action: "dismiss", rankingVersion: suggestion.rankingVersion
            ))
        } catch {
            suggestions.append(suggestion)
            dismissedSuggestion = nil
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func undoDismiss(_ suggestion: PeopleSuggestion) async {
        do {
            try await peopleService().dismissSuggestion(userID: suggestion.id, undo: true)
            suggestions.insert(suggestion, at: 0)
            dismissedSuggestion = nil
            MugshotAnalytics.shared.capture(.peopleSuggestionDismissed(
                reason: suggestion.reason, action: "undo", rankingVersion: suggestion.rankingVersion
            ))
        } catch { errorMessage = MugshotUserFacingError.message(for: error, context: .social) }
    }

    @MainActor
    private func handleInitialInvite() async {
        guard !hasHandledInitialInvite, let initialInviteSecret else { return }
        hasHandledInitialInvite = true
        await resolveInvite(initialInviteSecret, source: .inviteLink)
    }

    @MainActor
    private func resolveInvite(_ secret: String, source: PeopleDiscoverySource) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let resolved = try await peopleService().resolveInvite(secret: secret) else {
                errorMessage = "This invitation is unavailable. Ask your friend for a new link, or find them by @username."
                MugshotAnalytics.shared.capture(.peopleInviteResolved(outcome: "failed", source: source))
                return
            }
            selectedProfile = PeopleProfileRoute(
                id: resolved.userID,
                displayName: resolved.displayName,
                username: resolved.username,
                state: resolved.friendshipState
            )
            MugshotAnalytics.shared.capture(.peopleInviteResolved(outcome: "success", source: source))
        } catch {
            errorMessage = "Mugshot couldn’t open that invitation. Please try again."
            MugshotAnalytics.shared.capture(.peopleInviteResolved(outcome: "failed", source: source))
        }
    }

    private func updateState(userID: UUID, state: FriendshipState) {
        searchResults = searchResults.map { person in
            guard person.id == userID else { return person }
            return PeopleSearchResult(
                id: person.id, displayName: person.displayName, username: person.username,
                bio: person.bio, location: person.location, favoriteDrink: person.favoriteDrink,
                avatarURL: person.avatarURL, bannerURL: person.bannerURL,
                friendshipState: state, mutualFriendCount: person.mutualFriendCount,
                rankBucket: person.rankBucket, matchScore: person.matchScore
            )
        }
        suggestions.removeAll { $0.id == userID }
    }

    private func peopleService() throws -> PeopleDiscoveryService {
        PeopleDiscoveryService(client: try SupabaseClientProvider.shared.client())
    }

    private func beginContactDiscovery() {
        MugshotAnalytics.shared.capture(.peopleContactsStarted(mode: "invite"))
        activeSheet = .contactsEducation
    }

    private func clearTransientContacts() {
        selectedContact = nil
        if activeSheet == .contactInvite || activeSheet == .contactPicker {
            activeSheet = nil
        }
    }

    private func relationshipState(_ kind: String) -> FriendshipState {
        switch kind {
        case "incoming": .incoming
        case "outgoing": .outgoing
        case "friends": .friends
        case "blocked": .blocked
        default: .none
        }
    }
}

private enum PeopleDiscoverySheet: String, Identifiable {
    case contactsEducation, contactPicker, contactInvite, qr, invite
    var id: String { rawValue }
}

private struct PeopleDiscoveryRow: View {
    let displayName: String
    let username: String
    let avatarURL: String?
    let subtitle: String?
    let state: FriendshipState
    let isWorking: Bool
    let primaryAction: () -> Void
    var secondaryAction: (() -> Void)? = nil
    let openProfile: () -> Void
    var dismissAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 11) {
            Button(action: openProfile) {
                HStack(spacing: 11) {
                    MugshotAvatar(name: displayName, size: 44, imageURL: avatarURL)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName).font(.system(size: 15, weight: .bold))
                        Text("@\(username)").font(.system(size: 12)).foregroundStyle(Color.secondaryText)
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.tertiaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.espressoBrown)
            Spacer(minLength: 6)
            if state == .none || state == .incoming {
                Button(state == .incoming ? "Accept" : "Add") { primaryAction() }
                    .buttonStyle(.borderedProminent)
                    .tint(.mugshotSage)
                    .disabled(isWorking)
            } else {
                Text(state == .friends ? "Friends" : state == .outgoing ? "Sent" : "View")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Color.mugshotSage)
            }
            if let secondaryAction {
                Button("Decline", role: .destructive, action: secondaryAction)
                    .font(.system(size: 11, weight: .bold))
            }
            if let dismissAction {
                Button(action: dismissAction) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityLabel("Hide suggestion for \(displayName)")
            }
        }
        .padding(12)
        .cardStyle()
    }
}

private struct PeopleSuggestionCard: View {
    let suggestion: PeopleSuggestion
    let isWorking: Bool
    let addAction: () -> Void
    let openProfile: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .accessibilityLabel("Hide suggestion for \(suggestion.displayName)")
            }
            .frame(height: 14)

            Button(action: openProfile) {
                VStack(spacing: 5) {
                    MugshotAvatar(name: suggestion.displayName, size: 62, imageURL: suggestion.avatarURL)
                    Text(suggestion.displayName)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(Color.espressoBrown)
                        .lineLimit(1)
                    Text("@\(suggestion.username)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Button(action: addAction) {
                Group {
                    if isWorking { ProgressView().tint(.white) }
                    else { Text("Add") }
                }
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color.mugshotSage)
            .clipShape(Capsule())
            .disabled(isWorking)

            HStack(alignment: .top, spacing: 5) {
                Image(systemName: suggestion.reasonSystemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.mugshotSageText)
                Text(suggestion.reasonText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 25, alignment: .topLeading)
        }
        .padding(8)
        .frame(width: 118, height: 208)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .shadow(color: Color.espressoBrown.opacity(0.06), radius: 10, y: 5)
    }
}

private struct ContactDiscoveryEducationView: View {
    @Environment(\.dismiss) private var dismiss
    let continueAction: () -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "message.badge.filled.fill")
                    .font(.system(size: 42)).foregroundStyle(Color.mugshotSage)
                Text("Invite one contact")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Color.espressoBrown)
                Text("Choose one person and Mugshot will prepare a private friend invitation in Messages. Their contact information stays on this iPhone and is never uploaded to Mugshot. Nothing is sent until you tap Send.")
                    .font(.system(size: 15)).foregroundStyle(Color.secondaryText)
                Spacer()
                Button("Choose a contact") {
                    dismiss()
                    DispatchQueue.main.async { continueAction() }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Not now", role: .cancel) { dismiss() }
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .background(Color.creamWhite)
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SelectedContactPicker: UIViewControllerRepresentable {
    let completion: (SelectedContactInvitation?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = context.coordinator
        controller.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        controller.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return controller
    }
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let completion: (SelectedContactInvitation?) -> Void
        init(completion: @escaping (SelectedContactInvitation?) -> Void) { self.completion = completion }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            guard let phoneNumber = contact.phoneNumbers.first?.value.stringValue else {
                completion(nil)
                return
            }
            completion(SelectedContactInvitation(
                id: "contact_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
                displayName: CNContactFormatter.string(from: contact, style: .fullName) ?? "Selected contact",
                phoneNumber: phoneNumber
            ))
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { completion(nil) }
    }
}

private struct ContactInviteComposerView: View {
    let contact: SelectedContactInvitation?
    let service: PeopleDiscoveryService?
    @Environment(\.dismiss) private var dismiss
    @State private var inviteURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isShowingMessage = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "message.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.mugshotSage)
                Text("Invite \(contact?.displayName ?? "your friend")")
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                Text("Their phone number stays on this iPhone. Mugshot only creates the invitation link; Messages sends it after you tap Send.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                if isLoading {
                    ProgressView("Creating invitation…")
                } else if inviteURL != nil, MFMessageComposeViewController.canSendText() {
                    Button("Open Messages") { isShowingMessage = true }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    MugshotStatusCard(
                        title: "Invitation unavailable",
                        message: errorMessage ?? "Messages is not available on this device.",
                        systemImage: "message.badge.filled.fill"
                    )
                    if errorMessage != nil {
                        Button("Retry") { Task { await load() } }
                    }
                }
                Spacer()
            }
            .padding(24)
            .background(Color.creamWhite)
            .navigationTitle("Private invitation")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await load() }
            .sheet(isPresented: $isShowingMessage) {
                if let contact, let inviteURL {
                    PeopleMessageComposeView(
                        recipient: contact.phoneNumber,
                        body: "Join me on Mugshot so we can share our coffee finds: \(inviteURL.absoluteString)"
                    ) { outcome in
                        MugshotAnalytics.shared.capture(.peopleInviteHandoffCompleted(outcome: outcome))
                        isShowingMessage = false
                    }
                }
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let service else { throw PeopleDiscoveryError.invalidResponse }
            let invite = try await service.createInvite()
            guard let url = service.inviteURL(invite) else { throw PeopleDiscoveryError.invalidResponse }
            inviteURL = url
            isLoading = false
            MugshotAnalytics.shared.capture(.peopleInviteCreated(outcome: "success"))
        } catch {
            isLoading = false
            errorMessage = "Mugshot couldn’t create an invitation yet."
            MugshotAnalytics.shared.capture(.peopleInviteCreated(outcome: "failed"))
        }
    }
}

private struct PeopleMessageComposeView: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    let completion: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = [recipient]
        controller.body = body
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let completion: (String) -> Void
        init(completion: @escaping (String) -> Void) { self.completion = completion }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            let outcome: String
            switch result {
            case .sent: outcome = "completed"
            case .cancelled: outcome = "canceled"
            case .failed: outcome = "failed"
            @unknown default: outcome = "failed"
            }
            controller.dismiss(animated: true) { self.completion(outcome) }
        }
    }
}

private struct ProfileQRCodeView: View {
    let displayName: String
    let username: String
    let url: URL?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text(displayName).font(.system(size: 26, weight: .bold, design: .serif))
                Text("@\(username)").foregroundStyle(Color.mugshotSage)
                if let url, let image = QRCodeRenderer.image(for: url.absoluteString) {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                        .frame(maxWidth: 280).accessibilityLabel("QR code for \(url.absoluteString)")
                    Text(url.absoluteString).font(.caption).textSelection(.enabled)
                    ShareLink(item: url, message: Text("Add me on Mugshot — @\(username)")) {
                        Label("Share profile", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.borderedProminent).tint(.mugshotSage)
                } else {
                    MugshotStatusCard(title: "Profile link unavailable", message: "Complete your username and try again.", systemImage: "person.crop.circle.badge.exclamationmark")
                }
                Spacer()
            }
            .padding(24).background(Color.creamWhite)
            .navigationTitle("My QR")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private enum QRCodeRenderer {
    static func image(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct FriendInviteShareView: View {
    let service: PeopleDiscoveryService?
    @Environment(\.dismiss) private var dismiss
    @State private var invite: FriendInvite?
    @State private var url: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var shareItems: [Any]?
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if isLoading { ProgressView("Creating invitation…") }
                else if let invite, let url {
                    Image(systemName: "cup.and.saucer.fill").font(.system(size: 44)).foregroundStyle(Color.mugshotSage)
                    Text("Invite a coffee friend").font(.system(size: 27, weight: .bold, design: .serif))
                    Text("They can reopen this private link after installing Mugshot.")
                        .multilineTextAlignment(.center).foregroundStyle(Color.secondaryText)
                    Text(invite.code).font(.system(size: 23, weight: .bold, design: .monospaced)).textSelection(.enabled)
                    Button {
                        shareItems = ["Join me on Mugshot so we can share our coffee finds:", url]
                    } label: {
                        Label("Choose someone to invite", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.borderedProminent).tint(.mugshotSage)
                } else {
                    MugshotStatusCard(title: "Invitation unavailable", message: errorMessage ?? "Please try again.", systemImage: "wifi.exclamationmark")
                    Button("Retry") { Task { await load() } }
                }
                Spacer()
            }
            .padding(24).background(Color.creamWhite)
            .navigationTitle("Invite")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await load() }
            .sheet(isPresented: Binding(
                get: { shareItems != nil },
                set: { if !$0 { shareItems = nil } }
            )) {
                if let shareItems {
                    PeopleInviteActivityShareView(items: shareItems) { outcome in
                        MugshotAnalytics.shared.capture(.peopleInviteHandoffCompleted(outcome: outcome))
                        self.shareItems = nil
                    }
                }
            }
        }
    }
    @MainActor private func load() async {
        isLoading = true; errorMessage = nil
        do {
            guard let service else { throw PeopleDiscoveryError.invalidResponse }
            let created = try await service.createInvite()
            invite = created; url = service.inviteURL(created); isLoading = false
            MugshotAnalytics.shared.capture(.peopleInviteCreated(outcome: url == nil ? "failed" : "success"))
        } catch {
            isLoading = false; errorMessage = "Mugshot couldn’t create an invitation yet."
            MugshotAnalytics.shared.capture(.peopleInviteCreated(outcome: "failed"))
        }
    }
}

private struct PeopleInviteActivityShareView: UIViewControllerRepresentable {
    let items: [Any]
    let completion: (String) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            DispatchQueue.main.async {
                completion(error == nil ? (completed ? "completed" : "canceled") : "failed")
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension PeopleProfileRoute {
    init(_ suggestion: PeopleSuggestion) {
        self.init(id: suggestion.id, displayName: suggestion.displayName,
                  username: suggestion.username, state: suggestion.friendshipState)
    }
}

#if DEBUG
struct PeopleDiscoveryHubPreviewHost: View {
    @ObservedObject var dataManager: DataManager

    private let payload = PeopleHubPayload(
        requests: [
            SocialConnection(
                relationshipID: UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!,
                userID: UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!,
                displayName: "Maya Chen",
                username: "mayach",
                avatarURL: nil,
                createdAt: "2026-09-17T12:00:00Z",
                kind: "incoming"
            )
        ],
        sent: [],
        friends: [
            SocialConnection(
                relationshipID: UUID(uuidString: "A2000000-0000-4000-8000-000000000001")!,
                userID: UUID(uuidString: "A2000000-0000-4000-8000-000000000002")!,
                displayName: "Grace",
                username: "lghammond0",
                avatarURL: nil,
                createdAt: "2026-09-10T12:00:00Z",
                kind: "friends"
            ),
            SocialConnection(
                relationshipID: UUID(uuidString: "A2000000-0000-4000-8000-000000000003")!,
                userID: UUID(uuidString: "A2000000-0000-4000-8000-000000000004")!,
                displayName: "Papa",
                username: "jrosso4",
                avatarURL: nil,
                createdAt: "2026-09-09T12:00:00Z",
                kind: "friends"
            )
        ],
        suggestions: [
            PeopleSuggestion(
                id: UUID(uuidString: "A3000000-0000-4000-8000-000000000001")!,
                displayName: "Elena Park",
                username: "elenapours",
                avatarURL: nil,
                friendshipState: .none,
                mutualFriendCount: 3,
                reason: "mutual_friends",
                rankingVersion: "people_v2"
            ),
            PeopleSuggestion(
                id: UUID(uuidString: "A3000000-0000-4000-8000-000000000002")!,
                displayName: "Jon Bell",
                username: "jonbrews",
                avatarURL: nil,
                friendshipState: .none,
                mutualFriendCount: 0,
                reason: "interacted_with_you",
                rankingVersion: "people_v2"
            ),
            PeopleSuggestion(
                id: UUID(uuidString: "A3000000-0000-4000-8000-000000000003")!,
                displayName: "Nia Cole",
                username: "niacoffee",
                avatarURL: nil,
                friendshipState: .none,
                mutualFriendCount: 0,
                reason: "shared_list",
                rankingVersion: "people_v2"
            )
        ],
        partialErrors: [:]
    )

    var body: some View {
        PeopleDiscoveryHubView(
            dataManager: dataManager,
            previewPayload: payload,
            previewProfileURL: URL(string: "https://mugshot.app/@joer")
        )
    }
}
#endif
