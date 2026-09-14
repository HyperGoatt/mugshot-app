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

/// Parses only this project's durable media references. This is separate from
/// deletion-path parsing so read compatibility cannot expand cleanup authority.
struct ProtectedStorageMediaLocation: Equatable {
    let bucketName: String
    let objectPath: String

    init?(storedValue: String, projectURL: URL) {
        if let reference = VisitPhotoStorageReference(storedValue: storedValue) {
            bucketName = reference.bucketName
            objectPath = reference.objectPath
            return
        }
        guard let components = URLComponents(string: storedValue),
              components.scheme == "https",
              components.host?.lowercased() == projectURL.host?.lowercased(),
              (components.port ?? 443) == (projectURL.port ?? 443),
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else { return nil }
        let prefix = "/storage/v1/object/public/"
        guard components.percentEncodedPath.hasPrefix(prefix),
              let path = String(components.percentEncodedPath.dropFirst(prefix.count)).removingPercentEncoding else { return nil }
        var parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty else { return nil }
        let bucket = parts.removeFirst()
        guard ["profile-media", "visit-photos", "visit-photos-private"].contains(bucket),
              parts.count >= (bucket == "profile-media" ? 2 : 3),
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
        bucketName = bucket
        objectPath = parts.joined(separator: "/")
    }
}

actor VisitPhotoAccessService {
    static let shared = VisitPhotoAccessService()

    func resolvedURL(for storedValue: String) async throws -> URL {
        let configuration = try SupabaseConfiguration.load()
        guard let location = ProtectedStorageMediaLocation(storedValue: storedValue, projectURL: configuration.url) else {
            guard let publicURL = URL(string: storedValue),
                  let scheme = publicURL.scheme?.lowercased(),
                  scheme == "https" || scheme == "http",
                  publicURL.user == nil, publicURL.password == nil else {
                throw VisitPhotoAccessError.invalidReference
            }
            // Keep foreign image compatibility without granting Storage access.
            // Malformed own-project public-object references must not bypass signing.
            if publicURL.host?.lowercased() == configuration.url.host?.lowercased(),
               publicURL.path.hasPrefix("/storage/v1/object/public/") {
                throw VisitPhotoAccessError.invalidReference
            }
            return publicURL
        }
        let client = try SupabaseClientProvider.shared.client()
        let accountID = client.auth.currentUser?.id
        // The pre-cutover server cannot sign profile-media reads. Only an exact
        // missing-API response permits legacy public URLs; auth/network errors
        // must never downgrade a protected read. Private references never fall back.
        if storedValue.hasPrefix("https://"),
           ["profile-media", "visit-photos"].contains(location.bucketName) {
            do {
                let permitted: Bool = try await client.rpc(
                    "can_read_protected_media_v1",
                    params: ["p_bucket": location.bucketName, "p_name": location.objectPath]
                ).execute().value
                guard permitted else { throw VisitPhotoAccessError.accessDenied }
            } catch let error as PostgrestError where
                error.code == "PGRST202" &&
                error.message.contains("public.can_read_protected_media_v1") {
                guard client.auth.currentUser?.id == accountID else {
                    throw VisitPhotoAccessError.accountScopeChanged
                }
                try Task.checkCancellation()
                guard let url = URL(string: storedValue) else {
                    throw VisitPhotoAccessError.invalidReference
                }
                return url
            }
        }
        // Every resolution rechecks Storage authorization; never reuse an old
        // signature after a privacy edit or account switch.
        let signedURL = try await client.storage
            .from(location.bucketName)
            .createSignedURL(path: location.objectPath, expiresIn: 60)
        guard client.auth.currentUser?.id == accountID else {
            throw VisitPhotoAccessError.accountScopeChanged
        }
        try Task.checkCancellation()
        return signedURL
    }
}

enum VisitPhotoAccessError: LocalizedError, Equatable {
    case invalidReference
    case accountScopeChanged
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .invalidReference:
            return "This photo reference is invalid."
        case .accessDenied:
            return "This photo is not available to your account."
        case .accountScopeChanged:
            return "Your account changed while loading this photo."
        }
    }
}
