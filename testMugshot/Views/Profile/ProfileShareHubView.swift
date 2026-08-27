import SwiftUI
import UIKit

struct ProfileShareContent: Equatable {
    struct FavoriteSpot: Equatable, Identifiable {
        let descriptor: String
        let cafeName: String

        var id: String { "\(descriptor)|\(cafeName)" }
    }

    let displayName: String
    let username: String
    let bio: String?
    let location: String?
    let favoriteDrink: String?
    let showsInstagram: Bool
    let showsWebsite: Bool
    let stats: SharedProfileStats
    let favoriteSpots: [FavoriteSpot]
    let bannerURL: String?
    let avatarURL: String?
    let postPhotoURLs: [String]

    init(projection: SharedProfileProjection, sips: [PublicProfileVisit]) {
        let profile = projection.profile
        displayName = Self.safeText(profile.displayName, fallback: "Mugshot friend", limit: 60)
        username = Self.safeUsername(profile.username) ?? "mugshot_friend"
        bio = Self.safeOptionalText(profile.bio, limit: 180)
        location = Self.safeOptionalText(profile.location, limit: 60)
        favoriteDrink = Self.safeOptionalText(profile.favoriteDrink, limit: 60)
        showsInstagram = Self.safeOptionalText(profile.instagramHandle, limit: 80) != nil
        showsWebsite = Self.safeOptionalText(profile.websiteURL, limit: 200) != nil
        stats = projection.stats
        favoriteSpots = projection.favoriteSpots.prefix(3).map {
            FavoriteSpot(
                descriptor: Self.safeText($0.descriptor, fallback: "Favorite", limit: 30),
                cafeName: Self.safeText($0.name, fallback: "Cafe", limit: 70)
            )
        }
        bannerURL = Self.safeRemoteImageURL(profile.bannerURL)
        avatarURL = Self.safeRemoteImageURL(profile.avatarURL)
        postPhotoURLs = sips
            .filter(\.isPublishedOnProfile)
            .sorted(by: Self.isNewerProfileSip)
            .compactMap { sip -> String? in
                if let poster = sip.posterPhotoURL,
                   let trimmedPoster = poster.remoteTrimmedNonEmpty {
                    return trimmedPoster
                }
                if let firstPhoto = sip.photoURLs?.first {
                    return firstPhoto.remoteTrimmedNonEmpty
                }
                return nil
            }
            .compactMap(Self.safePhotoReference)
            .prefix(9)
            .map { $0 }
    }

    var atUsername: String { "@\(username)" }

    var shareMessage: String {
        "Add me on Mugshot — \(atUsername)"
    }

    var linkMetadataTitle: String {
        "Add \(atUsername) on Mugshot"
    }

    private static func safeText(_ value: String?, fallback: String, limit: Int) -> String {
        safeOptionalText(value, limit: limit) ?? fallback
    }

    private static func safeOptionalText(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let bounded = String(collapsed.prefix(limit))
        return bounded.isEmpty ? nil : bounded
    }

    private static func safeUsername(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "@" })
        let allowed = trimmed.filter {
            $0.isLetter || $0.isNumber || $0 == "_" || $0 == "."
        }
        let bounded = String(allowed.prefix(40))
        return bounded.isEmpty ? nil : bounded
    }

    private static func safeRemoteImageURL(_ value: String?) -> String? {
        guard let value = safeOptionalText(value, limit: 2_048),
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url.absoluteString
    }

    private static func safePhotoReference(_ value: String?) -> String? {
        guard let value = safeOptionalText(value, limit: 2_048) else { return nil }
        if let storageReference = VisitPhotoStorageReference(storedValue: value) {
            return storageReference.storedValue
        }
        return safeRemoteImageURL(value)
    }

    private static func isNewerProfileSip(
        _ lhs: PublicProfileVisit,
        than rhs: PublicProfileVisit
    ) -> Bool {
        let leftDate = profileSipDate(lhs.createdAt)
        let rightDate = profileSipDate(rhs.createdAt)
        if leftDate != rightDate {
            return leftDate > rightDate
        }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func profileSipDate(_ value: String) -> Date {
        (try? Date(
            value,
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        ))
            ?? (try? Date(value, strategy: Date.ISO8601FormatStyle()))
            ?? .distantPast
    }
}

struct ProfileSharePackage {
    let content: ProfileShareContent
    let storyArtwork: UIImage
    let postArtwork: UIImage
    let linkPreviewArtwork: UIImage
    let publicURL: URL

    func artwork(for format: MugshotShareFormat) -> UIImage {
        switch format {
        case .story: return storyArtwork
        case .post: return postArtwork
        }
    }

