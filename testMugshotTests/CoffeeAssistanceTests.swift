import Foundation
import Testing
import UIKit
@testable import testMugshot

@MainActor
struct CoffeeAssistanceTests {
    private let owner = UUID()
    private func request(task: CoffeeAssistanceTask = .memorySearch) -> CoffeeAssistanceRequest {
        CoffeeAssistanceRequest(ownerID: owner, task: task, query: "Find my latte",
            evidence: [CoffeeAssistanceEvidence(id: "sip-1", title: "Latte", detail: "Origin: Colombia")])
    }
    private func result() -> CoffeeAssistanceResult {
        CoffeeAssistanceResult(text: "A saved memory", evidenceIDs: ["sip-1"], fields: [], searchTerms: [])
    }

    @Test func requestAlwaysEncodesConsentAndNullImageWithBoundedUnicode() throws {
        let request = CoffeeAssistanceRequest(ownerID: owner, task: .memorySearch,
            query: String(repeating: "☕️", count: 500),
            evidence: (0..<50).map { CoffeeAssistanceEvidence(id: "sip-\($0)", title: "Memory", detail: String(repeating: "x", count: 800)) })
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(json["image"] is NSNull)
        #expect(json["consent_version"] as? String == "selected-details-v1")
        #expect(request.query.utf16.count <= 400)
        #expect(request.evidence.count <= 40)
        #expect(request.evidence.reduce(0) { $0 + $1.title.utf16.count + $1.detail.utf16.count } <= 20_000)
    }

    @Test func untrustedReferencesOrWriteFieldsNeverBecomeUsableSuggestions() throws {
        let wrong = CoffeeAssistanceResult(text: "An invented memory", evidenceIDs: ["other-owner"], fields: [], searchTerms: [])
        #expect(throws: CoffeeAssistanceError.self) { try wrong.validate(for: request()) }
        let changingAudience = CoffeeAssistanceResult(text: "Change audience", evidenceIDs: ["sip-1"],
            fields: [CoffeeAssistanceField(key: "visibility", value: "everyone", sourceQuote: "Origin: Colombia")], searchTerms: [])
        #expect(throws: CoffeeAssistanceError.self) { try changingAudience.validate(for: request(task: .bagScan)) }
        try result().validate(for: request())
    }

    @Test func extractionRequiresSourceEvidenceAndIsNeverAnAutomaticSave() throws {
        let quoted = CoffeeAssistanceResult(text: "Check the bag", evidenceIDs: ["sip-1"], fields: [
            CoffeeAssistanceField(key: "origin", value: "Colombia", sourceQuote: "Origin: Colombia")], searchTerms: [])
        try quoted.validate(for: request(task: .bagScan))
        #expect(throws: CoffeeAssistanceError.self) { try quoted.validate(for: request()) }
        let invented = CoffeeAssistanceResult(text: "Check the bag", evidenceIDs: ["sip-1"], fields: [
            CoffeeAssistanceField(key: "origin", value: "Kenya", sourceQuote: "Not in source")], searchTerms: [])
        #expect(throws: CoffeeAssistanceError.self) { try invented.validate(for: request(task: .bagScan)) }
    }

    @Test func cacheIsOwnerBoundShortLivedAndSensitiveToSourceChanges() {
        let cache = CoffeeAssistanceCache()
        let initial = request()
        let now = Date()
        cache.store(result(), for: initial, now: now)
        #expect(cache.result(for: initial, now: now.addingTimeInterval(100)) != nil)
        #expect(cache.result(for: initial, now: now.addingTimeInterval(301)) == nil)
        let changed = CoffeeAssistanceRequest(ownerID: owner, task: .memorySearch,
            query: initial.query, evidence: [CoffeeAssistanceEvidence(id: "sip-1", title: "Edited", detail: "Changed")])
        #expect(cache.result(for: changed, now: now) == nil)
        let other = CoffeeAssistanceRequest(ownerID: UUID(), task: .memorySearch, evidence: initial.evidence)
        #expect(cache.result(for: other, now: now) == nil)
        #expect(cache.result(for: initial, now: now) == nil)
    }

