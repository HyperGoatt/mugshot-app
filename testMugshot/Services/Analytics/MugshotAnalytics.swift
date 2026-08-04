import Foundation
import PostHog

struct MugshotAnalyticsConfiguration: Equatable {
    let projectToken: String
    let host: URL

    init?(infoDictionary: [String: Any]) {
        guard let projectToken = Self.resolvedString(
            infoDictionary["MUGSHOT_POSTHOG_PROJECT_TOKEN"]
        ),
        projectToken.hasPrefix("phc_"),
        let hostValue = Self.resolvedString(
            infoDictionary["MUGSHOT_POSTHOG_HOST"]
        ),
        let host = URL(string: hostValue),
        host.scheme?.lowercased() == "https",
        host.host != nil else {
            return nil
        }

        self.projectToken = projectToken
        self.host = host
    }

    private static func resolvedString(_ rawValue: Any?) -> String? {
        guard let value = rawValue as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("$("),
              !trimmed.contains("REPLACE_ME") else {
            return nil
        }
        return trimmed
    }
}

enum MugshotAnalyticsPropertyValue: Equatable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)

    var postHogValue: Any {
        switch self {
        case .string(let value): value
        case .integer(let value): value
        case .double(let value): value
        case .boolean(let value): value
        }
    }
}

struct MugshotAnalyticsPayload: Equatable {
    let event: String
    let properties: [String: MugshotAnalyticsPropertyValue]
}

enum MugshotAnalyticsScreen: String {
    case map
    case feed
    case sipComposer = "sip_composer"
    case saved
    case journal
    case passport
    case sipDetail = "sip_detail"
    case capturePreferences = "capture_preferences"
    case activityCenter = "activity_center"
    case shareHub = "share_hub"
}

enum MugshotAnalyticsScreenSource: String {
    case tab
    case navigation
    case sheet
    case deepLink = "deep_link"
    case postPublish = "post_publish"
    case notification
}

enum MugshotAuthenticationFlow: String {
    case signIn = "sign_in"
    case signUp = "sign_up"
    case sessionRestore = "session_restore"
    case accountRecovery = "account_recovery"
}

enum MugshotAuthenticationMethod: String {
    case email
    case apple
    case google
    case persistedSession = "persisted_session"
    case deepLink = "deep_link"
}

enum MugshotAnalyticsErrorCode: String {
    case authentication
    case configuration
    case network
    case permission
    case persistence
    case remoteService = "remote_service"
    case validation
    case unknown

    init(error: Error) {
        if error is URLError {
            self = .network
            return
        }

        let typeName = String(describing: type(of: error)).lowercased()
        if typeName.contains("auth") || typeName.contains("session") {
            self = .authentication
        } else if typeName.contains("config") {
            self = .configuration
        } else if typeName.contains("permission") || typeName.contains("authorization") {
            self = .permission
        } else if typeName.contains("store") || typeName.contains("cache") || typeName.contains("file") {
            self = .persistence
        } else if typeName.contains("supabase") || typeName.contains("postgrest") || typeName.contains("http") {
            self = .remoteService
        } else {
            self = .unknown
        }
    }
}

enum MugshotSipPublishBlockReason: String {
    case accountMismatch = "account_mismatch"
    case cafeRequired = "cafe_required"
    case contextNameRequired = "context_name_required"
    case drinkNameRequired = "drink_name_required"
    case visualRequired = "visual_required"
    case captionRequired = "caption_required"
    case captionTooLong = "caption_too_long"
    case privateNoteTooLong = "private_note_too_long"
    case contextNoteTooLong = "context_note_too_long"
    case tastingLensIncomplete = "tasting_lens_incomplete"
    case sipScoreRequired = "sip_score_required"
    case contextScoreRequired = "context_score_required"
    case recipeSourceRequired = "recipe_source_required"
    case recipeAudienceBlocked = "recipe_audience_blocked"
    case sharedAudienceRequired = "shared_audience_required"
    case sharedPrimaryRequired = "shared_primary_required"
    case publicContentRequired = "public_content_required"
    case textOnlyConfirmation = "text_only_confirmation"
    case authenticationRequired = "authentication_required"
    case pendingConflict = "pending_conflict"
    case unknown
}

