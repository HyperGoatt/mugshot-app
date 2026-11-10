import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PocketSipOwner: Codable, Equatable, Sendable {
    let userID: UUID?

    fileprivate var directoryName: String { userID?.uuidString.lowercased() ?? "guest" }
}

struct PocketSipShareSession: Codable, Equatable, Sendable {
    let owner: PocketSipOwner
    fileprivate let generation: UUID
}

struct PocketSipCapture: Sendable {
    let id: UUID
    let date: Date
    let owner: PocketSipOwner
    let photos: [Data]
}

enum PocketSipCaptureError: LocalizedError {
    case invalidSelection
    case unreadablePhoto
    case inboxUnavailable
    case accountChanged

    var errorDescription: String? {
        switch self {
        case .invalidSelection: "Choose between 1 and \(PocketSipPhoto.maximumCount) photos."
        case .unreadablePhoto: "One of those photos couldn’t be read. Choose it again or try a different photo."
        case .inboxUnavailable: "Open Mugshot once, then try sharing these photos again."
        case .accountChanged: "The active Mugshot account changed. Open Mugshot before sharing again."
        }
    }
}

enum PocketSipPhoto {
    static let maximumCount = 10
    static let maximumJPEGBytes = 12 * 1_024 * 1_024
    private static let maximumDimension = 1_800

    /// Read from the provider's file while it is still available. The JPEG contains
    /// only the oriented image pixels, without the source's location or other EXIF.
    static func draftJPEG(at url: URL) throws -> Data {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            throw PocketSipCaptureError.unreadablePhoto
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw PocketSipCaptureError.unreadablePhoto
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PocketSipCaptureError.unreadablePhoto
        }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination), output.length <= maximumJPEGBytes else {
            throw PocketSipCaptureError.unreadablePhoto
        }
        return output as Data
    }

    static func preview(from jpeg: Data) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 192
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    static func validate(_ photos: [Data]) throws {
        guard (1...maximumCount).contains(photos.count) else { throw PocketSipCaptureError.invalidSelection }
        for photo in photos {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard photo.count <= maximumJPEGBytes,
                  let source = CGImageSourceCreateWithData(photo as CFData, options),
                  (CGImageSourceGetType(source) as String?) == UTType.jpeg.identifier,
                  CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  (1...maximumDimension).contains(width), (1...maximumDimension).contains(height),
                  properties[kCGImagePropertyGPSDictionary] == nil else {
                throw PocketSipCaptureError.unreadablePhoto
            }
        }
    }
}

/// A private handoff between the share extension and host. A visible packet is
/// complete, belongs to a specific owner, and stays present until the host
/// commits the corresponding draft. Each app process takes the same file lock.
struct PocketSipInbox {
    static let groupID = "group.co.mugshot.app.candlewood"

