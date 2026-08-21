import SwiftUI
import UIKit
import CoreLocation

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

    @EnvironmentObject private var authModel: AppAuthModel
    @State private var projection: SharedProfileProjection?
    @State private var sips: [PublicProfileVisit] = []
    @State private var selectedTab: SharedProfileTab = .sips
    @State private var selectedVisit: RemoteVisitSummary?
    @State private var selectedCafe: Cafe?
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var canLoadMore = true
    @State private var errorMessage: String?
    @State private var shareURL: URL?
    @State private var showsShareSheet = false
    @State private var showsEveryonePreview = false

    private enum SharedProfileTab: String, CaseIterable, Identifiable {
        case sips = "Sips"
        case topCafes = "Top cafes"
        case tastePassport = "Taste Passport"
        var id: String { rawValue }
    }

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
        .sheet(isPresented: $showsShareSheet) {
            if let shareURL {
                SharedProfileActivityView(items: [shareURL])
            }
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
            CafeDetailView(
                cafe: cafe,
                dataManager: dataManager,
                initialDetent: .medium
            )
            .environmentObject(authModel)
        }
    }

    private func profileBody(_ projection: SharedProfileProjection) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                identityHeader(projection)
                stats(projection.stats)

                if showsOwnerControls {
                    ownerActions
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                }

                if let supplementaryContent {
                    supplementaryContent
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                }

                if let highlight = projection.highlight {
                    highlightCard(highlight)
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                }

                MugshotSegmentedControl(
                    options: SharedProfileTab.allCases,
                    selection: $selectedTab,
                    title: { $0.rawValue }
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)

                tabContent(projection)
                    .padding(.top, 16)
            }
            .padding(.bottom, 42)
        }
        .scrollIndicators(.hidden)
    }

    private func identityHeader(_ projection: SharedProfileProjection) -> some View {
        let profile = projection.profile
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                MugshotProfileBanner(imageURL: profile.bannerURL, height: 174)
                LinearGradient(
                    colors: [.clear, Color.espressoBrown.opacity(0.32)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                MugshotAvatar(
                    name: profile.displayName,
                    size: 92,
                    imageURL: profile.avatarURL
                )
                .overlay(Circle().stroke(Color.creamWhite, lineWidth: 4))
                .offset(x: 18, y: 45)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(profile.displayName)
                    .mugshotDisplay(size: 30)
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

                HStack(spacing: 12) {
                    if let location = profile.location?.remoteTrimmedNonEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                    if let favorite = profile.favoriteDrink?.remoteTrimmedNonEmpty {
                        Label(favorite, systemImage: "cup.and.saucer.fill")
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.mugshotSage)

                socialLinks(profile)
            }
            .padding(.horizontal, 18)
            .padding(.top, 52)
        }
    }

    @ViewBuilder
    private func socialLinks(_ profile: SupabaseUserProfile) -> some View {
        let instagram = profile.instagramHandle?.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let website = normalizedURL(profile.websiteURL)
        if instagram?.isEmpty == false || website != nil {
            HStack(spacing: 18) {
                if let instagram, !instagram.isEmpty,
                   let url = URL(string: "https://instagram.com/\(instagram)") {
                    Link(destination: url) {
                        Label("Instagram", systemImage: "camera")
                    }
                }
                if let website {
                    Link(destination: website) {
                        Label("Website", systemImage: "globe")
                    }
                }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.mugshotSage)
            .frame(minHeight: 34)
        }
    }

    private func stats(_ stats: SharedProfileStats) -> some View {
        HStack(spacing: 0) {
            profileStat("Friends", value: stats.friends)
            Divider().frame(height: 38)
            profileStat("Sips", value: stats.sips)
            Divider().frame(height: 38)
            profileStat("Cafes", value: stats.cafes)
        }
        .padding(.vertical, 13)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }

    private func profileStat(_ title: String, value: Int) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.espressoBrown)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var ownerActions: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                Button { onEditProfile?() } label: {
                    Label("Edit profile", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button { Task { await shareProfile() } } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            HStack(spacing: 9) {
                Button { showsEveryonePreview = true } label: {
                    Label("Preview as Everyone", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button { onOpenSettings?() } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func highlightCard(_ highlight: SharedProfileHighlight) -> some View {
        Button {
            if let visitID = highlight.sip?.id {
                openVisit(visitID)
            } else if let cafe = highlight.cafe {
                selectedCafe = localCafe(from: cafe)
            }
        } label: {
            HStack(spacing: 14) {
                RemotePhotoImageView(
                    urlString: highlight.sip?.coverPhotoURL ?? highlight.cafe?.coverPhotoURL,
                    placeholderSystemName: highlight.type == "sip" ? "cup.and.saucer.fill" : "storefront.fill"
                )
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(highlight.type == "sip" ? "PINNED SIP" : "FAVORITE CAFE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color.mugshotSage)
                    Text(highlight.sip?.drinkName ?? highlight.cafe?.name ?? "Profile highlight")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Color.espressoBrown)
                    if let city = highlight.cafe?.city?.remoteTrimmedNonEmpty {
                        Text(city).font(.system(size: 12)).foregroundStyle(Color.secondaryText)
                    } else if let score = highlight.sip?.score {
                        Label(score.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.mugshotSage)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.mugshotSage)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sandBeige.opacity(0.52), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if showsOwnerControls {
                Button("Remove highlight", role: .destructive) {
                    Task { await clearHighlight() }
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ projection: SharedProfileProjection) -> some View {
        switch selectedTab {
        case .sips:
            sipGrid(projection)
        case .topCafes:
            topCafes(projection.topCafes)
        case .tastePassport:
            TastePassportProjectionSection(
                state: tastePassportState(projection),
                context: showsOwnerControls ? .owner : .viewer(displayName: projection.profile.displayName),
                onRetry: { Task { await loadInitial() } }
            )
            .padding(.horizontal, 16)
        }
    }

    private func sipGrid(_ projection: SharedProfileProjection) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
            spacing: 2
        ) {
            ForEach(sips) { sip in
                Button {
                    selectedVisit = sip.summary(profile: projection.profile)
                } label: {
                    Group {
                        if let photo = sip.posterPhotoURL?.remoteTrimmedNonEmpty
                            ?? sip.photoURLs?.first?.remoteTrimmedNonEmpty {
                            RemotePhotoImageView(
                                urlString: photo,
                                placeholderSystemName: "cup.and.saucer.fill",
                                contentMode: .fill
                            )
                        } else {
                            MugsyPhotoPlaceholderView(
                                scene: MugsySceneResolver.scene(for: .journalMemory, stableID: sip.id.uuidString),
                                style: .thumbnail,
                                photoDescription: "No sip photo"
                            )
                        }
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(sip.drinkDisplayName)")
                .contextMenu {
                    if showsOwnerControls {
                        Button("Pin this sip") {
                            Task { await setHighlight(type: "sip", targetID: sip.id) }
                        }
                    }
                }
                .onAppear {
                    if sip.id == sips.last?.id { Task { await loadMore() } }
                }
            }
        }
        .overlay {
            if sips.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No visible sips yet",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Shared sips will fill this photo grid.")
                )
            }
        }
    }

    private func topCafes(_ cafes: [SharedProfileTopCafe]) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(cafes.enumerated()), id: \.element.id) { index, cafe in
                Button {
                    selectedCafe = localCafe(from: cafe)
                } label: {
                    HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(width: 28)
                    RemotePhotoImageView(
                        urlString: cafe.coverPhotoURL,
                        placeholderSystemName: "storefront.fill"
                    )
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cafe.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.espressoBrown)
                        if let city = cafe.city?.remoteTrimmedNonEmpty {
                            Text(city).font(.system(size: 11)).foregroundStyle(Color.secondaryText)
                        }
                        Text(cafe.basis == "cafe_pulse" ? "Cafe Pulse" : "Visible sip average")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.tertiaryText)
                    }
                    Spacer()
                    Text(cafe.score.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Color.mugshotSage)
                    }
                    .padding(12)
                    .cardStyle()
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if showsOwnerControls {
                        Button("Feature this cafe") {
                            Task { await setHighlight(type: "cafe", targetID: cafe.id) }
                        }
                    }
                }
            }

            if cafes.isEmpty {
                ContentUnavailableView(
                    "No top cafes yet",
                    systemImage: "storefront",
                    description: Text("Visible cafe ratings will rank here.")
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func tastePassportState(_ projection: SharedProfileProjection) -> TastePassportLoadState {
        guard projection.tastePassportVisible,
              let passport = projection.tastePassport else {
            return .loaded(.hidden)
        }
        do {
            return .loaded(try TastePassportAccessState.resolve(
                passport,
                requestedUserID: projection.profile.id
            ))
        } catch {
            return .failed("This Taste Passport could not be shown safely.")
        }
    }

    @MainActor
    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            let loadedProjection: SharedProfileProjection?
            let loadedSips: [PublicProfileVisit]
            switch source {
            case .user(let userID, let asEveryone):
                loadedProjection = try await service.projection(userID: userID, asEveryone: asEveryone)
                loadedSips = try await service.sips(userID: userID, asEveryone: asEveryone)
            case .share(let slug):
                loadedProjection = try await service.sharedProjection(slug: slug)
                loadedSips = try await service.sharedSips(slug: slug)
            }
            guard let loadedProjection else {
                projection = nil
                sips = []
                return
            }
            projection = loadedProjection
            sips = loadedSips
            canLoadMore = loadedSips.count == 24
        } catch {
            projection = nil
            sips = []
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
            case .user(_, let asEveryone):
                page = try await service.sips(
                    userID: projection.profile.id,
                    asEveryone: asEveryone,
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
            sips.append(contentsOf: page.filter { !existing.contains($0.id) })
            canLoadMore = page.count == 24
        } catch {
            canLoadMore = false
        }
    }

    private func openVisit(_ visitID: UUID) {
        if let sip = sips.first(where: { $0.id == visitID }), let projection {
            selectedVisit = sip.summary(profile: projection.profile)
            return
        }
        Task { @MainActor in
            guard let client = try? SupabaseClientProvider.shared.client(),
                  let detail = try? await VisitService(client: client).fetchVisitDetail(
                    visitId: visitID,
                    currentUserId: authModel.authenticatedUser?.id
                  ) else { return }
            selectedVisit = detail.summary
        }
    }

    @MainActor
    private func shareProfile() async {
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            shareURL = try await service.createOwnerShareURL()
            showsShareSheet = shareURL != nil
        } catch {
            errorMessage = "Mugshot couldn’t create a profile link."
        }
    }

    @MainActor
    private func setHighlight(type: String, targetID: UUID) async {
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            _ = try await service.setHighlight(type: type, targetID: targetID)
            projection = try await service.projection(userID: projection!.profile.id)
        } catch {
            errorMessage = "Mugshot couldn’t update this highlight."
        }
    }

    @MainActor
    private func clearHighlight() async {
        guard let projection else { return }
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            try await service.clearHighlight()
            self.projection = try await service.projection(userID: projection.profile.id)
        } catch {
            errorMessage = "Mugshot couldn’t remove this highlight."
        }
    }

    private func normalizedURL(_ value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        let candidate = value.lowercased().hasPrefix("http") ? value : "https://\(value)"
        guard let url = URL(string: candidate),
              url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }

    private func localCafe(from cafe: SharedProfileHighlightCafe) -> Cafe {
        Cafe(
            name: cafe.name,
            location: CLLocationCoordinate2D(latitude: cafe.latitude, longitude: cafe.longitude),
            address: cafe.address ?? cafe.city ?? "",
            remoteCafeId: cafe.id
        )
    }

    private func localCafe(from cafe: SharedProfileTopCafe) -> Cafe {
        Cafe(
            name: cafe.name,
            location: CLLocationCoordinate2D(latitude: cafe.latitude, longitude: cafe.longitude),
            address: cafe.address ?? cafe.city ?? "",
            averageRating: cafe.score,
            visitCount: cafe.sipCount,
            remoteCafeId: cafe.id
        )
    }
}

private struct SharedProfileActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
