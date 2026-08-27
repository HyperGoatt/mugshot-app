import Combine
import Foundation
import LinkPresentation
import UIKit

enum MugshotShareFormat: String, CaseIterable, Identifiable {
    case story
    case post

    var id: String { rawValue }

    var title: String {
        switch self {
        case .story: return "Story"
        case .post: return "Post"
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .story: return CGSize(width: 1_080, height: 1_920)
        case .post: return CGSize(width: 1_080, height: 1_350)
        }
    }
}

enum MugshotShareTemplate: String, CaseIterable, Identifiable {
    case fullBleed
    case fieldNote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullBleed: return "Full Bleed"
        case .fieldNote: return "Field Note"
        }
    }
}

enum MugshotSharePhotoLayout: String, CaseIterable, Identifiable {
    case singlePhoto
    case twoPhoto
    case threePhoto
    case fourPhoto
    /// Retained for decoding analytics produced by older builds.
    case smartCollage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePhoto: return "Single photo"
        case .twoPhoto: return "2 photos"
        case .threePhoto: return "3 photos"
        case .fourPhoto: return "4 photos"
        case .smartCollage: return "Smart collage"
        }
    }

    var photoLimit: Int {
        switch self {
        case .singlePhoto: return 1
        case .twoPhoto: return 2
        case .threePhoto: return 3
        case .fourPhoto, .smartCollage: return 4
        }
    }

    var isCollage: Bool { self != .singlePhoto }

    static func availableLayouts(photoCount: Int) -> [MugshotSharePhotoLayout] {
        var layouts: [MugshotSharePhotoLayout] = photoCount >= 2
            ? [.smartCollage, .singlePhoto]
            : [.singlePhoto]
        if photoCount >= 2 { layouts.append(.twoPhoto) }
        if photoCount >= 3 { layouts.append(.threePhoto) }
        if photoCount >= 4 { layouts.append(.fourPhoto) }
        return layouts
    }

    static func defaultLayout(photoCount: Int) -> MugshotSharePhotoLayout {
        (2...4).contains(photoCount) ? .smartCollage : .singlePhoto
    }
}

enum MugshotShareDestination: String, CaseIterable, Identifiable {
    case instagramStory
    case facebookStory
    case snapchat
    case messages
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instagramStory: return "Instagram"
        case .facebookStory: return "Facebook"
        case .snapchat: return "Snapchat"
        case .messages: return "Messages"
        case .more: return "More"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .instagramStory: return "Instagram Story"
        case .facebookStory: return "Facebook Story"
        case .snapchat: return "Snapchat"
        case .messages: return "Messages"
        case .more: return "More, X and other apps"
        }
    }

    var systemImage: String {
        switch self {
        case .instagramStory: return "camera.aperture"
        case .facebookStory: return "person.crop.circle.badge.plus"
        case .snapchat: return "bolt.fill"
        case .messages: return "message.fill"
        case .more: return "ellipsis"
        }
    }

    var preferredFormat: MugshotShareFormat {
        switch self {
        case .instagramStory, .facebookStory, .snapchat:
            return .story
        case .messages, .more:
            return .post
        }
    }
}

/// The allowlisted, consumer-safe fields that may enter an exported Mugshot.
/// Private notes, precise coordinates, recipe details, Passport evidence, and
/// unpublished media intentionally have no representation here.
struct MugshotShareContent: Equatable {
    let visitID: UUID
    let isOwner: Bool
    let isRemote: Bool
    let visibility: VisitVisibility
    let authorName: String
    let authorUsername: String?
    let drinkName: String
    let contextName: String
    let locationDetail: String?
    let rating: Double
    let createdAt: Date
    let caption: String?

    init(
        visitID: UUID,
        isOwner: Bool,
        isRemote: Bool,
        visibility: VisitVisibility,
        authorName: String,
        authorUsername: String? = nil,
        drinkName: String,
        contextName: String,
        locationDetail: String? = nil,
        rating: Double,
        createdAt: Date,
        caption: String?
    ) {
        self.visitID = visitID
        self.isOwner = isOwner
        self.isRemote = isRemote
        self.visibility = visibility
        self.authorName = Self.safeText(authorName, fallback: "Mugshot user", limit: 80)
        self.authorUsername = authorUsername.flatMap(Self.safeUsername)
        self.drinkName = Self.safeText(drinkName, fallback: "Coffee memory", limit: 100)
        self.contextName = Self.safeText(contextName, fallback: "Coffee stop", limit: 100)
        self.locationDetail = locationDetail.flatMap(Self.safeCoarseLocation)
        self.rating = min(max(rating, 0), 5)
        self.createdAt = createdAt
        self.caption = caption.flatMap { value in
            let safe = Self.safeText(value, fallback: "", limit: 500)
            return safe.isEmpty ? nil : safe
        }
    }

    var shareText: String {
        var components = [
            "\(authorAttribution) remembered \(drinkName) at \(displayContext) on Mugshot."
        ]
        if let caption {
            components.append(caption)
        }
        return components.joined(separator: "\n\n")
    }

    var authorAttribution: String {
        authorUsername.map { "@\($0)" } ?? authorName
    }

