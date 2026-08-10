import Foundation
import UIKit

struct StoredSipDraft: Equatable {
    var draft: SipDraft
    var images: [UIImage]

    static func == (lhs: StoredSipDraft, rhs: StoredSipDraft) -> Bool {
        lhs.draft == rhs.draft && lhs.images.count == rhs.images.count
    }
}

enum SipDraftReadIssue: Equatable {
    case legacyMigrationUnavailable
    case scopeDirectoryUnavailable
    case unreadableDraftMetadata(UUID?)

    var exportCode: String {
        switch self {
        case .legacyMigrationUnavailable:
            return "legacy_migration_unavailable"
        case .scopeDirectoryUnavailable:
            return "scope_directory_unavailable"
        case .unreadableDraftMetadata:
            return "draft_metadata_unreadable"
        }
    }
}

struct SipDraftReadReport: Equatable {
    let drafts: [SipDraft]
    let issues: [SipDraftReadIssue]

    var isComplete: Bool { issues.isEmpty }

    var unreadableDraftCount: Int {
        issues.reduce(into: 0) { count, issue in
            if case .unreadableDraftMetadata = issue { count += 1 }
        }
    }
}

final class SipDraftStore {
    static let shared = SipDraftStore()

    private let fileManager: FileManager
    private let baseDirectory: URL
    private let scopedRootDirectory: URL
    private let quarantineDirectory: URL
    private let migrationMarkerURL: URL
    private let legacyActiveDraftIDURL: URL
    private let legacyDraftURL: URL
    private let lock = NSRecursiveLock()
    private var activeScope: LocalAccountScope = .guest

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MugshotSipDraft", isDirectory: true)
        self.scopedRootDirectory = self.baseDirectory.appendingPathComponent("v2", isDirectory: true)
        self.quarantineDirectory = self.baseDirectory
            .appendingPathComponent("v2", isDirectory: true)
            .appendingPathComponent("quarantine", isDirectory: true)
        self.migrationMarkerURL = self.baseDirectory
            .appendingPathComponent("v2", isDirectory: true)
            .appendingPathComponent("legacy-migration-complete")
        self.legacyActiveDraftIDURL = self.baseDirectory.appendingPathComponent("active-draft-id")
        self.legacyDraftURL = self.baseDirectory.appendingPathComponent("active-draft.json")
    }

    @discardableResult
    func save(
        _ draft: SipDraft,
        images: [UIImage],
        in scope: LocalAccountScope
    ) throws -> SipDraft {
        lock.lock()
        defer { lock.unlock() }
        try migrateLegacyDataIfNeeded()
        guard draftBelongsToScope(draft, scope: scope) else {
            throw SipDraftStoreError.ownerMismatch
        }

        let scopeDirectory = directory(for: scope)
        try fileManager.createDirectory(at: scopeDirectory, withIntermediateDirectories: true)

        var storedDraft = draft
        storedDraft.updatedAt = Date()
        let imageDirectory = directory(for: storedDraft.id, in: scope)
        try fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)

        let priorNames = Set(storedDraft.localPhotoNames)
        var names: [String] = []
        do {
            for (index, image) in images.prefix(VisitPhotoUploadPlan.maxPhotoCount).enumerated() {
                let existingName = storedDraft.localPhotoNames.indices.contains(index)
                    ? storedDraft.localPhotoNames[index]
                    : "photo-\(UUID().uuidString.lowercased()).jpg"
                let imageURL = imageDirectory.appendingPathComponent(existingName)
                if storedDraft.localPhotoNames.indices.contains(index),
                   fileManager.fileExists(atPath: imageURL.path) {
                    names.append(existingName)
                    continue
                }
                guard let data = image
                    .resizedForVisitUpload(maxDimension: 2_000)
                    .jpegData(compressionQuality: 0.82) else {
                    throw SipDraftStoreError.photoEncodingFailed
                }
                try data.write(to: imageURL, options: .atomic)
                names.append(existingName)
            }
        } catch {
            throw error
        }

        for staleName in priorNames.subtracting(names) {
            try? fileManager.removeItem(at: imageDirectory.appendingPathComponent(staleName))
        }

        storedDraft.localPhotoNames = names
        storedDraft.posterPhotoIndex = min(max(storedDraft.posterPhotoIndex, 0), max(names.count - 1, 0))
        let data = try JSONEncoder.mugshotDraftEncoder.encode(storedDraft)
        try data.write(to: draftMetadataURL(for: storedDraft.id, in: scope), options: .atomic)
        try setActiveDraftID(storedDraft.id, in: scope)
        return storedDraft
    }

    func activate(scope: LocalAccountScope) {
        lock.lock()
        activeScope = scope
        lock.unlock()
    }

    func load(in scope: LocalAccountScope) -> StoredSipDraft? {
        lock.lock()
        defer { lock.unlock() }
        try? migrateLegacyDataIfNeeded()

        if let activeID = activeDraftID(in: scope),
           let draft = loadDraft(id: activeID, in: scope) {
            return stored(draft, in: scope)
        }

        guard let newest = allDraftsWithoutLock(in: scope)
            .max(by: { $0.updatedAt < $1.updatedAt }) else { return nil }
        try? setActiveDraftID(newest.id, in: scope)
        return stored(newest, in: scope)
    }

    func allDrafts(in scope: LocalAccountScope) -> [SipDraft] {
        readReport(in: scope).drafts
    }

    /// Returns every readable draft together with explicit evidence that some
    /// local data could not be read. This lets recovery and export surfaces be
    /// honest without deleting, rewriting, or hiding the unreadable bytes.
    func readReport(in scope: LocalAccountScope) -> SipDraftReadReport {
        lock.lock()
        defer { lock.unlock() }

        var issues: [SipDraftReadIssue] = []
        do {
            try migrateLegacyDataIfNeeded()
        } catch {
            issues.append(.legacyMigrationUnavailable)
        }
        let scopedReport = readReportWithoutLock(in: scope)
        return SipDraftReadReport(
            drafts: scopedReport.drafts,
            issues: issues + scopedReport.issues
        )
    }

    func load(id: UUID, in scope: LocalAccountScope) -> StoredSipDraft? {
        lock.lock()
        defer { lock.unlock() }
        try? migrateLegacyDataIfNeeded()
        guard let draft = loadDraft(id: id, in: scope) else { return nil }
        return stored(draft, in: scope)
    }

    func remove(_ draft: SipDraft, in scope: LocalAccountScope) {
        lock.lock()
        defer { lock.unlock() }
        try? migrateLegacyDataIfNeeded()
        guard draftBelongsToScope(draft, scope: scope) else { return }

        try? fileManager.removeItem(at: directory(for: draft.id, in: scope))
        if activeDraftID(in: scope) == draft.id {
            try? fileManager.removeItem(at: activeDraftIDURL(in: scope))
            if let newest = allDraftsWithoutLock(in: scope)
                .max(by: { $0.updatedAt < $1.updatedAt }) {
                try? setActiveDraftID(newest.id, in: scope)
            }
        }
    }

    /// Moves current guest work into an authenticated account without ever
    /// deleting the guest copy before a complete destination write can be read
    /// back. The caller supplies the in-memory draft so the last edit is not
    /// lost if authentication completes between autosave callbacks.
    func adoptGuestDraft(
        _ draft: SipDraft,
        images: [UIImage],
        for userID: UUID
    ) throws -> StoredSipDraft {
        lock.lock()
        defer { lock.unlock() }
        try migrateLegacyDataIfNeeded()
        guard draft.ownerUserID == nil else {
            throw SipDraftStoreError.ownerMismatch
        }

        let guestDraft = try save(draft, images: images, in: .guest)
        var adoptedDraft = guestDraft
        adoptedDraft.ownerUserID = userID
        if adoptedDraft.cafeSessionDraft != nil {
            adoptedDraft.cafeSessionDraft?.ownerUserID = userID
        }
        if let reference = adoptedDraft.cafeSessionReference {
            adoptedDraft.cafeSessionReference = CafeSessionReference(
                id: reference.id,
                ownerUserID: userID,
                cafeID: reference.cafeID,
                startedAt: reference.startedAt,
                visibility: reference.visibility,
                primaryVisitID: reference.primaryVisitID,
                returnIntention: reference.returnIntention
            )
        }

        let destinationScope = LocalAccountScope.user(userID)
        _ = try save(adoptedDraft, images: images, in: destinationScope)
        guard let verified = load(id: adoptedDraft.id, in: destinationScope),
              verified.draft.ownerUserID == userID,
              verified.draft.cafeSessionDraft?.ownerUserID == userID
                || verified.draft.cafeSessionDraft == nil,
              verified.draft.cafeSessionReference?.ownerUserID == userID
                || verified.draft.cafeSessionReference == nil else {
            throw SipDraftStoreError.adoptionVerificationFailed
        }

        remove(guestDraft, in: .guest)
        activeScope = destinationScope
        return verified
    }

    // Compatibility entry points use the active account scope. Saving a draft
    // with a proven owner also activates that owner's scope; these APIs never
    // search every account scope.
    @discardableResult
    func save(_ draft: SipDraft, images: [UIImage]) throws -> SipDraft {
        let scope = LocalAccountScope.forUserID(draft.ownerUserID)
        activate(scope: scope)
        return try save(draft, images: images, in: scope)
    }

    func load() -> StoredSipDraft? {
        load(in: currentScope)
    }

    func allDrafts() -> [SipDraft] {
        allDrafts(in: currentScope)
    }

    func load(id: UUID) -> StoredSipDraft? {
        load(id: id, in: currentScope)
    }

    func remove(_ draft: SipDraft) {
        remove(draft, in: .forUserID(draft.ownerUserID))
    }

    /// Removes only the deleted account's drafts, photos, attributable legacy
    /// bundles, and quarantine copies. Unproven quarantine data is preserved.
    func purge(ownerUserID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        try migrateLegacyDataIfNeeded()

        let scope = LocalAccountScope.user(ownerUserID)
        let scopedDirectory = directory(for: scope)
        if fileManager.fileExists(atPath: scopedDirectory.path) {
            try fileManager.removeItem(at: scopedDirectory)
        }
        try purgeAttributedCopies(in: quarantineDirectory, ownerUserID: ownerUserID)
        try purgeAttributedLegacyCopies(ownerUserID: ownerUserID)
        if activeScope == scope { activeScope = .guest }
    }

