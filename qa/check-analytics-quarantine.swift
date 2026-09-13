import Foundation

@main
struct AnalyticsQuarantineCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let base = root.appendingPathComponent("test.bundle")
        let sdk = base.appendingPathComponent("phc_synthetic")
        try fm.createDirectory(at: sdk, withIntermediateDirectories: true)
        try Data("queued".utf8).write(to: sdk.appendingPathComponent("posthog.queueFolder.uuid"))
        try Data("legacy".utf8).write(to: base.appendingPathComponent("posthog.queue.plist"))
        let journal = base.appendingPathComponent("journal.json")
        try Data("keep".utf8).write(to: journal)
        let otherProject = base.appendingPathComponent("phc_other")
        try fm.createDirectory(at: otherProject, withIntermediateDirectories: true)
        let policy = AnalyticsDeletionQuarantine(applicationSupport: root, bundleIdentifier: "test.bundle")
        try policy.purgeBeforeStartup(projectToken: "phc_synthetic", discardPriorIdentity: false)
        precondition(fm.fileExists(atPath: sdk.path), "Ordinary startup preserves the queue")
        try policy.prepare()
        // A new instance represents a new process reading the durable marker.
        try AnalyticsDeletionQuarantine(applicationSupport: root, bundleIdentifier: "test.bundle")
            .purgeBeforeStartup(projectToken: "phc_synthetic", discardPriorIdentity: false)
        precondition(!fm.fileExists(atPath: sdk.path), "Marked project queue removed")
        precondition(!fm.fileExists(atPath: base.appendingPathComponent("posthog.queue.plist").path))
        precondition(fm.fileExists(atPath: journal.path) && fm.fileExists(atPath: otherProject.path))
        try fm.createDirectory(at: sdk, withIntermediateDirectories: true)
        try policy.purgeBeforeStartup(projectToken: "phc_synthetic", discardPriorIdentity: false)
        precondition(fm.fileExists(atPath: sdk.path), "Successful purge clears the marker")
        try policy.purgeBeforeStartup(projectToken: "phc_synthetic", discardPriorIdentity: true)
        precondition(!fm.fileExists(atPath: sdk.path), "Signed-out startup discards old identity")
        try policy.prepare()
        do {
            try policy.purgeBeforeStartup(projectToken: "phc_../outside", discardPriorIdentity: false)
            fatalError("Invalid project token accepted")
        } catch {}
        let outside = root.appendingPathComponent("outside")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try fm.removeItem(at: base)
        try fm.createSymbolicLink(at: base, withDestinationURL: outside)
        do {
            try policy.purgeBeforeStartup(projectToken: "phc_synthetic", discardPriorIdentity: false)
            fatalError("Symlink base accepted")
        } catch {}
        print("PASS analytics quarantine: durable marker, exact namespace, legacy queues, unrelated-file preservation, signed-out disposal and path guards")
    }
}
