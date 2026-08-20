import Foundation
import Supabase
import UIKit

struct MugshotShareConfiguration: Equatable {
    let publicBaseURL: URL?
    let appStoreURL: URL?
    let metaAppID: String?
    let snapchatClientID: String?

    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> MugshotShareConfiguration {
        let baseURL = usableValue(
            environment["MUGSHOT_PUBLIC_BASE_URL"],
            bundle.object(forInfoDictionaryKey: "MUGSHOT_PUBLIC_BASE_URL") as? String
        ).flatMap(URL.init(string:))
        let appStoreURL = usableValue(
            environment["MUGSHOT_APP_STORE_URL"],
            bundle.object(forInfoDictionaryKey: "MUGSHOT_APP_STORE_URL") as? String
        ).flatMap(URL.init(string:))

        return MugshotShareConfiguration(
            publicBaseURL: baseURL?.scheme?.lowercased() == "https" ? baseURL : nil,
            appStoreURL: appStoreURL?.scheme?.lowercased() == "https" ? appStoreURL : nil,
            metaAppID: usableValue(
                environment["MUGSHOT_META_APP_ID"],
                bundle.object(forInfoDictionaryKey: "MUGSHOT_META_APP_ID") as? String
            ),
            snapchatClientID: usableValue(
                environment["MUGSHOT_SNAPCHAT_CLIENT_ID"],
                bundle.object(forInfoDictionaryKey: "MUGSHOT_SNAPCHAT_CLIENT_ID") as? String
            )
        )
    }

    func publicURL(slug: String) -> URL? {
        guard MugshotSharedLinkRoute.isValidSlug(slug),
              let publicBaseURL else {
            return nil
        }
        return publicBaseURL
            .appendingPathComponent("m", isDirectory: true)
            .appendingPathComponent(slug, isDirectory: false)
    }

    private static func usableValue(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first {
                !$0.isEmpty
                    && !$0.contains("$(")
                    && !$0.localizedCaseInsensitiveContains("replace_me")
                    && !$0.localizedCaseInsensitiveContains("your_")
            }
    }
}

enum MugshotShareFeatureFlags {
    static let hub = "feature.postPublishShareHub"
    static let instagram = "feature.shareHub.instagram"
    static let facebook = "feature.shareHub.facebook"
    static let snapchat = "feature.shareHub.snapchat"
    static let publicLinks = "feature.shareHub.publicLinks"

    static func isEnabled(_ key: String, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }
}

final class MugshotShareLinkService {
    private let client: SupabaseClient
    private let configuration: MugshotShareConfiguration

    init(
        client: SupabaseClient,
        configuration: MugshotShareConfiguration = .load()
    ) {
        self.client = client
        self.configuration = configuration
    }

    func createOwnerLink(visitID: UUID) async throws -> URL? {
        guard MugshotShareFeatureFlags.isEnabled(MugshotShareFeatureFlags.publicLinks),
              configuration.publicBaseURL != nil else {
            return nil
        }
        let slug: String = try await client.rpc(
            "create_visit_share_link_v1",
            params: ["p_visit_id": visitID]
        )
        .execute()
        .value
        return configuration.publicURL(slug: slug)
    }

    func existingLink(visitID: UUID) async throws -> URL? {
        guard MugshotShareFeatureFlags.isEnabled(MugshotShareFeatureFlags.publicLinks),
              configuration.publicBaseURL != nil else {
            return nil
        }
        let slug: String? = try await client.rpc(
            "get_visit_share_slug_v1",
            params: ["p_visit_id": visitID]
        )
        .execute()
        .value
        return slug.flatMap(configuration.publicURL(slug:))
    }

    func publicProjection(slug: String) async throws -> MugshotPublicProjection? {
        guard MugshotSharedLinkRoute.isValidSlug(slug) else { return nil }
        if let endpoint = configuration.publicURL(slug: slug),
           var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) {
            components.queryItems = [URLQueryItem(name: "format", value: "json")]
            if let url = components.url {
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                request.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: request)
                if let response = response as? HTTPURLResponse {
                    if response.statusCode == 404 { return nil }
                    guard (200..<300).contains(response.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                }
                return try Self.publicProjectionDecoder.decode(
                    MugshotPublicProjection.self,
                    from: data
                )
            }
        }

