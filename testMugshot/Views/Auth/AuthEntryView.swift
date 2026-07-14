//
//  AuthEntryView.swift
//  testMugshot
//

import AuthenticationServices
import SwiftUI

struct AuthEntryView: View {
    @ObservedObject var dataManager: DataManager
    var contextTitle: String? = nil
    var contextMessage: String? = nil
    var showsCloseButton = false
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isCreatingAccount = false
    @State private var email = ""
    @State private var password = ""
    @State private var appleNonce: String?
    
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
                    if showsCloseButton {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.espressoBrown)
                                    .frame(width: 44, height: 44)
                                    .background(Color.foamWhite)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.mugshotLine))
                            }
                            .accessibilityLabel("Keep exploring")
                        }
                        .padding(.horizontal, 24)
                    } else {
                        Spacer(minLength: 42)
                    }
                    
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
                        
                        Text(contextTitle ?? (isCreatingAccount ? "Start your sip journal." : "Savor more. Share better."))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    SignedOutJournalPreview(message: contextMessage)

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.continue) { request in
                            do {
                                let nonce = try AppleSignInNonce.random()
                                appleNonce = nonce
                                request.requestedScopes = [.email, .fullName]
                                request.nonce = AppleSignInNonce.sha256(nonce)
                            } catch {
                                appleNonce = nil
                            }
                        } onCompletion: { result in
                            handleAppleAuthorization(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                        .disabled(isBusy)

                        HStack(spacing: 10) {
                            Rectangle().fill(Color.mugshotLine).frame(height: 1)
                            Text("or use email")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.tertiaryText)
                            Rectangle().fill(Color.mugshotLine).frame(height: 1)
                        }
                    }
                    .padding(.horizontal, 24)
                    
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
        .onChange(of: authModel.authenticatedUser?.id) { _, userId in
            if userId != nil, showsCloseButton {
                dismiss()
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

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = appleNonce else {
            return
        }

        Task {
            await authModel.signInWithApple(
                idToken: idToken,
                nonce: nonce,
                dataManager: dataManager
            )
            appleNonce = nil
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
                
                Text(releaseMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("Try again in a moment, or contact support@mugshot.app.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.espressoBrown.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }

    private var releaseMessage: String {
        #if DEBUG
        return message
        #else
        return "Mugshot is temporarily unavailable."
        #endif
    }
}

struct AuthLoadingView: View {
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.mugshotSage)
                
                Text("Opening your journal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

private struct SignedOutJournalPreview: View {
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Your first sip, saved with care", systemImage: "book.closed.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)

            HStack(spacing: 10) {
                previewStep(icon: "camera.fill", title: "Photograph", detail: "Add a cover")
                previewStep(icon: "star.fill", title: "Rate", detail: "Remember the taste")
                previewStep(icon: "lock.fill", title: "Keep", detail: "Private notes stay yours")
            }

            Text(message ?? "Create an account to keep your photo-backed sips, saved cafes, and personal tasting notes together.")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.sandBeige.opacity(0.56))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func previewStep(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.mugshotSage)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func authFieldStyle() -> some View {
        mugshotFormField()
    }
}
