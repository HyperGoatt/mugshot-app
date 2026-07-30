import Foundation
import Supabase

/// A durable database value for a Storage object.
///
/// Mugshot stores this reference instead of a signed URL because signed URLs
/// expire. The current viewer resolves it through Supabase Storage, where RLS
/// decides whether that viewer can read the visit at that moment.
struct VisitPhotoStorageReference: Equatable, Hashable {
    static let scheme = "mugshot-storage"
    static let legacyPublicBucketName = "visit-photos"
    static let privateBucketName = "visit-photos-private"

    let bucketName: String
    let objectPath: String

    init?(bucketName: String, objectPath: String) {
        guard bucketName == Self.privateBucketName,
              let normalizedPath = Self.normalizedObjectPath(objectPath) else {
            return nil
        }
        self.bucketName = bucketName
        self.objectPath = normalizedPath
    }

    init?(storedValue: String) {
        guard let components = URLComponents(string: storedValue),
              components.scheme?.lowercased() == Self.scheme,
              let bucketName = components.host?.lowercased(),
              components.query == nil,
              components.fragment == nil else {
            return nil
        }
        let encodedPath = components.percentEncodedPath
        let pathStart = encodedPath.hasPrefix("/")
            ? encodedPath.index(after: encodedPath.startIndex)
            : encodedPath.startIndex
        guard let decodedPath = String(encodedPath[pathStart...]).removingPercentEncoding else {
            return nil
        }
        self.init(bucketName: bucketName, objectPath: decodedPath)
    }

    var storedValue: String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        let encodedSegments = objectPath.split(separator: "/", omittingEmptySubsequences: false)
            .compactMap { String($0).addingPercentEncoding(withAllowedCharacters: allowed) }
        return "\(Self.scheme)://\(bucketName)/\(encodedSegments.joined(separator: "/"))"
    }

    private static func normalizedObjectPath(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count >= 3,
              segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }
        return segments.joined(separator: "/")
    }
}

struct VisitPhotoStorageLocation: Equatable, Hashable {
    let bucketName: String
    let objectPath: String

    var cleanupIdentifier: String {
        if let reference = VisitPhotoStorageReference(
            bucketName: bucketName,
            objectPath: objectPath
        ) {
            return reference.storedValue
        }
        // Version-one cleanup queues stored only the legacy public-bucket path.
        return objectPath
    }

    init(bucketName: String, objectPath: String) {
        self.bucketName = bucketName
        self.objectPath = objectPath
    }

    init?(storedValue: String) {
        if let reference = VisitPhotoStorageReference(storedValue: storedValue) {
            self.init(bucketName: reference.bucketName, objectPath: reference.objectPath)
            return
        }

        guard let url = URL(string: storedValue) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let bucketIndex = components.firstIndex(
            of: VisitPhotoStorageReference.legacyPublicBucketName
        ), bucketIndex >= 4,
              Array(components[(bucketIndex - 4)..<bucketIndex]) == [
                "storage", "v1", "object", "public"
              ],
              bucketIndex + 1 < components.count else {
            return nil
        }
        let path = components[(bucketIndex + 1)...]
            .joined(separator: "/")
            .removingPercentEncoding
        guard let path, !path.isEmpty else { return nil }
        self.init(
            bucketName: VisitPhotoStorageReference.legacyPublicBucketName,
            objectPath: path
        )
    }

    init?(cleanupIdentifier: String) {
        if let reference = VisitPhotoStorageReference(storedValue: cleanupIdentifier) {
            self.init(bucketName: reference.bucketName, objectPath: reference.objectPath)
            return
        }
        guard !cleanupIdentifier.isEmpty else { return nil }
        self.init(
            bucketName: VisitPhotoStorageReference.legacyPublicBucketName,
            objectPath: cleanupIdentifier
        )
    }
}

actor VisitPhotoAccessService {
    static let shared = VisitPhotoAccessService()

    private struct SignedURLCacheEntry {
        let url: URL
        let refreshAfter: Date
    }

    private let signedURLLifetimeSeconds = 300
    private let signedURLRefreshSeconds: TimeInterval = 240
    private var signedURLCache: [String: SignedURLCacheEntry] = [:]

    func resolvedURL(for storedValue: String) async throws -> URL {
        guard let privateReference = VisitPhotoStorageReference(storedValue: storedValue) else {
            guard let publicURL = URL(string: storedValue),
                  let scheme = publicURL.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                throw VisitPhotoAccessError.invalidReference
            }
            // Historical photos already carry durable public-bucket URLs.
            // Re-signing them adds an authenticated request that can race a
            // sign-out even though the object itself remains publicly readable.
            return publicURL
        }
        let location = VisitPhotoStorageLocation(
            bucketName: privateReference.bucketName,
            objectPath: privateReference.objectPath
        )

        let client = try SupabaseClientProvider.shared.client()
        let accountScope = client.auth.currentUser?.id.uuidString.lowercased() ?? "anon"
        let cacheKey = "\(accountScope)|\(location.cleanupIdentifier)"
        if let cached = signedURLCache[cacheKey], cached.refreshAfter > Date() {
            return cached.url
        }

        signedURLCache = signedURLCache.filter { $0.value.refreshAfter > Date() }
        let signedURL = try await client.storage
            .from(location.bucketName)
            .createSignedURL(
                path: location.objectPath,
                expiresIn: signedURLLifetimeSeconds
            )
        signedURLCache[cacheKey] = SignedURLCacheEntry(
            url: signedURL,
            refreshAfter: Date().addingTimeInterval(signedURLRefreshSeconds)
        )
        return signedURL
    }
}

enum VisitPhotoAccessError: LocalizedError, Equatable {
    case invalidReference

    var errorDescription: String? {
        switch self {
        case .invalidReference:
            return "This photo reference is invalid."
        }
    }
}
