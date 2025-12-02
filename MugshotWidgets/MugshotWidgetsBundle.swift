//
//  MugshotWidgetsBundle.swift
//  MugshotWidgets
//
//  Widget bundle that registers all Mugshot widgets
//

import WidgetKit
import SwiftUI

@main
struct MugshotWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Alpha widgets (must ship)
        TodaysMugshotWidget()
        FriendsLatestSipsWidget()
        StreakWidget()
        
        // Beta widgets (very doable next)
        FavoritesQuickAccessWidget()
        CafeOfTheDayWidget()
        NearbyCafeWidget()
    }
}