        let rows: [MugshotPublicProjection] = try await client.rpc(
            "get_public_mugshot_share_v1",
            params: ["p_slug": slug]
        )
        .execute()
        .value
        return rows.first
    }

    private static var publicProjectionDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Mugshot share timestamp"
            )
        }
        return decoder
    }

    func recordPublicEvent(slug: String, eventName: String) async {
        guard MugshotSharedLinkRoute.isValidSlug(slug),
              eventName == "landing_visit" || eventName == "app_open" else {
            return
        }
        _ = try? await client.rpc(
            "record_public_mugshot_share_event_v1",
            params: [
                "p_slug": slug,
                "p_event_name": eventName
            ]
        )
        .execute()
    }
}

enum MugshotShareHandoffError: LocalizedError, Equatable {
    case unavailable
    case missingProviderConfiguration
    case artworkEncodingFailed
    case openFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "That app is not available. Try More or save the image."
        case .missingProviderConfiguration:
            return "That destination is not configured yet. Try More or save the image."
        case .artworkEncodingFailed:
            return "Mugshot could not prepare the image. Please try again."
        case .openFailed:
            return "The destination did not open. Try More or save the image."
        }
    }
}

@MainActor
final class MugshotShareDestinationCoordinator {
    private let application: UIApplication
    private let pasteboard: UIPasteboard
    private let configuration: MugshotShareConfiguration

    init(
        application: UIApplication,
        pasteboard: UIPasteboard,
        configuration: MugshotShareConfiguration
    ) {
        self.application = application
        self.pasteboard = pasteboard
        self.configuration = configuration
    }

    convenience init(configuration: MugshotShareConfiguration = .load()) {
        self.init(
            application: .shared,
            pasteboard: .general,
            configuration: configuration
        )
    }

    func isAvailable(_ destination: MugshotShareDestination) -> Bool {
        switch destination {
        case .instagramStory:
            return MugshotShareFeatureFlags.isEnabled(MugshotShareFeatureFlags.instagram)
                && configuration.metaAppID != nil
        case .facebookStory:
            return MugshotShareFeatureFlags.isEnabled(MugshotShareFeatureFlags.facebook)
                && configuration.metaAppID != nil
        case .snapchat:
            return MugshotShareFeatureFlags.isEnabled(MugshotShareFeatureFlags.snapchat)
                && configuration.snapchatClientID != nil
        case .messages:
            return true
        case .more:
            return true
        }
    }

    func open(
        _ destination: MugshotShareDestination,
        package: MugshotSharePackage,
        format: MugshotShareFormat
    ) async throws {
        let artwork = package.artwork(for: format)
        switch destination {
        case .instagramStory:
            try await openMetaStory(
                scheme: "instagram-stories://share",
                artwork: artwork
            )
        case .facebookStory:
            try await openMetaStory(
                scheme: "facebook-stories://share",
                artwork: artwork
            )
        case .snapchat:
            try await openSnapchat(
                artwork: artwork,
                caption: package.content.shareText
            )
        case .messages, .more:
            return
        }
    }

    private func openMetaStory(scheme: String, artwork: UIImage) async throws {
        guard let appID = configuration.metaAppID else {
            throw MugshotShareHandoffError.missingProviderConfiguration
        }
        guard let imageData = artwork.pngData() else {
            throw MugshotShareHandoffError.artworkEncodingFailed
        }
        guard var components = URLComponents(string: scheme) else {
            throw MugshotShareHandoffError.unavailable
        }
        components.queryItems = [URLQueryItem(name: "source_application", value: appID)]
        guard let url = components.url, application.canOpenURL(url) else {
            throw MugshotShareHandoffError.unavailable
        }
        pasteboard.setItems(
            [[
                "com.instagram.sharedSticker.backgroundImage": imageData,
                "com.facebook.sharedSticker.backgroundImage": imageData
            ]],
            options: [
                .expirationDate: Date().addingTimeInterval(300),
                .localOnly: true
            ]
        )
        try await open(url)
    }

