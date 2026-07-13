import MapKit
import SwiftUI

struct PeopleHubView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searchResults: [PeopleSearchResult] = []
    @State private var incoming: [SocialConnection] = []
    @State private var outgoing: [SocialConnection] = []
    @State private var friends: [SocialConnection] = []
    @State private var blocked: [SocialConnection] = []
    @State private var selectedProfile: PeopleProfileRoute?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if let errorMessage {
                        MugshotStatusCard(
                            title: "Couldn’t update people",
                            message: errorMessage,
                            systemImage: "wifi.exclamationmark"
                        )
                    }

                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        peopleSection("People", rows: searchResults)
                    } else {
                        connectionSection("Requests", rows: incoming, icon: "person.crop.circle.badge.plus")
                        connectionSection("Sent", rows: outgoing, icon: "paperplane")
                        connectionSection("Friends", rows: friends, icon: "person.2.fill")
                        connectionSection("Blocked", rows: blocked, icon: "hand.raised.fill")
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color.creamWhite)
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search username or name")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isLoading && searchResults.isEmpty && friends.isEmpty {
                    ProgressView("Finding your coffee people…")
                }
            }
            .task { await loadConnections() }
            .task(id: query) { await search() }
            .refreshable { await loadConnections() }
            .navigationDestination(item: $selectedProfile) { route in
                PublicProfileView(route: route, onRelationshipChanged: {
                    await loadConnections()
                    await search(immediate: true)
                })
            }
        }
    }

    @ViewBuilder
    private func peopleSection(_ title: String, rows: [PeopleSearchResult]) -> some View {
        if rows.isEmpty && !isLoading {
            MugsyEmptyStateView(
                asset: .noFriends,
                title: "No people found",
                message: "Try a username, display name, or a shorter spelling."
            )
        } else {
            MugshotSectionTitle(title: title)
            ForEach(rows) { person in
                Button {
                    selectedProfile = PeopleProfileRoute(person)
                } label: {
                    PeopleRow(
                        displayName: person.displayName,
                        username: person.username,
                        subtitle: person.mutualFriendCount == 0 ? person.location : "\(person.mutualFriendCount) mutual friends",
                        state: person.friendshipState
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func connectionSection(_ title: String, rows: [SocialConnection], icon: String) -> some View {
        if !rows.isEmpty {
            MugshotSectionTitle(title: title, subtitle: nil)
            ForEach(rows) { person in
                Button {
                    selectedProfile = PeopleProfileRoute(person)
                } label: {
                    PeopleRow(
                        displayName: person.displayName,
                        username: person.username,
                        subtitle: nil,
                        state: state(for: person.kind)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func state(for kind: String) -> FriendshipState {
        switch kind {
        case "friends": .friends
        case "incoming": .incoming
        case "outgoing": .outgoing
        case "blocked": .blocked
        default: .none
        }
    }

    @MainActor
    private func loadConnections() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let service = try socialService()
            async let incomingRequest = service.connections(kind: "incoming")
            async let outgoingRequest = service.connections(kind: "outgoing")
            async let friendsRequest = service.connections(kind: "friends")
            async let blockedRequest = service.connections(kind: "blocked")
            (incoming, outgoing, friends, blocked) = try await (
                incomingRequest, outgoingRequest, friendsRequest, blockedRequest
            )
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func search(immediate: Bool = false) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        if !immediate { try? await Task.sleep(for: .milliseconds(250)) }
        guard !Task.isCancelled else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            searchResults = try await socialService().searchPeople(query: trimmed)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    private func socialService() throws -> SocialDiscoveryService {
        SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
    }
}

private struct PeopleRow: View {
    let displayName: String
    let username: String
    let subtitle: String?
    let state: FriendshipState

    var body: some View {
        HStack(spacing: 12) {
            MugshotAvatar(name: displayName, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName).font(.system(size: 15, weight: .bold)).foregroundColor(.espressoBrown)
                Text("@\(username)").font(.system(size: 13)).foregroundColor(.secondaryText)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.tertiaryText)
                }
            }
            Spacer()
            Text(stateLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.mugshotSage)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.tertiaryText)
        }
        .padding(14)
        .cardStyle()
    }

    private var stateLabel: String {
        switch state {
        case .none: "View"
        case .incoming: "Respond"
        case .outgoing: "Sent"
        case .friends: "Friends"
        case .blocked: "Blocked"
        case .self: "You"
        }
    }
}

struct PeopleProfileRoute: Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let username: String
    let relationshipID: UUID?
    let state: FriendshipState

    init(_ result: PeopleSearchResult) {
        id = result.id
        displayName = result.displayName
        username = result.username
        relationshipID = nil
        state = result.friendshipState
    }

    init(_ connection: SocialConnection) {
        id = connection.userID
        displayName = connection.displayName
        username = connection.username
        relationshipID = connection.relationshipID
        switch connection.kind {
        case "friends": state = .friends
        case "incoming": state = .incoming
        case "outgoing": state = .outgoing
        case "blocked": state = .blocked
        default: state = .none
        }
    }
}

private struct PublicProfileView: View {
    let route: PeopleProfileRoute
    let onRelationshipChanged: () async -> Void
    @State private var payload: PublicProfilePayload?
    @State private var state: FriendshipState
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var reportReason: ReportReason?

    init(route: PeopleProfileRoute, onRelationshipChanged: @escaping () async -> Void) {
        self.route = route
        self.onRelationshipChanged = onRelationshipChanged
        _state = State(initialValue: route.state)
    }

    var body: some View {
        profileContent
            .background(Color.creamWhite)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { safetyToolbar }
            .task { await load() }
            .alert("Report this profile?", isPresented: reportIsPresented) {
                Button("Report", role: .destructive) { Task { await report() } }
                Button("Cancel", role: .cancel) { reportReason = nil }
            } message: {
                Text("The report will be reviewed. It does not automatically remove content.")
            }
    }

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                profileHeader

                if let payload {
                    HStack(spacing: 10) {
                        StatBox(title: "Visible sips", value: "\(payload.stats.visibleVisits)")
                        StatBox(title: "Cafes", value: "\(payload.stats.cafes)")
                        StatBox(title: "Friends", value: "\(payload.stats.friends)")
                    }
                    .padding(.horizontal)

                    relationshipButton
                        .padding(.horizontal)

                    if state == .incoming {
                        Button("Decline request", role: .destructive) {
                            Task { await declineRequest() }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .disabled(isWorking)
                    }

                    if !payload.visits.isEmpty {
                        profileMap(payload.visits)
                        visibleVisits(payload.visits)
                    }
                } else if let errorMessage {
                    MugshotStatusCard(title: "Profile unavailable", message: errorMessage, systemImage: "person.slash")
                        .padding(.horizontal)

                    // A blocked profile is intentionally unreadable, but the
                    // person who created the block must still be able to undo
                    // it from the Blocked management list.
                    if state == .blocked {
                        relationshipButton
                            .padding(.horizontal)
                    }
                } else {
                    ProgressView().padding(.top, 30)
                }
            }
            .padding(.bottom, 30)
        }
    }

    private var profileHeader: some View {
        ZStack(alignment: .bottomLeading) {
            MugshotProfileBanner(imageURL: payload?.profile.bannerURL)
            HStack(alignment: .bottom, spacing: 12) {
                MugshotAvatar(
                    name: payload?.profile.displayName ?? route.displayName,
                    size: 72,
                    imageURL: payload?.profile.avatarURL
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(payload?.profile.displayName ?? route.displayName)
                        .font(.system(size: 21, weight: .bold))
                    Text("@\(payload?.profile.username ?? route.username)")
                        .font(.system(size: 13, weight: .semibold))
                    if let location = payload?.profile.location {
                        Text(location).font(.system(size: 12))
                    }
                }
                .foregroundColor(.espressoBrown)
                Spacer()
            }
            .padding(16)
            .background(Color.foamWhite.opacity(0.92))
        }
    }

    @ToolbarContentBuilder
    private var safetyToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(ReportReason.allCases) { reason in
                    Button("Report: \(reason.title)", role: .destructive) { reportReason = reason }
                }
                if state != .blocked {
                    Button("Block user", role: .destructive) { Task { await block() } }
                }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    private var reportIsPresented: Binding<Bool> {
        Binding(
            get: { reportReason != nil },
            set: { if !$0 { reportReason = nil } }
        )
    }

    private var relationshipButton: some View {
        Button {
            Task { await relationshipAction() }
        } label: {
            Label(actionTitle, systemImage: actionIcon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isWorking)
    }

    private func profileMap(_ visits: [PublicProfileVisit]) -> some View {
        MapViewRepresentable(
            region: .constant(profileRegion(visits)),
            cafes: Array(Dictionary(grouping: visits.map(\.cafe), by: \.id).values.compactMap { $0.first }),
            highlightedCafe: nil,
            showsUserLocation: false,
            trackingMode: .constant(.none),
            onCafeTap: { _ in }
        )
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .padding(.horizontal)
        .accessibilityLabel("Visible cafe map")
    }

    private func visibleVisits(_ visits: [PublicProfileVisit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(title: "Visible sips")
            ForEach(visits) { visit in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(visit.cafeName).font(.system(size: 14, weight: .bold))
                        Text(visit.drinkSubtype ?? visit.drinkType ?? "Coffee").font(.system(size: 12)).foregroundColor(.secondaryText)
                    }
                    Spacer()
                    MugshotRatingBadge(score: visit.overallScore)
                }
                .padding(12)
                .cardStyle()
            }
        }
        .padding(.horizontal)
    }

    private func profileRegion(_ visits: [PublicProfileVisit]) -> MKCoordinateRegion {
        let first = visits[0]
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )
    }

    private var actionTitle: String {
        switch state {
        case .none: "Add Friend"
        case .incoming: "Accept Request"
        case .outgoing: "Cancel Request"
        case .friends: "Remove Friend"
        case .blocked: "Unblock"
        case .self: "This is you"
        }
    }

    private var actionIcon: String {
        switch state {
        case .none: "person.badge.plus"
        case .incoming: "checkmark.circle"
        case .outgoing: "xmark.circle"
        case .friends: "person.badge.minus"
        case .blocked: "hand.raised.slash"
        case .self: "person.crop.circle"
        }
    }

    @MainActor private func load() async {
        do {
            payload = try await service().publicProfile(userID: route.id)
            state = payload?.friendshipState ?? state
            errorMessage = nil
        } catch { errorMessage = MugshotUserFacingError.message(for: error, context: .loading) }
    }

    @MainActor private func relationshipAction() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let service = try service()
            switch state {
            case .none:
                try await service.sendFriendRequest(to: route.id); state = .outgoing
            case .incoming:
                guard let requestID = try await requestID(kind: "incoming", service: service) else { return }
                try await service.respond(to: requestID, accept: true); state = .friends
            case .outgoing:
                guard let requestID = try await requestID(kind: "outgoing", service: service) else { return }
                try await service.cancel(requestID: requestID); state = .none
            case .friends:
                try await service.removeFriend(userID: route.id); state = .none
            case .blocked:
                try await service.unblock(userID: route.id); state = .none
            case .self: break
            }
            await onRelationshipChanged()
            await load()
        } catch { errorMessage = MugshotUserFacingError.message(for: error, context: .social) }
    }

    @MainActor private func declineRequest() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let service = try service()
            guard let requestID = try await requestID(kind: "incoming", service: service) else { return }
            try await service.respond(to: requestID, accept: false)
            state = .none
            await onRelationshipChanged()
            await load()
        } catch { errorMessage = MugshotUserFacingError.message(for: error, context: .social) }
    }

    private func requestID(kind: String, service: SocialDiscoveryService) async throws -> UUID? {
        if let relationshipID = route.relationshipID { return relationshipID }
        return try await service.connections(kind: kind).first(where: { $0.userID == route.id })?.relationshipID
    }

    @MainActor private func block() async {
        do { try await service().block(userID: route.id); state = .blocked; payload = nil; await onRelationshipChanged() }
        catch { errorMessage = MugshotUserFacingError.message(for: error, context: .social) }
    }

    @MainActor private func report() async {
        guard let reportReason else { return }
        defer { self.reportReason = nil }
        do { try await service().report(reason: reportReason, details: nil, userID: route.id) }
        catch { errorMessage = MugshotUserFacingError.message(for: error, context: .social) }
    }

    private func service() throws -> SocialDiscoveryService {
        SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
    }
}