enum MugshotSipRecoveryState: String {
    case none
    case protectedRetry = "protected_retry"
    case publicationProtected = "publication_protected"
    case localDraft = "local_draft"
}

enum MugshotCafeState: String {
    case favorite
    case wantToTry = "want_to_try"
}

enum MugshotAnalyticsMutationAction: String {
    case added
    case removed
}

enum MugshotAnalyticsSurface: String {
    case map
    case saved
    case feed
    case sipDetail = "sip_detail"
    case remoteSipDetail = "remote_sip_detail"
}

enum MugshotAnalyticsShareAction: String {
    case hubViewed = "share_hub_viewed"
    case formatSelected = "share_format_selected"
    case templateSelected = "share_template_selected"
    case photoLayoutSelected = "share_photo_layout_selected"
    case destinationTapped = "share_destination_tapped"
    case handoffOpened = "share_handoff_opened"
    case handoffFailed = "share_handoff_failed"
    case systemShareCompleted = "system_share_completed"
    case hubDismissed = "share_hub_dismissed"
}

struct MugshotSipAnalyticsSnapshot: Equatable {
    let entryPoint: String
    let context: String
    let step: String
    let visibility: String
    let captureMode: String
    let isDraftResume: Bool
    let hasPhoto: Bool
    let usesPhotoPlaceholder: Bool
    let hasCaption: Bool
    let hasPrivateNote: Bool
    let hasContextNote: Bool
    let sipCriteriaCount: Int
    let contextCriteriaCount: Int

    init(draft: SipDraft, photoCount: Int, isDraftResume: Bool) {
        entryPoint = Self.entryPoint(draft.launchContext.source)
        context = draft.context.rawValue.lowercased()
        step = (draft.v3Step ?? .setup).rawValue
        visibility = draft.visibility.rawValue.lowercased()
        captureMode = Self.captureMode(draft.captureMode)
        self.isDraftResume = isDraftResume
        hasPhoto = photoCount > 0
        usesPhotoPlaceholder = draft.photoFallback != nil
        hasCaption = draft.socialCaption.remoteTrimmedNonEmpty != nil
        hasPrivateNote = draft.privateNotes.remoteTrimmedNonEmpty != nil
        hasContextNote = draft.contextNotes.remoteTrimmedNonEmpty != nil
        sipCriteriaCount = min(max(draft.ratingCriteria.count, 0), 20)
        contextCriteriaCount = min(max(draft.contextRatingCriteria.count, 0), 20)
    }

    fileprivate var properties: [String: MugshotAnalyticsPropertyValue] {
        [
            "entry_point": .string(entryPoint),
            "context": .string(context),
            "step": .string(step),
            "visibility": .string(visibility),
            "capture_mode": .string(captureMode),
            "is_draft_resume": .boolean(isDraftResume),
            "has_photo": .boolean(hasPhoto),
            "uses_photo_placeholder": .boolean(usesPhotoPlaceholder),
            "has_caption": .boolean(hasCaption),
            "has_private_note": .boolean(hasPrivateNote),
            "has_context_note": .boolean(hasContextNote),
            "sip_criteria_count": .integer(sipCriteriaCount),
            "context_criteria_count": .integer(contextCriteriaCount)
        ]
    }

    private static func entryPoint(_ source: SipComposerSource) -> String {
        switch source {
        case .centralAdd: "central_add"
        case .map: "map"
        case .saved: "saved"
        case .cafeDetail: "cafe_detail"
        case .repeatSip: "repeat_sip"
        case .addAnotherSip: "add_another_sip"
        case .brewAgain: "brew_again"
        case .widget: "widget"
        case .appShortcut: "app_shortcut"
        case .camera: "camera"
        }
    }

