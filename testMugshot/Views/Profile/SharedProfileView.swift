import CoreLocation
import MapKit
import SwiftUI
import UIKit

enum SharedProfileSource: Equatable {
    case user(UUID, asEveryone: Bool)
    case share(slug: String)
}

@MainActor
struct SharedProfileView: View {
    let source: SharedProfileSource
    @ObservedObject var dataManager: DataManager
    var showsOwnerControls = false
    var supplementaryContent: AnyView?
    var onEditProfile: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var previewFixture: EditorialProfileFixture?

    @EnvironmentObject private var authModel: AppAuthModel
    @State private var projection: SharedProfileProjection?
    @State private var sips: [PublicProfileVisit] = []
    @State private var cafes: [SharedProfilePublicCafe] = []
    @State private var taggedSips: [PublicProfileVisit] = []
    @State private var selectedTab: SharedProfileTab = .mugshots
    @State private var selectedVisit: RemoteVisitSummary?
    @State private var selectedCafe: Cafe?
    @State private var selectedClusterCafes: [Cafe] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var canLoadMore = true
    @State private var canLoadMoreTagged = true
    @State private var errorMessage: String?
    @State private var profileSharePresentation: ProfileSharePresentation?
    @State private var isPreparingProfileShare = false
    @State private var showsEveryonePreview = false
    @State private var showsFriends = false
    @State private var showsFavoriteEditor = false
    @State private var taggedAction: TaggedProfileAction?

