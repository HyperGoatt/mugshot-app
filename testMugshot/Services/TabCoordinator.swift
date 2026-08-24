//
//  TabCoordinator.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/15/25.
//

import SwiftUI

class TabCoordinator: ObservableObject {
    @Published var selectedTab: Int {
        didSet {
            if selectedTab != 2 {
                lastNonAddTab = selectedTab
            }
        }
    }
    private(set) var lastNonAddTab: Int
    @Published private(set) var pendingMapCafe: Cafe?

    init(selectedTab: Int = 0) {
        let safeTab = (0...4).contains(selectedTab) ? selectedTab : 0
        self.selectedTab = safeTab
        self.lastNonAddTab = safeTab == 2 ? 0 : safeTab
    }
    
    func switchToFeed() {
        selectedTab = 1
    }

    func returnFromComposer(fallback: Int = 4) {
        selectedTab = lastNonAddTab == 2 ? fallback : lastNonAddTab
    }

    func showCafeOnMap(_ cafe: Cafe) {
        pendingMapCafe = cafe
        selectedTab = 0
    }

    func consumePendingMapCafe() -> Cafe? {
        defer { pendingMapCafe = nil }
        return pendingMapCafe
    }
}
