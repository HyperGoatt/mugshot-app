import Foundation
import Supabase
import Testing
@testable import testMugshot

struct AuthSessionIdentityTests {
    @MainActor @Test func successfulSignInRetainsTheSameCurrentIdentity() async throws {
        let storage = KeychainLocalStorage(service: "co.mugshot.synthetic-auth-regression")
        let key = "identity-\(UUID().uuidString)"
        defer { try? storage.remove(key: key) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyntheticAuthResponseProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://auth-repair.invalid")!,
            supabaseKey: "synthetic-publishable-key",
            options: .init(
                auth: .init(storage: storage, storageKey: key, autoRefreshToken: false, emitLocalSessionAsInitialSession: true),
                global: .init(session: session)
            )
        )
        let service = AuthService(client: client)
        let user = try await service.signIn(email: "synthetic@example.invalid", password: "synthetic-password")
        #expect(user.id == UUID(uuidString: "00000000-0000-4000-8000-000000009999"))
        #expect(service.currentUserID == user.id)
        #expect(try storage.retrieve(key: key) != nil)
    }
}

private final class SyntheticAuthResponseProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "auth-repair.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let data = Data("""
        {"access_token":"synthetic-token","refresh_token":"synthetic-refresh","token_type":"bearer","expires_in":3600,"expires_at":\(Date().timeIntervalSince1970 + 3600),"user":{"id":"00000000-0000-4000-8000-000000009999","aud":"authenticated","role":"authenticated","email":"synthetic@example.invalid","app_metadata":{"provider":"email"},"user_metadata":{},"created_at":"2026-09-14T00:00:00Z","updated_at":"2026-09-14T00:00:00Z","identities":[]}}
        """.utf8)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
