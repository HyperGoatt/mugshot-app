import Foundation
import PostHog

enum DiscoveryFeatureFlag: String, CaseIterable {
    case mapDiscovery = "MugshotFeature.discoveryMap.v1"
    case shareImport = "MugshotFeature.discoveryImport.v1"
    case publicLists = "MugshotFeature.discoveryPublicLists.v1"
    case nearbyReminders = "MugshotFeature.discoveryNearbyReminders.v1"

    var remoteKey: String {
        switch self {
        case .mapDiscovery: "mugshot-discovery-map-v1"
        case .shareImport: "mugshot-discovery-import-v1"
        case .publicLists: "mugshot-discovery-public-lists-v1"
        case .nearbyReminders: "mugshot-discovery-nearby-reminders-v1"
        }
    }
}

enum DiscoveryFeatureFlags {
    static func isEnabled(
        _ flag: DiscoveryFeatureFlag,
        defaults: UserDefaults = .standard
    ) -> Bool {
        if defaults.object(forKey: flag.rawValue) != nil {
            return defaults.bool(forKey: flag.rawValue)
        }

        let remoteValue = PostHogSDK.shared.getFeatureFlag(
            flag.remoteKey,
            sendFeatureFlagEvent: false
        )
        return resolvedEnabled(
            remoteValue: remoteValue,
            defaultValue: buildDefaultEnabled
        )
    }

    static func setEnabled(
        _ enabled: Bool,
        for flag: DiscoveryFeatureFlag,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: flag.rawValue)
    }

    static func resolvedEnabled(
        remoteValue: Any?,
        defaultValue: Bool
    ) -> Bool {
        if let enabled = remoteValue as? Bool {
            return enabled
        }
        if remoteValue is String {
            return true
        }
        return defaultValue
    }

    private static var buildDefaultEnabled: Bool {
#if DEBUG
        true
#else
        false
#endif
    }
}