    @MainActor
    func primaryActivityItems(for format: MugshotShareFormat) -> [Any] {
        [
            artwork(for: format),
            content.shareMessage,
            MugshotShareLinkItemSource(
                url: publicURL,
                previewImage: linkPreviewArtwork,
                title: content.linkMetadataTitle
            ),
        ]
    }
}

struct ProfileSharePresentation: Identifiable {
    let id = UUID()
    let content: ProfileShareContent
    let publicURL: URL
}

@MainActor
struct ProfileShareHubView: View {
    let content: ProfileShareContent
    let publicURL: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedFormat: MugshotShareFormat = .story
    @State private var sharePackage: ProfileSharePackage?
    @State private var systemSharePresentation: ProfileSystemSharePresentation?
    @State private var errorMessage: String?
    @State private var isPreparing = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                exportPreview
                formatPicker
                canonicalLinkRow
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 108)
        }
        .background(Color.creamWhite)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomAction }
        .task(id: content.username) { await preparePackage() }
        .alert(
            "Couldn’t prepare this profile",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try sharing again.")
        }
        .sheet(item: $systemSharePresentation) { presentation in
            ProfileSystemShareView(items: presentation.items)
        }
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("profile.shareHub")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Share your profile")
                    .mugshotDisplay(size: 34)
                    .foregroundStyle(Color.espressoBrown)
                Text("A public snapshot, ready to send.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 12)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                    .frame(width: 40, height: 40)
                    .background(Color.foamWhite, in: Circle())
                    .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close profile sharing")
        }
    }

    private var exportPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Public profile snapshot")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                Spacer()
                Text("\(Int(selectedFormat.pixelSize.width)) × \(Int(selectedFormat.pixelSize.height))")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.tertiaryText)
            }

            Group {
                if let image = sharePackage?.artwork(for: selectedFormat) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ZStack {
                        Color.sandBeige.opacity(0.38)
                        ProgressView("Building your profile…")
                            .font(.system(size: 12, weight: .semibold))
                            .tint(Color.mugshotSage)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(
                selectedFormat.pixelSize.width / selectedFormat.pixelSize.height,
                contentMode: .fit
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
            .shadow(color: DesignSystem.cardShadow.color, radius: 18, y: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(selectedFormat.title) snapshot of \(content.displayName)’s public profile")
        }
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Format")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 8) {
                ForEach(MugshotShareFormat.allCases) { format in
                    Button {
                        withAnimation(reduceMotion ? nil : DesignSystem.Motion.fast) {
                            selectedFormat = format
                        }
                    } label: {
                        Text(format.title)
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                selectedFormat == format
                                    ? Color.mugshotMint.opacity(0.62)
                                    : Color.foamWhite
                            )
                            .foregroundStyle(Color.espressoBrown)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    selectedFormat == format
                                        ? Color.mugshotSage.opacity(0.5)
                                        : Color.mugshotLine,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedFormat == format ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }

    private var canonicalLinkRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.foamWhite)
                .frame(width: 38, height: 38)
                .background(Color.mugshotSage, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(content.shareMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                Text("Includes an active Mugshot profile link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.mugshotMint.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var bottomAction: some View {
        Button(action: presentSystemShare) {
            HStack(spacing: 10) {
                if isPreparing {
                    ProgressView().tint(Color.foamWhite)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPreparing ? "Preparing…" : "Share profile")
                        .font(.system(size: 15, weight: .bold))
                    Text("Snapshot and active Mugshot link")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.78)
                }
                Spacer()
            }
            .foregroundStyle(Color.foamWhite)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 18)
            .background(Color.mugshotSage)
            .clipShape(Capsule())
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.plain)
        .disabled(isPreparing || sharePackage == nil)
    }

    private func preparePackage() async {
        isPreparing = true
        let images = await ProfileShareRemoteImageLoader.load(content: content)
        guard !Task.isCancelled else { return }
        let story = renderArtwork(format: .story, images: images)
        let post = renderArtwork(format: .post, images: images)
        let preview = renderLinkPreview(images: images)
        guard let story, let post, let preview else {
            isPreparing = false
            errorMessage = "Mugshot couldn’t build the public profile snapshot."
            return
        }
        sharePackage = ProfileSharePackage(
            content: content,
            storyArtwork: story,
            postArtwork: post,
            linkPreviewArtwork: preview,
            publicURL: publicURL
        )
        isPreparing = false
    }

    private func renderArtwork(
        format: MugshotShareFormat,
        images: ProfileShareLoadedImages
    ) -> UIImage? {
        let size = format.pixelSize
        let artwork = ProfileShareArtworkView(content: content, images: images, format: format)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func renderLinkPreview(images: ProfileShareLoadedImages) -> UIImage? {
        let size = CGSize(width: 1_200, height: 630)
        let artwork = ProfileShareLinkPreviewView(content: content, images: images)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func presentSystemShare() {
        guard let sharePackage else {
            errorMessage = "Mugshot is still building the public profile snapshot."
            return
        }
        systemSharePresentation = ProfileSystemSharePresentation(
            items: sharePackage.primaryActivityItems(for: selectedFormat)
        )
    }
}

struct ProfileShareLoadedImages {
    let banner: UIImage?
    let avatar: UIImage?
    let posts: [UIImage?]

    static let empty = ProfileShareLoadedImages(banner: nil, avatar: nil, posts: [])
}

@MainActor
enum ProfileShareRemoteImageLoader {
    static func load(content: ProfileShareContent) async -> ProfileShareLoadedImages {
        let urls = [content.bannerURL, content.avatarURL] + content.postPhotoURLs.map(Optional.some)
        let data = await withTaskGroup(of: (Int, Data?).self, returning: [Data?].self) { group in
            for (index, value) in urls.enumerated() {
                group.addTask { (index, await remoteData(value)) }
            }
            var results = Array<Data?>(repeating: nil, count: urls.count)
            for await (index, value) in group {
                results[index] = value
            }
            return results
        }
        let images = data.map { $0.flatMap(UIImage.init(data:)) }
        return ProfileShareLoadedImages(
            banner: images.indices.contains(0) ? images[0] : nil,
            avatar: images.indices.contains(1) ? images[1] : nil,
            posts: Array(images.dropFirst(2))
        )
    }

    private nonisolated static func remoteData(_ value: String?) async -> Data? {
        guard let value else { return nil }
        let url: URL
        do {
            url = try await VisitPhotoAccessService.shared.resolvedURL(for: value)
        } catch {
            return nil
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count <= 20_000_000 else { return nil }
        return data
    }
}

struct ProfileShareArtworkView: View {
    let content: ProfileShareContent
    let images: ProfileShareLoadedImages
    let format: MugshotShareFormat

    var body: some View {
        let output = format.pixelSize
        let logicalWidth: CGFloat = 390
        let scale = output.width / logicalWidth
        let logicalHeight = output.height / scale

        ZStack(alignment: .topLeading) {
            Color.creamWhite
            ProfileShareSnapshotCanvas(
                content: content,
                images: images,
                logicalHeight: logicalHeight
            )
            .frame(width: logicalWidth, height: logicalHeight)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .frame(width: output.width, height: output.height)
        .clipped()
    }
}

private struct ProfileShareSnapshotCanvas: View {
    let content: ProfileShareContent
    let images: ProfileShareLoadedImages
    let logicalHeight: CGFloat

    var body: some View {
        ZStack {
            Color.creamWhite
            GeometryReader { canvas in
                VStack(alignment: .leading, spacing: 0) {
                    profileHeader
                    if !content.favoriteSpots.isEmpty {
                        favoriteSpots
                            .padding(.top, 18)
                    }
                    tabRail
                        .padding(.top, 14)
                    postGrid
                }
                .frame(width: canvas.size.width, alignment: .topLeading)
            }
        }
        .overlay(alignment: .bottom) { marketingFooter }
        .frame(width: 390, height: logicalHeight)
        .clipped()
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                shareBanner
                    .frame(height: 112)
                    .clipped()

                LinearGradient(
                    colors: [.clear, Color.espressoBrown.opacity(0.16)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 14) {
                    shareAvatar
                        .frame(width: 104, height: 104)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.creamWhite, lineWidth: 5))
                        .shadow(color: .black.opacity(0.14), radius: 16, y: 7)
                        .offset(y: 46)

                    statisticsDock
                        .offset(y: 30)
                }
                .padding(.horizontal, 18)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(content.displayName)
                    .mugshotDisplay(size: 32)
                    .foregroundStyle(Color.espressoBrown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(content.atUsername)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)

                if let bio = content.bio {
                    Text(bio)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.espressoBrown)
                        .lineLimit(2)
                }

                detailRail
            }
            .padding(.horizontal, 18)
            .padding(.top, 58)
        }
    }

    @ViewBuilder
    private var shareBanner: some View {
        if let banner = images.banner {
            Image(uiImage: banner)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color.mugshotMint.opacity(0.72), Color.sandBeige],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var shareAvatar: some View {
        if let avatar = images.avatar {
            Image(uiImage: avatar)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.mugshotMint
                Text(String(content.displayName.prefix(1)).uppercased())
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundStyle(Color.espressoBrown)
            }
        }
    }

    private var statisticsDock: some View {
        HStack(spacing: 0) {
            shareStat("Friends", value: content.stats.friends)
            Divider().frame(height: 36)
            shareStat("Sips", value: content.stats.sips)
            Divider().frame(height: 36)
            shareStat("Cafes", value: content.stats.cafes)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.foamWhite.opacity(0.97), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }

    private func shareStat(_ title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.espressoBrown)
        .frame(maxWidth: .infinity, minHeight: 40)
    }

    @ViewBuilder
    private var detailRail: some View {
        let hasDetails = content.location != nil
            || content.favoriteDrink != nil
            || content.showsInstagram
            || content.showsWebsite
        if hasDetails {
            HStack(spacing: 14) {
                if let location = content.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
                if let favoriteDrink = content.favoriteDrink {
                    Label(favoriteDrink, systemImage: "cup.and.saucer.fill")
                        .lineLimit(1)
                }
                if content.showsInstagram {
                    Label("Instagram", systemImage: "camera")
                }
                if content.showsWebsite {
                    Label("Website", systemImage: "globe")
                }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.mugshotSage)
            .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
        }
    }

    private var favoriteSpots: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Favorite Spots")
                .mugshotDisplay(size: 21)
                .foregroundStyle(Color.espressoBrown)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(content.favoriteSpots.enumerated()), id: \.element.id) { index, spot in
                    if index > 0 {
                        Divider()
                            .frame(height: 42)
                            .padding(.horizontal, 9)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(spot.descriptor)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.mugshotSage)
                            .lineLimit(1)
                        Text(spot.cafeName)
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .foregroundStyle(Color.espressoBrown)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private var tabRail: some View {
        HStack(spacing: 0) {
            ForEach(SharedProfileTab.allCases) { tab in
                VStack(spacing: 9) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 19, weight: tab == .mugshots ? .semibold : .regular))
                    Capsule()
                        .fill(tab == .mugshots ? Color.mugshotSage : .clear)
                        .frame(height: 3)
                }
                .foregroundStyle(tab == .mugshots ? Color.mugshotSage : Color.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
        }
        .padding(.horizontal, 12)
        .background(Color.foamWhite)
        .overlay(alignment: .top) { Divider() }
    }

    private var postGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
        return LazyVGrid(columns: columns, spacing: 1) {
            ForEach(0..<max(6, images.posts.count), id: \.self) { index in
                Group {
                    if images.posts.indices.contains(index), let image = images.posts[index] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color.sandBeige.opacity(index.isMultiple(of: 2) ? 0.58 : 0.34)
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.mugshotSage.opacity(0.68))
                        }
                    }
                }
                .frame(height: 172)
                .clipped()
            }
        }
    }

    private var marketingFooter: some View {
        HStack(spacing: 11) {
            Image("MugshotAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Add me on Mugshot")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                Text(content.atUsername)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mugshotSage)
            }
            Spacer()
            Text("mugshotapp.co")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(Color.foamWhite.opacity(0.98))
        .overlay(alignment: .top) { Divider() }
    }
}

