import Foundation
import Supabase
import Testing
@testable import testMugshot

@MainActor
@Suite(.serialized)
struct MugsyReminderTests {
    private let owner = UUID(uuidString: "00000000-0000-4000-8000-000000008101")!
    private let now = Date(timeIntervalSince1970: 1_795_600_000)

    @Test func consentDefaultsOffAndDaytimeBoundariesAreExplicit() {
        var preferences = MugsyReminderPreferences()
        #expect(!preferences.mugsyEnabled)
        #expect(preferences.pace.weeklyLimit == 3)
        #expect(preferences.preferredMinute == 660)
        #expect(preferences.timingIsValid)
        preferences.preferredMinute = 1140
        #expect(!preferences.timingIsValid)
        preferences.preferredMinute = 540
        #expect(preferences.timingIsValid)
        preferences.windowStartMinute = 1140
        preferences.windowEndMinute = 540
        #expect(!preferences.timingIsValid)
        preferences.pausedUntil = now.addingTimeInterval(1)
        #expect(preferences.isPaused(at: now))
        #expect(!preferences.isPaused(at: now.addingTimeInterval(2)))
        preferences.pausedIndefinitely = true
        #expect(preferences.isPaused(at: now.addingTimeInterval(100_000)))
    }

    @Test func intentRejectsMalformedExpiredAndUnsupportedPayloads() throws {
        let payload = makePayload(link: "mugshot://mugsy/log")
        #expect(MugsyNotificationIntent.resolve(userInfo: payload, now: now)?.destination == .log)
        #expect(MugsyNotificationIntent.resolve(userInfo: payload, now: now.addingTimeInterval(7200)) == nil)
        #expect(MugsyNotificationIntent.resolve(userInfo: makePayload(link: "https://example.invalid/log"), now: now) == nil)
        #expect(MugsyNotificationIntent.resolve(userInfo: makePayload(link: "mugshot://mugsy/unknown"), now: now) == nil)
        var missingOwner = try #require(payload["mugshot_mugsy"] as? [String: Any])
        missingOwner.removeValue(forKey: "recipient_id")
        #expect(MugsyNotificationIntent.resolve(userInfo: ["mugshot_mugsy": missingOwner], now: now) == nil)
        missingOwner["recipient_id"] = owner.uuidString
        missingOwner["version"] = 2
        #expect(MugsyNotificationIntent.resolve(userInfo: ["mugshot_mugsy": missingOwner], now: now) == nil)
    }

