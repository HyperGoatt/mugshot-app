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
            if MugshotLaunchEnvironment.isUITesting {
                MainTabView(dataManager: dataManager)
            } else {
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
        }
        .environmentObject(authModel)
        .preferredColorScheme(.light)
        .task {
            guard !MugshotLaunchEnvironment.isUITesting else { return }
            await PerformanceMonitor.measure("Session restore") {
                await authModel.restoreSession(dataManager: dataManager)
            }
        }
    }
}
