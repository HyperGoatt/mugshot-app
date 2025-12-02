//
//  OnboardingView.swift
//  testMugshot
//
//  Legacy non-animated onboarding. Not currently used; kept for future reference.
//  The app now uses MugshotOnboardingView with ConcentricOnboarding for animated onboarding.
//

import SwiftUI

struct OnboardingView: View {
    let hasLocationPermission: Bool
    let onRequestLocation: () -> Void
    let onComplete: () -> Void
    
    @ObservedObject var dataManager: DataManager
    @State private var currentStep = 0
    @State private var username = ""
    @State private var location = ""
    @State private var ratingTemplate = RatingTemplate()
    
    private var maxStepIndex: Int { 3 } // Welcome, UserInfo, Location, RatingTemplate
    
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            TabView(selection: $currentStep) {
                WelcomeStep()
                    .tag(0)
                
                UserInfoStep(username: $username, location: $location)
                    .tag(1)
                
                LocationPermissionStep(
                    hasLocationPermission: hasLocationPermission,
                    onRequestLocation: onRequestLocation
                )
                    .tag(2)
                
                RatingTemplateStep(ratingTemplate: $ratingTemplate)
                    .tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            VStack {
                Spacer()
                
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                    Spacer()
                    
                    Button(currentStep == maxStepIndex ? "Start using Mugshot" : "Next") {
                        if currentStep == maxStepIndex {
                            completeOnboarding()
                        } else {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(currentStep == 1 && (username.isEmpty || location.isEmpty))
                }
                .padding()
            }
        }
        .onChange(of: hasLocationPermission) {
            if hasLocationPermission && currentStep == 2 {
                // Auto-advance when location permission is granted
                withAnimation(.spring()) {
                    currentStep = min(currentStep + 1, maxStepIndex)
                }
            }
        }
    }
    
    private func completeOnboarding() {
        let user = User(
            username: username,
            location: location,
            bio: ""
        )
        dataManager.setCurrentUser(user)
        dataManager.updateRatingTemplate(ratingTemplate)
        onComplete()
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Mugshot")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.espressoBrown)
            
            Text("Capture every sip.")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.espressoBrown.opacity(0.7))
            
            Spacer()
        }
        .padding()
    }
}

struct UserInfoStep: View {
    @Binding var username: String
    @Binding var location: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Tell us about yourself")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.espressoBrown)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Username")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.espressoBrown)
                
                TextField("@username", text: $username)
                    .foregroundColor(.inputText)
                    .tint(.mugshotMint)
                    .accentColor(.mugshotMint)
                    .padding(12)
                    .background(Color.inputBackground)
                    .cornerRadius(DesignSystem.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                            .stroke(Color.inputBorder, lineWidth: 1)
                    )
                    .autocapitalization(.none)
                
                Text("Location")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.espressoBrown)
                
                TextField("City", text: $location)
                    .foregroundColor(.inputText)
                    .tint(.mugshotMint)
                    .accentColor(.mugshotMint)
                    .padding(12)
                    .background(Color.inputBackground)
                    .cornerRadius(DesignSystem.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                            .stroke(Color.inputBorder, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
}

struct LocationPermissionStep: View {
    let hasLocationPermission: Bool
    let onRequestLocation: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Enable Location")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.espressoBrown)
                .padding(.bottom, 8)
            
            Text("We use your location to find nearby cafes and place your visits on the map.")
                .font(.system(size: 16))
                .foregroundColor(.espressoBrown.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if hasLocationPermission {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.mugshotMint)
                        .font(.system(size: 24))
                    Text("Location enabled")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.espressoBrown)
                }
                .padding()
                .background(Color.sandBeige)
                .cornerRadius(DesignSystem.cornerRadius)
                .padding(.horizontal, 32)
            } else {
                Button(action: {
                    onRequestLocation()
                }) {
                    Text("Enable Location")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.mugshotMint)
                        .foregroundColor(.espressoBrown)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct RatingTemplateStep: View {
    @Binding var ratingTemplate: RatingTemplate
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Your rating preferences")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.espressoBrown)
                .padding(.bottom, 8)
            
            Text("You can customize these later in your profile")
                .font(.system(size: 14))
                .foregroundColor(.espressoBrown.opacity(0.6))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                ForEach(ratingTemplate.categories) { category in
                    HStack {
                        Text(category.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.espressoBrown)
                        
                        Spacer()
                        
                        Text("\(Int(category.weight * 100))%")
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                    }
                    .padding()
                    .background(Color.sandBeige)
                    .cornerRadius(DesignSystem.smallCornerRadius)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
}

