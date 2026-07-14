import Foundation
import Supabase

struct OwnerDataExportPackage: Identifiable {
    let id = UUID()
    let directoryURL: URL
    let shareURLs: [URL]
    let packagedMediaCount: Int
    let unavailableMediaCount: Int
}

final class OwnerDataExportService {
    private let client: SupabaseClient
    private let fileManager: FileManager
    private let session: URLSession

    init(
        client: SupabaseClient,
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.client = client
        self.fileManager = fileManager
        self.session = session
    }

    func prepareExport() async throws -> OwnerDataExportPackage {
        let response = try await client.rpc("build_owner_data_export").execute()
        let object = try JSONSerialization.jsonObject(with: response.data)
        let prettyData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )

        let stamp = DateFormatter.mugshotExportStamp.string(from: Date())
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("Mugshot-Export-\(stamp)", isDirectory: true)
        try? fileManager.removeItem(at: directory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let journalURL = directory.appendingPathComponent("mugshot-journal.json")
        try prettyData.write(to: journalURL, options: .atomic)

        let mediaDirectory = directory.appendingPathComponent("Media", isDirectory: true)
        let references = Self.mediaReferences(from: object)
        var shareURLs = [journalURL]
        var packaged = 0
        var unavailable = 0
        if !references.isEmpty {
            try fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        }
        for (index, reference) in references.enumerated() {
            guard let remoteURL = URL(string: reference) else {
                unavailable += 1
                continue
            }
            do {
                let (temporaryURL, response) = try await session.download(from: remoteURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    unavailable += 1
                    continue
                }
                let ext = remoteURL.pathExtension.remoteTrimmedNonEmpty ?? "jpg"
                let destination = mediaDirectory.appendingPathComponent(
                    String(format: "media-%04d.%@", index + 1, ext.lowercased())
                )
                try fileManager.moveItem(at: temporaryURL, to: destination)
                shareURLs.append(destination)
                packaged += 1
            } catch {
                unavailable += 1
            }
        }

        return OwnerDataExportPackage(
            directoryURL: directory,
            shareURLs: shareURLs,
            packagedMediaCount: packaged,
            unavailableMediaCount: unavailable
        )
    }

    private static func mediaReferences(from object: Any) -> [String] {
        guard let dictionary = object as? [String: Any],
              let references = dictionary["media_references"] as? [String] else { return [] }
        return Array(Set(references)).sorted()
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