struct ProfileShareLinkPreviewView: View {
    let content: ProfileShareContent
    let images: ProfileShareLoadedImages

    var body: some View {
        ZStack {
            Color.creamWhite
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image("MugshotAppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text("Mugshot")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundStyle(Color.espressoBrown)
                    }
                    Spacer()
                    Text("Add me on Mugshot")
                        .font(.system(size: 44, weight: .regular, design: .serif))
                        .foregroundStyle(Color.espressoBrown)
                    HStack(spacing: 18) {
                        avatar
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.foamWhite, lineWidth: 4))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(content.displayName)
                                .font(.system(size: 30, weight: .bold, design: .serif))
                                .foregroundStyle(Color.espressoBrown)
                                .lineLimit(1)
                            Text(content.atUsername)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(Color.mugshotSage)
                        }
                    }
                }
                .padding(48)
                .frame(width: 700, alignment: .leading)

                coverPhoto
                    .frame(width: 500, height: 630)
                    .clipped()
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatar = images.avatar {
            Image(uiImage: avatar).resizable().scaledToFill()
        } else {
            ZStack {
                Color.mugshotMint
                Text(String(content.displayName.prefix(1)).uppercased())
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(Color.espressoBrown)
            }
        }
    }

    @ViewBuilder
    private var coverPhoto: some View {
        if let image = images.posts.compactMap({ $0 }).first ?? images.banner {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            LinearGradient(
                colors: [Color.mugshotMint.opacity(0.72), Color.sandBeige],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct ProfileSystemSharePresentation: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ProfileSystemShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
