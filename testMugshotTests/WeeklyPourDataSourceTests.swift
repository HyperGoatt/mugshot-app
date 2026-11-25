import Foundation
import Supabase
import SwiftUI
import Testing
@testable import testMugshot

@Suite(.serialized)
struct WeeklyPourDataSourceTests {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000007101")!
    private let window = WeeklyPourWindow(endingAt: ISO8601DateFormatter().date(from: "2026-11-22T23:00:00Z")!)

    @Test func privateHomeProjectionRequiresADurableSaveAndExcludesPublishedAttempts() throws {
        var draft = HomeAttemptRecord(name: "Unfinished draft")
        draft.privateNote = "Never exported"
        var saved = HomeAttemptRecord(name: "Morning filter")
        saved.savedAt = window.end.addingTimeInterval(-3600)
        saved.privateNote = "Never exported"
        saved.reaction = "A remembered morning"
        saved.photoNames = ["private.jpg"]
        var published = saved
        published.id = UUID()
        published.publicationStatus = .published
        var pendingPublication = saved
        pendingPublication.id = UUID()
        pendingPublication.publicationStatus = .failed
        let values = WeeklyPourDataSource.privateMoments([draft, saved, published, pendingPublication], ownerID: owner)
        #expect(values.count == 2)
        let projected = try #require(values.first)
        #expect(projected.date == saved.savedAt)
        #expect(projected.caption == saved.reaction)
        #expect(projected.photo == .local("private.jpg"))
        #expect(projected.isPrivate && projected.ownerID == owner && projected.isComplete)
        #expect(projected.recordedRating == nil)
    }

    @Test(arguments: ["private", "Private", "unknown", "", "friends", "Everyone"])
    func canonicalVisibilityFailsClosed(_ visibility: String) {
        let value = WeeklyPourDataSource.moment(summary(visibility: visibility))
        #expect(value.isPrivate == !["friends", "Everyone"].contains(visibility))
        #expect(value.caption == "Saved caption")
        #expect(value.ownerID == owner)
        #expect(value.recordedRating == nil)
    }

    @Test func incompleteCanonicalAndLinkedHomeSaveCannotInflateAWeek() {
        let uploading = WeeklyPourDataSource.moment(summary(uploadState: "uploading"))
        #expect(WeeklyPourStory(ownerID: owner, window: window, candidates: [uploading]).moments.isEmpty)
        let remote = WeeklyPourDataSource.moment(summary())
        var home = HomeAttemptRecord(name: "Morning filter")
        home.savedAt = remote.date
        home.publicationDraftID = remote.id
        let local = WeeklyPourDataSource.privateMoments([home], ownerID: owner)
        #expect(WeeklyPourStory(ownerID: owner, window: window, candidates: [remote] + local).moments.count == 1)
    }

    @MainActor @Test func keepsakeRendersARealPortableImage() throws {
        let summary = WeeklyPourShareSummary(window: window, momentCount: 5, cafeCount: 2, homeCount: 2)
        let renderer = ImageRenderer(content: WeeklyPourKeepsakeCard(summary: summary).frame(width: 340)
            .environment(\.dynamicTypeSize, .large).environment(\.colorScheme, .light))
        renderer.scale = 3
        let image = try #require(renderer.uiImage)
        #expect(image.size.width == 340)
        #expect(image.size.height > 250)
        #expect(image.pngData()?.isEmpty == false)
    }

    @Test func remoteReadPagesTheWholeWindowAndPreservesOwnerFilters() async throws {
        WeeklyPourReadProtocol.configure(owner: owner, failSecondPage: false)
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        let values = try await VisitService(client: client).fetchWeeklyPour(userID: owner, window: window)
        #expect(values.count == 201)
        let requests = WeeklyPourReadProtocol.requests.filter { $0.url?.path.hasSuffix("/visits") == true }
        #expect(requests.count == 2)
        for request in requests {
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(query.contains { $0.name == "user_id" && $0.value == "eq.\(owner.uuidString)" })
            #expect(query.contains { $0.name == "upload_state" && $0.value == "eq.complete" })
            #expect(query.contains { $0.name == "created_at" && $0.value == "gte.\(window.start.ISO8601Format())" })
            #expect(query.contains { $0.name == "created_at" && $0.value == "lt.\(window.end.ISO8601Format())" })
            #expect(!query.contains { $0.value?.contains("notes") == true })
        }
    }

    @Test func failedLaterPageFailsTheWeekRatherThanReturningAPartialStory() async throws {
        WeeklyPourReadProtocol.configure(owner: owner, failSecondPage: true)
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        await #expect(throws: Error.self) {
            try await VisitService(client: client).fetchWeeklyPour(userID: owner, window: window)
        }
    }

    private func summary(visibility: String = "private", uploadState: String = "complete") -> RemoteVisitSummary {
        RemoteVisitSummary(visit: SupabaseVisitRow(id: UUID(), userId: owner, cafeId: nil,
            drinkType: "Coffee", drinkTypeCustom: nil, drinkSubtype: "Filter coffee",
            caption: "Saved caption", notes: "Never projected", visibility: visibility,
            uploadState: uploadState, ratings: [:], overallScore: 0, posterPhotoURL: nil,
            contextType: "Home", locationName: "Home", cityState: nil, brewMethod: nil,
            createdAt: window.end.addingTimeInterval(-3600).ISO8601Format()), cafe: nil)
    }

    private func makeClient() -> (SupabaseClient, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WeeklyPourReadProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = SupabaseClient(supabaseURL: URL(string: "https://weekly-pour-tests.invalid")!,
            supabaseKey: "synthetic-public-key", options: .init(
                auth: .init(storage: WeeklyPourMemoryStorage(), autoRefreshToken: false, emitLocalSessionAsInitialSession: true),
                global: .init(session: session)))
        return (client, session)
    }
}

private final class WeeklyPourMemoryStorage: AuthLocalStorage, @unchecked Sendable {
    func store(key: String, value: Data) throws {}
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws {}
}

private final class WeeklyPourReadProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var owner = UUID()
    private static var failSecond = false
    private static var recorded: [URLRequest] = []
    static var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return recorded }
    static func configure(owner: UUID, failSecondPage: Bool) {
        lock.lock(); defer { lock.unlock() }
        self.owner = owner; failSecond = failSecondPage; recorded = []
    }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "weekly-pour-tests.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.recorded.append(request)
        let owner = Self.owner
        let fails = Self.failSecond
        Self.lock.unlock()
        let isVisit = request.url!.path.hasSuffix("/visits")
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let offset = Int(items.first { $0.name == "offset" }?.value ?? "0") ?? 0
        if isVisit, offset > 0, fails {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost)); return
        }
        let rows: [[String: Any]] = !isVisit ? [] : (0..<(offset == 0 ? 200 : 1)).map { index in
            ["id": String(format: "00000000-0000-0000-0000-%012d", offset + index + 1),
             "user_id": owner.uuidString, "drink_type": "Coffee", "caption": "",
             "visibility": "private", "upload_state": "complete", "ratings": [:] as [String: Double],
             "overall_score": 0, "context_type": "Home", "created_at": "2026-11-20T12:00:00Z"]
        }
        let data = try! JSONSerialization.data(withJSONObject: rows)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
