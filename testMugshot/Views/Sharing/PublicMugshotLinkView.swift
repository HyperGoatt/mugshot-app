import SwiftUI

struct PublicMugshotLinkView: View {
    let route: MugshotSharedLinkRoute

    @State private var projection: MugshotPublicProjection?
    @State private var isLoading = true
    @State private var selectedPhotoIndex = 0

    var body: some View {
        Group {
            if let projection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("MUGSHOT")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(2.4)
                            .foregroundStyle(Color.mugshotSage)

                        let photoURLs = projection.photoURLs.isEmpty
                            ? projection.coverPhotoURL.map { [$0] } ?? []
                            : projection.photoURLs
                        if !photoURLs.isEmpty {
                            TabView(selection: $selectedPhotoIndex) {
                                ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, url in
                                    RemotePhotoImageView(
                                        urlString: url,
                                        placeholderSystemName: "photo.on.rectangle"
                                    )
                                    .tag(index)
                                    .overlay(alignment: .topTrailing) {
                                        if photoURLs.count > 1 {
                                            Text("\(index + 1)/\(photoURLs.count)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(.black.opacity(0.7), in: Capsule())
                                                .padding(14)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(4 / 5, contentMode: .fit)
                            .tabViewStyle(
                                .page(indexDisplayMode: photoURLs.count > 1 ? .automatic : .never)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }

                        HStack(spacing: 12) {
                            if let avatarURL = projection.authorAvatarURL,
                               let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Color.mugshotMint
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(projection.authorName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.espressoBrown)
                                if let username = projection.authorUsername {
                                    Text("@\(username)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.tertiaryText)
                                }
                            }
                            Spacer()
                            Text(projection.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.tertiaryText)
                        }

                        Text(projection.drinkName)
                            .mugshotDisplay(size: 38)
                            .foregroundStyle(Color.espressoBrown)

                        HStack(alignment: .lastTextBaseline) {
                            Text(projection.contextName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.secondaryText)
                            Spacer()
                            Text(projection.rating, format: .number.precision(.fractionLength(1)))
                                .mugshotDisplay(size: 42)
                                .monospacedDigit()
                            Text("OUT OF 5")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(1.2)
                                .foregroundStyle(Color.mugshotSage)
                        }

                        if let caption = projection.caption {
                            Text(caption)
                                .font(.system(size: 19, weight: .medium, design: .serif))
                                .italic()
                                .foregroundStyle(Color.roastBrown)
                                .padding(.leading, 14)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.mugshotMint)
                                        .frame(width: 3)
                                }
                        }

                        if !projection.ratings.isEmpty {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ],
                                spacing: 10
                            ) {
                                ForEach(projection.ratings.keys.sorted(), id: \.self) { name in
                                    if let value = projection.ratings[name] {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(name.replacingOccurrences(of: "_", with: " "))
                                                .font(.system(size: 10, weight: .bold))
                                                .textCase(.uppercase)
                                                .foregroundStyle(Color.tertiaryText)
                                            Text(value, format: .number.precision(.fractionLength(1)))
                                                .mugshotDisplay(size: 24)
                                                .foregroundStyle(Color.espressoBrown)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(13)
                                        .background(Color.foamWhite)
                                        .clipShape(
                                            RoundedRectangle(
                                                cornerRadius: 14,
                                                style: .continuous
                                            )
                                        )
                                        .overlay {
                                            RoundedRectangle(
                                                cornerRadius: 14,
                                                style: .continuous
                                            )
                                            .stroke(Color.mugshotLine, lineWidth: 1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            } else if isLoading {
                ProgressView("Opening Mugshot…")
                    .tint(.mugshotSage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "This Mugshot is not available.",
                    systemImage: "cup.and.saucer",
                    description: Text("It may have been removed or its audience may have changed.")
                )
            }
        }
        .background(Color.creamWhite)
        .navigationTitle("Mugshot")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: route.slug) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let client = try? SupabaseClientProvider.shared.client() else {
            projection = nil
            return
        }
        let service = MugshotShareLinkService(client: client)
        projection = try? await service.publicProjection(slug: route.slug)
        if projection != nil {
            await service.recordPublicEvent(slug: route.slug, eventName: "app_open")
        }
    }
}
