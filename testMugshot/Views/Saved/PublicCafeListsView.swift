import MapKit
import SwiftUI

struct PublicCafeListsSection: View {
    @ObservedObject var dataManager: DataManager
    let currentUserID: UUID

    @State private var lists: [PublicCafeList] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var following: [PublicCafeList] { lists.filter(\.isFollowing) }
    private var explore: [PublicCafeList] { lists.filter { !$0.isFollowing } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                MugshotLoadingState(layout: .collection, count: 2)
            } else if !following.isEmpty {
                listRow(title: "Following", lists: following)
            }

            if !explore.isEmpty {
                listRow(
                    title: following.isEmpty ? "Public cafe lists" : "Explore public lists",
                    lists: explore
                )
            }

            if let errorMessage, lists.isEmpty, !isLoading {
                InlineCafeListNotice(
                    title: "Public lists need another try",
                    message: errorMessage,
                    actionTitle: "Try again"
                ) {
                    Task { await load() }
                }
            }
        }
        .task(id: currentUserID) { await load() }
    }

    private func listRow(title: String, lists: [PublicCafeList]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(lists) { list in
                        NavigationLink {
                            PublicCafeListDetailView(
                                initialList: list,
                                dataManager: dataManager,
                                currentUserID: currentUserID,
                                onChanged: update
                            )
                        } label: {
                            PublicCafeListTile(list: list)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.bottom, 4)
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            lists = try await PublicCafeListService(
                client: try SupabaseClientProvider.shared.client()
            ).browse()
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    private func update(_ updated: PublicCafeList) {
        guard let index = lists.firstIndex(where: { $0.id == updated.id }) else { return }
        lists[index] = updated
    }
}

struct PublicCafeListLinkView: View {
    let route: PublicCafeListLinkRoute
    @ObservedObject var dataManager: DataManager
    let currentUserID: UUID?

    @State private var list: PublicCafeList?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let list {
                PublicCafeListDetailView(
                    initialList: list,
                    dataManager: dataManager,
                    currentUserID: currentUserID,
                    onChanged: { self.list = $0 }
                )
            } else if let errorMessage {
                ContentUnavailableView(
                    "This cafe list is not available",
                    systemImage: "list.bullet.rectangle",
                    description: Text(errorMessage)
                )
            } else {
                MugshotLoadingState(layout: .journal, count: 4)
            }
        }
        .task(id: route.slug) {
            do {
                list = try await PublicCafeListService(
                    client: try SupabaseClientProvider.shared.client()
                ).list(slug: route.slug)
                errorMessage = nil
            } catch {
                errorMessage = "It may have been removed or made private."
            }
        }
    }
}

private struct PublicCafeListTile: View {
    let list: PublicCafeList

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 36, height: 36)
                    .background(Color.mugshotSage.opacity(0.12), in: Circle())
                Spacer()
                if list.isFollowing {
                    Label("Following", systemImage: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.mugshotSage)
                }
            }

            Text(list.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
            Text("by \(list.creator.visibleName)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
            Label(
                "\(list.cafeCount) \(list.cafeCount == 1 ? "cafe" : "cafes")",
                systemImage: "cup.and.saucer.fill"
            )
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondaryText)
        }
        .frame(width: 190, height: 138, alignment: .topLeading)
        .padding(14)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

struct PublicCafeListDetailView: View {
    @ObservedObject var dataManager: DataManager
    let currentUserID: UUID?
    let onChanged: (PublicCafeList) -> Void

    @State private var list: PublicCafeList
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var commentText = ""
    @State private var presentedCafe: Cafe?

    init(
        initialList: PublicCafeList,
        dataManager: DataManager,
        currentUserID: UUID?,
        onChanged: @escaping (PublicCafeList) -> Void
    ) {
        _list = State(initialValue: initialList)
        self.dataManager = dataManager
        self.currentUserID = currentUserID
        self.onChanged = onChanged
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MugshotScreenHeader(
                    list.title,
                    subtitle: list.description ?? "A public cafe list by \(list.creator.visibleName)"
                )

                creatorLine
                    .padding(.horizontal, 16)
                actionRow
                    .padding(.horizontal, 16)

                if let inspiration = list.inspiredBy {
                    Label(
                        "Inspired by \(inspiration.creator.visibleName)",
                        systemImage: "sparkles"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondaryText)
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
                        title: "That needs another try",
                        message: errorMessage,
                        actionTitle: "Reload"
                    ) { Task { await load() } }
                    .padding(.horizontal, 16)
                }

