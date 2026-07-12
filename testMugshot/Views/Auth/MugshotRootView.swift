//
//  MugshotRootView.swift
//  testMugshot
//

import SwiftUI

struct MugshotRootView: View {
    @ObservedObject var dataManager: DataManager
    @StateObject private var authModel = AppAuthModel()
    
    var body: some View {
        Group {
            switch authModel.status {
            case .checking:
                AuthLoadingView()
            case .configurationRequired(let message):
                SupabaseConfigurationRequiredView(message: message)
            case .working, .signedOut, .failed:
                AuthEntryView(dataManager: dataManager)
            case .signedIn:
                MainTabView(dataManager: dataManager)
            }
        }
        .environmentObject(authModel)
        .preferredColorScheme(.light)
        .task {
            await PerformanceMonitor.measure("Session restore") {
                await authModel.restoreSession(dataManager: dataManager)
            }
        }
    }
}
