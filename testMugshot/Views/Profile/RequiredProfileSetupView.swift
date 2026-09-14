import PhotosUI
import SwiftUI

@MainActor
struct RequiredProfileSetupView: View {
    @ObservedObject var dataManager: DataManager
    let requiresUsernameConfirmation: Bool
    let onCompleted: () -> Void

    @EnvironmentObject private var authModel: AppAuthModel
    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var instagramHandle = ""
    @State private var websiteURL = ""
    @State private var favoriteDrink = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var bannerImage: UIImage?
    @State private var isPreparingMedia = false
    @State private var completedProfileID: UUID?

    private var normalizedUsername: String {
        username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private var canContinue: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && (3...30).contains(normalizedUsername.count)
            && !isWorking
    }

    private var isWorking: Bool {
        isPreparingMedia || authModel.isUpdatingProfile || authModel.isCompletingProfileSetup
    }

    var body: some View {
        Group {
            if let completedProfileID {
                ProfileSetupFavoriteSpotsStep(
                    userID: completedProfileID,
                    dataManager: dataManager,
                    onCompleted: onCompleted
                )
            } else {
                profileDetails
            }
        }
    }

    private var profileDetails: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileMedia

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make your profile yours")
                            .mugshotDisplay(size: 34)
                            .foregroundStyle(Color.espressoBrown)
                        Text("Your name and handle are required. Everything else can be added now or later.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                    }

                    setupField("Display name", text: $displayName, placeholder: "Your name")
                    setupField(
                        "Choose your username",
                        text: $username,
                        placeholder: "your_username",
                        capitalization: .never,
                        autocorrectionDisabled: true
                    )

                    if requiresUsernameConfirmation {
                        Text("Mugshot created a temporary username during sign-in. Choose the public username people will see and share.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !username.isEmpty && !(3...30).contains(normalizedUsername.count) {
                        Text("Use 3–30 letters, numbers, or underscores.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.red.opacity(0.82))
                    }

                    setupField("Location", text: $location, placeholder: "City")
                    setupField("Favorite drink", text: $favoriteDrink, placeholder: "Cortado, matcha, pour-over…")
                    setupField(
                        "Instagram",
                        text: $instagramHandle,
                        placeholder: "handle",
                        capitalization: .never,
                        autocorrectionDisabled: true
                    )
                    Text("Your Instagram username is separate from your Mugshot username. You can paste a profile link.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    setupField(
                        "Website",
                        text: $websiteURL,
                        placeholder: "https://…",
                        capitalization: .never,
                        autocorrectionDisabled: true
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.espressoBrown)
                        TextField("What are you sipping lately?", text: $bio, axis: .vertical)
                            .lineLimit(3...5)
                            .mugshotFormField()
                    }

                    if let error = authModel.profileSetupError ?? authModel.profileUpdateError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button { Task { await complete() } } label: {
                        HStack(spacing: 9) {
                            if isWorking { ProgressView().tint(.foamWhite) }
                            Text("Finish profile")
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.58)

                    Text("You can change these details and your profile audience later in Settings.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.tertiaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.creamWhite)
            .navigationTitle("Set up profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
        .onAppear(perform: seedProfile)
        .onChange(of: avatarItem) { _, item in
            Task { avatarImage = await loadImage(item) }
        }
        .onChange(of: bannerItem) { _, item in
            Task { bannerImage = await loadImage(item) }
        }
    }

    private var profileMedia: some View {
        let selectedBannerImage = bannerImage
        let selectedAvatarImage = avatarImage
        let profileBannerURL = authModel.profile?.bannerURL
        let profileAvatarURL = authModel.profile?.avatarURL
        let avatarName = displayName.remoteTrimmedNonEmpty ?? "Mugshot user"

        return ZStack(alignment: .bottomLeading) {
            PhotosPicker(selection: $bannerItem, matching: .images) {
                Group {
                    if let selectedBannerImage {
                        Image(uiImage: selectedBannerImage).resizable().scaledToFill()
                    } else {
                        MugshotProfileBanner(imageURL: profileBannerURL, height: 132)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Label("Banner", systemImage: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(.black.opacity(0.52), in: Capsule())
                        .padding(10)
                }
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $avatarItem, matching: .images) {
                Group {
                    if let selectedAvatarImage {
                        Image(uiImage: selectedAvatarImage).resizable().scaledToFill()
                    } else {
                        MugshotAvatar(
                            name: avatarName,
                            size: 82,
                            imageURL: profileAvatarURL
                        )
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.creamWhite, lineWidth: 4))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.mugshotSage, in: Circle())
                }
                .offset(x: 16, y: 38)
            }
            .buttonStyle(.plain)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
        .padding(.bottom, 34)
    }

    private func setupField(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        capitalization: TextInputAutocapitalization = .words,
        autocorrectionDisabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .mugshotFormField()
        }
    }

    private func seedProfile() {
        guard let profile = authModel.profile else { return }
        displayName = profile.displayName
        username = ProfileSetupPresentationPolicy.initialUsername(
            storedUsername: profile.username,
            requiresConfirmation: requiresUsernameConfirmation
        )
        bio = profile.bio ?? ""
        location = profile.location ?? ""
        instagramHandle = profile.instagramHandle ?? ""
        websiteURL = profile.websiteURL ?? ""
        favoriteDrink = profile.favoriteDrink ?? ""
    }

    private func loadImage(_ item: PhotosPickerItem?) async -> UIImage? {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }

    @MainActor
    private func complete() async {
        guard canContinue else { return }
        isPreparingMedia = true
        authModel.clearProfileSetupError()
        defer { isPreparingMedia = false }

        if let avatarImage,
           await authModel.updateAvatar(avatarImage, dataManager: dataManager) == false {
            return
        }
        if let bannerImage,
           await authModel.updateBanner(bannerImage, dataManager: dataManager) == false {
            return
        }
        let succeeded = await authModel.completeProfileSetup(
            displayName: displayName,
            username: normalizedUsername,
            bio: bio,
            location: location,
            instagramHandle: instagramHandle,
            websiteURL: websiteURL,
            favoriteDrink: favoriteDrink,
            dataManager: dataManager
        )
        if succeeded, let userID = authModel.authenticatedUser?.id {
            completedProfileID = userID
        }
    }
}

@MainActor
private struct ProfileSetupFavoriteSpotsStep: View {
    let userID: UUID
    @ObservedObject var dataManager: DataManager
    let onCompleted: () -> Void

    @State private var spots: [SharedProfileFavoriteSpot] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showsEditor = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your favorite spots")
                        .mugshotDisplay(size: 34)
                        .foregroundStyle(Color.espressoBrown)
                    Text("Choose up to three cafes that feel like you. This is optional and can be changed from your profile anytime.")
                        .font(.body)
                        .foregroundStyle(Color.secondaryText)
                }

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading your profile…")
                    }
                    .foregroundStyle(Color.secondaryText)
                } else if loadError == nil {
                    Button { showsEditor = true } label: {
                        Label(
                            spots.isEmpty
                                ? "Choose Favorite Spots"
                                : "Edit \(spots.count) Favorite Spot\(spots.count == 1 ? "" : "s")",
                            systemImage: "storefront.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                if spots.isEmpty {
                    Button("Do this later", action: onCompleted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.espressoBrown)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Button("Continue to Mugshot", action: onCompleted)
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(24)
            .background(Color.creamWhite)
            .navigationTitle("Finish profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
        .task { await loadSpots() }
        .sheet(isPresented: $showsEditor) {
            ProfileFavoriteSpotsEditor(
                spots: spots,
                dataManager: dataManager
            ) { spots = $0 }
        }
    }

    private func loadSpots() async {
        defer { isLoading = false }
        do {
            spots = try await SharedProfileService(
                client: SupabaseClientProvider.shared.client()
            ).projection(userID: userID).favoriteSpots
        } catch {
            loadError = "Favorite Spots couldn't load right now. You can continue and add them later from your profile."
        }
    }
}
