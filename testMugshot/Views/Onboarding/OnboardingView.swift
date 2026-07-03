//
//  OnboardingView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var dataManager: DataManager
    @State private var currentStep = 0
    @State private var username = ""
    @State private var location = ""
    @State private var ratingTemplate = RatingTemplate()
    
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            TabView(selection: $currentStep) {
                WelcomeStep()
                    .tag(0)
                
                UserInfoStep(username: $username, location: $location)
                    .tag(1)
                
                RatingTemplateStep(ratingTemplate: $ratingTemplate)
                    .tag(2)
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
                    
                    Button(currentStep == 2 ? "Start sipping" : "Next") {
                        if currentStep == 2 {
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
                .background(Color.creamWhite.opacity(0.94))
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
        dataManager.completeOnboarding()
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image("MugshotAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 7)
            
            Text("Mugshot")
                .mugshotDisplay(size: 44)
                .foregroundColor(.espressoBrown)
            
            Text("Sip. Save. Share.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.roastBrown)

            VStack(spacing: 10) {
                OnboardingValueRow(icon: "camera.fill", title: "Photo-backed logs", detail: "Remember what you drank and where it was worth returning.")
                OnboardingValueRow(icon: "bookmark.fill", title: "Saved cafes", detail: "Build a calm list of favorites and places to try.")
                OnboardingValueRow(icon: "person.2.fill", title: "Social without noise", detail: "See friend-powered recommendations when the beta loop is ready.")
            }
            .padding(16)
            .cardStyle(radius: DesignSystem.Radius.heroCard)
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .padding()
    }
}

struct OnboardingValueRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .frame(width: 32, height: 32)
                .background(Color.mugshotMint.opacity(0.22))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

struct UserInfoStep: View {
    @Binding var username: String
    @Binding var location: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Make it yours")
                .mugshotDisplay(size: 34)
                .foregroundColor(.espressoBrown)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 16) {
                MugshotSectionTitle(title: "Profile basics", subtitle: "This is how your sips show up in Feed and Profile.")

                Text("Username")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                TextField("@username", text: $username)
                    .mugshotFormField()
                    .autocapitalization(.none)
                
                Text("Location")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                TextField("City", text: $location)
                    .mugshotFormField()
            }
            .padding(18)
            .cardStyle(radius: DesignSystem.Radius.heroCard)
            .padding(.horizontal, 24)
            
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
            
            Text("Rate your ritual")
                .mugshotDisplay(size: 34)
                .foregroundColor(.espressoBrown)
                .padding(.bottom, 8)
            
            Text("Mugshot starts with a balanced taste template. You can tune it later.")
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
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
                    .background(Color.sandBeige.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                }
            }
            .padding(18)
            .cardStyle(radius: DesignSystem.Radius.heroCard)
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding()
    }
}
