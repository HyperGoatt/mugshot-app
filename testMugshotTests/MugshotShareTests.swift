import Foundation
import Testing
@testable import testMugshot

struct MugshotShareTests {
    private let visitID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test func shareFormatsUseExactExportDimensions() {
        #expect(MugshotShareFormat.story.pixelSize.width == 1_080)
        #expect(MugshotShareFormat.story.pixelSize.height == 1_920)
        #expect(MugshotShareFormat.post.pixelSize.width == 1_080)
        #expect(MugshotShareFormat.post.pixelSize.height == 1_350)
    }

    @Test func multiplePhotosDefaultToSmartCollage() {
        #expect(MugshotSharePhotoLayout.defaultLayout(photoCount: 0) == .singlePhoto)
        #expect(MugshotSharePhotoLayout.defaultLayout(photoCount: 1) == .singlePhoto)
        #expect(MugshotSharePhotoLayout.defaultLayout(photoCount: 2) == .smartCollage)
        #expect(
            MugshotSharePhotoLayout.availableLayouts(photoCount: 1) == [.singlePhoto]
        )
        #expect(
            MugshotSharePhotoLayout.availableLayouts(photoCount: 4)
                == [.singlePhoto, .smartCollage]
        )
    }

    @Test func destinationDefaultsMatchNativeHandoffs() {
        #expect(MugshotShareDestination.instagramStory.preferredFormat == .story)
        #expect(MugshotShareDestination.facebookStory.preferredFormat == .story)
        #expect(MugshotShareDestination.snapchat.preferredFormat == .story)
        #expect(MugshotShareDestination.messages.preferredFormat == .post)
        #expect(MugshotShareDestination.more.preferredFormat == .post)
    }

    @Test func safeShareContentHasNoPrivateDataSurface() {
        let content = MugshotShareContent(
            visitID: visitID,
            isOwner: true,
            isRemote: true,
            visibility: .everyone,
            authorName: "  Journal \n Owner  ",
            drinkName: " Cortado ",
            contextName: " Test Cafe ",
            rating: 7,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            caption: "  Bright \n finish  "
        )
        let fields = Set(Mirror(reflecting: content).children.compactMap(\.label))

        #expect(fields == [
            "visitID", "isOwner", "isRemote", "visibility", "authorName",
            "drinkName", "contextName", "rating", "createdAt", "caption"
        ])
        #expect(!fields.contains("notes"))
        #expect(!fields.contains("privateNotes"))
        #expect(!fields.contains("latitude"))
        #expect(!fields.contains("longitude"))
        #expect(!fields.contains("recipe"))
        #expect(!fields.contains("evidence"))
        #expect(content.authorName == "Journal Owner")
        #expect(content.caption == "Bright finish")
        #expect(content.rating == 5)
        #expect(content.mayHavePublicLink)
    }

    @Test func privateAndFriendsHandoffsRequireOneExplicitWarningAndNeverQualifyForLinks() {
        for visibility in [VisitVisibility.private, .friends] {
            let content = MugshotShareContent(
                visitID: visitID,
                isOwner: true,
                isRemote: true,
                visibility: visibility,
                authorName: "Owner",
                drinkName: "Cortado",
                contextName: "Cafe",
                rating: 4.2,
                createdAt: .now,
                caption: nil
            )
            #expect(content.requiresExternalAudienceWarning)
            #expect(!content.mayHavePublicLink)
        }
    }

    @Test func publicLinkRouteAcceptsOnlyConfiguredCanonicalAndCustomRoutes() {
        let slug = String(repeating: "a", count: 48)
        let baseURL = URL(string: "https://mugshotapp.co")!

        #expect(
            MugshotSharedLinkRoute.resolve(
                URL(string: "https://mugshotapp.co/m/\(slug)")!,
                publicBaseURL: baseURL
            )?.slug == slug
        )
        #expect(
            MugshotSharedLinkRoute.resolve(
                URL(string: "mugshot://m/\(slug)")!,
                publicBaseURL: nil
            )?.slug == slug
        )
        #expect(
            MugshotSharedLinkRoute.resolve(
                URL(string: "https://example.com/m/\(slug)")!,
                publicBaseURL: baseURL
            ) == nil
        )
        #expect(
            MugshotSharedLinkRoute.resolve(
                URL(string: "https://mugshotapp.co/m/short")!,
                publicBaseURL: baseURL
            ) == nil
        )
    }

    @Test func providerConfigurationFailsClosedForPlaceholdersAndNonHTTPSLinks() {
        let configuration = MugshotShareConfiguration.load(
            bundle: Bundle(for: EmptyBundleAnchor.self),
            environment: [
                "MUGSHOT_PUBLIC_BASE_URL": "http://mugshotapp.co",
                "MUGSHOT_APP_STORE_URL": "https://apps.apple.com/app/id123",
                "MUGSHOT_META_APP_ID": "REPLACE_ME",
                "MUGSHOT_SNAPCHAT_CLIENT_ID": "$(SNAP_ID)"
            ]
        )

        #expect(configuration.publicBaseURL == nil)
        #expect(configuration.appStoreURL?.host == "apps.apple.com")
        #expect(configuration.metaAppID == nil)
        #expect(configuration.snapchatClientID == nil)
    }

    @Test func analyticsProjectionCannotContainContentOrIdentifiers() {
        let properties = MugshotShareAnalyticsProperties(
            destination: MugshotShareDestination.messages.rawValue,
            format: MugshotShareFormat.post.rawValue,
            template: MugshotShareTemplate.fieldNote.rawValue,
            photoLayout: MugshotSharePhotoLayout.smartCollage.rawValue,
            visibility: VisitVisibility.everyone.supabaseValue,
            hasPublicLink: true
        )
        let fields = Set(Mirror(reflecting: properties).children.compactMap(\.label))

        #expect(fields == [
            "destination", "format", "template", "photoLayout", "visibility", "hasPublicLink"
        ])
        #expect(!fields.contains("caption"))
        #expect(!fields.contains("url"))
        #expect(!fields.contains("photo"))
        #expect(!fields.contains("visitID"))
    }
}

private final class EmptyBundleAnchor {}
