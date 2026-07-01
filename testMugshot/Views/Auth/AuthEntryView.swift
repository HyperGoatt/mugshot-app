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
                VStack(spacing: 28) {
                    Spacer(minLength: 56)
                    
                    VStack(spacing: 12) {
                        Text("Mugshot")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        
                        Text("Sign in to start saving your coffee journey.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
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
                                        .tint(.espressoBrown)
                                }
                                
                                Text(isCreatingAccount ? "Create Account" : "Sign In")
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
                                .foregroundColor(.espressoBrown.opacity(0.75))
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isBusy)
                    }
                    .padding(22)
                    .background(Color.sandBeige.opacity(0.55))
                    .cornerRadius(DesignSystem.cornerRadius)
                    .padding(.horizontal, 24)
                    
                    Text("Map, Feed, Add, Saved, and Profile are still local prototype surfaces after sign-in in this phase.")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    
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
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.espressoBrown)
                
                Text("Supabase config needed")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("Create Config/SupabaseConfig.local.xcconfig from the example file, then rebuild.")
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
                    .tint(.mugshotMint)
                
                Text("Checking session")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.espressoBrown.opacity(0.75))
            }
        }
    }
}

private extension View {
    func authFieldStyle() -> some View {
        padding(12)
            .foregroundColor(.inputText)
            .tint(.mugshotMint)
            .background(Color.inputBackground)
            .cornerRadius(DesignSystem.smallCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                    .stroke(Color.inputBorder, lineWidth: 1)
            )
    }
}
