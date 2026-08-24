import Foundation
import Supabase
import UIKit

enum OwnerDataExportCompleteness: String, Equatable {
    case complete
    case partial
}

struct OwnerDataExportPackage: Identifiable {
    let id = UUID()
    let directoryURL: URL
    let shareURLs: [URL]
    let packagedMediaCount: Int
    let unavailableMediaCount: Int
    let sourceSchemaVersion: Int
    let completeness: OwnerDataExportCompleteness
    let omittedCollections: [String]
}

protocol OwnerDataExportRemoteTransport: AnyObject {
    var currentUserID: UUID? { get }
    func fetchV2Export() async throws -> Data
    func fetchV1Export() async throws -> Data
    func fetchEnforcementExport() async throws -> Data
    func signedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL
}

private final class SupabaseOwnerDataExportRemoteTransport: OwnerDataExportRemoteTransport {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var currentUserID: UUID? { client.auth.currentUser?.id }

    func fetchV2Export() async throws -> Data {
        try await client.rpc("build_owner_data_export_v2").execute().data
    }

    func fetchV1Export() async throws -> Data {
        try await client.rpc("build_owner_data_export").execute().data
    }

    func fetchEnforcementExport() async throws -> Data {
        try await client.rpc("build_owner_enforcement_export_v1").execute().data
    }

    func signedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL {
        try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }
}

struct OwnerExportMediaReference: Hashable {
    enum Source: Hashable {
        case storage(bucket: String, path: String, access: String?)
        case remoteURL(URL)
    }

    let source: Source

    var preferredFileExtension: String? {
        switch source {
        case let .storage(_, path, _):
            return URL(fileURLWithPath: path).pathExtension.remoteTrimmedNonEmpty
        case let .remoteURL(url):
            return url.pathExtension.remoteTrimmedNonEmpty
        }
    }
}

final class OwnerDataExportService {
    static let allowedStorageBuckets: Set<String> = [
        "visit-photos",
        "visit-photos-private",
        "profile-media",
        "home-coffee-bag-photos"
    ]
    static let maximumMediaFileBytes: Int64 = 50 * 1_024 * 1_024
    static let maximumPackagedMediaBytes: Int64 = 500 * 1_024 * 1_024
    static let maximumMediaReferenceCount = 1_000
    static let v1OmittedCollections = [
        "V3 reflections",
        "cafe experience sessions",
        "social interactions",
        "safety report receipts",
        "enforcement decisions and appeal statements",
        "visit tags",
        "collaborative list memberships and contributions",
        "notification and device metadata",
        "structured private media references"
    ]

    private let remote: OwnerDataExportRemoteTransport
    private let pendingStore: PendingVisitSubmissionStore
    private let draftStore: SipDraftStore
    private let reportStore: SafetyReportReceiptStore
    private let appealStore: ModerationAppealReceiptStore
    private let homeLibraryStore: HomeLibraryStore
    private let fileManager: FileManager
    private let temporaryDirectory: URL
    private let session: URLSession
    private let now: () -> Date

    init(
        client: SupabaseClient,
        pendingStore: PendingVisitSubmissionStore = .shared,
        draftStore: SipDraftStore = .shared,
        reportStore: SafetyReportReceiptStore = .shared,
        appealStore: ModerationAppealReceiptStore = .shared,
        homeLibraryStore: HomeLibraryStore = .shared,
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        temporaryDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        remote = SupabaseOwnerDataExportRemoteTransport(client: client)
        self.pendingStore = pendingStore
        self.draftStore = draftStore
        self.reportStore = reportStore
        self.appealStore = appealStore
        self.homeLibraryStore = homeLibraryStore
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory ?? fileManager.temporaryDirectory
        self.session = session
        self.now = now
    }

