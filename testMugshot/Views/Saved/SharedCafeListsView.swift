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
                cafes: dataManager.appData.cafes,
                existingCafeIDs: Set(items.map(\.cafeID))
            ) { cafe in
                Task { await add(cafe) }
            }
        }
        .sheet(isPresented: $isPresentingFriendPicker) {
            CafeListFriendPicker(friends: friends) { friend, role in
                Task { await invite(friend, role: role) }
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
        guard let cafeID = cafe.remoteCafeId else {
            errorMessage = "This cafe needs to finish syncing before it can join a shared list."
            return
        }
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            _ = try await service.addCafe(cafeID, to: list.id)
            isPresentingCafePicker = false
            await load()
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func invite(_ friend: SocialConnection, role: String) async {
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            _ = try await service.inviteFriend(friend.userID, to: list.id, role: role)
            isPresentingFriendPicker = false
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
    let cafes: [Cafe]
    let existingCafeIDs: Set<UUID>
    let onSelect: (Cafe) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(cafes.filter { cafe in
                guard let id = cafe.remoteCafeId else { return false }
                return !existingCafeIDs.contains(id)
            }) { cafe in
                Button(cafe.consumerDisplayName) { onSelect(cafe) }
                    .foregroundColor(.espressoBrown)
            }
            .navigationTitle("Add a cafe")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

private struct CafeListFriendPicker: View {
    let friends: [SocialConnection]
    let onSelect: (SocialConnection, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var role = "viewer"

    var body: some View {
        NavigationStack {
            List {
                Picker("Permission", selection: $role) {
                    Text("Can view").tag("viewer")
                    Text("Can edit").tag("editor")
                }
                ForEach(friends) { friend in
                    Button {
                        onSelect(friend, role)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(friend.displayName).fontWeight(.semibold)
                            Text("@\(friend.username)").font(.caption).foregroundColor(.secondaryText)
                        }
                    }
                }
            }
            .navigationTitle("Invite a friend")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
