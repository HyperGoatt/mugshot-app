import PhotosUI
import SwiftUI

@MainActor
struct RequiredProfileSetupView: View {
    @ObservedObject var dataManager: DataManager
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
                        "Handle",
                        text: $username,
                        placeholder: "your_handle",
                        capitalization: .never,
                        autocorrectionDisabled: true
                    )

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
        ZStack(alignment: .bottomLeading) {
            PhotosPicker(selection: $bannerItem, matching: .images) {
                Group {
                    if let bannerImage {
                        Image(uiImage: bannerImage).resizable().scaledToFill()
                    } else {
                        MugshotProfileBanner(imageURL: authModel.profile?.bannerURL, height: 132)
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
                    if let avatarImage {
                        Image(uiImage: avatarImage).resizable().scaledToFill()
                    } else {
                        MugshotAvatar(
                            name: displayName.remoteTrimmedNonEmpty ?? "Mugshot user",
                            size: 82,
                            imageURL: authModel.profile?.avatarURL
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
        username = profile.username
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
        if succeeded { onCompleted() }
    }
}