    init(
        remote: OwnerDataExportRemoteTransport,
        pendingStore: PendingVisitSubmissionStore,
        draftStore: SipDraftStore = .shared,
        reportStore: SafetyReportReceiptStore = .shared,
        appealStore: ModerationAppealReceiptStore = .shared,
        homeLibraryStore: HomeLibraryStore = .shared,
        fileManager: FileManager,
        session: URLSession,
        temporaryDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.remote = remote
        self.pendingStore = pendingStore
        self.draftStore = draftStore
        self.reportStore = reportStore
        self.appealStore = appealStore
        self.homeLibraryStore = homeLibraryStore
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory ?? fileManager.temporaryDirectory
        self.session = session
        self.now = now
    }

    func prepareExport() async throws -> OwnerDataExportPackage {
        guard let ownerID = remote.currentUserID else {
            throw OwnerDataExportError.authenticationRequired
        }
        try requireActiveOwner(ownerID)

        let serverResult: (
            data: Data,
            sourceVersion: Int,
            completeness: OwnerDataExportCompleteness,
            omittedCollections: [String]
        )
        do {
            let data = try await remote.fetchV2Export()
            try requireActiveOwner(ownerID)
            serverResult = (data, 2, .complete, [])
        } catch {
            try requireActiveOwner(ownerID)
            guard Self.isMissingV2Function(error) else { throw error }
            let data = try await remote.fetchV1Export()
            try requireActiveOwner(ownerID)
            serverResult = (data, 1, .partial, Self.v1OmittedCollections)
        }

        let serverData = serverResult.data
        let sourceVersion = serverResult.sourceVersion
        var completeness = serverResult.completeness
        var omittedCollections = serverResult.omittedCollections

        guard var object = try JSONSerialization.jsonObject(with: serverData) as? [String: Any] else {
            throw OwnerDataExportError.invalidServerExport
        }
        if sourceVersion == 2 {
            let serverManifest = object["export_manifest"] as? [String: Any]
            let serverCompleteness = serverManifest?["server_contract_completeness"]
                as? String
            if serverCompleteness != "complete_as_of_schema_version_2" {
                completeness = .partial
                let knownOmissions = serverManifest?["known_omissions"] as? [String] ?? []
                omittedCollections.append(contentsOf: knownOmissions.isEmpty
                    ? ["server export manifest is incomplete or unavailable"]
                    : knownOmissions)
            }

            do {
                let enforcementData = try await remote.fetchEnforcementExport()
                try requireActiveOwner(ownerID)
                guard let enforcement = try JSONSerialization.jsonObject(
                    with: enforcementData
                ) as? [String: Any] else {
                    throw OwnerDataExportError.invalidServerExport
                }
                object["enforcement_and_appeals"] = enforcement
            } catch {
                try requireActiveOwner(ownerID)
                guard Self.isMissingV2Function(error) else { throw error }
                completeness = .partial
                omittedCollections.append("enforcement decisions and appeal statements")
            }
        }

        let pendingRecords: [PendingVisitSubmissionRecord]
        let pendingOutboxReadComplete: Bool
        do {
            pendingRecords = try pendingStore.loadAll(userId: ownerID)
            pendingOutboxReadComplete = true
        } catch {
            pendingRecords = []
            pendingOutboxReadComplete = false
            completeness = .partial
            omittedCollections.append(
                "local pending MugShot recovery records could not be read"
            )
        }
        object["local_pending_submission_outbox"] = try Self.pendingExportObject(
            from: pendingRecords
        )

        let draftReadReport = draftStore.readReport(in: .user(ownerID))
        let localDrafts = draftReadReport.drafts
        if !draftReadReport.isComplete {
            completeness = .partial
            omittedCollections.append(
                "one or more local sip drafts could not be read"
            )
        }
        object["local_sip_drafts"] = try Self.draftExportObject(from: localDrafts)
        let localHomeLibrary = homeLibraryStore.load(in: .user(ownerID))
        object["local_home_workbench_cache"] = try Self.homeLibraryExportObject(
            from: localHomeLibrary
        )
        object["local_data_read_status"] = [
            "pending_submission_outbox": [
                "status": pendingOutboxReadComplete
                    ? "complete"
                    : "unavailable_preserved",
                "readable_record_count": pendingRecords.count
            ],
            "sip_drafts": [
                "status": draftReadReport.isComplete
                    ? "complete"
                    : "partial_unavailable_preserved",
                "readable_record_count": localDrafts.count,
                "unreadable_draft_count": draftReadReport.unreadableDraftCount,
                "issues": draftReadReport.issues.map(\.exportCode)
            ],
            "home_workbench_cache": [
                "status": "complete",
                "coffee_bag_count": localHomeLibrary.bags.count,
                "equipment_profile_count": localHomeLibrary.equipment.count,
                "recent_setup_count": localHomeLibrary.recentSetups.count
            ]
        ] as [String: Any]
        object["local_unconfirmed_safety_reports"] = try Self.jsonObject(
            from: reportStore.receipts(accountID: ownerID).filter {
                $0.deliveryState != .submitted
            }
        )
        object["local_unconfirmed_moderation_appeals"] = try Self.jsonObject(
            from: appealStore.pending(accountID: ownerID)
        )
        let stamp = DateFormatter.mugshotExportStamp.string(from: now())
        let directory = temporaryDirectory
            .appendingPathComponent(
                "Mugshot-Export-\(stamp)-\(UUID().uuidString.lowercased())",
                isDirectory: true
            )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var retainPreparedDirectory = false
        defer {
            if !retainPreparedDirectory {
                try? fileManager.removeItem(at: directory)
            }
        }

        let pendingDirectory = directory.appendingPathComponent(
            "Pending-MugShots",
            isDirectory: true
        )
        var pendingMediaManifest: [[String: Any]] = []
        var pendingMediaFailures: [[String: String]] = []
        var draftMediaManifest: [[String: Any]] = []
        var draftMediaFailures: [[String: String]] = []
        var homeBagMediaManifest: [[String: String]] = []
        var homeBagMediaFailures: [[String: String]] = []
        var mediaURLs: [URL] = []
        var packaged = 0
        var unavailable = 0
        var totalPackagedBytes: Int64 = 0

        if pendingRecords.contains(where: { !$0.localPhotoNames.isEmpty }) {
            try fileManager.createDirectory(
                at: pendingDirectory,
                withIntermediateDirectories: true
            )
        }
        for record in pendingRecords where !record.localPhotoNames.isEmpty {
            let visitDirectory = pendingDirectory.appendingPathComponent(
                record.id.uuidString.lowercased(),
                isDirectory: true
            )
            do {
                let images = try pendingStore.loadImages(for: record)
                try fileManager.createDirectory(
                    at: visitDirectory,
                    withIntermediateDirectories: true
                )
                var relativeFiles: [String] = []
                for (index, image) in images.enumerated() {
                    guard let data = image.jpegData(compressionQuality: 0.9),
                          Int64(data.count) <= Self.maximumMediaFileBytes,
                          totalPackagedBytes + Int64(data.count)
                            <= Self.maximumPackagedMediaBytes else {
                        pendingMediaFailures.append([
                            "visit_id": record.id.uuidString.lowercased(),
                            "file": "photo-\(index + 1)",
                            "reason": "image unavailable or package size limit reached"
                        ])
                        unavailable += 1
                        continue
                    }
                    let filename = String(format: "photo-%03d.jpg", index + 1)
                    let destination = visitDirectory.appendingPathComponent(filename)
                    try data.write(to: destination, options: .atomic)
                    totalPackagedBytes += Int64(data.count)
                    packaged += 1
                    mediaURLs.append(destination)
                    relativeFiles.append(
                        "Pending-MugShots/\(record.id.uuidString.lowercased())/\(filename)"
                    )
                }
                pendingMediaManifest.append([
                    "visit_id": record.id.uuidString.lowercased(),
                    "files": relativeFiles
                ])
            } catch {
                for index in record.localPhotoNames.indices {
                    pendingMediaFailures.append([
                        "visit_id": record.id.uuidString.lowercased(),
                        "file": "photo-\(index + 1)",
                        "reason": "local pending image could not be read"
                    ])
                    unavailable += 1
                }
            }
        }

        let draftDirectory = directory.appendingPathComponent(
            "Draft-MugShots",
            isDirectory: true
        )
        if localDrafts.contains(where: { !$0.localPhotoNames.isEmpty }) {
            try fileManager.createDirectory(
                at: draftDirectory,
                withIntermediateDirectories: true
            )
        }
        for draft in localDrafts where !draft.localPhotoNames.isEmpty {
            let itemDirectory = draftDirectory.appendingPathComponent(
                draft.id.uuidString.lowercased(),
                isDirectory: true
            )
            guard let stored = draftStore.load(id: draft.id, in: .user(ownerID)) else {
                for index in draft.localPhotoNames.indices {
                    draftMediaFailures.append([
                        "draft_id": draft.id.uuidString.lowercased(),
                        "file": "photo-\(index + 1)",
                        "reason": "local draft image could not be read"
                    ])
                    unavailable += 1
                }
                continue
            }
            try fileManager.createDirectory(
                at: itemDirectory,
                withIntermediateDirectories: true
            )
            var relativeFiles: [String] = []
            for (index, image) in stored.images.enumerated() {
                guard let data = image.jpegData(compressionQuality: 0.9),
                      Int64(data.count) <= Self.maximumMediaFileBytes,
                      totalPackagedBytes + Int64(data.count)
                        <= Self.maximumPackagedMediaBytes else {
                    draftMediaFailures.append([
                        "draft_id": draft.id.uuidString.lowercased(),
                        "file": "photo-\(index + 1)",
                        "reason": "image unavailable or package size limit reached"
                    ])
                    unavailable += 1
                    continue
                }
                let filename = String(format: "photo-%03d.jpg", index + 1)
                let destination = itemDirectory.appendingPathComponent(filename)
                try data.write(to: destination, options: .atomic)
                totalPackagedBytes += Int64(data.count)
                packaged += 1
                mediaURLs.append(destination)
                relativeFiles.append(
                    "Draft-MugShots/\(draft.id.uuidString.lowercased())/\(filename)"
                )
            }
            if stored.images.count < draft.localPhotoNames.count {
                for index in stored.images.count..<draft.localPhotoNames.count {
                    draftMediaFailures.append([
                        "draft_id": draft.id.uuidString.lowercased(),
                        "file": "photo-\(index + 1)",
                        "reason": "local draft image could not be read"
                    ])
                    unavailable += 1
                }
            }
            draftMediaManifest.append([
                "draft_id": draft.id.uuidString.lowercased(),
                "files": relativeFiles
            ])
        }

        let homeBagDirectory = directory.appendingPathComponent(
            "Home-Coffee-Bag-Photos",
            isDirectory: true
        )
        let bagsWithLocalPhotos = localHomeLibrary.bags.filter {
            $0.localPhotoPath?.remoteTrimmedNonEmpty != nil
        }
        if !bagsWithLocalPhotos.isEmpty {
            try fileManager.createDirectory(
                at: homeBagDirectory,
                withIntermediateDirectories: true
            )
        }
        for bag in bagsWithLocalPhotos {
            let bagID = bag.id.uuidString.lowercased()
            guard let image = homeLibraryStore.bagPhoto(
                relativePath: bag.localPhotoPath,
                in: .user(ownerID)
            ),
            let data = image.jpegData(compressionQuality: 0.9),
            Int64(data.count) <= Self.maximumMediaFileBytes,
            totalPackagedBytes + Int64(data.count) <= Self.maximumPackagedMediaBytes else {
                homeBagMediaFailures.append([
                    "coffee_bag_id": bagID,
                    "reason": "local bag image could not be read or package size limit reached"
                ])
                unavailable += 1
                continue
            }
            let filename = "\(bagID).jpg"
            let destination = homeBagDirectory.appendingPathComponent(filename)
            try data.write(to: destination, options: .atomic)
            totalPackagedBytes += Int64(data.count)
            packaged += 1
            mediaURLs.append(destination)
            homeBagMediaManifest.append([
                "coffee_bag_id": bagID,
                "file": "Home-Coffee-Bag-Photos/\(filename)"
            ])
        }

        let mediaDirectory = directory.appendingPathComponent("Media", isDirectory: true)
        let rawReferenceCount = (object["media_references"] as? [Any])?.count ?? 0
        let allReferences = Self.mediaReferences(from: object, ownerID: ownerID)
        if rawReferenceCount > allReferences.count {
            unavailable += rawReferenceCount - allReferences.count
        }
        let references = Array(allReferences.prefix(Self.maximumMediaReferenceCount))
        if allReferences.count > references.count {
            unavailable += allReferences.count - references.count
        }
        if !references.isEmpty {
            try fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        }

        for (index, reference) in references.enumerated() {
            do {
                let remoteURL = try await resolvedURL(for: reference, ownerID: ownerID)
                let (temporaryURL, response) = try await session.download(from: remoteURL)
                try requireActiveOwner(ownerID)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      http.url.flatMap({ Self.safeRemoteURL($0.absoluteString) }) != nil,
                      http.mimeType?.lowercased().hasPrefix("image/") == true else {
                    unavailable += 1
                    continue
                }
                let attributes = try fileManager.attributesOfItem(atPath: temporaryURL.path)
                let fileBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                guard fileBytes > 0,
                      fileBytes <= Self.maximumMediaFileBytes,
                      totalPackagedBytes + fileBytes <= Self.maximumPackagedMediaBytes else {
                    unavailable += 1
                    continue
                }
                let ext = Self.fileExtension(for: http.mimeType) ?? "jpg"
                let destination = mediaDirectory.appendingPathComponent(
                    String(format: "media-%04d.%@", index + 1, ext.lowercased())
                )
                try fileManager.moveItem(at: temporaryURL, to: destination)
                mediaURLs.append(destination)
                totalPackagedBytes += fileBytes
                packaged += 1
            } catch let error as OwnerDataExportError
                where error == .accountScopeChanged {
                throw error
            } catch {
                unavailable += 1
            }
        }

        if !pendingMediaFailures.isEmpty
            || !draftMediaFailures.isEmpty
            || !homeBagMediaFailures.isEmpty
            || unavailable > 0 {
            completeness = .partial
            omittedCollections.append("one or more media files were unavailable")
        }
        object["pending_outbox_media_manifest"] = pendingMediaManifest
        object["pending_outbox_media_failures"] = pendingMediaFailures
        object["draft_media_manifest"] = draftMediaManifest
        object["draft_media_failures"] = draftMediaFailures
        object["home_coffee_bag_media_manifest"] = homeBagMediaManifest
        object["home_coffee_bag_media_failures"] = homeBagMediaFailures
        object["client_export_manifest"] = [
            "contract": "mugshot-owner-data-export-package",
            "source_schema_version": sourceVersion,
            "completeness": completeness.rawValue,
            "omitted_collections": Array(Set(omittedCollections)).sorted(),
            "pending_outbox_record_count": pendingOutboxReadComplete
                ? pendingRecords.count
                : NSNull(),
            "readable_pending_outbox_record_count": pendingRecords.count,
            "pending_outbox_media": !pendingOutboxReadComplete
                ? "unavailable_preserved"
                : (pendingMediaFailures.isEmpty ? "packaged" : "partial"),
            "local_draft_count": draftReadReport.isComplete
                ? localDrafts.count
                : NSNull(),
            "readable_local_draft_count": localDrafts.count,
            "local_draft_media": !draftReadReport.isComplete
                ? "partial_unavailable_preserved"
                : (draftMediaFailures.isEmpty ? "packaged" : "partial"),
            "local_home_coffee_bag_media": homeBagMediaFailures.isEmpty
                ? "packaged"
                : "partial",
            "packaged_media_count": packaged,
            "unavailable_media_count": unavailable,
            "packaged_media_bytes": totalPackagedBytes,
            "per_file_byte_limit": Self.maximumMediaFileBytes,
            "package_byte_limit": Self.maximumPackagedMediaBytes,
            "generated_at": ISO8601DateFormatter().string(from: now())
        ] as [String: Any]
        let prettyData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        let journalURL = directory.appendingPathComponent("mugshot-journal.json")
        try requireActiveOwner(ownerID)
        try prettyData.write(to: journalURL, options: .atomic)

        let package = OwnerDataExportPackage(
            directoryURL: directory,
            shareURLs: [journalURL] + mediaURLs,
            packagedMediaCount: packaged,
            unavailableMediaCount: unavailable,
            sourceSchemaVersion: sourceVersion,
            completeness: completeness,
            omittedCollections: Array(Set(omittedCollections)).sorted()
        )
        retainPreparedDirectory = true
        return package
    }

