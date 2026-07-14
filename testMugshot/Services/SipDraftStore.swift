import Foundation
import UIKit

struct StoredSipDraft: Equatable {
    var draft: SipDraft
    var images: [UIImage]

    static func == (lhs: StoredSipDraft, rhs: StoredSipDraft) -> Bool {
        lhs.draft == rhs.draft && lhs.images.count == rhs.images.count
    }
}

final class SipDraftStore {
    static let shared = SipDraftStore()

    private let fileManager: FileManager
    private let baseDirectory: URL
    private let activeDraftIDURL: URL
    private let legacyDraftURL: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MugshotSipDraft", isDirectory: true)
        self.activeDraftIDURL = self.baseDirectory.appendingPathComponent("active-draft-id")
        self.legacyDraftURL = self.baseDirectory.appendingPathComponent("active-draft.json")
    }

    @discardableResult
    func save(_ draft: SipDraft, images: [UIImage]) throws -> SipDraft {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        var storedDraft = draft
        storedDraft.updatedAt = Date()
        let imageDirectory = directory(for: storedDraft.id)
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
        try data.write(to: draftMetadataURL(for: storedDraft.id), options: .atomic)
        try setActiveDraftID(storedDraft.id)
        try? fileManager.removeItem(at: legacyDraftURL)
        return storedDraft
    }

    func load() -> StoredSipDraft? {
        if let activeID = activeDraftID(),
           let draft = loadDraft(id: activeID) {
            return stored(draft)
        }

        if let data = try? Data(contentsOf: legacyDraftURL),
           let legacy = try? JSONDecoder.mugshotDraftDecoder.decode(SipDraft.self, from: data) {
            let legacyBundle = stored(legacy)
            if let migrated = try? save(legacy, images: legacyBundle.images) {
                return stored(migrated)
            }
            return legacyBundle
        }

        guard let newest = allDrafts().max(by: { $0.updatedAt < $1.updatedAt }) else { return nil }
        try? setActiveDraftID(newest.id)
        return stored(newest)
    }

    func allDrafts() -> [SipDraft] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let id = UUID(uuidString: url.lastPathComponent),
                  let draft = loadDraft(id: id) else { return nil }
            return draft
        }
    }

    func load(id: UUID) -> StoredSipDraft? {
        guard let draft = loadDraft(id: id) else { return nil }
        return stored(draft)
    }

    func remove(_ draft: SipDraft) {
        try? fileManager.removeItem(at: directory(for: draft.id))
        if activeDraftID() == draft.id {
            try? fileManager.removeItem(at: activeDraftIDURL)
            if let newest = allDrafts().max(by: { $0.updatedAt < $1.updatedAt }) {
                try? setActiveDraftID(newest.id)
            }
        }
    }

#if DEBUG
    func removeAllForTesting() {
        try? fileManager.removeItem(at: baseDirectory)
    }
#endif

    private func directory(for draftID: UUID) -> URL {
        baseDirectory.appendingPathComponent(draftID.uuidString.lowercased(), isDirectory: true)
    }

    private func draftMetadataURL(for draftID: UUID) -> URL {
        directory(for: draftID).appendingPathComponent("draft.json")
    }

    private func loadDraft(id: UUID) -> SipDraft? {
        guard let data = try? Data(contentsOf: draftMetadataURL(for: id)) else { return nil }
        return try? JSONDecoder.mugshotDraftDecoder.decode(SipDraft.self, from: data)
    }

    private func stored(_ draft: SipDraft) -> StoredSipDraft {
        let images = draft.localPhotoNames.compactMap { name in
            UIImage(contentsOfFile: directory(for: draft.id).appendingPathComponent(name).path)
        }
        return StoredSipDraft(draft: draft, images: images)
    }

    private func activeDraftID() -> UUID? {
        guard let data = try? Data(contentsOf: activeDraftIDURL),
              let rawValue = String(data: data, encoding: .utf8) else { return nil }
        return UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func setActiveDraftID(_ id: UUID) throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let data = Data(id.uuidString.lowercased().utf8)
        try data.write(to: activeDraftIDURL, options: .atomic)
    }
}

enum SipDraftStoreError: LocalizedError {
    case photoEncodingFailed

    var errorDescription: String? {
        "One selected photo could not be preserved in this draft."
    }
}

final class CafeVisibilityPreferenceStore {
    static let shared = CafeVisibilityPreferenceStore()

    private let defaults: UserDefaults
    static let valueKey = "MugshotComposer.lastCafeVisibility.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var defaultCafeVisibility: VisitVisibility {
        guard let rawValue = defaults.string(forKey: Self.valueKey),
              let visibility = VisitVisibility(rawValue: rawValue) else {
            return .friends
        }
        return visibility
    }

    func rememberCafeVisibility(_ visibility: VisitVisibility) {
        defaults.set(visibility.rawValue, forKey: Self.valueKey)
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