    @Test func weeklyIntentKeepsOriginalWindowAndNearbyRequiresAnOwner() throws {
        let end = "2026-11-22T23:00:00Z"
        let intent = try #require(MugsyNotificationIntent.resolve(
            userInfo: makePayload(link: "mugshot://mugsy/weekly?end=\(end)"), now: now))
        let endDate = try #require(MugsyNotificationIntent.parseDate(end))
        #expect(intent.destination == .weekly(endDate))
        let cafe = UUID()
        #expect(NearbyCafeNotificationRoute.resolve(userInfo: ["nearby_cafe_id": cafe.uuidString]) == nil)
        let route = try #require(NearbyCafeNotificationRoute.resolve(userInfo: [
            "nearby_cafe_id": cafe.uuidString, "nearby_account_id": owner.uuidString]))
        #expect(route.cafeID == cafe && route.accountID == owner)
    }

    @Test func actualPreferenceRPCSendsExplicitNullPauseAndIdempotencyFields() async throws {
        let (client, session) = try await makeClient()
        defer { session.invalidateAndCancel() }
        var preferences = MugsyReminderPreferences()
        preferences.mugsyEnabled = true
        preferences.timezoneName = "America/New_York"
        preferences.revision = 7
        let requestID = UUID()
        let saved = try await MugsyReminderService(client: client, accountID: owner).save(preferences, requestID: requestID)
        #expect(saved.revision == 8)
        let request = try #require(MugsyWireProtocol.requests.last { $0.url?.path.hasSuffix("set_mugsy_preferences_v1") == true })
        #expect(request.value(forHTTPHeaderField: "x-mugshot-account-id") == owner.uuidString.lowercased())
        let object = try #require(try JSONSerialization.jsonObject(with: Self.body(of: request)) as? [String: Any])
        #expect(object["p_paused_until"] is NSNull)
        #expect(object["p_paused_indefinitely"] as? Bool == false)
        #expect(object["p_mugsy_enabled"] as? Bool == true)
        #expect(object["p_expected_revision"] as? Int == 7)
        #expect((object["p_request_id"] as? String)?.lowercased() == requestID.uuidString.lowercased())
        #expect(object["p_timezone_name"] as? String == "America/New_York")
        #expect(object.keys.count == 10)
    }

    @Test func missingAuthorizedOccurrenceIsTerminalAndWrongOwnerNeverCallsRPC() async throws {
        let (client, session) = try await makeClient()
        defer { session.invalidateAndCancel() }
        let intent = MugsyNotificationIntent(accountID: owner, occurrenceID: UUID(), destination: .journal,
            expiresAt: Date.now.addingTimeInterval(3600))
        #expect(try await MugsyReminderService(client: client, accountID: owner).authorize(intent) == false)
        let before = MugsyWireProtocol.requests.count
        await #expect(throws: CancellationError.self) {
            _ = try await MugsyReminderService(client: client, accountID: UUID()).fetch()
        }
        #expect(MugsyWireProtocol.requests.count == before)
    }

    @Test func accountErasurePurgesNearbyFactsWithoutChangingAnotherOwnerOrLegacyState() throws {
        let suite = "MugsyNearbyErasure.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let otherOwner = UUID()
        let erasedKeys = ["enabled", "lastDaily", "lastByCafe"].map {
            "MugshotNearbyReminders.\($0).v2.\(owner.uuidString)"
        }
        let otherKey = "MugshotNearbyReminders.lastByCafe.v2.\(otherOwner.uuidString)"
        let legacyKey = "MugshotNearbyReminders.enabled.v1"
        erasedKeys.forEach { defaults.set(Data("owned state".utf8), forKey: $0) }
        let preserved = Data("another owner’s state".utf8)
        defaults.set(preserved, forKey: otherKey)
        defaults.set(true, forKey: legacyKey)
        NearbyCafeReminderCoordinator.eraseAccountPreferences(accountID: owner, defaults: defaults)
        #expect(erasedKeys.allSatisfy { defaults.object(forKey: $0) == nil })
        #expect(defaults.data(forKey: otherKey) == preserved)
        #expect(defaults.bool(forKey: legacyKey))
    }

    private func makePayload(link: String) -> [AnyHashable: Any] {
        ["mugshot_mugsy": ["version": 1, "recipient_id": owner.uuidString,
            "occurrence_id": UUID().uuidString, "deep_link": link,
            "expires_at": now.addingTimeInterval(3600).ISO8601Format()]]
    }

    private func makeClient() async throws -> (SupabaseClient, URLSession) {
        MugsyWireProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MugsyWireProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = SupabaseClient(supabaseURL: URL(string: "https://mugsy-wire.invalid")!,
            supabaseKey: "synthetic-key", options: .init(
                auth: .init(storage: MugsyWireStorage(), autoRefreshToken: false, emitLocalSessionAsInitialSession: true),
                global: .init(session: session)))
        _ = try await AuthService(client: client).signIn(email: "mugsy@example.invalid", password: "synthetic-password")
        return (client, session)
    }

    private static func body(of request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var result = Data(); var bytes = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&bytes, maxLength: bytes.count)
            if count <= 0 { break }
            result.append(bytes, count: count)
        }
        return result
    }
}

private final class MugsyWireStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; values[key] = value }
    func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
    func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key) }
}

private final class MugsyWireProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var recorded: [URLRequest] = []
    static var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return recorded }
    static func reset() { lock.lock(); defer { lock.unlock() }; recorded = [] }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "mugsy-wire.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.recorded.append(request); Self.lock.unlock()
        let text: String
        if request.url!.path.contains("/auth/") {
            text = """
            {"access_token":"synthetic-token","refresh_token":"synthetic-refresh","token_type":"bearer","expires_in":3600,"expires_at":\(Date.now.timeIntervalSince1970 + 3600),"user":{"id":"00000000-0000-4000-8000-000000008101","aud":"authenticated","role":"authenticated","email":"mugsy@example.invalid","app_metadata":{"provider":"email"},"user_metadata":{},"created_at":"2026-11-01T00:00:00Z","updated_at":"2026-11-01T00:00:00Z","identities":[]}}
            """
        } else if request.url!.path.hasSuffix("get_mugsy_notification_intent_v1") {
            text = "null"
        } else {
            text = """
            {"mugsy_enabled":true,"pace":"standard","preferred_minute":660,"window_start_minute":540,"window_end_minute":1140,"timezone_name":"America/New_York","paused_until":null,"paused_indefinitely":false,"revision":8,"consent_version":1,"holdout":false,"delivery_mode":"shadow"}
            """
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
