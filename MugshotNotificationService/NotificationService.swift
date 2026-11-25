import Foundation
import UserNotifications

/// Enriches an already meaningful alert with reviewed, bundled Mugsy artwork.
/// There is no network client, credential access, or personal-media loading.
final class NotificationService: UNNotificationServiceExtension {
    private let stateLock = NSLock()
    private var completion: MugsyNotificationCompletionGate<UNNotificationContent>?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let gate = MugsyNotificationCompletionGate(fallback: request.content, handler: contentHandler)
        stateLock.lock()
        let previous = completion
        completion = gate
        stateLock.unlock()
        previous?.finish()

        guard let asset = MugsyNotificationAttachmentPolicy.assetIdentifier(userInfo: request.content.userInfo),
              let source = Bundle.main.url(forResource: asset, withExtension: "png"),
              let enriched = request.content.mutableCopy() as? UNMutableNotificationContent else {
            gate.finish()
            return
        }

        // Unique directories avoid collisions between overlapping deliveries.
        // The OS manages the extension's temporary storage and attachment data.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mugsy-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let localFile = directory.appendingPathComponent("mugsy.png")
            try FileManager.default.copyItem(at: source, to: localFile)
            let attachment = try UNNotificationAttachment(identifier: "mugsy", url: localFile)
            enriched.attachments = [attachment]
            gate.finish(enriched)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            gate.finish()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        stateLock.lock()
        let gate = completion
        stateLock.unlock()
        gate?.finish()
    }
}
