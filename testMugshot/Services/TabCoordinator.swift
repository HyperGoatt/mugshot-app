//
//  TabCoordinator.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/15/25.
//

import SwiftUI

class TabCoordinator: ObservableObject {
    @Published var selectedTab: Int = 1
    
    func switchToFeed() {
        selectedTab = 1
    }
}
