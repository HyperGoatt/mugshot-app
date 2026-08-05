//
//  testMugshotApp.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import UIKit

@main
struct testMugshotApp: App {
    @UIApplicationDelegateAdaptor(MugshotNotificationAppDelegate.self) private var notificationDelegate
    @StateObject private var dataManager: DataManager
    
    init() {
#if DEBUG
        if !MugshotLaunchEnvironment.isUITesting {
            MugshotAnalytics.shared.configure()
        }
#else
        MugshotAnalytics.shared.configure()
#endif
        PerformanceMonitor.mark("App init")
        let manager = DataManager.shared
#if DEBUG
        MugshotLaunchEnvironment.prepareDebugFailureHooks()
        if MugshotLaunchEnvironment.isUITesting {
            if MugshotLaunchEnvironment.savedAuditScenario != nil,
               MugshotLaunchEnvironment.isUITestingSignedOut {
                manager.prepareGuestSession()
            }
            manager.prepareUITestFixture(reset: MugshotLaunchEnvironment.shouldResetUITestState)
            if MugshotLaunchEnvironment.savedAuditScenario == nil,
               MugshotLaunchEnvironment.isUITestingSignedOut {
                manager.prepareGuestSession()
            }
        }
#endif
        _dataManager = StateObject(wrappedValue: manager)
        // Keep input text legible without painting an inner UIKit background
        // inside SwiftUI's own field surfaces.
        configureTextInputAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            MugshotRootView(dataManager: dataManager)
        }
    }
    
    private func configureTextInputAppearance() {
        // Configure UITextField appearance for light mode
        let textFieldAppearance = UITextField.appearance()
        textFieldAppearance.textColor = UIColor(Color.espressoBrown)
        
        // Configure UITextView appearance for light mode
        let textViewAppearance = UITextView.appearance()
        textViewAppearance.textColor = UIColor(Color.espressoBrown)
    }
}
