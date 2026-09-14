import Foundation

/// Local telemetry only. Never removes journal, media, Auth or another app's files.
/// The PostHog storage layout is pinned by Package.resolved and checked on upgrades.
struct AnalyticsDeletionQuarantine {
    let applicationSupport: URL
    let bundleIdentifier: String
    private let fileManager = FileManager.default

    static var live: Self {
        Self(
            applicationSupport: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.posthog.unknown"
        )
    }

    private var marker: URL {
        applicationSupport.appendingPathComponent("MugshotAnalyticsSafety/deletion-pending")
    }

    func prepare() throws {
        try fileManager.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("1".utf8).write(to: marker, options: .atomic)
    }

    /// Call only before this process starts the SDK. A stopped SDK can still
    /// finish disk callbacks, so it must not be restarted in the deletion run.
    func purgeBeforeStartup(projectToken: String, discardPriorIdentity: Bool) throws {
        guard discardPriorIdentity || fileManager.fileExists(atPath: marker.path) else { return }
        guard !bundleIdentifier.isEmpty, ![".", ".."].contains(bundleIdentifier), !bundleIdentifier.contains("/"),
              projectToken.hasPrefix("phc_"),
              projectToken.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "_" }) else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let base = applicationSupport.appendingPathComponent(bundleIdentifier, isDirectory: true)
        if fileManager.fileExists(atPath: base.path) {
            guard try base.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                throw CocoaError(.fileReadNoPermission)
            }
            let project = base.appendingPathComponent(projectToken, isDirectory: true)
            if fileManager.fileExists(atPath: project.path) {
                try fileManager.removeItem(at: project)
            }
            // Pre-token-directory PostHog versions migrate these files at setup.
            for item in try fileManager.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
                where item.lastPathComponent.hasPrefix("posthog.") {
                try fileManager.removeItem(at: item)
            }
        }
        if fileManager.fileExists(atPath: marker.path) {
            try fileManager.removeItem(at: marker)
        }
    }
}
