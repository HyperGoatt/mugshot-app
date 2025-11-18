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
    @StateObject private var dataManager = DataManager.shared
    
    init() {
        // Configure UITextField and UITextView to use light mode colors
        configureTextInputAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            if !dataManager.appData.hasSeenMarketingOnboarding {
                MugshotOnboardingView(dataManager: dataManager)
                    .preferredColorScheme(.light) // Lock to light mode
            } else if !dataManager.appData.isAuthenticated {
                AuthFlowRootView()
                    .environmentObject(dataManager)
                    .environmentObject(HapticsManager.shared)
                    .preferredColorScheme(.light) // Lock to light mode
            } else if !dataManager.appData.hasCompletedProfileSetup {
                ProfileSetupOnboardingView()
                    .environmentObject(dataManager)
                    .environmentObject(HapticsManager.shared)
                    .preferredColorScheme(.light) // Lock to light mode
            } else {
                MainTabView(dataManager: dataManager)
                    .onAppear {
                        // Seed sample data if needed
                        SampleDataSeeder.seedSampleData(dataManager: dataManager)
                    }
                    .preferredColorScheme(.light) // Lock to light mode
            }
        }
    }
    
    private func configureTextInputAppearance() {
        // Configure UITextField appearance for light mode
        let textFieldAppearance = UITextField.appearance()
        textFieldAppearance.textColor = UIColor(Color.espressoBrown)
        textFieldAppearance.backgroundColor = UIColor(Color.creamWhite)
        
        // Configure UITextView appearance for light mode
        let textViewAppearance = UITextView.appearance()
        textViewAppearance.textColor = UIColor(Color.espressoBrown)
        textViewAppearance.backgroundColor = UIColor(Color.creamWhite)
    }
}