    var body: some View {
        Group {
            if let projection {
                profileBody(projection)
            } else if isLoading {
                ProgressView("Opening profile…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Profile unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(errorMessage ?? "This profile may be private or no longer available.")
                )
            }
        }
        .background(Color.creamWhite)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: source) { await loadInitial() }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedVisit != nil },
                set: { if !$0 { selectedVisit = nil } }
            )
        ) {
            if let selectedVisit {
                RemoteVisitDetailView(
                    visitId: selectedVisit.id,
                    initialSummary: selectedVisit,
                    currentUserId: authModel.authenticatedUser?.id,
                    dataManager: dataManager
                )
            }
        }
        .sheet(item: $profileSharePresentation) { presentation in
            ProfileShareHubView(
                content: presentation.content,
                publicURL: presentation.publicURL
            )
        }
        .sheet(isPresented: $showsEveryonePreview) {
            if let ownerID = projection?.profile.id {
                NavigationStack {
                    SharedProfileView(
                        source: .user(ownerID, asEveryone: true),
                        dataManager: dataManager
                    )
                    .environmentObject(authModel)
                    .navigationTitle("Preview as Everyone")
                }
            }
        }
        .sheet(item: $selectedCafe) { cafe in
            CafeDetailView(cafe: cafe, dataManager: dataManager, initialDetent: .medium)
                .environmentObject(authModel)
        }
        .sheet(
            isPresented: Binding(
                get: { !selectedClusterCafes.isEmpty },
                set: { if !$0 { selectedClusterCafes = [] } }
            )
        ) {
            ProfileMapClusterSheet(cafes: selectedClusterCafes) { cafe in
                selectedClusterCafes = []
                selectedCafe = cafe
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsFriends) {
            if let projection {
                SharedProfileFriendsView(profile: projection.profile, dataManager: dataManager)
                    .environmentObject(authModel)
            }
        }
        .sheet(isPresented: $showsFavoriteEditor) {
            if let projection {
                ProfileFavoriteSpotsEditor(
                    spots: projection.favoriteSpots,
                    dataManager: dataManager
                ) { updated in
                    self.projection = SharedProfileProjection(
                        profile: projection.profile,
                        friendshipState: projection.friendshipState,
                        stats: projection.stats,
                        favoriteSpots: updated,
                        topCafes: projection.topCafes,
                        tastePassportVisible: projection.tastePassportVisible,
                        tastePassport: projection.tastePassport,
                        viewerProjection: projection.viewerProjection,
                        profileContractVersion: projection.profileContractVersion
                    )
                }
                .environmentObject(authModel)
            }
        }
        .confirmationDialog(
            "Tagged Mugshot",
            isPresented: Binding(
                get: { taggedAction != nil },
                set: { if !$0 { taggedAction = nil } }
            ),
            presenting: taggedAction
        ) { action in
            Button("Hide from profile") {
                Task { await hideTaggedSip(action.sip) }
            }
            Button("Remove my tag", role: .destructive) {
                Task { await removeTag(from: action.sip) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Hiding keeps your tag on the Mugshot. Removing your tag also removes it from this profile tab.")
        }
    }

    private func profileBody(_ projection: SharedProfileProjection) -> some View {
        ScrollView {
            // This fixed-size shell stays eager while the post and cafe grids
            // below remain lazy. A LazyVStack wrapping a LazyVGrid can make the
            // outer scroll view repeatedly revise its content height as grid
            // rows are recycled, which presents as an up/down scroll loop.
            VStack(alignment: .leading, spacing: 0) {
                editorialHeader(projection)

                if let supplementaryContent {
                    supplementaryContent
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                }

                if showsOwnerControls {
                    ownerActions
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                }

                favoriteSpotsSection(projection)
                    .padding(.top, 18)

                profileTabRail
                    .padding(.top, 14)

                tabContent(projection)
            }
            .padding(.bottom, 42)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("profile.editorialAtlas")
    }

    private func editorialHeader(_ projection: SharedProfileProjection) -> some View {
        let profile = projection.profile
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                MugshotProfileBanner(
                    imageURL: profile.bannerURL,
                    height: MugshotProfileBanner.compactHeight
                )

                LinearGradient(
                    colors: [.clear, Color.espressoBrown.opacity(0.16)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 14) {
                    MugshotAvatar(name: profile.displayName, size: 104, imageURL: profile.avatarURL)
                        .overlay(Circle().stroke(Color.creamWhite, lineWidth: 5))
                        .shadow(color: .black.opacity(0.14), radius: 16, y: 7)
                        .offset(y: 46)

                    statisticsDock(projection.stats)
                        .offset(y: 30)
                }
                .padding(.horizontal, 18)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(profile.displayName)
                    .mugshotDisplay(size: 32)
                    .foregroundStyle(Color.espressoBrown)
                Text("@\(profile.username)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)

                if let bio = profile.bio?.remoteTrimmedNonEmpty {
                    Text(bio)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.espressoBrown)
                        .fixedSize(horizontal: false, vertical: true)
                }

                profileDetailRail(profile)
            }
            .padding(.horizontal, 18)
            .padding(.top, 58)
        }
    }

    private func statisticsDock(_ stats: SharedProfileStats) -> some View {
        HStack(spacing: 0) {
            statButton("Friends", value: stats.friends) { showsFriends = true }
            Divider().frame(height: 36)
            statButton("Sips", value: stats.sips) {
                withAnimation(.snappy) { selectedTab = .mugshots }
            }
            Divider().frame(height: 36)
            statButton("Cafes", value: stats.cafes) {
                withAnimation(.snappy) { selectedTab = .cafes }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.foamWhite.opacity(0.97), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        .accessibilityIdentifier("profile.statisticsDock")
    }

    private func statButton(_ title: String, value: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .monospacedDigit()
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.espressoBrown)
            .frame(maxWidth: .infinity, minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) \(title)")
    }

    @ViewBuilder
    private func profileDetailRail(_ profile: SupabaseUserProfile) -> some View {
        let instagram = profile.instagramHandle?.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let website = normalizedURL(profile.websiteURL)
        if profile.location?.remoteTrimmedNonEmpty != nil
            || profile.favoriteDrink?.remoteTrimmedNonEmpty != nil
            || instagram?.isEmpty == false
            || website != nil {
            TastingLensFlowLayout(spacing: 14) {
                if let location = profile.location?.remoteTrimmedNonEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .semibold))
                }
                if let favorite = profile.favoriteDrink?.remoteTrimmedNonEmpty {
                    Label(favorite, systemImage: "cup.and.saucer.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                if let instagram, !instagram.isEmpty,
                   let url = URL(string: "https://instagram.com/\(instagram)") {
                    Link(destination: url) { Label("Instagram", systemImage: "camera") }
                        .font(.system(size: 13, weight: .bold))
                }
                if let website {
                    Link(destination: website) { Label("Website", systemImage: "globe") }
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundStyle(Color.mugshotSage)
            .frame(minHeight: 28)
        }
    }

    private var ownerActions: some View {
        HStack(spacing: 10) {
            Button { onEditProfile?() } label: {
                Label("Edit profile", systemImage: "pencil")
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mugshotSage)

            Menu {
                Button("Share profile", systemImage: "square.and.arrow.up") {
                    Task { await shareProfile() }
                }
                .disabled(isPreparingProfileShare)
                Button("Preview as Everyone", systemImage: "eye") { showsEveryonePreview = true }
                Button("Settings", systemImage: "gearshape") { onOpenSettings?() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 42)
                    .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.mugshotLine, lineWidth: 1)
                    }
            }
            .foregroundStyle(Color.espressoBrown)
            .accessibilityLabel("More profile actions")
        }
    }

    @ViewBuilder
    private func favoriteSpotsSection(_ projection: SharedProfileProjection) -> some View {
        if showsOwnerControls || !projection.favoriteSpots.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Favorite Spots")
                        .mugshotDisplay(size: 21)
                        .foregroundStyle(Color.espressoBrown)
                    Spacer()
                    if showsOwnerControls {
                        Button(projection.favoriteSpots.isEmpty ? "Add" : "Edit") {
                            showsFavoriteEditor = true
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                    }
                }

                if projection.favoriteSpots.isEmpty {
                    Button { showsFavoriteEditor = true } label: {
                        Label("Name the cafes you keep coming back to", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.espressoBrown)
                            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                            .padding(.horizontal, 13)
                            .background(Color.sandBeige.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(projection.favoriteSpots.enumerated()), id: \.element.id) { index, spot in
                            if index > 0 {
                                Divider()
                                    .frame(height: 42)
                                    .padding(.horizontal, 9)
                            }
                            favoriteSpotLabel(spot)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private func favoriteSpotLabel(_ spot: SharedProfileFavoriteSpot) -> some View {
        Button { selectedCafe = spot.localCafe } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(spot.descriptor)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .lineLimit(1)
                Text(spot.name)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(Color.espressoBrown)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(spot.name), \(spot.descriptor)")
    }

    private var profileTabRail: some View {
        HStack(spacing: 0) {
            ForEach(SharedProfileTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.28)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 9) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 19, weight: selectedTab == tab ? .semibold : .regular))
                        Capsule()
                            .fill(selectedTab == tab ? Color.mugshotSage : .clear)
                            .frame(height: 3)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.mugshotSage : Color.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityTitle)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .background(Color.foamWhite)
        .overlay(alignment: .top) { Divider() }
        .accessibilityIdentifier("profile.tabRail")
    }

    @ViewBuilder
    private func tabContent(_ projection: SharedProfileProjection) -> some View {
        switch selectedTab {
        case .mugshots:
            mugshotGrid(sips, profile: projection.profile, emptyTitle: "No profile Mugshots yet", isTagged: false)
        case .cafes:
            cafeGrid
        case .map:
            ProfileExplorationMap(
                cafes: cafes,
                onCafeTap: { selectedCafe = $0 },
                onClusterTap: { selectedClusterCafes = $0 }
            )
            .padding(.horizontal, 18)
            .padding(.top, 16)
        case .tagged:
            mugshotGrid(
                taggedSips,
                profile: projection.profile,
                emptyTitle: "No profile tags yet",
                isTagged: true
            )
        }
    }

    @ViewBuilder
    private func mugshotGrid(
        _ visits: [PublicProfileVisit],
        profile: SupabaseUserProfile,
        emptyTitle: String,
        isTagged: Bool
    ) -> some View {
        if visits.isEmpty && !isLoading {
            ContentUnavailableView(
                emptyTitle,
                systemImage: isTagged ? "person.crop.rectangle" : "photo.on.rectangle.angled",
                description: Text("Friends and Everyone Mugshots can appear here. Private Mugshots never do.")
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3),
                spacing: 1
            ) {
                ForEach(visits) { sip in
                    GeometryReader { cell in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                selectedVisit = sip.summary(profile: profile)
                            } label: {
                                profilePhoto(sip)
                                    .frame(width: cell.size.width, height: cell.size.height)
                                    .clipped()
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(sip.drinkDisplayName)")

                            if isTagged && showsOwnerControls {
                                Button { taggedAction = TaggedProfileAction(sip: sip) } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(.black.opacity(0.48), in: Circle())
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Tagged Mugshot actions")
                            }
                        }
                        .onAppear {
                            if !isTagged, sip.id == sips.last?.id { Task { await loadMore() } }
                            if isTagged, sip.id == taggedSips.last?.id { Task { await loadMoreTagged() } }
                        }
                    }
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                }
            }
        }
    }

    @ViewBuilder
    private func profilePhoto(_ sip: PublicProfileVisit) -> some View {
        if let photo = sip.posterPhotoURL?.remoteTrimmedNonEmpty
            ?? sip.photoURLs?.first?.remoteTrimmedNonEmpty {
            RemotePhotoImageView(urlString: photo, placeholderSystemName: "cup.and.saucer.fill", contentMode: .fill)
        } else {
            MugsyPhotoPlaceholderView(
                scene: MugsySceneResolver.scene(for: .journalMemory, stableID: sip.id.uuidString),
                style: .thumbnail,
                photoDescription: "No Mugshot photo"
            )
        }
    }

    private var cafeGrid: some View {
        Group {
            if cafes.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No public cafes yet",
                    systemImage: "storefront",
                    description: Text("Cafes from profile-visible Mugshots appear here. Private Mugshots never do.")
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 14) {
                    ForEach(cafes) { cafe in
                        Button { selectedCafe = cafe.localCafe } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                RemotePhotoImageView(
                                    urlString: cafe.coverPhotoURL,
                                    placeholderSystemName: "storefront.fill",
                                    contentMode: .fill
                                )
                                .frame(maxWidth: .infinity)
                                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                Text(cafe.name)
                                    .font(.system(size: 15, weight: .bold, design: .serif))
                                    .foregroundStyle(Color.espressoBrown)
                                    .lineLimit(2)
                                    .frame(minHeight: 38, alignment: .topLeading)
                                HStack {
                                    Text(cafe.city?.remoteTrimmedNonEmpty ?? "Cafe")
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(cafe.sipCount) sip\(cafe.sipCount == 1 ? "" : "s")")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
        }
    }

    @MainActor
    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        if let previewFixture {
            projection = previewFixture.projection
            sips = previewFixture.sips
            cafes = previewFixture.cafes
            taggedSips = previewFixture.taggedSips
            canLoadMore = false
            canLoadMoreTagged = false
            return
        }
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            let loadedProjection: SharedProfileProjection?
            let loadedSips: [PublicProfileVisit]
            switch source {
            case .user(let userID, _):
                loadedProjection = try await service.projection(userID: userID, asEveryone: true)
                loadedSips = try await service.publicSips(userID: userID)
            case .share(let slug):
                loadedProjection = try await service.sharedProjection(slug: slug)
                loadedSips = try await service.sharedSips(slug: slug)
            }
            guard let loadedProjection else {
                projection = nil
                sips = []
                return
            }

            sips = loadedSips.filter(\.isPublishedOnProfile)
            canLoadMore = loadedSips.count == 24

            switch source {
            case .user(let userID, _):
                do {
                    cafes = try await service.publicCafes(userID: userID)
                } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                    cafes = Self.deriveCafes(from: sips)
                }
                do {
                    taggedSips = try await service.publicTaggedSips(userID: userID)
                    canLoadMoreTagged = taggedSips.count == 24
                } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                    taggedSips = []
                    canLoadMoreTagged = false
                }
            case .share(let slug):
                do {
                    cafes = try await service.sharedCafes(slug: slug)
                } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                    cafes = Self.deriveCafes(from: sips)
                }
                do {
                    taggedSips = try await service.sharedTaggedSips(slug: slug)
                    canLoadMoreTagged = taggedSips.count == 24
                } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
                    taggedSips = []
                    canLoadMoreTagged = false
                }
            }
            if loadedProjection.profileContractVersion >= 4 {
                projection = loadedProjection
            } else {
                projection = SharedProfileProjection(
                    profile: loadedProjection.profile,
                    friendshipState: loadedProjection.friendshipState,
                    stats: SharedProfileStats(
                        friends: loadedProjection.stats.friends,
                        sips: sips.count,
                        cafes: cafes.count
                    ),
                    favoriteSpots: [],
                    topCafes: loadedProjection.topCafes,
                    tastePassportVisible: loadedProjection.tastePassportVisible,
                    tastePassport: loadedProjection.tastePassport,
                    viewerProjection: loadedProjection.viewerProjection,
                    profileContractVersion: loadedProjection.profileContractVersion
                )
            }
        } catch {
            projection = nil
            sips = []
            cafes = []
            taggedSips = []
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func loadMore() async {
        guard canLoadMore, !isLoadingMore, let projection, let last = sips.last else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            let page: [PublicProfileVisit]
            switch source {
            case .user:
                page = try await service.publicSips(
                    userID: projection.profile.id,
                    afterCreatedAt: last.createdAt,
                    afterID: last.id
                )
            case .share(let slug):
                page = try await service.sharedSips(
                    slug: slug,
                    afterCreatedAt: last.createdAt,
                    afterID: last.id
                )
            }
            let existing = Set(sips.map(\.id))
            sips.append(contentsOf: page.filter { !existing.contains($0.id) && $0.isPublishedOnProfile })
            canLoadMore = page.count == 24
        } catch {
            canLoadMore = false
        }
    }

    @MainActor
    private func loadMoreTagged() async {
        guard canLoadMoreTagged,
              !isLoadingMore,
              let projection,
              let last = taggedSips.last else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            let page: [PublicProfileVisit]
            switch source {
            case .user:
                page = try await service.publicTaggedSips(
                    userID: projection.profile.id,
                    afterCreatedAt: last.createdAt,
                    afterID: last.id
                )
            case .share(let slug):
                page = try await service.sharedTaggedSips(
                    slug: slug,
                    afterCreatedAt: last.createdAt,
                    afterID: last.id
                )
            }
            let existing = Set(taggedSips.map(\.id))
            taggedSips.append(contentsOf: page.filter { !existing.contains($0.id) && $0.isPublishedOnProfile })
            canLoadMoreTagged = page.count == 24
        } catch {
            canLoadMoreTagged = false
        }
    }

    @MainActor
    private func shareProfile() async {
        guard !isPreparingProfileShare, let projection else { return }
        isPreparingProfileShare = true
        defer { isPreparingProfileShare = false }
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            guard let publicURL = try await service.createOwnerShareURL() else {
                errorMessage = "Mugshot couldn’t create a profile link."
                return
            }

            var publicProjection = projection
            var publicSips = sips
            if let route = MugshotProfileSharedLinkRoute.resolve(publicURL) {
                if let exactProjection = try? await service.sharedProjection(slug: route.slug) {
                    publicProjection = exactProjection
                }
                if let exactSips = try? await service.sharedSips(slug: route.slug) {
                    publicSips = exactSips
                }
            }

            profileSharePresentation = ProfileSharePresentation(
                content: ProfileShareContent(
                    projection: publicProjection,
                    sips: publicSips
                ),
                publicURL: publicURL
            )
        } catch {
            errorMessage = "Mugshot couldn’t create a profile link."
        }
    }

    @MainActor
    private func hideTaggedSip(_ sip: PublicProfileVisit) async {
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            _ = try await service.setTaggedPostHidden(visitID: sip.id, hidden: true)
            taggedSips.removeAll { $0.id == sip.id }
        } catch {
            errorMessage = "Mugshot couldn’t hide this tagged Mugshot."
        }
    }

    @MainActor
    private func removeTag(from sip: PublicProfileVisit) async {
        guard let accountID = authModel.authenticatedUser?.id else { return }
        do {
            let client = try SupabaseClientProvider.shared.client()
            _ = try await ActivityService(client: client).removeTag(visitID: sip.id, accountID: accountID)
            taggedSips.removeAll { $0.id == sip.id }
        } catch {
            errorMessage = "Mugshot couldn’t remove your tag."
        }
    }

    private func normalizedURL(_ value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let candidate = value.lowercased().hasPrefix("http") ? value : "https://\(value)"
        guard let url = URL(string: candidate), ["https", "http"].contains(url.scheme) else { return nil }
        return url
    }

    static func deriveCafes(from visits: [PublicProfileVisit]) -> [SharedProfilePublicCafe] {
        let publicVisits = visits.filter(\.isPublishedOnProfile).filter { $0.journalContext == .cafe }
        let grouped = Dictionary(grouping: publicVisits) { visit in
            visit.identityKey?.remoteTrimmedNonEmpty ?? visit.cafeID?.uuidString ?? visit.id.uuidString
        }
        return grouped.compactMap { _, group in
            guard let latest = group.sorted(by: { $0.createdAt > $1.createdAt }).first,
                  let cafeID = latest.cafeID,
                  let name = latest.cafeName else { return nil }
            let rated = group.map(\.overallScore).filter { $0 > 0 && $0.isFinite }
            return SharedProfilePublicCafe(
                id: cafeID,
                name: name,
                city: latest.cafeCity,
                address: nil,
                latitude: latest.latitude,
                longitude: latest.longitude,
                identityKey: latest.identityKey,
                score: rated.isEmpty ? 0 : rated.reduce(0, +) / Double(rated.count),
                evidenceCount: rated.count,
                sipCount: group.count,
                coverPhotoURL: group.lazy.compactMap {
                    $0.posterPhotoURL?.remoteTrimmedNonEmpty ?? $0.photoURLs?.first?.remoteTrimmedNonEmpty
                }.first
            )
        }
        .sorted {
            if $0.sipCount == $1.sipCount { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return $0.sipCount > $1.sipCount
        }
    }
}

