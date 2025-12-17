//
//  Light20SocialHubView.swift
//  testMugshot
//
//  Light 2.0 social hub with friends list and activity
//  Clean card layout with mint accents
//

import SwiftUI

/// Light 2.0 Social Hub simply wraps the existing FriendsHubView to reuse friend logic.
struct Light20SocialHubView: View {
    @ObservedObject var dataManager: DataManager
    
    var body: some View {
        FriendsHubView(dataManager: dataManager)
    }
}