    func resolvedURL(
        for reference: OwnerExportMediaReference,
        ownerID: UUID
    ) async throws -> URL {
        try requireActiveOwner(ownerID)
        switch reference.source {
        case let .storage(bucket, path, _):
            // Storage references, including visit-photos-private, are resolved
            // with the current authenticated client rather than treated as
            // durable public URLs.
            guard Self.allowedStorageBuckets.contains(bucket),
                  path.split(separator: "/").first?.lowercased()
                    == ownerID.uuidString.lowercased(),
                  Self.safeStoragePath(path) else {
                throw OwnerDataExportError.unsafeMediaReference
            }
            let signedURL = try await remote.signedURL(
                bucket: bucket,
                path: path,
                expiresIn: 300
            )
            try requireActiveOwner(ownerID)
            guard Self.safeRemoteURL(signedURL.absoluteString) != nil else {
                throw OwnerDataExportError.unsafeMediaReference
            }
            return signedURL
        case let .remoteURL(url):
            guard Self.safeRemoteURL(url.absoluteString) != nil else {
                throw OwnerDataExportError.unsafeMediaReference
            }
            return url
        }
    }

    private func requireActiveOwner(_ ownerID: UUID) throws {
        guard remote.currentUserID == ownerID else {
            throw OwnerDataExportError.accountScopeChanged
        }
    }

