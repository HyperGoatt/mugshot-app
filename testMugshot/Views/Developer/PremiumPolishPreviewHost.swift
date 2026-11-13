#if DEBUG
import SwiftUI

/// Local-only failure fixtures. No authenticated user, RPC or network transport.
struct PremiumPolishPreviewHost: View {
    @StateObject private var discovery = makeDiscoveryStore()
    private let owner = UUID(uuidString: "10000000-0000-4000-8000-000000000013")!

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Discovery recovery") {
                    FriendsDiscoverabilitySettingsView(previewStore: discovery, accountID: owner)
                }
                NavigationLink("Reflection recovery") {
                    ReflectionPreferencesView(previewTransport: Self.reflectionTransport())
                }
                NavigationLink("Map key") {
                    ScrollView {
                        RatingsLegend(showsFriendContext: false).padding(20)
                    }
                    .background(Color.creamWhite)
                    .navigationTitle("Map key")
                }
            }
            .navigationTitle("Polish fixtures")
        }
    }

    private static func reflectionTransport() -> ReflectionPreferencesView.PreviewTransport {
        let owner = UUID(uuidString: "10000000-0000-4000-8000-000000000014")!
        var reads = 0
        var writes = 0
        return .init(owner: owner, fetch: {
            reads += 1
            if reads == 1 { throw URLError(.notConnectedToInternet) }
            return UserReflectionPreferences(userID: owner, monthlyRecaps: true,
                yearlyRecaps: true, onThisSipReminders: false, reflectionReminders: false)
        }, save: { value in
            writes += 1
            if writes == 1 { throw URLError(.networkConnectionLost) }
            return value
        })
    }

    private static func makeDiscoveryStore() -> DiscoveryPreferencesStore {
        var reads = 0
        var confirmed = PeopleDiscoveryPreferences(emailDiscoverable: false,
            suggestionsEnabled: true, mutualExplanationsEnabled: true,
            consentVersion: nil, version: 1, hasDiscoveryEmail: false)
        return DiscoveryPreferencesStore(fetch: { _ in
            reads += 1
            try await Task.sleep(for: .milliseconds(250))
            if reads == 1 { throw URLError(.notConnectedToInternet) }
            return confirmed
        }, save: { _, proposed in
            confirmed = proposed
            try await Task.sleep(for: .milliseconds(250))
            throw URLError(.networkConnectionLost)
        })
    }
}
#endif