    static var shared: Self? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
            .map { Self(directory: $0.appendingPathComponent("PocketSipInbox-v1", isDirectory: true)) }
    }

    private struct Manifest: Codable {
        let id: UUID
        let date: Date
        let owner: PocketSipOwner
        let count: Int
    }

    let directory: URL
    private let files = FileManager.default

    private var sessionURL: URL { directory.appendingPathComponent("active-owner.json") }

    func activeSession() -> PocketSipShareSession? {
        guard let data = try? Data(contentsOf: sessionURL) else { return nil }
        return try? JSONDecoder().decode(PocketSipShareSession.self, from: data)
    }

    func activate(_ owner: PocketSipOwner?) throws {
        try withLock {
            guard activeSession()?.owner != owner else { return }
            if let owner {
                let session = PocketSipShareSession(owner: owner, generation: UUID())
                try JSONEncoder().encode(session).write(to: sessionURL, options: .atomic)
            } else if files.fileExists(atPath: sessionURL.path) {
                try files.removeItem(at: sessionURL)
            }
        }
    }

    func enqueue(_ capture: PocketSipCapture, for session: PocketSipShareSession) throws {
        try PocketSipPhoto.validate(capture.photos)
        try withLock {
            guard activeSession() == session, capture.owner == session.owner else {
                throw PocketSipCaptureError.accountChanged
            }
            let ownerURL = ownerDirectory(session.owner)
            try files.createDirectory(at: ownerURL, withIntermediateDirectories: true)
            try cleanStaging(in: ownerURL)
            let final = packetURL(capture.id, owner: session.owner)
            guard !files.fileExists(atPath: final.path) else { return }
            let stage = ownerURL.appendingPathComponent(".stage-\(capture.id.uuidString)", isDirectory: true)
            try files.createDirectory(at: stage, withIntermediateDirectories: false)
            defer { try? files.removeItem(at: stage) }
            for (index, photo) in capture.photos.enumerated() {
                try photo.write(to: stage.appendingPathComponent("photo-\(index).jpg"))
            }
            let manifest = Manifest(id: capture.id, date: capture.date, owner: capture.owner, count: capture.photos.count)
            try JSONEncoder().encode(manifest).write(to: stage.appendingPathComponent("capture.json"))
            try files.moveItem(at: stage, to: final)
        }
    }

    func pendingIDs(for owner: PocketSipOwner) throws -> [UUID] {
        try withLock {
            guard activeSession()?.owner == owner else { return [] }
            let ownerURL = ownerDirectory(owner)
            guard files.fileExists(atPath: ownerURL.path) else { return [] }
            try cleanStaging(in: ownerURL)
            return try files.contentsOfDirectory(at: ownerURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                .compactMap { UUID(uuidString: $0.lastPathComponent) }
        }
    }

    /// The caller's save is synchronous and idempotent using the capture ID.
    /// A failed save or acknowledgement leaves the source packet available.
    func consume(id: UUID, for owner: PocketSipOwner, save: (PocketSipCapture) throws -> Void) throws {
        try withLock {
            guard activeSession()?.owner == owner else { throw PocketSipCaptureError.accountChanged }
            let packet = packetURL(id, owner: owner)
            guard files.fileExists(atPath: packet.path) else { return }
            let manifest = try JSONDecoder().decode(
                Manifest.self, from: Data(contentsOf: packet.appendingPathComponent("capture.json"))
            )
            guard manifest.id == id, manifest.owner == owner,
                  (1...PocketSipPhoto.maximumCount).contains(manifest.count) else {
                throw PocketSipCaptureError.invalidSelection
            }
            let photos = try (0..<manifest.count).map { index in
                let url = packet.appendingPathComponent("photo-\(index).jpg")
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0, size <= PocketSipPhoto.maximumJPEGBytes else {
                    throw PocketSipCaptureError.unreadablePhoto
                }
                return try Data(contentsOf: url)
            }
            try save(PocketSipCapture(id: id, date: manifest.date, owner: owner, photos: photos))
            let consumed = ownerDirectory(owner).appendingPathComponent(".consumed-\(id.uuidString)", isDirectory: true)
            try files.moveItem(at: packet, to: consumed)
            try? files.removeItem(at: consumed)
        }
    }

    func purge(_ owner: PocketSipOwner) throws {
        try withLock {
            if activeSession()?.owner == owner {
                try files.removeItem(at: sessionURL)
            }
            let ownerURL = ownerDirectory(owner)
            if files.fileExists(atPath: ownerURL.path) {
                try files.removeItem(at: ownerURL)
            }
        }
    }

    private func ownerDirectory(_ owner: PocketSipOwner) -> URL {
        directory.appendingPathComponent(owner.directoryName, isDirectory: true)
    }

    private func packetURL(_ id: UUID, owner: PocketSipOwner) -> URL {
        ownerDirectory(owner).appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
    }

    private func cleanStaging(in ownerURL: URL) throws {
        for url in try files.contentsOfDirectory(at: ownerURL, includingPropertiesForKeys: nil)
        where url.lastPathComponent.hasPrefix(".stage-") || url.lastPathComponent.hasPrefix(".consumed-") {
            try? files.removeItem(at: url)
        }
    }

    private func withLock<T>(_ work: () throws -> T) throws -> T {
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = directory.appendingPathComponent("lock")
        let lock = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lock >= 0 else { throw PocketSipCaptureError.inboxUnavailable }
        defer { close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw PocketSipCaptureError.inboxUnavailable }
        defer { flock(lock, LOCK_UN) }
        return try work()
    }
}