    var displayContext: String {
        guard let locationDetail,
              locationDetail.caseInsensitiveCompare(contextName) != .orderedSame else {
            return contextName
        }
        return "\(contextName) · \(locationDetail)"
    }

    var requiresExternalAudienceWarning: Bool {
        visibility != .everyone
    }

    var mayHavePublicLink: Bool {
        isOwner && isRemote && visibility != .private
    }

    private static func safeText(_ value: String, fallback: String, limit: Int) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\u{0000}", with: "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return String((collapsed.isEmpty ? fallback : collapsed).prefix(limit))
    }

    private static func safeUsername(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "@" })
        let allowed = trimmed.filter { character in
            character.isLetter || character.isNumber || character == "_" || character == "."
        }
        let bounded = String(allowed.prefix(40))
        return bounded.isEmpty ? nil : bounded
    }

    private static func safeCoarseLocation(_ value: String) -> String? {
        let safe = safeText(value, fallback: "", limit: 80)
        guard !safe.isEmpty,
              !safe.contains(where: \.isNumber) else {
            return nil
        }
        return safe
    }
}

struct MugshotSharePackage {
    let content: MugshotShareContent
    let storyArtwork: UIImage
    let postArtwork: UIImage
    let linkPreviewArtwork: UIImage
    let publicURL: URL?

    func artwork(for format: MugshotShareFormat) -> UIImage {
        switch format {
        case .story: return storyArtwork
        case .post: return postArtwork
        }
    }

    @MainActor
    func primaryActivityItems(for format: MugshotShareFormat) -> [Any] {
        guard let publicURL else {
            return artworkActivityItems(for: format)
        }
        return [
            artwork(for: format),
            MugshotShareLinkItemSource(
                url: publicURL,
                previewImage: linkPreviewArtwork
            )
        ]
    }

    func artworkActivityItems(for format: MugshotShareFormat) -> [Any] {
        [artwork(for: format)]
    }
}

@MainActor
final class MugshotShareLinkItemSource: NSObject, @preconcurrency UIActivityItemSource {
    nonisolated static let title = "Mugshot: Capture Every Sip"

    let url: URL
    private let previewImage: UIImage
    private let metadataTitle: String

    init(
        url: URL,
        previewImage: UIImage,
        title: String = MugshotShareLinkItemSource.title
    ) {
        self.url = url
        self.previewImage = previewImage
        metadataTitle = title
        super.init()
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        Self.linkMetadata(url: url, previewImage: previewImage, title: metadataTitle)
    }

    static func linkMetadata(
        url: URL,
        previewImage: UIImage,
        title: String = MugshotShareLinkItemSource.title
    ) -> LPLinkMetadata {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.originalURL = url
        metadata.url = url
        metadata.imageProvider = NSItemProvider(object: previewImage)
        return metadata
    }
}

struct MugshotPublicProjection: Decodable, Identifiable, Equatable {
    let visitID: UUID
    let slug: String
    let authorName: String
    let authorUsername: String?
    let authorAvatarURL: String?
    let drinkName: String
    let contextName: String
    let rating: Double
    let ratings: [String: Double]
    let caption: String?
    let coverPhotoURL: String?
    let photoURLs: [String]
    let createdAt: Date

    var id: UUID { visitID }

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case slug
        case authorName = "author_name"
        case authorUsername = "author_username"
        case authorAvatarURL = "author_avatar_url"
        case drinkName = "drink_name"
        case contextName = "context_name"
        case rating
        case ratings
        case caption
        case coverPhotoURL = "cover_photo_url"
        case photoURLs = "photo_urls"
        case createdAt = "created_at"
    }
}

struct MugshotSharedLinkRoute: Identifiable, Equatable {
    let slug: String
    var id: String { slug }

    static func resolve(
        _ url: URL,
        publicBaseURL: URL? = MugshotShareConfiguration.load().publicBaseURL
    ) -> MugshotSharedLinkRoute? {
        var pathParts = url.pathComponents.filter { $0 != "/" }
        if url.scheme?.lowercased() == "mugshot", let host = url.host {
            pathParts.insert(host, at: 0)
        }
        guard pathParts.count == 2,
              pathParts[0].lowercased() == "m",
              isValidSlug(pathParts[1]) else {
            return nil
        }

        if url.scheme?.lowercased() == "mugshot" {
            return MugshotSharedLinkRoute(slug: pathParts[1])
        }

        guard let publicBaseURL,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == publicBaseURL.host?.lowercased() else {
            return nil
        }
        return MugshotSharedLinkRoute(slug: pathParts[1])
    }

    static func isValidSlug(_ slug: String) -> Bool {
        (24...128).contains(slug.count)
            && slug.unicodeScalars.allSatisfy {
                $0.isASCII
                    && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_")
            }
    }
}

final class JournalPassportRouter: ObservableObject {
    static let shared = JournalPassportRouter()

    @Published private(set) var requestID: UUID?

    func requestPassport() {
        requestID = UUID()
    }

    func consume(_ requestID: UUID?) {
        guard self.requestID == requestID else { return }
        self.requestID = nil
    }
}
