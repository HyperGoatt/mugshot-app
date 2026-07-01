//
//  ProfileTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct ProfileTabView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var selectedTab: ProfileContentTab = .recent
    @State private var showEditProfile = false

    enum ProfileContentTab: String, CaseIterable {
        case recent = "Recent"
        case topCafes = "Top Cafes"
        case favorites = "Favorites"
        case wishlist = "Wishlist"
    }

    var user: User? {
        dataManager.appData.currentUser
    }

    var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        dataManager.getUserStats()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.mugshotMint, Color.sageGray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Spacer()

                                // Avatar
                                Circle()
                                    .fill(Color.creamWhite)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(user?.username.prefix(1).uppercased() ?? "U")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.espressoBrown)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.creamWhite, lineWidth: 4)
                                    )
                                    .offset(y: 40)
                            }
                        )

                    VStack(spacing: 20) {
                        // User info
                        VStack(spacing: 8) {
                            if let displayName = user?.displayName, !displayName.isEmpty {
                                Text(displayName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.espressoBrown.opacity(0.8))
                            }

                            Text("@\(user?.username ?? "user")")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.espressoBrown)

                            if authModel.profile != nil {
                                Text("Supabase profile active")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.espressoBrown.opacity(0.65))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.mugshotMint.opacity(0.45))
                                    .cornerRadius(DesignSystem.smallCornerRadius)
                            }

                            if let location = user?.location, !location.isEmpty {
                                Text(location)
                                    .font(.system(size: 16))
                                    .foregroundColor(.espressoBrown.opacity(0.7))
                            }

                            if let bio = user?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.system(size: 14))
                                    .foregroundColor(.espressoBrown.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top, 50)

                        if authModel.profile != nil {
                            Button {
                                authModel.clearProfileUpdateError()
                                showEditProfile = true
                            } label: {
                                Label("Edit Profile", systemImage: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal)
                        }

                        Button {
                            Task {
                                await authModel.signOut()
                            }
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.horizontal)

                        // Stats section
                        VStack(spacing: 16) {
                            Text("Stats")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.espressoBrown)

                            HStack(spacing: 20) {
                                StatBox(
                                    title: "Visits",
                                    value: "\(stats.totalVisits)"
                                )

                                StatBox(
                                    title: "Cafés",
                                    value: "\(stats.totalCafes)"
                                )

                                StatBox(
                                    title: "Avg Score",
                                    value: String(format: "%.1f", stats.averageScore)
                                )

                                StatBox(
                                    title: "Favorite",
                                    value: stats.favoriteDrinkType?.rawValue ?? "-"
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.sandBeige)
                        .cornerRadius(DesignSystem.cornerRadius)
                        .padding(.horizontal)

                        // Coffee Journey
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Coffee Journey")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.espressoBrown)

                            CoffeeJourneyView(stats: stats)
                        }
                        .padding()
                        .background(Color.sandBeige)
                        .cornerRadius(DesignSystem.cornerRadius)
                        .padding(.horizontal)

                        // Content tabs
                        Picker("Content", selection: $selectedTab) {
                            ForEach(ProfileContentTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // Content based on selected tab
                        contentView
                            .padding()
                    }
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("Profile")
            .sheet(isPresented: $showEditProfile) {
                if let profile = authModel.profile {
                    EditProfileView(profile: profile, dataManager: dataManager)
                        .environmentObject(authModel)
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .recent:
            RecentVisitsView(dataManager: dataManager)
        case .topCafes:
            TopCafesView(dataManager: dataManager)
        case .favorites:
            FavoritesView(dataManager: dataManager)
        case .wishlist:
            WishlistView(dataManager: dataManager)
        }
    }
}

struct EditProfileView: View {
    let profile: SupabaseUserProfile
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var username: String
    @State private var bio: String
    @State private var location: String
    @State private var favoriteDrink: String
    @State private var instagramHandle: String
    @State private var websiteURL: String

    init(profile: SupabaseUserProfile, dataManager: DataManager) {
        self.profile = profile
        self.dataManager = dataManager
        _displayName = State(initialValue: profile.displayName)
        _username = State(initialValue: profile.username)
        _bio = State(initialValue: profile.bio ?? "")
        _location = State(initialValue: profile.location ?? "")
        _favoriteDrink = State(initialValue: profile.favoriteDrink ?? "")
        _instagramHandle = State(initialValue: profile.instagramHandle ?? "")
        _websiteURL = State(initialValue: profile.websiteURL ?? "")
    }

    private var normalizedUsername: String {
        username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private var displayNameIsValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var usernameIsValid: Bool {
        normalizedUsername.count >= 3
    }

    private var canSave: Bool {
        displayNameIsValid && usernameIsValid && !authModel.isUpdatingProfile
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileField(
                        title: "Display Name",
                        text: $displayName,
                        placeholder: "Your name"
                    )

                    profileField(
                        title: "Username",
                        text: $username,
                        placeholder: "username",
                        autocapitalization: .never,
                        autocorrectionDisabled: true
                    )

                    if !usernameIsValid {
                        Text("Username must be at least 3 letters, numbers, or underscores.")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.8))
                    } else if normalizedUsername != username.trimmingCharacters(in: .whitespacesAndNewlines) {
                        Text("Will save as @\(normalizedUsername).")
                            .font(.system(size: 12))
                            .foregroundColor(.espressoBrown.opacity(0.6))
                    }

                    profileField(
                        title: "Location",
                        text: $location,
                        placeholder: "City"
                    )

                    profileField(
                        title: "Favorite Drink",
                        text: $favoriteDrink,
                        placeholder: "Cortado, matcha, pour-over..."
                    )

                    profileField(
                        title: "Instagram",
                        text: $instagramHandle,
                        placeholder: "handle",
                        autocapitalization: .never,
                        autocorrectionDisabled: true
                    )

                    profileField(
                        title: "Website",
                        text: $websiteURL,
                        placeholder: "https://...",
                        autocapitalization: .never,
                        autocorrectionDisabled: true
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)

                        TextField("Tell people what you are sipping lately.", text: $bio, axis: .vertical)
                            .lineLimit(3...5)
                            .profileEditorField()
                    }

                    if let error = authModel.profileUpdateError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: saveProfile) {
                        HStack {
                            if authModel.isUpdatingProfile {
                                ProgressView()
                                    .tint(.espressoBrown)
                            }

                            Text("Save Profile")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.6)
                }
                .padding(DesignSystem.largePadding)
            }
            .background(Color.creamWhite)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(authModel.isUpdatingProfile)
                }
            }
        }
    }

    private func profileField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        autocapitalization: TextInputAutocapitalization = .words,
        autocorrectionDisabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .profileEditorField()
        }
    }

    private func saveProfile() {
        Task {
            let didSave = await authModel.updateProfile(
                displayName: displayName,
                username: normalizedUsername,
                bio: bio,
                location: location,
                favoriteDrink: favoriteDrink,
                instagramHandle: instagramHandle,
                websiteURL: websiteURL,
                dataManager: dataManager
            )

            if didSave {
                dismiss()
            }
        }
    }
}