    static func mediaReferences(
        from object: [String: Any],
        ownerID: UUID
    ) -> [OwnerExportMediaReference] {
        guard let rawReferences = object["media_references"] as? [Any] else { return [] }
        let references = rawReferences.compactMap { value -> OwnerExportMediaReference? in
            if let rawURL = value as? String {
                if let location = VisitPhotoStorageLocation(storedValue: rawURL) {
                    guard allowedStorageBuckets.contains(location.bucketName),
                          location.objectPath.split(separator: "/").first?.lowercased()
                            == ownerID.uuidString.lowercased() else { return nil }
                    return OwnerExportMediaReference(source: .storage(
                        bucket: location.bucketName,
                        path: location.objectPath,
                        access: nil
                    ))
                }
                guard let url = Self.safeRemoteURL(rawURL) else { return nil }
                return OwnerExportMediaReference(source: .remoteURL(url))
            }

            guard let dictionary = value as? [String: Any],
                  let kind = dictionary["kind"] as? String else { return nil }
            if kind == "storage",
               let bucket = dictionary["bucket"] as? String,
               let path = dictionary["path"] as? String,
               allowedStorageBuckets.contains(bucket),
               path.split(separator: "/").first?.lowercased()
                    == ownerID.uuidString.lowercased(),
               Self.safeStoragePath(path) {
                return OwnerExportMediaReference(source: .storage(
                    bucket: bucket,
                    path: path,
                    access: dictionary["access"] as? String
                ))
            }
            if kind == "remote_url",
               let rawURL = dictionary["url"] as? String,
               let url = Self.safeRemoteURL(rawURL) {
                return OwnerExportMediaReference(source: .remoteURL(url))
            }
            return nil
        }
        return Array(Set(references)).sorted { String(describing: $0.source) < String(describing: $1.source) }
    }

