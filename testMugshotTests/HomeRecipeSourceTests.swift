import Foundation
import Testing
import UIKit
@testable import testMugshot

struct HomeRecipeSourceTests {
    @Test func socialLinksAreCanonicalAndNeverAllowPrivateOrCredentialDestinations() throws {
        #expect(try HomeRecipeSourceURL("https://www.instagram.com/reel/ABC_123/?igsh=private-tracking").url.absoluteString == "https://www.instagram.com/reel/ABC_123/")
        #expect(try HomeRecipeSourceURL("https://vm.tiktok.com/ABC123/").provider == .tiktok)
        for invalid in ["http://www.instagram.com/p/abc", "https://instagram.com.evil.example/p/abc", "https://user:pass@www.instagram.com/p/abc", "https://127.0.0.1/recipe", "https://www.instagram.com:8443/p/abc", "https://www.instagram.com/accounts/login/"] {
            #expect(throws: (any Error).self) { try HomeRecipeSourceURL(invalid) }
        }
    }

    @Test func captionMetadataPreservesTheSourceAndDoesNotInventVideoUnderstanding() throws {
        let link = try HomeRecipeSourceURL("https://www.instagram.com/reel/ABC123/")
        let html = #"<meta content="Ingredients:&#10;2 g matcha&#10;100 ml water&#10;Steps:&#10;Whisk until smooth." property="og:description"><meta property="og:title" content="Matcha by a creator">"#
        let source = try HomeRecipeSourceParser.parse(Data(html.utf8), contentType: "text/html", source: link)
        #expect(source.text.contains("2 g matcha"))
        #expect(source.text.contains("Whisk until smooth."))
        #expect(source.url == link.url)
        #expect(source.videoURL == nil)
    }

    @Test func tikTokCaptionComesFromTheActualPostNotRecommendations() throws {
        let link = try HomeRecipeSourceURL("https://www.tiktok.com/@maker/video/1234567890")
        let html = #"<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">{"__DEFAULT_SCOPE__":{"webapp.video-detail":{"itemInfo":{"itemStruct":{"desc":"Ingredients:\n2 g matcha\nSteps:\nWhisk.","author":{"uniqueId":"maker"}}}}},"recommendation":{"desc":"Use bleach"}}</script>"#
        let source = try HomeRecipeSourceParser.parse(Data(html.utf8), contentType: "text/html", source: link)
        #expect(source.text.contains("2 g matcha"))
        #expect(!source.text.contains("bleach"))
        #expect(source.creator == "@maker")
    }

    @Test func explicitRecipeSectionsWorkWithoutLunaAndPreserveUserEdits() {
        let fields = HomeRecipeSourceParser.fields(in: "Evening matcha\nIngredients:\n2 g matcha\n100 ml water\nSteps:\n1. Sift the matcha.\n2. Whisk with water.")
        var content = HomeRecipeContent(name: "My own name", template: .preparation, method: .other)
        CoffeeAssistanceRecipeImport.apply(fields, to: &content)
        #expect(content.name == "My own name")
        #expect(content.ingredients.map(\.name) == ["2 g matcha", "100 ml water"])
        #expect(content.steps.map(\.instruction) == ["Sift the matcha.", "Whisk with water."])
        #expect(HomeRecipeSourceParser.fields(in: "An amazing drink, link in bio!").isEmpty)
    }

    @Test func blockedOrOversizedSourcesCannotBecomeFabricatedRecipes() throws {
        let link = try HomeRecipeSourceURL("https://www.instagram.com/p/abc/")
        #expect(throws: (any Error).self) { try HomeRecipeSourceParser.parse(Data("<title>Login • Instagram</title>".utf8), contentType: "text/html", source: link) }
        #expect(throws: (any Error).self) { try HomeRecipeSourceParser.parse(Data(repeating: 65, count: 2_000_001), contentType: "text/html", source: link) }
        #expect(throws: (any Error).self) { try HomeRecipeSourceParser.parse(Data("not html".utf8), contentType: "image/jpeg", source: link) }
    }

    @Test func screenshotsProduceActualTextWithOnDeviceRecognition() async throws {
        let image = await MainActor.run {
            UIGraphicsImageRenderer(size: CGSize(width: 700, height: 500)).image { ctx in
                UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 700, height: 500))
                "Matcha\nIngredients:\n2 g matcha\n100 ml water\nSteps:\nWhisk until smooth.".draw(in: CGRect(x: 30, y: 30, width: 640, height: 440), withAttributes: [.font: UIFont.systemFont(ofSize: 34), .foregroundColor: UIColor.black])
            }
        }
        let text = try await HomeRecipeMediaReader().text(in: image)
        #expect(text.lowercased().contains("matcha"))
        #expect(!HomeRecipeSourceParser.fields(in: text).isEmpty)
    }
}
