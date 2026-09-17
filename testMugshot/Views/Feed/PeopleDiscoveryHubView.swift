import Contacts
import ContactsUI
import CoreImage.CIFilterBuiltins
import SwiftUI

struct PeopleDiscoveryHubView: View {
    @ObservedObject var dataManager: DataManager
    var initialInviteSecret: String? = nil
    var source: PeopleDiscoverySource = .peopleHub
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
    @State private var selectedContacts: [SelectedContactForDiscovery] = []
    @State private var contactResults: [ContactDiscoveryResult] = []
    @State private var dismissedSuggestion: PeopleSuggestion?
    @State private var inviteCode = ""
    @State private var hasHandledInitialInvite = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    actionGrid
                    if capabilities.invitations { inviteCodeEntry }

                    if let errorMessage {
                        MugshotStatusCard(
                            title: "Couldn’t update people",
                            message: errorMessage,
                            systemImage: "wifi.exclamationmark"
                        )
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
                        connectionSection("Requests", rows: incoming)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isLoading && incoming.isEmpty && friends.isEmpty && suggestions.isEmpty {
                    ProgressView("Finding your coffee people…")
                }
            }
            .task(id: authModel.authenticatedUser?.id) { await load() }
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
                SelectedContactPicker { contacts in
                    selectedContacts = contacts
                    if !contacts.isEmpty {
                        MugshotAnalytics.shared.capture(.peopleContactsSelectionCompleted(
                            selectedCount: contacts.count,
                            usableCount: contacts.filter { !$0.emails.isEmpty }.count
                        ))
                    }
                    activeSheet = contacts.isEmpty ? nil : .contactsReview
                }
            case .contactsReview:
                ContactDiscoveryReviewView(
                    contacts: selectedContacts,
                    results: contactResults,
                    isWorking: isLoading,
                    errorMessage: errorMessage,
                    onMatch: { await matchSelectedContacts() },
                    onAdd: { match in await sendRequest(to: match.id, source: .contacts) },
                    onInvite: { activeSheet = .invite }
                )
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
        guard let username = authModel.profile?.username else { return nil }
        return MugshotShareConfiguration.load().profileURL(username: username)
    }

    private var actionGrid: some View {
        HStack(spacing: 10) {
            if capabilities.contactMatching {
                discoveryAction("Contacts", systemImage: "person.crop.circle.badge.plus") {
                    beginContactDiscovery()
                }
            }
            if let profileURL {
                ShareLink(item: profileURL, message: Text("Add me on Mugshot — @\(authModel.profile?.username ?? "")")) {
                    actionLabel("Share profile", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    MugshotAnalytics.shared.capture(.peopleProfileShareOpened(format: "link", source: source))
                })
            } else {
                actionLabel("Share profile", systemImage: "square.and.arrow.up").opacity(0.45)
            }
            if profileURL != nil {
                discoveryAction("My QR", systemImage: "qrcode") {
                    MugshotAnalytics.shared.capture(.peopleProfileShareOpened(format: "qr", source: source))
                    activeSheet = .qr
                }
            } else {
                actionLabel("My QR", systemImage: "qrcode").opacity(0.45)
            }
        }
    }

    private func discoveryAction(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { actionLabel(title, systemImage: systemImage) }
            .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(Color.espressoBrown)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.control)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }

    private var inviteCodeEntry: some View {
        HStack(spacing: 9) {
            TextField("Have an invite code?", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .semibold))
                .accessibilityLabel("Friend invite code")
            Button("Open") { Task { await resolveInvite(inviteCode, source: .inviteCode) } }
                .font(.system(size: 13, weight: .bold))
                .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))
    }

    @ViewBuilder
    private var suggestionSection: some View {
        if !suggestions.isEmpty {
            MugshotSectionTitle(title: "Suggested", subtitle: "People connected by activity you can already see.")
            ForEach(suggestions) { suggestion in
                PeopleDiscoveryRow(
                    displayName: suggestion.displayName,
                    username: suggestion.username,
                    avatarURL: suggestion.avatarURL,
                    subtitle: suggestion.reasonText,
                    state: suggestion.friendshipState,
                    isWorking: pendingIDs.contains(suggestion.id),
                    primaryAction: { Task { await sendRequest(to: suggestion.id, source: .suggestion) } },
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
    }

    @ViewBuilder
    private var searchSection: some View {
        if searchResults.isEmpty && !isLoading {
            if capabilities.contactMatching {
                MugsyEmptyStateView(
                    placement: .friendsEmpty,
                    title: "No match yet",
                    message: "Try their name or @username.",
                    primaryAction: MugsyEmptyStateAction("Choose from Contacts", systemImage: "person.crop.circle.badge.plus", accessibilityHint: "Opens the selected contact picker") {
                        beginContactDiscovery()
                    },
                    secondaryAction: capabilities.invitations ? MugsyEmptyStateAction("Invite a friend", systemImage: "square.and.arrow.up", accessibilityHint: "Creates a private friend invitation") {
                        activeSheet = .invite
                    } : nil
                )
            } else if capabilities.invitations {
                MugsyEmptyStateView(
                    placement: .friendsEmpty,
                    title: "No match yet",
                    message: "Try their name or @username, or send a private invitation.",
                    primaryAction: MugsyEmptyStateAction("Invite a friend", systemImage: "square.and.arrow.up", accessibilityHint: "Creates a private friend invitation") {
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
        if capabilities.contactMatching {
            MugsyEmptyStateView(
                placement: .friendsEmpty,
                title: "Your coffee people are out there",
                message: "Choose someone you know or share your profile to start your circle.",
                primaryAction: MugsyEmptyStateAction("Choose from Contacts", systemImage: "person.crop.circle.badge.plus", accessibilityHint: "Opens the selected contact picker") {
                    beginContactDiscovery()
                },
                secondaryAction: capabilities.invitations ? MugsyEmptyStateAction("Invite a friend", systemImage: "square.and.arrow.up", accessibilityHint: "Creates a private friend invitation") {
                    activeSheet = .invite
                } : nil
            )
        } else if capabilities.invitations {
            MugsyEmptyStateView(
                placement: .friendsEmpty,
                title: "Your coffee people are out there",
                message: "Share your profile or invite a friend to start your circle.",
                primaryAction: MugsyEmptyStateAction("Invite a friend", systemImage: "square.and.arrow.up", accessibilityHint: "Creates a private friend invitation") {
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
    private func matchSelectedContacts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            contactResults = try await peopleService().match(selectedContacts)
            errorMessage = nil
            MugshotAnalytics.shared.capture(.peopleContactsMatchCompleted(
                selectedCount: selectedContacts.count,
                matchedCount: contactResults.filter { !$0.matches.isEmpty }.count,
                outcome: "success"
            ))
        } catch {
            errorMessage = "Mugshot couldn’t check those contacts. Nothing was saved; please try again."
            MugshotAnalytics.shared.capture(.peopleContactsMatchCompleted(
                selectedCount: selectedContacts.count, matchedCount: 0, outcome: "failed"
            ))
        }
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
            inviteCode = ""
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
        MugshotAnalytics.shared.capture(.peopleContactsStarted(mode: "selected"))
        activeSheet = .contactsEducation
    }

    private func clearTransientContacts() {
        selectedContacts.removeAll()
        contactResults.removeAll()
        if activeSheet == .contactsReview || activeSheet == .contactPicker {
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
    case contactsEducation, contactPicker, contactsReview, qr, invite
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
                            Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.tertiaryText)
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

private struct ContactDiscoveryEducationView: View {
    @Environment(\.dismiss) private var dismiss
    let continueAction: () -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 42)).foregroundStyle(Color.mugshotSage)
                Text("Choose people you know")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Color.espressoBrown)
                Text("Mugshot checks the email addresses you select for accounts that allow contact discovery. Selected addresses are sent securely for this check and are not saved as an address book. Nothing is sent to your contacts.")
                    .font(.system(size: 15)).foregroundStyle(Color.secondaryText)
                Spacer()
                Button("Choose Contacts") {
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
    let completion: ([SelectedContactForDiscovery]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = context.coordinator
        controller.displayedPropertyKeys = [CNContactEmailAddressesKey]
        return controller
    }
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let completion: ([SelectedContactForDiscovery]) -> Void
        init(completion: @escaping ([SelectedContactForDiscovery]) -> Void) { self.completion = completion }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            completion(contacts.prefix(50).map { contact in
                SelectedContactForDiscovery(
                    id: "contact_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
                    displayName: CNContactFormatter.string(from: contact, style: .fullName) ?? "Selected contact",
                    emails: Array(Set(contact.emailAddresses.map { String($0.value) })).prefix(10).map { $0 }
                )
            })
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { completion([]) }
    }
}

private struct ContactDiscoveryReviewView: View {
    let contacts: [SelectedContactForDiscovery]
    let results: [ContactDiscoveryResult]
    let isWorking: Bool
    let errorMessage: String?
    let onMatch: () async -> Void
    let onAdd: (ContactDiscoveryMatch) async -> Void
    let onInvite: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("We use selected email addresses only to look for discoverable Mugshot accounts.")
                }
                if results.isEmpty {
                    Section("Selected") {
                        ForEach(contacts) { contact in
                            LabeledContent(contact.displayName, value: contact.emails.isEmpty ? "Invite only" : "Ready")
                        }
                    }
                    Button("Find selected friends") { Task { await onMatch() } }
                        .disabled(isWorking || contacts.allSatisfy(\.emails.isEmpty))
                } else {
                    Section("Matches") {
                        ForEach(results.flatMap(\.matches)) { match in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(match.displayName).fontWeight(.semibold)
                                    Text("@\(match.username)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(match.friendshipState == .none ? "Add" : "\(match.friendshipState.rawValue.capitalized)") {
                                    Task { await onAdd(match) }
                                }.disabled(match.friendshipState != .none)
                            }
                        }
                    }
                    Section("No discoverable match") {
                        ForEach(results.filter(\.matches.isEmpty)) { result in
                            HStack {
                                Text(result.contact.displayName)
                                Spacer()
                                Button("Invite", action: onInvite)
                            }
                        }
                        Text("They may use another email or have contact discovery turned off.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Selected Contacts")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
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
                    Text("They can reopen this link after installing Mugshot or enter the code in Find your people.")
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
