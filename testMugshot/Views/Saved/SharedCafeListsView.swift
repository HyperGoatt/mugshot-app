import MapKit
import SwiftUI

struct SharedCafeListsView: View {
    @ObservedObject var dataManager: DataManager
    let currentUserID: UUID

    @State private var lists: [CafeListRecord] = []
    @State private var pendingMemberships: [CafeListMemberRecord] = []
    @State private var isPresentingNewList = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MugshotSectionTitle(
                    title: "Cafe lists",
                    subtitle: "Keep places together or plan with friends."
                )
                Spacer()
                Button {
                    isPresentingNewList = true
                } label: {
                    Label("New list", systemImage: "plus")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.bordered)
                .tint(.mugshotSage)
            }

            if isLoading && lists.isEmpty {
                ProgressView("Loading lists…")
                    .tint(.mugshotSage)
            } else if lists.isEmpty {
                Button {
                    isPresentingNewList = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.mugshotSage)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start a cafe list")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            Text("Try a neighborhood, trip, or coffee date list.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.tertiaryText)
                    }
                    .padding(14)
                    .cardStyle()
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(lists) { list in
                            if pendingMemberships.contains(where: { $0.listID == list.id }) {
                                VStack(spacing: 8) {
                                    CafeListTile(list: list, isOwner: false)
                                    HStack(spacing: 8) {
                                        Button("Decline") {
                                            Task { await respond(to: list.id, accept: false) }
                                        }
                                        .buttonStyle(.bordered)
                                        Button("Join") {
                                            Task { await respond(to: list.id, accept: true) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .tint(.mugshotSage)
                                }
                            } else {
                                NavigationLink {
                                    CafeListDetailView(
                                        list: list,
                                        dataManager: dataManager,
                                        currentUserID: currentUserID
                                    )
                                } label: {
                                    CafeListTile(list: list, isOwner: list.ownerID == currentUserID)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.82))
            }
        }
        .task { await load() }
        .sheet(isPresented: $isPresentingNewList) {
            NewCafeListView { list in
                lists.insert(list, at: 0)
                isPresentingNewList = false
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            async let loadedLists = service.cafeLists()
            async let memberships = service.cafeListMemberships(userID: currentUserID)
            let (resolvedLists, resolvedMemberships) = try await (loadedLists, memberships)
            lists = resolvedLists
            pendingMemberships = resolvedMemberships.filter { $0.invitationStatus == "pending" }
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func respond(to listID: UUID, accept: Bool) async {
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            try await service.respondToListInvitation(listID: listID, accept: accept)
            await load()
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }
}

private struct CafeListTile: View {
    let list: CafeListRecord
    let isOwner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: list.visibility == .private ? "lock.fill" : "person.2.fill")
                .foregroundColor(.mugshotSage)
            Text(list.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
            Text(isOwner ? list.visibility.title : "Shared with you")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
        .frame(width: 154, height: 112, alignment: .topLeading)
        .padding(14)
        .cardStyle()
    }
}

private struct NewCafeListView: View {
    let onCreated: (CafeListRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var visibility: CafeListVisibility = .private
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("List") {
                    TextField("Weekend coffee crawl", text: $title)
                    TextField("Optional note", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Who can see it") {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(CafeListVisibility.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Text("Invited-only lists stay hidden until you choose collaborators.")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("New cafe list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Creating…" : "Create") {
                        Task { await create() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    @MainActor
    private func create() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            let list = try await service.createCafeList(
                title: title,
                description: description,
                visibility: visibility
            )
            onCreated(list)
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }
}

private struct CafeListDetailView: View {
    let list: CafeListRecord
    @ObservedObject var dataManager: DataManager
    let currentUserID: UUID

    @State private var items: [CafeListItemRecord] = []
    @State private var members: [CafeListMemberRecord] = []
    @State private var friends: [SocialConnection] = []
    @State private var isPresentingCafePicker = false
    @State private var isPresentingFriendPicker = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MugshotScreenHeader(list.title, subtitle: list.description ?? list.visibility.title)

                if list.ownerID == currentUserID {
                    HStack(spacing: 10) {
                        Button { isPresentingCafePicker = true } label: {
                            Label("Add cafe", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mugshotSage)

                        Button { isPresentingFriendPicker = true } label: {
                            Label("Invite", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .tint(.mugshotSage)
                    }
                    .padding(.horizontal, 16)
                }

                if items.isEmpty {
                    MugsyEmptyStateView(
                        asset: .noFavorites,
                        title: "No cafes yet",
                        message: "Add a cafe to begin this list."
                    )
                    .padding(.horizontal, 16)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            cafeItem(item)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !members.isEmpty {
                    MugshotSectionTitle(title: "Collaborators", subtitle: "Editors can add and reorder cafes.")
                        .padding(.horizontal, 16)
                    Text("\(acceptedMemberCount) joined · \(pendingMemberCount) pending")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 16)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.82))
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.creamWhite)
        .navigationTitle("Cafe list")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $isPresentingCafePicker) {
            CafeListCafePicker(
                dataManager: dataManager,
                existingCafeIDs: Set(items.map(\.cafeID))
            ) { cafe in
                Task { await add(cafe) }
            }
        }
        .sheet(isPresented: $isPresentingFriendPicker) {
            CafeListFriendPicker(
                initialFriends: friends,
                existingMemberIDs: Set(members.map(\.userID))
            ) { friend, role in
                let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
                _ = try await service.inviteFriend(friend.userID, to: list.id, role: role)
                await load()
            }
        }
    }

    private var acceptedMemberCount: Int {
        members.filter { $0.invitationStatus == "accepted" }.count
    }

    private var pendingMemberCount: Int {
        members.filter { $0.invitationStatus == "pending" }.count
    }

    private func cafeItem(_ item: CafeListItemRecord) -> some View {
        let cafe = dataManager.appData.cafes.first { ($0.remoteCafeId ?? $0.id) == item.cafeID }
        return HStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .foregroundColor(.mugshotSage)
                .frame(width: 38, height: 38)
                .background(Color.mugshotSage.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(cafe?.consumerDisplayName ?? "Saved cafe")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.espressoBrown)
                if let note = item.note?.remoteTrimmedNonEmpty {
                    Text(note).font(.system(size: 12)).foregroundColor(.secondaryText)
                }
            }
            Spacer()
            if canEditList && items.count > 1 {
                VStack(spacing: 2) {
                    Button { Task { await move(item, by: -1) } } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(item.position == 0)
                    Button { Task { await move(item, by: 1) } } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(item.position >= items.count - 1)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.mugshotSage)
                .buttonStyle(.plain)
                .accessibilityLabel("Move \(cafe?.consumerDisplayName ?? "cafe")")
            } else {
                Text("\(item.position + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(12)
        .cardStyle()
    }

    private var canEditList: Bool {
        list.ownerID == currentUserID || members.contains {
            $0.userID == currentUserID && $0.role == "editor" && $0.invitationStatus == "accepted"
        }
    }

    @MainActor
    private func load() async {
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            async let loadedItems = service.cafeListItems(listID: list.id)
            async let loadedMembers = service.cafeListMembers(listID: list.id)
            async let loadedFriends = service.connections(kind: "friends")
            (items, members, friends) = try await (loadedItems, loadedMembers, loadedFriends)
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func add(_ cafe: Cafe) async {
        do {
            let client = try SupabaseClientProvider.shared.client()
            let remoteCafe = try await CafeService(client: client).findOrCreateCafe(from: cafe)
            dataManager.upsertRemoteCafe(remoteCafe)
            let service = SocialDiscoveryService(client: client)
            _ = try await service.addCafe(remoteCafe.id, to: list.id)
            isPresentingCafePicker = false
            await load()
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func move(_ item: CafeListItemRecord, by offset: Int) async {
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            _ = try await service.moveCafeListItem(item.id, to: item.position + offset)
            items = try await service.cafeListItems(listID: list.id)
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }
}

private struct CafeListCafePicker: View {
    @ObservedObject var dataManager: DataManager
    let existingCafeIDs: Set<UUID>
    let onSelect: (Cafe) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = MapSearchService()
    @StateObject private var locationManager = LocationManager()
    @State private var query = ""
    @State private var resolvingSuggestion: String?
    @State private var selectedMapItem: MKMapItem?
    @State private var mapPosition: MapCameraPosition = .automatic

    private var searchRegion: MKCoordinateRegion {
        if let location = locationManager.location?.coordinate {
            return MKCoordinateRegion(
                center: location,
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
            guard let id = cafe.remoteCafeId else { return true }
            return !existingCafeIDs.contains(id)
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
                            .onChange(of: query) { _, value in
                                if value.remoteTrimmedNonEmpty == nil {
                                    searchService.cancelSearch()
                                } else {
                                    searchService.search(query: value, region: searchRegion)
                                }
                            }
                            .onSubmit {
                                searchService.search(query: query, region: searchRegion, immediately: true)
                            }
                    }
                } footer: {
                    Text("Search works beyond your saved and visited cafes, so lists can plan a future trip.")
                }

                if query.remoteTrimmedNonEmpty != nil,
                   !searchService.searchResults.isEmpty {
                    Section {
                        Map(position: $mapPosition) {
                            ForEach(searchService.searchResults, id: \.self) { item in
                                Annotation(
                                    item.name ?? "Cafe",
                                    coordinate: item.placemark.coordinate,
                                    anchor: .bottom
                                ) {
                                    Button {
                                        focus(item)
                                    } label: {
                                        Image(systemName: selectedMapItem == item ? "cup.and.saucer.fill" : "mappin.circle.fill")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(
                                                selectedMapItem == item ? Color.espressoBrown : Color.mugshotSage,
                                                Color.foamWhite
                                            )
                                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Select \(item.name ?? "cafe")")
                                }
                            }
                        }
                        .mapStyle(.standard(pointsOfInterest: .including([.cafe, .bakery])))
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                        if let selectedMapItem {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(selectedMapItem.name ?? "Cafe")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.espressoBrown)
                                    Text(MapSearchService.subtitle(for: selectedMapItem))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button("Add") { select(selectedMapItem) }
                                    .font(.system(size: 13, weight: .bold))
                                    .buttonStyle(.borderedProminent)
                                    .tint(.mugshotSage)
                            }
                        }
                    } header: {
                        Text("Choose on the map")
                    }
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
                                Text(searchService.isSearching ? "Finding cafes…" : "Finding suggestions…")
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }

                    if !searchService.completions.isEmpty && searchService.searchResults.isEmpty {
                        Section("Suggestions") {
                            ForEach(searchService.completions.prefix(6), id: \.self) { completion in
                                Button {
                                    resolvingSuggestion = completion.title
                                    Task {
                                        if let item = await searchService.resolve(completion: completion, region: searchRegion) {
                                            focus(item)
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
                                Button { focus(item) } label: {
                                    HStack {
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
                                        Spacer()
                                        Image(systemName: selectedMapItem == item ? "checkmark.circle.fill" : "mappin.circle")
                                            .foregroundColor(.mugshotSage)
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
                guard value.remoteTrimmedNonEmpty != nil else { return }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, query == value else { return }
                searchService.search(query: value, region: searchRegion, immediately: true)
            }
            .onAppear {
                mapPosition = .region(searchRegion)
            }
            .onChange(of: searchService.completedQuery) { _, _ in
                guard let first = searchService.searchResults.first else { return }
                focus(first)
            }
        }
    }

    private func cafeButton(_ cafe: Cafe) -> some View {
        Button { onSelect(cafe) } label: {
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

    private func select(_ item: MKMapItem) {
        let cafe = dataManager.findOrCreateCafe(from: item)
        searchService.recordRecent(item)
        onSelect(cafe)
    }

    private func focus(_ item: MKMapItem) {
        selectedMapItem = item
        mapPosition = .region(MKCoordinateRegion(
            center: item.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        ))
    }
}

private struct CafeListFriendPicker: View {
    let initialFriends: [SocialConnection]
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
            $0.displayName.localizedLowercase.contains(search) ||
                $0.username.localizedLowercase.contains(search)
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
                    Text(role == "editor" ? "Editors can add and reorder cafes." : "Viewers can follow the list without changing it.")
                }

                Section("Friends") {
                    if isLoading && friends.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Finding your friends…")
                                .foregroundColor(.secondaryText)
                        }
                    } else if availableFriends.isEmpty {
                        Text(query.remoteTrimmedNonEmpty == nil
                            ? "Everyone here has already been invited."
                            : "No friends match that search.")
                            .foregroundColor(.secondaryText)
                    } else {
                        ForEach(availableFriends) { friend in
                            Button {
                                invite(friend)
                            } label: {
                                HStack(spacing: 12) {
                                    MugshotAvatar(name: friend.displayName, size: 42, imageURL: friend.avatarURL)
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
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.82))
                    }
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
        friends = initialFriends
        guard friends.isEmpty else { return }
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
