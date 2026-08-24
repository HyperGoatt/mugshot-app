import Testing
@testable import testMugshot

@MainActor
struct TabCoordinatorTests {
    @Test func coldLaunchDefaultsToMap() {
        let coordinator = TabCoordinator()

        #expect(coordinator.selectedTab == 0)
    }

    @Test func composerWithoutPriorTabReturnsToMap() {
        let coordinator = TabCoordinator(selectedTab: 2)

        coordinator.returnFromComposer()

        #expect(coordinator.selectedTab == 0)
    }

    @Test func invalidInitialTabFallsBackToMap() {
        let coordinator = TabCoordinator(selectedTab: 99)

        #expect(coordinator.selectedTab == 0)
    }
}
