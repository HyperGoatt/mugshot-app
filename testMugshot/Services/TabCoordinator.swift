//
//  TabCoordinator.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/15/25.
//

import SwiftUI

class TabCoordinator: ObservableObject {
    @Published var selectedTab: Int = 1 {
        didSet {
            if selectedTab != 2 {
                lastNonAddTab = selectedTab
            }
        }
    }
    private(set) var lastNonAddTab: Int = 1
    
    func switchToFeed() {
        selectedTab = 1
    }

    func returnFromComposer(fallback: Int = 4) {
        selectedTab = lastNonAddTab == 2 ? fallback : lastNonAddTab
    }
}