    private static func captureMode(_ mode: SipCaptureMode) -> String {
        switch mode {
        case .quickSip: "quick_sip"
        case .addDetails: "add_details"
        }
    }
}

enum MugshotAnalyticsEvent: Equatable {
    case screenViewed(MugshotAnalyticsScreen, source: MugshotAnalyticsScreenSource)
    case authenticationCompleted(
        flow: MugshotAuthenticationFlow,
        method: MugshotAuthenticationMethod
    )
    case authenticationFailed(
        flow: MugshotAuthenticationFlow,
        method: MugshotAuthenticationMethod,
        errorCode: MugshotAnalyticsErrorCode
    )
    case accountSignedOut(usedLocalFallback: Bool)
    case capturePreferencesViewed(allowsSkipping: Bool)
    case capturePreferencesCompleted(
        selectedDrinkFamilyCount: Int,
        selectedDiscoveryIntentCount: Int,
        hasHabit: Bool
    )
    case capturePreferencesSkipped
    case sipComposerOpened(MugshotSipAnalyticsSnapshot)
    case sipContextSelected(MugshotSipAnalyticsSnapshot)
    case sipStepViewed(MugshotSipAnalyticsSnapshot)
    case sipPublishAttempted(MugshotSipAnalyticsSnapshot, isRecovery: Bool)
    case sipPublishBlocked(
        MugshotSipAnalyticsSnapshot,
        reason: MugshotSipPublishBlockReason
    )
    case sipPublished(
        MugshotSipAnalyticsSnapshot,
        durationSeconds: Int,
        isRemote: Bool,
        wasRecovery: Bool
    )
    case sipPublishFailed(
        MugshotSipAnalyticsSnapshot,
        errorCode: MugshotAnalyticsErrorCode,
        recoveryState: MugshotSipRecoveryState
    )
    case sipDraftSaved(
        MugshotSipAnalyticsSnapshot,
        durationSeconds: Int
    )
    case sipRecoveryResumed(MugshotSipAnalyticsSnapshot)
    case sipPublicationDeduplicated(MugshotSipAnalyticsSnapshot)
    case cafeStateChanged(
        state: MugshotCafeState,
        action: MugshotAnalyticsMutationAction,
        surface: MugshotAnalyticsSurface
    )
    case sipLiked(
        action: MugshotAnalyticsMutationAction,
        surface: MugshotAnalyticsSurface
    )
    case commentAdded(surface: MugshotAnalyticsSurface)
    case share(
        action: MugshotAnalyticsShareAction,
        destination: String?,
        format: String?,
        template: String?,
        photoLayout: String?,
        visibility: String,
        hasPublicLink: Bool
    )

