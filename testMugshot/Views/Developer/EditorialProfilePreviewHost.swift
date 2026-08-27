import SwiftUI

struct EditorialProfileFixture {
    let projection: SharedProfileProjection
    let sips: [PublicProfileVisit]
    let cafes: [SharedProfilePublicCafe]
    let taggedSips: [PublicProfileVisit]

    static let sample: EditorialProfileFixture = {
        let profileID = UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!
        let authorID = UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!
        let cafeIDs = [
            UUID(uuidString: "C1000000-0000-4000-8000-000000000001")!,
            UUID(uuidString: "C1000000-0000-4000-8000-000000000002")!,
            UUID(uuidString: "C1000000-0000-4000-8000-000000000003")!,
        ]
        let assets = [
            "V3OrangeCreamsicleHeroV2",
            "V3CreamyLatte",
            "V3QuietCafeCorner",
            "V3OrangeCitrusDetail",
            "V3OrangeCreamsicleSquare",
            "OnboardingMarketing03Feed",
        ]
        let names = ["Bad Bunnies Coffee", "Sightsee", "Babas on Meeting"]
        let descriptors = ["Best coffee", "Best fun drinks", "Work remote"]
        let cities = ["Charleston", "Charleston", "Charleston"]
        let coordinates = [(32.7834, -79.9373), (32.7765, -79.9311), (32.7891, -79.9379)]

        let cafes = cafeIDs.enumerated().map { index, id in
            SharedProfilePublicCafe(
                id: id,
                name: names[index],
                city: cities[index],
                address: "Charleston, SC",
                latitude: coordinates[index].0,
                longitude: coordinates[index].1,
                identityKey: "fixture:\(index)",
                score: [4.7, 4.4, 4.2][index],
                evidenceCount: [9, 6, 4][index],
                sipCount: [12, 8, 5][index],
                coverPhotoURL: "asset://\(assets[index])"
            )
        }
        let favorites = cafeIDs.enumerated().map { index, id in
            SharedProfileFavoriteSpot(
                position: index,
                descriptor: descriptors[index],
                cafeID: id,
                name: names[index],
                city: cities[index],
                address: "Charleston, SC",
                latitude: coordinates[index].0,
                longitude: coordinates[index].1,
                identityKey: "fixture:\(index)",
                coverPhotoURL: "asset://\(assets[index])"
            )
        }
        let profile = SupabaseUserProfile(
            id: profileID,
            displayName: "amanda",
            username: "dairiequeen",
            bio: "Cafe walks, fun drinks, and a good corner table.",
            location: "Charleston, SC",
            favoriteDrink: "Coffee",
            instagramHandle: nil,
            avatarURL: "asset://V3CreamyLatte",
            bannerURL: "asset://V3OrangeCreamsicleHeroV2",
            websiteURL: nil
        )

        func visit(_ index: Int, author: UUID = profileID) -> PublicProfileVisit {
            let cafeIndex = index % cafes.count
            return PublicProfileVisit(
                id: UUID(uuidString: String(format: "D1000000-0000-4000-8000-%012d", index + 1))!,
                userID: author,
                cafeID: cafeIDs[cafeIndex],
                caption: "A really good afternoon sip in Charleston.",
                drinkType: "Coffee",
                drinkTypeCustom: nil,
                drinkSubtype: ["Iced latte", "Cortado", "Orange espresso"][cafeIndex],
                visibility: "everyone",
                ratings: ["Taste": [4.7, 4.4, 4.2][cafeIndex]],
                overallScore: [4.7, 4.4, 4.2][cafeIndex],
                posterPhotoURL: "asset://\(assets[index % assets.count])",
                photoURLs: [],
                contextType: "cafe",
                locationName: nil,
                createdAt: String(format: "2026-08-%02dT15:00:00Z", 25 - index),
                cafeName: names[cafeIndex],
                cafeCity: cities[cafeIndex],
                latitude: coordinates[cafeIndex].0,
                longitude: coordinates[cafeIndex].1,
                identityKey: "fixture:\(cafeIndex)",
                authorDisplayName: author == profileID ? "amanda" : "Maya",
                authorUsername: author == profileID ? "dairiequeen" : "maya_sips",
                authorAvatarURL: nil
            )
        }

        return EditorialProfileFixture(
            projection: SharedProfileProjection(
                profile: profile,
                friendshipState: .friends,
                stats: SharedProfileStats(friends: 152, sips: 56, cafes: 30),
                favoriteSpots: favorites,
                viewerProjection: "everyone"
            ),
            sips: (0..<9).map { visit($0) },
            cafes: cafes,
            taggedSips: (3..<9).map { visit($0, author: authorID) }
        )
    }()
}

#if DEBUG
struct EditorialProfilePreviewHost: View {
    let showsOwnerControls: Bool
    @StateObject private var dataManager = DataManager()

    var body: some View {
        NavigationStack {
            SharedProfileView(
                source: .user(EditorialProfileFixture.sample.projection.profile.id, asEveryone: true),
                dataManager: dataManager,
                showsOwnerControls: showsOwnerControls,
                previewFixture: .sample
            )
        }
    }
}
#endif
