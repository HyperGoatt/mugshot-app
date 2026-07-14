import Foundation
import OSLog

enum SipSaveStage: String {
    case requested
    case validationBlocked
    case awaitingTextOnlyConfirmation
    case localSaveStarted
    case remoteSaveStarted
    case submissionPrepared
    case visitCreated
    case photosUploaded
    case visitFinalized
    case analysisQueued
    case completed
    case failed
}

/// Privacy-safe save diagnostics. These events intentionally contain only a
/// stage and opaque identifiers—never drink text, captions, private notes,
/// ratings, photos, locations, or error descriptions.
enum SipSaveDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "co.mugshot.app",
        category: "SipSave"
    )

    static func record(
        _ stage: SipSaveStage,
        draftID: UUID,
        visitID: UUID? = nil
    ) {
        let visit = visitID?.uuidString.lowercased() ?? "none"
        logger.notice(
            "stage=\(stage.rawValue, privacy: .public) draft_id=\(draftID.uuidString.lowercased(), privacy: .private) visit_id=\(visit, privacy: .private)"
        )
    }
}
