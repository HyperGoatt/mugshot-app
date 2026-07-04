//
//  AuthEntryView.swift
//  testMugshot
//

import SwiftUI

struct AuthEntryView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    
    @State private var isCreatingAccount = false
    @State private var email = ""
    @State private var password = ""
    
    private var isBusy: Bool {
        if case .working = authModel.status {
            return true
        }
        return false
    }
    
    private var message: String? {
        switch authModel.status {
        case .signedOut(let message):
            return message
        case .failed(let message):
            return message
        default:
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 42)
                    
                    VStack(spacing: 10) {
                        Image("MugshotAppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 5)

                        Text("Mugshot")
                            .mugshotDisplay(size: 42)
                            .foregroundColor(.espressoBrown)
                        
                        Text(isCreatingAccount ? "Start your sip journal." : "Savor more. Share better.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        MugshotSectionTitle(
                            title: isCreatingAccount ? "Create your account" : "Welcome back",
                            subtitle: "Your photo-backed sips, saved cafes, notes, and ratings stay with you."
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            
                            TextField("you@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .authFieldStyle()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            
                            SecureField("Password", text: $password)
                                .textContentType(isCreatingAccount ? .newPassword : .password)
                                .authFieldStyle()
                        }
                        
                        if let message {
                            Text(message)
                                .font(.system(size: 13))
                                .foregroundColor(messageColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Button(action: submit) {
                            HStack {
                                if isBusy {
                                    ProgressView()
                                        .tint(.foamWhite)
                                }
                                
                                Text(isCreatingAccount ? "Create account" : "Sign in")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSubmit || isBusy)
                        .opacity(!canSubmit || isBusy ? 0.6 : 1)
                        
                        Button {
                            authModel.clearError()
                            isCreatingAccount.toggle()
                        } label: {
                            Text(isCreatingAccount ? "Already have an account? Sign in" : "Need an account? Create one")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.roastBrown)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isBusy)
                    }
                    .padding(22)
                    .cardStyle(radius: DesignSystem.Radius.heroCard)
                    .padding(.horizontal, 24)
                    
                    HStack(spacing: 6) {
                        MugshotTagChip(title: "Photo sips", icon: "camera.fill")
                        MugshotTagChip(title: "Private notes", icon: "lock.fill")
                        MugshotTagChip(title: "Cafe saves", icon: "bookmark.fill")
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }
    
    private var messageColor: Color {
        if case .signedOut = authModel.status {
            return .espressoBrown.opacity(0.7)
        }
        return .red.opacity(0.85)
    }
    
    private func submit() {
        Task {
            if isCreatingAccount {
                await authModel.signUp(email: email, password: password, dataManager: dataManager)
            } else {
                await authModel.signIn(email: email, password: password, dataManager: dataManager)
            }
        }
    }
}

struct SupabaseConfigurationRequiredView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            VStack(spacing: 18) {
                Text("Mugshot")
                    .mugshotDisplay(size: 40)
                    .foregroundColor(.espressoBrown)
                
                Text("Sign-in is unavailable")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("Please try again after account access is set up.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.espressoBrown.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }
}

struct AuthLoadingView: View {
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.mugshotSage)
                
                Text("Checking session")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

private extension View {
    func authFieldStyle() -> some View {
        mugshotFormField()
    }
}