    static func isMissingV2Function(_ error: Error) -> Bool {
        guard let postgrestError = error as? PostgrestError else { return false }
        return postgrestError.code == "PGRST202"
            || postgrestError.code == "42883"
    }

    private static func jsonObject<T: Encodable>(from value: T) throws -> Any {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try JSONSerialization.jsonObject(with: encoder.encode(value))
    }

    /// Local filenames are implementation details and may reveal a sandbox
    /// layout. The durable payload remains intact while its media is mapped to
    /// package-relative entries in `pending_outbox_media_manifest`.
    private static func pendingExportObject(
        from records: [PendingVisitSubmissionRecord]
    ) throws -> Any {
        guard var values = try jsonObject(from: records) as? [[String: Any]] else {
            throw OwnerDataExportError.invalidServerExport
        }
        for index in values.indices {
            let localNames = values[index].removeValue(forKey: "localPhotoNames")
                as? [String] ?? []
            values[index]["localPhotoCount"] = localNames.count
        }
        return values
    }

    private static func draftExportObject(from drafts: [SipDraft]) throws -> Any {
        guard var values = try jsonObject(from: drafts) as? [[String: Any]] else {
            throw OwnerDataExportError.invalidServerExport
        }
        for index in values.indices {
            let localNames = values[index].removeValue(forKey: "localPhotoNames")
                as? [String] ?? []
            values[index]["localPhotoCount"] = localNames.count
        }
        return values
    }

