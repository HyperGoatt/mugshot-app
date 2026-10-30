import Foundation
import Supabase
import Testing
import UIKit
@testable import testMugshot

@Suite(.serialized)
struct SipPublicationReliabilityTests {
    @MainActor @Test func frozenUploadedSubmissionCanRetryWithoutLocalPhotosOrFreshFormValidation() throws {
        let owner = UUID()
        var draft = SipDraft(ownerUserID: owner, context: .home, locationName: "Home", drinkName: "Latte", overallScore: 4, socialCaption: "Fixture", visibility: .friends)
        let suite = "PublicationRegression-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = PendingVisitSubmissionStore(defaults: defaults, baseDirectory: directory)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        var pending = try store.prepare(
            visitId: draft.id, userId: owner, cafe: nil, entryContext: .home,
            locationName: "Home", drinkType: .coffee, customDrinkType: nil,
            drinkSubtype: "Latte", caption: "Fixture", notes: nil,
            visibility: .friends, ratings: [:], overallScore: 4,
            ratingTemplate: RatingTemplate(), images: [image], posterPhotoIndex: 0
        )
        pending.phase = .photosUploaded
        pending.uploadedPhotoURLs = ["fixture-reference"]
        pending.completedPhotoObjectPaths = pending.objectPaths
        let photoFile = directory.appendingPathComponent("v2/users/\(owner.uuidString.lowercased())/\(pending.id.uuidString.lowercased())/\(pending.localPhotoNames[0])")
        try FileManager.default.removeItem(at: photoFile)
        #expect(try store.loadUploadImages(for: pending).first! == nil)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) != nil)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: pending, authenticatedUserID: owner) == nil)
        draft.socialCaption = ""
        pending.remoteFinalizedAt = .now
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: pending, authenticatedUserID: owner) == nil)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: pending, authenticatedUserID: UUID()) != nil)
    }

    @Test func sharedValidationExplainsEveryBoundaryInsteadOfSilentlyDisablingPublish() {
        let owner = UUID()
        var draft = SipDraft(ownerUserID: owner, context: .elsewhere, locationName: "Train", drinkName: "Tea", overallScore: 0.5, socialCaption: "Fixture", visibility: .friends, photoFallback: .mugsyMissedPhoto)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) == nil)
        draft.overallScore = .nan
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) != nil)
        draft.overallScore = 4
        draft.privateNotes = String(repeating: "x", count: 10_001)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner)?.contains("10,000") == true)
        draft.privateNotes = ""
        draft.socialCaption = ""
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) == SipCaptionValidationError.required.localizedDescription)
    }

    @MainActor @Test func publicationGateRejectsRepeatedTapsAndConcurrentRecoveryUntilReleased() {
        let gate = SipPublicationGate()
        let owner = UUID(), visit = UUID()
        let token = gate.begin(userID: owner, visitID: visit)
        #expect(token != nil)
        #expect(gate.begin(userID: owner, visitID: visit) == nil)
        gate.finish(token: UUID())
        #expect(gate.begin(userID: owner, visitID: visit) == nil)
        gate.finish(token: token!)
        #expect(gate.begin(userID: owner, visitID: visit) != nil)
    }

    @MainActor @Test func existingProviderCafeDoesNotDependOnVerificationBeingOnline() async throws {
        let fixture = makeClient()
        defer { fixture.session.invalidateAndCancel() }
        PublicationFixtureProtocol.reset()
        let cafe = Cafe(name: "Synthetic cafe", appleMapsPlaceID: "I123")
        let result = try await CafeService(client: fixture.client).findOrCreateCafe(from: cafe)
        #expect(result.id == PublicationFixtureProtocol.cafeID)
        #expect(!PublicationFixtureProtocol.paths.contains { $0.contains("verify-cafe") })
    }

    @MainActor @Test func newCafeVerificationOutageIsExplicitAndNeverFallsBackToUnverifiedInsert() async {
        let fixture = makeClient()
        defer { fixture.session.invalidateAndCancel() }
        PublicationFixtureProtocol.reset()
        PublicationFixtureProtocol.setCatalogAvailable(false)
        do {
            _ = try await CafeService(client: fixture.client).findOrCreateCafe(from: Cafe(name: "Synthetic cafe", appleMapsPlaceID: "I123"))
            Issue.record("New cafe must remain unverified during outage")
        } catch {
            #expect(error as? CafeVerificationError == .unavailable)
            #expect(MugshotAnalyticsErrorCode(error: error) == .remoteService)
            #expect(MugshotUserFacingError.message(for: error, context: .sipSave).contains("verify this cafe"))
        }
        #expect(PublicationFixtureProtocol.paths.filter { $0.contains("verify-cafe") }.count == 1)
    }

    @Test func publishingFailureTelemetryIncludesOnlyBoundedStageAndClassifiedReason() {
        let snapshot = MugshotSipAnalyticsSnapshot(draft: SipDraft(), photoCount: 0, isDraftResume: false)
        let payload = MugshotAnalyticsEvent.sipPublishFailed(snapshot, errorCode: .remoteService, recoveryState: .protectedRetry, operation: .creatingVisit).payload
        #expect(payload.properties["publication_stage"] == .string("creatingVisit"))
        #expect(payload.properties["error_code"] == .string("remote_service"))
        #expect(!payload.properties.keys.contains("visit_id"))
    }

    @MainActor @Test func publicationClientNeverBorrowsTheNextAccountsToken() async throws {
        let fixture = makeClient()
        defer { fixture.session.invalidateAndCancel() }
        PublicationFixtureProtocol.reset()
        let owner = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let ownerToken = token("owner")
        let nextToken = token("next")
        _ = try await fixture.client.auth.setSession(accessToken: ownerToken, refreshToken: "synthetic-refresh")
        let bound = SupabaseClientProvider.makePublicationClient(
            configuration: SupabaseConfiguration(url: URL(string: "https://publication-fixture.invalid")!, publishableKey: "synthetic-key"),
            source: fixture.client, userID: owner, session: fixture.session
        )
        let _: [SupabaseCafeSummary] = try await bound.from("cafes").select().execute().value
        #expect(PublicationFixtureProtocol.authorizations.last == "Bearer \(ownerToken)")
        try await fixture.client.auth.signOut(scope: .local)
        // A subsequent account must never be used by the old publication.
        PublicationFixtureProtocol.activeUserID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        _ = try await fixture.client.auth.setSession(accessToken: nextToken, refreshToken: "synthetic-next-refresh")
        _ = try? await bound.from("cafes").select().execute()
        #expect(PublicationFixtureProtocol.authorizations.last == "Bearer mugshot-invalid-publication-session")
        #expect(PublicationFixtureProtocol.authorizations.last != "Bearer \(nextToken)")
    }

    @MainActor @Test func acknowledgedPhotoCanFinishWithoutItsLocalBytesAndCancelledEmptyUploadCannotSucceed() async throws {
        let fixture = makeClient()
        defer { fixture.session.invalidateAndCancel() }
        PublicationFixtureProtocol.reset()
        let owner = UUID(), visit = UUID()
        let path = VisitPhotoUploadPlan.objectPath(userId: owner, visitId: visit, objectId: UUID())
        let service = VisitPhotoUploadService(client: fixture.client)
        let result = try await service.uploadPlannedPhotos(
            userId: owner, visitId: visit, images: [nil], posterPhotoIndex: 0,
            plannedObjectPaths: [path], completedObjectPaths: [path], onPhotoUploaded: { _ in Issue.record("Must not re-upload") }
        )
        #expect(result.objectPaths == [path])
        #expect(PublicationFixtureProtocol.paths.isEmpty)
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.uploadPhotos(userId: owner, visitId: visit, images: [], posterPhotoIndex: 0)
        }
        do { _ = try await task.value; Issue.record("Cancelled upload must not report success") }
        catch { #expect(error is CancellationError) }
    }

    private func token(_ label: String) -> String {
        let payload = Data("{\"exp\":\(Date().timeIntervalSince1970 + 3600)}".utf8)
            .base64EncodedString().replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        return "e30.\(payload).synthetic-\(label)"
    }

    private func makeClient() -> (client: SupabaseClient, session: URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicationFixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        return (SupabaseClient(
            supabaseURL: URL(string: "https://publication-fixture.invalid")!, supabaseKey: "synthetic-key",
            options: .init(auth: .init(storage: PublicationMemoryAuthStorage(), autoRefreshToken: false, emitLocalSessionAsInitialSession: true), global: .init(session: session))
        ), session)
    }

    @MainActor @Test func editUploadReceiptsSurviveServiceReloadAndStayAccountAndVisitScoped() throws {
        let suite = "EditPublicationRegression-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = UUID(), visit = UUID()
        let paths = VisitPhotoUploadPlan.objectPaths(userId: owner, visitId: visit, objectIds: [UUID(), UUID()])
        let store = VisitEditMediaProgressStore(defaults: defaults)
        try store.record(paths[0], userID: owner, visitID: visit, plannedPaths: paths)
        let restored = VisitEditMediaProgressStore(defaults: defaults)
        #expect(restored.completedPaths(userID: owner, visitID: visit, plannedPaths: paths) == [paths[0]])
        #expect(restored.completedPaths(userID: UUID(), visitID: visit, plannedPaths: paths).isEmpty)
        #expect(restored.completedPaths(userID: owner, visitID: UUID(), plannedPaths: paths).isEmpty)
        #expect(throws: VisitPhotoUploadError.invalidUploadPlan) {
            try restored.record(paths[0], userID: UUID(), visitID: visit, plannedPaths: paths)
        }
        restored.remove(userID: owner, visitID: visit)
        #expect(restored.completedPaths(userID: owner, visitID: visit, plannedPaths: paths).isEmpty)
    }

    @Test func publicationValidationCoversRequiredContextScoresAndBoundaryNotes() {
        let owner = UUID()
        let draft = SipDraft(ownerUserID: owner, context: .cafe, cafe: Cafe(name: "Fixture cafe"), drinkName: "Tea", overallScore: 4, socialCaption: "Fixture", visibility: .friends, contextScore: 1, photoFallback: .mugsyMissedPhoto)
        #expect(SipPublicationValidation.message(for: draft, photoCount: 0, pending: nil, authenticatedUserID: owner) == nil)
        var invalid = draft
        invalid.contextScore = 0.5
        #expect(SipPublicationValidation.message(for: invalid, photoCount: 0, pending: nil, authenticatedUserID: owner)?.contains("cafe score") == true)
        invalid = draft
        invalid.captureMode = .addDetails
        #expect(SipPublicationValidation.message(for: invalid, photoCount: 0, pending: nil, authenticatedUserID: owner)?.contains("Tasting Lens") == true)
        invalid = draft
        invalid.contextNotes = String(repeating: "x", count: 10_001)
        #expect(SipPublicationValidation.message(for: invalid, photoCount: 0, pending: nil, authenticatedUserID: owner)?.contains("context journal") == true)
        invalid = draft
        invalid.socialCaption = String(repeating: "x", count: 1_001)
        #expect(SipPublicationValidation.message(for: invalid, photoCount: 0, pending: nil, authenticatedUserID: owner) == SipCaptionValidationError.tooLong(maximum: 1_000).localizedDescription)
    }

    @Test func uploadPlanRejectsMissingDuplicateAndForeignAccountPhotos() throws {
        let owner = UUID(), visit = UUID()
        let paths = VisitPhotoUploadPlan.objectPaths(userId: owner, visitId: visit, objectIds: [UUID(), UUID()])
        try VisitPhotoUploadPlan.validate(userID: owner, visitID: visit, imageCount: 2, paths: paths, completedPaths: [])
        #expect(throws: VisitPhotoUploadError.invalidUploadPlan) {
            try VisitPhotoUploadPlan.validate(userID: owner, visitID: visit, imageCount: 0, paths: paths, completedPaths: [])
        }
        #expect(throws: VisitPhotoUploadError.invalidUploadPlan) {
            try VisitPhotoUploadPlan.validate(userID: owner, visitID: visit, imageCount: 2, paths: [paths[0], paths[0]], completedPaths: [])
        }
        #expect(throws: VisitPhotoUploadError.invalidUploadPlan) {
            try VisitPhotoUploadPlan.validate(userID: UUID(), visitID: visit, imageCount: 2, paths: paths, completedPaths: [])
        }
    }
}