    var payload: MugshotAnalyticsPayload {
        switch self {
        case .screenViewed(let screen, let source):
            return payload(
                "screen_viewed",
                [
                    "screen_name": .string(screen.rawValue),
                    "source": .string(source.rawValue)
                ]
            )
        case .authenticationCompleted(let flow, let method):
            return authenticationPayload(
                "authentication_completed",
                flow: flow,
                method: method
            )
        case .authenticationFailed(let flow, let method, let errorCode):
            var properties = authenticationProperties(flow: flow, method: method)
            properties["error_code"] = .string(errorCode.rawValue)
            return payload("authentication_failed", properties)
        case .accountSignedOut(let usedLocalFallback):
            return payload(
                "account_signed_out",
                ["used_local_fallback": .boolean(usedLocalFallback)]
            )
        case .capturePreferencesViewed(let allowsSkipping):
            return payload(
                "capture_preferences_viewed",
                ["allows_skipping": .boolean(allowsSkipping)]
            )
        case .capturePreferencesCompleted(
            let drinkFamilyCount,
            let discoveryIntentCount,
            let hasHabit
        ):
            return payload(
                "capture_preferences_completed",
                [
                    "drink_family_count": .integer(min(max(drinkFamilyCount, 0), 4)),
                    "discovery_intent_count": .integer(
                        min(max(discoveryIntentCount, 0), 4)
                    ),
                    "has_habit": .boolean(hasHabit)
                ]
            )
        case .capturePreferencesSkipped:
            return payload("capture_preferences_skipped")
        case .sipComposerOpened(let snapshot):
            return sipPayload("sip_composer_opened", snapshot: snapshot)
        case .sipContextSelected(let snapshot):
            return sipPayload("sip_context_selected", snapshot: snapshot)
        case .sipStepViewed(let snapshot):
            return sipPayload("sip_step_viewed", snapshot: snapshot)
        case .sipPublishAttempted(let snapshot, let isRecovery):
            return sipPayload(
                "sip_publish_attempted",
                snapshot: snapshot,
                additional: ["is_recovery": .boolean(isRecovery)]
            )
        case .sipPublishBlocked(let snapshot, let reason):
            return sipPayload(
                "sip_publish_blocked",
                snapshot: snapshot,
                additional: ["reason": .string(reason.rawValue)]
            )
        case .sipPublished(
            let snapshot,
            let durationSeconds,
            let isRemote,
            let wasRecovery
        ):
            return sipPayload(
                "sip_published",
                snapshot: snapshot,
                additional: [
                    "duration_seconds": .integer(Self.boundedDuration(durationSeconds)),
                    "is_remote": .boolean(isRemote),
                    "was_recovery": .boolean(wasRecovery)
                ]
            )
        case .sipPublishFailed(let snapshot, let errorCode, let recoveryState):
            return sipPayload(
                "sip_publish_failed",
                snapshot: snapshot,
                additional: [
                    "error_code": .string(errorCode.rawValue),
                    "recovery_state": .string(recoveryState.rawValue)
                ]
            )
        case .sipDraftSaved(let snapshot, let durationSeconds):
            return sipPayload(
                "sip_draft_saved",
                snapshot: snapshot,
                additional: [
                    "duration_seconds": .integer(Self.boundedDuration(durationSeconds))
                ]
            )
        case .sipRecoveryResumed(let snapshot):
            return sipPayload("sip_recovery_resumed", snapshot: snapshot)
        case .sipPublicationDeduplicated(let snapshot):
            return sipPayload("sip_publication_deduplicated", snapshot: snapshot)
        case .cafeStateChanged(let state, let action, let surface):
            return payload(
                "cafe_state_changed",
                [
                    "state": .string(state.rawValue),
                    "action": .string(action.rawValue),
                    "surface": .string(surface.rawValue)
                ]
            )
        case .sipLiked(let action, let surface):
            return payload(
                "sip_liked",
                [
                    "action": .string(action.rawValue),
                    "surface": .string(surface.rawValue)
                ]
            )
        case .commentAdded(let surface):
            return payload(
                "comment_added",
                ["surface": .string(surface.rawValue)]
            )
        case .share(
            let action,
            let destination,
            let format,
            let template,
            let photoLayout,
            let visibility,
            let hasPublicLink
        ):
            var properties: [String: MugshotAnalyticsPropertyValue] = [
                "visibility": .string(visibility),
                "has_public_link": .boolean(hasPublicLink)
            ]
            if let destination {
                properties["destination"] = .string(destination)
            }
            if let format {
                properties["format"] = .string(format)
            }
            if let template {
                properties["template"] = .string(template)
            }
            if let photoLayout {
                properties["photo_layout"] = .string(photoLayout)
            }
            return payload(action.rawValue, properties)
        }
    }

    private func authenticationPayload(
        _ event: String,
        flow: MugshotAuthenticationFlow,
        method: MugshotAuthenticationMethod
    ) -> MugshotAnalyticsPayload {
        payload(
            event,
            authenticationProperties(flow: flow, method: method)
        )
    }