    @Test func noConsentOrChangedOwnerMeansNoTransportCall() async {
        let transport = FixtureTransport(result: result())
        let session = CoffeeAssistanceSession(transport: transport, cache: CoffeeAssistanceCache())
        await session.run(request(), consent: false, currentOwner: { owner })
        #expect(transport.calls == 0)
        await session.run(request(), consent: true, currentOwner: { nil })
        #expect(transport.calls == 0)
        #expect(session.result == nil)
    }

    @Test func successfulRequestsReuseExactEvidenceWithoutCallingAgain() async {
        let transport = FixtureTransport(result: result())
        let session = CoffeeAssistanceSession(transport: transport, cache: CoffeeAssistanceCache())
        await session.run(request(), consent: true, currentOwner: { owner })
        #expect(session.result == result())
        await session.run(request(), consent: true, currentOwner: { owner })
        #expect(transport.calls == 1)
    }

    @Test func providerFailureLeavesAnHonestFallbackAndRetryWorks() async {
        let transport = FixtureTransport(result: result())
        transport.shouldFail = true
        let session = CoffeeAssistanceSession(transport: transport, cache: CoffeeAssistanceCache())
        await session.run(request(), consent: true, currentOwner: { owner })
        #expect(session.result == nil)
        #expect(session.message != nil)
        #expect(!session.isWorking)
        transport.shouldFail = false
        await session.run(request(), consent: true, currentOwner: { owner })
        #expect(session.result == result())
    }

    @Test func invalidationWhileRequestIsRunningDropsLateResult() async {
        let transport = FixtureTransport(result: result())
        let session = CoffeeAssistanceSession(transport: transport, cache: CoffeeAssistanceCache())
        transport.beforeReturning = { session.invalidate() }
        await session.run(request(), consent: true, currentOwner: { owner })
        #expect(session.result == nil)
        #expect(!session.isWorking)
    }

    @Test func accountChangesWhileRequestIsRunningDropResultAndCache() async {
        let transport = FixtureTransport(result: result())
        let cache = CoffeeAssistanceCache()
        let session = CoffeeAssistanceSession(transport: transport, cache: cache)
        var current: UUID? = owner
        transport.beforeReturning = { current = UUID() }
        await session.run(request(), consent: true, currentOwner: { current })
        #expect(session.result == nil)
        #expect(cache.result(for: request()) == nil)
        #expect(!session.isWorking)
    }

    @Test func journalContextRequiresOwnerCompletionAndExplicitPrivateNoteInclusion() {
        func entry(userID: UUID, state: String = "complete") -> JournalEntryProjection {
            let row = SupabaseVisitRow(id: UUID(), userId: userID, cafeId: nil,
                drinkType: "Latte", drinkTypeCustom: nil, drinkSubtype: nil, caption: "Recorded caption",
                notes: nil, visibility: "private", uploadState: state, ratings: [:], overallScore: 0,
                posterPhotoURL: nil, contextType: "cafe", locationName: "Fixture Cafe", cityState: "Fixture City",
                brewMethod: nil, createdAt: "2026-11-02T12:00:00Z")
            return JournalEntryProjection(summary: RemoteVisitSummary(visit: row, cafe: nil),
                privateNote: "Private fixture note", isBookmarked: false)
        }
        let owned = entry(userID: owner)
        let rows = [owned, entry(userID: UUID()), entry(userID: owner, state: "pending")]
        let ordinary = CoffeeAssistanceContext.journal(rows, ownerID: owner)
        #expect(ordinary.map(\.id) == [owned.id.uuidString.lowercased()])
        #expect(!ordinary[0].detail.contains("Private fixture note"))
        #expect(ordinary[0].detail.contains("Unrated"))
        #expect(CoffeeAssistanceContext.journal(rows, ownerID: owner, includePrivateNotes: true)[0].detail.contains("Private fixture note"))
    }

