import Foundation
import UIKit
import Testing
@testable import testMugshot

struct ProtectedImageStoreTests {
    actor Transport {
        var authorizations = 0
        var downloads = 0
        var denied = false
        func resolve(_ value: String) async throws -> URL {
            authorizations += 1
            try await Task.sleep(for: .milliseconds(10))
            if denied { throw URLError(.noPermissionsToReadFile) }
            return URL(string: "https://example.invalid/image?token=\(authorizations)")!
        }
        func download(_ url: URL) -> UIImage { downloads += 1; return UIImage() }
        func deny() { denied = true }
    }
    @Test func coalescesPixelsButRenewsAuthorizationAndClearsDeniedAccess() async throws {
        let transport = Transport()
        let store = ProtectedImageStore(resolve: { try await transport.resolve($0) }, download: { await transport.download($0) })
        async let first = store.load("object-v1", account: "A")
        async let duplicate = store.load("object-v1", account: "A")
        _ = try await (first, duplicate)
        _ = try await store.load("object-v1", account: "A")
        #expect(await transport.downloads == 1)
        #expect(await transport.authorizations == 1)
        _ = try await store.load("object-v1", account: "A", renew: true)
        #expect(await transport.downloads == 1)
        #expect(await transport.authorizations == 2)
        _ = try await store.load("object-v1", account: "B")
        #expect(await transport.downloads == 2)
        await transport.deny()
        await #expect(throws: URLError.self) { try await store.load("object-v1", account: "B", renew: true) }
        await #expect(throws: URLError.self) { try await store.load("object-v1", account: "B") }
        #expect(await transport.downloads == 2)
        #expect(await transport.authorizations == 5)
    }
}
