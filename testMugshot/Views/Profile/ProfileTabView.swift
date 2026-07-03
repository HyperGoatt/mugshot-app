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
    @State private var showSettings = false
    @State private var remoteProfileVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteProfileStats = false
    @State private var remoteProfileStatsError: String?

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

    private var displayedStats: ProfileStatsDisplay {
        if authModel.authenticatedUser != nil {
            return ProfileStatsDisplay(remote: RemoteProfileStats.calculate(from: remoteProfileVisits))
        }

        return ProfileStatsDisplay(
            totalVisits: stats.totalVisits,
            totalCafes: stats.totalCafes,
            averageScore: stats.averageScore,
            favoriteDrinkLabel: stats.favoriteDrinkType?.rawValue
        )
    }

    /// Drink category distribution powering the taste identity card.
    private var tasteCategories: [TasteCategoryShare] {
        let labels: [String]
        if authModel.authenticatedUser != nil {
            labels = remoteProfileVisits.map { summary in
                summary.visit.drinkCategoryDisplayName ?? summary.visit.drinkDisplayName
            }
        } else {
            labels = dataManager.appData.visits.map { $0.drinkType.rawValue }
        }

        return TasteCategoryShare.calculate(from: labels)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.mugshotSageSoft, Color.mugshotMint],
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
                                    .frame(width: 84, height: 84)
                                    .overlay(
                                        Text(user?.username.prefix(1).uppercased() ?? "U")
                                            .font(.system(size: 34, weight: .bold, design: .serif))
                                            .foregroundColor(.mugshotForest)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.creamWhite, lineWidth: 4)
                                    )
                                    .shadow(color: Color.espressoBrown.opacity(0.12), radius: 8, x: 0, y: 3)
                                    .offset(y: 42)
                            }
                        )

                    VStack(spacing: 20) {
                        // User info
                        VStack(spacing: 6) {
                            if let displayName = user?.displayName, !displayName.isEmpty {
                                Text(displayName)
                                    .font(.system(size: 26, weight: .bold, design: .serif))
                                    .foregroundColor(.espressoBrown)
                            }

                            Text("@\(user?.username ?? "user")")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.espressoBrown.opacity(0.62))

                            if let location = user?.location, !location.isEmpty {
                                Label(location, systemImage: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.espressoBrown.opacity(0.66))
                            }

                            if let bio = user?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.system(size: 14))
                                    .foregroundColor(.espressoBrown.opacity(0.72))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.top, 52)

                        if authModel.profile != nil {
                            Button {
                                authModel.clearProfileUpdateError()
                                showEditProfile = true
                            } label: {
                                Label("Edit Profile", systemImage: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                                    .padding(.horizontal, 20)
                                    .frame(height: 40)
                                    .background(Color.creamWhite)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.sandBeige, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }

                        // Stats row
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                MugStatTile(
                                    value: "\(displayedStats.totalVisits)",
                                    title: "Sips",
                                    systemImage: "cup.and.saucer.fill"
                                )

                                MugStatTile(
                                    value: "\(displayedStats.totalCafes)",
                                    title: "Cafes",
                                    systemImage: "mappin.and.ellipse"
                                )

                                MugStatTile(
                                    value: displayedStats.totalVisits > 0 ? String(format: "%.1f", displayedStats.averageScore) : "–",
                                    title: "Avg Score",
                                    systemImage: "star.fill"
                                )
                            }

                            if isLoadingRemoteProfileStats {
                                Text("Refreshing stats...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.62))
                            } else if let remoteProfileStatsError {
                                Text(remoteProfileStatsError)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.82))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal)

                        // Taste identity
                        TasteIdentityCard(
                            categories: tasteCategories,
                            favoriteDrinkLabel: displayedStats.favoriteDrinkLabel,
                            totalVisits: displayedStats.totalVisits,
                            totalCafes: displayedStats.totalCafes
                        )
                        .padding(.horizontal)

                        // Content tabs
                        MugSegmentedControl(
                            options: ProfileContentTab.allCases,
                            selection: $selectedTab,
                            label: { $0.rawValue }
                        )
                        .padding(.horizontal)

                        // Content based on selected tab
                        contentView
                            .padding()
                    }
                }
            }
            .background(Color.mugshotCanvas)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.espressoBrown)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let profile = authModel.profile {
                    EditProfileView(profile: profile, dataManager: dataManager)
                        .environmentObject(authModel)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authModel)
            }
            .task(id: authModel.authenticatedUser?.id) {
                await loadRemoteProfileStats()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .recent:
            RecentVisitsView(dataManager: dataManager)
                .environmentObject(authModel)
        case .topCafes:
            TopCafesView(
                dataManager: dataManager,
                remoteStats: authModel.authenticatedUser == nil ? nil : RemoteProfileStats.calculate(from: remoteProfileVisits)
            )
        case .favorites:
            FavoritesView(dataManager: dataManager)
        case .wishlist:
            WishlistView(dataManager: dataManager)
        }
    }

    @MainActor
    private func loadRemoteProfileStats() async {
        guard let userId = authModel.authenticatedUser?.id else {
            remoteProfileVisits = []
            remoteProfileStatsError = nil
            isLoadingRemoteProfileStats = false
            return
        }

        isLoadingRemoteProfileStats = true
        remoteProfileStatsError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            remoteProfileVisits = try await service.fetchRecentVisits(
                userId: userId,
                limit: 100,
                includeSocialState: false
            )
            isLoadingRemoteProfileStats = false
        } catch {
            remoteProfileStatsError = "Could not load remote profile stats."
            isLoadingRemoteProfileStats = false
        }
    }
}