#if DEBUG
    func removeAllForTesting() {
        lock.lock()
        defer { lock.unlock() }
        try? fileManager.removeItem(at: baseDirectory)
    }
#endif

    private func allDraftsWithoutLock(in scope: LocalAccountScope) -> [SipDraft] {
        readReportWithoutLock(in: scope).drafts
    }

    private func readReportWithoutLock(in scope: LocalAccountScope) -> SipDraftReadReport {
        let scopeDirectory = directory(for: scope)
        guard fileManager.fileExists(atPath: scopeDirectory.path) else {
            return SipDraftReadReport(drafts: [], issues: [])
        }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: scopeDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return SipDraftReadReport(
                drafts: [],
                issues: [.scopeDirectoryUnavailable]
            )
        }

        var drafts: [SipDraft] = []
        var issues: [SipDraftReadIssue] = []
        for url in urls {
            let isDirectory: Bool
            do {
                isDirectory = try url.resourceValues(
                    forKeys: [.isDirectoryKey]
                ).isDirectory == true
            } catch {
                issues.append(.unreadableDraftMetadata(nil))
                continue
            }
            guard isDirectory else { continue }
            guard let id = UUID(uuidString: url.lastPathComponent) else {
                issues.append(.unreadableDraftMetadata(nil))
                continue
            }
            guard let draft = loadDraft(id: id, in: scope) else {
                issues.append(.unreadableDraftMetadata(id))
                continue
            }
            drafts.append(draft)
        }
        return SipDraftReadReport(drafts: drafts, issues: issues)
    }

    private var currentScope: LocalAccountScope {
        lock.lock()
        defer { lock.unlock() }
        return activeScope
    }

    private func directory(for scope: LocalAccountScope) -> URL {
        switch scope {
        case .guest:
            return scopedRootDirectory.appendingPathComponent("guest", isDirectory: true)
        case .user(let userID):
            return scopedRootDirectory
                .appendingPathComponent("users", isDirectory: true)
                .appendingPathComponent(userID.uuidString.lowercased(), isDirectory: true)
        }
    }

    private func directory(for draftID: UUID, in scope: LocalAccountScope) -> URL {
        directory(for: scope)
            .appendingPathComponent(draftID.uuidString.lowercased(), isDirectory: true)
    }

    private func draftMetadataURL(for draftID: UUID, in scope: LocalAccountScope) -> URL {
        directory(for: draftID, in: scope).appendingPathComponent("draft.json")
    }

    private func activeDraftIDURL(in scope: LocalAccountScope) -> URL {
        directory(for: scope).appendingPathComponent("active-draft-id")
    }

    private func loadDraft(id: UUID, in scope: LocalAccountScope) -> SipDraft? {
        guard let data = try? Data(contentsOf: draftMetadataURL(for: id, in: scope)),
              let draft = try? JSONDecoder.mugshotDraftDecoder.decode(SipDraft.self, from: data),
              draft.id == id,
              draftBelongsToScope(draft, scope: scope) else { return nil }
        return draft
    }

    private func stored(_ draft: SipDraft, in scope: LocalAccountScope) -> StoredSipDraft {
        let images = draft.localPhotoNames.compactMap { name in
            UIImage(contentsOfFile: directory(for: draft.id, in: scope).appendingPathComponent(name).path)
        }
        return StoredSipDraft(draft: draft, images: images)
    }

    private func activeDraftID(in scope: LocalAccountScope) -> UUID? {
        guard let data = try? Data(contentsOf: activeDraftIDURL(in: scope)),
              let rawValue = String(data: data, encoding: .utf8) else { return nil }
        return UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func setActiveDraftID(_ id: UUID, in scope: LocalAccountScope) throws {
        try fileManager.createDirectory(at: directory(for: scope), withIntermediateDirectories: true)
        let data = Data(id.uuidString.lowercased().utf8)
        try data.write(to: activeDraftIDURL(in: scope), options: .atomic)
    }

    private func draftBelongsToScope(_ draft: SipDraft, scope: LocalAccountScope) -> Bool {
        switch scope {
        case .guest:
            return draft.ownerUserID == nil
        case .user(let userID):
            return draft.ownerUserID == userID
        }
    }

    private func migrateLegacyDataIfNeeded() throws {
        guard !fileManager.fileExists(atPath: migrationMarkerURL.path) else { return }
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: scopedRootDirectory, withIntermediateDirectories: true)

        let legacyItems = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for item in legacyItems where item.lastPathComponent != "v2" {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true,
                  let pathID = UUID(uuidString: item.lastPathComponent) else { continue }
            try migrateLegacyBundle(at: item, pathID: pathID)
        }

        try migrateLegacySingleFileIfPresent()
        try migrateLegacyActiveDraftPointerIfPresent()
        try Data("complete".utf8).write(to: migrationMarkerURL, options: .atomic)
    }

    private func migrateLegacyBundle(at source: URL, pathID: UUID) throws {
        let metadataURL = source.appendingPathComponent("draft.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let draft = try? JSONDecoder.mugshotDraftDecoder.decode(SipDraft.self, from: data),
              draft.id == pathID,
              let ownerUserID = draft.ownerUserID else {
            try quarantineCopy(of: source, reason: "unproven")
            return
        }

        let destination = directory(for: draft.id, in: .user(ownerUserID))
        guard !fileManager.fileExists(atPath: destination.path) else {
            try quarantineCopy(of: source, reason: "collision")
            return
        }
        try copyAtomically(from: source, to: destination)
    }

    private func migrateLegacySingleFileIfPresent() throws {
        guard fileManager.fileExists(atPath: legacyDraftURL.path) else { return }
        guard let data = try? Data(contentsOf: legacyDraftURL),
              let draft = try? JSONDecoder.mugshotDraftDecoder.decode(SipDraft.self, from: data),
              let ownerUserID = draft.ownerUserID else {
            try quarantineCopy(of: legacyDraftURL, reason: "unproven-active")
            return
        }

        let scope = LocalAccountScope.user(ownerUserID)
        let destination = directory(for: draft.id, in: scope)
        if fileManager.fileExists(atPath: destination.path) {
            guard loadDraft(id: draft.id, in: scope) != nil else {
                try quarantineCopy(of: legacyDraftURL, reason: "collision-active")
                return
            }
            return
        }

        let staging = directory(for: scope)
            .appendingPathComponent(".migration-\(UUID().uuidString.lowercased())", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try data.write(to: staging.appendingPathComponent("draft.json"), options: .atomic)
            let legacyBundle = baseDirectory
                .appendingPathComponent(draft.id.uuidString.lowercased(), isDirectory: true)
            for name in draft.localPhotoNames {
                let sourcePhoto = legacyBundle.appendingPathComponent(name)
                guard fileManager.fileExists(atPath: sourcePhoto.path) else { continue }
                try fileManager.copyItem(
                    at: sourcePhoto,
                    to: staging.appendingPathComponent(name)
                )
            }
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func migrateLegacyActiveDraftPointerIfPresent() throws {
        guard let data = try? Data(contentsOf: legacyActiveDraftIDURL),
              let rawValue = String(data: data, encoding: .utf8),
              let draftID = UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        let legacyMetadataURL = baseDirectory
            .appendingPathComponent(draftID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("draft.json")
        let metadataURL = fileManager.fileExists(atPath: legacyMetadataURL.path)
            ? legacyMetadataURL
            : legacyDraftURL
        guard let metadata = try? Data(contentsOf: metadataURL),
              let draft = try? JSONDecoder.mugshotDraftDecoder.decode(SipDraft.self, from: metadata),
              draft.id == draftID,
              let ownerUserID = draft.ownerUserID else {
            try quarantineCopy(of: legacyActiveDraftIDURL, reason: "unproven-pointer")
            return
        }

        let scope = LocalAccountScope.user(ownerUserID)
        guard loadDraft(id: draftID, in: scope) != nil else {
            try quarantineCopy(of: legacyActiveDraftIDURL, reason: "orphan-pointer")
            return
        }
        if activeDraftID(in: scope) == nil {
            try setActiveDraftID(draftID, in: scope)
        }
    }

    private func copyAtomically(from source: URL, to destination: URL) throws {
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent
            .appendingPathComponent(".migration-\(UUID().uuidString.lowercased())", isDirectory: true)
        do {
            try fileManager.copyItem(at: source, to: staging)
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func quarantineCopy(of source: URL, reason: String) throws {
        try fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        let destination = quarantineDirectory.appendingPathComponent(
            "\(source.lastPathComponent)-\(reason)-\(UUID().uuidString.lowercased())",
            isDirectory: source.hasDirectoryPath
        )
        try fileManager.copyItem(at: source, to: destination)
    }

    private func purgeAttributedCopies(in root: URL, ownerUserID: UUID) throws {
        guard fileManager.fileExists(atPath: root.path) else { return }
        for item in try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) where draftOwner(at: item) == ownerUserID {
            try fileManager.removeItem(at: item)
        }
    }

    private func purgeAttributedLegacyCopies(ownerUserID: UUID) throws {
        guard fileManager.fileExists(atPath: baseDirectory.path) else { return }
        var removedDraftIDs = Set<UUID>()
        for item in try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) where item.lastPathComponent != "v2" && draftOwner(at: item) == ownerUserID {
            if let draftID = draft(at: item)?.id { removedDraftIDs.insert(draftID) }
            try fileManager.removeItem(at: item)
        }

        guard let data = try? Data(contentsOf: legacyActiveDraftIDURL),
              let rawValue = String(data: data, encoding: .utf8),
              let activeID = UUID(
                uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
              ),
              removedDraftIDs.contains(activeID) else { return }
        try fileManager.removeItem(at: legacyActiveDraftIDURL)
    }

    private func draftOwner(at item: URL) -> UUID? {
        draft(at: item)?.ownerUserID
    }

    private func draft(at item: URL) -> SipDraft? {
        let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory)
            == true
        let metadataURL = isDirectory ? item.appendingPathComponent("draft.json") : item
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder.mugshotDraftDecoder.decode(SipDraft.self, from: data)
    }
}

enum SipDraftStoreError: LocalizedError {
    case adoptionVerificationFailed
    case photoEncodingFailed
    case ownerMismatch

    var errorDescription: String? {
        switch self {
        case .adoptionVerificationFailed:
            return "Mugshot couldn’t verify the account copy. Your guest draft is still safe on this device."
        case .photoEncodingFailed:
            return "One selected photo could not be preserved in this draft."
        case .ownerMismatch:
            return "This draft belongs to a different local account."
        }
    }
}

final class CafeVisibilityPreferenceStore {
    static let shared = CafeVisibilityPreferenceStore()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var activeScope: LocalAccountScope
    static let valueKey = "MugshotComposer.lastCafeVisibility.v1"
    private static let keyPrefix = "MugshotComposer.lastCafeVisibility.v2."

    init(defaults: UserDefaults = .standard, initialScope: LocalAccountScope = .guest) {
        self.defaults = defaults
        self.activeScope = initialScope
    }

    func activate(scope: LocalAccountScope) {
        lock.lock()
        activeScope = scope
        lock.unlock()
    }

    var defaultCafeVisibility: VisitVisibility {
        defaultCafeVisibility(in: currentScope)
    }

    func defaultCafeVisibility(in scope: LocalAccountScope) -> VisitVisibility {
        guard let rawValue = defaults.string(forKey: Self.storageKey(for: scope)),
              let visibility = VisitVisibility(rawValue: rawValue) else {
            return .private
        }
        return visibility
    }

    func rememberCafeVisibility(_ visibility: VisitVisibility) {
        rememberCafeVisibility(visibility, in: currentScope)
    }

    func rememberCafeVisibility(_ visibility: VisitVisibility, in scope: LocalAccountScope) {
        defaults.set(visibility.rawValue, forKey: Self.storageKey(for: scope))
    }

    static func storageKey(for scope: LocalAccountScope) -> String {
        keyPrefix + scope.defaultsComponent
    }

    func remove(ownerUserID: UUID) {
        defaults.removeObject(forKey: Self.storageKey(for: .user(ownerUserID)))
        lock.lock()
        if activeScope == .user(ownerUserID) { activeScope = .guest }
        lock.unlock()
    }

    private var currentScope: LocalAccountScope {
        lock.lock()
        defer { lock.unlock() }
        return activeScope
    }
}

enum CafeSessionContinuationStage: String, Codable {
    case completion
    case activeAdditionalSip
}

/// Durable handoff between a completed cafe-session sip and the optional
/// "Add another sip" action. This is deliberately separate from the sip
/// draft: secondary sips carry only a compact session reference so Cafe Pulse
/// is never duplicated into each drink.
struct CafeSessionContinuationRecord: Codable, Equatable {
    var ownerUserID: UUID?
    var session: CafeSessionDraft
    var cafe: Cafe
    var summary: SipCompletionSnapshot
    var stage: CafeSessionContinuationStage
    var activeDraftID: UUID?
    var updatedAt: Date
}

struct SipCompletionSnapshot: Codable, Equatable {
    let drinkName: String
    let locationName: String
    let context: JournalEntryContext
    let score: Double
    let visibility: VisitVisibility
    let usedTastingLens: Bool
    let hasPhoto: Bool
    let hasThought: Bool
    let hasPrivateNote: Bool
    let hasBrewDetails: Bool
    let isCafeSession: Bool
    let cafeRating: Double?
    let nextMove: CafeNextMoveKind
}

final class CafeSessionContinuationStore {
    static let shared = CafeSessionContinuationStore()

    private let defaults: UserDefaults
    private let keyPrefix = "MugshotCafeSessionContinuation.v1."
    private let expirationInterval: TimeInterval

    init(
        defaults: UserDefaults = .standard,
        expirationInterval: TimeInterval = 24 * 60 * 60
    ) {
        self.defaults = defaults
        self.expirationInterval = expirationInterval
    }

    func save(_ record: CafeSessionContinuationRecord) throws {
        defaults.set(
            try JSONEncoder.mugshotDraftEncoder.encode(record),
            forKey: storageKey(record.ownerUserID)
        )
    }

    func load(ownerUserID: UUID?, now: Date = .now) -> CafeSessionContinuationRecord? {
        let key = storageKey(ownerUserID)
        guard let data = defaults.data(forKey: key),
              let record = try? JSONDecoder.mugshotDraftDecoder.decode(
                CafeSessionContinuationRecord.self,
                from: data
              ) else {
            return nil
        }
        guard now.timeIntervalSince(record.updatedAt) <= expirationInterval else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return record
    }

    func remove(ownerUserID: UUID?) {
        defaults.removeObject(forKey: storageKey(ownerUserID))
    }

#if DEBUG
    func removeAllForTesting() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
#endif

    private func storageKey(_ ownerUserID: UUID?) -> String {
        keyPrefix + (ownerUserID?.uuidString.lowercased() ?? "anonymous")
    }
}

private extension JSONEncoder {
    static var mugshotDraftEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var mugshotDraftDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
