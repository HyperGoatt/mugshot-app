//
//  testMugshotTests.swift
//  testMugshotTests
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import Testing
@testable import testMugshot

struct testMugshotTests {

    @Test func supabaseConfigurationLoadsClientSafeValues() throws {
        let configuration = try SupabaseConfiguration.load(
            environment: [
                "MUGSHOT_SUPABASE_URL": "https://example.supabase.co",
                "MUGSHOT_SUPABASE_PUBLISHABLE_KEY": "sb_publishable_test_key"
            ]
        )

        #expect(configuration.url.absoluteString == "https://example.supabase.co")
        #expect(configuration.publishableKey == "sb_publishable_test_key")
    }

    @Test func supabaseConfigurationRejectsSecretKeys() {
        var thrownError: SupabaseConfigurationError?
        let rejectedClientKey = "sb_" + "secret_not_for_clients"

        do {
            _ = try SupabaseConfiguration.load(
                environment: [
                    "MUGSHOT_SUPABASE_URL": "https://example.supabase.co",
                    "MUGSHOT_SUPABASE_PUBLISHABLE_KEY": rejectedClientKey
                ]
            )
        } catch let error as SupabaseConfigurationError {
            thrownError = error
        } catch {
            thrownError = nil
        }

        #expect(thrownError == .secretKeyRejected)
    }

    @Test func supabaseProfileMapsToLocalUser() {
        let id = UUID()
        let profile = SupabaseUserProfile(
            id: id,
            displayName: "Joe",
            username: "joe",
            bio: "Coffee notes",
            location: "CHS",
            favoriteDrink: "Espresso",
            instagramHandle: "rosso5",
            avatarURL: "https://example.com/avatar.jpg",
            bannerURL: nil,
            websiteURL: "https://mugshotapp.co"
        )

        let user = profile.localUser

        #expect(user.id == id)
        #expect(user.username == "joe")
        #expect(user.displayName == "Joe")
        #expect(user.location == "CHS")
        #expect(user.bio == "Coffee notes")
        #expect(user.avatarImageName == "https://example.com/avatar.jpg")
    }

    @Test func profileUpdateEncodesNullForClearedOptionalFields() throws {
        let update = SupabaseUserProfileUpdate(
            displayName: "Joe",
            username: "joe",
            bio: nil,
            location: "CHS",
            favoriteDrink: nil,
            instagramHandle: "rosso5",
            websiteURL: nil
        )

        let data = try JSONEncoder().encode(update)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["display_name"] as? String == "Joe")
        #expect(object["username"] as? String == "joe")
        #expect(object["location"] as? String == "CHS")
        #expect(object["instagram_handle"] as? String == "rosso5")
        #expect(object["bio"] is NSNull)
        #expect(object["favorite_drink"] is NSNull)
        #expect(object["website_url"] is NSNull)
    }

}