    private func openSnapchat(artwork: UIImage, caption: String) async throws {
        guard let clientID = configuration.snapchatClientID else {
            throw MugshotShareHandoffError.missingProviderConfiguration
        }
        guard let imageData = artwork.pngData() else {
            throw MugshotShareHandoffError.artworkEncodingFailed
        }
        guard var components = URLComponents(string: "snapchat://creativekit/preview") else {
            throw MugshotShareHandoffError.unavailable
        }
        components.queryItems = [
            URLQueryItem(name: "checkcount", value: "1"),
            URLQueryItem(name: "clientId", value: clientID),
            URLQueryItem(name: "appDisplayName", value: "Mugshot")
        ]
        guard let url = components.url, application.canOpenURL(url) else {
            throw MugshotShareHandoffError.unavailable
        }
        pasteboard.setItems(
            [[
                "com.snapchat.creativekit.clientID": clientID,
                "com.snapchat.creativekit.backgroundImage": imageData,
                "com.snapchat.creativekit.captionText": String(caption.prefix(300))
            ]],
            options: [
                .expirationDate: Date().addingTimeInterval(300),
                .localOnly: true
            ]
        )
        try await open(url)
    }

    private func open(_ url: URL) async throws {
        let succeeded = await withCheckedContinuation { continuation in
            application.open(url, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
        guard succeeded else { throw MugshotShareHandoffError.openFailed }
    }
}

enum MugshotShareAnalyticsEvent: String {
    case hubViewed = "share_hub_viewed"
    case formatSelected = "share_format_selected"
    case templateSelected = "share_template_selected"
    case photoLayoutSelected = "share_photo_layout_selected"
    case destinationTapped = "share_destination_tapped"
    case handoffOpened = "share_handoff_opened"
    case handoffFailed = "share_handoff_failed"
    case systemShareCompleted = "system_share_completed"
    case hubDismissed = "share_hub_dismissed"

    var postHogAction: MugshotAnalyticsShareAction {
        switch self {
        case .hubViewed: .hubViewed
        case .formatSelected: .formatSelected
        case .templateSelected: .templateSelected
        case .photoLayoutSelected: .photoLayoutSelected
        case .destinationTapped: .destinationTapped
        case .handoffOpened: .handoffOpened
        case .handoffFailed: .handoffFailed
        case .systemShareCompleted: .systemShareCompleted
        case .hubDismissed: .hubDismissed
        }
    }
}

struct MugshotShareAnalyticsProperties: Encodable, Equatable {
    let destination: String?
    let format: String?
    let template: String?
    let photoLayout: String?
    let visibility: String
    let hasPublicLink: Bool

    enum CodingKeys: String, CodingKey {
        case destination
        case format
        case template
        case photoLayout = "photo_layout"
        case visibility
        case hasPublicLink = "has_public_link"
    }
}

final class MugshotShareAnalytics {
    static let shared = MugshotShareAnalytics()

    func record(
        _ event: MugshotShareAnalyticsEvent,
        content: MugshotShareContent,
        destination: MugshotShareDestination? = nil,
        format: MugshotShareFormat? = nil,
        template: MugshotShareTemplate? = nil,
        photoLayout: MugshotSharePhotoLayout? = nil,
        hasPublicLink: Bool = false,
        userID: UUID?
    ) {
        _ = userID
        MugshotAnalytics.shared.capture(
            .share(
                action: event.postHogAction,
                destination: destination?.rawValue,
                format: format?.rawValue,
                template: template?.rawValue,
                photoLayout: photoLayout?.rawValue,
                visibility: content.visibility.rawValue.lowercased(),
                hasPublicLink: hasPublicLink
            )
        )
        if event == .hubViewed {
            MugshotAnalytics.shared.capture(
                .screenViewed(
                    .shareHub,
                    source: content.isOwner ? .postPublish : .sheet
                )
            )
        }
    }
}