private struct TaggedProfileAction: Identifiable {
    let sip: PublicProfileVisit
    var id: UUID { sip.id }
}

private struct ProfileExplorationMap: View {
    let cafes: [SharedProfilePublicCafe]
    let onCafeTap: (Cafe) -> Void
    let onClusterTap: ([Cafe]) -> Void

    @StateObject private var locationManager = LocationManager()
    @State private var trackingMode: MKUserTrackingMode = .none
    @State private var region: MKCoordinateRegion

    init(
        cafes: [SharedProfilePublicCafe],
        onCafeTap: @escaping (Cafe) -> Void,
        onClusterTap: @escaping ([Cafe]) -> Void
    ) {
        self.cafes = cafes
        self.onCafeTap = onCafeTap
        self.onClusterTap = onClusterTap
        let coordinates = cafes.compactMap(\.localCafe.location)
        _region = State(initialValue: Self.fittedRegion(coordinates))
    }

    private var localCafes: [Cafe] { cafes.compactMap { $0.localCafe.location == nil ? nil : $0.localCafe } }

    private var scores: [UUID: MapPinScore] {
        Dictionary(uniqueKeysWithValues: cafes.compactMap { cafe in
            guard cafe.score > 0 else { return nil }
            return (
                cafe.id,
                MapPinScore(
                    value: cafe.score,
                    source: .sip,
                    audience: .personal,
                    ratedCafeSessionCount: 0,
                    physicalSessionCount: cafe.evidenceCount,
                    sipCount: cafe.sipCount,
                    contributorCount: 1,
                    relationshipStage: .unrated
                )
            )
        })
    }

