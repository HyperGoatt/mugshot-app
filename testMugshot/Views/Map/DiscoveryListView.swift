import CoreLocation
import Foundation
import SwiftUI

struct DiscoveryListView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var locationManager: LocationManager
    @Binding var discoveryMode: MapDiscoveryMode
    @AppStorage(DistanceUnitPreference.storageKey) private var distanceUnitPreferenceRaw = DistanceUnitPreference.automatic.rawValue
    @State private var radiusKM = 25.0
    @State private var cafesBySection: [DiscoverySection: [DiscoveryCafe]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCafe: Cafe?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        MapDiscoveryModeControl(selection: $discoveryMode)
                            .frame(width: 166)
                    }

                    discoveryContext

                    if isLoading && cafesBySection.isEmpty {
                        MugshotLoadingCards(count: 4, cardHeight: 148)
                    } else if let errorMessage, cafesBySection.isEmpty {
                        MugshotRecoveryCard(
                            title: "Discovery is taking a coffee break",
                            message: errorMessage,
                            actionTitle: "Retry"
                        ) { Task { await load() } }
                    } else if cafesBySection.values.allSatisfy(\.isEmpty) {
                        MugsyEmptyStateView(
                            asset: .noCafes,
                            title: "No cafes to show yet",
                            message: "Try the wider radius or pull to refresh. Saved and visited cafes still appear without location."
                        )
                    } else {
                        ForEach(DiscoverySection.allCases) { section in
                            if let cafes = cafesBySection[section], !cafes.isEmpty {
                                DiscoverySectionView(section: section, cafes: cafes) { cafe in
                                    selectedCafe = cafe.localCafe
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 116)
            }
            .background(Color.creamWhite)
            .refreshable { await load() }
            .sheet(item: $selectedCafe) { cafe in
                CafeDetailView(cafe: cafe, dataManager: dataManager)
            }
            .task(id: "\(radiusKM)-\(locationManager.location?.timestamp.timeIntervalSince1970 ?? 0)") {
                await load()
            }
        }
    }

    private var discoveryContext: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Discover")
                    .mugshotDisplay(size: 30)
                    .foregroundColor(.espressoBrown)
                Text(locationManager.location == nil ? "Great coffee, no location needed" : "Balanced picks around you")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            Picker("Radius", selection: $radiusKM) {
                Text(radiusLabel(25)).tag(25.0)
                Text(radiusLabel(100)).tag(100.0)
            }
            .pickerStyle(.menu)
            .tint(.mugshotSage)
            .accessibilityLabel("Discovery radius, \(radiusLabel(radiusKM))")
        }
    }

    private var distanceUnitPreference: DistanceUnitPreference {
        DistanceUnitPreference.stored(distanceUnitPreferenceRaw)
    }

    private func radiusLabel(_ kilometers: Double) -> String {
        MugshotDistanceFormatter.discoveryRadius(
            kilometers: kilometers,
            preference: distanceUnitPreference
        )
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
#if DEBUG
            // Gives UI automation a deterministic offline path without
            // changing host networking or affecting release builds.
            if ProcessInfo.processInfo.environment["MUGSHOT_DISCOVERY_OFFLINE"] == "1" {
                throw URLError(.notConnectedToInternet)
            }
#endif
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            async let nearby = service.discovery(section: .nearby, location: locationManager.location, radiusKM: radiusKM)
            async let friends = service.discovery(section: .lovedByFriends, location: locationManager.location, radiusKM: radiusKM)
            async let drinks = service.discovery(section: .popularDrinks, location: locationManager.location, radiusKM: radiusKM)
            async let trending = service.discovery(section: .trending, location: locationManager.location, radiusKM: radiusKM)
            async let saved = service.discovery(section: .saved, location: locationManager.location, radiusKM: radiusKM)
            async let visited = service.discovery(section: .visited, location: locationManager.location, radiusKM: radiusKM)
            cafesBySection = try await [
                .nearby: nearby,
                .lovedByFriends: friends,
                .popularDrinks: drinks,
                .trending: trending,
                .saved: saved,
                .visited: visited
            ]
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }
}

private struct DiscoverySectionView: View {
    let section: DiscoverySection
    let cafes: [DiscoveryCafe]
    let onSelect: (DiscoveryCafe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(title: section.title)
            ForEach(cafes) { cafe in
                Button { onSelect(cafe) } label: {
                    DiscoveryCafeRow(cafe: cafe)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DiscoveryCafeRow: View {
    let cafe: DiscoveryCafe

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let cover = cafe.recentCover {
                    RemotePhotoImageView(urlString: cover, placeholderSystemName: "cup.and.saucer.fill", contentMode: .fill)
                } else {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.mugshotMint.opacity(0.32))
                }
            }
            .frame(width: 82, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(cafe.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(1)
                    Spacer()
                    if let rating = cafe.averageRating { MugshotRatingBadge(score: rating) }
                }
                Text(cafe.rankingReason)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let distance = cafe.distanceKM {
                        Label(
                            MugshotDistanceFormatter.distance(
                                kilometers: distance,
                                preference: DistanceUnitPreference.stored(distanceUnitPreferenceRaw)
                            ),
                            systemImage: "location.fill"
                        )
                    }
                    if cafe.friendCount > 0 {
                        Label(
                            "\(cafe.friendCount) \(cafe.friendCount == 1 ? "friend" : "friends")",
                            systemImage: "person.2.fill"
                        )
                    }
                    Label(
                        "\(cafe.visibleVisitCount) \(cafe.visibleVisitCount == 1 ? "sip" : "sips")",
                        systemImage: "cup.and.saucer"
                    )
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
                if !cafe.topDrinks.isEmpty {
                    Text(cafe.topDrinks.map(\.name).joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.tertiaryText)
        }
        .padding(12)
        .cardStyle()
    }

    @AppStorage(DistanceUnitPreference.storageKey) private var distanceUnitPreferenceRaw = DistanceUnitPreference.automatic.rawValue
}
