//
//  TabCoordinator.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/15/25.
//

import SwiftUI

enum MugshotTab: Int, Codable, CaseIterable, Identifiable, Sendable {
    case map = 0
    case feed = 1
    case add = 2
    case saved = 3
    case journal = 4

    var id: Int { rawValue }
}

@MainActor
final class TabCoordinator: ObservableObject {
    @Published var selectedTab: MugshotTab {
        didSet {
            if selectedTab != .add {
                lastNonAddTab = selectedTab
            }
        }
    }
    private(set) var lastNonAddTab: MugshotTab
    @Published private(set) var pendingMapCafe: Cafe?

    init(selectedTab: MugshotTab = .feed) {
        self.selectedTab = selectedTab
        self.lastNonAddTab = selectedTab == .add ? .feed : selectedTab
    }
    
    func switchToFeed() {
        selectedTab = .feed
    }

    func returnFromComposer(fallback: MugshotTab = .feed) {
        selectedTab = lastNonAddTab == .add ? fallback : lastNonAddTab
    }

    func showCafeOnMap(_ cafe: Cafe) {
        pendingMapCafe = cafe
        selectedTab = .map
    }

    func consumePendingMapCafe() -> Cafe? {
        defer { pendingMapCafe = nil }
        return pendingMapCafe
    }
}