    var body: some View {
        Group {
            if localCafes.isEmpty {
                ContentUnavailableView(
                    "No explored cafes yet",
                    systemImage: "map",
                    description: Text("Profile-visible cafe Mugshots will build this map.")
                )
                .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                ZStack(alignment: .bottomTrailing) {
                    MapViewRepresentable(
                        region: $region,
                        cafes: localCafes,
                        highlightedCafe: nil,
                        friendCounts: [:],
                        pinScores: scores,
                        placeNames: [:],
                        showsFriendContext: false,
                        showsUserLocation: true,
                        trackingMode: $trackingMode,
                        onCafeTap: onCafeTap,
                        onClusterListRequested: onClusterTap
                    )

                    VStack(alignment: .trailing, spacing: 12) {
                        Text("\(cafes.count) cafe\(cafes.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.espressoBrown)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.foamWhite.opacity(0.94), in: Capsule())

                        MyLocationButton(
                            locationManager: locationManager,
                            region: $region,
                            trackingMode: $trackingMode
                        )
                    }
                    .padding(14)
                }
                .frame(height: 470)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private static func fittedRegion(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 55)
            )
        }
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.05, (maxLat - minLat) * 1.45),
                longitudeDelta: max(0.05, (maxLon - minLon) * 1.45)
            )
        )
    }
}

