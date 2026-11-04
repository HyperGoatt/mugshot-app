import Foundation
import Testing
import UIKit
@testable import testMugshot

@Suite(.serialized)
struct HomeRecipeSourceTests {
    @Test func sourceTransportIsUnauthenticatedAndFailureLeavesAnHonestFallback() async throws {
        let reader = HomeRecipeSourceReader(protocolClasses: [RecipeSourceProtocol.self])
        RecipeSourceProtocol.reply = (200, "text/html", Data(#"<meta property="og:description" content="Ingredients:&#10;2 g matcha&#10;Steps:&#10;Whisk.">"#.utf8))
        let source = try await reader.read("https://www.instagram.com/p/test-source/?igsh=tracking")
        #expect(source.text.contains("2 g matcha"))
        #expect(RecipeSourceProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(RecipeSourceProtocol.lastRequest?.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(RecipeSourceProtocol.lastRequest?.url?.query == nil)
        RecipeSourceProtocol.reply = (403, "text/html", Data("Sign in".utf8))
        await #expect(throws: (any Error).self) { try await reader.read("https://www.instagram.com/p/test-source/") }
        RecipeSourceProtocol.reply = (200, "image/jpeg", Data("not a caption".utf8))
        await #expect(throws: (any Error).self) { try await reader.read("https://www.instagram.com/p/test-source/") }
    }

    @Test func approvedVideoDataIsBoundedAndStoredOnlyInATemporaryFile() async throws {
        let reader = HomeRecipeSourceReader(protocolClasses: [RecipeSourceProtocol.self])
        RecipeSourceProtocol.reply = (200, "video/mp4", Data([1, 2, 3]))
        let url = try await reader.video(URL(string: "https://video.cdninstagram.com/clip.mp4")!)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try Data(contentsOf: url) == Data([1, 2, 3]))
        await #expect(throws: (any Error).self) { try await reader.video(URL(string: "https://127.0.0.1/clip.mp4")!) }
        RecipeSourceProtocol.reply = (200, "text/html", Data("Not a video".utf8))
        await #expect(throws: (any Error).self) { try await reader.video(URL(string: "https://video.cdninstagram.com/clip.mp4")!) }
    }

    @Test func replacingAScreenshotKeepsItsCaptionAndUserTyping() {
        var sources = HomeRecipeCaptureSources()
        let caption = sources.update(.caption, text: "Creator caption", currentText: "")
        let first = sources.update(.screenshot, text: "Old screenshot", currentText: caption)
        let second = sources.update(.screenshot, text: "New screenshot", currentText: first)
        #expect(second.contains("Creator caption"))
        #expect(second.contains("New screenshot"))
        #expect(!second.contains("Old screenshot"))
        let edited = "My correction\n" + second
        #expect(sources.update(.video, text: "Spoken instructions", currentText: edited).contains(edited))
    }

    @Test func combinedSourcesReserveTheCreditSlotInsideTheServerEvidenceLimit() {
        var content = HomeRecipeContent(name: "Tea", template: .preparation, method: .westernTea)
        content.sourceURL = "https://www.instagram.com/p/abc/"
        content.creatorCredit = "Creator"
        content.sourceText = String(repeating: "Recipe text 🧋", count: 4_000)
        let source = CoffeeAssistanceRecipeImport.source(content)
        #expect(source.count <= 20)
        #expect(source.allSatisfy { $0.detail.utf16.count <= 800 })
        #expect(source.first?.id == "recipe-credit")
    }

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

private final class RecipeSourceProtocol: URLProtocol, @unchecked Sendable {
    static var reply = (200, "text/html", Data())
    static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let (status, mime, data) = Self.reply
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": mime, "Content-Length": String(data.count)])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
