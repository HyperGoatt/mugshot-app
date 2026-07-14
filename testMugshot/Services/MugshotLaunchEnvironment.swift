import Foundation

enum MugshotLaunchEnvironment {
    private static let arguments = ProcessInfo.processInfo.arguments
    private static let forcedSaveFailureKey = "MugshotUITest.forcedSaveFailureConsumed"
    private static let authInterruptionKey = "MugshotUITest.authInterruptionConsumed"
    private static let remotePhotoFailureKey = "MugshotDebug.remotePhotoFailureConsumed"

    static let isUITesting = arguments.contains("--ui-testing")
    static let shouldResetUITestState = arguments.contains("--ui-testing-reset")
    static let shouldSeedUITestPhoto = arguments.contains("--ui-testing-seed-photo")

    static func prepareDebugFailureHooks() {
        if arguments.contains("--debug-reset-failure-hooks") {
            UserDefaults.standard.removeObject(forKey: remotePhotoFailureKey)
        }

        guard arguments.contains("--debug-enqueue-media-cleanup"),
              let path = argumentValue(prefix: "--debug-media-cleanup-path="),
              !path.isEmpty,
              let rawUserId = argumentValue(prefix: "--debug-media-cleanup-user-id="),
              let userId = UUID(uuidString: rawUserId) else {
            return
        }
        VisitMediaCleanupStore.shared.enqueue([path], userId: userId)
    }

    static func resetDeterministicFailures() {
        guard isUITesting else { return }
        UserDefaults.standard.removeObject(forKey: forcedSaveFailureKey)
        UserDefaults.standard.removeObject(forKey: authInterruptionKey)
    }

    static func consumeForcedSaveFailure() -> Bool {
        consumeOnce(argument: "--ui-testing-fail-first-save", key: forcedSaveFailureKey)
    }

    static func consumeAuthenticationInterruption() -> Bool {
        consumeOnce(argument: "--ui-testing-interrupt-auth-once", key: authInterruptionKey)
    }

    static func consumeRemotePhotoUploadFailure() -> Bool {
        guard arguments.contains("--debug-fail-first-photo-upload") else { return false }
        guard !UserDefaults.standard.bool(forKey: remotePhotoFailureKey) else { return false }
        UserDefaults.standard.set(true, forKey: remotePhotoFailureKey)
        return true
    }

    private static func consumeOnce(argument: String, key: String) -> Bool {
        guard isUITesting, arguments.contains(argument), !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }

    private static func argumentValue(prefix: String) -> String? {
        arguments.first(where: { $0.hasPrefix(prefix) }).map {
            String($0.dropFirst(prefix.count))
        }
    }
}