struct ProfileStatsDisplay: Equatable {
    let totalVisits: Int
    let totalCafes: Int
    let averageScore: Double
    let favoriteDrinkLabel: String?

    init(
        totalVisits: Int,
        totalCafes: Int,
        averageScore: Double,
        favoriteDrinkLabel: String?
    ) {
        self.totalVisits = totalVisits
        self.totalCafes = totalCafes
        self.averageScore = averageScore
        self.favoriteDrinkLabel = favoriteDrinkLabel
    }

    init(remote: RemoteProfileStats) {
        self.init(
            totalVisits: remote.totalVisits,
            totalCafes: remote.totalCafes,
            averageScore: remote.averageScore,
            favoriteDrinkLabel: remote.favoriteDrinkLabel
        )
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
            .tint(.mugshotForest)
            .background(Color.inputBackground)
            .cornerRadius(DesignSystem.smallCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                    .stroke(Color.inputBorder, lineWidth: 1)
            )
    }
}

/// One drink category's share of the user's logged sips.
struct TasteCategoryShare: Identifiable, Equatable {
    let name: String
    let count: Int
    let fraction: Double

    var id: String { name }

    var iconName: String {
        let lowered = name.lowercased()
        if lowered.contains("matcha") { return "leaf.fill" }
        if lowered.contains("hojicha") { return "flame.fill" }
        if lowered.contains("tea") || lowered.contains("chai") { return "mug.fill" }
        if lowered.contains("chocolate") { return "takeoutbag.and.cup.and.straw.fill" }
        if lowered.contains("coffee") || lowered.contains("latte") || lowered.contains("espresso") { return "cup.and.saucer.fill" }
        return "sparkles"
    }

    /// Groups raw drink labels into ranked category shares (top 4).
    static func calculate(from labels: [String]) -> [TasteCategoryShare] {
        let cleaned = labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { return [] }

        let counts = Dictionary(grouping: cleaned) { $0.capitalized }
            .mapValues { $0.count }

        let total = Double(cleaned.count)

        return counts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .prefix(4)
            .map { name, count in
                TasteCategoryShare(name: name, count: count, fraction: Double(count) / total)
            }
    }
}

