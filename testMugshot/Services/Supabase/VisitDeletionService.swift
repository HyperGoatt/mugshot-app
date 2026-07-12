import Foundation
import Supabase

enum VisitPhotoObjectPath {
    static let bucketName = "visit-photos"

    static func path(fromPublicURL value: String) -> String? {
        guard let url = URL(string: value) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let bucketIndex = components.firstIndex(of: bucketName),
              bucketIndex + 1 < components.count else {
            return nil
        }
        return components[(bucketIndex + 1)...]
            .joined(separator: "/")
            .removingPercentEncoding
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
        defaults.stringArray(forKey: key(userId)) ?? []
    }

    func enqueue(_ paths: [String], userId: UUID) {
        let merged = Set(pendingPaths(userId: userId)).union(paths)
        defaults.set(merged.sorted(), forKey: key(userId))
    }

    func remove(_ paths: [String], userId: UUID) {
        let remaining = Set(pendingPaths(userId: userId)).subtracting(paths)
        if remaining.isEmpty {
            defaults.removeObject(forKey: key(userId))
        } else {
            defaults.set(remaining.sorted(), forKey: key(userId))
        }
    }

    private func key(_ userId: UUID) -> String {
        keyPrefix + userId.uuidString.lowercased()
    }
}

final class VisitDeletionService {
    private let visitService: VisitService
    private let photoService: VisitPhotoUploadService
    private let cleanupStore: VisitMediaCleanupStore

    init(
        client: SupabaseClient,
        cleanupStore: VisitMediaCleanupStore = .shared
    ) {
        visitService = VisitService(client: client)
        photoService = VisitPhotoUploadService(client: client)
        self.cleanupStore = cleanupStore
    }

    func deleteVisit(visitId: UUID, userId: UUID) async throws {
        let photoRows = try await visitService.fetchVisitPhotoRows(visitId: visitId)
        let ownerPrefix = userId.uuidString.lowercased() + "/"
        let paths = photoRows
            .compactMap { VisitPhotoObjectPath.path(fromPublicURL: $0.photoURL) }
            .filter { $0.lowercased().hasPrefix(ownerPrefix) }

        // Delete the journal record first so a cleanup outage can never leave
        // a visible sip pointing at already-deleted media. Storage cleanup is
        // durable and retried separately if it fails.
        try await visitService.deleteVisit(visitId: visitId, userId: userId)
        guard !paths.isEmpty else { return }

        do {
            try await photoService.deletePhotos(at: paths)
            cleanupStore.remove(paths, userId: userId)
        } catch {
            cleanupStore.enqueue(paths, userId: userId)
        }
    }

    func retryPendingMediaCleanup(userId: UUID) async {
        let paths = cleanupStore.pendingPaths(userId: userId)
        guard !paths.isEmpty else { return }
        do {
            try await photoService.deletePhotos(at: paths)
            cleanupStore.remove(paths, userId: userId)
        } catch {
            // The queue remains account-scoped for the next launch.
        }
    }
}