private extension View {
    func profileEditorField() -> some View {
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

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.espressoBrown)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.espressoBrown.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct CoffeeJourneyView: View {
    let stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Simple progress representation
            HStack(spacing: 8) {
                ForEach(0..<min(stats.totalCafes, 10), id: \.self) { _ in
                    Circle()
                        .fill(Color.mugshotMint)
                        .frame(width: 12, height: 12)
                }

                if stats.totalCafes > 10 {
                    Text("+\(stats.totalCafes - 10)")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
            }

            Text("\(stats.totalVisits) visits across \(stats.totalCafes) cafés")
                .font(.system(size: 14))
                .foregroundColor(.espressoBrown.opacity(0.7))
        }
    }
}

struct RecentVisitsView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedVisit: Visit?
    @State private var showVisitDetail = false

    var visits: [Visit] {
        dataManager.appData.visits.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if visits.isEmpty {
                Text("No visits yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(visits) { visit in
                    if dataManager.getCafe(id: visit.cafeId) != nil {
                        VisitCard(visit: visit, dataManager: dataManager, selectedScope: .friends)
                            .onTapGesture {
                                selectedVisit = visit
                                showVisitDetail = true
                            }
                    }
                }
            }
        }
        .sheet(isPresented: $showVisitDetail) {
            if let visit = selectedVisit {
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
        }
    }
}

struct TopCafesView: View {
    @ObservedObject var dataManager: DataManager

    var topCafes: [Cafe] {
        dataManager.appData.cafes
            .filter { $0.averageRating > 0 }
            .sorted { $0.averageRating > $1.averageRating }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if topCafes.isEmpty {
                Text("No cafés yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(topCafes) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: false,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var dataManager: DataManager

    var favorites: [Cafe] {
        dataManager.appData.cafes.filter { $0.isFavorite }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if favorites.isEmpty {
                Text("No favorites yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(favorites) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: false,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}

struct WishlistView: View {
    @ObservedObject var dataManager: DataManager

    var wishlist: [Cafe] {
        dataManager.appData.cafes.filter { $0.wantToTry }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if wishlist.isEmpty {
                Text("No wishlist items yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(wishlist) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: true,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}
