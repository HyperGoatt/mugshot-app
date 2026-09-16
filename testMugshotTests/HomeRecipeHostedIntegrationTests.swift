import XCTest
import Supabase
import UIKit
@testable import testMugshot

/// Opt-in hosted acceptance. Default test runs never contact any backend.
final class HomeRecipeHostedIntegrationTests: XCTestCase {
    @MainActor
    func testNativeWorkspaceMediaAndConflictRecoveryAgainstIsolatedBackend() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let reference = env["MUGSHOT_QA_PROJECT_REF"],
              let email = env["MUGSHOT_QA_EMAIL"], let password = env["MUGSHOT_QA_PASSWORD"] else {
            throw XCTSkip("Requires explicitly provisioned isolated Home QA credentials")
        }
        let configuration = try SupabaseConfiguration.load()
        guard reference != "quskamnfwglctqewwfln", configuration.url.host == "\(reference).supabase.co",
              email.hasSuffix("@example.invalid") else { return XCTFail("Refusing non-QA backend") }
        // Isolate this explicit QA sign-in from the app host's startup session.
        // Mirror the production client's initial-session behavior.
        let storage = HostedHomeAuthStorage()
        let storageKey = "hosted-\(UUID())"
        defer { try? storage.remove(key: storageKey) }
        let client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey,
            options: .init(auth: .init(storage: storage, storageKey: storageKey,
                autoRefreshToken: false, emitLocalSessionAsInitialSession: true)))
        let session = try await client.auth.signIn(email: email, password: password)
        let owner = session.user.id
        let currentSession = try await client.auth.session
        XCTAssertEqual(currentSession.user.id, owner)
        let transport = HomeRecipeWorkspaceService(client: client)
        let emptyWorkspace = try await transport.fetch(ownerID: owner)
        XCTAssertEqual(emptyWorkspace.remoteRevision, 0)
        print("Hosted Home QA: authenticated native RPC and isolated session verified")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HostedHomeQA-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let first = HomeRecipeWorkspaceStore(root: root.appendingPathComponent("first"), transport: transport)
        first.activate(.user(owner))
        var content = HomeRecipeContent(name: "Native hosted espresso", template: .coffee, method: .espresso)
        content.targets = HomeRecipeTargets(dose: 18, ratio: 2, seconds: 28)
        let recipeID = try first.saveRecipe(HomeRecipeEditorDraft(content: content))
        let recipe = try XCTUnwrap(first.workspace.recipes.first { $0.id == recipeID })
        var attempt = HomeAttemptRecord.fresh(from: recipe)
        attempt.actuals.output = 37.5
        attempt.privateNote = "Native private reflection"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.brown.setFill(); context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let name = try first.savePhoto(try XCTUnwrap(image.jpegData(compressionQuality: 0.8)), attemptID: attempt.id)
        attempt.photoNames = [name]
        try first.saveAttempt(attempt)
        await first.synchronize()
        XCTAssertNil(first.errorMessage)
        XCTAssertNil(first.workspace.pendingOperationID)
        XCTAssertEqual(first.workspace.remoteRevision, 1)
        let referenceID = try XCTUnwrap(attempt.recipe)
        let projected = try await transport.content(versionID: referenceID.versionID)
        XCTAssertEqual(projected?.targets.resolvedOutput, 36)

        let second = HomeRecipeWorkspaceStore(root: root.appendingPathComponent("second"), transport: transport)
        second.activate(.user(owner))
        await second.synchronize()
        XCTAssertNil(second.errorMessage)
        XCTAssertEqual(second.workspace.attempts.first?.actuals.output, 37.5)
        XCTAssertNil(second.workspace.attempts.first?.actuals.dose)
        XCTAssertEqual(second.workspace.attempts.first?.privateNote, "Native private reflection")
        XCTAssertNotNil(second.photo(name))
        _ = try first.saveRecipe(HomeRecipeEditorDraft(content: HomeRecipeContent(name: "First device syrup", template: .component)))
        await first.synchronize()
        XCTAssertNil(first.errorMessage)
        _ = try second.saveRecipe(HomeRecipeEditorDraft(content: HomeRecipeContent(name: "Second device drink", template: .drink)))
        await second.synchronize()
        XCTAssertTrue(second.hasRemoteConflict)
        try second.useRemoteAfterConflict()
        await second.synchronize()
        XCTAssertNil(second.errorMessage)
        XCTAssertEqual(second.workspace.recipes.count, 3)
        XCTAssertEqual(second.workspace.attempts.count, 1)
        let published = try await VisitService(client: client).createVisit(userId: owner, cafe: nil,
            entryContext: .home, locationName: "Home", drinkType: .coffee, customDrinkType: nil,
            drinkSubtype: "Unrated native Home make", caption: "A photo-free home make", notes: nil,
            visibility: .friends, ratings: [:], overallScore: 0, ratingTemplate: RatingTemplate(categories: []))
        XCTAssertEqual(published.visit.overallScore, 0)
        XCTAssertEqual(published.visit.drinkSubtype, "Unrated native Home make")
        second.activate(.user(UUID()))
        XCTAssertNil(second.photo(name))
        XCTAssertTrue(second.workspace.attempts.isEmpty)
        try await client.auth.signOut()
    }
}

/// Unsigned test builds cannot access Keychain. Keep only this synthetic test
/// session in memory; production still uses its existing Keychain storage.
private final class HostedHomeAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws {
        lock.lock(); defer { lock.unlock() }; values[key] = value
    }
    func retrieve(key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }; return values[key]
    }
    func remove(key: String) throws {
        lock.lock(); defer { lock.unlock() }; values[key] = nil
    }
}
