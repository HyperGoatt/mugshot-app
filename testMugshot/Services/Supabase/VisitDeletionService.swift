import Foundation
import Supabase

enum VisitPhotoObjectPath {
    static let bucketName = VisitPhotoStorageReference.legacyPublicBucketName

    static func path(fromPublicURL value: String) -> String? {
        VisitPhotoStorageLocation(storedValue: value)?.objectPath
    }

    static func location(fromStoredValue value: String) -> VisitPhotoStorageLocation? {
        VisitPhotoStorageLocation(storedValue: value)
    }
}

final class VisitMediaCleanupStore {
    static let shared = VisitMediaCleanupStore()

    private let defaults: UserDefaults
    private let keyPrefix = "MugshotVisitMediaCleanup.v1."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func pendingPaths(userId: UUID) -> [String] {
        pendingLocations(userId: userId).map(\.objectPath)
    }

    func pendingLocations(userId: UUID) -> [VisitPhotoStorageLocation] {
        (defaults.stringArray(forKey: key(userId)) ?? [])
            .compactMap(VisitPhotoStorageLocation.init(cleanupIdentifier:))
    }

    func enqueue(_ paths: [String], userId: UUID) {
        enqueue(
            paths.map {
                VisitPhotoStorageLocation(
                    bucketName: VisitPhotoStorageReference.legacyPublicBucketName,
                    objectPath: $0
                )
            },
            userId: userId
        )
    }

    func enqueue(_ locations: [VisitPhotoStorageLocation], userId: UUID) {
        let merged = Set(pendingLocations(userId: userId))
            .union(locations)
            .map(\.cleanupIdentifier)
            .sorted()
        defaults.set(merged, forKey: key(userId))
    }

    func remove(_ paths: [String], userId: UUID) {
        remove(
            paths.map {
                VisitPhotoStorageLocation(
                    bucketName: VisitPhotoStorageReference.legacyPublicBucketName,
                    objectPath: $0
                )
            },
            userId: userId
        )
    }

    func remove(_ locations: [VisitPhotoStorageLocation], userId: UUID) {
        let remaining = Set(pendingLocations(userId: userId))
            .subtracting(locations)
        if remaining.isEmpty {
            defaults.removeObject(forKey: key(userId))
        } else {
            defaults.set(
                remaining.map(\.cleanupIdentifier).sorted(),
                forKey: key(userId)
            )
        }
    }

    func removeAll(userId: UUID) {
        defaults.removeObject(forKey: key(userId))
    }

    private func key(_ userId: UUID) -> String {
        keyPrefix + userId.uuidString.lowercased()
    }
}

final class VisitDeletionService {
    private let client: SupabaseClient
    private let visitService: VisitService
    private let photoService: VisitPhotoUploadService
    private let cleanupStore: VisitMediaCleanupStore

    init(
        client: SupabaseClient,
        cleanupStore: VisitMediaCleanupStore = .shared
    ) {
        self.client = client
        visitService = VisitService(client: client)
        photoService = VisitPhotoUploadService(client: client)
        self.cleanupStore = cleanupStore
    }

    func deleteVisit(visitId: UUID, userId: UUID, knownPhotoURLs: [String] = []) async throws {
        guard client.auth.currentUser?.id == userId else { throw VisitServiceError.accountScopeChanged }
        let deletedPhotoURLs: [String]
        do {
            deletedPhotoURLs = try await visitService.deleteOwnedVisit(visitId: visitId)
        } catch let error as PostgrestError where VisitDeletionAcknowledgment.isAlreadyAbsent(
            code: error.code, message: error.message, currentOwner: client.auth.currentUser?.id, expectedOwner: userId) {
            // A committed delete whose response was lost is safe to acknowledge
            // on retry. Authentication/authorization/network errors remain errors.
            let exactPrefix = userId.uuidString.lowercased() + "/" + visitId.uuidString.lowercased() + "/"
            deletedPhotoURLs = knownPhotoURLs.filter {
                VisitPhotoObjectPath.location(fromStoredValue: $0)?.objectPath.lowercased().hasPrefix(exactPrefix) == true
            }
        }
        let ownerPrefix = userId.uuidString.lowercased() + "/"
        let locations = deletedPhotoURLs
            .compactMap { VisitPhotoObjectPath.location(fromStoredValue: $0) }
            .filter { $0.objectPath.lowercased().hasPrefix(ownerPrefix) }

        // The RPC has already committed the journal deletion. Storage cleanup
        // remains durable and retried separately if object removal fails.
        guard !locations.isEmpty else { return }

        do {
            try await photoService.deletePhotos(at: locations)
            cleanupStore.remove(locations, userId: userId)
        } catch {
            cleanupStore.enqueue(locations, userId: userId)
        }
    }

    func retryPendingMediaCleanup(userId: UUID) async {
        let locations = cleanupStore.pendingLocations(userId: userId)
        guard !locations.isEmpty else { return }
        do {
            try await photoService.deletePhotos(at: locations)
            cleanupStore.remove(locations, userId: userId)
        } catch {
            // The queue remains account-scoped for the next launch.
        }
    }
}

enum VisitDeletionAcknowledgment {
    static func isAlreadyAbsent(code: String?, message: String, currentOwner: UUID?, expectedOwner: UUID) -> Bool {
        currentOwner == expectedOwner && code == "P0002" && message == "visit not found"
    }
}
