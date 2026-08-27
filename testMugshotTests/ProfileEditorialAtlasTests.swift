import Foundation
import SwiftUI
import Testing
import UIKit
@testable import testMugshot

struct ProfileEditorialAtlasTests {
    @Test func profileTabsKeepTheApprovedOrderAndAccessibilityIdentity() {
        #expect(SharedProfileTab.allCases == [.mugshots, .cafes, .map, .tagged])
        #expect(SharedProfileTab.mugshots.accessibilityTitle == "Public Mugshots")
        #expect(SharedProfileTab.cafes.accessibilityTitle == "Public cafes")
        #expect(SharedProfileTab.map.accessibilityTitle == "Public exploration map")
        #expect(SharedProfileTab.tagged.accessibilityTitle == "Tagged Mugshots")
    }

    @Test func favoriteSpotPolicyAllowsThreeUniqueNormalizedSelections() throws {
        let inputs = [
            ProfileFavoriteSpotInput(cafeID: UUID(), descriptor: "  Best coffee  "),
            ProfileFavoriteSpotInput(cafeID: UUID(), descriptor: "Best hang"),
            ProfileFavoriteSpotInput(cafeID: UUID(), descriptor: "Fun drinks"),
        ]

        let validated = try #require(ProfileFavoriteSpotPolicy.validated(inputs))
        #expect(validated.count == 3)
        #expect(validated[0].descriptor == "Best coffee")
        #expect(ProfileFavoriteSpotPolicy.validated(inputs + [
            ProfileFavoriteSpotInput(cafeID: UUID(), descriptor: "Fourth")
        ]) == nil)
        #expect(ProfileFavoriteSpotPolicy.validated([
            inputs[0],
            ProfileFavoriteSpotInput(cafeID: inputs[0].cafeID, descriptor: "Duplicate")
        ]) == nil)
        #expect(ProfileFavoriteSpotPolicy.normalizedDescriptor(String(repeating: "x", count: 31)) == nil)
    }

    @Test func descriptorCatalogCoversAllFavoriteSpotReasonsWithoutDuplicates() {
        #expect(ProfileSpotDescriptorCategory.allCases == [
            .drink, .vibe, .food, .occasion, .service, .custom
        ])
        let suggestions = ProfileSpotDescriptorCategory.allCases.flatMap(\.suggestions)
        #expect(Set(suggestions).count == suggestions.count)
        #expect(suggestions.count >= 25)
        #expect(suggestions.contains("Best coffee"))
        #expect(suggestions.contains("Best fun drinks"))
        #expect(suggestions.contains("Best hang"))
        #expect(suggestions.contains("Work remote"))
        #expect(suggestions.contains("Best pastries"))
        #expect(suggestions.contains("Worth the trip"))
        #expect(suggestions.contains("Best service"))
        #expect(ProfileSpotDescriptorCategory.category(containing: "Best service") == .service)
        #expect(ProfileSpotDescriptorCategory.category(containing: "Best people-watching") == .custom)
        #expect(ProfileSpotDescriptorCategory.category(containing: nil) == .drink)
    }

    @Test @MainActor
    func cafeDerivationStitchesProfilePublishedRowsAndRejectsPrivateRows() throws {
        let canonicalCafeID = UUID()
        let duplicateCafeID = UUID()
        let publicFirst = makeVisit(
            cafeID: canonicalCafeID,
            visibility: "everyone",
            score: 4.2,
            identityKey: "charleston:tiny-nook-rutledge",
            createdAt: "2026-08-24T10:00:00Z"
        )
        let publicSecond = makeVisit(
            cafeID: duplicateCafeID,
            visibility: "Everyone",
            score: 4.6,
            identityKey: "charleston:tiny-nook-rutledge",
            createdAt: "2026-08-25T10:00:00Z"
        )
        let friendsOnly = makeVisit(
            cafeID: canonicalCafeID,
            visibility: "friends",
            score: 5,
            identityKey: "charleston:tiny-nook-rutledge",
            createdAt: "2026-08-25T11:00:00Z"
        )
        let privateVisit = makeVisit(
            cafeID: canonicalCafeID,
            visibility: "private",
            score: 1,
            identityKey: "charleston:tiny-nook-rutledge",
            createdAt: "2026-08-25T12:00:00Z"
        )

        let cafes = SharedProfileView.deriveCafes(
            from: [publicFirst, publicSecond, friendsOnly, privateVisit]
        )
        let cafe = try #require(cafes.first)
        #expect(cafes.count == 1)
        #expect(cafe.id == canonicalCafeID)
        #expect(cafe.sipCount == 3)
        #expect(cafe.evidenceCount == 3)
        #expect(abs(cafe.score - 4.6) < 0.0001)
        #expect(cafe.localCafe.id == canonicalCafeID)
    }

    @Test func profilePublicationIncludesFriendsAndEveryoneButNeverPrivate() {
        let cafeID = UUID()
        let everyone = makeVisit(
            cafeID: cafeID,
            visibility: "everyone",
            score: 4,
            identityKey: "test:cafe",
            createdAt: "2026-08-24T10:00:00Z"
        )
        let friends = makeVisit(
            cafeID: cafeID,
            visibility: "Friends",
            score: 4,
            identityKey: "test:cafe",
            createdAt: "2026-08-24T11:00:00Z"
        )
        let privateVisit = makeVisit(
            cafeID: cafeID,
            visibility: "private",
            score: 4,
            identityKey: "test:cafe",
            createdAt: "2026-08-24T12:00:00Z"
        )

        #expect(everyone.isPublishedOnProfile)
        #expect(friends.isPublishedOnProfile)
        #expect(!privateVisit.isPublishedOnProfile)
        #expect(everyone.isStrictlyPublic)
        #expect(!friends.isStrictlyPublic)
    }

    @Test func profileShareContentUsesOnlyProfilePublishedRowsAndPublicDisplayFields() {
        let cafeID = UUID()
        let everyone = makeVisit(
            cafeID: cafeID,
            visibility: "everyone",
            score: 4.5,
            identityKey: "test:cafe",
            createdAt: "2026-08-24T10:00:00Z"
        )
        let friends = makeVisit(
            cafeID: cafeID,
            visibility: "friends",
            score: 4.2,
            identityKey: "test:cafe",
            createdAt: "2026-08-24T11:00:00Z"
        )
        let privateVisit = makeVisit(
            cafeID: cafeID,
            visibility: "private",
            score: 5,
            identityKey: "test:cafe",
            createdAt: "2026-08-24T12:00:00Z"
        )
        let content = ProfileShareContent(
            projection: EditorialProfileFixture.sample.projection,
            sips: [everyone, friends, privateVisit]
        )
        let fields = Set(Mirror(reflecting: content).children.compactMap(\.label))

        #expect(content.displayName == "amanda")
        #expect(content.username == "dairiequeen")
        #expect(content.shareMessage == "Add me on Mugshot — @dairiequeen")
        #expect(content.linkMetadataTitle == "Add @dairiequeen on Mugshot")
        #expect(content.postPhotoURLs.count == 2)
        #expect(content.favoriteSpots.count == 3)
        #expect(fields.contains("postPhotoURLs"))
        #expect(!fields.contains("privateNotes"))
        #expect(!fields.contains("latitude"))
        #expect(!fields.contains("longitude"))
        #expect(!fields.contains("ratings"))
    }

    @Test func profileShareContentUsesNewestPhotosAndRetainsDurableStorageReferences() {
        let cafeID = UUID()
        let latestReference = "mugshot-storage://visit-photos-private/user/visit/latest.jpg"
        let latest = makeVisit(
            cafeID: cafeID,
            visibility: "friends",
            score: 4.8,
            identityKey: "test:cafe",
            createdAt: "2026-08-26T17:00:00.123Z",
            posterPhotoURL: latestReference
        )
        let middle = makeVisit(
            cafeID: cafeID,
            visibility: "everyone",
            score: 4.5,
            identityKey: "test:cafe",
            createdAt: "2026-08-25T17:00:00Z",
            posterPhotoURL: "https://example.com/middle.jpg"
        )
        let oldest = makeVisit(
            cafeID: cafeID,
            visibility: "everyone",
            score: 4.0,
            identityKey: "test:cafe",
            createdAt: "2025-12-24T17:00:00Z",
            posterPhotoURL: "https://example.com/christmas.jpg"
        )

        let content = ProfileShareContent(
            projection: EditorialProfileFixture.sample.projection,
            sips: [oldest, latest, middle]
        )

        #expect(content.postPhotoURLs == [
            latestReference,
            "https://example.com/middle.jpg",
            "https://example.com/christmas.jpg",
        ])
    }

    @MainActor
    @Test func profileShareArtworkRendersAtExactStoryAndPostBounds() throws {
        let content = ProfileShareContent(
            projection: EditorialProfileFixture.sample.projection,
            sips: EditorialProfileFixture.sample.sips
        )

        for format in MugshotShareFormat.allCases {
            let size = format.pixelSize
            let artwork = ProfileShareArtworkView(
                content: content,
                images: .empty,
                format: format
            )
            .frame(width: size.width, height: size.height)
            let renderer = ImageRenderer(content: artwork)
            renderer.scale = 1
            let rendered = try #require(renderer.uiImage)
            #expect(rendered.size == size)
        }
    }

    @MainActor
    @Test func profileSharePackageIncludesArtworkMarketingCopyAndCanonicalLink() throws {
        let content = ProfileShareContent(
            projection: EditorialProfileFixture.sample.projection,
            sips: EditorialProfileFixture.sample.sips
        )
        let publicURL = try #require(
            URL(string: "https://mugshotapp.co/p/\(String(repeating: "a", count: 48))")
        )
        let package = ProfileSharePackage(
            content: content,
            storyArtwork: UIImage(),
            postArtwork: UIImage(),
            linkPreviewArtwork: UIImage(),
            publicURL: publicURL
        )

        let items = package.primaryActivityItems(for: .story)
        #expect(items.count == 3)
        #expect(items[0] is UIImage)
        #expect(items[1] as? String == content.shareMessage)
        #expect((items[2] as? MugshotShareLinkItemSource)?.url == publicURL)
        let metadata = MugshotShareLinkItemSource.linkMetadata(
            url: publicURL,
            previewImage: UIImage(),
            title: content.linkMetadataTitle
        )
        #expect(metadata.title == "Add @dairiequeen on Mugshot")
        #expect(metadata.url == publicURL)
    }

    private func makeVisit(
        cafeID: UUID,
        visibility: String,
        score: Double,
        identityKey: String,
        createdAt: String,
        posterPhotoURL: String = "https://example.com/photo.jpg"
    ) -> PublicProfileVisit {
        PublicProfileVisit(
            id: UUID(),
            userID: UUID(),
            cafeID: cafeID,
            caption: "Caption",
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Latte",
            visibility: visibility,
            ratings: [:],
            overallScore: score,
            posterPhotoURL: posterPhotoURL,
            photoURLs: [],
            contextType: "cafe",
            locationName: nil,
            createdAt: createdAt,
            cafeName: "Tiny Nook Cafe",
            cafeCity: "Charleston",
            latitude: 32.78,
            longitude: -79.94,
            identityKey: identityKey,
            authorDisplayName: "Amanda",
            authorUsername: "amanda",
            authorAvatarURL: nil
        )
    }
}