    private static func homeLibraryExportObject(
        from snapshot: HomeLibrarySnapshot
    ) throws -> Any {
        guard var object = try jsonObject(from: snapshot) as? [String: Any] else {
            throw OwnerDataExportError.invalidServerExport
        }
        if var bags = object["bags"] as? [[String: Any]] {
            for index in bags.indices {
                bags[index].removeValue(forKey: "localPhotoPath")
            }
            object["bags"] = bags
        }
        return object
    }

    private static func safeRemoteURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host?.lowercased(),
              !host.isEmpty,
              url.user == nil,
              url.password == nil,
              isPublicRemoteHost(host) else { return nil }
        return url
    }

    private static func isPublicRemoteHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if normalized == "localhost"
            || normalized.hasSuffix(".localhost")
            || normalized.hasSuffix(".local")
            || normalized.hasSuffix(".internal") {
            return false
        }

        let octets = normalized.split(separator: ".", omittingEmptySubsequences: false)
        let values = octets.compactMap { Int($0) }
        if octets.count == 4,
           values.count == 4,
           values.allSatisfy({ (0...255).contains($0) }) {
            let first = values[0]
            let second = values[1]
            return first != 0
                && first != 10
                && first != 127
                && !(first == 100 && (64...127).contains(second))
                && !(first == 169 && second == 254)
                && !(first == 172 && (16...31).contains(second))
                && !(first == 192 && second == 168)
                && !(first == 198 && (18...19).contains(second))
                && first < 224
        }

        if normalized.contains(":") {
            if normalized.hasPrefix("::ffff:") {
                return isPublicRemoteHost(String(normalized.dropFirst(7)))
            }
            return normalized != "::"
                && normalized != "::1"
                && !normalized.hasPrefix("fc")
                && !normalized.hasPrefix("fd")
                && !normalized.hasPrefix("fe8")
                && !normalized.hasPrefix("fe9")
                && !normalized.hasPrefix("fea")
                && !normalized.hasPrefix("feb")
        }

        return normalized.contains(".")
    }

    private static func fileExtension(for mimeType: String?) -> String? {
        switch mimeType?.lowercased().split(separator: ";").first {
        case "image/jpeg", "image/jpg": return "jpg"
        case "image/png": return "png"
        case "image/heic", "image/heif": return "heic"
        case "image/webp": return "webp"
        case "image/gif": return "gif"
        default: return nil
        }
    }

    private static func safeStoragePath(_ value: String) -> Bool {
        let segments = value.split(separator: "/", omittingEmptySubsequences: false)
        return segments.count >= 2
            && segments.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}

enum OwnerDataExportError: LocalizedError, Equatable {
    case authenticationRequired
    case accountScopeChanged
    case invalidServerExport
    case unsafeMediaReference

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Sign in before preparing your Mugshot data export."
        case .accountScopeChanged:
            return "The signed-in account changed while Mugshot prepared the export. The temporary package was removed."
        case .invalidServerExport:
            return "Mugshot received an invalid export response. Nothing was written."
        case .unsafeMediaReference:
            return "Mugshot skipped a media reference that was not safe to export."
        }
    }
}

private extension DateFormatter {
    static let mugshotExportStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}