private struct ProfileMapClusterSheet: View {
    let cafes: [Cafe]
    let onSelect: (Cafe) -> Void

    var body: some View {
        NavigationStack {
            List(cafes) { cafe in
                Button { onSelect(cafe) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cafe.name).fontWeight(.semibold).foregroundStyle(Color.espressoBrown)
                        if !cafe.address.isEmpty {
                            Text(cafe.address).font(.caption).foregroundStyle(Color.secondaryText)
                        }
                    }
                }
            }
            .navigationTitle("Cafes in this area")
        }
    }
}

private struct SharedProfileFriendsView: View {
    let profile: SupabaseUserProfile
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [SharedProfileFriend] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading friends…")
                } else if let errorMessage {
                    ContentUnavailableView("Friends unavailable", systemImage: "person.2.slash", description: Text(errorMessage))
                } else if friends.isEmpty {
                    ContentUnavailableView("No friends yet", systemImage: "person.2")
                } else {
                    List(friends) { friend in
                        NavigationLink {
                            PublicProfileView(
                                route: PeopleProfileRoute(
                                    id: friend.userID,
                                    displayName: friend.displayName,
                                    username: friend.username,
                                    relationshipID: friend.relationshipID,
                                    state: friend.friendshipState
                                ),
                                dataManager: dataManager,
                                onRelationshipChanged: { await load() }
                            )
                        } label: {
                            HStack(spacing: 12) {
                                MugshotAvatar(name: friend.displayName, size: 44, imageURL: friend.avatarURL)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName).fontWeight(.semibold)
                                    Text("@\(friend.username)").font(.caption).foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("\(profile.displayName)’s friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            friends = try await SharedProfileService(
                client: try SupabaseClientProvider.shared.client()
            ).friends(userID: profile.id)
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }
}
