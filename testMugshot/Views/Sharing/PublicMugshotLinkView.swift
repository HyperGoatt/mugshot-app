import SwiftUI

struct PublicMugshotLinkView: View {
    let route: MugshotSharedLinkRoute

    @State private var projection: MugshotPublicProjection?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let projection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("MUGSHOT")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(2.4)
                            .foregroundStyle(Color.mugshotSage)

                        if let coverPhotoURL = projection.coverPhotoURL,
                           let url = URL(string: coverPhotoURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Color.sandBeige
                                        .overlay {
                                            ProgressView()
                                                .tint(.mugshotSage)
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(4 / 5, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }

                        HStack {
                            Label(projection.contextName, systemImage: "mappin.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.mugshotSage)
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

                        Text("Remembered by \(projection.authorName)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.tertiaryText)
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