                if isLoading, list.items == nil {
                    MugshotLoadingState(layout: .journal, count: 4)
                        .padding(.horizontal, 16)
                } else {
                    cafesSection
                    commentsSection
                }
            }
            .padding(.bottom, 36)
        }
        .background(Color.creamWhite)
        .navigationTitle("Public cafe list")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: list.slug) { await load() }
        .sheet(item: $presentedCafe) { cafe in
            CafeDetailView(
                cafe: cafe,
                dataManager: dataManager,
                discoverySource: .publicList
            )
        }
    }

    private var creatorLine: some View {
        HStack(spacing: 10) {
            MugshotAvatar(
                name: list.creator.visibleName,
                size: 36,
                imageURL: list.creator.avatarURL
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(list.creator.visibleName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text("\(list.followerCount) followers · \(list.cafeCount) cafes")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
        }
    }

    private var actionRow: some View {
        HStack(spacing: 9) {
            Button {
                Task { await toggleFollowing() }
            } label: {
                Label(
                    list.isFollowing ? "Following" : "Follow",
                    systemImage: list.isFollowing ? "checkmark" : "plus"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.mugshotSage)

            Button {
                Task { await copyList() }
            } label: {
                Label("Copy", systemImage: "square.on.square")
            }
            .buttonStyle(.bordered)
            .tint(.mugshotSage)

            if let url = URL(string: "https://mugshotapp.co/l/\(list.slug)") {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(.mugshotSage)
                .accessibilityLabel("Share cafe list")
            }
        }
        .disabled(isWorking)
    }

    private var cafesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: "Cafes",
                subtitle: "An ordered shortlist from \(list.creator.visibleName)."
            )
            .padding(.horizontal, 16)

            if list.resolvedItems.isEmpty {
                MugsyEmptyStateView(
                    placement: .sharedLists,
                    title: "No cafes yet",
                    message: "The creator is still building this list."
                )
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(list.resolvedItems) { item in
                        PublicCafeListItemRow(
                            item: item,
                            isSaved: dataManager.getCafe(id: item.cafeID)?.wantToTry == true,
                            isWorking: isWorking,
                            onOpen: { open(item) },
                            onSave: { Task { await save(item) } },
                            onDirections: { openDirections(for: item) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: "Comments",
                subtitle: list.commentsEnabled
                    ? "Keep the planning conversation useful and kind."
                    : "The creator turned comments off."
            )
            .padding(.horizontal, 16)

            if list.canComment {
                HStack(alignment: .bottom, spacing: 9) {
                    TextField("Add a comment", text: $commentText, axis: .vertical)
                        .lineLimit(1 ... 4)
                        .textFieldStyle(.roundedBorder)
                    Button("Post") { Task { await postComment() } }
                        .font(.system(size: 13, weight: .bold))
                        .disabled(commentText.remoteTrimmedNonEmpty == nil || isWorking)
                }
                .padding(.horizontal, 16)
            }

            ForEach(list.resolvedComments) { comment in
                HStack(alignment: .top, spacing: 10) {
                    MugshotAvatar(
                        name: comment.author.visibleName,
                        size: 30,
                        imageURL: comment.author.avatarURL
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(comment.author.visibleName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        Text(comment.body)
                            .font(.system(size: 13))
                            .foregroundColor(.primaryText)
                    }
                    Spacer(minLength: 6)
                    Menu {
                        if comment.canDelete {
                            Button("Delete", role: .destructive) {
                                Task { await delete(comment) }
                            }
                        } else {
                            Button("Report", role: .destructive) {
                                Task { await report(comment) }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondaryText)
                    }
                    .accessibilityLabel("Comment actions")
                }
                .padding(12)
                .cardStyle()
                .padding(.horizontal, 16)
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await makeService().list(slug: list.slug)
            list = loaded
            onChanged(loaded)
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func toggleFollowing() async {
        guard !isWorking else { return }
        guard currentUserID != nil else {
            statusMessage = "Sign in to follow public cafe lists."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await makeService().setFollowing(listID: list.id, following: !list.isFollowing)
            list.isFollowing.toggle()
            onChanged(list)
            statusMessage = list.isFollowing ? "Added to Saved → Following." : "Removed from Following."
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func copyList() async {
        guard !isWorking else { return }
        guard currentUserID != nil else {
            statusMessage = "Sign in to copy this cafe list."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let copied = try await makeService().copy(listID: list.id)
            statusMessage = "Copied as the private list “\(copied.title).”"
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func save(_ item: PublicCafeListItem) async {
        guard !isWorking else { return }
        guard let currentUserID else {
            statusMessage = "Sign in to save this cafe."
            return
        }
        isWorking = true
        defer { isWorking = false }
        let previous = dataManager.getCafe(id: item.localCafe.id)
        let cafe = dataManager.saveDiscoveryCandidate(
            DiscoveryPlaceCandidate(cafe: item.localCafe),
            wantToTry: true,
            note: nil,
            source: .publicList
        )
        dataManager.setCafeState(
            cafeId: cafe.id,
            isFavorite: previous?.isFavorite ?? false,
            wantToTry: true
        )
        do {
            let result = try await CafeStateService(
                client: try SupabaseClientProvider.shared.client()
            ).setCafeState(
                userId: currentUserID,
                cafe: cafe,
                isFavorite: previous?.isFavorite ?? false,
                wantToTry: true,
                discoverySource: .publicList,
                discoveredAt: cafe.discoveredAt ?? .now
            )
            dataManager.upsertRemoteCafe(
                result.cafe,
                isFavorite: result.state.isFavorite,
                wantToTry: result.state.wantToTry
            )
            _ = try? await DiscoveryInteractionService(
                client: try SupabaseClientProvider.shared.client()
            ).record(
                cafeID: result.cafe.id,
                appleMapsPlaceID: result.cafe.appleMapsPlaceID,
                source: .publicList,
                kind: .listSaved,
                sourceListID: list.id
            )
            statusMessage = "Saved \(cafe.name) to Want to Try."
            errorMessage = nil
        } catch {
            dataManager.setCafeState(
                cafeId: cafe.id,
                isFavorite: previous?.isFavorite ?? false,
                wantToTry: previous?.wantToTry ?? false
            )
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func postComment() async {
        guard let body = commentText.remoteTrimmedNonEmpty, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await makeService().comment(listID: list.id, body: body)
            commentText = ""
            await load()
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func delete(_ comment: PublicCafeListComment) async {
        do {
            try await makeService().delete(commentID: comment.id)
            await load()
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func report(_ comment: PublicCafeListComment) async {
        do {
            try await makeService().report(commentID: comment.id, reason: .other)
            statusMessage = "Report received. Thank you."
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    private func makeService() throws -> PublicCafeListService {
        PublicCafeListService(client: try SupabaseClientProvider.shared.client())
    }

    private func openDirections(for item: PublicCafeListItem) {
        guard let coordinate = item.coordinate else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = item.cafeName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
        recordInteraction(for: item, kind: .directionsRequested)
    }

    private func open(_ item: PublicCafeListItem) {
        presentedCafe = item.localCafe
        recordInteraction(for: item, kind: .publicListOpened)
    }

    private func recordInteraction(
        for item: PublicCafeListItem,
        kind: DiscoveryInteractionKind
    ) {
        Task {
            guard let client = try? SupabaseClientProvider.shared.client() else { return }
            _ = try? await DiscoveryInteractionService(client: client).record(
                cafeID: item.cafeID,
                appleMapsPlaceID: item.appleMapsPlaceID,
                source: .publicList,
                kind: kind,
                sourceListID: list.id
            )
        }
    }
}

private struct PublicCafeListItemRow: View {
    let item: PublicCafeListItem
    let isSaved: Bool
    let isWorking: Bool
    let onOpen: () -> Void
    let onSave: () -> Void
    let onDirections: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    if let photoURL = item.photoURL?.remoteTrimmedNonEmpty {
                        RemotePhotoImageView(
                            urlString: photoURL,
                            placeholderSystemName: "cup.and.saucer.fill",
                            contentMode: .fill
                        )
                        .frame(width: 62, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.mugshotSage)
                            .frame(width: 62, height: 62)
                            .background(Color.mugshotSage.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.cafeName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        if let location = item.cafeAddress ?? item.cafeCity {
                            Text(location)
                                .font(.system(size: 11))
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                        if let caption = item.caption?.remoteTrimmedNonEmpty {
                            Text(caption)
                                .font(.system(size: 12))
                                .foregroundColor(.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 9) {
                Button(action: onDirections) {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
                .buttonStyle(.bordered)
                Button(action: onSave) {
                    Label(isSaved ? "Saved" : "Want to Try", systemImage: isSaved ? "checkmark" : "bookmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.mugshotSage)
            }
            .font(.system(size: 12, weight: .bold))
            .disabled(isWorking || isSaved)
        }
        .padding(13)
        .cardStyle()
    }
}
