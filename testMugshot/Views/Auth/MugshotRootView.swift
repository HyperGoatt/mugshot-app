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
            case .checking, .working:
                AuthLoadingView()
            case .configurationRequired(let message):
                SupabaseConfigurationRequiredView(message: message)
            case .signedOut, .failed:
                AuthEntryView(dataManager: dataManager)
            case .signedIn:
                MainTabView(dataManager: dataManager)
                    .onAppear {
                        SampleDataSeeder.seedSampleData(dataManager: dataManager)
                    }
            }
        }
        .environmentObject(authModel)
        .preferredColorScheme(.light)
        .task {
            await authModel.restoreSession(dataManager: dataManager)
        }
    }
}