    @Test func homeEvidenceExcludesDraftsDuplicatesPlannedTargetsAndRoasterClaims() {
        let now = Date()
        var saved = HomeAttemptRecord(name: "Home test", preparation: .starting(.coffee), reaction: "Too sweet", savedAt: now)
        saved.preparation?.targets.dose = 999
        saved.preparation?.coffee = CoffeeBag(roaster: "Fixture", name: "Bag", tastingNotes: "Fictional roaster note").safeSnapshot
        let evidence = CoffeeAssistanceContext.home([saved, HomeAttemptRecord(name: "Draft")], canonicalIDs: [])
        #expect(evidence.count == 1)
        #expect(!evidence[0].detail.contains("999"))
        #expect(!evidence[0].detail.contains("Fictional roaster note"))
        #expect(CoffeeAssistanceContext.home([saved], canonicalIDs: [saved.id]).isEmpty)
        saved.privateNote = "A private detail"
        #expect(!CoffeeAssistanceContext.attempt(saved).detail.contains("A private detail"))
        #expect(CoffeeAssistanceContext.attempt(saved, includePrivateNotes: true).detail.contains("A private detail"))
    }

    @Test func homeExperimentUsesRecordedIngredientAmountsInsteadOfRecipeTargets() {
        let syrup = HomeRecipeIngredient(name: "Vanilla syrup", amount: 999, unit: "g")
        var recipe = HomeRecipeContent(name: "Latte")
        recipe.ingredients = [syrup]
        var attempt = HomeAttemptRecord(name: "Home latte", preparation: recipe,
            reaction: "Too sweet", nextTimeNote: "Use less syrup", savedAt: .now)
        attempt.actuals.ingredients = [HomeIngredientActual(ingredientID: syrup.id, amount: 15, unit: "g")]
        let evidence = CoffeeAssistanceContext.attempt(attempt, includePrivateNotes: true)
        #expect(evidence.detail.contains("Vanilla syrup: 15"))
        #expect(evidence.detail.contains("Use less syrup"))
        #expect(!evidence.detail.contains("999"))
    }

    @Test func recipeImportPreservesRightsAttributionAndExistingContent() {
        var content = HomeRecipeContent(name: "My recipe", sourceURL: "https://example.test/original", creatorCredit: "Original creator")
        let fields = [CoffeeAssistanceField(key: "name", value: "Replacement", sourceQuote: "Replacement"),
            CoffeeAssistanceField(key: "ingredient", value: "10 g syrup", sourceQuote: "10 g syrup"),
            CoffeeAssistanceField(key: "step", value: "Stir", sourceQuote: "Stir"),
            CoffeeAssistanceField(key: "creatorCredit", value: "Other", sourceQuote: "Other")]
        CoffeeAssistanceRecipeImport.apply(fields, to: &content)
        CoffeeAssistanceRecipeImport.apply(fields, to: &content)
        #expect(content.name == "My recipe")
        #expect(content.creatorCredit == "Original creator")
        #expect(content.ingredients.count == 1)
        #expect(content.ingredients[0].amount == nil)
        #expect(content.steps.count == 1)
        content.sourceReuseAllowed = false
        let protected = content
        CoffeeAssistanceRecipeImport.apply([CoffeeAssistanceField(key: "step", value: "Protected", sourceQuote: "Protected")], to: &content)
        #expect(content == protected)
        #expect(CoffeeAssistanceRecipeImport.source(content).isEmpty)
    }

    @Test func analyticsContainOnlyTaskAndOutcomeEnums() {
        let payload = MugshotAnalyticsEvent.coffeeAssistance(task: .bagScan, action: .requested).payload
        #expect(payload.event == "coffee_assistance")
        #expect(Set(payload.properties.keys) == ["task", "action"])
    }

    @Test func selectedImagesLoseMetadataAndAreBoundedJPEGs() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        }
        let encoded = try CoffeeAssistanceImage.encode(image)
        #expect(encoded.hasPrefix("data:image/jpeg;base64,"))
        let data = try #require(Data(base64Encoded: String(encoded.dropFirst(23))))
        let decoded = try #require(UIImage(data: data))
        #expect(decoded.size.width <= 1280)
        #expect(data.count <= 290_000)
    }

    private final class FixtureTransport: CoffeeAssistanceTransport {
        var calls = 0
        var shouldFail = false
        var beforeReturning: (() -> Void)?
        let result: CoffeeAssistanceResult
        init(result: CoffeeAssistanceResult) { self.result = result }
        func suggest(_ request: CoffeeAssistanceRequest) async throws -> CoffeeAssistanceResult {
            calls += 1
            await Task.yield()
            beforeReturning?()
            if shouldFail { throw CoffeeAssistanceError.unavailable }
            return result
        }
    }
}