/// "My Taste Identity" card: category breakdown bars plus favorite-drink
/// summary, per the Mugshot design system.
struct TasteIdentityCard: View {
    let categories: [TasteCategoryShare]
    let favoriteDrinkLabel: String?
    let totalVisits: Int
    let totalCafes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.mugshotForest)

                Text("My Taste Identity")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.espressoBrown)
            }

            if categories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.32))

                    Text("Log a few sips to reveal your taste profile.")
                        .font(.system(size: 13))
                        .foregroundColor(.espressoBrown.opacity(0.62))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(spacing: 12) {
                    ForEach(categories) { category in
                        MugTasteCategoryRow(
                            name: category.name,
                            systemImage: category.iconName,
                            fraction: category.fraction
                        )
                    }
                }

                HStack(spacing: 8) {
                    if let favoriteDrinkLabel, !favoriteDrinkLabel.isEmpty {
                        MugTagChip(title: "Go-to: \(favoriteDrinkLabel)", systemImage: "heart.fill")
                    }

                    MugTagChip(title: "\(totalVisits) sips", systemImage: "cup.and.saucer.fill")
                    MugTagChip(title: "\(totalCafes) cafes", systemImage: "mappin.and.ellipse")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }
}

struct RecentVisitsView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteVisits = false
    @State private var remoteVisitError: String?
    @State private var selectedVisit: Visit?
    @State private var showVisitDetail = false
    @State private var selectedRemoteVisit: RemoteVisitSummary?

    private var localVisits: [Visit] {
        dataManager.appData.visits.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if authModel.authenticatedUser != nil {
                remoteContent
            } else {
                localContent
            }
        }
        .task(id: authModel.authenticatedUser?.id) {
            await loadRemoteVisits()
        }
        .sheet(isPresented: $showVisitDetail) {
            if let visit = selectedVisit {
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
        }
        .sheet(item: $selectedRemoteVisit) { visit in
            RemoteVisitDetailView(
                visitId: visit.id,
                initialSummary: visit,
                currentUserId: authModel.authenticatedUser?.id,
                dataManager: dataManager
            )
        }
    }

    @ViewBuilder
    private var remoteContent: some View {
        if isLoadingRemoteVisits {
            MugLoadingStateView(message: "Loading your sips...")
        } else if let remoteVisitError {
            MugErrorStateView(
                title: "Could not load your sips",
                message: remoteVisitError,
                onRetry: {
                    Task {
                        await loadRemoteVisits()
                    }
                }
            )
        } else if remoteVisits.isEmpty {
            ProfileEmptyStateCard(
                asset: .noCafes,
                systemImage: "cup.and.saucer.fill",
                title: "No visits yet",
                message: "Save a real visit from Add. It will appear here, open in detail, and persist after relaunch."
            )
        } else {
            ForEach(remoteVisits) { visit in
                Button {
                    selectedRemoteVisit = visit
                } label: {
                    RemoteVisitSummaryCard(visit: visit)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(visit.visit.drinkDisplayName) at \(visit.locationTitle)")
                .accessibilityHint("Opens visit details")
            }
        }
    }

    @ViewBuilder
    private var localContent: some View {
        if localVisits.isEmpty {
            ProfileEmptyStateCard(
                asset: .noCafes,
                systemImage: "cup.and.saucer.fill",
                title: "No local visits yet",
                message: "Log a visit to start filling your taste journal."
            )
        } else {
            ForEach(localVisits) { visit in
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

    private func loadRemoteVisits() async {
        guard let userId = authModel.authenticatedUser?.id else {
            remoteVisits = []
            remoteVisitError = nil
            isLoadingRemoteVisits = false
            return
        }

        isLoadingRemoteVisits = true
        remoteVisitError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let visits = try await service.fetchRecentVisits(userId: userId)
            remoteVisits = visits
            isLoadingRemoteVisits = false
        } catch {
            remoteVisits = []
            remoteVisitError = error.localizedDescription
            isLoadingRemoteVisits = false
        }
    }
}

struct ProfileEmptyStateCard: View {
    let asset: MugsyEmptyStateAsset?
    let systemImage: String
    let title: String
    let message: String

    init(
        asset: MugsyEmptyStateAsset? = nil,
        systemImage: String,
        title: String,
        message: String
    ) {
        self.asset = asset
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    var body: some View {
        if let asset {
            MugsyEmptyStateView(asset: asset, title: title, message: message)
        } else {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.36))
                .frame(width: 52, height: 52)
                .background(Color.sandBeige.opacity(0.45))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.espressoBrown.opacity(0.64))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
        }
    }
}

struct RemoteVisitSummaryCard: View {
    let visit: RemoteVisitSummary

