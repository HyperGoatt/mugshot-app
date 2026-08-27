import Foundation
import Testing
@testable import testMugshot

@MainActor
struct TabCoordinatorTests {
    @Test func tabIdentityPreservesApprovedVisualOrderAndLegacyRawValues() throws {
        #expect(MugshotTab.allCases == [.map, .feed, .add, .saved, .journal])
        #expect(MugshotTab.allCases.map(\.rawValue) == [0, 1, 2, 3, 4])
        let encoded = try JSONEncoder().encode(MugshotTab.feed)
        #expect(try JSONDecoder().decode(MugshotTab.self, from: encoded) == .feed)
    }

    @Test func signedInColdLaunchDefaultsToFeed() {
        let coordinator = TabCoordinator()

        #expect(coordinator.selectedTab == .feed)
    }

    @Test func composerWithoutPriorTabReturnsToFeed() {
        let coordinator = TabCoordinator(selectedTab: .add)

        coordinator.returnFromComposer()

        #expect(coordinator.selectedTab == .feed)
    }

    @Test func composerReturnsToLastNonAddTab() {
        let coordinator = TabCoordinator(selectedTab: .map)
        coordinator.selectedTab = .add

        coordinator.returnFromComposer()

        #expect(coordinator.selectedTab == .map)
    }
}