private final class PublicationMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; values[key] = value }
    func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
    func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; values[key] = nil }
}

private final class PublicationFixtureProtocol: URLProtocol, @unchecked Sendable {
    static let cafeID = UUID(uuidString: "00000000-0000-4000-8000-000000000099")!
    private static let lock = NSLock()
    private static var recordedPaths: [String] = []
    private static var catalogAvailable = true
    static func setCatalogAvailable(_ value: Bool) { lock.lock(); defer { lock.unlock() }; catalogAvailable = value }
    private static var recordedAuthorizations: [String] = []
    static var activeUserID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    static var paths: [String] { lock.lock(); defer { lock.unlock() }; return recordedPaths }
    static var authorizations: [String] { lock.lock(); defer { lock.unlock() }; return recordedAuthorizations }
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        recordedPaths = []; recordedAuthorizations = []; catalogAvailable = true
        activeUserID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "publication-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        Self.lock.lock()
        Self.recordedPaths.append(path)
        Self.recordedAuthorizations.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
        let userID = Self.activeUserID
        let hasCafe = Self.catalogAvailable
        Self.lock.unlock()
        let status: Int
        let body: String
        if path.contains("verify-cafe") {
            status = 503; body = "{\"error\":\"verification unavailable\"}"
        } else if path.contains("/auth/v1/user") {
            status = 200
            body = "{\"id\":\"\(userID.uuidString)\",\"aud\":\"authenticated\",\"role\":\"authenticated\",\"app_metadata\":{},\"user_metadata\":{},\"created_at\":\"2026-10-30T00:00:00Z\",\"updated_at\":\"2026-10-30T00:00:00Z\"}"
        } else {
            status = 200
            body = hasCafe ? "[{\"id\":\"\(Self.cafeID.uuidString)\",\"name\":\"Synthetic cafe\",\"apple_maps_place_id\":\"I123\"}]" : "[]"
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
