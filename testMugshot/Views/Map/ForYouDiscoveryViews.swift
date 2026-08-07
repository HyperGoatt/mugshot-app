import CoreLocation
import SwiftUI

struct MapDiscoveryScopeMenu: View {
    @Binding var selection: MapDiscoveryScope
    let isAuthenticated: Bool

    var body: some View {
        Menu {
            ForEach(MapDiscoveryScope.available(isAuthenticated: isAuthenticated)) { scope in
                Button {
                    selection = scope
                    MugshotAnalytics.shared.capture(.discovery(
                        action: .scopeSelected,
                        source: scope == .forYou ? .forYou : .appleSearch,
                        surface: .map,
                        rankingVersion: scope == .forYou ? ForYouRankingConfiguration.v1.version : nil,
                        cafeID: nil
                    ))
                } label: {
                    Label(scope.rawValue, systemImage: scope.icon)
                }
            }
        } label: {
            Image(systemName: selection.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.mugshotSageText)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
                .mugshotGlassSurface(
                    radius: 26,
                    tint: .creamWhite,
                    stroke: Color.foamWhite.opacity(0.78),
                    shadow: DesignSystem.Shadow(
                        color: .black.opacity(0.10),
                        radius: 16,
                        x: 0,
                        y: 6
                    ),
                    interactive: true
                )
        }
        .accessibilityIdentifier("map.discovery.scope")
        .accessibilityLabel("Map view: \(selection.rawValue)")
        .accessibilityHint("Shows map view choices")
    }
}

struct ForYouRecommendationCard: View {
    let recommendation: ForYouRecommendation
    let walkingMinutes: Int?
    let onOpen: () -> Void
    let onDirections: () -> Void
    let onWantToTry: () -> Void

    private var distanceText: String? {
        guard let meters = recommendation.distanceMeters else { return nil }
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }

    var body: some View {
        VStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 14) {
                    placeholder

                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendation.candidate.name)
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .foregroundColor(.espressoBrown)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        HStack(spacing: 7) {
                            if recommendation.candidate.availability == .verifiedOpen {
                                Circle()
                                    .fill(Color.mugshotSage)
                                    .frame(width: 8, height: 8)
                                Text("Open")
                                    .foregroundColor(.mugshotSageText)
                            }
                            if let distanceText {
                                if recommendation.candidate.availability == .verifiedOpen {
                                    Text("·")
                                }
                                Text(distanceText)
                            }
                            if let walkingMinutes {
                                if distanceText != nil || recommendation.candidate.availability == .verifiedOpen {
                                    Text("·")
                                }
                                Image(systemName: "figure.walk")
                                Text("\(walkingMinutes) min walk")
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondaryText)

                        Label(recommendation.reason, systemImage: evidenceIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.espressoBrown)
                            .lineLimit(2)

                        if !practicalTags.isEmpty {
                            Text(practicalTags.joined(separator: " · "))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.mugshotSageText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: recommendation.candidate.isWantToTry ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.roastBrown)
                        .frame(width: 38, height: 38)
                        .background(Color.sandBeige.opacity(0.62), in: Circle())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.forYou.card")
            .accessibilityHint("Shows cafe details")

            HStack(spacing: 10) {
                Button(action: onDirections) {
                    Label("Directions", systemImage: "arrow.turn.up.right")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.foamWhite)
                .background(Color.mugshotSage, in: Capsule())

                Button(action: onWantToTry) {
                    Label(
                        recommendation.candidate.isWantToTry ? "Saved" : "Want to Try",
                        systemImage: recommendation.candidate.isWantToTry ? "bookmark.fill" : "bookmark"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.roastBrown)
                .overlay(Capsule().stroke(Color.roastBrown.opacity(0.65), lineWidth: 1))
            }
        }
        .padding(16)
        .background(Color.foamWhite.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.foamWhite, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.13), radius: 22, x: 0, y: 9)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.sandBeige)
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.mugshotSage)
        }
        .frame(width: 82, height: 96)
        .accessibilityHidden(true)
    }

    private var evidenceIcon: String {
        switch recommendation.evidence.first?.kind {
        case .friendVisit: "person.crop.circle.fill"
        case .wantToTry: "bookmark.fill"
        case .practicalFit: "checkmark.seal.fill"
        case .drinkMatch: "cup.and.saucer.fill"
        case .publicList: "list.bullet.rectangle"
        case .publicMugshot: "camera.fill"
        case .nearby, .none: "location.fill"
        }
    }

    private var practicalTags: [String] {
        let labels: [String: String] = [
            "quiet": "Quiet",
            "wifi": "Wi-Fi",
            "outlets": "Outlets",
            "work_study": "Good for work",
            "table_space": "Table space",
            "accessible": "Accessible",
            "group_friendly": "Group friendly",
            "calm": "Calm"
        ]
        return recommendation.evidence
            .filter { $0.kind == .practicalFit }
            .flatMap(\.tags)
            .compactMap { labels[$0] }
            .reduce(into: [String]()) { result, label in
                if !result.contains(label) { result.append(label) }
            }
            .prefix(3)
            .map { $0 }
    }
}

struct ForYouListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recommendations: [ForYouRecommendation]
    let isStillLearning: Bool
    let onSelect: (ForYouRecommendation) -> Void

    private var grouped: [(ForYouSection, [ForYouRecommendation])] {
        ForYouSection.allCases.compactMap { section in
            let rows = recommendations.filter { $0.section == section }
            return rows.isEmpty ? nil : (section, rows)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if isStillLearning {
                    Section {
                        StillLearningDiscoveryView()
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                ForEach(grouped, id: \.0.id) { section, rows in
                    Section(section.title) {
                        ForEach(rows) { recommendation in
                            Button {
                                dismiss()
                                DispatchQueue.main.async {
                                    onSelect(recommendation)
                                }
                            } label: {
                                ForYouRecommendationRow(recommendation: recommendation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if recommendations.isEmpty {
                    ContentUnavailableView(
                        "No picks here yet",
                        systemImage: "map",
                        description: Text("Move the map or search a city to explore nearby cafes.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("For You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("map.forYou.list")
    }
}

private struct ForYouRecommendationRow: View {
    let recommendation: ForYouRecommendation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.foamWhite)
                .frame(width: 38, height: 38)
                .background(Color.mugshotSage, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.candidate.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Text(recommendation.reason)
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct StillLearningDiscoveryView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.mugshotSageText)
                .frame(width: 36, height: 36)
                .background(Color.mugshotMint.opacity(0.32), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("Mugshot is still learning your taste")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Text("Nearby cafes are ready now. Your picks get more personal as you log Mugshots and save places.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