    private var hasPhoto: Bool {
        visit.visit.posterPhotoURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasPhoto {
                poster
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius))
                    .overlay(alignment: .topTrailing) {
                        scoreBadge
                            .padding(10)
                    }
                    .padding([.top, .horizontal], 12)
            }

            HStack(alignment: .top, spacing: 12) {
                if !hasPhoto {
                    poster
                        .frame(width: 76, height: 76)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(visit.locationTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.espressoBrown)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let subtitle = visit.locationSubtitle {
                                Text(subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        if !hasPhoto {
                            scoreBadge
                        }
                    }

                    Text(visit.visit.drinkDisplayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(2)

                    if !visit.visit.caption.isEmpty {
                        Text(visit.visit.caption)
                            .font(.system(size: 13))
                            .foregroundColor(.espressoBrown.opacity(0.68))
                            .lineLimit(2)
                    }

                    metadataRow
                }
            }
            .padding(12)
        }
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
        .shadow(
            color: DesignSystem.cardShadow.color,
            radius: DesignSystem.cardShadow.radius,
            x: DesignSystem.cardShadow.x,
            y: DesignSystem.cardShadow.y
        )
    }

    private var poster: some View {
        Group {
            if visit.visit.posterPhotoURL != nil {
                RemotePhotoImageView(
                    urlString: visit.visit.posterPhotoURL,
                    placeholderSystemName: "photo"
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
            } else {
                RemoteVisitNoPhotoThumbnail()
            }
        }
    }

    private var scoreBadge: some View {
        MugScoreBadge(score: visit.visit.overallScore, size: .compact)
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            Label(formatDate(visit.visit.createdAtDate), systemImage: "clock.fill")
            Text("•")
            Label(visit.visit.backendVisibilityLabel, systemImage: visibilityIcon)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.35))
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.espressoBrown.opacity(0.55))
        .lineLimit(1)
    }

    private var visibilityIcon: String {
        switch visit.visit.backendVisibilityLabel.lowercased() {
        case "private":
            return "lock.fill"
        case "friends":
            return "person.2.fill"
        default:
            return "globe"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RemoteVisitNoPhotoThumbnail: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.4))

            Text("No photo")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sandBeige.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
    }
}

struct TopCafesView: View {
    @ObservedObject var dataManager: DataManager
    let remoteStats: RemoteProfileStats?

    var topCafes: [Cafe] {
        dataManager.appData.cafes
            .filter { $0.averageRating > 0 }
            .sorted { $0.averageRating > $1.averageRating }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let remoteStats {
                if remoteStats.topCafes.isEmpty {
                    ProfileEmptyStateCard(
                        asset: .noCafes,
                        systemImage: "cup.and.saucer.fill",
                        title: "No top cafés yet",
                        message: "Photo-backed remote visits will rank your cafés here."
                    )
                } else {
                    ForEach(remoteStats.topCafes) { topCafe in
                        RemoteTopCafeCard(topCafe: topCafe)
                    }
                }
            } else if topCafes.isEmpty {
                ProfileEmptyStateCard(
                    asset: .noCafes,
                    systemImage: "cup.and.saucer.fill",
                    title: "No cafés yet",
                    message: "Log visits to rank your cafés."
                )
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

struct RemoteTopCafeCard: View {
    let topCafe: RemoteTopCafe

    var body: some View {
        HStack(spacing: 12) {
            RemotePhotoImageView(
                urlString: topCafe.posterPhotoURL,
                placeholderSystemName: "cup.and.saucer.fill"
            )
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))

            VStack(alignment: .leading, spacing: 6) {
                Text(topCafe.cafe.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(2)

                if !topCafe.cafe.displayLocation.isEmpty {
                    Text(topCafe.cafe.displayLocation)
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.62))
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label(String(format: "%.1f", topCafe.averageScore), systemImage: "star.fill")
                    Label("\(topCafe.visitCount)", systemImage: "cup.and.saucer.fill")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.68))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
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
                MugsyEmptyStateView(
                    asset: .noFavorites,
                    title: "No favorites yet",
                    message: "Heart the cafes you love and they will live here."
                )
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
                MugsyEmptyStateView(
                    asset: .noWishlist,
                    title: "Nothing on the wishlist yet",
                    message: "Mark cafes as Want to Try to plan your next sip."
                )
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