    private func authenticationProperties(
        flow: MugshotAuthenticationFlow,
        method: MugshotAuthenticationMethod
    ) -> [String: MugshotAnalyticsPropertyValue] {
        [
            "auth_flow": .string(flow.rawValue),
            "auth_method": .string(method.rawValue)
        ]
    }

    private func sipPayload(
        _ event: String,
        snapshot: MugshotSipAnalyticsSnapshot,
        additional: [String: MugshotAnalyticsPropertyValue] = [:]
    ) -> MugshotAnalyticsPayload {
        payload(event, snapshot.properties.merging(additional) { _, new in new })
    }

    private func payload(
        _ event: String,
        _ properties: [String: MugshotAnalyticsPropertyValue] = [:]
    ) -> MugshotAnalyticsPayload {
        MugshotAnalyticsPayload(event: event, properties: properties)
    }

    private static func boundedDuration(_ durationSeconds: Int) -> Int {
        min(max(durationSeconds, 0), 14_400)
    }
}

protocol MugshotAnalyticsTransport: AnyObject {
    func configure(_ configuration: MugshotAnalyticsConfiguration)
    func capture(_ payload: MugshotAnalyticsPayload)
    func identify(distinctID: String)
    func reset()
}

private final class PostHogMugshotAnalyticsTransport: MugshotAnalyticsTransport {
    func configure(_ configuration: MugshotAnalyticsConfiguration) {
        let config = PostHogConfig(
            projectToken: configuration.projectToken,
            host: configuration.host.absoluteString
        )
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.sessionReplay = false
        config.surveys = false
        config.enableSwizzling = false
        PostHogSDK.shared.setup(config)
    }

    func capture(_ payload: MugshotAnalyticsPayload) {
        PostHogSDK.shared.capture(
            payload.event,
            properties: payload.properties.mapValues(\.postHogValue)
        )
    }

    func identify(distinctID: String) {
        PostHogSDK.shared.identify(distinctID)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }
}

final class MugshotAnalytics {
    static let shared = MugshotAnalytics(
        transport: PostHogMugshotAnalyticsTransport()
    )

    private let transport: MugshotAnalyticsTransport
    private let metadata: [String: MugshotAnalyticsPropertyValue]
    private(set) var isConfigured = false
    private(set) var isAuthenticated = false

    init(
        transport: MugshotAnalyticsTransport,
        bundle: Bundle = .main,
        buildConfiguration: String = {
#if DEBUG
            "debug"
#else
            "release"
#endif
        }()
    ) {
        self.transport = transport
        metadata = [
            "analytics_version": .integer(1),
            "platform": .string("ios"),
            "app_version": .string(
                bundle.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "unknown"
            ),
            "app_build": .string(
                bundle.object(
                    forInfoDictionaryKey: "CFBundleVersion"
                ) as? String ?? "unknown"
            ),
            "build_configuration": .string(buildConfiguration)
        ]
    }

    func configure(
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) {
        guard !isConfigured,
              let configuration = MugshotAnalyticsConfiguration(
                infoDictionary: infoDictionary
              ) else {
            return
        }
        transport.configure(configuration)
        isConfigured = true
    }

    func capture(_ event: MugshotAnalyticsEvent) {
        guard isConfigured else { return }
        let eventPayload = event.payload
        let properties = metadata
            .merging(eventPayload.properties) { _, eventValue in eventValue }
            .merging(
                ["is_authenticated": .boolean(isAuthenticated)]
            ) { _, currentValue in currentValue }
        transport.capture(
            MugshotAnalyticsPayload(
                event: eventPayload.event,
                properties: properties
            )
        )
    }

    func identify(userID: UUID) {
        guard isConfigured else { return }
        transport.identify(distinctID: userID.uuidString.lowercased())
        isAuthenticated = true
    }

    func reset() {
        guard isConfigured else { return }
        transport.reset()
        isAuthenticated = false
    }
}
