import MapKit
import SwiftUI

struct PeopleHubView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel
    @AppStorage(RoadmapFeatureFlags.phase4LightweightFriends) private var phase4LightweightFriends = true
    @State private var query = ""
    @State private var searchResults: [PeopleSearchResult] = []
    @State private var incoming: [SocialConnection] = []
    @State private var outgoing: [SocialConnection] = []
    @State private var friends: [SocialConnection] = []
    @State private var blocked: [SocialConnection] = []
    @State private var selectedProfile: PeopleProfileRoute?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var recommendations: [TrustedRecommendation] = []
    @State private var sharedRecipes: [SharedRecipeRecord] = []
    @State private var selectedSharedRecipe: SharedRecipeRecord?

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
                        if phase4LightweightFriends {
                            recommendationSection
                        }
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
                PublicProfileView(route: route, dataManager: dataManager, onRelationshipChanged: {
                    await loadConnections()
                    await search(immediate: true)
                })
            }
            .sheet(item: $selectedSharedRecipe) { recipe in
                SharedRecipeDetailView(recipe: recipe)
            }
        }
    }

    @ViewBuilder
    private var recommendationSection: some View {
        let incomingRecommendations = recommendations.filter {
            $0.recipientID == authModel.authenticatedUser?.id && $0.status != "dismissed"
        }
        if !incomingRecommendations.isEmpty {
            MugshotSectionTitle(title: "Shared with you", subtitle: "Coffee ideas from friends you trust.")
            ForEach(incomingRecommendations.prefix(4)) { recommendation in
                HStack(spacing: 12) {
                    Image(systemName: recommendationIcon(recommendation.targetKind))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 38, height: 38)
                        .background(Color.mugshotSage.opacity(0.14))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recommendationTitle(recommendation))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        if let note = recommendation.note?.remoteTrimmedNonEmpty {
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    if let recipe = sharedRecipe(for: recommendation) {
                        Button("View") { selectedSharedRecipe = recipe }
                            .font(.system(size: 12, weight: .bold))
                            .buttonStyle(.bordered)
                            .tint(.mugshotSage)
                    }
                    Button("Done") {
                        Task { await dismissRecommendation(recommendation) }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .buttonStyle(.bordered)
                    .tint(.mugshotSage)
                }
                .padding(12)
                .cardStyle()
            }
        }
    }

    private func recommendationTitle(_ recommendation: TrustedRecommendation) -> String {
        if let recipe = sharedRecipe(for: recommendation) {
            return recipe.recipeName
        }
        return switch recommendation.targetKind {
        case .cafe: "A cafe recommendation"
        case .visit: "A sip recommendation"
        case .recipe: "A recipe recommendation"
        }
    }

    private func sharedRecipe(for recommendation: TrustedRecommendation) -> SharedRecipeRecord? {
        guard recommendation.targetKind == .recipe else { return nil }
        return sharedRecipes.first { $0.recipeVersionID == recommendation.targetRecipeVersionID }
    }

    private func recommendationIcon(_ kind: TrustedRecommendationKind) -> String {
        switch kind {
        case .cafe: "mappin.and.ellipse"
        case .visit: "cup.and.saucer.fill"
        case .recipe: "list.bullet.clipboard.fill"
        }
    }

    @ViewBuilder
    private func peopleSection(_ title: String, rows: [PeopleSearchResult]) -> some View {
        if rows.isEmpty && !isLoading {
            MugsyEmptyStateView(
                placement: .friendsEmpty,
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
                        avatarURL: person.avatarURL,
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
                        avatarURL: person.avatarURL,
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
            if phase4LightweightFriends {
                recommendations = (try? await service.recommendations()) ?? []
                sharedRecipes = (try? await service.sharedRecipes()) ?? []
            }
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func dismissRecommendation(_ recommendation: TrustedRecommendation) async {
        do {
            let updated = try await socialService().updateRecommendation(recommendation.id, status: "dismissed")
            recommendations = recommendations.map { $0.id == updated.id ? updated : $0 }
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
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
    let avatarURL: String?
    let subtitle: String?
    let state: FriendshipState

    var body: some View {
        HStack(spacing: 12) {
            MugshotAvatar(name: displayName, size: 46, imageURL: avatarURL)
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

    init(
        id: UUID,
        displayName: String,
        username: String,
        relationshipID: UUID? = nil,
        state: FriendshipState = .none
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.relationshipID = relationshipID
        self.state = state
    }
}

struct PublicProfileView: View {
    let route: PeopleProfileRoute
    @ObservedObject var dataManager: DataManager
    let onRelationshipChanged: () async -> Void
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var payload: PublicProfilePayload?
    @State private var state: FriendshipState
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var reportReason: ReportReason?
    @State private var reportDetailsRequest: SafetyReportDetailsRequest?
    @State private var failedReportReceipt: SafetyReportReceipt?
    @State private var showBlockConfirmation = false
    @State private var safetyStatus: String?
    @State private var compatibility: FriendCompatibility?
    @State private var passportState: TastePassportLoadState = .loading
    @State private var selectedSipFilter: PublicSipFilter = .all
    @State private var selectedVisit: RemoteVisitSummary?
    @AppStorage(RoadmapFeatureFlags.phase4LightweightFriends) private var phase4LightweightFriends = true

    private enum PublicSipFilter: String, CaseIterable {
        case all = "All"
        case cafe = "Cafe"
        case home = "Home"
    }

    init(
        route: PeopleProfileRoute,
        dataManager: DataManager,
        onRelationshipChanged: @escaping () async -> Void
    ) {
        self.route = route
        self.dataManager = dataManager
        self.onRelationshipChanged = onRelationshipChanged
        _state = State(initialValue: route.state)
    }

    var body: some View {
        Group {
            if state == .blocked {
                profileContent
            } else {
                SharedProfileView(
                    source: .user(route.id, asEveryone: false),
                    dataManager: dataManager,
                    supplementaryContent: AnyView(sharedProfileSocialControls)
                )
            }
        }
            .background(Color.creamWhite)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { safetyToolbar }
            .task(id: authModel.authenticatedUser?.id) { await load() }
            .onChange(of: authModel.authenticatedUser?.id) { _, accountID in
                resetForAccountChange(accountID: accountID)
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedVisit != nil },
                    set: { if !$0 { selectedVisit = nil } }
                )
            ) {
                if let visit = selectedVisit {
                    RemoteVisitDetailView(
                        visitId: visit.id,
                        initialSummary: visit,
                        currentUserId: authModel.authenticatedUser?.id,
                        dataManager: dataManager
                    )
                }
            }
            .alert("Report this profile?", isPresented: reportIsPresented) {
                Button("Report", role: .destructive) { confirmSelectedReport() }
                Button("Cancel", role: .cancel) { reportReason = nil }
            } message: {
                Text("Send this concern using the reason you selected.")
            }
            .sheet(item: $reportDetailsRequest) { request in
                SafetyReportDetailsSheet(targetLabel: request.target.reportLabel) { details in
                    Task { await report(reason: .other, details: details) }
                }
            }
            .alert("Block @\(route.username)?", isPresented: $showBlockConfirmation) {
                Button("Block · Keep Recipe Copies", role: .destructive) {
                    Task { await block(removeSavedRecipeCopies: false) }
                }
                Button("Block · Remove Recipe Copies", role: .destructive) {
                    Task { await block(removeSavedRecipeCopies: true) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(SocialSafetyCopy.blockConsequences)
            }
            .alert(
                "Report not confirmed",
                isPresented: Binding(
                    get: { failedReportReceipt != nil },
                    set: { if !$0 { failedReportReceipt = nil } }
                ),
                presenting: failedReportReceipt
            ) { receipt in
                Button("Retry") { Task { await submitPreparedReport(receipt) } }
                Button("Not now", role: .cancel) {}
            } message: { _ in
                Text(SocialSafetyCopy.reportFailed)
            }
    }

    private var sharedProfileSocialControls: some View {
        VStack(spacing: 10) {
            if let safetyStatus {
                MugshotStatusCard(
                    title: "Safety update",
                    message: safetyStatus,
                    systemImage: "checkmark.shield.fill"
                )
            }

            if phase4LightweightFriends,
               state == .friends,
               let compatibility {
                compatibilityCard(compatibility)
            }

            relationshipButton

            if state == .incoming {
                Button("Decline request", role: .destructive) {
                    Task { await declineRequest() }
                }
                .font(.system(size: 13, weight: .semibold))
                .disabled(isWorking)
            }
        }
    }

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                profileHeader

                if let safetyStatus {
                    MugshotStatusCard(
                        title: "Safety update",
                        message: safetyStatus,
                        systemImage: "checkmark.shield.fill"
                    )
                    .padding(.horizontal)
                }

                if let payload {
                    HStack(spacing: 10) {
                        StatBox(title: "Visible sips", value: "\(payload.stats.visibleVisits)")
                        StatBox(title: "Cafes", value: "\(payload.stats.cafes)")
                        StatBox(title: "Friends", value: "\(payload.stats.friends)")
                    }
                    .padding(.horizontal)

                    TastePassportProjectionSection(
                        state: passportState,
                        context: .viewer(displayName: payload.profile.displayName),
                        onRetry: {
                            Task { await loadPassport() }
                        }
                    )
                    .padding(.horizontal)

                    if phase4LightweightFriends,
                       state == .friends,
                       let compatibility {
                        compatibilityCard(compatibility)
                            .padding(.horizontal)
                    }

                    relationshipButton
                        .padding(.horizontal)

                    if state == .incoming {
                        Button("Decline request", role: .destructive) {
                            Task { await declineRequest() }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .disabled(isWorking)
                    }

                    if payload.visits.contains(where: { $0.cafe != nil }) {
                        profileMap(payload.visits)
                    }
                    if !payload.visits.isEmpty {
                        visibleVisits(payload.visits)
                    }
                } else if state == .blocked {
                    MugshotStatusCard(
                        title: "Account blocked",
                        message: "This profile and your shared social activity are hidden. Your private journal is unchanged.",
                        systemImage: "hand.raised.fill"
                    )
                    .padding(.horizontal)

                    relationshipButton
                        .padding(.horizontal)
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

    private func compatibilityCard(_ compatibility: FriendCompatibility) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(compatibility.title, systemImage: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text(compatibility.explanation)
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)
            if !compatibility.sharedAttributes.isEmpty {
                Text(compatibility.sharedAttributes.map { $0.capitalized }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }
            Text("Based only on journal patterns each of you has supported across at least three sips.")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }

    private var profileHeader: some View {
        ZStack(alignment: .bottomLeading) {
            MugshotProfileBanner(imageURL: payload?.profile.bannerURL, height: 194)
            LinearGradient(
                colors: [.clear, Color.espressoBrown.opacity(0.56)],
                startPoint: .top,
                endPoint: .bottom
            )
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
                .foregroundColor(.foamWhite)
                Spacer()
            }
            .padding(16)
        }
    }

    @ToolbarContentBuilder
    private var safetyToolbar: some ToolbarContent {
        if state != .self && state != .blocked {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ReportReason.allCases) { reason in
                        Button("Report: \(reason.title)", role: .destructive) {
                            reportReason = reason
                        }
                    }
                    Button("Block user", role: .destructive) {
                        showBlockConfirmation = true
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Profile safety actions")
            }
        }
    }

    private var reportIsPresented: Binding<Bool> {
        Binding(
            get: { reportReason != nil },
            set: { if !$0 { reportReason = nil } }
        )
    }

    @ViewBuilder
    private var relationshipButton: some View {
        if state == .friends {
            Menu {
                Button("Remove friend", role: .destructive) {
                    Task { await relationshipAction() }
                }
            } label: {
                Label("Friends", systemImage: "person.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isWorking)
        } else {
            Button {
                Task { await relationshipAction() }
            } label: {
                Label(actionTitle, systemImage: actionIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isWorking || state == .self)
        }
    }

    private func profileMap(_ visits: [PublicProfileVisit]) -> some View {
        let cafes = visits.compactMap(\.cafe)
        return MapViewRepresentable(
            region: .constant(profileRegion(visits)),
            cafes: Array(Dictionary(grouping: cafes, by: \.id).values.compactMap { $0.first }),
            highlightedCafe: nil,
            friendCounts: [:],
            pinScores: [:],
            placeNames: [:],
            showsFriendContext: false,
            showsUserLocation: false,
            trackingMode: .constant(.none),
            onCafeTap: { _ in },
            onClusterListRequested: { _ in }
        )
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .padding(.horizontal)
        .accessibilityLabel("Visible cafe map")
    }

    private func visibleVisits(_ visits: [PublicProfileVisit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: "Public tasting journal",
                subtitle: "Only sips shared with you appear here."
            )
            MugshotSegmentedControl(
                options: PublicSipFilter.allCases,
                selection: $selectedSipFilter,
                title: { $0.rawValue }
            )
            ForEach(filteredPublicVisits(visits)) { visit in
                Button {
                    selectedVisit = visit.summary(profile: payload!.profile)
                } label: {
                    RemoteJournalRow(visit: visit.summary(profile: payload!.profile))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func profileRegion(_ visits: [PublicProfileVisit]) -> MKCoordinateRegion {
        guard let first = visits.first(where: { $0.latitude != nil && $0.longitude != nil }),
              let latitude = first.latitude,
              let longitude = first.longitude else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 55)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )
    }

    private func filteredPublicVisits(_ visits: [PublicProfileVisit]) -> [PublicProfileVisit] {
        visits.filter { visit in
            switch selectedSipFilter {
            case .all: return true
            case .cafe: return visit.journalContext == .cafe
            case .home: return visit.journalContext == .home
            }
        }
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
        guard let expectedAccountID = authModel.authenticatedUser?.id else {
            resetForAccountChange(accountID: nil)
            errorMessage = "Sign in to view profiles."
            return
        }
        do {
            let socialService = try service()
            let loadedPayload = try await socialService.publicProfile(userID: route.id)
            guard authModel.authenticatedUser?.id == expectedAccountID,
                  !Task.isCancelled else { return }
            payload = loadedPayload
            await loadPassport(expectedAccountID: expectedAccountID)
            guard authModel.authenticatedUser?.id == expectedAccountID,
                  !Task.isCancelled else { return }
            state = loadedPayload.friendshipState
            if phase4LightweightFriends && state == .friends {
                let loadedCompatibility = try? await socialService.compatibility(with: route.id)
                guard authModel.authenticatedUser?.id == expectedAccountID,
                      !Task.isCancelled else { return }
                compatibility = loadedCompatibility
            } else {
                compatibility = nil
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            if state == .blocked {
                passportState = .loaded(.hidden)
            }
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor private func relationshipAction() async {
        guard let expectedAccountID = authModel.authenticatedUser?.id,
              !isWorking else { return }
        isWorking = true
        defer {
            if authModel.authenticatedUser?.id == expectedAccountID {
                isWorking = false
            }
        }
        do {
            let service = try service()
            switch state {
            case .none:
                try await service.sendFriendRequest(to: route.id)
                guard authModel.authenticatedUser?.id == expectedAccountID else { return }
                state = .outgoing
            case .incoming:
                guard let requestID = try await requestID(kind: "incoming", service: service) else { return }
                guard authModel.authenticatedUser?.id == expectedAccountID else { return }
                try await service.respond(to: requestID, accept: true)
                guard authModel.authenticatedUser?.id == expectedAccountID else { return }
                state = .friends
            case .outgoing:
                guard let requestID = try await requestID(kind: "outgoing", service: service) else { return }
                guard authModel.authenticatedUser?.id == expectedAccountID else { return }
                try await service.cancel(requestID: requestID)
                guard authModel.authenticatedUser?.id == expectedAccountID else { return }
                state = .none
            case .friends:
                try await service.removeFriend(userID: route.id)
                guard authModel.authenticatedUser?.id == expectedAccountID else { return }
                state = .none
            case .blocked:
                try await SocialSafetyService(
                    client: try SupabaseClientProvider.shared.client()
                ).unblock(
                    userID: route.id,
                    expectedAccountID: expectedAccountID
                )
                guard authModel.authenticatedUser?.id == expectedAccountID else { return }
                state = .none
                safetyStatus = "@\(route.username) is unblocked. Removed social activity was not restored."
                dataManager.noteJournalMutation()
            case .self: break
            }
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            await onRelationshipChanged()
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            await load()
        } catch {
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor private func declineRequest() async {
        guard let expectedAccountID = authModel.authenticatedUser?.id else { return }
        isWorking = true
        defer {
            if authModel.authenticatedUser?.id == expectedAccountID {
                isWorking = false
            }
        }
        do {
            let service = try service()
            guard let requestID = try await requestID(kind: "incoming", service: service) else { return }
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            try await service.respond(to: requestID, accept: false)
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            state = .none
            await onRelationshipChanged()
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            await load()
        } catch {
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    private func requestID(kind: String, service: SocialDiscoveryService) async throws -> UUID? {
        if let relationshipID = route.relationshipID { return relationshipID }
        return try await service.connections(kind: kind).first(where: { $0.userID == route.id })?.relationshipID
    }

    @MainActor private func block(removeSavedRecipeCopies: Bool) async {
        guard let expectedAccountID = authModel.authenticatedUser?.id else {
            errorMessage = "Sign in to block an account."
            return
        }
        isWorking = true
        defer {
            if authModel.authenticatedUser?.id == expectedAccountID {
                isWorking = false
            }
        }
        do {
            _ = try await SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            ).block(
                userID: route.id,
                expectedAccountID: expectedAccountID,
                removeSavedRecipeCopies: removeSavedRecipeCopies
            )
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            state = .blocked
            payload = nil
            compatibility = nil
            passportState = .loaded(.hidden)
            errorMessage = nil
            safetyStatus = "@\(route.username) is blocked."
            dataManager.noteJournalMutation()
            await onRelationshipChanged()
        } catch {
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            let message = MugshotUserFacingError.message(for: error, context: .social)
            errorMessage = message
            safetyStatus = message
        }
    }

    private func confirmSelectedReport() {
        guard let reportReason else { return }
        self.reportReason = nil
        if reportReason == .other {
            reportDetailsRequest = SafetyReportDetailsRequest(target: .user(route.id))
        } else {
            Task { await report(reason: reportReason, details: nil) }
        }
    }

    @MainActor private func report(reason: ReportReason, details: String?) async {
        guard let accountID = authModel.authenticatedUser?.id else {
            errorMessage = "Sign in to report a profile."
            return
        }
        reportDetailsRequest = nil
        do {
            let service = SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            )
            let receipt = try service.prepareReport(
                accountID: accountID,
                target: .user(route.id),
                reason: reason,
                details: details
            )
            await submitPreparedReport(receipt)
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor private func submitPreparedReport(_ receipt: SafetyReportReceipt) async {
        guard authModel.authenticatedUser?.id == receipt.accountID else {
            errorMessage = "Sign in to the account that started this report before retrying."
            return
        }
        isWorking = true
        safetyStatus = SocialSafetyCopy.reportPending
        failedReportReceipt = nil
        do {
            let outcome = try await SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            ).submit(receipt)
            guard authModel.authenticatedUser?.id == receipt.accountID else { return }
            isWorking = false
            switch outcome {
            case .submitted:
                safetyStatus = SocialSafetyCopy.reportSubmitted
            case .failed(let failedReceipt):
                safetyStatus = SocialSafetyCopy.reportFailed
                failedReportReceipt = failedReceipt
            }
        } catch {
            guard authModel.authenticatedUser?.id == receipt.accountID else { return }
            isWorking = false
            safetyStatus = nil
            let message = MugshotUserFacingError.message(for: error, context: .social)
            errorMessage = message
            if (error as? SocialSafetyServiceError) != .accountScopeChanged {
                failedReportReceipt = receipt
            }
        }
    }

    private func service() throws -> SocialDiscoveryService {
        SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
    }

    @MainActor
    private func loadPassport(expectedAccountID: UUID? = nil) async {
        guard let activeAccountID = authModel.authenticatedUser?.id,
              expectedAccountID == nil || expectedAccountID == activeAccountID else {
            passportState = .loaded(.hidden)
            return
        }
        passportState = .loading
        do {
            let client = try SupabaseClientProvider.shared.client()
            let access = try await TastePassportService(client: client)
                .fetchPassport(userID: route.id)
            guard authModel.authenticatedUser?.id == activeAccountID,
                  !Task.isCancelled else { return }
            passportState = .loaded(access)
        } catch is CancellationError {
            return
        } catch {
            guard authModel.authenticatedUser?.id == activeAccountID else { return }
            passportState = .failed(
                MugshotUserFacingError.message(for: error, context: .loading)
            )
        }
    }

    @MainActor
    private func resetForAccountChange(accountID: UUID?) {
        payload = nil
        compatibility = nil
        passportState = accountID == nil ? .loaded(.hidden) : .loading
        selectedVisit = nil
        reportReason = nil
        reportDetailsRequest = nil
        failedReportReceipt = nil
        showBlockConfirmation = false
        safetyStatus = nil
        errorMessage = nil
        isWorking = false
        state = .none
    }
}

private struct SharedRecipeDetailView: View {
    let recipe: SharedRecipeRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.recipeName)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundColor(.espressoBrown)
                        Text(recipe.versionLabel?.remoteTrimmedNonEmpty ?? "Version \(recipe.versionNumber)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.mugshotSage)
                        if let note = recipe.note?.remoteTrimmedNonEmpty {
                            Text(note)
                                .font(.system(size: 15))
                                .foregroundColor(.secondaryText)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recipe details")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        recipeRow("Beans", recipe.brewDetails.beans)
                        recipeRow("Origin", recipe.brewDetails.beanOrigin)
                        recipeRow("Roast", recipe.brewDetails.roastLevel)
                        recipeRow("Grind", recipe.brewDetails.grindSetting)
                        recipeRow("Ratio", recipe.brewDetails.extractionSummary)
                        recipeRow("Water", recipe.brewDetails.waterNotes)
                        recipeRow("Additions", recipe.brewDetails.additions)
                    }
                    .padding(16)
                    .cardStyle()

                    if let steps = recipe.brewDetails.steps, !steps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Steps")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.foamWhite)
                                        .frame(width: 26, height: 26)
                                        .background(Color.mugshotSage)
                                        .clipShape(Circle())
                                    Text(step.instruction)
                                        .font(.system(size: 14))
                                        .foregroundColor(.espressoBrown)
                                }
                            }
                        }
                        .padding(16)
                        .cardStyle()
                    }

                    Text("Shared recipes include brew instructions only. Private journal notes are never included.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                .padding(16)
            }
            .background(Color.creamWhite)
            .navigationTitle("Shared recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    @ViewBuilder
    private func recipeRow(_ title: String, _ value: String?) -> some View {
        if let value = value?.remoteTrimmedNonEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.espressoBrown)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
